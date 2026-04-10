# Repository Governance

## Repository role

This repository is the canonical semantic definition of the ASH Pattern System.
It is not a language implementation repository.

## Governance rules

### 1. Language neutrality

No programming language may be described as the canonical identity of the engine in this repository.

### 2. Platform neutrality

No operating system, runtime family, or device category may be described as the canonical platform identity of the engine in this repository.

### 3. Spec-first rule

Changes that affect semantics must be made in the specification documents first.
Implementation repositories must follow the specifications, not redefine them.

### 4. Pseudocode rule

When algorithmic examples are needed, use pseudocode unless a target-specific handoff explicitly requires implementation syntax.

### 5. Semantic clarity rule

A document is only complete if a downstream coding agent can determine:

- what the model means
- what invariants must hold
- what boundary separates planning from materialization
- what behaviors are prohibited

### 6. Standalone baseline rule

This repository stands on its own as a canonical agnostic baseline.
It should not depend on explanation through older implementation layouts.

### 7. State-layer closure discipline

Specifications that define foundational state-layer behavior (control-bit derivation, core admissibility, state-validity diagnostics) are authoritative.

Downstream implementation repositories must not:

- invent foundational semantics that are not defined in this repository
- substitute alternative values for locked algebraic definitions (the control-bit derivation formula and the admissibility codeword set are locked design decisions)
- guess values for any remaining unresolved items (e.g., fallback-policy registry)
- silently use placeholder values for unresolved items in production code
- treat convenience behavior as canonical if the specifications do not define it

If a specification marks a rule as an **unresolved item**, that item must be resolved by an explicit design decision recorded in this repository before any downstream implementation may treat it as settled. Locked design decisions (marked as **LOCKED** in the specs) are normative and must be implemented exactly.

## Admission rule for future files

A new file belongs in this repository only if it strengthens the semantic source of truth.
If it mainly expresses one platform's build, runtime, or packaging concerns, it belongs in a downstream implementation repository instead.

## GitHub governance agents

A sentinel agent layer is defined in `governance/github-agents-governance.md` and enforced via workflows under `.github/workflows/`. The agents detect canonical-repo boundary drift, guard the locked research-baseline math, block reintroduction of superseded canonical language, and provide a reusable conformance workflow for downstream repositories. The agents are gatekeepers only — they do not own or redefine canonical truth.
