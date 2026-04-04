# Codeword Set — canonical specification (Research Baseline)

## Purpose

This specification defines the canonical **codeword set** `C ⊂ F2^9` for the ASH Pattern System.

The codeword set is the algebraic structure that governs all state transformations, orbit structure, averaging behavior, and branching topology in the ASH model. Every transformation `x' = x ⊕ c` uses a codeword from this set.

## Closure status

> **STATUS: PARTIALLY CLOSED**
>
> The codeword set is established as a subgroup of `(F2^9, ⊕)`. Its exact generators and exhaustive enumeration remain pending extraction from the published research materials. This is the sole remaining open research-closure item in the ASH Pattern System specification.

---

## Locked facts (canonical now)

The following properties of `C` are established and canonical:

1. **Domain**: `C ⊂ F2^9` — every codeword is a full 9-bit binary vector
2. **Non-emptiness**: `C` is non-empty
3. **Identity**: `C` contains the zero vector `0 ∈ C`, so `x ⊕ 0 = x` (identity transformation)
4. **XOR closure**: if `c1, c2 ∈ C` then `c1 ⊕ c2 ∈ C` — the set is closed under the group operation
5. **Subgroup**: properties 2–4 establish that `C` is a **subgroup** of `(F2^9, ⊕)`. This is the minimum algebraic consequence required by the canonical averaging operator `T` with `T² = T` (see derivation below)
6. **Determinism**: `C` is fixed for a given ASH model configuration — it does not vary at runtime
7. **Research grounding**: the codeword set must be grounded in published research materials, not invented by implementations
8. **No coordinate privilege**: codewords are full 9-bit objects — no coordinate is structurally privileged at the foundational level
9. **No 8+1 decomposition**: codewords are not decomposed into 8-bit components plus a derived 9th bit at the foundational level

### Derivation of the subgroup property

The averaging operator is defined as:

```text
T f(x) = (1/|C|) Σ_{c∈C} f(x ⊕ c)
```

The canonical requirement `T² = T` (idempotent projection) holds if and only if the index set of the sum is closed under the group operation and contains the identity. That is, `C` must be a subgroup of `(F2^9, ⊕)`.

This is a mathematical consequence of the already-locked averaging-operator specification, not an independent assumption. The subgroup property does not by itself determine the generators, dimension, or size of `C` — it constrains but does not exhaust the codeword-set closure problem.

## Supported but non-exhaustive facts

The following are observable or inferable but do not constitute exhaustive closure:

1. **Published examples**: some published example codewords have their 9th coordinate set to `0`. This is an observable structural property of those specific codewords. It does **not** mandate that all codewords must have `b8 = 0`, nor does it justify promoting the 9th coordinate to a derived parity/control role
2. **Generating structures**: the research materials (ashcosmology.net, published papers and preprints) describe generating transformations and adinkra / graph-theoretic constructs related to the codeword structure
3. **Size constraint**: as a subgroup of `F2^9`, `|C|` must be a power of 2 (possible sizes: 1, 2, 4, 8, 16, 32, 64, 128, 256, 512)

## Unresolved closure items

The following remain open and must be resolved by extraction from the published research materials:

1. **Generators**: the exact generating set for `C` has not been extracted from published sources into this repository
2. **Dimension**: the dimension of `C` as a subspace of `F2^9` (and therefore `|C|`) is not yet formalized here
3. **Exhaustive enumeration**: the complete list of all codewords in `C` is not yet available in this repository

These items are **not blocked by missing theory** — the subgroup structure is locked and the research materials contain the generating information. The remaining work is extraction and formalization, not discovery.

## Downstream implementation constraints

### Implementations must not

- Invent codewords not grounded in the research baseline
- Extend the codeword set beyond what the research materials justify
- Treat the codeword set as an open parameter that implementations may choose freely
- Assume `C` is the full space `F2^9` or any specific subspace without explicit research support
- Assume any algebraic property of `C` stronger than the subgroup property unless separately established from the research baseline

### Implementations must

- Treat `C` as a **single replaceable point of definition** — the codeword set must be injectable/configurable so it can be updated when the exhaustive enumeration is formalized
- Handle `UNCLASSIFIED` admissibility status correctly when `C` is not fully specified (see `state-admissibility.pseudo.md`)
- Enforce that all codewords used in transformations are members of the provided `C`
- Validate the subgroup property on any provided codeword set (identity present, XOR-closed)

### Implementations may

- Proceed with a partial or placeholder codeword set only under **CONFORMANT WITH CAVEATS** acceptance posture for all codeword-dependent features (see `implementation-acceptance.md`)
- Use the subgroup property to validate and test codeword-set integrity

---

## Relation to other specifications

- **codeword-transformation-semantics.pseudo.md** — defines `x' = x ⊕ c` using codewords from this set
- **averaging-operator-semantics.pseudo.md** — defines `T` as a sum over codeword transformations; the `T² = T` requirement is the source of the subgroup property
- **branching-semantics.pseudo.md** — branching topology is governed by the codeword structure
- **state-admissibility.pseudo.md** — admissibility is defined relative to the codeword orbit structure
- **ash-state-space.pseudo.md** — defines the F2^9 state space in which codewords operate
- **transition-system.pseudo.md** — transitions use codeword transformations

## Invariants

1. **Research grounding**: the codeword set must be grounded in published research materials, not invented
2. **9-bit completeness**: codewords are full 9-bit vectors in F2^9
3. **No 8+1 decomposition**: codewords are not decomposed into 8-bit components plus a derived 9th bit at the foundational level
4. **Determinism**: the codeword set is fixed for a given ASH model configuration — it does not vary at runtime
5. **Subgroup**: `C` is a subgroup of `(F2^9, ⊕)` — contains identity, closed under XOR
