# Platform Implementation Guide

This page summarizes the Apple-platform implementation deliverables for the Mac/iOS edition.

## Required Deliverables

The repository should maintain:

1. module mapping evidence;
2. SwiftPM build and test evidence;
3. Xcode package-scheme build evidence for macOS and iOS;
4. diagnostics conformance evidence;
5. materialization-boundary evidence;
6. deviation and blocker evidence;
7. macOS and iOS acceptance judgments;
8. signing, archive, distribution, install, accessibility, security, and release evidence when product targets exist.

## Template Sources

- `handoff-templates/common-platform-handoff-requirements.md`
- `handoff-templates/desktop-implementation-handoff-template.md`
- `handoff-templates/mobile-implementation-handoff-template.md`
- `handoff-templates/service-implementation-handoff-template.md`

## Platform Principles

1. Templates define structure and evidence, not new APS behavior.
2. macOS and iOS release claims must be backed by platform evidence.
3. Conformance evidence must map to APS invariants and contracts.
4. Deviation and blocker records are mandatory when release evidence is missing.

## Current Boundaries

The repository currently provides Swift libraries and tests. App targets, signing, archive/export workflows, notarization, App Store/TestFlight distribution, accessibility audits, and install/device matrices remain release blockers.
