> Historical reference retained from the pre-SDK Apple baseline. For SDK 1.0.0-rc.1, current semantic authority is ASH-Pattern-System 1.0.0-rc.3 at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8. Current public-contract decisions override conflicting retained prose; see repository-root docs/sdk-authority-and-conformance.md.

# Recoverability Semantics — canonical specification (Research Baseline)

> **Rewritten in R2 — State/Recovery Realignment.**
> Recovery categories are now expressed in full 9-bit state terms using codeword-based correction, not 8+1 control-bit re-derivation.

## Purpose

This specification defines the **recoverability layer** of the ASH Pattern System.

Recoverability determines the deterministic mapping from each system-state class to the **allowed recovery category**. It answers: given the current system-state classification, what category of recovery action is permitted, required, or forbidden?

## Recovery categories

```text
ENUM RecoveryCategory
    NO_ACTION
    NORMALIZE_STATE
    APPLY_CORRECTION
    FALLBACK_REQUIRED
    CONTAINMENT_REQUIRED
    ESCALATION_REQUIRED
    TERMINAL_NO_RECOVERY
END ENUM
```

### NO_ACTION
- **Applies to**: `STABLE`
- **Meaning**: The system is healthy. No recovery action is needed.

### NORMALIZE_STATE
- **Applies to**: `UNSTABLE`
- **Meaning**: The state is transformation-compatible but not in a recognized valid configuration. Recovery consists of restoring the state to a valid configuration using the codeword structure.
- **Preconditions**: State is `TRANSFORMATION_COMPATIBLE`. A normalization path exists.
- **Blocked when**: Codeword set is not fully specified, preventing normalization.

### APPLY_CORRECTION
- **Applies to**: `CORRECTABLE`
- **Meaning**: The state can be corrected to a valid state through a known codeword correction sequence.
- **Preconditions**: A specific correction path is known. The correction produces a `VALID` state.
- **Postconditions**: After correction, the state must classify as `STABLE`.

### FALLBACK_REQUIRED
- **Applies to**: `DEGRADED`
- **Meaning**: The state is transformation-incompatible or correction is ambiguous. Select a known-good fallback state from the fallback-policy registry.
- **Blocked when**: No fallback-policy registry is available, or registry contains no candidates. Escalate to containment.

### CONTAINMENT_REQUIRED
- **Applies to**: `CONTAINED`
- **Meaning**: Restrict operations to prevent error propagation. Await external resolution.
- **Escalation**: If containment boundary is breached, escalate to `SAFE_HALT`.

### ESCALATION_REQUIRED
- **Applies to**: `FAILED`
- **Meaning**: No automated recovery path exists. Escalate to external authority.

### TERMINAL_NO_RECOVERY
- **Applies to**: `SAFE_HALT`
- **Meaning**: The system has already halted. No further transitions or recovery actions.

## Deterministic mapping

```text
FUNCTION classify_recoverability(state_class: SystemStateClass) -> RecoveryCategory
    SWITCH state_class
        CASE STABLE:                RETURN NO_ACTION
        CASE UNSTABLE:              RETURN NORMALIZE_STATE
        CASE CORRECTABLE:           RETURN APPLY_CORRECTION
        CASE DEGRADED:              RETURN FALLBACK_REQUIRED
        CASE CONTAINED:             RETURN CONTAINMENT_REQUIRED
        CASE FAILED:                RETURN ESCALATION_REQUIRED
        CASE SAFE_HALT:             RETURN TERMINAL_NO_RECOVERY
    END SWITCH
END FUNCTION
```

## Blocked recovery conditions

| Recovery Category | Blocked When | Fallback Behavior |
|---|---|---|
| `NORMALIZE_STATE` | Codeword set not fully specified | Normalization is `BLOCKED`; escalate to containment |
| `APPLY_CORRECTION` | Correction path not computable | Escalate to `FALLBACK_REQUIRED` |
| `FALLBACK_REQUIRED` | No registry or no candidates | Escalate to `CONTAINMENT_REQUIRED` |
| `CONTAINMENT_REQUIRED` | Containment boundary breached | Escalate to `TERMINAL_NO_RECOVERY` |
| `ESCALATION_REQUIRED` | No external authority reachable | Escalate to `TERMINAL_NO_RECOVERY` |

## Invariants

1. **Determinism** — the same system-state class always maps to the same recovery category
2. **Completeness** — every system-state class has a defined recovery category
3. **Monotonic escalation** — blocked recovery always escalates to a more severe category
4. **No silent recovery** — every recovery action must produce a diagnostic record
5. **Finality** — `TERMINAL_NO_RECOVERY` is the completed terminal state
6. **No 8+1 dependency** — recovery categories are expressed in full 9-bit state terms

## Relation to other specifications

- **system-state-classification.pseudo.md** — provides the system-state class that maps to a recovery category
- **recovery-fallback-semantics.pseudo.md** — implements the algorithmic details of correction, fallback, and escalation
- **containment-safe-failure-semantics.pseudo.md** — implements containment and safe-halt behavior
- **state-validity-diagnostics.pseudo.md** — provides diagnostics that inform classification and recovery
- **codeword-set.pseudo.md** — provides the codeword structure used for normalization and correction
- **state-admissibility.pseudo.md** — provides admissibility classification
