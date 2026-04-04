# Design Roadmap

## Goal

Move from the ASH research math baseline to implementation-ready handoff materials without collapsing the design into any single language or platform.

> **Research Math Realignment R1**: The foundational math has been reset to the full 9D ASH research baseline. Phases and packages built on the superseded 8+1 formalization are noted as such below. Later layers have been rebuilt in R2 and R3.

## Pre-realignment history

### Phase 1 through Phase 3 (superseded foundation)

The following phases were completed under the original 8+1 formalization. Their structural contributions (resilient software semantics, diagnostic schemas, contract framework, verification framework) remain valuable, but their **mathematical assumptions** (8-bit core + derived 9th control bit, [8,4,4] admissibility, parity formula) are **superseded** by the research math realignment.

- **Phase 1** — semantic foundation (state space, realm identity, transitions, topology, axioms, generation planning)
- **Phase 1.5 / Design Package A** — formal state layers (control-bit derivation, core admissibility, state-validity diagnostics) — **mathematical basis superseded by R1**
- **Phase 1.75 / Design Package B** — resilient software semantics (system-state classification, recoverability, recovery/fallback, containment/safe-failure) — **rewritten in R2**
- **Phase 1.85 / Design Package C** — algebraic locks (parity formula, [8,4,4] codeword set) — **superseded by R1**
- **Phase 1.9 / Design Package D** — registry and diagnostics layer (fallback-policy registry, diagnostic schema, rule-ID taxonomy) — **structural concepts preserved, invariants revalidated in R3**
- **Phase 2** — implementation contracts (9 module contracts, materialization boundary) — **rebuilt in R3**
- **Phase 3** — invariant-based verification requirements — **rebuilt in R3**

## Research math realignment sequence

### R1 — Foundational Math Reset (current)

Reset the canonical mathematical foundation to the full 9D ASH research baseline:

- **State space** — full F2^9 with 512 vertices/realms
- **Transformation** — XOR-by-codeword: `x' = x ⊕ c` for `c ∈ C ⊂ F2^9`
- **Averaging operator** — `T f(x) = (1/|C|) Σ f(x ⊕ c)` with `T² = T`
- **Branching** — first-class canonical capability

De-authorize the 8+1 drift formalization. Later layers were rebuilt in R2 and R3.

New specifications created:

- `specs/algorithms/codeword-transformation-semantics.pseudo.md`
- `specs/algorithms/averaging-operator-semantics.pseudo.md`
- `specs/algorithms/branching-semantics.pseudo.md`

Rewritten to research baseline:

- `specs/core/ash-state-space.pseudo.md`
- `specs/core/realm-identity.pseudo.md`
- `specs/algorithms/transition-system.pseudo.md`

**Status**: Complete.

### R2 — Rewrite state/recovery semantics against restored 9D baseline

Rewrite the state-layer and resilient-software semantics to operate on the full 9D model:

- Define validity and admissibility for full 9-bit states under the research codeword structure
- Rewrite state-validity diagnostics for the 9D model
- Rewrite system-state classification, recoverability, recovery/fallback/containment against the 9D baseline
- Formalize the specific codeword set `C ⊂ F2^9` from the research baseline

New specifications created:

- `specs/core/codeword-set.pseudo.md`
- `specs/core/state-admissibility.pseudo.md`

Rewritten to full 9D terms:

- `specs/core/state-validity-diagnostics.pseudo.md`
- `specs/core/system-state-classification.pseudo.md`
- `specs/core/recoverability-semantics.pseudo.md`
- `specs/algorithms/recovery-fallback-semantics.pseudo.md`

Cleaned of authoritative 8+1 mandates:

- `specs/interfaces/semantic-contracts.md`
- `governance/ai-coding-handoff.md`

**Status**: Complete. State/recovery semantics are now grounded in the full 9D research baseline.

### R3 — Rebuild contracts and verification after math realignment

Rebuild the contract and verification layers on the revalidated 9D foundation:

- Revalidate or rewrite all 9 module contracts against the 9D model
- Revalidate or rewrite the diagnostic schema and rule-ID taxonomy
- Revalidate or rewrite the invariant specification, conformance categories, and acceptance criteria
- Confirm that the materialization boundary, fallback-policy registry, and other structural contributions from the original phases remain valid or are updated

Rebuilt/revalidated:

- All 9 detailed module contracts in `specs/interfaces/contracts/`
- `specs/interfaces/semantic-contracts.md` (umbrella, authority status clarified)
- `specs/interfaces/diagnostic-schema.md` (revalidated for 9D)
- `specs/interfaces/rule-id-taxonomy.md` (revalidated for 9D)
- `specs/verification/invariant-spec.md` (rebuilt on 9D terms)
- `specs/verification/conformance-categories.md` (rebuilt on 9D terms)
- `specs/verification/implementation-acceptance.md` (rebuilt on 9D terms with honest codeword-set handling)

**Status**: Complete. The contract and verification layers are now authoritative for the full 9D research baseline. The codeword set is partially closed — established as a subgroup of `(F2^9, ⊕)`, with exact generators and exhaustive enumeration pending extraction from published research. Codeword-dependent acceptance uses CONFORMANT WITH CAVEATS posture.

### Phase 4 — create platform build handoff packages

For each target implementation repo, the coding agent should receive:

- this repository (post-R3, fully revalidated)
- target platform constraints
- target language constraints
- runtime constraints
- packaging constraints
- performance constraints if applicable

**Status**: Ready to begin. The codeword set's algebraic structure (subgroup of `F2^9`) is locked. Platform handoff may proceed under CONFORMANT WITH CAVEATS acceptance posture for codeword-dependent features until the exact generators and exhaustive enumeration are extracted from published research.

## Immediate next design step

R1, R2, and R3 are complete. The contract and verification layers are rebuilt on the 9D research baseline.

The immediate next steps are:

1. **Complete codeword-set closure** — extract the exact generators and exhaustive enumeration of `C ⊂ F2^9` from the published research materials into `specs/core/codeword-set.pseudo.md`. The algebraic structure (subgroup of `F2^9`) is already locked; the remaining work is extraction from published sources, not discovery
2. **Begin Phase 4** — create platform build handoff packages (may proceed now under CONFORMANT WITH CAVEATS acceptance for codeword-dependent features)
