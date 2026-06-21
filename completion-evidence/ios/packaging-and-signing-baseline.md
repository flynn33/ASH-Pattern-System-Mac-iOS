# iOS Packaging And Signing Baseline

## Current State

The repository currently contains a Swift package with library products only:

- `ASHCore`
- `ASHPatternSystem`

No Xcode app project, iOS app bundle target, archive scheme, signing configuration, entitlements file, App Store Connect configuration, or TestFlight artifact is present in this repository state.

## Verified

- Swift package release build passes locally with `swift build --package-path MaciOS -c release`.
- Swift package tests pass locally with `swift test --package-path MaciOS`.
- Xcode package scheme `ASHCore` builds for generic iOS.
- Xcode package scheme `ASHPatternSystem` builds for generic iOS.

## Not Verified

- iOS archive
- iOS signing
- App Store Connect upload
- TestFlight distribution
- Clean install, launch, upgrade, migration, and removal
