# Containment and Safe-Failure Semantics - APS Semantic Contract

## Purpose

This specification defines the **algorithmic semantics of containment and safe failure** for the ASH Pattern System.

The ASH Pattern System is a framework for resilient software. Resilience does not mean that every error is correctable. It means that the system has a defined, deterministic response for every condition — including conditions where correction is impossible and the only safe action is to restrict operations or halt.

This file defines what happens when recovery and fallback have failed or are not applicable: the system must either contain the error or halt safely.

## Containment

### Containment triggers

The system enters containment (`CONTAINED` state) when any of the following conditions occur:

1. **Fallback failure** — the system is in `DEGRADED` state and fallback selection has failed (no candidates, registry unavailable, or selected fallback did not validate as `STABLE`)
2. **Propagation risk** — during recovery, the system detects that applying a correction or fallback could propagate the error to other system components
3. **Operator/policy request** — an external operator or policy explicitly requests containment
4. **Recovery validation failure** — a recovery action completed but the post-recovery state did not classify as `STABLE`, and the recovery category does not permit further escalation within the recovery flow

### Containment objectives

When in containment, the system must:

1. **Prevent error propagation** — restrict operations to a safe subset that cannot spread the corrupted state to other components
2. **Preserve diagnostic state** — maintain the full diagnostic chain (original state, classification, recovery attempts, failure reasons) for operator inspection
3. **Remain operational in restricted mode** — containment is not halt. The system continues to operate but with restricted capabilities
4. **Signal containment status** — all diagnostic outputs must indicate that the system is in containment, including the trigger condition

### Containment behavior

```text
FUNCTION enter_containment(diagnostic: StateValidityDiagnostic, trigger: ContainmentTrigger) -> ContainmentRecord
    record = new ContainmentRecord()
    record.trigger = trigger
    record.original_diagnostic = diagnostic
    record.system_state_class = CONTAINED
    record.restricted_operations = determine_safe_operation_subset(diagnostic)
    record.containment_time = current_timestamp()
    record.awaiting_resolution = TRUE
    record.rule_ids = ["CONTAINMENT-TRIGGER-" + trigger.id]
    record.notes = ["Containment entered: " + trigger.reason]

    RETURN record
END FUNCTION
```

### When containment overrides correction

Containment overrides correction when:

1. **Propagation risk exceeds correction benefit** — the error could spread to other components during the correction process. In this case, containment is preferred even if the core is technically correctable.
2. **Correction has already failed** — a previous correction attempt did not produce a `STABLE` state. Repeating the same correction is not permitted.
3. **Multiple simultaneous errors** — the system detects errors in multiple state dimensions. Correcting one dimension might mask or worsen another.

The determination of propagation risk is a policy decision. If no propagation-risk policy is defined, the system must not assume safety — it must escalate to containment rather than guess.

### Containment resolution

Containment is resolved by:

1. **Operator intervention** — an operator inspects the diagnostic state and directs the system to a specific recovery action (which may include full state reset, manual correction, or safe halt)
2. **Policy-driven resolution** — a containment-resolution policy directs the system to a specific action after a defined period or condition
3. **Escalation to safe halt** — if the containment boundary is breached (the error propagates despite containment), the system must escalate to `SAFE_HALT`

Containment must never silently resolve. Resolution must be recorded in the diagnostic chain.

## Safe failure

### When safe failure is mandatory

The system must enter `SAFE_HALT` when:

1. **FAILED state** — the system is in an unrecoverable error state (transformation-incompatible state with no recovery path) and the external authority (operator/supervisor) directs halt
2. **Containment breach** — the system is in `CONTAINED` state and the containment boundary has been violated (error has propagated despite restrictions)
3. **Operator/policy halt request** — an explicit halt is requested regardless of current state
4. **Unresolvable blocked recovery** — the system is in a blocked recovery state with no path forward and no containment option

### What SAFE_HALT means semantically

`SAFE_HALT` is a **terminal system state** with the following properties:

1. **No further transitions** — once in `SAFE_HALT`, the system does not transition to any other state. This is the only system-state class with this property.
2. **Diagnostic preservation** — the full diagnostic chain is preserved: original state, classification, all recovery and containment attempts, failure reasons, and the halt trigger.
3. **Intentional action** — `SAFE_HALT` is a deliberate, defined system action. It is not a crash, not an uncontrolled shutdown, and not an undefined behavior.
4. **Post-mortem readiness** — the preserved diagnostic state must be sufficient for a human or external system to understand what happened and why the system halted.

### Separation of FAILED and SAFE_HALT

`FAILED` and `SAFE_HALT` are distinct system-state classes:

| Property | FAILED | SAFE_HALT |
|---|---|---|
| System is running | Yes — in unrecoverable error state | No — system has halted |
| Further transitions | Possible (escalation to SAFE_HALT, or external resolution) | None permitted |
| Recovery path | Escalation to external authority | None — terminal |
| Diagnostic state | Preserved and actively updated | Frozen for post-mortem |
| Entry mechanism | Automatic from `TRANSFORMATION_INCOMPATIBLE` classification with no recovery path | Deliberate action (operator, policy, containment breach) |

A system in `FAILED` state may eventually enter `SAFE_HALT`, but a system in `SAFE_HALT` cannot return to `FAILED` or any other state.

### Safe-halt behavior

```text
FUNCTION enter_safe_halt(diagnostic: StateValidityDiagnostic, trigger: SafeHaltTrigger) -> SafeHaltRecord
    record = new SafeHaltRecord()
    record.trigger = trigger
    record.original_diagnostic = diagnostic
    record.system_state_class = SAFE_HALT
    record.halt_time = current_timestamp()
    record.is_terminal = TRUE
    record.rule_ids = ["SAFE-HALT-TRIGGER-" + trigger.id]
    record.notes = ["Safe halt entered: " + trigger.reason]
    record.full_diagnostic_chain = collect_full_diagnostic_chain(diagnostic)

    -- Freeze diagnostic state
    record.frozen = TRUE

    RETURN record
END FUNCTION
```

## Minimum diagnostic content for containment and safe-failure actions

### Containment diagnostic

Every containment action must produce a record containing at minimum:

```text
TYPE ContainmentDiagnostic
    trigger                  : ContainmentTrigger
    original_diagnostic      : StateValidityDiagnostic
    system_state_class       : SystemStateClass (always CONTAINED)
    restricted_operations    : List of String
    containment_time         : Timestamp
    awaiting_resolution      : Boolean
    resolution               : ContainmentResolution or PENDING
    rule_ids                 : List of String
    notes                    : List of String
END TYPE

ENUM ContainmentTrigger
    FALLBACK_FAILURE
    PROPAGATION_RISK
    OPERATOR_REQUEST
    RECOVERY_VALIDATION_FAILURE
END ENUM
```

### Safe-halt diagnostic

Every safe-halt action must produce a record containing at minimum:

```text
TYPE SafeHaltDiagnostic
    trigger                  : SafeHaltTrigger
    original_diagnostic      : StateValidityDiagnostic
    system_state_class       : SystemStateClass (always SAFE_HALT)
    halt_time                : Timestamp
    full_diagnostic_chain    : List of diagnostic records from initial error through halt
    is_terminal              : Boolean (always TRUE)
    rule_ids                 : List of String
    notes                    : List of String
END TYPE

ENUM SafeHaltTrigger
    ESCALATION_FROM_FAILED
    CONTAINMENT_BREACH
    OPERATOR_HALT_REQUEST
    POLICY_HALT_REQUEST
    UNRESOLVABLE_BLOCKED_RECOVERY
END ENUM
```

## Relation to diagnostics and observability

Containment and safe failure are the most critical states for observability:

1. **External monitors** must be able to detect containment and safe-halt states without deep knowledge of ASH internals. The diagnostic records must be self-explanatory.
2. **Audit trails** — every containment entry, resolution attempt, and safe-halt action must be recorded in sequence so the full chain of events is reconstructable.
3. **Operator alerting** — containment and safe-halt conditions should trigger alerts (the alerting mechanism is implementation-specific, but the diagnostic content must support it).

## Invariants

1. **Monotonic escalation** — containment can escalate to safe halt, but safe halt cannot de-escalate to containment or any other state.
2. **Terminal finality** — `SAFE_HALT` is irrevocable within the ASH recovery semantics.
3. **No silent containment** — entering containment must always produce a diagnostic record with the trigger condition.
4. **No silent halt** — entering safe halt must always preserve the full diagnostic chain.
5. **Containment is not halt** — a contained system is still operational in restricted mode. Only safe halt stops the system.
6. **Diagnostic sufficiency** — the preserved diagnostic state must be sufficient for post-mortem analysis without access to runtime memory.

## Schema and taxonomy conformance

Containment and safe-halt diagnostics conform to the shared diagnostic envelope defined in `specs/interfaces/diagnostic-schema.md`:

- Containment diagnostics use `diagnostic_kind` = `CONTAINMENT`, `stage` = `ESCALATION`
- Safe-halt diagnostics use `diagnostic_kind` = `SAFE_HALT`, `stage` = `TERMINAL`
- `rule_ids` must conform to the `ASH-CONTAINMENT` and `ASH-HALT` families in `specs/interfaces/rule-id-taxonomy.md`

### Diagnostic chaining

- Containment diagnostics must set `parent_diagnostic_reference` to the preceding recovery or fallback diagnostic that triggered escalation.
- Safe-halt diagnostics must set `parent_diagnostic_reference` to the preceding containment or escalation diagnostic.
- Both must set `chain_root_reference` to the originating state-validity diagnostic at the root of the chain.
- The `full_diagnostic_chain` field in `SafeHaltDiagnostic` preserves the entire chain for post-mortem.

## Relation to other specifications

- **system-state-classification.pseudo.md** — defines `CONTAINED`, `FAILED`, and `SAFE_HALT` as system-state classes
- **recoverability-semantics.pseudo.md** — defines `CONTAINMENT_REQUIRED`, `ESCALATION_REQUIRED`, and `TERMINAL_NO_RECOVERY` as recovery categories
- **recovery-fallback-semantics.pseudo.md** — escalates to containment when fallback fails
- **fallback-policy-registry.md** — containment receives escalation when no valid fallback candidate exists
- **state-validity-diagnostics.pseudo.md** — provides the diagnostic records consumed by containment and safe-halt logic
- **state-admissibility.pseudo.md** — provides admissibility classification
- **codeword-set.pseudo.md** — provides the codeword structure that determines recoverability
- **diagnostic-schema.md** — defines the shared diagnostic envelope this specification conforms to (pending R3 revalidation)
- **rule-id-taxonomy.md** — defines the canonical rule-ID pattern for the `rule_ids` field (pending R3 revalidation)
