# AI Coding Handoff

> **Post-R3 status**: The ASH Pattern System is grounded in the **full 9-dimensional research baseline**. The contract and verification layers have been rebuilt on the 9D foundation (R3). The codeword set `C ⊂ F2^9` is partially closed — its algebraic structure (subgroup of `F2^9`) is locked, but exact generators and exhaustive enumeration remain pending extraction from published research.

## Purpose

This document tells a coding agent how to use this repository when building a target implementation.

The ASH Pattern System is a **resilient software semantics framework** grounded in the **full 9D ASH research math**. The canonical state space is F2^9 with 512 vertices, XOR-by-codeword transformations, an averaging operator with T²=T, and first-class branching semantics.

## Handoff rule

Treat this repository as the semantic authority.
Do not infer core semantics from convenience, local idiom, or language defaults.
The **research baseline** is canonical — not the superseded 8+1 drift formalization.

## Required coding-agent workflow

1. read `README.md`
2. read all files in `docs/`
3. read all files in `specs/core/`, paying particular attention to:
   - `ash-state-space.pseudo.md` — canonical F2^9 state definition (research baseline)
   - `codeword-set.pseudo.md` — canonical codeword structure (research baseline)
   - `state-admissibility.pseudo.md` — full 9-bit admissibility and validity
   - `state-validity-diagnostics.pseudo.md` — full 9D diagnostic model
   - `system-state-classification.pseudo.md` — system-state classes (9D terms)
   - `recoverability-semantics.pseudo.md` — recovery categories (9D terms)
   - Note: `control-bit-derivation.pseudo.md` and `core-admissibility.pseudo.md` are **superseded** historical files — do not treat as current authority
4. read all files in `specs/algorithms/`, paying particular attention to:
   - `recovery-fallback-semantics.pseudo.md` — deterministic recovery and fallback selection
   - `containment-safe-failure-semantics.pseudo.md` — containment and safe-failure behavior
5. read `specs/interfaces/semantic-contracts.md` and all files in `specs/interfaces/contracts/`
6. read `governance/repository-governance.md`
7. confirm that the canonical specs use the full 9D research baseline (not the superseded 8+1 model)
8. check for any remaining unresolved or pending-research-closure items
9. only then begin target-specific design and implementation planning

## What the coding agent must preserve

The coding agent must preserve:

- the ASH state space as **full F2^9** — all 9 coordinates participate in the algebraic structure
- XOR-by-codeword as the canonical state transformation mechanism
- research-baseline codeword structure (see `specs/core/codeword-set.pseudo.md`)
- full 9-bit state admissibility (see `specs/core/state-admissibility.pseudo.md`)
- deterministic normalization on full 9-bit states
- deterministic realm identity from full 9-bit states
- deterministic transition behavior via codeword transformations
- deterministic topology expansion
- full axiom diagnostics
- explicit separation between generation planning and materialization
- system-state classification (all 7 canonical classes) based on full-state diagnostics
- deterministic recoverability mapping (class-to-recovery-category)
- deterministic recovery and fallback behavior using codeword-based correction
- containment and safe-failure behavior
- diagnosable recovery — no silent healing

## What the coding agent must not do

The coding agent must not:

- reintroduce the superseded 8+1 decomposition (8-bit core + derived 9th bit) as canonical
- invent codewords not grounded in the research baseline
- treat the superseded parity formula or 16-codeword set as canonical
- make one platform's file structure into the system's identity
- replace semantic planning with direct side effects
- treat convenience behavior as canonical if the specs do not say so
- guess any foundational semantic that is explicitly marked as unresolved or pending research closure
- silently heal or mutate state without producing a diagnostic record
- skip containment when the recovery/fallback specifications require it
- allow a `FAILED` state to continue normal operations without escalation
- allow transitions from `SAFE_HALT` to any other state

## Canonical design decisions (Research Baseline — R1)

The following are canonical after Research Math Realignment R1:

- **State space** — full F2^9, 512 vertices, 9-bit states
- **Transformation** — XOR-by-codeword: `x' = x ⊕ c` where `c ∈ C ⊂ F2^9`
- **Averaging operator** — `T f(x) = (1/|C|) Σ f(x ⊕ c)` with `T² = T`
- **Branching** — first-class canonical capability
- **No derived 9th bit** — the 9th coordinate is not canonically a derived control/parity bit computed from the first 8

## Superseded design decisions (8+1 formalization)

The following are **superseded and not canonical** after R1:

- Control-bit derivation formula (`b8 = b0 ⊕ ... ⊕ b7`) — superseded
- 8-bit [8,4,4] core admissibility law — superseded
- Corrected-core derivation rule — superseded
The coding agent must not treat the superseded 8+1 formalization as authoritative for implementation.

## Rebuilt layers (post-R3)

The following layers have been **rebuilt on the 9D research baseline** and are authoritative:

- Contract layer (`specs/interfaces/semantic-contracts.md` and `specs/interfaces/contracts/`) — rebuilt in R3
- Verification layer (`specs/verification/`) — rebuilt in R3
- Diagnostic schema and rule-ID taxonomy — revalidated in R3

**Open research-closure item**: The codeword set `C ⊂ F2^9` is partially closed. The algebraic structure is locked: `C` is a subgroup of `(F2^9, ⊕)`, established by the `T² = T` averaging-operator requirement. The exact generators and exhaustive enumeration remain pending extraction from published research. Implementations must treat `C` as a single replaceable point of definition and must not invent or extend codewords beyond research-grounded vectors. Codeword-dependent features operate under CONFORMANT WITH CAVEATS acceptance (see `implementation-acceptance.md`).

## Design package status

- **R1 — Foundational Math Reset** — complete
- **R2 — State/Recovery Realignment** — complete
- **R3 — Contract and Verification Rebuild** — complete

## Required delivery shape for implementation repos

A downstream implementation handoff should include, at minimum:

- mapping from spec modules to implementation modules
- invariant-based test plan
- materialization boundary design
- diagnostics design
- target-runtime constraints
- packaging and build decisions for that target repo
