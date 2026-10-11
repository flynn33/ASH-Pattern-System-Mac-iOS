> Historical reference retained from the pre-SDK Apple baseline. For SDK 1.0.0-rc.1, current semantic authority is ASH-Pattern-System 1.0.0-rc.3 at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8. Current public-contract decisions override conflicting retained prose; see repository-root docs/sdk-authority-and-conformance.md.

# ASH State Space — canonical specification (Research Baseline)

> **Realigned in Research Math Realignment Package R1.**
> This file now reflects the full 9-dimensional ASH research model.
> The previous 8+1 formalization (8-bit "stabilizing algebraic core" + derived 9th "control/parity bit") is superseded.

## Design decision

The ASH state space is **F2^9** — the set of all 9-bit binary vectors.

An ASH state is a **full 9-coordinate binary vector**:

```text
S = (b0, b1, b2, b3, b4, b5, b6, b7, b8)
where each bi ∈ F2
```

There are **512 states** (vertices / realms) in the state space.

## Structural interpretation

All 9 coordinates participate in the algebraic structure of the ASH state space. No single coordinate is structurally privileged as a "derived" dimension at the foundational level.

The state space structure is defined by the **codeword set** `C ⊂ F2^9`, which determines:

- the allowed transformations (XOR-by-codeword motion between states)
- the orbit structure (which states are reachable from which)
- the averaging operator and its invariant subspaces
- the branching / expansion topology

### Observation about published examples

Some published ASH example codewords have their 9th coordinate set to `0`. This is an observable property of those specific codewords. It does **not** justify promoting the 9th coordinate to a canonical "derived control/parity dimension" or inferring that `b8` must always be derived from `b0..b7` by a parity formula. The research baseline treats all 9 coordinates as part of the full algebraic structure.

## Canonical state record

```text
TYPE AshState
    bits: Vector[9] over F2
END TYPE
```

Equivalent expanded form:

```text
TYPE AshStateExpanded
    b0: Bit
    b1: Bit
    b2: Bit
    b3: Bit
    b4: Bit
    b5: Bit
    b6: Bit
    b7: Bit
    b8: Bit
END TYPE
```

The canonical form is the **full 9-bit vector**. Implementations may use either representation, but the 9-bit vector is the semantic normal form.

## Canonical transformation

Ordinary movement between states is defined by **XOR-by-codeword**:

```text
x' = x ⊕ c    where x ∈ F2^9, c ∈ C ⊂ F2^9
```

See `specs/algorithms/codeword-transformation-semantics.pseudo.md` for the full definition.

## Pseudocode

```text
FUNCTION make_state(bits[9]) -> AshState
    PRECONDITION: length(bits) == 9
    PRECONDITION: all elements of bits are in F2

    state.bits = bits
    RETURN state
END FUNCTION
```

```text
FUNCTION transform_state(state: AshState, codeword[9]) -> AshState
    PRECONDITION: length(codeword) == 9
    PRECONDITION: codeword ∈ C (the canonical codeword set)

    result.bits = state.bits XOR codeword
    RETURN result
END FUNCTION
```

## Validity and admissibility

Validity and admissibility for the full 9D model are defined by:

- **Codeword-orbit membership** — whether a state is reachable from known valid states via codeword transformations
- **Admissibility classification** — VALID, TRANSFORMATION_COMPATIBLE, TRANSFORMATION_INCOMPATIBLE, or UNCLASSIFIED

See `specs/core/state-admissibility.pseudo.md` for the full admissibility specification.
See `specs/core/codeword-set.pseudo.md` for the canonical codeword structure.

## Required invariants

1. The state space is F2^9 — all states are 9-bit binary vectors
2. Normalization is deterministic — the same candidate state always produces the same result
3. Codeword transformations are deterministic — the same state and codeword always produce the same result
4. State validity can be explained diagnostically
5. All 9 coordinates are part of the algebraic structure — no coordinate is excluded from the foundational model

## Related specifications

- `specs/core/codeword-set.pseudo.md` — canonical codeword set definition
- `specs/core/state-admissibility.pseudo.md` — full 9-bit admissibility and validity
- `specs/algorithms/codeword-transformation-semantics.pseudo.md` — canonical XOR-by-codeword transformation
- `specs/algorithms/averaging-operator-semantics.pseudo.md` — canonical averaging operator `T` with `T² = T`
- `specs/algorithms/branching-semantics.pseudo.md` — canonical branching / leaf expansion
- `specs/core/realm-identity.pseudo.md` — realm identity encoding from full 9-bit state

### Superseded specifications (not canonical after R1)

- `specs/core/control-bit-derivation.pseudo.md` — superseded 8+1 control-bit model
- `specs/core/core-admissibility.pseudo.md` — superseded 8-bit [8,4,4] admissibility model
- `specs/core/state-validity-diagnostics.pseudo.md` — superseded 8+1 diagnostic model
