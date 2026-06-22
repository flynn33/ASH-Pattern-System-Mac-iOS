# Axiom Evaluation - APS Semantic Contract

## Purpose

The axiom evaluator determines whether a candidate ASH subject satisfies the engine's five axiom requirements and returns an explainable diagnostic.

## Canonical axiom set

The engine evaluates the following five axioms:

1. relational existence
2. structural compressibility
3. multi-scale persistence
4. energetic cost of erasure
5. self-reference for consciousness

## Diagnostic model

```text
TYPE AxiomDiagnostic
    a1_relational_existence: Boolean
    a2_structural_compressibility: Boolean
    a3_multi_scale_persistence: Boolean
    a4_energetic_cost_of_erasure: Boolean
    a5_self_reference_for_consciousness: Boolean
    overall_pass: Boolean
    notes: List<String>
END TYPE
```

## Pseudocode

```text
FUNCTION diagnose_axioms(subject) -> AxiomDiagnostic
    diag.a1_relational_existence = (subject.relation_count > 0)
    diag.a2_structural_compressibility = (subject.compressed_measure < subject.raw_measure)
    diag.a3_multi_scale_persistence = (subject.scale_count > 1)
    diag.a4_energetic_cost_of_erasure = (subject.erasure_cost > 0)
    diag.a5_self_reference_for_consciousness = (
        subject.self_reference_capable == true AND
        subject.self_model_available == true
    )

    diag.overall_pass = (
        diag.a1_relational_existence AND
        diag.a2_structural_compressibility AND
        diag.a3_multi_scale_persistence AND
        diag.a4_energetic_cost_of_erasure AND
        diag.a5_self_reference_for_consciousness
    )

    diag.notes = explanatory_messages(diag)
    RETURN diag
END FUNCTION
```

## Contract rule

The evaluator must return the full diagnostic structure, not only a pass/fail boolean.

## Separation rule

This specification defines the semantics of the checks.
It does not define whether enforcement happens at compile time, runtime, static analysis time, or generation-planning time.

## Required invariants

1. equal candidate subject => equal diagnostic
2. overall pass derives from the five component checks
3. diagnostics are explainable
