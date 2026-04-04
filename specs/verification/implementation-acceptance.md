# Implementation Acceptance — canonical verification requirements (9D Research Baseline)

## Purpose

This specification defines the **minimum acceptance threshold** for a downstream implementation to be considered conformant with the ASH Pattern System, grounded in the full 9D research baseline.

**Open research-closure item**: The codeword set `C ⊂ F2^9` is partially closed. Its algebraic structure is locked — `C` is a subgroup of `(F2^9, ⊕)`, established by the `T² = T` averaging-operator requirement. The exact generators and exhaustive enumeration remain pending extraction from published research. Acceptance for codeword-set-dependent invariants (marked in `invariant-spec.md`) applies to whatever codeword set is provided but cannot be fully assessed until the generators are specified. This does not block conformance judgment for all other invariants.

---

## Minimum acceptance conditions

A downstream implementation is **accepted as conformant** if and only if:

1. **All non-codeword-dependent invariants pass** — every invariant in `invariant-spec.md` that does not depend on the exhaustive codeword-set closure must be verified and must pass.

2. **Codeword-dependent invariants are satisfied for the provided codeword set** — if a codeword set is provided (even partial), the implementation must satisfy codeword-dependent invariants against that set.

3. **All 5 conformance categories are covered** — every category in `conformance-categories.md` must be represented in the test suite.

4. **Per-module contracts are satisfied** — every module contract in `specs/interfaces/contracts/` must be satisfied as grounded in the 9D baseline.

5. **Diagnostics are complete** — the diagnostic chain is conformant with the shared schema and taxonomy.

6. **Open research items are handled honestly** — if the codeword set is not fully specified, the implementation must handle `UNCLASSIFIED` admissibility status correctly and must not substitute an invented codeword set.

---

## Failure conditions

A downstream implementation is **non-conformant** if any of the following:

1. Any non-codeword-dependent invariant fails
2. Any conformance category is missing from the test suite
3. The implementation decomposes the 9-bit state into an 8-bit core + derived 9th bit for canonical processing
4. The materialization boundary is violated
5. Diagnostics are incomplete or non-conformant with the schema/taxonomy
6. Silent healing occurs (recovery without diagnostics)
7. The implementation invents codewords not grounded in the research baseline

---

## Non-waivable requirements

The following may **not be waived, deferred, or locally overridden**:

| Requirement | Source |
|---|---|
| Full F2^9 state space | `ash-state-space.pseudo.md` |
| XOR-by-codeword as canonical transformation | `codeword-transformation-semantics.pseudo.md` |
| Materialization boundary (planner/emitter separation) | `generation-planner-contract.md`, `artifact-emitter-contract.md` |
| Fallback-policy registry conformance | `fallback-policy-registry.md` |
| Diagnostic schema conformance | `diagnostic-schema.md` |
| Rule-ID taxonomy conformance | `rule-id-taxonomy.md` |
| SAFE_HALT terminal finality | `containment-safe-failure-semantics.pseudo.md` |
| Monotonic escalation | `recoverability-semantics.pseudo.md` |
| No 8+1 decomposition as canonical | R1 realignment decision |

---

## Acceptance judgment language

### CONFORMANT
All non-codeword-dependent invariants pass, all 5 categories are covered, all contracts are satisfied, diagnostics are complete, and open research items are handled honestly.

### CONFORMANT WITH CAVEATS
All of the above, plus: codeword-dependent invariants are satisfied for the provided codeword set, but the exact generators and exhaustive enumeration of `C` are not yet extracted from the research baseline. The caveat must state: "codeword-set generators and enumeration pending extraction from published research."

### NON-CONFORMANT
Any acceptance condition is not met. The judgment must include: failing invariants (by ID), failing categories, and recommendations for remediation.

### PARTIAL — not a valid judgment
There is no "partial conformance." An implementation is CONFORMANT, CONFORMANT WITH CAVEATS, or NON-CONFORMANT.

---

## Relation to other specifications

- `invariant-spec.md` — the canonical invariant set
- `conformance-categories.md` — the 5 verification buckets
- `semantic-contracts.md` — umbrella contract document
- `specs/interfaces/contracts/` — detailed module contracts
- `codeword-set.pseudo.md` — codeword-set closure status
