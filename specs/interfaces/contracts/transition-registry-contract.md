> Historical reference retained from the pre-SDK Apple baseline. For SDK 1.0.0, current semantic authority is ASH-Pattern-System 1.0.0-rc.3 at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8. Current public-contract decisions override conflicting retained prose; see repository-root docs/sdk-authority-and-conformance.md.

# TransitionRegistry Contract — implementation contract (9D Research Baseline)

## Purpose

The `TransitionRegistry` module resolves and applies state transitions deterministically. It operates on full 9-bit states and uses XOR-by-codeword as the canonical transformation mechanism.

## Canonical responsibility

The `TransitionRegistry` module is the single authority for:

- resolving which transitions are available for a given state
- applying a selected transition to produce a new state
- ensuring transitions respect the codeword structure

## Required inputs

- A valid `AshState` (full 9-bit vector in F2^9)
- A transition identifier or codeword

## Required outputs

- A new `AshState` (full 9-bit vector, the result of applying the transition)
- Transition diagnostics when resolution or application fails

## Required behaviors

### Deterministic resolution
- Transition resolution must be deterministic — the same state and transition identifier always resolve to the same outcome

### XOR-by-codeword transformation
- The canonical transformation mechanism is `x' = x ⊕ c` where `c ∈ C ⊂ F2^9`
- Transitions operate on the full 9-bit state simultaneously
- There is no separate "apply to subset, then re-derive remainder" step

### Valid-state requirement
- Transitions should operate on valid states
- If an invalid state is provided, the registry must fail with a diagnostic

## Required diagnostics

- If transition resolution fails, produce a diagnostic conforming to `diagnostic-schema.md`
- Rule IDs must conform to `rule-id-taxonomy.md`

## Invariants

1. Transition resolution is deterministic
2. XOR-by-codeword produces a well-formed 9-bit state
3. `(x ⊕ c) ⊕ c = x` — applying the same codeword twice returns to the original state
4. Failed applicability checks return explainable diagnostics

## Prohibited shortcuts

- Must not decompose the state into sub-components for transformation
- Must not silently drop a failed transition
- Must not assume a specific exhaustive codeword set if research-baseline closure is pending

## Relation to other contracts and specifications

- `state-model-contract.md` — provides valid states consumed by TransitionRegistry
- `transition-system.pseudo.md` — transition semantics
- `codeword-transformation-semantics.pseudo.md` — canonical XOR-by-codeword operation
- `codeword-set.pseudo.md` — canonical codeword structure
- `ash-state-space.pseudo.md` — canonical F2^9 state definition
- `diagnostics-module-contract.md` — schema and taxonomy conformance
