# Source acceptance and release gates — 1.0.0-rc.1

This record describes the source candidate and required final transaction. It does not prefill a publication success or an integrated SHA into its own commit. Final SDK-MANIFEST, RELEASE-MANIFEST and external release verification identify the real delivered source and bindings.

## Observed source evidence

The baseline had 35 Debug and 35 Release tests. An exact native source reproduction showed raw 512 and 65535 accepted by Codable despite the direct state initializer refusing them. Duplicate injected transition registries and empty topology branches could trap. The owning decode/registry/topology boundaries now reject those inputs with regression evidence. Canonical rc.2 reuse and bounded rc.3 source correction are recorded in [authority/conformance](sdk-authority-and-conformance.md).

The final guard-inclusive source run passed 106 XCTest cases per configuration (84 Core and 22 composed), in each of root/nested Debug/Release with warnings as errors. Strict root and nested Debug/Release suites exercise the expanded native source, including all 10,340 raw canonical cases, complete diagnostic/chain parity, malformed nested input, complete forged-plan guards, validated context, fallback evidence and frozen session entrypoints. Narrow session ThreadSanitizer tests exercised concurrency without reported races. Final-source counts and command hashes are preserved in the external qualification record; earlier successful suites are superseded when reviewed fixes change source.

The strict parser additionally passed 1,000 independent portable canonical JSON comparisons and rejected nonportable cases. Independent canonical schema and semantic validators accepted actual emitted containment/halt wrappers, complete original/action chains, times and by-value prefixes. Support tests executed real controlled decoding failure, JSON/Markdown parity, redaction before retention/export, concurrent bounded retention, overflow counters, invalid/symlink/unwritable destinations, cancellation, full canonical chains and unsafe-evidence refusal. Release uses the minimal actor selected at compilation. Privacy manifests declare no tracking, collected-data categories or required-reason API categories; source/API review found no calls in Apple's listed categories in the SDK implementation.

## Required final release evidence

Clean integrated source must pass equivalent root/nested source gates. Both frameworks must archive for macOS arm64/x86_64, device arm64 and simulator arm64/x86_64, with independent public-interface typechecking, real minimum/platform metadata, Core linkage once, correct privacy resources, Release development-symbol exclusion and matching dSYMs. Real disposable framework mutation tests and packager unit rejection cases must pass. A dirty or changed build stage cannot be packaged.

Source Git consumers must resolve the integrated SHA and then exact annotated release tag. Core-only, composed-only and dual-product observations must match binary acquisition. Extracted and downloaded-byte binary consumers must run with producer sources inaccessible and network denied after acquisition, return nonzero unique checks and real Release-minimal identity, export useful paired evidence and exercise iPhone/iPad native simulator UI plus unsigned device linkage. Six realization reviews and original-method contract/preflight/delivery must bind the actual successor profiles.

Only then publish the curated prerelease, download every asset, verify external/internal digests and repeat consumers on those downloaded bytes. Actual source/wiki/tag synchronization, release inventory, signatures and environment/case counts belong to the final delivery record. Historical `completion-evidence` receipts are unchanged.

## Limits and owner phase

Physical-device validation is pending [owner procedure](sdk-owner-validation.md). Oldest supported OS versions, older compilers and translated Intel runtime are unexecuted. Framework deployment metadata and public interface checks are narrower evidence. No product UI/accessibility acceptance, signed product application, notarization, App Store or TestFlight delivery is claimed. Failure-injection of fsync/write/rename, hostile concurrent filesystem races and crash-time flush were not exercised; the implemented transactional paths have source review and the stated native error tests. CPU/memory profiling is unavailable, not an invented measured budget.
