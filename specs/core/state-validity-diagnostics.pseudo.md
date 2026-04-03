# State-Validity Diagnostics — agnostic specification

## Purpose

This specification defines a **canonical diagnostic model** for ASH state validity.

Every downstream implementation must be able to produce a structured diagnostic record that explains, for any candidate state:

- whether it is valid
- why or why not
- what recovery path (if any) is available
- which specification rules were evaluated

This record is the foundation for:

- **self-healing behavior** — the system can inspect its own state and determine what to do
- **self-correcting behavior** — the system can identify correctable errors and apply fixes
- **safe-failure behavior** — the system can recognize unrecoverable states and fail gracefully
- **deterministic recovery planning** — recovery decisions are based on structured diagnostics, not heuristics
- **observability** — external monitors can inspect state health without understanding internal implementation details

## Diagnostic record

```text
TYPE StateValidityDiagnostic
    input_state              : AshStateExpanded or raw 9-element vector
    extracted_core           : Vector[8] over F2
    corrected_core           : Vector[8] over F2 or NOT_APPLICABLE
    observed_control_dimension : Bit
    expected_control_dimension : Bit or UNABLE_TO_DERIVE
    admissibility_status     : AdmissibilityStatus
    control_derivation_status : ControlDerivationStatus
    normalization_status     : NormalizationStatus
    recoverability_status    : RecoverabilityStatus
    is_valid_normalized_state : Boolean
    rule_ids                 : List of String
    notes                    : List of String
END TYPE
```

### Field definitions

#### `input_state`
The raw candidate state as received by the diagnostic function. This is the unmodified input before any extraction or derivation.

#### `extracted_core`
The 8-bit stabilizing core extracted from the input state (coordinates `b0..b7`). This is the raw, unmodified core before any correction.

#### `corrected_core`
If the extracted core is `INADMISSIBLE_CORRECTABLE`, this field contains the corrected admissible core (the nearest valid codeword). If the core is already `ADMISSIBLE` or is not correctable, this field is `NOT_APPLICABLE`.

The **corrected-core derivation rule** requires that `expected_control_dimension` be derived from `corrected_core` (not `extracted_core`) when correction applies. This ensures that the diagnostic predicts the same control value that normalization would produce.

#### `observed_control_dimension`
The value of the 9th coordinate (`b8`) as it appears in the input state.

#### `expected_control_dimension`
The derived control value that normalization would produce, determined by the **corrected-core derivation rule**:

- If the core is `ADMISSIBLE`: the value that `derive_control_bit(extracted_core)` would produce
- If the core is `INADMISSIBLE_CORRECTABLE`: the value that `derive_control_bit(corrected_core)` would produce, where `corrected_core` is the nearest admissible codeword
- If the core is `INADMISSIBLE_DETECTABLE` or `INADMISSIBLE_UNRECOVERABLE`: `UNABLE_TO_DERIVE` — control derivation is not meaningful for uncorrectable inadmissible cores because no valid recovery precondition exists

This ensures that the diagnostic predicts the same control value that `normalize_state` would produce.

#### `admissibility_status`
The result of `classify_core_admissibility(extracted_core)` as defined in `core-admissibility.pseudo.md`.

```text
ENUM AdmissibilityStatus
    ADMISSIBLE
    INADMISSIBLE_CORRECTABLE
    INADMISSIBLE_DETECTABLE
    INADMISSIBLE_UNRECOVERABLE
END ENUM
```

#### `control_derivation_status`
Whether the observed control dimension matches the expected derived value.

```text
ENUM ControlDerivationStatus
    MATCH                -- observed == expected
    MISMATCH             -- observed != expected, but expected is known
    UNABLE_TO_DERIVE     -- derivation not meaningful (uncorrectable inadmissible core or malformed input)
    DERIVATION_ERROR     -- derivation failed due to invalid input
END ENUM
```

#### `normalization_status`
Whether the state can be or has been normalized.

```text
ENUM NormalizationStatus
    ALREADY_NORMALIZED   -- core is admissible, control matches derivation
    NORMALIZABLE         -- core is admissible or correctable, control can be re-derived
    NOT_NORMALIZABLE     -- core is inadmissible beyond correction
    BLOCKED              -- normalization cannot proceed (e.g., malformed input or implementation nonconformance)
END ENUM
```

#### `recoverability_status`
The overall recovery classification of the state.

```text
ENUM RecoverabilityStatus
    STABLE               -- valid, no action needed
    UNSTABLE             -- admissible core, wrong control bit; recoverable via re-derivation
    CORRECTABLE          -- inadmissible core within correctable distance; recoverable via correction + re-derivation
    DEGRADED             -- inadmissible core, error detected but correction ambiguous; fallback required
    FAILED               -- inadmissible core, beyond reliable correction; safe failure required
END ENUM
```

#### `is_valid_normalized_state`
A boolean summary: `TRUE` if and only if:

1. `admissibility_status == ADMISSIBLE`
2. `control_derivation_status == MATCH`
3. `normalization_status == ALREADY_NORMALIZED`

#### `rule_ids`
A list of specification rule identifiers that were evaluated during diagnosis. This provides traceability back to this repository.

Example rule IDs:

- `ASH-STATE-SPACE-VALIDITY-1` — core must be structurally admissible
- `ASH-STATE-SPACE-VALIDITY-2` — control bit must be consistent with derivation rule
- `CONTROL-BIT-DERIVATION-INVARIANT-1` — derivation is deterministic
- `CORE-ADMISSIBILITY-INVARIANT-4` — inadmissible core must not be silently accepted

#### `notes`
A list of human-readable diagnostic strings providing additional context. These are not machine-parseable and are intended for developers and operators.

## Pseudocode

```text
FUNCTION diagnose_state(candidate) -> StateValidityDiagnostic
    diagnostic = new StateValidityDiagnostic()
    diagnostic.input_state = candidate
    diagnostic.rule_ids = []
    diagnostic.notes = []

    -- Step 1: Extract core and observed control
    diagnostic.extracted_core = extract_core_bits(candidate)
    diagnostic.observed_control_dimension = extract_control_bit(candidate)

    -- Step 2: Classify core admissibility and apply corrected-core derivation rule
    diagnostic.admissibility_status = classify_core_admissibility(diagnostic.extracted_core)
    diagnostic.rule_ids.append("ASH-STATE-SPACE-VALIDITY-1")

    -- Step 2a: Determine the core to use for control-bit derivation
    -- Corrected-core derivation rule: for correctable cores, derive from the corrected core
    IF diagnostic.admissibility_status == INADMISSIBLE_CORRECTABLE THEN
        diagnostic.corrected_core = correct_to_nearest_codeword(diagnostic.extracted_core)
        derivation_core = diagnostic.corrected_core
        diagnostic.notes.append("Core corrected for derivation: " + diagnostic.extracted_core + " -> " + diagnostic.corrected_core)
    ELSE
        diagnostic.corrected_core = NOT_APPLICABLE
        derivation_core = diagnostic.extracted_core
    END IF

    -- Step 3: Derive expected control bit (formula is locked: overall parity)
    IF diagnostic.admissibility_status IN [INADMISSIBLE_DETECTABLE, INADMISSIBLE_UNRECOVERABLE] THEN
        -- Core is not correctable; derivation is not meaningful for normalization
        diagnostic.control_derivation_status = UNABLE_TO_DERIVE
        diagnostic.expected_control_dimension = UNABLE_TO_DERIVE
        diagnostic.notes.append("Control derivation not meaningful: uncorrectable inadmissible core")
    ELSE
        TRY
            diagnostic.expected_control_dimension = derive_control_bit(derivation_core)

            IF diagnostic.observed_control_dimension == diagnostic.expected_control_dimension THEN
                diagnostic.control_derivation_status = MATCH
            ELSE
                diagnostic.control_derivation_status = MISMATCH
                diagnostic.notes.append("Observed control bit does not match derived value")
            END IF
        CATCH derivation_error
            diagnostic.control_derivation_status = DERIVATION_ERROR
            diagnostic.expected_control_dimension = UNABLE_TO_DERIVE
            diagnostic.notes.append("Derivation failed: " + derivation_error.message)
        END TRY
    END IF
    diagnostic.rule_ids.append("ASH-STATE-SPACE-VALIDITY-2")

    -- Step 4: Determine recoverability
    SWITCH diagnostic.admissibility_status
        CASE ADMISSIBLE:
            IF diagnostic.control_derivation_status == MATCH THEN
                diagnostic.recoverability_status = STABLE
            ELSE
                diagnostic.recoverability_status = UNSTABLE
            END IF

        CASE INADMISSIBLE_CORRECTABLE:
            diagnostic.recoverability_status = CORRECTABLE
            diagnostic.notes.append("Core is correctable to nearest codeword")

        CASE INADMISSIBLE_DETECTABLE:
            diagnostic.recoverability_status = DEGRADED
            diagnostic.notes.append("Error detected but correction is ambiguous; fallback required")

        CASE INADMISSIBLE_UNRECOVERABLE:
            diagnostic.recoverability_status = FAILED
            diagnostic.notes.append("Core is beyond reliable correction; safe failure required")
    END SWITCH

    -- Step 5: Determine normalization status
    IF diagnostic.recoverability_status == STABLE THEN
        diagnostic.normalization_status = ALREADY_NORMALIZED
    ELSE IF diagnostic.recoverability_status IN [UNSTABLE, CORRECTABLE] THEN
        IF diagnostic.control_derivation_status == DERIVATION_ERROR THEN
            diagnostic.normalization_status = BLOCKED
            diagnostic.notes.append("Cannot normalize: derivation failed due to malformed input")
        ELSE
            diagnostic.normalization_status = NORMALIZABLE
        END IF
    ELSE
        diagnostic.normalization_status = NOT_NORMALIZABLE
    END IF

    -- Step 6: Summary validity
    diagnostic.is_valid_normalized_state = (
        diagnostic.admissibility_status == ADMISSIBLE
        AND diagnostic.control_derivation_status == MATCH
        AND diagnostic.normalization_status == ALREADY_NORMALIZED
    )

    RETURN diagnostic
END FUNCTION
```

## Diagnostic completeness requirement

Every downstream implementation must be capable of producing a `StateValidityDiagnostic` for any candidate state, even when:

- the candidate state is malformed (report the malformation in notes and set appropriate status fields)
- the core is uncorrectable inadmissible (use `UNABLE_TO_DERIVE` for expected control)
- derivation fails due to implementation error (use `DERIVATION_ERROR`)

The diagnostic must never be empty, partial, or silently omitted. If diagnosis cannot be completed, the diagnostic record must explain why.

## Relation to other specifications

- **ash-state-space.pseudo.md** — defines the state structure that is being diagnosed
- **control-bit-derivation.pseudo.md** — provides the locked derivation formula (overall parity) used in step 3
- **core-admissibility.pseudo.md** — provides the locked admissibility classification (normative 16-codeword set) used in step 2
- **semantic-contracts.md** — requires that all implementations expose diagnosable state validation
