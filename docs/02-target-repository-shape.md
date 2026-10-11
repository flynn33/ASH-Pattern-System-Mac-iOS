# Repository shape — 1.0.0

Root `Package.swift` and `MaciOS/Package.swift` compile the same public graph. `MaciOS/Sources/ASHCore` owns the core services and diagnostic profiles. `MaciOS/Sources/ASHOrchestration` supplies the public ASHPatternSystem module. `MaciOS/ASHSDK.xcodeproj` lists those same production files explicitly; shared framework schemes archive every required platform. Resources include each module's privacy manifest.

`MaciOS/Tests` contains public-surface XCTest and precisely acquired immutable canonical fixtures. `tools/acquire_canonical_corpus.py` records raw source and adapter identity. `Examples/SDKConsumer` contains product-owned public-only native and command-line verification. `tools/sdk` builds, curates and checks the SDK and consumers.

`docs` and `wiki` contain current SDK information. `specs` and `handoff-templates` preserve historical reference; their banners point to current external authority. `completion-evidence` preserves previous dated receipts. The instruction package, raw runtime evidence, full canonical/policy checkouts, archive stages and release assets live outside the product source and curated payload.
