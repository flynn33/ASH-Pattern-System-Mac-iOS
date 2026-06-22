# iOS Implementation Checklist

## Target Class

iOS implementation of the ASH Pattern System.

## Scope

This checklist applies to the iOS surface of this repository. It covers native Swift implementation, SwiftPM and Xcode package builds, app-target release blockers, signing, App Store/TestFlight distribution, and iOS release evidence.

## Required Sections In This Repository

### 1. Target Environment

Document the specific iOS target:

- supported iOS versions;
- Swift tools version;
- app target status;
- simulator and device validation status;
- lifecycle model;
- storage and privacy boundary.

Active documents: `MaciOS/Package.swift`, `completion-evidence/ios/architecture-inventory.md`.

### 2. Semantic-Module Mapping

Map each of the 9 APS semantic modules to concrete Swift modules.

Active document: `completion-evidence/ios/architecture-inventory.md`.

### 3. Verification Inputs

Document how the iOS implementation verifies conformance:

- SwiftPM build and tests;
- Xcode package-scheme builds;
- canonical corpus fixture coverage;
- simulator and physical-device blockers;
- protected-surface verification.

Active document: `completion-evidence/ios/test-and-quality-baseline.md`.

### 4. Diagnostics Integration

Document how diagnostics are represented and validated in the Swift core:

- diagnostic model types;
- schema and taxonomy conformance;
- chain integrity;
- lifecycle constraints once an app target exists.

Active evidence: Swift tests under `MaciOS/Tests/ASHCoreTests/`.

### 5. Materialization Boundary

Document how the planner/emitter boundary is respected:

- where planning occurs;
- where descriptor emission occurs;
- how the boundary is enforced by Swift APIs and tests.

Active evidence: Swift sources and tests for `ASHGenerationPlanner` and `ASHArtifactEmitter`.

### 6. Packaging / Build / Deployment Decisions

Document iOS-specific decisions:

- SwiftPM package layout;
- Xcode package scheme;
- app target status;
- signing, entitlements, and provisioning status;
- archive/export workflow status;
- App Store and TestFlight status;
- install, upgrade, and removal validation.

Active documents: `completion-evidence/ios/packaging-and-signing-baseline.md`, `completion-evidence/ios/final-acceptance-report.md`.

### 7. Performance / Resource Constraints

Document iOS-specific constraints:

- memory behavior;
- startup time;
- battery and thermal behavior after an app target exists;
- storage behavior;
- offline operation requirements if applicable.

### 8. Caveat / Deviation Tracking

Maintain evidence for iOS limitations and release blockers.

Active documents: `completion-evidence/ios/finding-register.json`, `completion-evidence/ios/final-acceptance-report.md`.

### 9. Proof-Of-Conformance Deliverables

Produce the deliverables listed in `common-platform-handoff-requirements.md` before the iOS product can move beyond its current blocked release status.
