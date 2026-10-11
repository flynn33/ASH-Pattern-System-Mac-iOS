import Foundation
import ASHCore

public struct ASHPatternSystemSnapshot: Codable, Hashable, Sendable {
  public let contextID: String
  public let state: ASHState?
  public let stateClass: SystemStateClass?
  public let runtimeMode: ASHRuntimeMode
  public let diagnostics: [ASHDiagnosticEnvelope]
  public let recoveryOutcome: ASHOperationalRecoveryOutcome?
  public let breachConfirmed: Bool
  public let containmentRecord: ASHDiagnosticValue?
  public let safeHaltRecord: ASHDiagnosticValue?
  public var containmentRecordJSONData: Data? { containmentRecord?.canonicalJSONData }
  public var safeHaltRecordJSONData: Data? { safeHaltRecord?.canonicalJSONData }
  public var terminal: Bool { runtimeMode == .safeHalt }
  public var diagnosticsFrozen: Bool { terminal }
  public var transitionsAllowed: Bool { state != nil && runtimeMode == .active }
  public var restrictedOperationsOnly: Bool { runtimeMode == .contained }
}
public struct ASHSessionPlanningResult: Sendable { public let snapshot: ASHPatternSystemSnapshot; public let plan: ASHGenerationPlan? }
public struct ASHSessionEmissionResult: Sendable { public let snapshot: ASHPatternSystemSnapshot; public let artifacts: [ASHMaterializedArtifact] }

/// Mutable operational state is owned by this actor. Pure services remain independently usable.
public actor ASHPatternSystemSession {
  private var context: ASHOperationalContext
  private let model: ASHStateModel
  private let registry: ASHTransitionRegistry
  private let recovery: ASHRecoveryEngine
  private let supportDiagnostics: (any ASHSupportDiagnosticCollecting)?
  private var state: ASHState?
  private var stateClass: SystemStateClass?
  private var mode: ASHRuntimeMode = .active
  private var chain: [ASHDiagnosticEnvelope] = []
  private var outcome: ASHOperationalRecoveryOutcome?
  private var breachConfirmed = false
  private var frozen: ASHPatternSystemSnapshot?
  private var supportFailures = 0
  private var containmentPlacement: ASHSafetyRecordPlacement?
  private var haltPlacement: ASHSafetyRecordPlacement?
  public init(context: ASHOperationalContext, supportDiagnostics: (any ASHSupportDiagnosticCollecting)? = nil) throws {
    try context.validate()
    self.context = context; self.supportDiagnostics = supportDiagnostics
    let model = ASHStateModel(), registry = ASHTransitionRegistry(stateModel: ASHStateModel())
    self.model = model; self.registry = registry
    self.recovery = ASHRecoveryEngine(stateModel: model, transitionRegistry: registry)
  }
  public func snapshot() -> ASHPatternSystemSnapshot {
    frozen ?? ASHPatternSystemSnapshot(contextID: context.contextID, state: state, stateClass: stateClass,
      runtimeMode: mode, diagnostics: chain, recoveryOutcome: outcome, breachConfirmed: breachConfirmed,
      containmentRecord:containmentPlacement.flatMap { ASHCanonicalSafetyRecords.record(chain:chain,placement:$0,safeHalt:false) },
      safeHaltRecord:haltPlacement.flatMap { ASHCanonicalSafetyRecords.record(chain:chain,placement:$0,safeHalt:true) })
  }
  public func supportDiagnosticFailureCount() -> Int { supportFailures }
  public func bootstrap(bitString: String) async -> ASHPatternSystemSnapshot {
    if let frozen { return frozen }
    guard mode == .active, state == nil else { return await deny("bootstrap") }
    let assessment = model.assess(bitString: bitString, context: context)
    if assessment.inputStatus == .malformed {
      place(assessment.diagnostics[0]); return await finish("bootstrap", expected: "nine-bit input", actual: "MALFORMED")
    }
    append(kind: .inputValidation, stage: .parse, disposition: .recorded, summary: "Nine-bit input parsed without changing realm identity.", rules: ["ASH-INPUT-001"], details: ["input_status":.string("WELL_FORMED")])
    state = assessment.state; stateClass = assessment.stateClass
    place(assessment.diagnostics[0])
    return await finish("bootstrap", expected: "validated assessment", actual: stateClass?.rawValue ?? "BLOCKED")
  }
  public func transition(transitionID: String) async -> ASHPatternSystemSnapshot {
    if let frozen { return frozen }
    guard mode == .active, let state else { return await deny("transition") }
    let result = registry.applyTransition(from: state, transitionID: transitionID)
    if let applied = result.applied {
      self.state = applied.toState
      let assessment = model.assess(state: applied.toState, context: context)
      stateClass = assessment.stateClass
      append(kind: .transition, stage: .transform, disposition: .resolved, summary: "Canonical transition applied.", rules: ["ASH-TRANSITION-001"], details: ["from_state":.string(state.description), "to_state":.string(applied.toState.description), "transition_id":.string(applied.transitionID), "codeword":.string(applied.codeword.description), "post_state_class":.string(stateClass?.rawValue ?? "BLOCKED")])
    } else {
      append(kind: .transition, stage: .transform, disposition: .blocked, summary: result.failureDiagnostic?.summary ?? "Transition blocked.", rules: ["ASH-TRANSITION-001"], details: ["transition_id":.string(transitionID)])
    }
    return await finish("transition", expected: "registered canonical transition", actual: result.applied == nil ? "BLOCKED" : "APPLIED")
  }
  public func recover() async -> ASHPatternSystemSnapshot {
    if let frozen { return frozen }
    guard mode == .active, let state else { return await deny("recover") }
    let result = recovery.recover(state: state, context: context)
    outcome = result.outcome
    // Classification is an assessment of current input, already represented in this chain.
    for record in result.diagnostics.dropFirst() { place(record) }
    if [.recovered, .recoveredViaFallbackReplacement].contains(result.outcome) {
      self.state = result.resultingState; stateClass = result.postAssessment?.stateClass
    } else if result.outcome == .escalateToContainment {
      mode = .contained; stateClass = .contained
      appendContainment(trigger:.fallbackFailure, reason: "Fallback policy declares no validated replacement.", disposition: .escalated)
    }
    return await finish("recover", expected: "context-authorized recovery", actual: result.outcome.rawValue)
  }
  public func resolveContext(_ replacement: ASHOperationalContext, authority: String) async -> ASHPatternSystemSnapshot {
    if let frozen { return frozen }
    guard mode == .active, let state else { return await deny("resolve_context") }
    guard replacement.validationIssues.isEmpty, !authority.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      append(kind: .recovery, stage: .recover, disposition: .blocked, summary: "External context resolution is invalid.", rules: ["ASH-RECOVERY-001"], details: ["validation_issues":.array(replacement.validationIssues.map(ASHDiagnosticValue.string))])
      return await finish("resolve_context", expected: "validated external authority", actual: "BLOCKED")
    }
    context = replacement; stateClass = model.assess(state: state, context: replacement).stateClass
    append(kind: .recovery, stage: .recover, disposition: .resolved, summary: "External authority supplied a validated operational context without mutating state.", rules: ["ASH-RECOVERY-001"], details: ["authority":.string(authority), "context_id":.string(replacement.contextID), "post_state_class":.string(stateClass?.rawValue ?? "BLOCKED")])
    return await finish("resolve_context", expected: "explicit context resolution", actual: "RESOLVED")
  }
  public func enterContainment(reason: String) async -> ASHPatternSystemSnapshot {
    await enterContainment(trigger:.operatorRequest,reason:reason)
  }
  public func enterContainment(trigger: ASHContainmentTrigger, reason: String = "") async -> ASHPatternSystemSnapshot {
    if let frozen { return frozen }
    guard mode != .contained else { return await deny("enter_containment") }
    guard state != nil else { return await deny("enter_containment") }
    mode = .contained; stateClass = .contained
    appendContainment(trigger:trigger, reason: reason, disposition: .escalated)
    return await finish("enter_containment", expected: "restricted containment", actual: "CONTAINED")
  }
  public func reportContainmentAttempt(operation: String, boundaryBreached: Bool, attemptPrevented: Bool, propagationObserved: Bool) async -> ASHPatternSystemSnapshot {
    if let frozen { return frozen }
    guard mode == .contained else { return await deny("containment_attempt") }
    guard boundaryBreached == propagationObserved && !(boundaryBreached && attemptPrevented) else {
      append(kind:.containment, severity:.warning, stage:.contain, disposition:.blocked,
        summary:"Inconsistent containment observations are rejected; restrictions remain active.", rules:["ASH-CONTAINMENT-001"],
        details:["attempted_operation":.string(operation), "boundary_breached":.bool(boundaryBreached), "attempt_prevented":.bool(attemptPrevented), "propagation_observed":.bool(propagationObserved), "observation_validation":.string("REJECTED_INCONSISTENT_EVIDENCE")])
      return await finish("containment_attempt",expected:"consistent boundary and propagation evidence",actual:"INVALID_OBSERVATION")
    }
    let confirmed = boundaryBreached && !attemptPrevented && propagationObserved
    let details: [String:ASHDiagnosticValue] = ["attempted_operation":.string(operation), "boundary_breached":.bool(boundaryBreached), "attempt_prevented":.bool(attemptPrevented), "propagation_observed":.bool(propagationObserved), "breach_confirmed":.bool(confirmed)]
    append(kind: .containment, stage: .contain, disposition: confirmed ? .escalated : .blocked,
      summary: confirmed ? "Observed propagation confirms containment breach." : "Containment remains active; no breach is confirmed.", rules: ["ASH-CONTAINMENT-001"], details: ASHDiagnosticObject(details))
    if confirmed {
      breachConfirmed = true
      if let placement = containmentPlacement {
        containmentPlacement = .init(actionIndex:chain.count-1, trigger:placement.trigger, timeUTC:placement.timeUTC, awaitingResolution:false, resolution:"SAFE_HALT")
      }
      freezeHalt(trigger:.containmentBreach, reason:"Observed propagation despite containment.")
    }
    return await finish("containment_attempt", expected: "containment boundary preserved", actual: confirmed ? "SAFE_HALT" : "CONTAINED")
  }
  public func resolveContainment(authority: String) async -> ASHPatternSystemSnapshot {
    if let frozen { return frozen }
    guard mode == .contained, !authority.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return await deny("resolve_containment") }
    append(kind: .containment, stage: .contain, disposition: .resolved, summary: "External containment resolution recorded; restrictions remain active for this session.", rules: ["ASH-CONTAINMENT-001"], details: ["authority":.string(authority), "resolution":.string("OPERATOR_DIRECTED"), "successor_session_required":.bool(true)])
    if let placement = containmentPlacement {
      containmentPlacement = .init(actionIndex:chain.count-1, trigger:placement.trigger, timeUTC:placement.timeUTC, awaitingResolution:false, resolution:"OPERATOR_DIRECTED")
    }
    return await finish("resolve_containment", expected: "recorded authority resolution", actual: "RESOLVED")
  }
  public func markFailed(reason: String) async -> ASHPatternSystemSnapshot {
    if let frozen { return frozen }
    guard mode == .active, state != nil else { return await deny("mark_failed") }
    mode = .failed; stateClass = .failed
    append(kind: .recovery, stage: .recover, disposition: .blocked, summary: "Automated recovery exhausted; awaiting external authority.", rules: ["ASH-RECOVERY-001"], details: ["reason":.string(reason), "state_class":.string("FAILED")])
    return await finish("mark_failed", expected: "diagnostic preservation", actual: "FAILED")
  }
  public func halt(reason: String) async -> ASHPatternSystemSnapshot {
    await halt(trigger:.operatorHaltRequest,reason:reason)
  }
  public func halt(trigger: ASHSafeHaltTrigger, reason: String = "") async -> ASHPatternSystemSnapshot {
    if let frozen { return frozen }
    if trigger == .containmentBreach && !(mode == .contained && breachConfirmed) { return await deny("halt_requires_confirmed_containment_breach") }
    if trigger == .escalationFromFailed && mode != .failed { return await deny("halt_requires_failed_runtime") }
    // This supported policy always provides containment; the canonical trigger requires no containment option.
    if trigger == .unresolvableBlockedRecovery { return await deny("halt_requires_no_recovery_path_and_no_containment_option") }
    if mode == .active || chain.isEmpty {
      append(kind: .recovery, stage: .recover, disposition: .escalated, summary: "Explicit authority requested terminal halt.", rules: ["ASH-RECOVERY-001"], details: ["reason":.string(reason)])
    }
    freezeHalt(trigger:trigger, reason: reason)
    return await finish("halt", expected: "terminal frozen snapshot", actual: "SAFE_HALT")
  }
  public func plan(depth: Int, constraints: ASHTargetRuntimeConstraints = .init()) async -> ASHSessionPlanningResult {
    if let frozen { return .init(snapshot: frozen, plan: nil) }
    guard mode == .active, let state else { return .init(snapshot: await deny("plan"), plan: nil) }
    let topology = ASHTopologyGenerator(stateModel: model, transitionRegistry: registry).generateTopology(from: state, depth: depth)
    guard let value = topology.topology else {
      append(kind: .generationPlan, stage: .plan, disposition: .blocked, summary: "Topology failure blocks generation planning.", rules: ["ASH-GENERATION-001"], details: [:])
      return .init(snapshot: await finish("plan", expected: "complete topology", actual: "BLOCKED"), plan: nil)
    }
    let result = ASHGenerationPlanner(stateModel: model, realmEncoder: ASHRealmEncoder(stateModel: model)).buildPlan(from: state, topology: value, axiomEvaluation: ASHAxiomEvaluator().evaluate(state: state), targetConstraints: constraints)
    for record in result.canonicalDiagnostics(subject: state.description) { place(record) }
    let saved = await finish("plan", expected: "complete abstract plan", actual: result.plan == nil ? "BLOCKED" : "PLANNED")
    return .init(snapshot: saved, plan: result.plan)
  }
  public func emit(plan: ASHGenerationPlan) async -> ASHSessionEmissionResult {
    if let frozen { return .init(snapshot: frozen, artifacts: []) }
    guard mode == .active, state != nil else { return .init(snapshot: await deny("emit"), artifacts: []) }
    guard plan.normalizedState == state else {
      append(kind:.emission, stage:.emit, disposition:.blocked, summary:"Session emission requires a plan for the current state.", rules:["ASH-EMISSION-001"], details:["plan_state":.string(plan.normalizedState.description), "current_state":state.map { .string($0.description) } ?? .null])
      return .init(snapshot:await finish("emit",expected:"plan for current session state",actual:"BLOCKED"),artifacts:[])
    }
    let result = ASHArtifactEmitter().emit(plan: plan)
    for record in result.canonicalDiagnostics(subject: state?.description ?? "session") { place(record) }
    let saved = await finish("emit", expected: "validated plan-derived artifacts", actual: result.artifacts.isEmpty ? "BLOCKED" : "EMITTED")
    return .init(snapshot: saved, artifacts: result.artifacts)
  }
  private func appendContainment(trigger: ASHContainmentTrigger, reason: String, disposition: ASHDiagnosticDisposition) {
    let time = ASHCanonicalSafetyRecords.timestamp()
    append(kind:.containment,stage:.contain,disposition:disposition,summary:"Containment restricts operations and preserves the diagnostic chain.",rules:["ASH-CONTAINMENT-001"],
      details:["trigger":.string(trigger.rawValue),"reason":.string(reason),"state_class":.string("CONTAINED"),"restricted_operations":.array([.string("DIAGNOSTIC_READ"),.string("STATE_INSPECTION"),.string("EXTERNAL_RESOLUTION")]),"awaiting_resolution":.bool(true)],
      occurrenceMetadata:["containment_time":.string(time)])
    containmentPlacement = .init(actionIndex:chain.count-1,trigger:trigger.rawValue,timeUTC:time,awaitingResolution:true,resolution:"PENDING")
  }
  private func freezeHalt(trigger: ASHSafeHaltTrigger, reason: String) {
    mode = .safeHalt; stateClass = .safeHalt
    let time = ASHCanonicalSafetyRecords.timestamp()
    append(kind:.safeHalt,stage:.halt,disposition:.terminal,summary:"Safe halt preserves and freezes this session's complete diagnostic chain.",rules:["ASH-HALT-001"],
      details:["trigger":.string(trigger.rawValue),"reason":.string(reason),"is_terminal":.bool(true),"frozen":.bool(true)],occurrenceMetadata:["halt_time":.string(time)])
    haltPlacement = .init(actionIndex:chain.count-1,trigger:trigger.rawValue,timeUTC:time,awaitingResolution:false,resolution:"SAFE_HALT")
    frozen = snapshot()
  }
  private func deny(_ operation: String) async -> ASHPatternSystemSnapshot {
    let kind: ASHDiagnosticKind = state == nil ? .inputValidation : (mode == .contained ? .containment : .recovery)
    let stage: ASHDiagnosticStage = state == nil ? .parse : (mode == .contained ? .contain : .recover)
    append(kind:kind, stage:stage, disposition:.blocked,
      summary:"Runtime restrictions block the requested operation.", rules:[state == nil ? "ASH-INPUT-001" : (mode == .contained ? "ASH-CONTAINMENT-001" : "ASH-RECOVERY-001")],
      details:["operation":.string(operation), "runtime_mode":.string(mode.rawValue), "bootstrap_required":.bool(state == nil)])
    return await finish(operation, expected: "authorized runtime operation", actual: "BLOCKED")
  }
  private func append(kind: ASHDiagnosticKind, severity: ASHDiagnosticSeverity = .info, stage: ASHDiagnosticStage, disposition: ASHDiagnosticDisposition, summary: String, rules: [String], details: ASHDiagnosticObject, occurrenceMetadata:ASHDiagnosticObject? = nil) {
    let requestedSeverity: ASHDiagnosticSeverity = kind == .safeHalt ? .critical : severity
    let selectedSeverity = (chain.last?.severity.rank ?? 0) > requestedSeverity.rank ? (chain.last?.severity ?? requestedSeverity) : requestedSeverity
    chain.append(.canonical(kind: kind, severity: selectedSeverity, stage: stage, disposition: disposition, subject: state?.description ?? "session", ruleIDs: rules, summary: summary, notes: ["State and diagnostic updates are committed before returning the operation snapshot."], details: details, parent: chain.last, occurrenceMetadata:occurrenceMetadata))
    if kind == .containment, let placement = containmentPlacement {
      containmentPlacement = .init(actionIndex:chain.count-1,trigger:placement.trigger,timeUTC:placement.timeUTC,awaitingResolution:placement.awaitingResolution,resolution:placement.resolution)
    }
  }
  private func place(_ record: ASHDiagnosticEnvelope) {
    append(kind: record.diagnosticKind, severity:record.severity, stage: record.stage, disposition: record.disposition, summary: record.summary, rules: record.ruleIDs, details: record.details)
  }
  private func finish(_ operation: String, expected: String, actual: String) async -> ASHPatternSystemSnapshot {
    // Commit and capture a snapshot before crossing the collector actor boundary.
    let saved = snapshot()
    if let supportDiagnostics {
      do { _ = try await supportDiagnostics.capture(.init(operation: operation, correlation: "\(context.contextID):\(saved.diagnostics.count)", expected: expected, actual: actual, context: ["classification":saved.stateClass?.rawValue ?? "UNCLASSIFIED"], canonicalDiagnostics:saved.diagnostics)) }
      catch { supportFailures += 1 }
    }
    return saved
  }
}
