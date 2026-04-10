#!/usr/bin/env python3
"""Downstream Conformance Agent — reusable sentinel for downstream repos.

Validates the six canonical downstream conformance artifacts defined in
`handoff-templates/common-downstream-handoff-requirements.md`:

  1. module mapping
  2. verification report
  3. diagnostics conformance
  4. materialization boundary
  5. deviation log
  6. acceptance judgment

The acceptance judgment file must contain exactly one of the three canonical
judgment strings defined in
  specs/verification/implementation-acceptance.md line 69:
    CONFORMANT
    CONFORMANT WITH CAVEATS
    NON-CONFORMANT

The set of accepted strings is INTENTIONALLY aligned with the canonical
acceptance doc — neither broader nor narrower. If the canonical doc ever
narrows or broadens these, this script must be updated to match, not the
other way around.

Paths and require-all behavior are configurable via environment variables
populated from workflow inputs (see downstream-conformance-agent.yml).
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

from _common import banner, gh_error, gh_warning, read_text, rel, repo_root

CANONICAL_JUDGMENTS = ("CONFORMANT", "CONFORMANT WITH CAVEATS", "NON-CONFORMANT")


def env(name: str, default: str) -> str:
    val = os.environ.get(name, "")
    return val if val else default


def env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name, "")
    if not raw:
        return default
    return raw.strip().lower() in ("1", "true", "yes", "y")


def check_artifact(path: Path, label: str, root: Path) -> tuple[bool, list[str]]:
    """Return (ok, messages). Messages are printed regardless of ok."""
    rp = rel(path, root)
    if not path.is_file():
        return False, [f"{label}: missing ({rp})"]
    text = read_text(path)
    if not text.strip():
        return False, [f"{label}: file exists but is empty ({rp})"]
    if "#" not in text:
        return False, [f"{label}: file has no markdown heading ({rp})"]
    return True, [f"{label}: present ({rp})"]


def check_acceptance_judgment(path: Path, root: Path) -> tuple[bool, list[str]]:
    rp = rel(path, root)
    if not path.is_file():
        return False, [f"acceptance judgment: missing ({rp})"]
    text = read_text(path)
    if not text.strip():
        return False, [f"acceptance judgment: file exists but is empty ({rp})"]
    matched = [j for j in CANONICAL_JUDGMENTS if j in text]
    if not matched:
        return False, [
            f"acceptance judgment: no canonical judgment string found in {rp}",
            "  Expected one of: CONFORMANT, CONFORMANT WITH CAVEATS, NON-CONFORMANT",
            "  (canonical source: specs/verification/implementation-acceptance.md line 69)",
        ]
    # Multiple matches are allowed (e.g., a doc that discusses several);
    # downstream repos may document their judgment explicitly.
    return True, [f"acceptance judgment: present, contains canonical judgment ({rp})"]


def main() -> int:
    root = repo_root()

    conformance_root = env("CONFORMANCE_ROOT", "conformance/")
    module_mapping_path = env("MODULE_MAPPING_PATH", f"{conformance_root.rstrip('/')}/module-mapping.md")
    verification_report_path = env("VERIFICATION_REPORT_PATH", f"{conformance_root.rstrip('/')}/verification-report.md")
    diagnostics_conformance_path = env("DIAGNOSTICS_CONFORMANCE_PATH", f"{conformance_root.rstrip('/')}/diagnostics-conformance.md")
    materialization_boundary_path = env("MATERIALIZATION_BOUNDARY_PATH", f"{conformance_root.rstrip('/')}/materialization-boundary.md")
    deviation_log_path = env("DEVIATION_LOG_PATH", f"{conformance_root.rstrip('/')}/deviation-log.md")
    acceptance_judgment_path = env("ACCEPTANCE_JUDGMENT_PATH", f"{conformance_root.rstrip('/')}/acceptance-judgment.md")
    require_all = env_bool("REQUIRE_ALL", True)

    print("Downstream Conformance Agent — checking required artifacts...")
    print(f"  conformance-root:            {conformance_root}")
    print(f"  require-all:                 {require_all}")

    artifacts = [
        ("module mapping", root / module_mapping_path, False),
        ("verification report", root / verification_report_path, False),
        ("diagnostics conformance", root / diagnostics_conformance_path, False),
        ("materialization boundary", root / materialization_boundary_path, False),
        ("deviation log", root / deviation_log_path, False),
        ("acceptance judgment", root / acceptance_judgment_path, True),
    ]

    any_failed = False
    for label, path, is_judgment in artifacts:
        if is_judgment:
            ok, msgs = check_acceptance_judgment(path, root)
        else:
            ok, msgs = check_artifact(path, label, root)
        for msg in msgs:
            print(f"  {msg}")
        if not ok:
            any_failed = True
            if require_all:
                gh_error(rel(path, root), 1, f"{label}: required artifact missing or invalid")
            else:
                gh_warning(rel(path, root), 1, f"{label}: artifact missing or invalid (require-all=false)")

    if any_failed and require_all:
        banner("DOWNSTREAM CONFORMANCE AGENT", "MISSING ARTIFACTS")
        return 1
    if any_failed:
        print()
        print("Downstream Conformance Agent: some artifacts missing (require-all=false, non-blocking).")
        return 0
    print()
    print("Downstream Conformance Agent: all required artifacts present.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
