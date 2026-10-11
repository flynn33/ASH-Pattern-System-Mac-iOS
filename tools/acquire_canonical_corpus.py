#!/usr/bin/env python3
"""Acquire an explicit immutable APS fixture map for XCTest only."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

CANONICAL_COMMIT = "50d7e5ab88932a4a967ffc2c83bd18fae45b73c8"
CANONICAL_VERSION = "1.0.0-rc.3"
SOURCE_REPOSITORY = "https://github.com/flynn33/ASH-Pattern-System"
FIXTURE_ROOT = Path("MaciOS/Tests/ASHCoreTests/Fixtures/CanonicalReference")
CATEGORIES = (
    "averaging", "axioms", "codewords", "containment", "diagnostic-chains",
    "diagnostics", "fallback", "generation-plans", "materialization-boundary",
    "reachability", "realm-identities", "recovery", "safe-halt",
    "state-assessments", "states", "topology", "transformations",
)
ASSETS = {
    f"conformance/1.0/vectors/{name}.jsonl": f"Corpus/{name}.jsonl"
    for name in CATEGORIES
}
ASSETS.update({
    "conformance/1.0/manifest.json": "Corpus/corpus-manifest.json",
    "conformance/1.0/SHA256SUMS": "Corpus/corpus-SHA256SUMS",
    "conformance/1.0/invalid/invalid-state-signature.json": "Invalid/invalid-state-signature.json",
    "conformance/1.0/invalid/undeclared-rule-id.json": "Invalid/undeclared-rule-id.json",
    "conformance/1.0/invalid/manifest.json": "Invalid/invalid-vector-manifest.json",
    "examples/invalid/diagnostic-empty-notes.json": "Invalid/diagnostic-empty-notes.json",
    "examples/invalid/diagnostic-missing-details.json": "Invalid/diagnostic-missing-details.json",
    "examples/invalid/manifest.json": "Invalid/invalid-example-manifest.json",
    "canonical-data/1.0/fallback-policy-definitions.json": "Corpus/fallback-policy-definitions.json",
    "canonical-data/1.0/rule-registry.json": "Corpus/rule-registry.json",
})
GENERATOR_FILES = (
    "tools/product/__init__.py", "tools/product/aps_product.py",
    "tools/product/diagnostic_contract.py", "tools/product/cli.py",
    "tools/product/generate_canonical_data.py",
    "tools/product/generate_conformance_corpus.py",
)
GENERATOR_COMMANDS = (
    "tools/product/generate_canonical_data.py",
    "tools/product/generate_conformance_corpus.py",
)


def git_bytes(checkout: Path, source: str) -> bytes:
    return subprocess.check_output(
        ["git", "show", f"{CANONICAL_COMMIT}:{source}"], cwd=checkout
    )


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def acquire(checkout: Path, target: Path, work_directory: Path) -> dict:
    """Regenerate outside product source, compare pinned bytes, then copy the map."""
    subprocess.run(["git", "cat-file", "-e", CANONICAL_COMMIT + "^{commit}"],
                   cwd=checkout, check=True)
    assets = {source: git_bytes(checkout, source) for source in ASSETS}
    generators = {source: git_bytes(checkout, source) for source in GENERATOR_FILES}
    work_directory.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="aps-reference-", dir=work_directory) as temp:
        work = Path(temp)
        source_root = work / "generator"
        generated = work / "generated"
        for source, data in generators.items():
            path = source_root / source
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        for command in GENERATOR_COMMANDS:
            subprocess.run([sys.executable, str(source_root / command), "--root", str(generated)],
                           cwd=source_root, check=True)
        for source, data in assets.items():
            if source.endswith("SHA256SUMS"):
                continue  # Release inventory is compared to its immutable Git blob.
            produced = generated / source
            if not produced.is_file() or produced.read_bytes() != data:
                raise ValueError(f"Pinned generator reproduction differs: {source}")
    rows = []
    for source, data in assets.items():
        destination = target / ASSETS[source]
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        record = {"sourcePath": source, "fixturePath": ASSETS[source],
                  "sha256": digest(data), "sizeBytes": len(data)}
        if source.endswith(".jsonl"):
            record["vectorCount"] = len(data.splitlines())
        rows.append(record)
    manifest = {
        "schemaVersion": "1.0", "sourceRepository": SOURCE_REPOSITORY,
        "sourceCommit": CANONICAL_COMMIT, "productVersion": CANONICAL_VERSION,
        "scope": "Explicit raw XCTest fixtures; excluded from runtime products and SDK payloads.",
        "acquisitionScript": "tools/acquire_canonical_corpus.py",
        "acquisitionScriptSha256": digest(Path(__file__).read_bytes()),
        "generatorCommands": list(GENERATOR_COMMANDS),
        "generatorFiles": [{"sourcePath": source, "sha256": digest(data)}
                           for source, data in generators.items()],
        "generatorReproduction": "Exact pinned-byte comparison for every mapped generated JSON/JSONL artifact.",
        "assets": rows,
    }
    (target / "corpus-provenance.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return manifest


def verify(checkout: Path, target: Path) -> dict:
    manifest = json.loads((target / "corpus-provenance.json").read_text(encoding="utf-8"))
    if (manifest["sourceCommit"] != CANONICAL_COMMIT
            or manifest["productVersion"] != CANONICAL_VERSION
            or manifest["sourceRepository"] != SOURCE_REPOSITORY
            or manifest["acquisitionScriptSha256"] != digest(Path(__file__).read_bytes())):
        raise ValueError("Fixture provenance or acquisition-script identity differs")
    expected_generators = [{"sourcePath": source, "sha256": digest(git_bytes(checkout, source))}
                           for source in GENERATOR_FILES]
    if (manifest["generatorFiles"] != expected_generators
            or manifest["generatorCommands"] != list(GENERATOR_COMMANDS)):
        raise ValueError("Pinned generator provenance differs")
    actual_map = {item["sourcePath"]: item["fixturePath"] for item in manifest["assets"]}
    if actual_map != ASSETS or len(manifest["assets"]) != len(ASSETS):
        raise ValueError("Fixture map differs from the explicit acquisition map")
    fixture_paths = {path.relative_to(target).as_posix()
                     for directory in (target / "Corpus", target / "Invalid")
                     for path in directory.rglob("*") if path.is_file()}
    if fixture_paths != set(ASSETS.values()):
        raise ValueError("Unmapped or missing raw reference fixtures")
    for item in manifest["assets"]:
        source = git_bytes(checkout, item["sourcePath"])
        fixture = (target / item["fixturePath"]).read_bytes()
        if (source != fixture or item["sha256"] != digest(source)
                or item["sizeBytes"] != len(source)):
            raise ValueError(f"Fixture bytes or digest differ: {item['fixturePath']}")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--canonical-checkout", type=Path, required=True)
    parser.add_argument("--work-directory", type=Path)
    parser.add_argument("--output-root", type=Path, default=Path(__file__).resolve().parents[1] / FIXTURE_ROOT)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    try:
        if args.verify_only:
            manifest = verify(args.canonical_checkout, args.output_root)
        else:
            if args.work_directory is None:
                parser.error("--work-directory must point to an external execution directory")
            product_root = Path(__file__).resolve().parents[1]
            if product_root == args.work_directory.resolve() or product_root in args.work_directory.resolve().parents:
                parser.error("Canonical generator execution must remain outside the product repository")
            acquire(args.canonical_checkout, args.output_root, args.work_directory)
            manifest = verify(args.canonical_checkout, args.output_root)
    except (ValueError, OSError, subprocess.CalledProcessError, KeyError) as exc:
        print(f"Canonical fixture validation failed: {exc}", file=sys.stderr)
        return 1
    print(f"Verified {len(manifest['assets'])} immutable test fixtures at {CANONICAL_COMMIT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
