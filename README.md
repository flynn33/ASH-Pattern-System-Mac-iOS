# ASH Pattern System - Mac/iOS Edition

This repository contains the Mac/iOS edition of the ASH Pattern System. It packages the APS semantic core as an Apple-native Swift package for macOS and iOS, with SwiftPM targets, Xcode-compatible package schemes, conformance evidence, and release-readiness documentation.

## Repository Purpose

The Mac/iOS edition exists to make APS usable from supported Apple-platform code while preserving deterministic behavior, explainable diagnostics, safe failure, fallback handling, and auditable release gates.

This repository defines and maintains:

- a Swift 5.10 implementation of the nine APS semantic modules;
- a Swift package named `MaciOS`;
- library products `ASHCore` and `ASHPatternSystem`;
- tests backed by canonical corpus fixtures for realms, orbits, codewords, transitions, and transformations;
- macOS and iOS build/test evidence;
- platform conformance, packaging, signing, and release-readiness documentation.

This repository does not currently provide:

- a macOS app bundle;
- an iOS app target;
- signing identities, entitlements, provisioning profiles, or archive/export workflows;
- notarization, App Store, or TestFlight distribution evidence;
- final owner-controlled release approval.

The current acceptance reports state that the package is not accepted for signed platform release. See [completion-evidence/final-acceptance-report.md](completion-evidence/final-acceptance-report.md) and [completion-evidence/ios/final-acceptance-report.md](completion-evidence/ios/final-acceptance-report.md).

## Platform Scope

- **Package:** `MaciOS`
- **Language:** Swift 5.10
- **Products:** `ASHCore`, `ASHPatternSystem`
- **Platforms:** iOS 16+ and macOS 14+
- **Apple tooling:** SwiftPM and Xcode package schemes
- **Dependencies:** no external package dependencies

## Implemented Semantic Modules

The Apple-platform semantic core implements these APS modules:

- `StateModel`
- `RecoveryEngine`
- `RealmEncoder`
- `TransitionRegistry`
- `TopologyGenerator`
- `AxiomEvaluator`
- `GenerationPlanner`
- `ArtifactEmitter`
- `Diagnostics`

The native file mapping is documented in [completion-evidence/architecture-inventory.md](completion-evidence/architecture-inventory.md) and [completion-evidence/ios/architecture-inventory.md](completion-evidence/ios/architecture-inventory.md).

## Repository Map

```text
.
├── README.md
├── docs/
│   ├── 00-repository-purpose.md
│   ├── 01-design-philosophy.md
│   ├── 02-target-repository-shape.md
│   └── 03-design-roadmap.md
├── MaciOS/
│   ├── Package.swift
│   ├── README.md
│   ├── Sources/
│   └── Tests/
├── specs/                         # APS semantic contract files bundled for implementation reference
├── handoff-templates/              # Apple platform implementation reference checklists
└── completion-evidence/            # macOS and iOS completion and release-readiness evidence
```

## Build And Test

SwiftPM:

```bash
swift package --package-path MaciOS dump-package
swift build --package-path MaciOS -c release
swift test --package-path MaciOS
```

Xcode package-scheme builds:

```bash
xcodebuild -scheme ASHCore -destination 'generic/platform=macOS' -configuration Release build -quiet
xcodebuild -scheme ASHPatternSystem -destination 'generic/platform=macOS' -configuration Release build -quiet
xcodebuild -scheme ASHCore -destination 'generic/platform=iOS' -configuration Release build -quiet
xcodebuild -scheme ASHPatternSystem -destination 'generic/platform=iOS' -configuration Release build -quiet
```

See [completion-evidence/test-and-quality-baseline.md](completion-evidence/test-and-quality-baseline.md) and [completion-evidence/ios/test-and-quality-baseline.md](completion-evidence/ios/test-and-quality-baseline.md) for recorded verification evidence.

## Release Status

The Swift package semantic core is implemented, but signed platform release remains blocked by:

- missing macOS and iOS app targets;
- missing archive/export workflows;
- missing signing, entitlements, provisioning, notarization, App Store, and TestFlight evidence;
- missing accessibility audits;
- missing simulator, device, install, upgrade, and removal matrices;
- inactive hosted branch protection noted in the current evidence;
- final owner-controlled release approval.

## License

Copyright 2026 James Daley

This project is licensed under the Apache License, Version 2.0.
See the [LICENSE](LICENSE) file for the full terms.
