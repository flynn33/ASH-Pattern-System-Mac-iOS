# Averaging Operator Semantics — canonical specification

## Purpose

This specification defines the **canonical averaging operator** for the ASH Pattern System, grounded in the research baseline.

The averaging operator is the fundamental tool for projecting functions on the state space onto the subspace of functions that are invariant under codeword transformations. It is central to stability, invariant behavior, and the algebraic structure of the ASH model.

## Canonical definition

Given:
- a function `f : F2^9 → R` (a real-valued function on the state space)
- the codeword set `C ⊂ F2^9`

The averaging operator `T` is defined as:

```text
T f(x) = (1/|C|) Σ_{c ∈ C} f(x ⊕ c)
```

where:
- `x ∈ F2^9` is a state
- `c` ranges over all codewords in `C`
- `⊕` is coordinate-wise XOR (addition in F2)
- `|C|` is the number of codewords in `C`

## Idempotency

The averaging operator is **idempotent**:

```text
T² = T
```

That is, applying the averaging operator twice produces the same result as applying it once. This means `T` is a **projection operator** — it projects functions onto the subspace of C-invariant functions.

## Projection onto C-invariant functions

A function `f` is **C-invariant** if:

```text
f(x ⊕ c) = f(x)    for all x ∈ F2^9 and all c ∈ C
```

The averaging operator `T` projects any function onto the space of C-invariant functions:
- If `f` is already C-invariant, then `T f = f`
- If `f` is not C-invariant, then `T f` is the "closest" C-invariant function in the averaging sense

## Role in stability and invariant behavior

The averaging operator provides the algebraic foundation for:

- **Stability analysis** — a state property is stable under codeword transformations if and only if its indicator function is C-invariant (fixed by `T`)
- **Invariant detection** — `T` identifies which functions (and therefore which state properties) are preserved under the codeword algebra
- **Equilibrium characterization** — the image of `T` characterizes the equilibrium or steady-state behavior of the system under codeword motion

## Pseudocode

```text
FUNCTION averaging_operator(f, x, codeword_set C) -> Real
    PRECONDITION: x ∈ F2^9
    PRECONDITION: C ⊂ F2^9, C is non-empty

    sum = 0
    FOR EACH c IN C
        sum = sum + f(x XOR c)
    END FOR

    result = sum / |C|

    RETURN result
END FUNCTION
```

## Invariants

1. **Idempotency**: `T(T f) = T f` for all functions `f`
2. **Linearity**: `T(af + bg) = a(Tf) + b(Tg)` for scalars `a, b`
3. **Determinism**: the same function and state always produce the same averaged value
4. **Fixpoint characterization**: `Tf = f` if and only if `f` is C-invariant

## Boundaries of this specification

This specification defines the averaging operator as it appears in the research baseline. It does not:

- Overstate the operator's role beyond what the research materials justify
- Infer additional algebraic properties not established in the research baseline
- Prescribe how Apple implementation modules must use the operator beyond preserving its mathematical definition

## Relation to other specifications

- **codeword-set.pseudo.md** — defines the canonical codeword set `C` over which the averaging operator sums
- **codeword-transformation-semantics.pseudo.md** — defines the `x ⊕ c` transformation that the averaging operator is built on
- **ash-state-space.pseudo.md** — defines the canonical F2^9 state space
- **branching-semantics.pseudo.md** — branching and averaging interact in the full ASH model
