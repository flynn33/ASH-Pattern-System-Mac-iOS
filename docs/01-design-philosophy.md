# Design Philosophy

## Primary Principle

The Mac/iOS edition implements APS semantics with Apple-native Swift tooling while keeping platform decisions explicit, testable, and auditable.

## Governing Ideas

### 1. Semantics Before Platform Mechanics

Swift package layout, Xcode package schemes, and Apple distribution decisions must support the APS state model and recovery behavior. They must not change what the semantic modules mean.

### 2. Apple-Native Tooling

Production implementation work uses Swift 5.10, SwiftPM, Xcode package builds, Foundation, and XCTest. External package dependencies are not part of the current Swift package.

### 3. Determinism Matters

Equal inputs must produce equal semantic outputs for:

- state classification;
- normalization;
- realm and orbit identity;
- transition application;
- topology generation;
- axiom evaluation;
- generation planning;
- artifact descriptor emission.

### 4. Diagnostics Are Part Of Behavior

The Swift core must expose diagnostics that explain:

- why a state is valid or invalid;
- why a transition is accepted or rejected;
- why recovery, fallback, containment, or safe halt occurred;
- why an axiom passed, failed, or was indeterminate;
- why an emission request was accepted or blocked.

Silent correction and silent failure are not acceptable behavior.

### 5. Planning Before Materialization

`ASHGenerationPlanner` produces an inspectable plan before any output is materialized. `ASHArtifactEmitter` consumes that plan and produces traceable descriptors. The current Swift package does not provide app-bundle materialization.

### 6. Fail Closed On Missing Release Evidence

If archive, signing, notarization, App Store, TestFlight, accessibility, device, simulator, install, upgrade, or removal evidence is missing, the Mac/iOS edition remains blocked for signed platform release.

### 7. Platform Decisions Stay Local

Apple-specific choices, such as Swift tools version, platform minimums, package products, XCTest layout, and Xcode build destinations, are documented as implementation decisions for this edition. They do not redefine APS semantics.

## Design Test

A design decision is aligned only if it preserves APS behavior, fits the Apple-native architecture, and can be verified through code, tests, or release evidence.
