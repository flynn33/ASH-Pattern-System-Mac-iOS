> Historical reference retained from the pre-SDK Apple baseline. For SDK 1.0.0, current semantic authority is ASH-Pattern-System 1.0.0-rc.3 at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8. Current public-contract decisions override conflicting retained prose; see repository-root docs/sdk-authority-and-conformance.md.

# Branching Semantics — canonical specification

## Purpose

This specification defines **branching and leaf expansion** as a **first-class canonical capability** of the ASH Pattern System, grounded in the research baseline.

Branching is not an optional decoration or a secondary feature. It is a fundamental aspect of the ASH model's generative and structural behavior.

## Canonical status

Branching / leaf expansion is **canonical and first-class** in the ASH Pattern System. It must be treated as an integral part of the system's semantics, not as an add-on or implementation convenience.

## Branching concept

In the research baseline, branching refers to the process by which the ASH state structure expands through **decoherence-tree** or **L-system style** generative processes:

- A state (vertex) in the ASH state space may serve as a **branch point** from which new structural elements emerge
- The branching process is governed by the algebraic structure of the state space and the codeword set
- Branching produces **leaf nodes** — terminal or expandable elements in the generative tree
- The branching structure encodes the system's capacity for growth, diversification, and hierarchical organization

## Relation to the ASH state space

- Branching operates within the canonical F2^9 state space
- Branch points are states (9-bit vertices) from which expansion occurs
- The branching topology is determined by the codeword structure and the state's position in the algebraic lattice
- Branching preserves the algebraic properties of the state space — it does not introduce states outside F2^9

## Relation to codeword transformations

- Codeword transformations (`x' = x ⊕ c`) define the motion between states
- Branching uses the codeword structure to determine how expansion proceeds from a given state
- The relationship between branching and codeword orbits is a key structural property of the ASH model

## Relation to the averaging operator

- The averaging operator projects functions onto C-invariant subspaces
- Branching behavior may interact with the invariant structure identified by the averaging operator
- The precise interaction between branching and averaging is part of the deeper ASH model semantics defined in the research baseline

## Platform-neutral semantics

This specification defines branching at the semantic level only:

- **What** branching means in the ASH model
- **That** branching is first-class and canonical
- **How** branching relates to the state space, codewords, and averaging operator

This specification does not define:

- How branching is implemented in any particular language or platform
- What data structures represent the branching tree
- How branching is rendered, visualized, or materialized

## Invariants

1. **First-class status**: branching must not be treated as optional or secondary in any ASH implementation
2. **Algebraic consistency**: branching must respect the algebraic structure of F2^9 and the codeword set
3. **Determinism**: for the same state and codeword structure, branching must produce the same expansion

## Boundaries of this specification

This specification establishes branching as a canonical first-class capability and defines its relationship to the rest of the ASH model. The detailed branching algorithms, expansion rules, and tree-structure semantics will be formalized in later realignment packages (R2) as the full research baseline is integrated.

## Relation to other specifications

- **codeword-set.pseudo.md** — defines the codeword set whose structure governs branching topology
- **ash-state-space.pseudo.md** — defines the canonical F2^9 state space in which branching occurs
- **codeword-transformation-semantics.pseudo.md** — defines the codeword operations that govern branching expansion
- **averaging-operator-semantics.pseudo.md** — defines the averaging operator whose invariant structure interacts with branching
