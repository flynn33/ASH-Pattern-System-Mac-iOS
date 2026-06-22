# Rule-ID Taxonomy — canonical specification (9D Research Baseline)

## Purpose

This specification defines the **canonical structure and governance for rule identifiers** across the ASH Pattern System repository.

Every diagnostic record must reference one or more rule IDs. Rule IDs provide traceability from a diagnostic back to the specific specification rule that was evaluated. This taxonomy ensures that rule IDs are consistent, unique, stable, and machine-parseable across all specifications and implementations.

This taxonomy is **canonical** (Design Package D). The Mac/iOS implementation must not invent local rule-ID formats.

## Canonical rule-ID pattern

```text
{FAMILY}-{CATEGORY}-{NUMBER}
```

Where:
- `{FAMILY}` is an uppercase token from the rule families list below
- `{CATEGORY}` is an uppercase token describing the rule category within the family
- `{NUMBER}` is a 3-digit zero-padded integer, monotonically increasing within the family-category pair

Example: `ASH-STATE-VALIDITY-001`

## Rule families

| Family | Scope | Source specification |
|---|---|---|
| `ASH-STATE` | State-space structure, validity, normalization | `ash-state-space.pseudo.md`, `state-validity-diagnostics.pseudo.md` |
| `ASH-CODEWORD` | Codeword structure, transformation, orbit membership | `codeword-set.pseudo.md`, `codeword-transformation-semantics.pseudo.md` |
| `ASH-ADMISSIBILITY` | Core admissibility, codeword classification, correction | `core-admissibility.pseudo.md` |
| `ASH-CLASSIFICATION` | System-state classification, class-to-action mapping | `system-state-classification.pseudo.md` |
| `ASH-RECOVERY` | Recoverability semantics, recovery actions | `recoverability-semantics.pseudo.md`, `recovery-fallback-semantics.pseudo.md` |
| `ASH-FALLBACK` | Fallback policy, candidate selection, registry | `fallback-policy-registry.md`, `recovery-fallback-semantics.pseudo.md` |
| `ASH-CONTAINMENT` | Containment triggers, containment behavior | `containment-safe-failure-semantics.pseudo.md` |
| `ASH-HALT` | Safe halt triggers, terminal state semantics | `containment-safe-failure-semantics.pseudo.md` |

## Numbering rules

1. Numbers are 3-digit zero-padded: `001`, `002`, ..., `999`.
2. Numbers are monotonically increasing within each family-category pair.
3. Gaps in numbering are permitted (e.g., if a rule is deprecated, its number is not reused).
4. Numbers must not restart or wrap within a family-category pair.

## Uniqueness rules

1. Every `{FAMILY}-{CATEGORY}-{NUMBER}` triple is globally unique across the entire repository.
2. No two rules may share the same identifier, even across different specifications.
3. If a rule is moved between specifications, its identifier must remain unchanged.

## Stability rules

1. Once a rule ID is assigned to a specific rule, it must not be reassigned to a different rule.
2. A rule may be deprecated (marked as deprecated in the source specification), but its ID must not be reused.
3. Rule IDs must remain stable across design packages and repository versions.
4. Renaming a rule's description or updating its semantics does not change its ID.

## Usage rules in diagnostics

1. Every diagnostic record must include at least one rule ID in its `rule_ids` field.
2. All rule IDs in diagnostics must conform to the canonical pattern.
3. Rule IDs must reference rules that are defined in the source specification listed in the rule families table.
4. A diagnostic may include multiple rule IDs when multiple rules were evaluated.
5. The ordering of rule IDs in the `rule_ids` list should reflect the order in which rules were evaluated.

## Extension rules for future phases

1. New rule families may be added in future design phases (e.g., `ASH-TOPOLOGY`, `ASH-AXIOM`, `ASH-GENERATION`).
2. Existing rule families must not be renamed or removed.
3. New categories may be added to existing families.
4. Existing categories must not be renamed within a family.
5. Extensions must be recorded in this file with the design package that introduced them.

## Example rule IDs

| Rule ID | Meaning | Source |
|---|---|---|
| `ASH-STATE-VALIDITY-001` | Core must be structurally admissible | `ash-state-space.pseudo.md` |
| `ASH-STATE-VALIDITY-002` | Control bit must be consistent with derivation rule | `ash-state-space.pseudo.md` |
| `ASH-CODEWORD-STRUCTURE-001` | Codeword set must be research-baseline grounded | `codeword-set.pseudo.md` |
| `ASH-ADMISSIBILITY-CLASSIFICATION-001` | Every F2^8 vector maps to exactly one admissibility class | `core-admissibility.pseudo.md` |
| `ASH-CLASSIFICATION-MAPPING-001` | Every state maps to exactly one system-state class | `system-state-classification.pseudo.md` |
| `ASH-RECOVERY-ACTION-001` | Recovery category is deterministic from state class | `recoverability-semantics.pseudo.md` |
| `ASH-FALLBACK-SELECTION-001` | Fallback must be selected from canonical registry | `fallback-policy-registry.md` |
| `ASH-CONTAINMENT-TRIGGER-001` | Containment entered due to fallback failure | `containment-safe-failure-semantics.pseudo.md` |
| `ASH-HALT-TRIGGER-001` | Safe halt entered due to containment breach | `containment-safe-failure-semantics.pseudo.md` |

## Relation to other specifications

- **diagnostic-schema.md** — requires that every diagnostic envelope include taxonomy-compliant rule IDs
- **state-validity-diagnostics.pseudo.md** — uses `ASH-STATE` family rule IDs
- **recovery-fallback-semantics.pseudo.md** — uses `ASH-RECOVERY` and `ASH-FALLBACK` family rule IDs
- **containment-safe-failure-semantics.pseudo.md** — uses `ASH-CONTAINMENT` and `ASH-HALT` family rule IDs
- **semantic-contracts.md** — requires Apple implementation modules to emit taxonomy-compliant rule IDs
