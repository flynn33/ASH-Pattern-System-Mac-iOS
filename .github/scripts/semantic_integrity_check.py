#!/usr/bin/env python3
"""Canonical Semantic Integrity Agent — ASH Pattern System sentinel.

Checks:
  (a) Superseded 8+1 canonical language reintroduction in active canonical
      files. Narrow file-local exemption: a file is exempt if and only if
      its first 10 lines contain the literal token "SUPERSEDED". The
      exemption does not propagate.
  (b) Handoff-template authority inversion (any language claiming handoff
      templates override or are canonical authority).
  (c) Status-language contradiction across README.md, docs/03-design-roadmap.md,
      and governance/ai-coding-handoff.md:
        - WARNING (non-blocking, even outside REPORT_ONLY): broad completion
          phrase "All specification layers are complete" appears alone with no
          Phase-4-active phrase in the three files.
        - BLOCKING: broad completion phrase AND Phase-4-active phrase both
          appear across the three files (the actual contradiction this repo
          has already had to fix twice).

See governance/github-agents-governance.md for policy.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from _common import (
    banner,
    finish,
    gh_error,
    gh_warning,
    is_negative_context,
    read_text,
    rel,
    repo_root,
    walk_files,
)

# -------------------------------------------------------------------
# Active canonical scan roots for the 8+1 reintroduction check
# -------------------------------------------------------------------
ACTIVE_CANONICAL_ROOTS = [
    "README.md",
    "specs",
    "docs",
    "governance",
    "handoff-templates",
]

# 8+1 reintroduction patterns. Each match is reported only if its paragraph
# does NOT contain a superseded marker.
EIGHT_PLUS_ONE_PATTERNS = [
    (re.compile(r"\[\s*8\s*,\s*4\s*,\s*4\s*\]"), "[8,4,4] codeword notation"),
    (re.compile(r"\bderived\s+9(?:th)?\s+(?:control|parity)\s+bit\b", re.IGNORECASE), "derived 9th control/parity bit"),
    (re.compile(r"\b8[- ]?bit\s+core\s*\+\s*derived\s+9(?:th)?", re.IGNORECASE), "8-bit core + derived 9th"),
    (re.compile(r"\bb8\s*=\s*b0\s*(?:⊕|\^|XOR)", re.IGNORECASE), "b8 = b0 ⊕ ... derivation formula"),
    (re.compile(r"\bparity\s+formula\b", re.IGNORECASE), "parity formula"),
]

# File-local exemption marker: first 10 lines contain the token SUPERSEDED.
FIRST_LINES_WINDOW = 10


def is_file_exempt(text: str) -> bool:
    head = "\n".join(text.splitlines()[:FIRST_LINES_WINDOW])
    return "SUPERSEDED" in head


def iter_active_canonical_md(root: Path):
    for entry in ACTIVE_CANONICAL_ROOTS:
        p = root / entry
        if p.is_file() and p.suffix == ".md":
            yield p
        elif p.is_dir():
            for sub in p.rglob("*.md"):
                yield sub


def line_of(text: str, pos: int) -> int:
    """Return 1-based line number of position `pos` in `text`."""
    return text.count("\n", 0, pos) + 1


def check_eight_plus_one(root: Path) -> list[tuple[str, int, str]]:
    violations = []
    for path in iter_active_canonical_md(root):
        text = read_text(path)
        if not text:
            continue
        if is_file_exempt(text):
            continue
        for pat, label in EIGHT_PLUS_ONE_PATTERNS:
            for m in pat.finditer(text):
                if is_negative_context(text, m.start()):
                    continue
                violations.append((
                    rel(path, root),
                    line_of(text, m.start()),
                    f"Superseded 8+1 canonical language reintroduction: {label}",
                ))
    return violations


# -------------------------------------------------------------------
# (b) Handoff-template authority inversion (scan whole repo of .md files)
# -------------------------------------------------------------------
HANDOFF_AUTHORITY_PATTERNS = [
    re.compile(r"handoff\s+templates?\s+(?:are|is)\s+(?:the\s+)?(?:semantic\s+)?authority", re.IGNORECASE),
    re.compile(r"handoff\s+templates?\s+override\w*\s+canonical", re.IGNORECASE),
    re.compile(r"handoff\s+templates?\s+define\w*\s+canonical", re.IGNORECASE),
    re.compile(r"handoff\s+templates?\s+own\w*\s+canonical", re.IGNORECASE),
]


def check_handoff_authority(root: Path) -> list[tuple[str, int, str]]:
    violations = []
    for path in walk_files(root):
        if path.suffix.lower() != ".md":
            continue
        text = read_text(path)
        if not text:
            continue
        for line_no, line in enumerate(text.splitlines(), start=1):
            for pat in HANDOFF_AUTHORITY_PATTERNS:
                if pat.search(line):
                    violations.append((
                        rel(path, root),
                        line_no,
                        "Handoff templates must not claim canonical authority",
                    ))
                    break
    return violations


# -------------------------------------------------------------------
# (c) Status-language contradiction (warning vs blocking)
# -------------------------------------------------------------------
STATUS_FILES = [
    "README.md",
    "docs/03-design-roadmap.md",
    "governance/ai-coding-handoff.md",
]

BROAD_COMPLETION = re.compile(r"\ball\s+specification\s+layers\s+are\s+complete\b", re.IGNORECASE)
PHASE4_ACTIVE = re.compile(r"\bphase\s*4\b[^.\n]{0,80}\b(active|in\s+progress|current)\b", re.IGNORECASE)


def check_status_contradiction(root: Path):
    """Return (warnings, errors) lists of (file, line, message)."""
    warnings = []
    errors = []
    broad_hits = []  # (file, line, context)
    phase4_hits = []

    for rel_path in STATUS_FILES:
        p = root / rel_path
        if not p.is_file():
            continue
        text = read_text(p)
        if not text:
            continue
        for line_no, line in enumerate(text.splitlines(), start=1):
            if BROAD_COMPLETION.search(line):
                broad_hits.append((rel_path, line_no))
            if PHASE4_ACTIVE.search(line):
                phase4_hits.append((rel_path, line_no))

    if broad_hits and phase4_hits:
        # Blocking contradiction — record errors on the broad phrase lines,
        # citing the phase-4-active occurrences.
        cites = ", ".join(f"{f}:{ln}" for f, ln in phase4_hits)
        for f, ln in broad_hits:
            errors.append((
                f,
                ln,
                f"Status contradiction: broad completion phrase co-occurs with Phase-4-active phrase at {cites}",
            ))
    elif broad_hits:
        for f, ln in broad_hits:
            warnings.append((
                f,
                ln,
                "Broad completion phrase 'All specification layers are complete' — warning (not blocking)",
            ))

    return warnings, errors


def main() -> int:
    root = repo_root()
    print("Canonical Semantic Integrity Agent — scanning active canonical files...")

    all_errors: list[tuple[str, int, str]] = []

    eight_plus_one = check_eight_plus_one(root)
    if eight_plus_one:
        print(f"Found {len(eight_plus_one)} 8+1 reintroduction violation(s):")
        for v in eight_plus_one:
            print(f"  - {v[0]}:{v[1]}: {v[2]}")
            gh_error(*v)
    all_errors.extend(eight_plus_one)

    handoff = check_handoff_authority(root)
    if handoff:
        print(f"Found {len(handoff)} handoff-template authority-inversion violation(s):")
        for v in handoff:
            print(f"  - {v[0]}:{v[1]}: {v[2]}")
            gh_error(*v)
    all_errors.extend(handoff)

    warnings, status_errors = check_status_contradiction(root)
    for w in warnings:
        print(f"  WARNING {w[0]}:{w[1]}: {w[2]}")
        gh_warning(*w)
    if status_errors:
        print(f"Found {len(status_errors)} status-contradiction blocking violation(s):")
        for v in status_errors:
            print(f"  - {v[0]}:{v[1]}: {v[2]}")
            gh_error(*v)
    all_errors.extend(status_errors)

    if not all_errors and not warnings:
        print("Canonical Semantic Integrity Agent: no violations or warnings found.")
    elif not all_errors:
        print("Canonical Semantic Integrity Agent: warnings only, no blocking violations.")
    return finish(bool(all_errors), "CANONICAL SEMANTIC INTEGRITY AGENT")


if __name__ == "__main__":
    sys.exit(main())
