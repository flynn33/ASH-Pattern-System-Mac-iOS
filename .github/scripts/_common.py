"""Shared helpers for ASH Pattern System governance agent scripts.

All four sentinel scripts (alignment, semantic-integrity, math-integrity,
downstream-conformance) reuse this module for:
  - report-only mode handling
  - repo-root resolution
  - repo walking with .git/ exclusion
  - paragraph splitting (for 8+1 reintroduction detection)
  - GitHub annotation printing
  - boxed banner printing

No external dependencies. Python 3 standard library only.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path


def repo_root() -> Path:
    """Return the repo root. Scripts are invoked from the repo root by the
    workflows, so os.getcwd() is the source of truth."""
    return Path(os.getcwd())


def report_only() -> bool:
    """Read the REPORT_ONLY env var. When true, scripts always exit 0 even
    if violations are found. The full report is still printed."""
    return os.environ.get("REPORT_ONLY", "0") == "1"


def walk_files(root: Path, skip_dirs=(".git",)):
    """Yield Path objects for every file under root, skipping listed dirs."""
    skip = set(skip_dirs)
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in skip]
        for name in filenames:
            yield Path(dirpath) / name


def read_text(path: Path) -> str:
    """Read a text file permissively. Returns empty string on failure."""
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return ""


def split_paragraphs(text: str):
    """Split text into paragraphs (contiguous non-blank lines).

    Returns a list of (start_line_1based, text) tuples so callers can emit
    GitHub annotations with the correct line number.
    """
    paragraphs = []
    current = []
    current_start = 1
    line_no = 0
    for line in text.splitlines():
        line_no += 1
        if line.strip() == "":
            if current:
                paragraphs.append((current_start, "\n".join(current)))
                current = []
            current_start = line_no + 1
        else:
            if not current:
                current_start = line_no
            current.append(line)
    if current:
        paragraphs.append((current_start, "\n".join(current)))
    return paragraphs


def rel(path: Path, root: Path) -> str:
    """POSIX-style path relative to root, for stable annotation output."""
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


def gh_error(file: str, line: int, message: str) -> None:
    print(f"::error file={file},line={line}::{message}")


def gh_warning(file: str, line: int, message: str) -> None:
    print(f"::warning file={file},line={line}::{message}")


def banner(title: str, status: str) -> None:
    """Boxed banner matching the style in .github/workflows/no-ai-attribution.yml."""
    bar = "=" * 42
    print()
    print(bar)
    print(f"{title} — {status}")
    print(bar)


# Negative / prohibition / superseded context markers. Used by the
# semantic-integrity and math-integrity agents to decide whether a
# superseded-era pattern is being reintroduced canonically (flag) or is
# being discussed / prohibited / marked historical (skip).
#
# The check is: strip markdown emphasis (* and _) from the backward window
# ending at the match position, then search for any of these markers. If
# any match, the context is negative and the finding is skipped.
import re as _re

_NEGATIVE_CONTEXT_MARKERS = _re.compile(
    r"\b("
    r"superseded|historical|not\s+canonical|non[- ]?canonical|"
    r"non-conformant|failure\s+condition|forbid\w*|prohibit\w*|reject\w*|"
    r"must\s+not|does\s+not|do\s+not|doesn'?t|don'?t|never|"
    r"observable\s+property|8\+1\s+(?:drift|formalization)"
    r")\b",
    _re.IGNORECASE,
)

_EMPHASIS = _re.compile(r"[*_]+")


def is_negative_context(full_text: str, match_start: int, back_window: int = 400) -> bool:
    """Return True if the content in the preceding window is clearly a
    prohibition, superseded marker, or historical discussion rather than a
    canonical assertion using the matched token.

    Only looks backward — looking forward is unsafe when a section mixes
    canonical assertions with later unrelated negations (e.g. a list of
    eligibility rules where item N happens to contain 'does not')."""
    start = max(0, match_start - back_window)
    window = full_text[start:match_start]
    # Strip markdown bold/italic so '**not**' matches '\bnot\b'-style patterns.
    window = _EMPHASIS.sub(" ", window)
    return bool(_NEGATIVE_CONTEXT_MARKERS.search(window))


def finish(failed: bool, title: str) -> int:
    """Return the exit code honoring REPORT_ONLY. Print a banner when failed."""
    if failed:
        if report_only():
            banner(title, "REPORT-ONLY (would block)")
            print("REPORT_ONLY is set; not blocking the run.")
            return 0
        banner(title, "BLOCKING")
        return 1
    return 0
