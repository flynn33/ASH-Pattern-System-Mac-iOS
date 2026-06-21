# Distribution Prerequisite Request

The repository currently contains Swift package products only. A signed platform release cannot be produced from this checkout until the app and distribution surfaces below are defined.

## Required macOS Decisions

- Distribution path: Developer ID or Mac App Store.
- Bundle identifier for the macOS application target.
- Team identifier and signing identity to use for release archives.
- Entitlement profile: sandboxing, hardened runtime, network access, file access, and automation permissions.
- Notarization credential method if Developer ID distribution is selected.
- Installer format, if an installer is required.
- Clean-machine validation target and supported macOS version floor.

## Required iOS Decisions

- Bundle identifier for the iOS application target.
- Team identifier and provisioning profile strategy.
- Device capability declarations and entitlement requirements.
- App Store Connect access method for upload and TestFlight distribution.
- Privacy declarations and required usage-description strings.
- TestFlight group or physical-device validation matrix.

## Required Repository Changes

- Add an app target or Xcode project/workspace that consumes the existing Swift package products.
- Add release archive schemes for the selected platform targets.
- Add entitlements and signing settings appropriate to the selected distribution paths.
- Add documented archive, export, signing, and distribution verification commands.
- Add release artifact manifest generation for produced archives and packages.
