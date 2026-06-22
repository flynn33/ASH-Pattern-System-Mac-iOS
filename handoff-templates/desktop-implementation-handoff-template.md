# macOS Implementation Checklist

## Target Class

macOS implementation of the ASH Pattern System.

## Scope

This checklist applies to the macOS surface of this repository. It covers native Swift implementation, SwiftPM and Xcode package builds, app-target release blockers, signing, notarization, and macOS release evidence.

## Required Sections In This Repository

### 1. Target Environment

Document the specific macOS target:

- supported macOS versions;
- Swift tools version;
- runtime framework boundary;
- app target status;
- filesystem access model;
- concurrency and lifecycle model.

Active documents: `MaciOS/Package.swift`, `completion-evidence/architecture-inventory.md`.

### 2. Semantic-Module Mapping

Map each of the 9 APS semantic modules to concrete Swift modules.

Active document: `completion-evidence/architecture-inventory.md`.

### 3. Verification Inputs

Document how the macOS implementation verifies conformance:

- SwiftPM build and tests;
- Xcode package-scheme builds;
- canonical corpus fixture coverage;
- protected-surface verification;
- release blockers.

Active document: `completion-evidence/test-and-quality-baseline.md`.

### 4. Diagnostics Integration

Document how diagnostics are represented and validated in the Swift core:

- diagnostic model types;
- schema and taxonomy conformance;
- chain integrity;
- runtime validation behavior.

Active evidence: Swift tests under `MaciOS/Tests/ASHCoreTests/`.

### 5. Materialization Boundary

Document how the planner/emitter boundary is respected:

- where planning occurs;
- where descriptor emission occurs;
- how the boundary is enforced by Swift APIs and tests.

Active evidence: Swift sources and tests for `ASHGenerationPlanner` and `ASHArtifactEmitter`.

### 6. Packaging / Build / Deployment Decisions

Document macOS-specific decisions:

- SwiftPM package layout;
- Xcode package scheme;
- app target status;
- signing and notarization status;
- archive/export workflow status;
- install, launch, upgrade, and removal validation.

Active documents: `completion-evidence/packaging-and-signing-baseline.md`, `completion-evidence/final-acceptance-report.md`.

### 7. Performance / Resource Constraints

Document macOS-specific constraints:

- memory behavior;
- startup time;
- responsiveness requirements after a UI exists;
- storage behavior;
- offline operation requirements if applicable.

### 8. Caveat / Deviation Tracking

Maintain evidence for macOS limitations and release blockers.

Active documents: `completion-evidence/finding-register.json`, `completion-evidence/final-acceptance-report.md`.

### 9. Proof-Of-Conformance Deliverables

Produce the deliverables listed in `common-platform-handoff-requirements.md` before the macOS product can move beyond its current blocked release status.
