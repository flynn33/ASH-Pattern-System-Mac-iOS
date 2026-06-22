# Target Repository Shape

## Mac/iOS Edition Structure

```text
ash-pattern-system-mac-ios/
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
│   │   ├── ASHCore/
│   │   └── ASHPatternSystem/
│   └── Tests/
│       ├── ASHCoreTests/
│       └── ASHPatternSystemTests/
├── specs/
│   ├── core/
│   ├── algorithms/
│   ├── interfaces/
│   ├── registries/
│   └── verification/
├── handoff-templates/
└── completion-evidence/
    └── ios/
```

## Structural Rules

### `docs/`

Contains repository-level Mac/iOS Edition documentation: purpose, design philosophy, repository shape, and roadmap.

### `MaciOS/`

Contains the Swift package. `Package.swift` defines the `ASHCore` and `ASHPatternSystem` library products, platform minimums, targets, and test resources.

### `MaciOS/Sources/`

Contains native Swift implementation code. `ASHCore` owns the semantic modules. `ASHPatternSystem` provides the composition root.

### `MaciOS/Tests/`

Contains XCTest coverage and canonical corpus fixtures used to verify realms, orbits, codewords, transitions, transformations, and public-record round trips.

### `specs/`

Contains APS semantic contract material bundled with this repository for implementation reference. These files describe the behavior the Swift implementation must preserve.

### `handoff-templates/`

Contains Apple platform implementation reference checklists for the active macOS and iOS target classes. Service/backend deployment is out of scope for this repository.

### `completion-evidence/`

Contains macOS completion and release-readiness evidence at the root, with iOS-specific evidence under `completion-evidence/ios/`.

## Exclusions From This Repository Shape

The Mac/iOS edition should not add unrelated platform implementations, service packaging, third-party runtime frameworks, or product claims that cannot be verified by macOS or iOS evidence.
