# Contracts and Verification

The Mac/iOS edition is conformant only when module contracts and verification thresholds are both satisfied.

## Required Semantic Modules

| Module | Contract file |
|---|---|
| StateModel | `specs/interfaces/contracts/state-model-contract.md` |
| RealmEncoder | `specs/interfaces/contracts/realm-encoder-contract.md` |
| TransitionRegistry | `specs/interfaces/contracts/transition-registry-contract.md` |
| TopologyGenerator | `specs/interfaces/contracts/topology-generator-contract.md` |
| AxiomEvaluator | `specs/interfaces/contracts/axiom-evaluator-contract.md` |
| GenerationPlanner | `specs/interfaces/contracts/generation-planner-contract.md` |
| ArtifactEmitter | `specs/interfaces/contracts/artifact-emitter-contract.md` |
| Diagnostics | `specs/interfaces/contracts/diagnostics-module-contract.md` |
| RecoveryEngine | `specs/interfaces/contracts/recovery-engine-contract.md` |

## Materialization Boundary (Locked)

- `GenerationPlanner`: computes abstract plan, no side effects.
- `ArtifactEmitter`: materializes plan output, no semantic invention.
- Plan is the only interface between planner and emitter.

## Verification Categories

All five categories are required for conformance:

1. Algebraic/state conformance
2. Recovery/fallback/containment conformance
3. Diagnostics conformance
4. Generation/materialization-boundary conformance
5. Contract/module conformance

## Acceptance Judgments

Only these are valid:

- `CONFORMANT`
- `CONFORMANT WITH CAVEATS`
- `NON-CONFORMANT`

## Conformance Gate Summary

The Mac/iOS edition is accepted only if all invariants pass, all five categories are covered, contracts are satisfied, and diagnostics are complete.

## References

- `specs/interfaces/semantic-contracts.md`
- `specs/verification/invariant-spec.md`
- `specs/verification/conformance-categories.md`
- `specs/verification/implementation-acceptance.md`
