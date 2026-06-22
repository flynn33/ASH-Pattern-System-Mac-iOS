# Core Admissibility — SUPERSEDED

> **SUPERSEDED — Research Math Realignment Package R1**
>
> This file reflects the **superseded 8+1 drift formalization**. It defined admissibility in terms of an 8-bit [8,4,4] extended Hamming code "stabilizing algebraic core" separate from a derived 9th bit. That model is **not canonical** after R1.
>
> The canonical ASH mathematical foundation is now the **full 9-dimensional research baseline** defined in `ash-state-space.pseudo.md` and the research-baseline algorithm specs.
>
> **This file must not be used as authority for Apple implementation work.**
> It is retained for historical reference only and is pending replacement in later realignment packages (R2).

---

# Core Admissibility — superseded specification (historical reference)

## Purpose

The admissibility layer defines **which 8-bit core vectors are structurally valid** within the ASH state space.

Not all 256 possible vectors in F2^8 are meaningful ASH core states. The 8-bit stabilizing core is modeled against the **[8,4,4] extended Hamming code**, which imposes algebraic structure on the space. Admissibility determines whether a given core vector belongs to the structured subset or lies outside it.

Admissibility is the foundation for:

- **normalization** — only admissible cores can be normalized into valid ASH states
- **state validity** — a state cannot be valid if its core is inadmissible (unless recovery succeeds)
- **self-correction** — the system's ability to detect and recover from corrupted states
- **safe-failure behavior** — the system's ability to recognize unrecoverable states and fail safely
- **fallback behavior** — the system's ability to choose a known-good state when recovery is not possible
- **deterministic recovery planning** — the system's ability to plan recovery paths based on distance from admissible states

## Admissibility concept

### The structured subset

The [8,4,4] extended Hamming code defines a **16-element subset** of F2^8 (the codewords). These codewords have minimum Hamming distance 4 from each other, which means:

- **1-bit errors** are always detectable
- **2-bit errors** are always detectable
- **1-bit errors** are correctable (the corrupted vector is distance 1 from exactly one codeword)
- **3-bit errors** are detectable but not reliably correctable

### Admissibility classification

An 8-bit core vector falls into exactly one of these categories:

```text
ENUM AdmissibilityStatus
    ADMISSIBLE
    INADMISSIBLE_CORRECTABLE
    INADMISSIBLE_DETECTABLE
    INADMISSIBLE_UNRECOVERABLE
END ENUM
```

| Classification | Meaning | Hamming distance from nearest codeword | Recovery path |
|---|---|---|---|
| `ADMISSIBLE` | The core is a valid codeword | 0 | None needed |
| `INADMISSIBLE_CORRECTABLE` | The core is not a codeword but is within correctable distance | 1 | Correction to nearest codeword |
| `INADMISSIBLE_DETECTABLE` | The core is not a codeword, error is detected but correction is ambiguous | 2 | Fallback required (cannot correct with certainty) |
| `INADMISSIBLE_UNRECOVERABLE` | The core is not a codeword and is beyond reliable detection/correction | 3+ | Safe failure required |

## State classifications (full 9-coordinate state)

When the admissibility of the core is combined with the status of the derived control bit, the full ASH state falls into one of these categories:

| Core admissibility | Control bit status | Full state classification | System behavior |
|---|---|---|---|
| `ADMISSIBLE` | Correctly derived | **Stable** | Normal operation |
| `ADMISSIBLE` | Incorrect or missing | **Unstable** | Recoverable via control-bit re-derivation |
| `INADMISSIBLE_CORRECTABLE` | Any | **Correctable** | Recover core to nearest codeword, then re-derive control |
| `INADMISSIBLE_DETECTABLE` | Any | **Degraded** | Error detected; fallback to known-good state required |
| `INADMISSIBLE_UNRECOVERABLE` | Any | **Failed** | Safe failure; no reliable correction path |

## Relation to normalization

Normalization requires:

1. The core must be admissible (or corrected to an admissible state).
2. The control bit must be derived from the (possibly corrected) admissible core.

If the core is inadmissible and uncorrectable, normalization **cannot proceed**. The system must report a diagnostic failure rather than produce a silently invalid normalized state.

```text
FUNCTION normalize_requires_admissibility(core_bits[8]) -> NormalizationPrecondition
    status = classify_core_admissibility(core_bits)

    IF status == ADMISSIBLE THEN
        RETURN { can_normalize: TRUE, core: core_bits }

    ELSE IF status == INADMISSIBLE_CORRECTABLE THEN
        corrected_core = correct_to_nearest_codeword(core_bits)
        RETURN { can_normalize: TRUE, core: corrected_core, correction_applied: TRUE }

    ELSE
        RETURN { can_normalize: FALSE, reason: status }
    END IF
END FUNCTION
```

## Relation to state validity

A state is **valid** if and only if:

1. its 8-bit core is admissible (classification = `ADMISSIBLE`)
2. its control bit matches the value produced by `derive_control_bit(core_bits)`

A state may be **recoverable** even if not currently valid:

- if the core is `INADMISSIBLE_CORRECTABLE`, correction restores admissibility
- if the control bit is wrong but the core is admissible, re-derivation restores consistency

## Relation to self-correction and fallback

The admissibility classification directly determines the recovery strategy:

| Classification | Recovery strategy |
|---|---|
| **Stable** | No action required |
| **Unstable** | Re-derive control bit from admissible core |
| **Correctable** | Correct core to nearest codeword, then re-derive control bit |
| **Degraded** | Cannot correct with certainty; fall back to a known-good state from the fallback registry |
| **Failed** | Cannot recover; invoke safe-failure protocol |

This mapping must be deterministic. The same admissibility status must always lead to the same category of recovery behavior.

## Invariants

1. **Determinism** — `classify_core_admissibility` always returns the same result for the same input.
2. **Completeness** — every vector in F2^8 maps to exactly one admissibility classification.
3. **Consistency with code structure** — the classification must be consistent with the [8,4,4] extended Hamming code distance properties.
4. **No silent acceptance** — an inadmissible core must never be silently treated as admissible.
5. **Purity** — classification has no side effects.

## Pseudocode interface shape

```text
FUNCTION classify_core_admissibility(core_bits[8]) -> AdmissibilityStatus
    PRECONDITION: length(core_bits) == 8
    PRECONDITION: all elements of core_bits are in F2

    distance = hamming_distance_to_nearest_codeword(core_bits)

    IF distance == 0 THEN
        RETURN ADMISSIBLE
    ELSE IF distance == 1 THEN
        RETURN INADMISSIBLE_CORRECTABLE
    ELSE IF distance == 2 THEN
        RETURN INADMISSIBLE_DETECTABLE
    ELSE
        RETURN INADMISSIBLE_UNRECOVERABLE
    END IF
END FUNCTION
```

```text
FUNCTION correct_to_nearest_codeword(core_bits[8]) -> Vector[8] over F2
    PRECONDITION: classify_core_admissibility(core_bits) == INADMISSIBLE_CORRECTABLE

    nearest = find_unique_nearest_codeword(core_bits)
    RETURN nearest
END FUNCTION
```

## Diagnostics boundary

When admissibility classification results in anything other than `ADMISSIBLE`, the diagnostic system must be able to report:

- the input core as received
- the classification result
- the Hamming distance to the nearest codeword (if computable)
- the nearest codeword (if unique and computable)
- whether correction was applied
- which specification rules were evaluated

This information feeds into the `StateValidityDiagnostic` record defined in `state-validity-diagnostics.pseudo.md`.

## Relation to other specifications

- **ash-state-space.pseudo.md** — defines the state structure; references admissibility in its validity rule
- **control-bit-derivation.pseudo.md** — defines the derivation that applies after admissibility is confirmed
- **state-validity-diagnostics.pseudo.md** — consumes admissibility classification to populate diagnostic records

---

## Locked design decision — admissibility law (Design Package C)

> **STATUS: LOCKED**

### Canonical generator matrix

The admissible codeword set is generated by the following matrix over F2:

```text
G =
[1 1 1 1 0 0 0 0]
[1 1 0 0 1 1 0 0]
[1 0 1 0 1 0 1 0]
[1 1 1 1 1 1 1 1]
```

Because this code is **self-dual** in the chosen presentation, the same row space may also be used as a parity-check matrix for specification purposes:

```text
H = G
```

### Normative admissible codeword set

The complete row-space of G consists of exactly **16 codewords**:

```text
00000000
00001111
00110011
00111100
01010101
01011010
01100110
01101001
10010110
10011001
10100101
10101010
11000011
11001100
11110000
11111111
```

This codeword set is **normative**. The Apple implementation may internally use an equivalent matrix representation only if it generates **exactly this same 16-codeword set** and therefore preserves the same admissibility, correction, and corrected-core semantics.

### Locked code properties

| Property | Value |
|---|---|
| Code length | 8 |
| Dimension | 4 |
| Minimum distance | 4 |
| Weight set | {0, 4, 8} |
| Doubly-even | Yes — all codeword weights are divisible by 4 |
| Even overall parity | Yes — all codewords have even parity |
| Number of codewords | 16 |

### Deterministic correction consequence

| Hamming distance to nearest codeword | Classification | Recovery path |
|---|---|---|
| 0 | `ADMISSIBLE` | None needed |
| 1 | `INADMISSIBLE_CORRECTABLE` | Unique nearest codeword; correct and re-derive control |
| 2 | `INADMISSIBLE_DETECTABLE` | Detected but correction ambiguous; fallback required |
| ≥ 3 | `INADMISSIBLE_UNRECOVERABLE` | Beyond reliable correction; safe failure required |

### What Apple implementation modules must do

1. Implementations must use **exactly this normative 16-codeword set** for admissibility classification.
2. Implementations must not substitute a different codeword set, generator matrix, or code structure.
3. Implementations must not treat the admissibility law as an open or configurable choice.
4. An equivalent matrix representation is permitted only if it generates the identical 16-codeword set and preserves all distance, correction, and admissibility semantics.
