# Architecture

The Mac/iOS edition targets Apple-platform Swift consumers on iOS 16+ and macOS 14+.

## Core Shape

- Swift 5.10 package named `MaciOS`.
- Library products: `ASHCore` and `ASHPatternSystem`.
- No external package dependencies.
- SwiftPM and Xcode package-scheme build paths.
- Canonical corpus fixtures bundled with tests.

## Implemented Modules

- `ASHStateModel`
- `ASHRecoveryEngine`
- `ASHRealmEncoder`
- `ASHTransitionRegistry`
- `ASHTopologyGenerator`
- `ASHAxiomEvaluator`
- `ASHGenerationPlanner`
- `ASHArtifactEmitter`
- `ASHDiagnosticsModule`

## Composition Root

`ASHPatternSystemEngine` composes the semantic modules into a deterministic bootstrap pipeline for native platform consumers.

## Release Boundary

The repository currently provides Swift libraries and tests. macOS and iOS app targets, signing, entitlements, provisioning, archive/export workflows, notarization, App Store, and TestFlight distribution remain open release gates.
