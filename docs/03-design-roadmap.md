# Design Roadmap

## Goal

Complete the Mac/iOS edition as a native, testable, releasable implementation of the ASH Pattern System for supported Apple platforms.

## Current State

The repository currently contains:

- Swift implementations for all nine APS semantic modules;
- Swift package products `ASHCore` and `ASHPatternSystem`;
- XCTest coverage with canonical corpus fixtures;
- SwiftPM and Xcode package-scheme verification evidence for macOS and iOS;
- macOS and iOS completion evidence under `completion-evidence/`;
- release acceptance reports that block signed platform release.

## Completed Platform Work

### Semantic Core

Implemented modules:

- `ASHStateModel`
- `ASHRecoveryEngine`
- `ASHRealmEncoder`
- `ASHTransitionRegistry`
- `ASHTopologyGenerator`
- `ASHAxiomEvaluator`
- `ASHGenerationPlanner`
- `ASHArtifactEmitter`
- `ASHDiagnosticsModule`

### Apple Build Assets

The current package uses:

- Swift tools version 5.10;
- SwiftPM package metadata;
- Xcode package-scheme builds;
- XCTest targets;
- canonical corpus fixtures under `MaciOS/Tests/ASHCoreTests/Fixtures/`.

### Conformance Documentation

macOS evidence is documented in:

- `completion-evidence/architecture-inventory.md`
- `completion-evidence/test-and-quality-baseline.md`
- `completion-evidence/final-acceptance-report.md`
- `completion-evidence/packaging-and-signing-baseline.md`

iOS evidence is documented in:

- `completion-evidence/ios/architecture-inventory.md`
- `completion-evidence/ios/test-and-quality-baseline.md`
- `completion-evidence/ios/final-acceptance-report.md`
- `completion-evidence/ios/packaging-and-signing-baseline.md`

## Remaining Work

### App Targets

Add product app targets before claiming app-level release readiness:

- macOS app bundle target;
- iOS app target;
- app lifecycle integration;
- UI and accessibility surface.

### Archive And Distribution

Complete archive/export workflows and evidence for:

- macOS archive and notarization;
- iOS archive and App Store/TestFlight distribution;
- signing identities;
- entitlements;
- provisioning profiles;
- checksums and release manifests.

### Platform Validation

Verify:

- iOS simulator matrix;
- iOS physical-device matrix;
- macOS install, upgrade, removal, and launch behavior;
- accessibility audits;
- performance budgets;
- privacy and support documentation.

### Final Release Judgment

The repository may not move beyond the current blocked release status until app targets, distribution configuration, signing inputs, archive/export workflows, platform validation, hosted protections, and owner-controlled approvals are complete.
