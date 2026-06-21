#!/usr/bin/env python3
"""Fail-closed metadata and content attribution sentinel."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path


ZERO_SHA = "0" * 40
GRANDFATHERED_PATHS = {
    ".github/workflows/no-ai-attribution.yml",
    "governance/ai-coding-handoff.md",
}

TOKEN_PARTS = (
    "ai",
    "assistant",
    "claude",
    "codex",
    "chatgpt",
    "gpt",
    "openai",
    "anthropic",
    "copilot",
    "gemini",
    "llm",
)

VENDOR_PARTS = (
    "claude",
    "anthropic",
    "chatgpt",
    "openai",
    "copilot",
    "gemini",
    "bard",
    "cursor",
    "windsurf",
    "devin",
    "codewhisperer",
    "tabnine",
)


class AttributionError(RuntimeError):
    pass


def run_git(*args: str) -> str:
    try:
        result = subprocess.run(
            ["git", *args],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        stderr = getattr(exc, "stderr", "") or str(exc)
        raise AttributionError(f"git {' '.join(args)} failed: {stderr}") from exc
    return result.stdout


def load_event() -> dict:
    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    if not event_path:
        return {}
    path = Path(event_path)
    if not path.is_file():
        raise AttributionError(f"GITHUB_EVENT_PATH does not exist: {event_path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise AttributionError(f"cannot parse event payload: {exc}") from exc


def commit_selector(event_name: str, event: dict) -> str | list[str]:
    if event_name == "pull_request":
        pr = event.get("pull_request") or {}
        base = (pr.get("base") or {}).get("sha", "")
        head = (pr.get("head") or {}).get("sha", "")
        if not base or not head:
            raise AttributionError("pull_request payload missing base/head SHA")
        return f"{base}..{head}"

    if event_name == "push":
        before = event.get("before", "")
        after = event.get("after", "") or os.environ.get("GITHUB_SHA", "")
        if not after:
            raise AttributionError("push payload missing after SHA")
        if before and before != ZERO_SHA:
            return f"{before}..{after}"
        pushed = [
            commit.get("id", "")
            for commit in event.get("commits", [])
            if isinstance(commit, dict) and commit.get("id")
        ]
        if not pushed:
            raise AttributionError("new-branch push payload missing explicit commit list")
        return pushed

    sha = os.environ.get("GITHUB_SHA", "")
    if sha:
        return f"{sha}^..{sha}"
    try:
        run_git("rev-parse", "--verify", "HEAD^")
        return "HEAD^..HEAD"
    except AttributionError:
        return "HEAD"


def parse_name_status(text: str) -> set[str]:
    paths: set[str] = set()
    for raw in text.splitlines():
        if not raw.strip():
            continue
        parts = raw.split("\t")
        status = parts[0]
        if status.startswith(("R", "C")):
            if len(parts) != 3:
                raise AttributionError(f"unexpected rename/copy record: {raw!r}")
            paths.update(parts[1:])
        else:
            if len(parts) != 2:
                raise AttributionError(f"unexpected change record: {raw!r}")
            paths.add(parts[1])
    return paths


def changed_files(selector: str | list[str]) -> set[str]:
    if isinstance(selector, list):
        paths: set[str] = set()
        for commit in selector:
            paths.update(parse_name_status(run_git("show", "--name-status", "--format=", "-M", commit, "--")))
        return paths
    if ".." in selector:
        return parse_name_status(run_git("diff", "--name-status", "-M", selector, "--"))
    return parse_name_status(run_git("show", "--name-status", "--format=", "-M", selector, "--"))


def commits(selector: str | list[str]) -> list[str]:
    if isinstance(selector, list):
        values = selector
    else:
        out = run_git("log", "--format=%H", selector)
        values = [line.strip() for line in out.splitlines() if line.strip()]
    if not values:
        raise AttributionError("commit range resolved to no commits")
    return values


def token_pattern() -> re.Pattern[str]:
    escaped = "|".join(re.escape(token) for token in sorted(TOKEN_PARTS, key=len, reverse=True))
    return re.compile(rf"(^|[/_.-])(?:{escaped})($|[/_.-])", re.IGNORECASE)


def metadata_pattern() -> re.Pattern[str]:
    escaped = "|".join(re.escape(token) for token in sorted(TOKEN_PARTS + VENDOR_PARTS, key=len, reverse=True))
    return re.compile(rf"\b(?:{escaped})\b", re.IGNORECASE)


def content_patterns() -> list[re.Pattern[str]]:
    vendor = "|".join(re.escape(token) for token in sorted(VENDOR_PARTS, key=len, reverse=True))
    synthetic = "ai|artificial intelligence|gpt|llm|large language model|machine learning|ml model"
    return [
        re.compile(("co-authored" + r"-by:\s*.*(?:") + vendor + r")", re.IGNORECASE),
        re.compile(r"\b(?:generated|written|authored|created|produced|assisted)\s+(?:by|with|using)\s+(?:" + synthetic + "|" + vendor + r")", re.IGNORECASE),
        re.compile(r"\bai[- ](?:generated|assisted|authored|written|created|produced)\b", re.IGNORECASE),
        re.compile(r"noreply@(?:anthropic|openai)\.com", re.IGNORECASE),
    ]


def line_number(text: str, pos: int) -> int:
    return text.count("\n", 0, pos) + 1


def check_ref_name(errors: list[str]) -> None:
    ref_name = os.environ.get("GITHUB_REF_NAME", "") or run_git("branch", "--show-current").strip()
    if not ref_name:
        return
    pattern = token_pattern()
    if pattern.search(ref_name):
        errors.append(f"prohibited attribution token in ref name: {ref_name}")


def check_paths(paths: set[str], errors: list[str]) -> None:
    pattern = token_pattern()
    for path in sorted(paths):
        if path in GRANDFATHERED_PATHS:
            continue
        if pattern.search(path):
            errors.append(f"prohibited attribution token in changed path: {path}")


def check_commit_metadata(commit_list: list[str], errors: list[str]) -> None:
    pattern = metadata_pattern()
    for commit in commit_list:
        record = run_git("log", "--format=%B%x1f%an%x1f%ae%x1f%cn%x1f%ce", "-1", commit)
        if pattern.search(record):
            errors.append(f"prohibited attribution token in commit metadata: {commit}")


def check_file_content(paths: set[str], errors: list[str]) -> None:
    patterns = content_patterns()
    for rel in sorted(paths):
        path = Path(rel)
        if not path.is_file():
            continue
        data = path.read_bytes()
        if b"\0" in data:
            continue
        text = data.decode("utf-8", errors="replace")
        for pattern in patterns:
            match = pattern.search(text)
            if match:
                errors.append(f"{rel}:{line_number(text, match.start())}: prohibited attribution marker in file content")
                break


def main() -> int:
    try:
        event_name = os.environ.get("GITHUB_EVENT_NAME", "")
        event = load_event()
        selector = commit_selector(event_name, event)
        commit_list = commits(selector)
        paths = changed_files(selector)

        errors: list[str] = []
        check_ref_name(errors)
        check_paths(paths, errors)
        check_commit_metadata(commit_list, errors)
        check_file_content(paths, errors)

        if errors:
            print("ATTRIBUTION CHECK: BLOCKING")
            for error in errors:
                print(f"::error::{error}")
            return 1

        print("Attribution check: no prohibited attribution metadata or markers found.")
        return 0
    except AttributionError as exc:
        print(f"::error::Attribution check failed closed: {exc}")
        return 2
    except Exception as exc:
        print(f"::error::Attribution check unexpected failure: {exc}")
        return 2


if __name__ == "__main__":
    sys.exit(main())
