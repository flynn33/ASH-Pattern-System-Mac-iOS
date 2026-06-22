# GenerationPlanner Contract — implementation contract (9D Research Baseline)

## Purpose

The `GenerationPlanner` module produces an abstract, inspectable generation plan before any side effects occur. It is the planning half of the locked **materialization boundary**: the planner plans, but does not emit artifacts.

## Canonical responsibility

The `GenerationPlanner` module is the single authority for:

- producing an abstract generation plan from the current state, topology, and axiom evaluations
- ensuring the plan is target-aware but non-materialized
- ensuring the plan is inspectable before materialization
- handing off the plan to `ArtifactEmitter` for materialization

## Required inputs

- Normalized `AshState`
- Generated topology (from `TopologyGenerator`)
- Axiom evaluation results (from `AxiomEvaluator`)
- Target platform/runtime constraints (abstract, not implementation-specific)

## Required outputs

- An abstract generation plan containing:
  - topology structure
  - role assignments
  - axiom diagnostic summaries
  - artifact descriptions (what should be emitted, not the artifacts themselves)
  - target-awareness metadata (platform constraints, runtime constraints)
- Plan diagnostics

## Required behaviors

### Abstract planning
- The plan must describe what should be materialized without actually materializing it
- The plan must be a complete, self-contained specification of the intended output
- The plan must be inspectable — a human or receiving system must be able to review it before materialization

### Target-aware but non-materialized
- The plan may incorporate target platform/runtime constraints to shape artifact descriptions
- The plan must not produce any actual files, modules, services, or runtime artifacts
- Target awareness means the plan knows what kind of artifact is needed, not that it produces the artifact

### No side effects
- The planner must not write files, create directories, start processes, or perform any observable side effect
- The planner must not emit artifacts — that is the exclusive responsibility of `ArtifactEmitter`
- If a side effect occurs during planning, the implementation is nonconformant

### Explicit handoff boundary
- The plan is the complete interface between `GenerationPlanner` and `ArtifactEmitter`
- `ArtifactEmitter` must be able to materialize entirely from the plan without calling back to the planner
- The planner must not retain state that the emitter needs but the plan does not contain

## Required diagnostics

- Plan generation must produce diagnostics conforming to `diagnostic-schema.md`
- Rule IDs must conform to `rule-id-taxonomy.md`
- Plan-level diagnostics must explain what was planned and why

## Invariants

1. Planning is deterministic — same inputs produce same plan
2. Planning produces no side effects
3. The plan is self-contained — the emitter needs only the plan
4. The plan is inspectable before materialization
5. The handoff boundary is complete — nothing is left implicit

## Prohibited shortcuts

- Must not emit artifacts directly
- Must not perform side effects
- Must not produce a plan that requires the emitter to call back to the planner
- Must not leave the plan incomplete or implicit
- Must not collapse planning and materialization into one step

## Relation to other contracts and specifications

- `generation-planning.pseudo.md` — abstract generation planning semantics
- `artifact-emitter-contract.md` — receives the plan and materializes it (the other half of the materialization boundary)
- `state-model-contract.md` — provides normalized state
- `topology-generator-contract.md` — provides topology
- `axiom-evaluator-contract.md` — provides axiom evaluation results
- `diagnostics-module-contract.md` — schema and taxonomy conformance requirements
