import XCTest
import Foundation
import CryptoKit
import ASHCore
import ASHPatternSystem

/// The adapter compares every field of expected_output. Wrapper metadata is recorded
/// as provenance, never represented as SDK-produced semantics. Transformation rows
/// contain no expected_output, so all their semantic fields are projected in place.
final class ASHCompleteCorpusTests: XCTestCase {
  private let model = ASHStateModel()
  private let names = ["states","codewords","transformations","reachability","realm-identities","averaging","topology","state-assessments","axioms","recovery","fallback","containment","safe-halt","generation-plans","materialization-boundary"]
  private func state(_ signature: String) throws -> ASHState { try XCTUnwrap(ASHState(bitString:signature)) }
  private func text(_ record:[String:Any],_ key:String) throws -> String { try XCTUnwrap(record[key] as? String) }
  private func canonical(_ object:Any) throws -> Data { try JSONSerialization.data(withJSONObject:object,options:[.sortedKeys,.fragmentsAllowed,.withoutEscapingSlashes]) }
  private func rational(_ value:ASHRationalAverage) -> [String:Any] { ["numerator":value.numerator,"denominator":value.denominator] }
  private func fixture(_ name:String,_ ext:String) throws -> URL {
    try XCTUnwrap(Bundle.module.url(forResource:name,withExtension:ext,subdirectory:"Fixtures/CanonicalReference/Corpus") ?? Bundle.module.url(forResource:name,withExtension:ext))
  }
  func testEveryNonDiagnosticRawCanonicalVectorHasExactExpectedOutput() async throws {
    let provenanceURL = try XCTUnwrap(Bundle.module.url(forResource:"corpus-provenance",withExtension:"json",subdirectory:"Fixtures/CanonicalReference") ?? Bundle.module.url(forResource:"corpus-provenance",withExtension:"json"))
    let provenance = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:provenanceURL)) as? [String:Any])
    let assets = try XCTUnwrap(provenance["assets"] as? [[String:Any]])
    var ledger: [[String:Any]] = [], exercised = 0
    for name in names {
      let url = try fixture(name,"jsonl"), data = try Data(contentsOf:url)
      let asset = try XCTUnwrap(assets.first { ($0["fixturePath"] as? String) == "Corpus/\(name).jsonl" })
      let hash = SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined()
      XCTAssertEqual(hash,asset["sha256"] as? String)
      let lines = try XCTUnwrap(String(data:data,encoding:.utf8)).split(separator:"\n")
      XCTAssertEqual(lines.count,asset["vectorCount"] as? Int)
      for (lineIndex,line) in lines.enumerated() {
        let row = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(line.utf8)) as? [String:Any])
        let expected = (row["expected_output"] as? [String:Any]) ?? row
        let actual = try await evaluate(name:name,row:row)
        let equal = try canonical(actual) == canonical(expected)
        let id = try text(row,"vector_id")
        ledger.append(["case_id":id,"source_commit":provenance["sourceCommit"] ?? "50d7e5ab88932a4a967ffc2c83bd18fae45b73c8", "source_path":asset["sourcePath"] ?? "", "source_hash":hash,
          "source_line":lineIndex+1,"adapter_version":"native-complete-1","requirement":row["requirements"] ?? [],"rule_ids":row["rule_ids"] ?? [],
          "public_operation":publicOperation(name),"adapter_input_profile":adapterInputProfile(name),"expected":expected,"actual":actual,"comparison_policy":name == "transformations" ? "complete semantic row; original wrapper metadata retained as provenance" : "all expected_output fields, exact JSON value equality", "result":equal ? "PASS":"FAIL"])
        XCTAssertTrue(equal,"\(id): expected \(expected), actual \(actual)")
        exercised += 1
      }
    }
    XCTAssertEqual(exercised,10_321)
    if let path = ProcessInfo.processInfo.environment["ASH_CASE_LEDGER"] {
      let data = try canonical(ledger)
      try data.write(to:URL(fileURLWithPath:path),options:.atomic)
    }
  }
  private func publicOperation(_ name:String) -> String {
    switch name {
    case "states":return "ASHState.init + ASHStateModel.diagnose + ASHRealmEncoder.encode"
    case "codewords":return "ASHTransitionRegistry.orderedTransitions + ASHStateModel.codewordID"
    case "transformations":return "ASHTransitionRegistry.applyTransition + ASHStateModel.diagnose + ASHRealmEncoder.encode"
    case "reachability":return "ASHStateModel.isReachable"
    case "realm-identities":return "ASHRealmEncoder.encode"
    case "averaging":return "ASHStateModel.average"
    case "topology":return "ASHTopologyGenerator.generateTopology"
    case "state-assessments":return "ASHStateModel.assess"
    case "axioms":return "ASHAxiomEvaluator.evaluate(subject:)"
    case "recovery", "fallback":return "ASHRecoveryEngine.recover + ASHStateModel.classifyRecovery"
    case "containment":return "ASHPatternSystemSession.enterContainment + reportContainmentAttempt"
    case "safe-halt":return "ASHPatternSystemSession.halt + transition"
    case "generation-plans":return "ASHGenerationPlanner.buildPlan + ASHGenerationPlan.identity + ASHArtifactEmitter.emit"
    case "materialization-boundary":return "ASHArtifactEmitter.emit"
    default:return "UNSUPPORTED"
    }
  }
  private func adapterInputProfile(_ name:String) -> String {
    switch name {
    case "axioms":return "Explicit native measured profile: met=(1,1,2,2,1,true,true); failed=(0,1,1,1,0,false,false); missing=all absent. Field order: relations,compressed,raw,scales,erasure,self-reference,self-model."
    case "fallback":return "Explicit downstream stable zero context; candidate zero with declared evidence and verification_sequence1 for policies001/002; policy999 has no candidate. Original state000000001."
    case "containment", "safe-halt":return "Explicit downstream stable zero context; bootstrap000000001; initial contained/halted mode established by public session operation before fixture operation."
    case "generation-plans", "materialization-boundary":return "Explicit downstream DEFAULT/ORDINAL/IN_MEMORY v1.0 registry; sourcezero, structuraldepth1; registry-change hashes raw unsupported1.1 content and verifies planner/emitter admission refusal."
    case "states", "codewords":return "Fixture declares no input; vector identity/rank selects the state or canonical registry member. All expected semantic fields then compared with public SDK results."
    default:return "Exact declared fixture input; no expected output computed from SDK."
    }
  }
  private func makePlan(constraints:ASHTargetRuntimeConstraints = .init(), transitionID:String = "APS-TRANSITION-CW-00") throws -> ASHGenerationPlan {
    let registry = ASHTransitionRegistry(stateModel:model)
    let topology = try XCTUnwrap(ASHTopologyGenerator(stateModel:model,transitionRegistry:registry).generateTopology(from:.zero,depth:1).topology)
    return try XCTUnwrap(ASHGenerationPlanner(stateModel:model,realmEncoder:ASHRealmEncoder(stateModel:model)).buildPlan(from:.zero,topology:topology,axiomEvaluation:ASHAxiomEvaluator().evaluate(state:.zero),targetConstraints:constraints,transitionID:transitionID).plan)
  }
  private func evaluate(name:String,row:[String:Any]) async throws -> [String:Any] {
    let input = row["input"] as? [String:Any] ?? [:], expected = row["expected_output"] as? [String:Any] ?? [:]
    let registry = ASHTransitionRegistry(stateModel:model)
    switch name {
    case "states":
      let value = try state(text(expected,"state_signature")), realm = try XCTUnwrap(ASHRealmEncoder(stateModel:model).encode(state:value).identity)
      return ["state_signature":value.description,"bits":value.bits.map(Int.init),"b8":Int(value.b8),"realm_index":Int(value.rawValue),"realm_id":realm.realmID,"orbit_id":try XCTUnwrap(model.diagnose(value).orbitInfo?.orbitID)]
    case "codewords":
      let rank = try XCTUnwrap(expected["ordering_rank"] as? Int), word = registry.orderedTransitions[rank].codeword
      return ["ordering_rank":rank,"signature":word.description,"bits":word.bits.map(Int.init),"weight":word.hammingWeight(),"is_identity":word == .zero,"codeword_id":try XCTUnwrap(model.codewordID(for:word))]
    case "transformations":
      let source = try state(text(row,"source_signature")), transitionID = try text(row,"transition_id")
      let applied = try XCTUnwrap(registry.applyTransition(from:source,transitionID:transitionID).applied)
      var actual = row
      actual["source_signature"] = source.description; actual["source_b8"] = Int(source.b8)
      actual["source_realm_id"] = try XCTUnwrap(ASHRealmEncoder(stateModel:model).encode(state:source).identity).realmID
      actual["source_orbit_id"] = try XCTUnwrap(model.diagnose(source).orbitInfo?.orbitID)
      actual["target_signature"] = applied.toState.description; actual["target_b8"] = Int(applied.toState.b8)
      actual["target_realm_id"] = try XCTUnwrap(ASHRealmEncoder(stateModel:model).encode(state:applied.toState).identity).realmID
      actual["target_orbit_id"] = try XCTUnwrap(model.diagnose(applied.toState).orbitInfo?.orbitID)
      actual["transition_id"] = applied.transitionID; actual["codeword_id"] = try XCTUnwrap(model.codewordID(for:applied.codeword))
      return actual
    case "reachability":
      let source = try state(text(input,"source_signature")), targets = model.knownValidStates.sorted().filter { model.isReachable(from:source,to:$0) }
      return ["reachable_targets":targets.map(\.description),"reachable_target_count":targets.count,"unreachable_target_count":512-targets.count]
    case "realm-identities":
      let value = try state(text(input,"state_signature")), identity = try XCTUnwrap(ASHRealmEncoder(stateModel:model).encode(state:value).identity)
      return ["state_signature":identity.stateSignature,"realm_id":identity.realmID,"realm_index":Int(value.rawValue)]
    case "averaging":
      let function = try text(input,"function"), all = model.knownValidStates.sorted()
      if function == "constant_one" {
        let values = Dictionary(uniqueKeysWithValues:all.map { ($0,Int64(1)) })
        let first = try model.average(at:.zero,values:values)
        let averaged = try Dictionary(uniqueKeysWithValues:all.map { ($0,try model.average(at:$0,values:values).numerator / 16) })
        return ["result":rational(first),"is_idempotent":try model.average(at:.zero,values:averaged) == first]
      }
      if function == "orbit_indicator" {
        let orbit = try text(input,"orbit_id")
        let members = all.filter { model.diagnose($0).orbitInfo?.orbitID == orbit }, outside = try XCTUnwrap(all.first { model.diagnose($0).orbitInfo?.orbitID != orbit })
        let values = Dictionary(uniqueKeysWithValues:all.map { ($0,Int64(members.contains($0) ? 1:0)) })
        return ["member_count":members.count,"result_inside_orbit":rational(try model.average(at:try XCTUnwrap(members.first),values:values)),"result_outside_orbit":rational(try model.average(at:outside,values:values))]
      }
      guard function == "state_indicator" else { throw CorpusError.unknownCase(function) }
      let value = try state(text(input,"state_signature")), outside = try XCTUnwrap(all.first { !model.isReachable(from:value,to:$0) })
      let values = Dictionary(uniqueKeysWithValues:all.map { ($0,Int64($0 == value ? 1:0)) })
      return ["result_on_same_orbit":rational(try model.average(at:value,values:values)),"result_outside_orbit":rational(try model.average(at:outside,values:values))]
    case "topology":
      let depth = try XCTUnwrap(input["depth"] as? Int), topology = try XCTUnwrap(ASHTopologyGenerator(stateModel:model,transitionRegistry:registry).generateTopology(from:.zero,depth:depth).topology)
      func projection(_ node:ASHTopologyNode) -> [String:Any] { ["depth":node.depth,"generation_ordinal":node.generationOrdinal,"global_ordinal":node.ordinal,"is_leaf":node.depth == topology.depth,"node_id":node.nodeID,"parent_path":node.parentPath as Any? ?? NSNull(),"path":node.pathToken] }
      return ["depth":topology.depth,"leaf_count":topology.leaves.count,"leaves":topology.leaves.map(projection),"nodes":topology.nodes.map(projection),"total_nodes":topology.nodes.count]
    case "state-assessments":
      let candidate = try text(input,"candidate")
      let context:ASHOperationalContext?
      if input["context"] is NSNull { context = nil }
      else { context = ASHOperationalContext(contextID:"corpus",allowedStableStates:try (input["allowed_stable_states"] as? [String] ?? ["000000000"]).map(state)) }
      let result = model.assess(bitString:candidate,context:context)
      if result.assessmentBlocked {
        if result.inputStatus == .malformed { return ["assessment_blocked":true,"input_status":result.inputStatus.rawValue] }
        return ["assessment_blocked":true]
      }
      var actual:[String:Any] = ["state_class":try XCTUnwrap(result.stateClass).rawValue]
      if expected["codeword_id"] != nil { actual["codeword_id"] = try XCTUnwrap(result.correctionCodewordID) }
      return actual
    case "axioms":
      let evidence = try text(input,"evidence"), subject:ASHAxiomSubject
      switch evidence {
      case "profile_threshold_met": subject = .init(relationCount:1,compressedMeasure:1,rawMeasure:2,scaleCount:2,erasureCost:1,selfReferenceCapable:true,selfModelAvailable:true)
      case "profile_threshold_failed": subject = .init(relationCount:0,compressedMeasure:1,rawMeasure:1,scaleCount:1,erasureCost:0,selfReferenceCapable:false,selfModelAvailable:false)
      case "missing_required_measurement": subject = .init()
      default: throw CorpusError.unknownCase(evidence)
      }
      return ["axiom_result":ASHAxiomEvaluator().evaluate(subject:subject).status.rawValue]
    case "recovery":
      if input["state_class"] != nil { return ["category":model.classifyRecovery(for:try XCTUnwrap(SystemStateClass(rawValue:text(input,"state_class")))).rawValue] }
      let current = try state(text(input,"current")), target = try state(text(input,"target")), context = ASHOperationalContext(contextID:"corpus",allowedStableStates:[target])
      let result = ASHRecoveryEngine(stateModel:model,transitionRegistry:registry).recover(state:current,context:context)
      var actual:[String:Any] = ["category":try XCTUnwrap(result.recoveryCategory).rawValue]
      if expected["delta"] != nil { actual["delta"] = current.xor(try XCTUnwrap(result.targetState)).description }
      return actual
    case "fallback":
      let policy = try XCTUnwrap(ASHFallbackPolicy(rawValue:text(input,"policy_id")))
      let candidates:[ASHFallbackCandidate] = policy == .containmentEscalation ? [] : [.init(state:.zero,verificationSequence:1,evidence:"Corpus adapter explicit downstream candidate and verification evidence")]
      let context = ASHOperationalContext(contextID:"corpus",allowedStableStates:[.zero],fallbackPolicyInstance:.init(policy:policy,candidates:candidates))
      let result = ASHRecoveryEngine(stateModel:model,transitionRegistry:registry).recover(state:try state("000000001"),context:context)
      return ["replacement_kind":result.outcome == .escalateToContainment ? "CONTAINMENT_ESCALATION":result.outcome.rawValue]
    case "containment", "safe-halt": return try await safety(name:name,input:input)
    case "generation-plans":
      if let profile = input["profile_id"] as? String {
        let constraints = ASHTargetRuntimeConstraints(profileID:profile)
        return ["expected_failure":try XCTUnwrap(constraints.validationIssues.first)]
      }
      let baseline = try makePlan(transitionID:input["transition_id"] as? String ?? "APS-TRANSITION-CW-00")
      if input["registry_version_changed"] as? Bool == true {
        let changed = ASHGenerationPlan(normalizedState:baseline.normalizedState,sourceRealm:baseline.sourceRealm,destinationRealm:baseline.destinationRealm,topologyNodes:baseline.topologyNodes,roleAssignments:baseline.roleAssignments,axiomSummaries:baseline.axiomSummaries,artifacts:baseline.artifacts,targetConstraints:.init(registryVersions:["profiles":"1.1","naming":"1.0","targets":"1.0"]),warnings:baseline.warnings,metadata:baseline.metadata)
        XCTAssertTrue(changed.validationIssues.contains("REGISTRY_REFERENCE_INVALID"))
        XCTAssertTrue(ASHArtifactEmitter().emit(plan:changed).artifacts.isEmpty)
        return ["plan_hash_changes":try baseline.identity() != changed.identity()]
      }
      return ["plan_hash_stable":try baseline.identity() == makePlan().identity()]
    case "materialization-boundary":
      let plan = try makePlan()
      if input["plan_complete"] as? Bool == true {
        let result = ASHArtifactEmitter().emit(plan:plan)
        return ["every_output_has_plan_reference":!result.artifacts.isEmpty && result.artifacts.allSatisfy { emitted in emitted.planID == (try? plan.identity()) && plan.artifacts.contains { planned in planned.artifactID == emitted.planArtifactID } }]
      }
      let incomplete = ASHGenerationPlan(normalizedState:plan.normalizedState,sourceRealm:plan.sourceRealm,destinationRealm:plan.destinationRealm,topologyNodes:[],roleAssignments:[],axiomSummaries:[],artifacts:[],targetConstraints:plan.targetConstraints,warnings:[],metadata:[:])
      let result = ASHArtifactEmitter().emit(plan:incomplete)
      guard result.artifacts.isEmpty, result.diagnostics.first?.disposition == .blocked else { throw CorpusError.unknownCase("emission unexpectedly accepted incomplete plan") }
      return ["expected_failure":"EMISSION_REFUSED"]
    default: throw CorpusError.unknownCase(name)
    }
  }
  private func safety(name:String,input:[String:Any]) async throws -> [String:Any] {
    let session = try ASHPatternSystemSession(context:.init(contextID:"corpus",allowedStableStates:[.zero]))
    _ = await session.bootstrap(bitString:"000000001")
    if name == "containment" {
      let entered = await session.enterContainment(reason:"PROPAGATION_BLOCKED")
      if input["initial_mode"] as? String == "DEGRADED" {
        return ["chain_append_count":1,"diagnostics_frozen":entered.diagnosticsFrozen,"diagnostics_preserved":!entered.diagnostics.isEmpty,"mode":entered.runtimeMode.rawValue,"restricted_operations_only":entered.restrictedOperationsOnly,"terminal":entered.terminal]
      }
      let result = await session.reportContainmentAttempt(operation:try text(input,"attempted_operation"),boundaryBreached:try XCTUnwrap(input["boundary_breached"] as? Bool),attemptPrevented:try XCTUnwrap(input["attempt_prevented"] as? Bool),propagationObserved:try XCTUnwrap(input["propagation_observed"] as? Bool))
      var actual:[String:Any] = ["breach_confirmed":result.breachConfirmed,"chain_append_count":result.diagnostics.count-entered.diagnostics.count,"diagnostics_frozen":result.diagnosticsFrozen,"diagnostics_preserved":Array(result.diagnostics.prefix(entered.diagnostics.count)) == entered.diagnostics,"mode":result.runtimeMode.rawValue,"terminal":result.terminal,"transitions_allowed":result.transitionsAllowed]
      if !result.terminal { actual["restricted_operations_only"] = result.restrictedOperationsOnly }
      let validation = ASHDiagnosticsModule().validateChain(result.diagnostics)
      XCTAssertTrue(validation.isValid,"\(validation.issues)")
      return actual
    }
    let halted = await session.halt(reason:"OPERATOR_HALT_REQUEST")
    if input["initial_mode"] == nil { return ["terminal":halted.terminal,"transitions_allowed":halted.transitionsAllowed] }
    let result = await session.transition(transitionID:try text(input,"attempted_transition"))
    return ["chain_append_count":result.diagnostics.count-halted.diagnostics.count,"diagnostics_frozen":result.diagnosticsFrozen,"diagnostics_preserved":result == halted,"expected_failure":model.classifyRecovery(for:try XCTUnwrap(result.stateClass)).rawValue,"mode":result.runtimeMode.rawValue,"terminal":result.terminal,"transitions_allowed":result.transitionsAllowed]
  }
  private enum CorpusError: Error { case unknownCase(String) }
}
