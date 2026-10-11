> Historical reference retained from the pre-SDK Apple baseline. For SDK 1.0.0, current semantic authority is ASH-Pattern-System 1.0.0-rc.3 at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8. Current public-contract decisions override conflicting retained prose; see repository-root docs/sdk-authority-and-conformance.md.

# RecoveryEngine Contract — implementation contract (9D Research Baseline)

## Purpose

The `RecoveryEngine` module implements deterministic recovery, fallback, containment, and safe-halt behavior for the ASH Pattern System. It consumes state classifications and diagnostics from `StateModel` and executes the appropriate recovery action — all grounded in the full 9-dimensional research baseline.

## Canonical responsibility

The `RecoveryEngine` module is the single authority for:

- executing recovery actions (codeword-based normalization, codeword-based correction)
- selecting fallback states from the canonical fallback-policy registry
- entering and managing containment mode
- entering safe halt
- producing recovery, fallback, containment, and safe-halt diagnostics
- enforcing monotonic escalation

## Required inputs

- `StateValidityDiagnostic` from StateModel
- `SystemStateClass` from StateModel
- `RecoveryCategory` from StateModel
- Access to the canonical fallback-policy registry
- Access to the canonical codeword set `C ⊂ F2^9`

## Required outputs

- `RecoveryDiagnostic` record for every recovery/fallback action
- `ContainmentDiagnostic` record for containment entry
- `SafeHaltDiagnostic` record for safe-halt entry
- Recovered/corrected `AshState` (full 9-bit vector, when recovery succeeds)

## Required behaviors

### Recovery actions
- `NORMALIZE_STATE`: restore a transformation-compatible state to a valid configuration using the codeword structure
- `APPLY_CORRECTION`: apply a known codeword correction sequence to reach a valid state
- Post-recovery validation: re-diagnose the recovered state; must classify as STABLE
- If validation fails: escalate

### Fallback selection
- Select from the canonical fallback-policy registry (`specs/registries/fallback-policy-registry.md`)
- Deterministic ordering by `ordering_rank` then `policy_id`
- Post-selection validation: selected state must classify as STABLE
- If no valid candidate: escalate to containment
- Must not invent, guess, or heuristically select fallback states

### Containment
- Enter containment when fallback fails, propagation risk detected, or operator requests
- Restrict operations to safe subset
- Preserve diagnostic state
- Escalate to safe halt if containment boundary is breached

### Safe halt
- Enter safe halt when directed by escalation, containment breach, or operator request
- No further transitions permitted — terminal state
- Preserve full diagnostic chain for post-mortem

### Monotonic escalation
- Recovery failure → fallback → containment → safe halt
- Escalation is strictly monotonic — never de-escalate without external intervention
- Every escalation must be recorded in the diagnostic chain

## Required diagnostics

- Every recovery step must produce a diagnostic record
- No silent healing — all state mutations must be diagnosable
- Diagnostics must conform to `diagnostic-schema.md`
- Rule IDs must conform to `rule-id-taxonomy.md`
- Diagnostic chaining: each diagnostic must reference its parent and chain root

## Invariants

1. Recovery is deterministic — same inputs produce same recovery outcome
2. Escalation is monotonic — severity never decreases without external intervention
3. No silent healing — every recovery action produces a diagnostic
4. Fallback is registry-driven — no ad hoc fallback selection
5. Safe halt is terminal — no transitions from SAFE_HALT
6. Recovery operates on full 9-bit states — no decomposition into core + derived bit

## Prohibited shortcuts

- Must not silently heal without producing diagnostics
- Must not skip containment when specifications require it
- Must not select fallback states outside the canonical registry
- Must not allow transitions from SAFE_HALT
- Must not decompose recovery into 8-bit core operations plus control-bit re-derivation
- Must not assume a specific exhaustive codeword set if research-baseline closure is pending

## Relation to other contracts and specifications

- `state-model-contract.md` — provides classification and diagnostics
- `recoverability-semantics.pseudo.md` — recovery category definitions
- `recovery-fallback-semantics.pseudo.md` — algorithmic recovery/fallback flow
- `containment-safe-failure-semantics.pseudo.md` — containment and safe-halt behavior
- `fallback-policy-registry.md` — canonical registry for fallback selection
- `codeword-set.pseudo.md` — codeword structure for normalization/correction
- `diagnostics-module-contract.md` — schema and taxonomy conformance
