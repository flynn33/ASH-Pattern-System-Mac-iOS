> Historical reference retained from the pre-SDK Apple baseline. For SDK 1.0.0, current semantic authority is ASH-Pattern-System 1.0.0-rc.3 at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8. Current public-contract decisions override conflicting retained prose; see repository-root docs/sdk-authority-and-conformance.md.

# RealmEncoder Contract — implementation contract (9D Research Baseline)

## Purpose

The `RealmEncoder` module encodes realm identity from a full 9-bit ASH state. It translates the algebraic state representation into a realm-level identity that preserves the semantic structure of the state model.

## Canonical responsibility

The `RealmEncoder` module is the single authority for:

- encoding realm identity from a valid full 9-bit ASH state
- producing deterministic, reproducible realm encodings
- rejecting invalid or unclassified states with a diagnostic

## Required inputs

- A valid `AshState` (full 9-bit vector in F2^9)

## Required outputs

- A deterministic realm identity encoding

## Required behaviors

### Deterministic encoding
- The same state must always produce the same realm encoding
- Encoding must be reproducible across platforms, implementations, and execution contexts

### Valid-state requirement
- The encoder must only accept valid states as input
- If an invalid or unclassified state is provided, the encoder must fail with a diagnostic
- The encoder must not attempt normalization itself — that is the responsibility of `StateModel`

### Full-state encoding
- All 9 coordinates of the state participate in the identity encoding
- The encoding must not decompose the state into sub-components for encoding purposes

## Required diagnostics

- If encoding fails (e.g., invalid input state), produce a diagnostic conforming to `diagnostic-schema.md`
- Rule IDs must conform to `rule-id-taxonomy.md`

## Invariants

1. Encoding is deterministic — equal inputs produce equal outputs
2. Encoding operates only on valid states
3. All 9 coordinates participate in the encoding

## Prohibited shortcuts

- Must not encode from an invalid or unclassified state
- Must not silently produce a default encoding when input is invalid
- Must not decompose the 9-bit state for encoding purposes

## Relation to other contracts and specifications

- `state-model-contract.md` — provides valid states consumed by RealmEncoder
- `realm-identity.pseudo.md` — realm identity semantics
- `ash-state-space.pseudo.md` — canonical F2^9 state definition
- `diagnostics-module-contract.md` — schema and taxonomy conformance
