#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path


PROTECTED_SPECS = (
    ".github",
    "governance",
    "CODEOWNERS",
    ".github/CODEOWNERS",
)


class VerificationError(RuntimeError):
    pass


def run_git(args: list[str], cwd: Path) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise VerificationError(result.stderr.strip() or result.stdout.strip())
    return result.stdout


def repository_root(cwd: Path) -> Path:
    return Path(run_git(["rev-parse", "--show-toplevel"], cwd).strip())


def current_commit(root: Path) -> str:
    return run_git(["rev-parse", "HEAD"], root).strip()


def current_branch(root: Path) -> str:
    return run_git(["branch", "--show-current"], root).strip()


def protected_status(root: Path) -> list[str]:
    output = run_git(
        ["status", "--porcelain", "--untracked-files=all", "--", *PROTECTED_SPECS],
        root,
    )
    return [line for line in output.splitlines() if line.strip()]


def tracked_protected_files(root: Path) -> list[Path]:
    output = run_git(["ls-files", "-z", "--", *PROTECTED_SPECS], root)
    files = []
    for raw in output.split("\0"):
        if not raw:
            continue
        path = root / raw
        if path.is_file():
            files.append(path)
    return sorted(files)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def protected_items(root: Path) -> list[dict[str, str]]:
    items = []
    for index, path in enumerate(tracked_protected_files(root), start=1):
        relative = path.relative_to(root).as_posix()
        items.append(
            {
                "item_id": f"protected-item-{index:03d}",
                "path_sha256": sha256_bytes(relative.encode("utf-8")),
                "content_sha256": sha256_bytes(path.read_bytes()),
            }
        )
    return items


def write_baseline(root: Path, output_path: Path, mode: str) -> None:
    target = output_path if output_path.is_absolute() else root / output_path
    target.parent.mkdir(parents=True, exist_ok=True)
    baseline = {
        "mode": mode,
        "baseline_commit": current_commit(root),
        "branch": current_branch(root),
        "protected_surface_diff_status": "clean",
        "protected_items": protected_items(root),
    }
    target.write_text(json.dumps(baseline, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify product protected surface integrity.")
    parser.add_argument("--mode", choices=["product"], required=True)
    parser.add_argument("--write-baseline", action="store_true")
    parser.add_argument(
        "--output",
        default="completion-evidence/protected-surface-baseline.json",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        root = repository_root(Path.cwd())
        changes = protected_status(root)
        if changes:
            print(f"protected surface has changes: {len(changes)} item(s)")
            return 1

        if args.write_baseline:
            write_baseline(root, Path(args.output), args.mode)

        print("protected surface verification passed")
        return 0
    except VerificationError as exc:
        print(f"protected surface verification failed: {exc}")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
