# Recovery and safety semantics — 1.0.0

All 512 states are structurally valid and normalize without realm mutation. Operational classification requires a validated context: STABLE, CORRECTABLE, UNSTABLE, DEGRADED, CONTAINED, FAILED and SAFE_HALT remain distinct. Multiple unselected reachable targets block recovery; no hidden target heuristic is used.

Correction applies the selected canonical codeword and reassesses immediately. Replacement fallback uses explicit ordered policy evidence, records attempted candidate and failed post assessment, and escalates when no validated replacement exists. Containment restricts transitions while allowing diagnostics/inspection/external-resolution recording. Prevented attempts do not prove breach; inconsistent observations are rejected. Confirmed propagation despite restrictions freezes terminal SAFE_HALT with the full chain.

Snapshots expose full canonical containment/halt wrappers, original/action records, once-stored times and immutable terminal data. Every subsequent mutation entry returns the same frozen snapshot. Current context always supports containment, so the special UNRESOLVABLE_BLOCKED_RECOVERY no-containment trigger is refused; operator/policy halt remains available. The SDK does not terminate the host process.

[Lifecycle/API](https://github.com/flynn33/ASH-Pattern-System-Mac-iOS/blob/v1.0.0/docs/sdk-api-and-lifecycle.md) and [canonical authority](https://github.com/flynn33/ASH-Pattern-System-Mac-iOS/blob/v1.0.0/docs/sdk-authority-and-conformance.md) describe exact policy and evidence boundaries.
