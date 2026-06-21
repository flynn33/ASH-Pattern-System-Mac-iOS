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
