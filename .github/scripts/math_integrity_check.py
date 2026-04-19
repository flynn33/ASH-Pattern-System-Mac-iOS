#!/usr/bin/env python3
"""Math Integrity Agent — ASH Pattern System sentinel.

Protects the locked 9D research baseline math.

Checks when any math-critical path is in the push/PR changed set:
  (a) A math-change note must exist in the same push/PR under
      governance/math-change-notes/*.md (excluding README.md) and must
      contain the three required headings: "## What changed", "## Why",
      "## Baseline preservation statement".
  (b) If the event is a pull_request and the PR payload is available,
      at least one human-review label must be present on the PR:
      "math-reviewed", "human-reviewed", or "baseline-approved".
  (c) No 8+1 canonical language appears in the post-change content of
      math-critical files (same patterns as the semantic-integrity agent).
  (d) Narrow 9D baseline-marker check: files in BASELINE_MARKER_PATHS
      that are edited must still contain at least one of the 9D markers
      after the change.

Blocking when REPORT_ONLY is unset or "0". Exits 0 with full report when
REPORT_ONLY=1.

See governance/github-agents-governance.md for policy.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

from _common import (
    banner,
    finish,
    gh_error,
    is_negative_context,
    read_text,
    rel,
    repo_root,
)

# -------------------------------------------------------------------
# Protected math-critical files. Editing any of these triggers the
# change-note requirement and the 8+1 reintroduction scan.
# -------------------------------------------------------------------
MATH_CRITICAL_PATHS = {
    "specs/core/ash-state-space.pseudo.md",
    "specs/core/codeword-set.pseudo.md",
    "specs/core/realm-identity.pseudo.md",
    "specs/core/recoverability-semantics.pseudo.md",
    "specs/core/state-admissibility.pseudo.md",
    "specs/core/state-validity-diagnostics.pseudo.md",
    "specs/core/system-state-classification.pseudo.md",
    "specs/algorithms/averaging-operator-semantics.pseudo.md",
    "specs/algorithms/branching-semantics.pseudo.md",
    "specs/algorithms/codeword-transformation-semantics.pseudo.md",
    "specs/algorithms/containment-safe-failure-semantics.pseudo.md",
    "specs/algorithms/recovery-fallback-semantics.pseudo.md",
    "specs/algorithms/transition-system.pseudo.md",
    "specs/algorithms/topology-expansion.pseudo.md",
    "specs/algorithms/axiom-evaluation.pseudo.md",
    "specs/algorithms/generation-planning.pseudo.md",
    "specs/verification/invariant-spec.md",
    "specs/verification/conformance-categories.md",
    "specs/verification/implementation-acceptance.md",
}

# -------------------------------------------------------------------
# Narrow subset: files where the 9D baseline is directly restated
# algebraically. Only these files are checked for the continued presence
# of 9D baseline markers after an edit.
# -------------------------------------------------------------------
BASELINE_MARKER_PATHS = {
    "specs/core/ash-state-space.pseudo.md",
    "specs/core/codeword-set.pseudo.md",
    "specs/core/realm-identity.pseudo.md",
    "specs/algorithms/codeword-transformation-semantics.pseudo.md",
    "specs/algorithms/averaging-operator-semantics.pseudo.md",
    "specs/algorithms/branching-semantics.pseudo.md",
}

BASELINE_MARKERS = [
    re.compile(r"F2\^9"),
    re.compile(r"F_2\^9"),
    re.compile(r"\b9D\b"),
    re.compile(r"9-dimensional", re.IGNORECASE),
    re.compile(r"full\s+9", re.IGNORECASE),
]

# Same 8+1 patterns as the semantic-integrity agent. is_negative_context()
# from _common applies the prohibition/superseded skip rule consistently.
EIGHT_PLUS_ONE_PATTERNS = [
    (re.compile(r"\[\s*8\s*,\s*4\s*,\s*4\s*\]"), "[8,4,4] codeword notation"),
    (re.compile(r"\bderived\s+9(?:th)?\s+(?:control|parity)\s+bit\b", re.IGNORECASE), "derived 9th control/parity bit"),
    (re.compile(r"\b8[- ]?bit\s+core\s*\+\s*derived\s+9(?:th)?", re.IGNORECASE), "8-bit core + derived 9th"),
    (re.compile(r"\bb8\s*=\s*b0\s*(?:⊕|\^|XOR)", re.IGNORECASE), "b8 = b0 ⊕ ... derivation formula"),
    (re.compile(r"\bparity\s+formula\b", re.IGNORECASE), "parity formula"),
]

REQUIRED_NOTE_HEADINGS = (
    "## What changed",
    "## Why",
    "## Baseline preservation statement",
)

HUMAN_REVIEW_LABELS = {"math-reviewed", "human-reviewed", "baseline-approved"}

NOTES_DIR = "governance/math-change-notes"


# -------------------------------------------------------------------
# Changed-file detection (mirrors .github/workflows/attribution-guard-agent.yml)
# -------------------------------------------------------------------
def git(*args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", *args],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except Exception:
        return ""


def changed_files() -> list[str]:
    """Return the POSIX-style list of files changed in the current event."""
    event_name = os.environ.get("GITHUB_EVENT_NAME", "")
    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    payload = {}
    if event_path and Path(event_path).is_file():
        try:
            payload = json.loads(Path(event_path).read_text(encoding="utf-8"))
        except Exception:
            payload = {}

    files: list[str] = []
    if event_name == "pull_request":
        base = payload.get("pull_request", {}).get("base", {}).get("sha", "")
        head = payload.get("pull_request", {}).get("head", {}).get("sha", "")
        if base and head:
            out = git("diff", "--name-only", base, head)
            if out:
                files = out.splitlines()
    else:
        before = payload.get("before", "")
        after = payload.get("after", "") or os.environ.get("GITHUB_SHA", "")
        if before and after and before != "0000000000000000000000000000000000000000":
            out = git("diff", "--name-only", before, after)
            if out:
                files = out.splitlines()
        elif after:
            # New branch or no before-sha: inspect just the tip commit.
            out = git("show", "--name-only", "--format=", after)
            if out:
                files = [ln for ln in out.splitlines() if ln]

    # Local self-test fallback: no GitHub env vars present.
    if not files and not event_name:
        # No event context: treat as a local dry-run with an empty diff.
        return []

    return files


def pr_labels() -> set[str]:
    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    if not event_path or not Path(event_path).is_file():
        return set()
    try:
        payload = json.loads(Path(event_path).read_text(encoding="utf-8"))
    except Exception:
        return set()
    pr = payload.get("pull_request") or {}
    labels = pr.get("labels") or []
    return {lbl.get("name", "") for lbl in labels if isinstance(lbl, dict)}


# -------------------------------------------------------------------
# Checks
# -------------------------------------------------------------------
def check_change_note(root: Path, changed: list[str]) -> list[tuple[str, int, str]]:
    """Require a valid math-change note in the same changed set."""
    errors = []
    notes = [
        f for f in changed
        if f.startswith(NOTES_DIR + "/")
        and f.endswith(".md")
        and not f.endswith(NOTES_DIR + "/README.md")
    ]
    if not notes:
        errors.append((
            NOTES_DIR + "/",
            1,
            f"Math-critical file edited but no note found under {NOTES_DIR}/ in the same push/PR",
        ))
        return errors

    for note_rel in notes:
        note_path = root / note_rel
        if not note_path.is_file():
            # Staged for deletion or otherwise missing post-change — skip.
            continue
        text = read_text(note_path)
        missing = [h for h in REQUIRED_NOTE_HEADINGS if h not in text]
        if missing:
            errors.append((
                note_rel,
                1,
                "Math-change note missing required heading(s): " + ", ".join(missing),
            ))
    return errors


def check_pr_review_label() -> list[tuple[str, int, str]]:
    if os.environ.get("GITHUB_EVENT_NAME", "") != "pull_request":
        return []
    labels = pr_labels()
    if labels & HUMAN_REVIEW_LABELS:
        return []
    return [(
        "PR",
        1,
        "Add a human-review label after review (math-reviewed, human-reviewed, or baseline-approved)",
    )]


def line_of(text: str, pos: int) -> int:
    return text.count("\n", 0, pos) + 1


def check_8_plus_1_in_math_files(root: Path, changed: list[str]) -> list[tuple[str, int, str]]:
    errors = []
    for rel_path in changed:
        if rel_path not in MATH_CRITICAL_PATHS:
            continue
        path = root / rel_path
        if not path.is_file():
            continue
        text = read_text(path)
        for pat, label in EIGHT_PLUS_ONE_PATTERNS:
            for m in pat.finditer(text):
                if is_negative_context(text, m.start()):
                    continue
                errors.append((
                    rel_path,
                    line_of(text, m.start()),
                    f"Superseded 8+1 canonical language in math-critical file: {label}",
                ))
    return errors


def check_baseline_markers(root: Path, changed: list[str]) -> list[tuple[str, int, str]]:
    errors = []
    for rel_path in changed:
        if rel_path not in BASELINE_MARKER_PATHS:
            continue
        path = root / rel_path
        if not path.is_file():
            continue
        text = read_text(path)
        if not any(m.search(text) for m in BASELINE_MARKERS):
            errors.append((
                rel_path,
                1,
                "9D baseline markers missing — possible silent baseline replacement",
            ))
    return errors


def main() -> int:
    root = repo_root()
    print("Math Integrity Agent — scanning for edits to locked-baseline math files...")

    changed = changed_files()
    math_changed = sorted(set(changed) & MATH_CRITICAL_PATHS)

    if not math_changed:
        print("No math-critical files changed. Nothing to check.")
        return finish(False, "MATH INTEGRITY AGENT")

    print(f"Math-critical files changed: {len(math_changed)}")
    for f in math_changed:
        print(f"  - {f}")

    all_errors: list[tuple[str, int, str]] = []

    note_errors = check_change_note(root, changed)
    for e in note_errors:
        print(f"  - {e[0]}:{e[1]}: {e[2]}")
        gh_error(*e)
    all_errors.extend(note_errors)

    label_errors = check_pr_review_label()
    for e in label_errors:
        print(f"  - {e[0]}:{e[1]}: {e[2]}")
        gh_error(*e)
    all_errors.extend(label_errors)

    eight_errors = check_8_plus_1_in_math_files(root, changed)
    for e in eight_errors:
        print(f"  - {e[0]}:{e[1]}: {e[2]}")
        gh_error(*e)
    all_errors.extend(eight_errors)

    baseline_errors = check_baseline_markers(root, changed)
    for e in baseline_errors:
        print(f"  - {e[0]}:{e[1]}: {e[2]}")
        gh_error(*e)
    all_errors.extend(baseline_errors)

    if not all_errors:
        print("Math Integrity Agent: all math-critical edits are properly documented and preserve baseline shape.")
    return finish(bool(all_errors), "MATH INTEGRITY AGENT")


if __name__ == "__main__":
    sys.exit(main())
