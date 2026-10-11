> Historical reference retained from the pre-SDK Apple baseline. For SDK 1.0.0-rc.1, current semantic authority is ASH-Pattern-System 1.0.0-rc.3 at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8. Current public-contract decisions override conflicting retained prose; see repository-root docs/sdk-authority-and-conformance.md.

# System-State Classification — canonical specification (Research Baseline)

> **Rewritten in R2 — State/Recovery Realignment.**
> Classification is now based on full 9-bit state diagnostics and codeword-structure compatibility, not on 8-bit core admissibility + control-bit mismatch.

## Purpose

This specification defines the **canonical system-state classes** for the ASH Pattern System.

Classification answers: given a state-validity diagnostic for a full 9-bit state, what should the system do about it?

## Classification criteria

A system-state class is determined by evaluating the state-validity diagnostic (`StateValidityDiagnostic`) which provides:

1. **Admissibility status** — VALID, TRANSFORMATION_COMPATIBLE, TRANSFORMATION_INCOMPATIBLE, or UNCLASSIFIED
2. **Transformation compatibility** — COMPATIBLE, INCOMPATIBLE, or UNKNOWN
3. **Normalization status** — ALREADY_VALID, NORMALIZABLE, NOT_NORMALIZABLE, or BLOCKED

Additional conditions from runtime context:

4. **Containment status** — has the system entered containment mode?
5. **Halt status** — has the system entered safe halt?

## Canonical state classes

```text
ENUM SystemStateClass
    STABLE
    UNSTABLE
    CORRECTABLE
    DEGRADED
    CONTAINED
    FAILED
    SAFE_HALT
END ENUM
```

### STABLE
The system is in normal operating condition.
- Admissibility: `VALID`
- Normalization: `ALREADY_VALID`
- No recovery action required

### UNSTABLE
The state is transformation-compatible but not currently in a recognized valid configuration.
- Admissibility: `TRANSFORMATION_COMPATIBLE`
- Normalization: `NORMALIZABLE`
- Recovery: restore to valid state via codeword-based normalization

### CORRECTABLE
The state can be corrected to a valid state through codeword operations.
- Admissibility: `TRANSFORMATION_COMPATIBLE`
- The specific correction path is known
- Recovery: apply codeword correction sequence to reach a valid state

### DEGRADED
The state is transformation-incompatible or correction is ambiguous. Fallback is required.
- Admissibility: `TRANSFORMATION_INCOMPATIBLE` or correction is ambiguous
- Normalization: `NOT_NORMALIZABLE` or no unique correction path
- Recovery: select a known-good fallback state from the fallback-policy registry

### CONTAINED
The system has entered containment to prevent error propagation.
- Entry: DEGRADED where fallback is unavailable, propagation risk detected, or operator request
- Behavior: restricted operations, awaiting resolution
- May escalate to SAFE_HALT if containment boundary is breached

### FAILED
The state is not recoverable through any automated path. Escalation required.
- Admissibility: `TRANSFORMATION_INCOMPATIBLE` with no fallback available
- Or: containment has failed to resolve the condition
- System is still running but in an unrecoverable error state

### SAFE_HALT
The system has deliberately halted in a known-safe terminal state.
- No further transitions permitted
- Diagnostic state preserved for post-mortem
- Distinct from FAILED: SAFE_HALT is an intentional terminal action

## Deterministic class-to-action mapping

| System-State Class | Action Category | Description |
|---|---|---|
| `STABLE` | `NO_ACTION` | Normal operation |
| `UNSTABLE` | `NORMALIZE_STATE` | Restore to valid state via codeword-based normalization |
| `CORRECTABLE` | `APPLY_CORRECTION` | Apply known codeword correction sequence |
| `DEGRADED` | `FALLBACK_REQUIRED` | Select known-good state from fallback-policy registry |
| `CONTAINED` | `CONTAINMENT_REQUIRED` | Restrict operations; await resolution |
| `FAILED` | `ESCALATION_REQUIRED` | Escalate to external authority |
| `SAFE_HALT` | `TERMINAL_NO_RECOVERY` | Already halted; no further transitions |

## Pseudocode

```text
FUNCTION classify_system_state(diagnostic: StateValidityDiagnostic, context: SystemContext) -> SystemStateClass

    -- Check terminal states first
    IF context.is_in_safe_halt THEN
        RETURN SAFE_HALT
    END IF

    IF context.is_in_containment THEN
        RETURN CONTAINED
    END IF

    -- Classify from full-state diagnostic
    IF diagnostic.admissibility_status == VALID AND diagnostic.normalization_status == ALREADY_VALID THEN
        RETURN STABLE
    END IF

    IF diagnostic.admissibility_status == TRANSFORMATION_COMPATIBLE THEN
        IF diagnostic.normalization_status == NORMALIZABLE THEN
            -- Determine if specific correction is known
            IF correction_path_is_known(diagnostic) THEN
                RETURN CORRECTABLE
            ELSE
                RETURN UNSTABLE
            END IF
        END IF
    END IF

    IF diagnostic.admissibility_status == TRANSFORMATION_INCOMPATIBLE THEN
        IF fallback_is_available(diagnostic) THEN
            RETURN DEGRADED
        ELSE
            RETURN FAILED
        END IF
    END IF

    -- Default for UNCLASSIFIED admissibility
    RETURN DEGRADED
END FUNCTION
```

## Invariants

1. **Completeness** — every state maps to exactly one system-state class
2. **Determinism** — the same diagnostic always produces the same classification
3. **Monotonic severity** — STABLE < UNSTABLE < CORRECTABLE < DEGRADED < CONTAINED < FAILED < SAFE_HALT
4. **Terminal finality** — SAFE_HALT is irrevocable
5. **No 8+1 dependency** — classification is based on full 9-bit state diagnostics

## Relation to other specifications

- **state-validity-diagnostics.pseudo.md** — provides the diagnostic that feeds classification
- **state-admissibility.pseudo.md** — provides admissibility status
- **recoverability-semantics.pseudo.md** — maps each class to its recovery category
- **recovery-fallback-semantics.pseudo.md** — implements recovery and fallback actions
- **containment-safe-failure-semantics.pseudo.md** — implements containment and safe-halt
