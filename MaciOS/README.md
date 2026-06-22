# Mac/iOS ASH Pattern System

This Swift package implements the Mac/iOS edition of the ASH Pattern System as an Apple-native foundation layer.

The package is intentionally independent of app targets and product UI. It focuses on APS semantic behavior for macOS and iOS consumers.

## Package

- Package name: `MaciOS`
- Swift tools version: 5.10
- Platforms: iOS 16+, macOS 14+
- External package dependencies: none

## Products

- `ASHCore`: ASH domain models and semantic services.
- `ASHPatternSystem`: orchestration layer that composes `ASHCore` into a deterministic bootstrap pipeline.

## Semantic Modules

`ASHCore` implements:

- `ASHStateModel`
- `ASHAxiomEvaluator`
- `ASHTransitionRegistry`
- `ASHTopologyGenerator`
- `ASHRealmEncoder`
- `ASHGenerationPlanner`
- `ASHArtifactEmitter`
- `ASHDiagnosticsModule`
- `ASHRecoveryEngine`

## Native Boundary

- Source language: Swift only.
- Apple frameworks/libraries: Foundation and XCTest in the current package.
- SwiftUI, Combine, SwiftData, Core Data, and other Apple frameworks may be used by future app/product layers when needed.
- Neutral artifacts: `.json` and `.md` are allowed.
- Third-party package dependencies are not allowed in this base layer.

This keeps the APS semantic implementation separated from app UI, signing, distribution, and runtime product concerns.

## API

- Engine class: `ASHPatternSystemEngine`
- Bootstrap report: `ASHPatternSystemBootstrapReport`
- Configuration: `ASHPatternSystemEngineConfiguration`

```swift
import ASHPatternSystem

let engine = ASHPatternSystemEngine()
let report = engine.bootstrap()
```

## Build And Test

```bash
swift package --package-path MaciOS dump-package
swift build --package-path MaciOS -c release
swift test --package-path MaciOS
```

## Release Boundary

The package provides Swift libraries and tests. It does not currently provide macOS or iOS app targets, signing configuration, archive/export workflows, notarization, App Store, or TestFlight distribution evidence.
