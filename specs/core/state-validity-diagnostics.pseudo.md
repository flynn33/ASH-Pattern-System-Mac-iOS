# State-Validity Diagnostics — canonical specification (Research Baseline)

> **Rewritten in R2 — State/Recovery Realignment.**
> This file now defines diagnostics for the full 9D research model.
> The previous 8+1 diagnostic structure (extracted_core, control_derivation_status, corrected_core, etc.) is superseded.

## Purpose

This specification defines the **canonical diagnostic model** for ASH state validity in the full 9-dimensional research baseline.

The Apple implementation must be able to produce a structured diagnostic record that explains, for any candidate state:

- whether it is valid
- its admissibility status relative to the codeword structure
- its transformation compatibility
- what recovery path (if any) is available
- which specification rules were evaluated

This record is the foundation for:

- **self-healing behavior** — the system can inspect its own state and determine what to do
- **self-correcting behavior** — the system can identify correctable errors and apply fixes
- **safe-failure behavior** — the system can recognize unrecoverable states and fail gracefully
- **deterministic recovery planning** — recovery decisions are based on structured diagnostics, not heuristics
- **observability** — external monitors can inspect state health

## Diagnostic record

```text
TYPE StateValidityDiagnostic
    input_state                  : Vector[9] over F2
    admissibility_status         : AdmissibilityStatus
    transformation_compatibility : TransformationCompatibility
    normalization_status         : NormalizationStatus
    recoverability_relevance     : RecoverabilityRelevance
    is_valid                     : Boolean
    orbit_info                   : OrbitInfo or NONE
    rule_ids                     : List of String
    notes                        : List of String
END TYPE
```

### Field definitions

#### `input_state`
The raw candidate state as received — a full 9-bit vector in F2^9.

#### `admissibility_status`
The result of classifying the state against the codeword structure, as defined in `state-admissibility.pseudo.md`.

```text
ENUM AdmissibilityStatus
    VALID
    TRANSFORMATION_COMPATIBLE
    TRANSFORMATION_INCOMPATIBLE
    UNCLASSIFIED
END ENUM
```

#### `transformation_compatibility`
Whether the state can participate in codeword transformations.

```text
ENUM TransformationCompatibility
    COMPATIBLE       -- state is within a codeword orbit
    INCOMPATIBLE     -- state is outside all known codeword orbits
    UNKNOWN          -- cannot determine (codeword set not fully specified)
END ENUM
```

#### `normalization_status`
Whether the state can be or has been normalized within the 9D model.

```text
ENUM NormalizationStatus
    ALREADY_VALID        -- state is valid, no normalization needed
    NORMALIZABLE         -- state can be restored to a valid state via codeword-based correction
    NOT_NORMALIZABLE     -- state cannot be restored via codeword operations
    BLOCKED              -- normalization cannot proceed (e.g., codeword set not fully specified)
END ENUM
```

#### `recoverability_relevance`
Whether the state's condition is relevant to the recovery/fallback/containment system.

```text
ENUM RecoverabilityRelevance
    NO_RECOVERY_NEEDED   -- state is valid
    RECOVERY_APPLICABLE  -- state is not valid but recovery may be possible
    FALLBACK_NEEDED      -- state requires fallback selection
    CONTAINMENT_NEEDED   -- state requires containment
    NOT_RECOVERABLE      -- no recovery path exists
END ENUM
```

#### `is_valid`
Boolean summary: `TRUE` if `admissibility_status == VALID` and `normalization_status == ALREADY_VALID`.

#### `orbit_info`
Optional information about the state's codeword orbit, if computable:
- which orbit the state belongs to
- how many states are in that orbit
- whether the orbit contains known valid states

Set to `NONE` if orbit information is not available or not applicable.

#### `rule_ids`
A list of specification rule identifiers that were evaluated during diagnosis. Must conform to the rule-ID taxonomy when the taxonomy is revalidated in R3.

#### `notes`
Human-readable diagnostic strings providing additional context.

## Pseudocode

```text
FUNCTION diagnose_state(candidate[9], codeword_set C) -> StateValidityDiagnostic
    diagnostic = new StateValidityDiagnostic()
    diagnostic.input_state = candidate
    diagnostic.rule_ids = []
    diagnostic.notes = []

    -- Step 1: Classify admissibility against codeword structure
    diagnostic.admissibility_status = classify_state_admissibility(candidate, C)

    -- Step 2: Determine transformation compatibility
    IF diagnostic.admissibility_status IN [VALID, TRANSFORMATION_COMPATIBLE] THEN
        diagnostic.transformation_compatibility = COMPATIBLE
    ELSE IF diagnostic.admissibility_status == TRANSFORMATION_INCOMPATIBLE THEN
        diagnostic.transformation_compatibility = INCOMPATIBLE
        diagnostic.notes.append("State is outside codeword orbit structure")
    ELSE
        diagnostic.transformation_compatibility = UNKNOWN
        diagnostic.notes.append("Transformation compatibility cannot be determined")
    END IF

    -- Step 3: Determine normalization status
    IF diagnostic.admissibility_status == VALID THEN
        diagnostic.normalization_status = ALREADY_VALID
    ELSE IF diagnostic.admissibility_status == TRANSFORMATION_COMPATIBLE THEN
        diagnostic.normalization_status = NORMALIZABLE
    ELSE IF diagnostic.admissibility_status == TRANSFORMATION_INCOMPATIBLE THEN
        diagnostic.normalization_status = NOT_NORMALIZABLE
    ELSE
        diagnostic.normalization_status = BLOCKED
        diagnostic.notes.append("Normalization blocked: admissibility cannot be determined")
    END IF

    -- Step 4: Determine recoverability relevance
    IF diagnostic.normalization_status == ALREADY_VALID THEN
        diagnostic.recoverability_relevance = NO_RECOVERY_NEEDED
    ELSE IF diagnostic.normalization_status == NORMALIZABLE THEN
        diagnostic.recoverability_relevance = RECOVERY_APPLICABLE
    ELSE IF diagnostic.normalization_status == NOT_NORMALIZABLE THEN
        diagnostic.recoverability_relevance = NOT_RECOVERABLE
        diagnostic.notes.append("State is not recoverable via codeword operations")
    ELSE
        diagnostic.recoverability_relevance = CONTAINMENT_NEEDED
    END IF

    -- Step 5: Compute orbit info if available
    diagnostic.orbit_info = compute_orbit_info(candidate, C)

    -- Step 6: Summary validity
    diagnostic.is_valid = (
        diagnostic.admissibility_status == VALID
        AND diagnostic.normalization_status == ALREADY_VALID
    )

    RETURN diagnostic
END FUNCTION
```

## Diagnostic completeness requirement

The Apple implementation must be capable of producing a `StateValidityDiagnostic` for any candidate 9-bit state, even when:

- The codeword set is not fully specified (use `UNCLASSIFIED` / `BLOCKED`)
- The candidate state is malformed (report in notes)
- Orbit information is not computable (use `NONE`)

The diagnostic must never be empty, partial, or silently omitted.

## Relation to other specifications

- **ash-state-space.pseudo.md** — defines the F2^9 state space being diagnosed
- **state-admissibility.pseudo.md** — provides the admissibility classification
- **codeword-set.pseudo.md** — provides the codeword structure used for classification
- **system-state-classification.pseudo.md** — consumes diagnostics to classify system state
- **recoverability-semantics.pseudo.md** — consumes diagnostics to determine recovery category
