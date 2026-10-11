import Foundation
import ASHCore
#if CONSUME_ORCHESTRATION
import ASHPatternSystem
#endif

struct ConsumerReport: Codable {
  let sdkVersion: String
  let diagnosticProfile: String
  let checks: [String]
  let publicOutcomes: [String: String]
  let exportDirectory: String
}

enum ConsumerCheckError: Error {
  case failed(String)
}

/// The consumer owns its scenarios and caller-selected export destination.
final class ConsumerChecks {
  private var checks: [String] = []
  private var outcomes: [String: String] = [:]
  private var frozenChain: [ASHDiagnosticEnvelope]?

  private func record(_ name: String, _ condition: Bool) throws {
    guard condition else { throw ConsumerCheckError.failed(name) }
    checks.append(name)
  }

  func run(exportRoot: URL) async throws -> ConsumerReport {
    let collector = try ASHSupportDiagnostics.makeCollector(identity:
      ASHSupportIdentity(version: ASHSDKVersion.version, build: ASHSDKVersion.buildNumber))
    do {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    for raw in 0..<512 {
      guard let state = ASHState(rawValue: UInt16(raw)) else {
        throw ConsumerCheckError.failed("valid-state-construction")
      }
      let decoded = try decoder.decode(ASHState.self, from: encoder.encode(state))
      try record("state-roundtrip-\(raw)", decoded == state)
    }
    for text in ["{\"rawValue\":512}", "{\"rawValue\":65535}", "{\"rawValue\":-1}",
                 "{\"rawValue\":1.5}", "{}", "{\"rawValue\":null}", "{\"rawValue\":\"0\"}", "{\"rawValue\":true}"] {
      var rejected = false
      do { _ = try decoder.decode(ASHState.self, from: Data(text.utf8)) }
      catch { rejected = true }
      try record("invalid-state-\(checks.count)", rejected)
    }
    try await collector.capture(ASHSupportEventInput(operation: "external-state-decode", correlation: "consumer-invalid-state",
      expected: "Malformed external state is rejected without mutation", actual: "All eight malformed representations rejected",
      context: ["fixture": "invalid-state-boundary", "state": "512", "outcome": "rejected"],
      failure: ASHSupportFailure(domain: "SDKConsumer", code: "INVALID_STATE", message: "Controlled invalid input rejected")))
    try runCoreChecks()
    #if CONSUME_ORCHESTRATION
    try await runSessionChecks(collector: collector, exportRoot: exportRoot)
    #endif
    let beforeExport = await collector.snapshot()
    try record("release-diagnostic-profile", beforeExport.profile == "release-minimal")
    let exported = try await collector.export(to: exportRoot)
    let parsed = try decoder.decode(ASHSupportSnapshot.self, from: Data(contentsOf: exported.json))
    let markdown = try String(contentsOf: exported.markdown, encoding: .utf8)
    try record("paired-json-snapshot", parsed == exported.snapshot)
    try record("paired-markdown-identity", markdown.contains(parsed.bundleID) && markdown.contains("consumer-invalid-state"))
    try record("controlled-failure-export", parsed.events.contains { $0.failure?.code == "INVALID_STATE" })
    if let frozenChain {
      try record("paired-canonical-frozen-chain", parsed.events.contains { $0.operation == "containment_attempt" && $0.canonicalDiagnostics == frozenChain }
        && frozenChain.allSatisfy { markdown.contains($0.diagnosticReference) })
      let requiredFields = ["schema_version", "diagnostic_id", "diagnostic_kind", "severity", "stage", "disposition", "subject_reference", "rule_ids",
        "summary", "details", "notes", "parent_diagnostic_id", "chain_root_diagnostic_id", "sequence_number", "occurrence_metadata"]
      let unescapedMarkdown = markdown.replacingOccurrences(of: "&#95;", with: "_")
      try record("paired-canonical-schema-fields", requiredFields.allSatisfy { unescapedMarkdown.contains($0) })
    }
    await collector.shutdown()
    var closed = false
    do { try await collector.capture(ASHSupportEventInput(operation: "after-shutdown", correlation: "closed", expected: "closed", actual: "denied")) }
    catch ASHSupportError.closed { closed = true }
    try record("collector-shutdown", closed)
    await collector.purge()
    let purged = await collector.snapshot()
    try record("collector-purge", purged.events.isEmpty)
    guard !checks.isEmpty else { throw ConsumerCheckError.failed("zero-cases") }
    return ConsumerReport(sdkVersion: ASHSDKVersion.version, diagnosticProfile: parsed.profile,
      checks: checks, publicOutcomes: outcomes, exportDirectory: exported.directory.path)
    } catch {
      // Preserve a startup/check failure even when the normal report/UI cannot complete.
      try? await collector.capture(ASHSupportEventInput(operation: "consumer-check-run", correlation: "consumer-startup-failure",
        expected: "All public consumer checks complete", actual: "Consumer check failed",
        context: ["outcome": "failure"], failure: ASHSupportFailure(domain: "SDKConsumer", code: "CHECK_FAILURE", message: String(describing: error))))
      _ = try? await collector.export(to: exportRoot)
      await collector.shutdown()
      throw error
    }
  }

  private func runCoreChecks() throws {
    let model = ASHStateModel(), registry = ASHTransitionRegistry(stateModel: ASHStateModel())
    let zero = ASHState(rawValue: 0)!, outside = ASHState(rawValue: 1)!
    let words = model.codewordSet.sorted(), correctable = words[1]
    let context = ASHOperationalContext(contextID: "consumer-core", allowedStableStates: [zero])
    try record("classification-stable", model.assess(state: zero, context: context).stateClass == .stable)
    try record("classification-correctable", model.assess(state: correctable, context: context).stateClass == .correctable)
    try record("classification-degraded", model.assess(state: outside, context: context).stateClass == .degraded)
    let ambiguous = ASHOperationalContext(contextID: "consumer-ambiguous", allowedStableStates: [zero, correctable])
    try record("classification-unstable", model.assess(state: words[2], context: ambiguous).stateClass == .unstable)
    let runtimeClasses: [(ASHRuntimeMode, SystemStateClass)] = [(.contained, .contained), (.failed, .failed), (.safeHalt, .safeHalt)]
    for pair in runtimeClasses {
      try record("classification-\(pair.0.rawValue)", model.assess(state: zero, context: context, runtime: pair.0).stateClass == pair.1)
    }
    try record("assessment-context-required", model.assess(state: zero, context: nil).assessmentBlocked)
    try record("assessment-malformed", model.assess(bitString: "000000002", context: context).inputStatus == .malformed)
    try record("canonical-reachability", model.reachableStates(from: zero) == words && !model.isReachable(from: outside, to: zero))
    let values = Dictionary(uniqueKeysWithValues: words.map { ($0, Int64($0.rawValue)) })
    let average = try model.average(at: zero, values: values)
    try record("canonical-averaging", average.denominator == 16 && average.numerator == values.values.reduce(0, +))
    var incompleteRejected = false
    do { _ = try model.average(at: zero, values: [zero: Int64(0)]) }
    catch ASHAveragingError.incompleteValues { incompleteRejected = true }
    try record("averaging-incomplete-rejected", incompleteRejected)
    let correction = ASHRecoveryEngine(stateModel: model, transitionRegistry: registry).recover(state: correctable, context: context)
    try record("reachable-recovery", correction.outcome == .recovered && correction.targetState == zero && correction.codewordID != nil)
    for policy in [ASHFallbackPolicy.declaredKnownGood, .lastVerifiedStable] {
      let fallback = ASHOperationalContext(contextID: "consumer-fallback", allowedStableStates: [zero],
        fallbackPolicyInstance: .init(policy: policy, candidates: [.init(state: zero, verificationSequence: 1, evidence: "consumer-declared-stable")]))
      let result = ASHRecoveryEngine(stateModel: model, transitionRegistry: registry).recover(state: outside, context: fallback)
      try record("fallback-\(policy.rawValue)", result.outcome == .recoveredViaFallbackReplacement && result.resultingState == zero && result.codewordID == nil)
    }
    let topologyResult = ASHTopologyGenerator(stateModel: model, transitionRegistry: registry).generateTopology(from: zero, depth: 2)
    guard let topology = topologyResult.topology else { throw ConsumerCheckError.failed("topology-missing") }
    try record("topology-structure", topology.nodes.count == 13 && topology.leaves.count == 9 && topology.nodes.allSatisfy { $0.state == zero })
    let planner = ASHGenerationPlanner(stateModel: model, realmEncoder: ASHRealmEncoder(stateModel: model))
    let result = planner.buildPlan(from: zero, topology: topology, axiomEvaluation: ASHAxiomEvaluator().evaluate(state: zero), targetConstraints: .init())
    guard let plan = result.plan else { throw ConsumerCheckError.failed("plan-missing") }
    let identity = try plan.identity(), emitted = ASHArtifactEmitter().emit(plan: plan)
    try record("planner-emitter", plan.validationIssues.isEmpty && emitted.artifacts.count == plan.artifacts.count && emitted.artifacts.allSatisfy { $0.planID == identity })
    try record("emission-determinism", emitted.artifacts == ASHArtifactEmitter().emit(plan: plan).artifacts)
    let malformed = ASHGenerationPlan(normalizedState: plan.normalizedState, sourceRealm: plan.sourceRealm, destinationRealm: plan.destinationRealm,
      topologyNodes: plan.topologyNodes, roleAssignments: [], axiomSummaries: plan.axiomSummaries, artifacts: plan.artifacts,
      targetConstraints: plan.targetConstraints, warnings: plan.warnings, metadata: plan.metadata)
    try record("emission-incomplete-plan-rejected", !malformed.validationIssues.isEmpty && ASHArtifactEmitter().emit(plan: malformed).artifacts.isEmpty)
    let unknownRegistry = ASHTargetRuntimeConstraints(registryVersions: ["profiles":"1.1", "naming":"1.0", "targets":"1.0"])
    let refused = planner.buildPlan(from: zero, topology: topology, axiomEvaluation: ASHAxiomEvaluator().evaluate(state: zero), targetConstraints: unknownRegistry)
    try record("planning-unknown-registry-rejected", !unknownRegistry.validationIssues.isEmpty && refused.plan == nil)
    outcomes["planIdentity"] = identity
    outcomes["artifactContent"] = emitted.artifacts.map(\.content).joined(separator: "\n---\n")
    outcomes["average"] = "\(average.numerator)/\(average.denominator)"
    outcomes["recovery"] = correction.outcome.rawValue
  }

  #if CONSUME_ORCHESTRATION
  private func runSessionChecks(collector: any ASHSupportDiagnosticCollecting, exportRoot: URL) async throws {
    let zero = ASHState(rawValue: 0)!, outside = ASHState(rawValue: 1)!
    let words = ASHStateModel().codewordSet.sorted()
    let context = ASHOperationalContext(contextID: "consumer-session", allowedStableStates: [zero])
    let session = try ASHPatternSystemSession(context: context, supportDiagnostics: collector)
    let beforeBootstrap = await session.recover()
    try record("session-prebootstrap-denial", beforeBootstrap.state == nil && beforeBootstrap.runtimeMode == .active && !beforeBootstrap.diagnostics.isEmpty)
    let malformed = await session.bootstrap(bitString: "invalid")
    try record("session-malformed-input", malformed.state == nil && malformed.runtimeMode == .active && !malformed.diagnostics.isEmpty)
    let boot = await session.bootstrap(bitString: words[1].description)
    try record("session-bootstrap", boot.state == words[1] && boot.stateClass == .correctable)
    let recovered = await session.recover()
    try record("session-recovery", recovered.state == zero && recovered.stateClass == .stable && recovered.recoveryOutcome == .recovered)
    let invalidTransition = await session.transition(transitionID: "INVALID")
    try record("session-invalid-transition", invalidTransition.state == zero && invalidTransition.runtimeMode == .active)
    let planning = await session.plan(depth: 2)
    guard let plan = planning.plan else { throw ConsumerCheckError.failed("session-plan-missing") }
    let emitted = await session.emit(plan: plan)
    try record("session-planner-emitter", !emitted.artifacts.isEmpty && emitted.artifacts.count == plan.artifacts.count)
    let independent = try ASHPatternSystemSession(context: context)
    let independentBoot = await independent.bootstrap(bitString: zero.description)
    let ambiguousContext = ASHOperationalContext(contextID: "consumer-policy", allowedStableStates: [zero, words[1]])
    let ambiguous = try ASHPatternSystemSession(context: ambiguousContext)
    _ = await ambiguous.bootstrap(bitString: words[2].description)
    let blocked = await ambiguous.recover()
    try record("session-target-resolution-blocked", blocked.state == words[2] && blocked.stateClass == .unstable && blocked.recoveryOutcome == .targetResolutionBlocked)
    let resolved = await ambiguous.resolveContext(context, authority: "consumer-owner")
    try record("session-context-resolution", resolved.state == words[2] && resolved.stateClass == .correctable)
    let fallbackContext = ASHOperationalContext(contextID: "consumer-fallback-session", allowedStableStates: [zero],
      fallbackPolicyInstance: .init(policy: .declaredKnownGood, candidates: [.init(state: zero, evidence: "consumer-authorized")]))
    let fallback = try ASHPatternSystemSession(context: fallbackContext)
    _ = await fallback.bootstrap(bitString: outside.description)
    let replaced = await fallback.recover()
    try record("session-fallback-replacement", replaced.state == zero && replaced.recoveryOutcome == .recoveredViaFallbackReplacement)
    let exhausted = try ASHPatternSystemSession(context: context)
    _ = await exhausted.bootstrap(bitString: outside.description)
    let contained = await exhausted.recover()
    try record("session-fallback-exhaustion", contained.runtimeMode == .contained && contained.state == outside && contained.recoveryOutcome == .escalateToContainment)
    let failed = try ASHPatternSystemSession(context: context)
    _ = await failed.bootstrap(bitString: zero.description)
    let failure = await failed.markFailed(reason: "consumer-controlled-failure")
    let failedRecovery = await failed.recover()
    try record("session-failed-mode", failure.runtimeMode == .failed && failedRecovery.state == zero && failedRecovery.runtimeMode == .failed)
    _ = await session.enterContainment(reason: "consumer-boundary-check")
    let prevented = await session.reportContainmentAttempt(operation: "transition", boundaryBreached: true, attemptPrevented: true, propagationObserved: false)
    try record("session-prevented-attempt", prevented.runtimeMode == .contained && !prevented.breachConfirmed)
    let denied = await session.transition(transitionID: "APS-TRANSITION-CW-01")
    try record("session-contained-transition", denied.state == zero && denied.runtimeMode == .contained && !denied.breachConfirmed)
    let authority = await session.resolveContainment(authority: "consumer-owner")
    try record("session-containment-resolution", authority.runtimeMode == .contained && authority.restrictedOperationsOnly)
    let terminal = await session.reportContainmentAttempt(operation: "transition", boundaryBreached: true, attemptPrevented: false, propagationObserved: true)
    try record("session-safe-halt", terminal.terminal && terminal.diagnosticsFrozen && terminal.breachConfirmed && terminal.state == zero)
    let attempted = [await session.bootstrap(bitString: outside.description), await session.transition(transitionID: "APS-TRANSITION-CW-01"),
      await session.recover(), await session.resolveContext(fallbackContext, authority: "consumer-owner"),
      await session.enterContainment(reason: "again"), await session.reportContainmentAttempt(operation: "again", boundaryBreached: false, attemptPrevented: true, propagationObserved: false),
      await session.resolveContainment(authority: "consumer-owner"), await session.markFailed(reason: "again"), await session.halt(reason: "again"), await session.snapshot()]
    let typedContainment = await session.enterContainment(trigger: .operatorRequest), typedHalt = await session.halt(trigger: .operatorHaltRequest)
    try record("session-terminal-all-entry-points", attempted.allSatisfy { $0 == terminal } && typedContainment == terminal && typedHalt == terminal)
    let haltedPlanning = await session.plan(depth: 2), haltedEmission = await session.emit(plan: plan)
    try record("session-terminal-plan-emission", haltedPlanning.snapshot == terminal && haltedPlanning.plan == nil && haltedEmission.snapshot == terminal && haltedEmission.artifacts.isEmpty)
    let finalIndependent = await independent.snapshot()
    try record("session-isolation", finalIndependent == independentBoot && finalIndependent.runtimeMode == .active)
    let supportFailures = await session.supportDiagnosticFailureCount()
    try record("session-support-collector", supportFailures == 0)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    let frozenData = try encoder.encode(terminal)
    let frozenURL = exportRoot.appendingPathComponent("FrozenSession.json")
    try frozenData.write(to: frozenURL, options: .atomic)
    let frozenDecoded = try JSONDecoder().decode(ASHPatternSystemSnapshot.self, from: Data(contentsOf: frozenURL))
    try record("session-frozen-chain-export", frozenDecoded == terminal && !frozenDecoded.diagnostics.isEmpty)
    guard let containmentData = terminal.containmentRecordJSONData, let haltData = terminal.safeHaltRecordJSONData,
      let containmentJSON = try JSONSerialization.jsonObject(with: containmentData) as? [String: Any],
      let haltJSON = try JSONSerialization.jsonObject(with: haltData) as? [String: Any],
      let containmentBody = containmentJSON["data"] as? [String: Any], let haltBody = haltJSON["data"] as? [String: Any]
      else { throw ConsumerCheckError.failed("session-safety-record-missing") }
    try record("session-canonical-safety-records", containmentJSON["schema_version"] as? String == "1.0" && haltJSON["product_version"] as? String == ASHSDKVersion.version
      && containmentBody["system_state_class"] as? String == "CONTAINED" && haltBody["is_terminal"] as? Bool == true && haltBody["frozen"] as? Bool == true
      && (haltBody["full_diagnostic_chain"] as? [Any])?.count == terminal.diagnostics.count)
    frozenChain = terminal.diagnostics
    outcomes["sessionTerminal"] = terminal.runtimeMode.rawValue
    outcomes["sessionChainCount"] = String(terminal.diagnostics.count)
  }
  #endif
}
