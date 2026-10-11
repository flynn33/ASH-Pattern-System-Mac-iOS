> Historical completion receipt from the pre-SDK Apple baseline at 5f15dc8acffc32f29b2397bd557df6482987699c. Its original application-readiness verdict and evidence remain unchanged. Current SDK 1.0.0 source/artifact acceptance is recorded separately in repository-root docs/sdk-acceptance.md and the final release manifests.

# Feature Inventory

## Implemented Native Surfaces

- State representation for full 9-bit `ASHState`
- Canonical 16-member codeword set
- Canonical 512-state default state space
- Realm encoding using `APS-REALM-###`
- Deterministic codeword transition registry
- Topology generation over codeword branches
- Axiom evaluation
- Recovery, containment, and safe-halt diagnostics
- Generation planning and artifact description emission
- Native implementation conformance tests for dependencies, imports, and source artifact types

## Not Present In This Repository State

- macOS app user interface
- iOS app user interface
- Accessibility validation target
- Localization resources
- App storage or migration layer
- App signing, notarization, App Store, or TestFlight artifacts
- Clean install, upgrade, migration, and uninstall evidence
- SBOM or release manifest for platform binaries
