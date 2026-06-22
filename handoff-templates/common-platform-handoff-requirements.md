# Common Apple Platform Handoff Requirements

## Purpose

This document defines the shared implementation requirements used by the Mac/iOS edition of the ASH Pattern System.

## Semantic Boundary

The Mac/iOS edition implements the APS semantic contract files under `specs/`. This requirements document constrains repository structure, required deliverables, and proof-of-conformance inputs for Apple platforms. It does not define new semantics.

Specifically:

- `specs/core/` and `specs/algorithms/` define APS behavior.
- `specs/interfaces/contracts/` defines module responsibilities.
- `specs/registries/` defines policy-driven behavior.
- `specs/verification/` defines what must be proven.
- `specs/interfaces/diagnostic-schema.md` and `specs/interfaces/rule-id-taxonomy.md` define diagnostic structure.

## Required Semantic-Module Mapping

The Mac/iOS edition must map each of the 9 APS semantic modules to a concrete Swift implementation module:

| APS module | Apple implementation must provide |
|---|---|
| `StateModel` | Full 9-bit state representation, normalization, admissibility, diagnostics, classification, recoverability |
| `RecoveryEngine` | Codeword-based recovery, registry-driven fallback, containment, safe halt, monotonic escalation |
| `RealmEncoder` | Deterministic realm identity encoding from valid 9-bit states |
| `TransitionRegistry` | XOR-by-codeword transition resolution and application |
| `TopologyGenerator` | Deterministic topology generation with stable ordering and lineage |
| `AxiomEvaluator` | Explainable axiom evaluation with diagnostic records |
| `GenerationPlanner` | Abstract plan production with no side effects |
| `ArtifactEmitter` | Plan materialization with no semantic invention |
| `Diagnostics` | Schema-conformant diagnostics with taxonomy-compliant rule IDs |

The mapping is documented in `completion-evidence/architecture-inventory.md` and `completion-evidence/ios/architecture-inventory.md`.

## Required Verification Inputs

The Mac/iOS edition must include verification evidence that addresses:

- all invariants defined in `specs/verification/invariant-spec.md`;
- all 5 conformance categories defined in `specs/verification/conformance-categories.md`;
- acceptance criteria defined in `specs/verification/implementation-acceptance.md`;
- SwiftPM build/test evidence;
- Xcode package-scheme evidence for macOS and iOS;
- platform release gates for signing, archives, distribution, accessibility, and device/simulator validation.

## Diagnostics Integration Expectations

The Swift implementation must:

- produce diagnostics conforming to `specs/interfaces/diagnostic-schema.md`;
- use rule IDs conforming to `specs/interfaces/rule-id-taxonomy.md`;
- maintain diagnostic chain integrity from detection through terminal halt;
- never silently omit diagnostics.

## Materialization-Boundary Expectations

The Swift implementation must respect the locked materialization boundary:

- `ASHGenerationPlanner` plans; it does not emit artifacts or perform side effects.
- `ASHArtifactEmitter` materializes from a plan; it does not invent semantics.
- The plan is the sole interface between planner and emitter.

## Packaging / Build / Deployment Decisions

The Mac/iOS edition must document:

- Swift tools version and package products;
- minimum supported platform versions;
- Xcode package-scheme build evidence;
- signing and entitlement status;
- notarization, App Store, and TestFlight status;
- simulator, device, install, upgrade, removal, and accessibility status.

## Performance / Resource Constraints

The Mac/iOS edition must document:

- memory and allocation expectations;
- startup behavior;
- CPU bounds for core operations;
- storage behavior;
- iOS battery, thermal, and lifecycle constraints when app targets exist;
- macOS install and launch constraints when app targets exist.

## Caveat / Deviation Tracking

The Mac/iOS edition must maintain evidence for:

- platform limitations that affect release claims;
- unresolved release blockers;
- Apple-specific decisions that require evidence before release.

Deviations from APS behavior require explicit documentation and must not be silently introduced.

## Proof-Of-Conformance Deliverables

Before the Mac/iOS product can move beyond its current blocked release status, the repository must produce:

1. module mapping evidence;
2. SwiftPM build and test evidence;
3. Xcode package-scheme evidence for macOS and iOS;
4. diagnostics conformance evidence;
5. materialization-boundary evidence;
6. deviation and blocker evidence;
7. acceptance judgment for macOS and iOS;
8. signing, archive, distribution, install, accessibility, security, and release evidence.
