> Historical reference retained from the pre-SDK Apple baseline. For SDK 1.0.0-rc.1, current semantic authority is ASH-Pattern-System 1.0.0-rc.3 at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8. Current public-contract decisions override conflicting retained prose; see repository-root docs/sdk-authority-and-conformance.md.

# Recovery and Fallback Semantics — canonical specification (Research Baseline)

> **Rewritten in R2 — State/Recovery Realignment.**
> Recovery operates on full 9-bit states using codeword-based correction, not 8+1 core/control re-derivation.

## Purpose

This specification defines the **algorithmic semantics of deterministic recovery and fallback selection** for the ASH Pattern System.

Every recovery action must be deterministic, diagnosable, and policy-driven.

## Correction attempt flow

When the recovery category is `APPLY_CORRECTION` (for `CORRECTABLE` states) or `NORMALIZE_STATE` (for `UNSTABLE` states), the system attempts deterministic correction using the codeword structure.

```text
FUNCTION attempt_recovery(diagnostic: StateValidityDiagnostic, state_class: SystemStateClass) -> RecoveryResult
    result = new RecoveryResult()
    result.original_diagnostic = diagnostic
    result.recovery_category = classify_recoverability(state_class)
    result.steps = []

    SWITCH result.recovery_category

        CASE NORMALIZE_STATE:
            -- State is transformation-compatible; restore to valid configuration
            normalized = normalize_via_codeword_structure(diagnostic.input_state)
            IF normalized is NONE THEN
                result.outcome = BLOCKED
                result.reason = "Normalization path not found"
                result.steps.append(step("normalize", BLOCKED, "no normalization path available"))
                RETURN result
            END IF

            result.corrected_state = normalized
            result.steps.append(step("normalize", COMPLETED, "state normalized via codeword structure"))
            result.outcome = RECOVERED

        CASE APPLY_CORRECTION:
            -- State is correctable; apply known correction sequence
            correction = find_correction_sequence(diagnostic.input_state)
            IF correction is NONE THEN
                result.outcome = BLOCKED
                result.reason = "Correction sequence not computable"
                result.steps.append(step("correct", BLOCKED, "no correction path found"))
                RETURN result
            END IF

            corrected = apply_codeword_chain(diagnostic.input_state, correction)
            result.corrected_state = corrected
            result.steps.append(step("correct", COMPLETED,
                "state corrected via codeword sequence"))
            result.outcome = RECOVERED

        CASE FALLBACK_REQUIRED:
            result = select_fallback(diagnostic, result)
            RETURN result

        OTHERWISE:
            result.outcome = NOT_APPLICABLE
            result.reason = "Recovery category handled by another specification"
            RETURN result

    END SWITCH

    -- Validate recovered state
    IF result.outcome == RECOVERED THEN
        validation = diagnose_state(result.corrected_state)
        result.steps.append(step("validate-recovery", COMPLETED,
            "post-recovery validation: " + validation.admissibility_status))

        IF NOT validation.is_valid THEN
            result.outcome = RECOVERY_FAILED
            result.reason = "Recovered state did not classify as VALID"
            result.steps.append(step("validate-recovery", FAILED,
                "post-recovery state is not valid"))
        END IF
    END IF

    RETURN result
END FUNCTION
```

## Fallback selection flow

When the recovery category is `FALLBACK_REQUIRED` (for `DEGRADED` states), the system selects from the canonical fallback-policy registry.

Fallback selection operates against the **canonical fallback-policy registry** (see `specs/registries/fallback-policy-registry.md`). Ordering is deterministic and fully specified by policy identifiers.

```text
FUNCTION select_fallback(diagnostic: StateValidityDiagnostic, result: RecoveryResult) -> RecoveryResult

    IF NOT fallback_registry_is_available() THEN
        result.outcome = ESCALATE_TO_CONTAINMENT
        result.reason = "No fallback-policy registry available"
        result.steps.append(step("select-fallback", BLOCKED, "fallback registry unavailable"))
        RETURN result
    END IF

    candidates = fallback_registry.get_candidates_for(diagnostic)

    IF candidates is empty THEN
        result.outcome = ESCALATE_TO_CONTAINMENT
        result.reason = "Fallback registry contains no candidates for this state"
        result.steps.append(step("select-fallback", BLOCKED, "no fallback candidates"))
        RETURN result
    END IF

    selected = candidates.first_by_policy_order()
    result.corrected_state = selected.state
    result.fallback_policy_id = selected.policy_id
    result.steps.append(step("select-fallback", COMPLETED,
        "fallback selected: policy=" + selected.policy_id))
    result.outcome = RECOVERED_VIA_FALLBACK

    -- Validate fallback state
    validation = diagnose_state(result.corrected_state)
    IF NOT validation.is_valid THEN
        result.outcome = ESCALATE_TO_CONTAINMENT
        result.reason = "Fallback state is not valid"
        result.steps.append(step("validate-fallback", FAILED, "escalating to containment"))
    END IF

    RETURN result
END FUNCTION
```

## No silent healing

All recovery actions must be diagnosable. The system must not silently mutate its own state without producing an explainable diagnostic record.

## Minimum diagnostic content for recovery and fallback

```text
TYPE RecoveryDiagnostic
    recovery_category        : RecoveryCategory
    original_state_class     : SystemStateClass
    original_diagnostic      : StateValidityDiagnostic
    steps                    : List of RecoveryStep
    outcome                  : RecoveryOutcome
    corrected_state          : AshState or NONE
    fallback_policy_id       : String or NONE
    reason                   : String
    rule_ids                 : List of String
END TYPE

ENUM RecoveryOutcome
    RECOVERED
    RECOVERED_VIA_FALLBACK
    BLOCKED
    RECOVERY_FAILED
    ESCALATE_TO_CONTAINMENT
    NOT_APPLICABLE
END ENUM
```

## Prohibition on heuristic guessing

When canonical policy is absent, the system must not guess. It must escalate to containment.

## Canonical fallback-policy registry

The fallback-policy registry is defined in `specs/registries/fallback-policy-registry.md`. It governs deterministic fallback selection with normative entry shapes, ordering rules, validation requirements, and escalation behavior.

## Relation to other specifications

- **system-state-classification.pseudo.md** — provides the system-state class that determines recovery category
- **recoverability-semantics.pseudo.md** — provides the recovery-category mapping
- **containment-safe-failure-semantics.pseudo.md** — handles escalation when recovery/fallback fails
- **state-validity-diagnostics.pseudo.md** — provides diagnostics for pre/post-recovery validation
- **codeword-set.pseudo.md** — provides the codeword structure used for normalization and correction
- **state-admissibility.pseudo.md** — provides admissibility classification
- **fallback-policy-registry.md** — canonical registry for fallback selection
