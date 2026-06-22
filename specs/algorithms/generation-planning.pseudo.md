# Generation Planning - APS Semantic Contract

## Purpose

The generation layer converts ASH semantics into an **abstract generation plan**.
It does not directly perform platform side effects.

## Core planning idea

The engine first computes what should exist.
A platform adapter later decides how that should be materialized.

## Canonical records

```text
TYPE GenerationRequest
    project_name: String
    seed_state: AshState
    transition_sequence: List<String>
    topology_depth: Integer
    profile_id: String
    naming_policy_id: String
    emission_target_kind: String
END TYPE
```

```text
TYPE GenerationPlan
    normalized_state: AshState
    source_realm: RealmIdentity
    destination_realm: RealmIdentity
    topology_nodes: List<TopologyNode>
    role_assignments: List<RoleAssignment>
    axiom_diagnostic: AxiomDiagnostic
    artifacts: List<ArtifactDescription>
    warnings: List<String>
    metadata: Map
END TYPE
```

## Pseudocode

```text
FUNCTION generate_plan(request: GenerationRequest) -> GenerationPlan
    plan.normalized_state = normalize_state(request.seed_state)
    plan.source_realm = encode_realm_identity(plan.normalized_state)

    transformed_state = apply_transition_chain(
        plan.normalized_state,
        resolve_transition_sequence(request.transition_sequence)
    )

    plan.destination_realm = encode_realm_identity(transformed_state)
    plan.topology_nodes = generate_topology(request.topology_depth)
    plan.role_assignments = assign_roles(plan.topology_nodes, request.profile_id)

    candidate_subject = build_axiom_subject(
        transformed_state,
        plan.topology_nodes,
        plan.role_assignments
    )

    plan.axiom_diagnostic = diagnose_axioms(candidate_subject)
    plan.artifacts = describe_artifacts(
        request.emission_target_kind,
        request.project_name,
        plan.role_assignments
    )

    IF plan.axiom_diagnostic.overall_pass == false THEN
        plan.warnings = derive_generation_warnings(plan.axiom_diagnostic)
    END IF

    plan.metadata = build_plan_metadata(request)
    RETURN plan
END FUNCTION
```

## Materialization boundary

A platform adapter is responsible for converting a `GenerationPlan` into concrete outputs such as:

- files
- directories
- modules
- packages
- services
- views
- manifests

That boundary must remain explicit.

## Required invariants

1. planning precedes side effects
2. equal request => equal plan, assuming identical registries and policies
3. axiom diagnostics are included in the plan
4. planning semantics are portable across implementations
