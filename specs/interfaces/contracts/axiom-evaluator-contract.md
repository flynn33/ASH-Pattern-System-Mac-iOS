# AxiomEvaluator Contract — implementation contract (9D Research Baseline)

## Purpose

The `AxiomEvaluator` module evaluates axioms against the current state and returns a full, explainable diagnostic record. It ensures that axiom evaluation is never opaque — every result must be accompanied by a clear explanation.

## Canonical responsibility

The `AxiomEvaluator` module is the single authority for:

- evaluating axioms against the current state or context
- producing full diagnostic records that explain evaluation results
- ensuring that axiom evaluation is explainable, not just pass/fail

## Required inputs

- The state or context against which axioms are evaluated
- The set of axioms to evaluate

## Required outputs

- A full diagnostic record for each axiom evaluated
- Diagnostic notes explaining why each axiom passed or failed

## Required behaviors

### Full diagnostic output
- Every axiom evaluation must produce a diagnostic record — not just a boolean pass/fail
- The diagnostic must include the axiom identifier, the evaluation result, and a human-readable explanation

### Explainable results
- Pass results must explain what conditions were satisfied
- Fail results must explain what conditions were violated and why
- The explanation must be sufficient for a human operator or receiving system to understand the result

### No silent pass/fail
- The evaluator must never return a bare boolean without an accompanying diagnostic
- Silent pass is prohibited — even a passing axiom must produce a diagnostic record confirming the pass

## Required diagnostics

- Every evaluation produces a diagnostic conforming to `diagnostic-schema.md`
- Rule IDs must conform to `rule-id-taxonomy.md`
- Diagnostic notes must include the axiom identifier and explanation

## Invariants

1. Every axiom evaluation produces a diagnostic record
2. Results are explainable — pass and fail both include explanations
3. No silent pass/fail — bare booleans without diagnostics are prohibited
4. Evaluation is deterministic — same inputs produce same results

## Prohibited shortcuts

- Must not return bare pass/fail without diagnostics
- Must not silently skip axiom evaluation
- Must not suppress failure diagnostics
- Must not produce unexplained results

## Relation to other contracts and specifications

- `axiom-evaluation.pseudo.md` — axiom evaluation semantics
- `state-model-contract.md` — provides state context for evaluation
- `diagnostics-module-contract.md` — schema and taxonomy conformance requirements
