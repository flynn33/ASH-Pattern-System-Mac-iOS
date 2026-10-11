> Historical completion receipt from the pre-SDK Apple baseline at 5f15dc8acffc32f29b2397bd557df6482987699c. Its original application-readiness verdict and evidence remain unchanged. Current SDK 1.0.0-rc.1 source/artifact acceptance is recorded separately in repository-root docs/sdk-acceptance.md and the final release manifests.

# Canonical Conformance Gap Analysis

## Remediated In This Pass

- Default `ASHStateModel` now treats all 512 well-formed 9-bit states as valid realms.
- Realm encoding now emits `APS-REALM-000` through `APS-REALM-511`.
- Transition coverage now proves 8,192 state/codeword applications across the default model.
- Executable tests now cover exact canonical codeword signatures, transition identifiers, orbit identifiers, and public-record JSON round trips.
- Canonical reference assets are vendored as test fixtures and decoded by the conformance suite.
- Restricted valid-state behavior remains available for operational recovery tests without replacing the canonical default.

## Remaining Gaps

- No iOS binary packaging or signing evidence exists.
- No iOS simulator, physical-device, App Store, or TestFlight validation was run in this pass.
- No platform release tag exists locally.
