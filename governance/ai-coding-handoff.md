# AI Coding Handoff

> **Post-R3 status**: The ASH Pattern System is grounded in the **full 9-dimensional research baseline**. The contract and verification layers have been rebuilt on the 9D foundation (R3). The codeword set `C ⊂ F2^9` is fully closed — exact generators and exhaustive enumeration have been extracted from published research. The canonical semantic, contract, and verification layers are complete. The downstream build handoff template layer is active / in progress.

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
6. read `governance/repository-governance.md` and `governance/github-agents-governance.md` (the latter documents the sentinel agent layer that gates math-critical changes, blocks 8+1 reintroduction, and guards canonical-repo boundary drift)
7. confirm that the canonical specs use the full 9D research baseline (not the superseded 8+1 model)
8. confirm that the canonical semantic, contract, and verification layers are complete, that Phase 4 downstream handoff-template work is treated as active / in progress (not complete), and that no stale or superseded content is treated as current
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
- treat the superseded parity formula or the 8+1-era interpretation of the codeword set as canonical (the canonical codeword set is the [9, 4, 4] code in `F2^9` specified in `codeword-set.pseudo.md` — not the superseded [8,4,4] code with a derived 9th bit)
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

**Codeword-set closure**: The codeword set `C ⊂ F2^9` is fully closed. `C` is a [9, 4, 4] doubly-even linear code with 16 members, extracted from published research materials (see `specs/core/codeword-set.pseudo.md` for generators, exhaustive enumeration, and source grounding). Implementations must use exactly the specified 16-codeword set and must not invent or extend codewords.

## Design package status

- **R1 — Foundational Math Reset** — complete
- **R2 — State/Recovery Realignment** — complete
- **R3 — Contract and Verification Rebuild** — complete
- **Phase 4 — Platform Build Handoff** — active / in progress

## Downstream build handoff templates

The `handoff-templates/` directory contains downstream build handoff templates that define what each target-class implementation repository must contain.

**Coding agent workflow for downstream implementations:**

1. Read the canonical specifications, contracts, and verification requirements first
2. Read `handoff-templates/common-downstream-handoff-requirements.md` for universal handoff expectations
3. Read the appropriate target-class template (`desktop-`, `mobile-`, or `service-implementation-handoff-template.md`)
4. Use the template to structure the downstream repository, plan deliverables, and track conformance

Handoff templates constrain downstream repository structure and proof-of-conformance inputs. They do **not** override canonical specifications, contracts, or verification requirements. The canonical agnostic repository remains the semantic authority.

## Required delivery shape for implementation repos

A downstream implementation handoff should include, at minimum, all deliverables specified in `handoff-templates/common-downstream-handoff-requirements.md`:

- module mapping document
- verification report
- diagnostics conformance report
- materialization-boundary report
- deviation log
- acceptance judgment
