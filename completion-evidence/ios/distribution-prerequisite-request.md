> Historical completion receipt from the pre-SDK Apple baseline at 5f15dc8acffc32f29b2397bd557df6482987699c. Its original application-readiness verdict and evidence remain unchanged. Current SDK 1.0.0-rc.1 source/artifact acceptance is recorded separately in repository-root docs/sdk-acceptance.md and the final release manifests.

# iOS Distribution Prerequisite Request

The repository currently contains Swift package products only. A signed iOS release cannot be produced from this checkout until the app and distribution surfaces below are defined.

## Required iOS Decisions

- Bundle identifier for the iOS application target.
- Team identifier and provisioning profile strategy.
- Device capability declarations and entitlement requirements.
- App Store Connect access method for upload and TestFlight distribution.
- Privacy declarations and required usage-description strings.
- TestFlight group or physical-device validation matrix.
- Supported iOS version floor and device families.

## Required Repository Changes

- Add an iOS app target or Xcode project/workspace that consumes the existing Swift package products.
- Add a release archive scheme for the iOS target.
- Add entitlements and signing settings appropriate to App Store distribution.
- Add documented archive, export, signing, upload, and TestFlight verification commands.
- Add release artifact manifest generation for produced archives and exported packages.
