> Historical reference retained from the pre-SDK Apple baseline. For SDK 1.0.0-rc.1, current semantic authority is ASH-Pattern-System 1.0.0-rc.3 at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8. Current public-contract decisions override conflicting retained prose; see repository-root docs/sdk-authority-and-conformance.md.

# Transition System — canonical specification (Research Baseline)

> **Realigned in Research Math Realignment Package R1.**
> Transitions now operate on the full 9-bit state via XOR-by-codeword.
> The previous model ("acts on 8-bit core, then re-derives control bit") is superseded.

## Purpose

The transition system defines how an ASH state evolves. In the research baseline, the canonical transition mechanism is **XOR-by-codeword** on the full 9-bit state in F2^9.

## Transition model

A transition applies a **codeword transformation** to the full 9-bit state:

```text
x' = x ⊕ c    where x ∈ F2^9, c ∈ C ⊂ F2^9
```

The transition operates on all 9 coordinates simultaneously. There is no separate "apply to core, then re-derive control" step at the foundational level.

See `specs/algorithms/codeword-transformation-semantics.pseudo.md` for the canonical transformation definition.

## Canonical transition record

```text
TYPE TransitionDefinition
    transition_id: String
    display_name: String
    description: String
    state_transform: Function (AshState -> AshState)
    applicability_rule: Function (AshState -> Boolean)
END TYPE
```

## Canonical transition registry

```text
TYPE TransitionRegistry
    ordered_transitions: List<TransitionDefinition>
END TYPE
```

## Application rule

1. Accept input state (full 9-bit vector)
2. Check applicability of requested transition
3. Apply the transition to the full 9-bit state
4. Return the transformed state

## Pseudocode

```text
FUNCTION apply_transition(state: AshState, transition: TransitionDefinition) -> AshState
    IF transition.applicability_rule(state) == false THEN
        RAISE TransitionNotApplicable
    END IF

    result = transition.state_transform(state)
    RETURN result
END FUNCTION
```

```text
FUNCTION apply_codeword_transition(state: AshState, codeword[9]) -> AshState
    PRECONDITION: codeword ∈ C (the canonical codeword set)

    result.bits = state.bits XOR codeword
    RETURN result
END FUNCTION
```

```text
FUNCTION apply_transition_chain(state: AshState, transitions: List<TransitionDefinition>) -> AshState
    current = state
    FOR each transition IN transitions
        current = apply_transition(current, transition)
    END FOR
    RETURN current
END FUNCTION
```

## Required invariants

1. Equal input state + equal transition => equal output state
2. Codeword transformations are deterministic and pure
3. `(x ⊕ c) ⊕ c = x` — applying the same codeword twice returns to the original state
4. Failed applicability checks return explainable diagnostics

## Relation to other specifications

- **codeword-set.pseudo.md** — defines the canonical codeword set used in transformations
- **state-admissibility.pseudo.md** — defines state validity for pre/post-transition checks
- **codeword-transformation-semantics.pseudo.md** — defines the canonical XOR-by-codeword operation
- **ash-state-space.pseudo.md** — defines the canonical F2^9 state space
- **averaging-operator-semantics.pseudo.md** — the averaging operator is defined over codeword transformations
