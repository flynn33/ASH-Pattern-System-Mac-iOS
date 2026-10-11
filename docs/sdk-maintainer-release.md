# Maintainer release procedure — 1.0.0

Use clean dedicated checkouts, repository-local owner identity and immutable authorities. The semantic VERSION is separate from numeric BUILD_NUMBER and derived Apple bundle configuration. `python3 tools/sdk/version.py` verifies derived files. Preserve existing release/tag bytes and unrelated worker changes.

## Source and reference gates

Run root and nested Debug/Release builds/tests with complete concurrency checking and warnings as errors. Run repository Python tests, SDK packager negative tests and the protected-surface/attribution guards with their supported options. Review the entire diff and actual source membership. Acquire the canonical test corpus reproducibly with `tools/acquire_canonical_corpus.py`; its manifest pins raw source/adapter hashes and all 10,340 cases. The canonical/method repositories stay outside SDK production/runtime.

The release build tool accepts an absolute fresh output directory:

```bash
./tools/sdk/build-sdk.sh --output '/absolute/empty/Release Build'
./tools/sdk/package-sdk.sh --build '/absolute/Release Build'   --provenance /absolute/external/provenance.json --output '/absolute/empty/Release Assets'
./tools/sdk/verify-sdk.sh '/absolute/Release Assets' --provenance /absolute/external/provenance.json
```

It archives both modules for macOS, iOS device and simulator, creates XCFrameworks, typechecks every public architecture interface against isolated module caches and checks Mach-O platform/minimums, dynamic dependency, privacy resources, release symbols and dSYMs. Actual archive failures and source changes during the matrix fail the build. Packaging rejects dirty/stale source, changed framework bytes, partial immutable metadata and unexpected payloads. Successful dirty-source plumbing is not an eligible release stage. Repeat on clean integrated source.

## Bindings and consumer gates

After integrating the Apple source, use a separate successor public-product profile pinned to that exact commit; preserve old profiles/validator/schema and original method 0.7.0. Provenance requires sourceCommit, canonicalCommit/version/schema/corpus, original methodCommit, canonical/native profile commits and SHA256, final contract SHA256, and actual tested/untested environment lists. Profile commits are policy revisions, not a replacement method version. Run original pinned contract/preflight/delivery tooling against matching producer/canonical and isolated consumer/canonical/native roots and profiles. Record all six independent realization conclusions.

```bash
./tools/sdk/verify-source-consumer.sh --revision ACTUAL_FORTY_CHARACTER_SHA --output '/absolute/empty/Git Revision Consumer'
ASH_PRODUCER_ROOT=/absolute/producer ./Examples/SDKConsumer/verify/verify-consumer.sh   --sdk '/absolute/extracted/ASH-Apple-SDK-1.0.0' --output '/absolute/empty/Binary Consumer' --simulators
python3 tools/sdk/compare-consumers.py --source '/absolute/Git Revision Consumer'   --binary '/absolute/Binary Consumer' --output /absolute/external/parity.json
```

Use the actual SHA in the source command. Inspect Package.resolved and the public-only product graph. A normal SwiftPM-managed source checkout is permitted; copied producer/canonical trees or test targets in consumer source are prohibited. Binary consumer build/runtime runs after acquisition with network and producer checkout reads denied. Require nonzero unique cases, real version/profile and fresh paired exports. Inspect native simulator screenshots and unsigned generic-device linkage separately from hardware execution. Run actual framework-mutation rejection tests on disposable copies, not only synthetic unit fixtures.

## Publication transaction

Create an owner-authored annotated `v1.0.0` tag at the qualified integrated commit, prove exact-version Git acquisition reaches the same SHA, create an unpublished draft for the stable release and upload only the five expected assets. The checksum file lists three ZIPs and external release manifest; it cannot contain its own digest. SDK-MANIFEST and COMPONENTS are custom provenance/inventory formats, not an industry SBOM claim. Inspect draft target, flags, inventory, sizes, hashes and notes before publishing as a stable release with the prerelease flag disabled.

Download every published asset into a fresh directory with spaces, verify external/internal hashes and repeat all public binary consumer modes, native iPhone/iPad simulator execution and generic-device build on those actual downloaded bytes. Preserve immutable published bytes; any published source/asset defect requires a new version. Synchronize maintained wiki source to actual `.wiki.git` remotes for every modified repository, then fetch and verify source/tag/wiki heads, clean status and no unpushed commits. Final reports name runtime gaps and physical-device owner validation pending.
