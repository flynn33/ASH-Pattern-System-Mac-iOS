#!/usr/bin/env python3
"""Attribution Guard sentinel script.

Blocks forbidden attribution markers in:
  - branch/reference names
  - commit messages
  - author/committer identities
  - added lines in pushed commits

Supports:
  - CI mode via workflow-provided environment variables
  - local pre-push mode via standard Git hook stdin
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from typing import Iterable

from _common import finish, gh_error

ZERO_SHA = "0" * 40

PROVIDER_TOKEN = (
    r"(?:artificial\s+intelligence|large\s+language\s+model|llm|"
    r"chatgpt|openai|anthropic|claude|copilot|gemini|bard|"
    r"gpt(?:-[0-9a-z]+)?|codewhisperer|tabnine|cursor|windsurf|devin|codex)"
)

ATTRIBUTION_PHRASE_RE = re.compile(
    rf"(?i)\b(?:generated|written|authored|created|produced|assisted)"
    rf"\s+(?:by|with|using)\s+(?:an?\s+)?(?:{PROVIDER_TOKEN}|a[ -]?i)\b"
)
COAUTHOR_RE = re.compile(
    rf"(?i)\bco-authored-by:\s*.*(?:{PROVIDER_TOKEN}|a[ -]?i)\b"
)
IDENTITY_RE = re.compile(
    rf"(?i)(?:{PROVIDER_TOKEN}|noreply@(anthropic|openai)\.com)"
)
REF_PROVIDER_RE = re.compile(
    r"(?i)(?:^|[/_-])(?:chatgpt|openai|anthropic|claude|copilot|gemini|bard|"
    r"gpt|llm|codewhisperer|tabnine|cursor|windsurf|devin|codex)"
    r"(?:$|[/_-])"
)
REF_AI_SEGMENT_RE = re.compile(r"(?i)(?:^|[/_-])a[ -]?i(?:$|[/_-])")
HUNK_RE = re.compile(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@")

SKIP_PATHS = {
    ".github/scripts/attribution_guard_check.py",
    ".github/workflows/attribution-guard-agent.yml",
    ".githooks/pre-push",
}


@dataclass(frozen=True)
class PushUpdate:
    local_ref: str
    local_sha: str
    remote_ref: str
    remote_sha: str


@dataclass(frozen=True)
class Finding:
    category: str
    location: str
    line: int
    message: str


class GitClient:
    def run(self, *args: str) -> str:
        try:
            return subprocess.check_output(
                ["git", *args],
                stderr=subprocess.DEVNULL,
                text=True,
            ).strip()
        except Exception:
            return ""


class AttributionGuard:
    def __init__(self, git_client: GitClient):
        self.git = git_client
        self.findings: list[Finding] = []

    def run(self, mode: str) -> int:
        updates = self._collect_updates(mode)
        if not updates:
            print("Attribution Guard: no refs to evaluate.")
            return 0

        for update in updates:
            self._check_ref(update.local_ref, "local")
            self._check_ref(update.remote_ref, "remote")
            commits = self._commits_for_update(update)
            for commit in commits:
                self._check_commit_message(commit)
                self._check_identities(commit)
                self._check_added_lines(commit)

        return self._report()

    def _collect_updates(self, mode: str) -> list[PushUpdate]:
        if mode == "pre-push":
            return self._updates_from_stdin()
        return self._updates_from_env()

    def _updates_from_stdin(self) -> list[PushUpdate]:
        updates: list[PushUpdate] = []
        payload = sys.stdin.read().strip()
        if not payload:
            return updates
        for raw_line in payload.splitlines():
            parts = raw_line.split()
            if len(parts) != 4:
                continue
            updates.append(PushUpdate(*parts))
        return updates

    def _updates_from_env(self) -> list[PushUpdate]:
        head_sha = self._env("GUARD_HEAD_SHA")
        if not head_sha:
            return []
        base_sha = self._env("GUARD_BASE_SHA") or ZERO_SHA
        head_ref = self._normalize_ref(
            self._env("GUARD_HEAD_REF") or "refs/heads/unknown"
        )
        base_ref = self._normalize_ref(
            self._env("GUARD_BASE_REF") or "refs/heads/unknown"
        )
        return [PushUpdate(head_ref, head_sha, base_ref, base_sha)]

    @staticmethod
    def _env(name: str) -> str:
        return os.environ.get(name, "").strip()

    @staticmethod
    def _normalize_ref(ref: str) -> str:
        if ref.startswith("refs/"):
            return ref
        if not ref:
            return "refs/heads/unknown"
        return f"refs/heads/{ref}"

    @staticmethod
    def _short_ref(ref: str) -> str:
        if ref.startswith("refs/heads/"):
            return ref[len("refs/heads/") :]
        return ref

    def _commits_for_update(self, update: PushUpdate) -> list[str]:
        if not update.local_sha or update.local_sha == ZERO_SHA:
            return []
        if update.remote_sha and update.remote_sha != ZERO_SHA:
            out = self.git.run("rev-list", f"{update.remote_sha}..{update.local_sha}")
        else:
            out = self.git.run("rev-list", update.local_sha, "--not", "--remotes")
        return [line.strip() for line in out.splitlines() if line.strip()]

    def _check_ref(self, ref: str, kind: str) -> None:
        if not ref:
            return
        short_ref = self._short_ref(ref)
        if REF_PROVIDER_RE.search(short_ref) or REF_AI_SEGMENT_RE.search(short_ref):
            self.findings.append(
                Finding(
                    category="ref",
                    location=short_ref,
                    line=1,
                    message=f"Forbidden attribution marker in {kind} ref name.",
                )
            )

    def _check_commit_message(self, commit: str) -> None:
        message = self.git.run("log", "--format=%B", "-1", commit)
        if self._is_forbidden_text(message):
            self.findings.append(
                Finding(
                    category="commit",
                    location=commit,
                    line=1,
                    message="Forbidden attribution marker in commit message.",
                )
            )

    def _check_identities(self, commit: str) -> None:
        author = self.git.run("log", "--format=%an <%ae>", "-1", commit)
        committer = self.git.run("log", "--format=%cn <%ce>", "-1", commit)
        if IDENTITY_RE.search(author):
            self.findings.append(
                Finding(
                    category="identity",
                    location=commit,
                    line=1,
                    message=f"Forbidden attribution marker in author identity: {author}",
                )
            )
        if IDENTITY_RE.search(committer):
            self.findings.append(
                Finding(
                    category="identity",
                    location=commit,
                    line=1,
                    message=f"Forbidden attribution marker in committer identity: {committer}",
                )
            )

    def _check_added_lines(self, commit: str) -> None:
        patch = self.git.run("show", "--pretty=format:", "--unified=0", "--no-color", commit)
        current_file = ""
        line_number = 0
        for line in patch.splitlines():
            if line.startswith("+++ b/"):
                current_file = line[6:].strip()
                line_number = 0
                continue
            if line.startswith("+++ /dev/null"):
                current_file = ""
                line_number = 0
                continue
            if line.startswith("@@"):
                match = HUNK_RE.search(line)
                line_number = int(match.group(1)) if match else 0
                continue
            if line.startswith("+") and not line.startswith("+++"):
                if current_file and current_file not in SKIP_PATHS:
                    added_line = line[1:]
                    if self._is_forbidden_text(added_line):
                        self.findings.append(
                            Finding(
                                category="file",
                                location=current_file,
                                line=max(line_number, 1),
                                message=(
                                    "Forbidden attribution marker in "
                                    f"commit {commit[:12]}."
                                ),
                            )
                        )
                line_number += 1

    @staticmethod
    def _is_forbidden_text(text: str) -> bool:
        if not text:
            return False
        lower = text.lower()
        return bool(
            ATTRIBUTION_PHRASE_RE.search(text)
            or COAUTHOR_RE.search(text)
            or "noreply@anthropic.com" in lower
            or "noreply@openai.com" in lower
        )

    def _report(self) -> int:
        if not self.findings:
            print("Attribution Guard: no forbidden markers found.")
            return 0

        deduped = self._dedupe(self.findings)
        for finding in deduped:
            if finding.category == "file":
                gh_error(finding.location, finding.line, finding.message)
            else:
                print(f"::error::{finding.location}: {finding.message}")

        print(f"Found {len(deduped)} blocking issue(s).")
        return finish(True, "ATTRIBUTION GUARD")

    @staticmethod
    def _dedupe(items: Iterable[Finding]) -> list[Finding]:
        seen: set[tuple[str, str, int, str]] = set()
        deduped: list[Finding] = []
        for item in items:
            key = (item.category, item.location, item.line, item.message)
            if key in seen:
                continue
            seen.add(key)
            deduped.append(item)
        return deduped


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run attribution guard checks.")
    parser.add_argument(
        "--mode",
        choices=("ci", "pre-push"),
        required=True,
        help="Execution mode: CI (env-based) or pre-push (stdin-based).",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    guard = AttributionGuard(GitClient())
    return guard.run(args.mode)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
