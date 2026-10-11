> Historical completion receipt from the pre-SDK Apple baseline at 5f15dc8acffc32f29b2397bd557df6482987699c. Its original application-readiness verdict and evidence remain unchanged. Current SDK 1.0.0 source/artifact acceptance is recorded separately in repository-root docs/sdk-acceptance.md and the final release manifests.

# Security Baseline

## Local Checks

- Attribution guard check: PASS
- Dependency check: PASS by package inspection; no external Swift package dependencies are declared.
- Protected-surface diff: no working-tree changes under `.github` or `governance`.
- Protected-surface verifier: PASS

## Protected File Hashes

Protected item content hashes are recorded in `completion-evidence/protected-surface-baseline.json`.

## Unverified Areas

- Server-side branch protection and ruleset state
- Signing certificate and provisioning profile handling
- Runtime sandbox entitlements
- macOS hardened runtime and notarization
- App Store privacy manifest review
