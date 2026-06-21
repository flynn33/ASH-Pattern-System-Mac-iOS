# Packaging And Signing Baseline

## Current State

The repository currently contains a Swift package with library products only:

- `ASHCore`
- `ASHPatternSystem`

No Xcode app project, app bundle target, archive scheme, signing configuration, entitlements file, installer package, notarization profile, App Store Connect configuration, or TestFlight artifact is present in this repository state.

## Verified

- Swift package release build passes locally with `swift build --package-path MaciOS -c release`.
- Swift package tests pass locally with `swift test --package-path MaciOS`.
- Xcode package scheme `ASHCore` builds for generic macOS.
- Xcode package scheme `ASHPatternSystem` builds for generic macOS.

## Not Verified

- macOS archive
- macOS signing
- macOS notarization
- iOS archive
- iOS signing
- App Store Connect upload
- TestFlight distribution
- Clean install, launch, upgrade, migration, and removal
