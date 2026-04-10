#!/usr/bin/env python3
"""Alignment Agent — ASH Pattern System sentinel.

Detects canonical-repo boundary drift:
  (a) implementation code anywhere outside the small .github/scripts/ allowlist
  (b) build / package / lockfile / platform-tree files anywhere in the repo
  (c) hierarchy-inversion language that treats a downstream repo as semantic
      authority over the canonical ASH Pattern System

Blocking when REPORT_ONLY is unset or "0". Exits 0 with full report when
REPORT_ONLY=1.

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
    read_text,
    rel,
    repo_root,
    walk_files,
)

# -------------------------------------------------------------------
# (a) Implementation code extensions (violation when outside allowlist)
# -------------------------------------------------------------------
IMPL_EXTENSIONS = {
    ".py", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx",
    ".rs", ".swift", ".java", ".kt", ".kts",
    ".cpp", ".cc", ".cxx", ".c", ".h", ".hpp",
    ".go", ".rb", ".php", ".cs", ".fs",
    ".m", ".mm", ".scala", ".lua", ".dart",
    ".ex", ".exs", ".erl", ".elm", ".clj", ".cljs",
    ".nim", ".zig", ".v", ".sol",
}

# Exact-path allowlist. .github/scripts/** is allowed via a prefix check below;
# anything else must be listed here explicitly.
ALLOWED_IMPL_PREFIXES = (".github/scripts/",)
ALLOWED_IMPL_EXACT: set[str] = set()

# -------------------------------------------------------------------
# (b) Build / package / platform-tree markers
# -------------------------------------------------------------------
BUILD_FILES = {
    "Cargo.toml", "Cargo.lock",
    "package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock",
    "pom.xml", "build.gradle", "build.gradle.kts",
    "settings.gradle", "settings.gradle.kts",
    "Makefile", "CMakeLists.txt",
    "pyproject.toml", "setup.py", "setup.cfg",
    "Pipfile", "Pipfile.lock", "poetry.lock",
    "go.mod", "go.sum",
    "Gemfile", "Gemfile.lock",
    "composer.json", "composer.lock",
    "Podfile", "Podfile.lock",
    "Package.swift",
}

PLATFORM_TREE_DIRS = {
    "src", "lib", "build", "dist", "target",
    "bin", "out", "node_modules", "vendor",
}

# -------------------------------------------------------------------
# (c) Hierarchy-inversion language
# -------------------------------------------------------------------
HIERARCHY_SCAN_GLOBS = [
    "README.md",
    "docs",
    "governance",
    "handoff-templates",
]

DOWNSTREAM_REFERENT = r"(aeostara|downstream\s+repo\w*|implementation\s+repo\w*|a\s+downstream|any\s+downstream|the\s+downstream)"
AUTHORITY_CLAIM = r"(source\s+of\s+truth|authoritative|defines\s+canonical\s+semantics|overrides?\s+canonical|canonical\s+authority)"

# Pair them in either direction within <=200 chars on the same line/window.
# Using negated class [^.\n]{0,200} to keep the match inside one sentence.
HIERARCHY_PATTERNS = [
    re.compile(rf"\b{DOWNSTREAM_REFERENT}\b[^.\n]{{0,200}}?\b{AUTHORITY_CLAIM}\b", re.IGNORECASE),
    re.compile(rf"\b{AUTHORITY_CLAIM}\b[^.\n]{{0,200}}?\b{DOWNSTREAM_REFERENT}\b", re.IGNORECASE),
]


def check_impl_code(root: Path) -> list[tuple[str, int, str]]:
    """Return list of (file, line, message) violations."""
    violations = []
    for path in walk_files(root):
        if path.suffix.lower() not in IMPL_EXTENSIONS:
            continue
        rp = rel(path, root)
        if any(rp.startswith(p) for p in ALLOWED_IMPL_PREFIXES):
            continue
        if rp in ALLOWED_IMPL_EXACT:
            continue
        violations.append((rp, 1, f"Implementation file not permitted in canonical repo: {path.suffix}"))
    return violations


def check_build_files(root: Path) -> list[tuple[str, int, str]]:
    violations = []
    for path in walk_files(root):
        rp = rel(path, root)
        if path.name in BUILD_FILES:
            violations.append((rp, 1, f"Build/package file not permitted in canonical repo: {path.name}"))
    # Top-level platform trees
    for name in PLATFORM_TREE_DIRS:
        if (root / name).is_dir():
            violations.append((name + "/", 1, f"Platform/build tree directory not permitted at repo root: {name}/"))
    return violations


def check_hierarchy_inversion(root: Path) -> list[tuple[str, int, str]]:
    violations = []
    targets: list[Path] = []
    for glob in HIERARCHY_SCAN_GLOBS:
        p = root / glob
        if p.is_file() and p.suffix == ".md":
            targets.append(p)
        elif p.is_dir():
            for sub in p.rglob("*.md"):
                targets.append(sub)

    for path in targets:
        text = read_text(path)
        if not text:
            continue
        for line_no, line in enumerate(text.splitlines(), start=1):
            for pat in HIERARCHY_PATTERNS:
                if pat.search(line):
                    violations.append((
                        rel(path, root),
                        line_no,
                        "Hierarchy inversion: downstream referent paired with canonical-authority claim",
                    ))
                    break
    return violations


def main() -> int:
    root = repo_root()
    all_violations: list[tuple[str, int, str]] = []

    print("Alignment Agent — scanning canonical repository boundary...")

    impl = check_impl_code(root)
    if impl:
        print(f"Found {len(impl)} implementation-code violation(s):")
        for v in impl:
            print(f"  - {v[0]}: {v[2]}")
            gh_error(*v)
    all_violations.extend(impl)

    build = check_build_files(root)
    if build:
        print(f"Found {len(build)} build/package/platform-tree violation(s):")
        for v in build:
            print(f"  - {v[0]}: {v[2]}")
            gh_error(*v)
    all_violations.extend(build)

    hier = check_hierarchy_inversion(root)
    if hier:
        print(f"Found {len(hier)} hierarchy-inversion violation(s):")
        for v in hier:
            print(f"  - {v[0]}:{v[1]}: {v[2]}")
            gh_error(*v)
    all_violations.extend(hier)

    if not all_violations:
        print("Alignment Agent: no violations found.")
    return finish(bool(all_violations), "ALIGNMENT AGENT")


if __name__ == "__main__":
    sys.exit(main())
