# Mac/iOS ASH Pattern System

This package implements the Mac/iOS **ASH Pattern System** as a standalone foundation layer.

It is intentionally independent of product/runtime frameworks and focuses only on canonical ASH behavior.

## Targets

- `ASHCore`: ASH domain models and services (state model, axiom evaluation, transition registry, topology generation).
- `ASHPatternSystem`: orchestration layer (`ASHPatternSystemEngine`) that composes `ASHCore` into a deterministic bootstrap pipeline.

## Native Boundary

- Source language: Swift only.
- Frameworks/libraries: Apple-native only (for example: Foundation, SwiftUI, Combine, SwiftData, CoreData, XCTest).
- Neutral artifacts: `.json` and `.md` are allowed.
- Third-party package dependencies are not allowed in this base layer.

This keeps the ASH Pattern System implementation cleanly separated from any product layer and runtime framework layer.

## ASH Pattern System API

- Engine class: `ASHPatternSystemEngine`
- Bootstrap report: `ASHPatternSystemBootstrapReport`
- Configuration: `ASHPatternSystemEngineConfiguration`

```swift
import ASHPatternSystem

let engine = ASHPatternSystemEngine()
let report = engine.bootstrap()
```

## Platforms

- iOS 16+
- macOS 14+
