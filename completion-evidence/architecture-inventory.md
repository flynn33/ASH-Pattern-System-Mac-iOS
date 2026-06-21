# Architecture Inventory

## Package

- Package name: `MaciOS`
- Tools version: Swift 5.10
- Platforms: iOS 16.0, macOS 14.0
- Products: `ASHCore`, `ASHPatternSystem`
- External package dependencies: none

## Native Modules

| Canonical module | Native implementation |
|---|---|
| `StateModel` | `MaciOS/Sources/ASHCore/Services/ASHStateModel.swift` |
| `RecoveryEngine` | `MaciOS/Sources/ASHCore/Services/ASHRecoveryEngine.swift` |
| `RealmEncoder` | `MaciOS/Sources/ASHCore/Services/ASHRealmEncoder.swift` |
| `TransitionRegistry` | `MaciOS/Sources/ASHCore/Services/ASHTransitionRegistry.swift` |
| `TopologyGenerator` | `MaciOS/Sources/ASHCore/Services/ASHTopologyGenerator.swift` |
| `AxiomEvaluator` | `MaciOS/Sources/ASHCore/Services/ASHAxiomEvaluator.swift` |
| `GenerationPlanner` | `MaciOS/Sources/ASHCore/Services/ASHGenerationPlanner.swift` |
| `ArtifactEmitter` | `MaciOS/Sources/ASHCore/Services/ASHArtifactEmitter.swift` |
| `Diagnostics` | `MaciOS/Sources/ASHCore/Services/ASHDiagnosticsModule.swift` |

## Composition Root

`MaciOS/Sources/ASHPatternSystem/ASHPatternSystemEngine.swift` wires `ASHStateModel`, `ASHAxiomEvaluator`, `ASHTransitionRegistry`, and `ASHTopologyGenerator` for native platform consumers.

## Boundary Notes

The package remains library-only. No app bundle, Xcode app target, signing configuration, entitlements, installer, TestFlight configuration, or notarization profile is present in this repository state.
