# Conformance And Release Status

## Semantic Coverage

The Mac/iOS edition maps all nine APS semantic modules to native Swift services. The detailed mapping lives in `completion-evidence/architecture-inventory.md` and `completion-evidence/ios/architecture-inventory.md`.

## Verification Evidence

The current evidence records:

- 512 well-formed realm states;
- 32 orbit representatives;
- 512 canonical realm identifiers;
- 8,192 state/codeword transformations;
- exact codeword signatures, transition identifiers, orbit identifiers, and public-record JSON round trips;
- SwiftPM release build and test runs;
- Xcode package-scheme builds for generic macOS and iOS.

## Current Judgment

Blocked for signed platform release.

Release remains blocked by:

- missing macOS and iOS app targets;
- missing signing, entitlements, provisioning, archive/export, notarization, App Store, and TestFlight evidence;
- missing iOS simulator and physical-device matrices;
- missing macOS install, upgrade, removal, and launch validation;
- missing accessibility audits and performance budgets;
- inactive hosted branch protection noted in the current evidence;
- final owner-controlled approvals.
