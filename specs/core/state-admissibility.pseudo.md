> Historical reference retained from the pre-SDK Apple baseline. For SDK 1.0.0, current semantic authority is ASH-Pattern-System 1.0.0-rc.3 at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8. Current public-contract decisions override conflicting retained prose; see repository-root docs/sdk-authority-and-conformance.md.

# State Admissibility — canonical specification (Research Baseline)

## Purpose

This specification defines **admissibility and validity** for full 9-bit states in the ASH Pattern System, grounded in the research baseline.

Admissibility determines whether a given 9-bit state is structurally valid within the ASH model and whether it is compatible with the codeword transformation structure.

## Admissibility concept

In the full 9D research model, admissibility is defined in terms of the state's relationship to the **codeword orbit structure** rather than membership in an 8-bit sub-code.

### Codeword orbits

For any state `x ∈ F2^9`, the **codeword orbit** of `x` is:

```text
Orbit(x) = { x ⊕ c : c ∈ C }
```

where `C` is the canonical codeword set. All states within the same orbit are reachable from each other via codeword transformations.

The orbits partition F2^9 into disjoint equivalence classes. Each orbit represents a family of states that are algebraically connected.

## Admissibility statuses

```text
ENUM AdmissibilityStatus
    VALID                        -- state is well-formed and transformation-compatible
    TRANSFORMATION_COMPATIBLE    -- state is reachable via codeword orbit from a known valid state
    TRANSFORMATION_INCOMPATIBLE  -- state is not reachable via any codeword orbit from known valid states
    UNCLASSIFIED                 -- admissibility cannot be determined (e.g., codeword set not fully specified)
END ENUM
```

### VALID

The state is a well-formed 9-bit vector in F2^9 and is recognized as a structurally valid state in the ASH model. Valid states are the normal operating states of the system.

### TRANSFORMATION_COMPATIBLE

The state is reachable from a known valid state via one or more codeword transformations. It is within the codeword orbit structure and can participate in normal transformation operations.

### TRANSFORMATION_INCOMPATIBLE

The state is a well-formed 9-bit vector but is not reachable from any known valid state via codeword transformations. It lies outside the codeword orbit structure and cannot be reached or departed from using canonical transformations alone.

### UNCLASSIFIED

Admissibility cannot be determined, either because:
- The state is malformed (not a valid 9-bit F2 vector)
- Implementation nonconformance prevents classification

## Relation to diagnostics and classification

Admissibility status feeds directly into the state-validity diagnostic and system-state classification:

| Admissibility Status | Diagnostic Implication | Classification Guidance |
|---|---|---|
| `VALID` | State is healthy | → STABLE (if no other issues) |
| `TRANSFORMATION_COMPATIBLE` | State is reachable but may need normalization | → STABLE or recovery depending on context |
| `TRANSFORMATION_INCOMPATIBLE` | State is outside orbit structure | → DEGRADED or FAILED depending on severity |
| `UNCLASSIFIED` | Cannot determine | → diagnostic notes must explain why |

## Pseudocode

```text
FUNCTION classify_state_admissibility(state[9], codeword_set C) -> AdmissibilityStatus
    PRECONDITION: length(state) == 9
    PRECONDITION: all elements are in F2

    IF state is a recognized valid state THEN
        RETURN VALID
    END IF

    IF exists c_sequence IN codeword_paths(C) such that
       apply_codeword_chain(known_valid_state, c_sequence) == state THEN
        RETURN TRANSFORMATION_COMPATIBLE
    END IF

    IF codeword_set_is_fully_specified() THEN
        RETURN TRANSFORMATION_INCOMPATIBLE
    ELSE
        RETURN UNCLASSIFIED
    END IF
END FUNCTION
```

## Relation to recovery semantics

- **VALID / TRANSFORMATION_COMPATIBLE** states are candidates for normal operation or normalization
- **TRANSFORMATION_INCOMPATIBLE** states require fallback or containment — they cannot be corrected via codeword transformations
- **UNCLASSIFIED** states require diagnostic reporting and may require containment until classification is possible

## What this specification does NOT define

This specification does not:
- Reuse the superseded [8,4,4] 8-bit core admissibility framing
- Define admissibility in terms of an 8-bit sub-code plus a derived control bit
- Assume a specific linear code structure unless the research baseline establishes one
- Invent admissibility rules not grounded in the research materials

## Invariants

1. **Completeness**: every 9-bit vector in F2^9 maps to exactly one admissibility status (given a fully specified codeword set)
2. **Determinism**: the same state and codeword set always produce the same admissibility status
3. **Research grounding**: admissibility rules are derived from the codeword structure defined by the research baseline
4. **No 8+1 decomposition**: admissibility is evaluated on the full 9-bit state, not on an 8-bit sub-vector

## Relation to other specifications

- **codeword-set.pseudo.md** — defines the codeword set `C` that determines orbit structure and admissibility
- **ash-state-space.pseudo.md** — defines the F2^9 state space
- **state-validity-diagnostics.pseudo.md** — consumes admissibility status to produce diagnostic records
- **system-state-classification.pseudo.md** — uses admissibility to determine system-state class
- **recoverability-semantics.pseudo.md** — uses admissibility to determine recovery category
