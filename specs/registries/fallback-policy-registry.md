# Fallback-Policy Registry — canonical specification

## Purpose

This specification defines the **canonical fallback-policy registry** for the ASH Pattern System.

The fallback-policy registry governs **deterministic fallback selection** when a system state is classified as `DEGRADED` and direct correction is not possible. Every fallback selection must be traceable to a registry entry, ordered deterministically, and validated after selection.

This registry is **normative**. The Mac/iOS implementation must not invent, hardcode, or heuristically select fallback states outside of this registry structure.

## Normative status

> **STATUS: CANONICAL (Design Package D)**

The fallback-policy registry is a locked design decision. It is not optional, not future, and not a placeholder.

## Policy identifier format

Each registry entry is identified by a **policy identifier** with the format:

```text
FALLBACK-{DOMAIN}-{SEQUENCE}
```

Where:
- `{DOMAIN}` is a short uppercase token identifying the policy domain (e.g., `CORE`, `REALM`, `TRANSITION`)
- `{SEQUENCE}` is a 3-digit zero-padded number, monotonically increasing within the domain

Examples: `FALLBACK-CORE-001`, `FALLBACK-REALM-001`, `FALLBACK-TRANSITION-003`

Policy identifiers must be globally unique and stable — once assigned, they must not be reassigned to a different policy.

## Registry entry shape

```text
TYPE FallbackPolicyEntry
    policy_id                : String (format: FALLBACK-{DOMAIN}-{SEQUENCE})
    applicability_conditions : List of condition predicates
    candidate_state_reference : AshState (a known-good admissible state)
    ordering_rank            : Integer (lower = higher priority)
    validation_requirements  : List of validation predicates
    escalation_on_failure    : EscalationAction
    notes                    : List of String
END TYPE
```

### Field definitions

#### `policy_id`
The unique identifier for this registry entry. Must conform to the policy identifier format.

#### `applicability_conditions`
A list of predicates that determine whether this entry is a candidate for a given degraded state. A candidate is eligible only if all applicability conditions are satisfied.

#### `candidate_state_reference`
The known-good admissible state that this entry proposes as a fallback target. This state must be an admissible codeword with correctly derived control bit (`control_bit = 0` per the locked parity formula).

#### `ordering_rank`
An integer that determines selection priority among eligible candidates. Lower rank = higher priority. Ties are broken by lexicographic ordering of `policy_id`.

#### `validation_requirements`
A list of predicates that the selected fallback state must satisfy after selection. At minimum, the selected state must classify as `STABLE` when re-diagnosed.

#### `escalation_on_failure`
The action to take if this candidate fails validation. Must be one of:
- `TRY_NEXT` — try the next candidate in ordering
- `ESCALATE_TO_CONTAINMENT` — skip remaining candidates and escalate immediately

#### `notes`
Human-readable annotations for operators and diagnostic inspection.

## Pseudocode interfaces

```text
FUNCTION get_fallback_candidates(diagnostic: StateValidityDiagnostic, state_class: SystemStateClass) -> OrderedList[FallbackPolicyEntry]
    PRECONDITION: state_class == DEGRADED

    candidates = []
    FOR EACH entry IN fallback_policy_registry
        IF all_satisfied(entry.applicability_conditions, diagnostic) THEN
            candidates.append(entry)
        END IF
    END FOR

    -- Deterministic ordering: by ordering_rank ASC, then by policy_id ASC
    candidates = sort(candidates, by: [ordering_rank ASC, policy_id ASC])

    RETURN candidates
END FUNCTION
```

```text
FUNCTION select_fallback_candidate(diagnostic: StateValidityDiagnostic, state_class: SystemStateClass) -> FallbackPolicyEntry or NONE
    candidates = get_fallback_candidates(diagnostic, state_class)

    IF candidates is empty THEN
        RETURN NONE  -- caller must escalate to containment
    END IF

    FOR EACH candidate IN candidates
        validation = diagnose_state(candidate.candidate_state_reference)

        IF validation.is_valid_normalized_state == TRUE THEN
            RETURN candidate
        ELSE
            IF candidate.escalation_on_failure == ESCALATE_TO_CONTAINMENT THEN
                RETURN NONE  -- immediate escalation
            END IF
            -- else TRY_NEXT: continue to next candidate
        END IF
    END FOR

    RETURN NONE  -- all candidates exhausted
END FUNCTION
```

## Candidate eligibility rules

1. A candidate state must be an admissible codeword from the locked [8,4,4] normative codeword set.
2. A candidate state must have a correctly derived control bit (which is `0` for all admissible states per the locked parity formula).
3. A candidate entry is eligible for a given degraded state only if all of its `applicability_conditions` are satisfied against the current diagnostic.
4. A candidate that does not satisfy all applicability conditions must not be considered.

## Deterministic ordering rules

1. Candidates are ordered by `ordering_rank` ascending (lower rank = higher priority).
2. Ties in `ordering_rank` are broken by lexicographic ordering of `policy_id` ascending.
3. No randomness, shuffling, or probabilistic selection is permitted.
4. The ordering must be identical across all platforms, implementations, and execution contexts for the same registry contents and diagnostic input.

## Post-selection validation requirements

1. After selecting a candidate, the system must re-diagnose the candidate state.
2. The re-diagnosis must classify the candidate state as `STABLE` (admissible core, correct control bit, no errors).
3. If the candidate does not classify as `STABLE`, its `escalation_on_failure` action determines the next step.
4. Post-selection validation must not be skipped, deferred, or silently omitted.

## Escalation behavior when no valid candidate exists

When `select_fallback_candidate` returns `NONE`:

1. The system must escalate to `CONTAINMENT_REQUIRED`.
2. The escalation must be recorded in the diagnostic chain with a `FALLBACK` diagnostic kind.
3. The diagnostic must include the reason: either "no candidates in registry" or "all candidates failed validation".
4. The system must not invent, guess, or heuristically select a fallback state outside the registry.

## Prohibition on heuristic and ad hoc fallback selection

The system must not:

- Select a fallback state by heuristic distance to the current state
- Select a fallback state from a "recently seen" or "most common" cache
- Select a fallback state based on probabilistic scoring
- Silently continue in the degraded state without fallback or escalation
- Invent a fallback state not present in the registry

All fallback selection must be traceable to a specific `policy_id` in the canonical registry.

## Invariants

1. **Determinism** — the same diagnostic and registry contents always produce the same candidate ordering and selection.
2. **Completeness** — every `DEGRADED` state is either served by a registry candidate or escalated to containment. No state falls through without a decision.
3. **Traceability** — every selected fallback is traceable to a `policy_id`. Every escalation is recorded in the diagnostic chain.
4. **Validation** — every selected candidate is validated before use. No unvalidated fallback state enters the system.
5. **No silent fallback** — fallback selection always produces a diagnostic record, whether successful or escalated.

## Schema conformance

Diagnostics emitted during fallback selection must conform to the shared diagnostic schema defined in `specs/interfaces/diagnostic-schema.md`.

Rule IDs used in fallback diagnostics must conform to the `ASH-FALLBACK` family in `specs/interfaces/rule-id-taxonomy.md`.

## Relation to other specifications

- **recovery-fallback-semantics.pseudo.md** — invokes this registry during the `FALLBACK_REQUIRED` recovery path
- **containment-safe-failure-semantics.pseudo.md** — receives escalation when no valid fallback candidate exists
- **semantic-contracts.md** — requires Apple implementation modules to implement fallback selection against this registry
- **system-state-classification.pseudo.md** — provides the `DEGRADED` classification that triggers fallback
- **state-validity-diagnostics.pseudo.md** — provides the diagnostic used for candidate eligibility and post-selection validation
