# Invariant Specification — canonical verification requirements (9D Research Baseline)

## Purpose

This specification defines the **canonical invariant set** that the Apple implementation of the ASH Pattern System must verify. All invariants are grounded in the full 9-dimensional research baseline.

**Codeword-set closure**: The codeword set `C ⊂ F2^9` is fully closed — a [9, 4, 4] doubly-even linear code with 16 members, extracted from published research (see `specs/core/codeword-set.pseudo.md`). All codeword-dependent invariants can now be fully assessed against the specified set.

---

## INV-STATE — Full-state semantics

### INV-STATE-001
**Statement**: The ASH state is a full 9-bit vector in F2^9. All 9 coordinates participate in the algebraic structure.
**Test criterion**: State representation uses all 9 coordinates; no coordinate is excluded from processing.
**Source**: `ash-state-space.pseudo.md`

### INV-STATE-002
**Statement**: Normalization is deterministic — the same candidate state always produces the same result.
**Test criterion**: Repeated normalization calls with the same input produce identical outputs.
**Source**: `ash-state-space.pseudo.md`, `state-model-contract.md`

### INV-STATE-003
**Statement**: Normalization fails with a diagnostic for transformation-incompatible states — it does not silently produce a result.
**Test criterion**: Normalization of incompatible states produces a diagnostic failure, not a normalized state.
**Source**: `state-validity-diagnostics.pseudo.md`

---

## INV-CODEWORD — Codeword structure and transformation

### INV-CODEWORD-001
**Statement**: Codeword transformations are XOR-by-codeword: `x' = x ⊕ c` for `c ∈ C ⊂ F2^9`.
**Test criterion**: Every transformation applies coordinate-wise XOR on all 9 bits.
**Source**: `codeword-transformation-semantics.pseudo.md`

### INV-CODEWORD-002
**Statement**: Codeword transformations are deterministic and pure — same inputs always produce same outputs with no side effects.
**Test criterion**: Repeated applications with the same state and codeword produce identical results.
**Source**: `codeword-transformation-semantics.pseudo.md`

### INV-CODEWORD-003
**Statement**: Applying the same codeword twice returns to the original state: `(x ⊕ c) ⊕ c = x`.
**Test criterion**: For any state and codeword, double application is identity.
**Source**: `codeword-transformation-semantics.pseudo.md`

### INV-CODEWORD-004 (codeword-set-dependent)
**Statement**: The codeword set used by the implementation is grounded in the research baseline — no invented codewords.
**Test criterion**: Every codeword used by the implementation matches the research-baseline source.
**Note**: The codeword set is fully closed. Full verification against the complete 16-codeword set is required.
**Source**: `codeword-set.pseudo.md`

---

## INV-ADMISSIBILITY — State admissibility

### INV-ADMISSIBILITY-001
**Statement**: Admissibility classification is deterministic — the same state always maps to the same status.
**Test criterion**: Repeated classification calls produce identical results.
**Source**: `state-admissibility.pseudo.md`

### INV-ADMISSIBILITY-002
**Statement**: Every 9-bit vector maps to exactly one admissibility status (given a specified codeword set).
**Test criterion**: No state produces multiple or ambiguous statuses.
**Source**: `state-admissibility.pseudo.md`

---

## INV-REALM — Deterministic realm encoding

### INV-REALM-001
**Statement**: Realm encoding is deterministic — equal valid states produce equal realm encodings.
**Test criterion**: Repeated encoding calls with the same state produce identical results.
**Source**: `realm-identity.pseudo.md`, `realm-encoder-contract.md`

### INV-REALM-002
**Statement**: Realm encoding operates only on valid states — invalid states must be rejected with a diagnostic.
**Test criterion**: Encoding an invalid state produces a diagnostic failure.
**Source**: `realm-encoder-contract.md`

---

## INV-TRANS — Deterministic transition outcomes

### INV-TRANS-001
**Statement**: Equal input state + equal transition always produce equal output state.
**Test criterion**: Repeated transition applications produce identical results.
**Source**: `transition-system.pseudo.md`, `transition-registry-contract.md`

### INV-TRANS-002
**Statement**: Transitions operate on full 9-bit states via XOR-by-codeword.
**Test criterion**: Transition results match coordinate-wise XOR with the specified codeword.
**Source**: `transition-registry-contract.md`

---

## INV-TOPO — Deterministic topology generation

### INV-TOPO-001
**Statement**: Topology generation is deterministic with stable ordering and lineage.
**Test criterion**: Same input produces identical topology structure across invocations.
**Source**: `topology-expansion.pseudo.md`, `topology-generator-contract.md`

---

## INV-AXIOM — Stable axiom diagnostics

### INV-AXIOM-001
**Statement**: Every axiom evaluation produces a diagnostic record — no bare pass/fail.
**Test criterion**: Every evaluation call returns a diagnostic with rule IDs and explanation.
**Source**: `axiom-evaluator-contract.md`

---

## INV-RECOVERY — Stable recovery/fallback/containment behavior

### INV-RECOVERY-001
**Statement**: Recovery is deterministic — the same classification always produces the same recovery category.
**Test criterion**: `classify_recoverability` always returns the same result for the same class.
**Source**: `recoverability-semantics.pseudo.md`, `recovery-engine-contract.md`

### INV-RECOVERY-002
**Statement**: Fallback selection uses only the canonical fallback-policy registry.
**Test criterion**: Every fallback selection is traceable to a `policy_id` in the registry.
**Source**: `fallback-policy-registry.md`, `recovery-engine-contract.md`

### INV-RECOVERY-003
**Statement**: Escalation is monotonic — severity never decreases without external intervention.
**Test criterion**: The severity sequence in any recovery chain is non-decreasing.
**Source**: `recoverability-semantics.pseudo.md`

### INV-RECOVERY-004
**Statement**: No silent healing — every recovery action produces a diagnostic record.
**Test criterion**: Every recovery/fallback/containment/halt action produces at least one diagnostic.
**Source**: `recovery-engine-contract.md`

### INV-RECOVERY-005
**Statement**: SAFE_HALT is terminal — no transitions from SAFE_HALT.
**Test criterion**: Once in SAFE_HALT, no subsequent state transition succeeds.
**Source**: `containment-safe-failure-semantics.pseudo.md`

---

## INV-PLAN — Stable generation-plan structure

### INV-PLAN-001
**Statement**: Planning produces no side effects.
**Test criterion**: Planning completes without creating, modifying, or deleting any external resource.
**Source**: `generation-planner-contract.md`

### INV-PLAN-002
**Statement**: The plan is self-contained — the emitter needs only the plan.
**Test criterion**: The emitter can materialize from the plan without planner interaction.
**Source**: `generation-planner-contract.md`

---

## INV-BOUNDARY — Materialization-boundary conformance

### INV-BOUNDARY-001
**Statement**: GenerationPlanner does not emit artifacts.
**Test criterion**: No file, module, or service is created during planning.
**Source**: `generation-planner-contract.md`

### INV-BOUNDARY-002
**Statement**: ArtifactEmitter does not invent semantics not present in the plan.
**Test criterion**: Every emitted artifact is traceable to a plan element.
**Source**: `artifact-emitter-contract.md`

---

## INV-DIAG — Diagnostic conformance

### INV-DIAG-001
**Statement**: Every diagnostic record conforms to the shared `DiagnosticEnvelope` schema.
**Test criterion**: Every diagnostic has all required fields.
**Source**: `diagnostic-schema.md`, `diagnostics-module-contract.md`

### INV-DIAG-002
**Statement**: Every rule_id conforms to the canonical taxonomy pattern.
**Test criterion**: Every rule_id matches `{FAMILY}-{CATEGORY}-{NUMBER}`.
**Source**: `rule-id-taxonomy.md`

### INV-DIAG-003
**Statement**: The diagnostic chain is complete — every step produces a diagnostic with valid chain references.
**Test criterion**: Chain parent and root references are intact for any recovery sequence.
**Source**: `diagnostic-schema.md`

### INV-DIAG-004
**Statement**: No silent omission — diagnostics are never deferred, batched, or suppressed.
**Test criterion**: Every required diagnostic is emitted at the point of action.
**Source**: `diagnostics-module-contract.md`
