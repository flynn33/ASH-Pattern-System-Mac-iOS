# ASH Pattern System - Mac/iOS Edition

This wiki documents the Mac/iOS edition of the ASH Pattern System.

The Mac/iOS edition provides an Apple-native Swift package with `ASHCore` and `ASHPatternSystem` library products, SwiftPM and Xcode package-scheme build evidence, canonical corpus tests, and release-readiness evidence for macOS and iOS targets.

## Current Status

Blocked for signed platform release.

The Swift package semantic core is implemented, but the repository still requires app targets, archive/export workflows, signing inputs, notarization, App Store/TestFlight distribution evidence, simulator/device matrices, accessibility validation, install/upgrade/removal validation, hosted protections, and final owner-controlled release approval.

## Start Here

| If you need to... | Open this page |
|---|---|
| Understand the platform package | [Architecture](Architecture) |
| Build and test the package | [Build and Test](Build-and-Test) |
| Review conformance and release blockers | [Conformance and Release Status](Conformance-and-Release-Status) |
| Understand APS contract layers used by the package | [Specification Layers](Specification-Layers) |
| Review recovery, fallback, containment, and safe halt | [Recovery and Safety Semantics](Recovery-and-Safety-Semantics) |
| Review contracts and verification requirements | [Contracts and Verification](Contracts-and-Verification) |
| Review repository checks | [Governance and Checks](Governance-and-Repository-Checks) |
| Review platform implementation checklists | [Platform Implementation Guide](Platform-Implementation-Guide) |
| Maintain this wiki | [Wiki Maintenance Playbook](Wiki-Maintenance-Playbook) |

## Repository Areas

- `MaciOS/Sources/` - Swift semantic core and package orchestration code.
- `MaciOS/Tests/` - XCTest coverage and canonical corpus fixtures.
- `MaciOS/Package.swift` - Swift package manifest for iOS 16+ and macOS 14+.
- `completion-evidence/` - macOS release-readiness evidence.
- `completion-evidence/ios/` - iOS release-readiness evidence.
