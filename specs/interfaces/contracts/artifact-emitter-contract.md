> Historical reference retained from the pre-SDK Apple baseline. For SDK 1.0.0, current semantic authority is ASH-Pattern-System 1.0.0-rc.3 at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8. Current public-contract decisions override conflicting retained prose; see repository-root docs/sdk-authority-and-conformance.md.

# ArtifactEmitter Contract — implementation contract (9D Research Baseline)

## Purpose

The `ArtifactEmitter` module materializes an abstract generation plan for a specific target platform or runtime. It is the materialization half of the locked **materialization boundary**: the emitter materializes, but does not invent semantics.

## Canonical responsibility

The `ArtifactEmitter` module is the single authority for:

- materializing a generation plan into target-specific artifacts (files, modules, services, etc.)
- preserving the semantic meaning of the plan during materialization
- producing emission diagnostics

## Required inputs

- A complete generation plan from `GenerationPlanner`
- Target platform/runtime configuration

## Required outputs

- Materialized artifacts (files, modules, services, etc.)
- Emission diagnostics

## Required behaviors

### Plan materialization only
- The emitter must materialize exactly what the plan specifies — no more, no less
- The emitter translates plan-level artifact descriptions into concrete platform-specific output
- The emitter must not add, remove, or modify semantic content that is not present in the plan

### Fidelity to plan semantics
- Every artifact must be traceable back to a plan element
- The emitter preserves the meaning of the plan rather than inventing new semantics
- If the plan specifies a module, the emitter produces that module — it does not decide on its own that a different module is needed

### No invention of missing semantics
- If the plan does not define a behavior, the emitter must not invent one
- If the plan is incomplete or ambiguous, the emitter must fail with a diagnostic rather than guess
- The emitter must not substitute local conventions, defaults, or assumptions for plan-defined semantics

### Explicit receipt of plan
- The emitter receives the complete plan from `GenerationPlanner`
- The emitter must not call back to the planner for additional information
- The plan is the sole interface between planner and emitter

## Required diagnostics

- Every emission must produce diagnostics conforming to `diagnostic-schema.md`
- Rule IDs must conform to `rule-id-taxonomy.md`
- Emission diagnostics must explain what was emitted and from which plan element
- If emission fails or the plan is incomplete, produce a diagnostic explaining the failure

## Invariants

1. Emission is deterministic — same plan and target configuration produce same artifacts
2. Every emitted artifact is traceable to a plan element
3. No semantics are invented beyond what the plan defines
4. The emitter operates solely from the plan — no callback to planner

## Prohibited shortcuts

- Must not invent semantics not present in the plan
- Must not skip plan elements during materialization
- Must not substitute local defaults for plan-defined behavior
- Must not call back to the planner for additional information
- Must not collapse planning and materialization into one step
- Must not treat the plan as optional or advisory

## Relation to other contracts and specifications

- `generation-planning.pseudo.md` — abstract generation planning semantics
- `generation-planner-contract.md` — produces the plan that the emitter materializes (the other half of the materialization boundary)
- `diagnostics-module-contract.md` — schema and taxonomy conformance requirements
