# Control-Bit Derivation — SUPERSEDED

> **SUPERSEDED — Research Math Realignment Package R1**
>
> This file reflects the **superseded 8+1 drift formalization**. It defined the 9th coordinate as a "derived control/parity bit" computed by XOR-parity of the first 8 coordinates. That model is **not canonical** after R1.
>
> The canonical ASH mathematical foundation is now the **full 9-dimensional research baseline** defined in `ash-state-space.pseudo.md` and the research-baseline algorithm specs.
>
> **This file must not be used as authority for Apple implementation work.**
> It is retained for historical reference only and is pending replacement in later realignment packages (R2).

---

# Control-Bit Derivation — superseded specification (historical reference)

## Purpose

The 9th coordinate of the ASH state space (`b8`) is a **derived control/parity dimension**.
It is not a free coordinate. Its value must be deterministically derived from the 8-bit stabilizing core (`b0..b7`).

The control-bit derivation function exists to:

- enforce consistency between the stabilizing core and the full 9-coordinate state
- enable detection of state corruption or unauthorized mutation
- support self-referential state semantics (the state can verify its own integrity)
- provide a foundation for normalization, validity checking, and diagnostic reporting
- prevent Apple implementation modules from treating the 9th coordinate as an ordinary peer bit

## Inputs

```text
core_bits: Vector[8] over F2
```

The 8-bit stabilizing algebraic core of the ASH state.

### Input preconditions

1. `core_bits` must be exactly 8 elements
2. each element must be in F2 (that is, exactly 0 or 1)
3. the input must be provided — derivation from an absent or partial core is not defined

## Outputs

```text
control_bit: Bit (element of F2)
```

A single derived bit representing the 9th coordinate of the full ASH state.

### Output postconditions

1. the output is deterministic: the same `core_bits` always produce the same `control_bit`
2. the output is in F2 (exactly 0 or 1)
3. equal 8-bit cores produce equal derived control bits

## Invariants

1. **Purity** — derivation has no side effects. It reads the core and returns a bit.
2. **Determinism** — identical inputs always produce identical outputs, regardless of platform, language, runtime, or execution context.
3. **Referential transparency** — the function may be called any number of times with the same input and must return the same output.
4. **Independence from external state** — the derivation must not depend on mutable global state, configuration, randomness, time, or any context outside the input vector.
5. **Algebraic closure** — the derivation operates over F2 and produces a value in F2. No intermediate computation may leave the field.

## Prohibited shortcuts

1. Do not allow any code path to set the control bit directly without going through derivation.
2. Do not allow platform-specific optimization to change the derivation semantics.
3. Do not allow lazy or deferred derivation that could produce a state with an unset control bit.
4. Do not allow a fallback value (such as always returning 0) in place of proper derivation.
5. Do not derive from a subset of the core — all 8 bits must participate as defined by the derivation formula.

## Pseudocode interface shape

```text
FUNCTION derive_control_bit(core_bits[8]) -> Bit
    PRECONDITION: length(core_bits) == 8
    PRECONDITION: all elements of core_bits are in F2

    control_bit = core_bits[0] XOR core_bits[1] XOR core_bits[2] XOR core_bits[3]
                  XOR core_bits[4] XOR core_bits[5] XOR core_bits[6] XOR core_bits[7]

    POSTCONDITION: control_bit is in F2
    POSTCONDITION: derivation is deterministic

    RETURN control_bit
END FUNCTION
```

## Diagnostic behavior when derivation cannot proceed

If derivation is invoked with invalid input, the implementation must not silently produce a default value.

The following conditions must produce a diagnosable failure:

| Condition | Required behavior |
|---|---|
| `core_bits` is absent or null | Derivation must fail with a diagnostic indicating missing input |
| `core_bits` has fewer than 8 elements | Derivation must fail with a diagnostic indicating insufficient length |
| `core_bits` has more than 8 elements | Derivation must fail with a diagnostic indicating excess length |
| Any element of `core_bits` is not in F2 | Derivation must fail with a diagnostic indicating domain violation |

In all failure cases, the diagnostic must include:

- the reason derivation could not proceed
- the input as received (or a safe representation of it)
- a reference to this specification

The implementation must not return a control bit when derivation fails.

## Relation to other specifications

- **ash-state-space.pseudo.md** — defines the full 9-coordinate state and references this derivation
- **core-admissibility.pseudo.md** — defines which 8-bit cores are admissible; derivation applies to both admissible and inadmissible cores but only produces a meaningful control bit when the core is admissible or has been corrected to an admissible codeword
- **state-validity-diagnostics.pseudo.md** — uses the result of derivation to populate the `control_derivation_status` and `expected_control_dimension` fields

---

## Locked design decision — derivation formula (Design Package C)

> **STATUS: LOCKED**

### Canonical formula

The control-bit derivation function is the **overall parity** of the 8-bit stabilizing core:

```text
derive_control_bit(core_bits) = b0 ⊕ b1 ⊕ b2 ⊕ b3 ⊕ b4 ⊕ b5 ⊕ b6 ⊕ b7
```

Equivalent algebraic form:

```text
derive_control_bit(core_bits) = (Σ_i=0^7 bi) mod 2
```

### Semantic rationale and consequence

Every admissible normalized core derives `control_bit = 0` because the locked [8,4,4] code is doubly-even and therefore has even overall parity.

A non-zero control bit therefore guarantees the state is not a valid normalized state.

However, a zero control bit alone does not prove admissibility or validity, because some inadmissible cores can also have even parity.

The control dimension is therefore:

- a deterministic parity-control coordinate
- a consistency sentinel
- a normalization check
- a self-healing target during correction and re-derivation

It is **not** a free semantic degree of freedom during ordinary normalized operation.

### Formula properties

- **Universal** — the formula does not vary by realm. It applies to all ASH states.
- **Deterministic** — the same 8-bit core always produces the same control bit.
- **Consistent with code structure** — the formula is algebraically aligned with the [8,4,4] extended Hamming code: all 16 admissible codewords have even parity, so derivation produces `0` for every admissible core.

### What Apple implementation modules must do

1. Implementations must use **exactly this formula** — overall parity (XOR of all 8 core bits).
2. Implementations must not substitute a different derivation function.
3. Implementations must not treat the formula as an open or configurable choice.
4. The formula is normative. An equivalent implementation (e.g., popcount mod 2, reduction XOR) is permitted only if it produces identical results for all 256 possible inputs in F2^8.
