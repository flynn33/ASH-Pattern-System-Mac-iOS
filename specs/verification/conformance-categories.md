# Conformance Categories — canonical verification requirements (9D Research Baseline)

## Purpose

This specification groups the canonical invariants from `invariant-spec.md` into **5 conformance categories**. Each category represents a distinct verification bucket that the Apple implementation must satisfy.

**Open research-closure item**: Invariants that depend on the specific codeword set `C ⊂ F2^9` are marked in `invariant-spec.md`. Full verification of codeword-dependent invariants requires the codeword-set closure to be resolved.

---

## Category 1: Algebraic/State Conformance

### Scope
Verifies that the implementation correctly represents, normalizes, classifies, and validates full 9-bit ASH states using the research-baseline algebraic structure.

### Invariant families
- `INV-STATE-001` through `INV-STATE-003`
- `INV-ADMISSIBILITY-001` through `INV-ADMISSIBILITY-002`
- `INV-CODEWORD-001` through `INV-CODEWORD-004`

### Mac/iOS test requirement
1. State representation uses all 9 coordinates
2. Normalization is deterministic on full 9-bit states
3. Admissibility classification is deterministic and total
4. Codeword transformations use XOR on all 9 bits
5. Double application is identity

---

## Category 2: Recovery/Fallback/Containment Conformance

### Scope
Verifies that the implementation correctly executes recovery, fallback, containment, and safe-halt behavior using the 9D semantics and the canonical fallback-policy registry.

### Invariant families
- `INV-RECOVERY-001` through `INV-RECOVERY-005`

### Mac/iOS test requirement
1. Recovery category mapping is deterministic
2. Fallback uses only the canonical registry
3. Escalation is monotonic
4. Every recovery action produces a diagnostic
5. SAFE_HALT is terminal

---

## Category 3: Diagnostics Conformance

### Scope
Verifies that diagnostics conform to the shared schema, use taxonomy-compliant rule IDs, maintain chain integrity, and are never silently omitted.

### Invariant families
- `INV-DIAG-001` through `INV-DIAG-004`
- `INV-AXIOM-001`

### Mac/iOS test requirement
1. Every diagnostic has all required schema fields
2. Every rule_id matches the taxonomy pattern
3. Diagnostic chains are complete
4. No silent omission
5. Axiom evaluations produce explainable diagnostics

---

## Category 4: Generation/Materialization-Boundary Conformance

### Scope
Verifies that the implementation respects the locked materialization boundary between GenerationPlanner and ArtifactEmitter.

### Invariant families
- `INV-PLAN-001` through `INV-PLAN-002`
- `INV-BOUNDARY-001` through `INV-BOUNDARY-002`

### Mac/iOS test requirement
1. Planning produces no side effects
2. The plan is self-contained
3. The planner produces no artifacts
4. The emitter invents no semantics beyond the plan

---

## Category 5: Contract/Module Conformance

### Scope
Verifies that the implementation satisfies the per-module contracts for modules not fully covered by the other categories.

### Invariant families
- `INV-REALM-001` through `INV-REALM-002`
- `INV-TRANS-001` through `INV-TRANS-002`
- `INV-TOPO-001`

### Mac/iOS test requirement
1. Realm encoding is deterministic on full 9-bit states and rejects invalid states
2. Transitions are deterministic, use XOR-by-codeword on full 9-bit states
3. Topology generation is deterministic with stable ordering

---

## Category coverage rule

All 5 conformance categories are **required**. The Apple implementation must not skip any category. Partial coverage is not sufficient for conformance.

See `implementation-acceptance.md` for the full acceptance threshold.
