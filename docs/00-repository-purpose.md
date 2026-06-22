# Repository Purpose

## What This Repository Is

This repository is the Mac/iOS edition of the ASH Pattern System. It contains a Swift package implementation, Apple-platform conformance evidence, and release-readiness documentation for macOS and iOS targets.

Its job is to turn the APS semantic contract into an Apple-native Swift implementation that can be built, tested, packaged, and audited with SwiftPM and Xcode tooling.

## What This Repository Must Accomplish

The Mac/iOS edition must make the following explicit:

- how each APS semantic module is represented in Swift;
- how 9-bit state, codewords, transitions, diagnostics, recovery, topology, axiom evaluation, planning, and emission are implemented;
- how deterministic behavior is verified by Swift tests and canonical corpus fixtures;
- how SwiftPM and Xcode package-scheme builds are run;
- where release blockers remain for app targets, signing, notarization, App Store, TestFlight, accessibility, installation, and owner approval;
- which platform decisions are local to this Apple-platform edition.

## What This Repository Is Not For

This repository is not a neutral design-only package. It is not the place to describe every possible language, operating system, runtime, or package model.

Examples of concerns outside this Mac/iOS edition:

- Windows build systems;
- non-Swift production implementations;
- service deployment;
- third-party runtime frameworks;
- product claims that are not backed by macOS or iOS evidence.

## Platform Boundary

Apple-specific choices belong in this repository when they are needed to build, test, package, or validate the Mac/iOS edition.

Semantic behavior must remain consistent with the APS contract files bundled in this repository. If a platform decision conflicts with those semantics, the platform decision must be changed or recorded as an unresolved release blocker.

## Success Condition

A reader should be able to understand how the Mac/iOS edition is built, how its semantic modules are wired, how its tests map to APS behavior, and why the current package is or is not ready for signed release.
