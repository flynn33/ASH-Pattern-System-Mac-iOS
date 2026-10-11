> Historical reference retained from the pre-SDK Apple baseline. For SDK 1.0.0-rc.1, current semantic authority is ASH-Pattern-System 1.0.0-rc.3 at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8. Current public-contract decisions override conflicting retained prose; see repository-root docs/sdk-authority-and-conformance.md.

# TopologyGenerator Contract — implementation contract (9D Research Baseline)

## Purpose

The `TopologyGenerator` module generates deterministic ternary topology from the ASH state model. It produces stable, ordered topology structures that preserve lineage relationships.

## Canonical responsibility

The `TopologyGenerator` module is the single authority for:

- generating deterministic ternary topology from normalized state
- preserving stable ordering across topology elements
- preserving lineage relationships within generated topology

## Required inputs

- Normalized `AshState` or state-derived context for topology generation

## Required outputs

- A deterministic ternary topology structure
- Topology diagnostics when generation fails or encounters invalid conditions

## Required behaviors

### Deterministic generation
- The same input state must always produce the same topology structure
- Topology generation must be reproducible across platforms, implementations, and execution contexts

### Stable ordering
- Topology elements must be ordered deterministically
- The ordering must not depend on platform-specific behavior, randomness, or execution order

### Stable lineage
- Lineage relationships between topology elements must be preserved and stable
- Lineage must not vary across invocations with the same input

### Diagnostics for invalid operations
- If topology generation encounters an invalid condition (e.g., state not suitable for topology expansion), produce a diagnostic
- Diagnostics must conform to `diagnostic-schema.md`

## Required diagnostics

- Diagnostics for rejected or invalid topology operations
- Rule IDs must conform to `rule-id-taxonomy.md`
- No silent omission of topology errors

## Invariants

1. Topology generation is deterministic
2. Ordering is stable and reproducible
3. Lineage is preserved across invocations
4. Invalid conditions produce diagnostics, not silent failures

## Prohibited shortcuts

- Must not produce non-deterministic topology
- Must not allow ordering to depend on platform-specific behavior
- Must not silently skip invalid conditions

## Relation to other contracts and specifications

- `state-model-contract.md` — provides normalized states consumed by TopologyGenerator
- `topology-expansion.pseudo.md` — topology generation semantics
- `diagnostics-module-contract.md` — schema and taxonomy conformance requirements
