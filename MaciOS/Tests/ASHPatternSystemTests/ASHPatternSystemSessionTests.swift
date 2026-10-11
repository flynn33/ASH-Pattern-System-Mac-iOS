import XCTest
import ASHCore
import ASHPatternSystem

final class ASHPatternSystemSessionTests: XCTestCase {
  private func session(_ stable:[ASHState] = [.zero]) throws -> ASHPatternSystemSession { try .init(context:.init(contextID:"test",allowedStableStates:stable)) }
  private func validate(_ snapshot:ASHPatternSystemSnapshot, file:StaticString = #filePath,line:UInt = #line) {
    let result = ASHDiagnosticsModule().validateChain(snapshot.diagnostics)
    XCTAssertTrue(result.isValid,"\(result.issues)",file:file,line:line)
  }
  func testCorrectionAmbiguityAndAuthorizedContextResolution() async throws {
    let other = try XCTUnwrap(ASHState(bitString:"001100110")), value = try session([.zero,other])
    let initial = await value.bootstrap(bitString:"000011110")
    XCTAssertEqual(initial.stateClass,.unstable); validate(initial)
    let blocked = await value.recover()
    XCTAssertEqual(blocked.state,initial.state); XCTAssertEqual(blocked.recoveryOutcome,.targetResolutionBlocked); validate(blocked)
    let context = ASHOperationalContext(contextID:"resolved",allowedStableStates:[.zero,other],preferredState:.zero)
    let resolved = await value.resolveContext(context,authority:"operator")
    XCTAssertEqual(resolved.stateClass,.correctable); validate(resolved)
    let recovered = await value.recover()
    XCTAssertEqual(recovered.state,.zero); XCTAssertEqual(recovered.stateClass,.stable); validate(recovered)
  }
  func testMalformedBootstrapRecordsUsefulFailureAndPermitsCorrectedInput() async throws {
    let value = try session()
    let malformed = await value.bootstrap(bitString:"bad-input")
    XCTAssertNil(malformed.state); XCTAssertNil(malformed.stateClass)
    XCTAssertEqual(malformed.diagnostics.first?.diagnosticKind,.inputValidation); validate(malformed)
    let corrected = await value.bootstrap(bitString:"000000000")
    XCTAssertEqual(corrected.state,.zero); validate(corrected)
  }
  func testContainedAttemptsRemainRestrictedUntilConfirmedBreach() async throws {
    let value = try session()
    _ = await value.bootstrap(bitString:"000000001")
    let contained = await value.enterContainment(reason:"operator")
    XCTAssertEqual(contained.runtimeMode,.contained); XCTAssertFalse(contained.terminal); validate(contained)
    let denied = await value.transition(transitionID:"APS-TRANSITION-CW-01")
    XCTAssertEqual(denied.state,contained.state); XCTAssertEqual(denied.runtimeMode,.contained); validate(denied)
    let blocked = await value.reportContainmentAttempt(operation:"UNDECLARED_WRITE",boundaryBreached:false,attemptPrevented:true,propagationObserved:false)
    XCTAssertEqual(blocked.diagnostics.count,denied.diagnostics.count+1); XCTAssertFalse(blocked.breachConfirmed); validate(blocked)
    let breach = await value.reportContainmentAttempt(operation:"UNDECLARED_WRITE",boundaryBreached:true,attemptPrevented:false,propagationObserved:true)
    XCTAssertEqual(breach.diagnostics.count,blocked.diagnostics.count+2); XCTAssertTrue(breach.breachConfirmed)
    XCTAssertTrue(breach.terminal); XCTAssertTrue(breach.diagnosticsFrozen); validate(breach)
  }
  func testEveryPublicMutationEntryReturnsOriginalFrozenSnapshot() async throws {
    let value = try session()
    _ = await value.bootstrap(bitString:"000000000")
    let planned = await value.plan(depth:1), plan = try XCTUnwrap(planned.plan)
    let halted = await value.halt(reason:"operator")
    validate(halted)
    let bootstrap = await value.bootstrap(bitString:"111111111")
    let transition = await value.transition(transitionID:"APS-TRANSITION-CW-01")
    let recovery = await value.recover()
    let context = await value.resolveContext(.init(contextID:"new",allowedStableStates:[.zero]),authority:"operator")
    let containment = await value.enterContainment(reason:"operator")
    let attempt = await value.reportContainmentAttempt(operation:"WRITE",boundaryBreached:true,attemptPrevented:false,propagationObserved:true)
    let resolution = await value.resolveContainment(authority:"operator")
    let failed = await value.markFailed(reason:"exhausted")
    let halt = await value.halt(reason:"repeat")
    let planning = await value.plan(depth:2)
    let emission = await value.emit(plan:plan)
    let snapshot = await value.snapshot()
    for result in [bootstrap,transition,recovery,context,containment,attempt,resolution,failed,halt,planning.snapshot,emission.snapshot,snapshot] { XCTAssertEqual(result,halted) }
    XCTAssertNil(planning.plan); XCTAssertTrue(emission.artifacts.isEmpty)
    let independent = try session(), fresh = await independent.bootstrap(bitString:"000000000")
    XCTAssertFalse(fresh.terminal); XCTAssertTrue(fresh.transitionsAllowed)
  }
  func testFailedRuntimeAwaitsAuthorityAndHaltRemainsExplicit() async throws {
    let value = try session()
    _ = await value.bootstrap(bitString:"000000000")
    let failed = await value.markFailed(reason:"correction and fallback exhausted")
    XCTAssertEqual(failed.stateClass,.failed); XCTAssertFalse(failed.terminal); validate(failed)
    let blocked = await value.recover()
    XCTAssertEqual(blocked.stateClass,.failed); XCTAssertFalse(blocked.terminal); validate(blocked)
    let halted = await value.halt(reason:"external authority")
    XCTAssertTrue(halted.terminal); validate(halted)
  }
  func testConcurrentTransitionsAreSerializedAndHaltFreezesFinalState() async throws {
    let value = try session()
    _ = await value.bootstrap(bitString:"000000000")
    await withTaskGroup(of:Void.self) { group in
      for _ in 0..<20 { group.addTask { _ = await value.transition(transitionID:"APS-TRANSITION-CW-01") } }
    }
    let result = await value.snapshot()
    XCTAssertEqual(result.state,.zero); XCTAssertEqual(result.diagnostics.count,22); validate(result)
    let halted = await value.halt(reason:"operator")
    await withTaskGroup(of:Void.self) { group in
      for _ in 0..<20 { group.addTask { _ = await value.recover() } }
    }
    let final = await value.snapshot(); XCTAssertEqual(final,halted)
  }
  func testInjectedSupportCollectorCapturesOperationsAndReceivesNoPostHaltMutations() async throws {
    let collector = try ASHSupportDiagnostics.makeCollector(identity:.init(version:ASHSDKVersion.version,build:ASHSDKVersion.buildNumber))
    let value = try ASHPatternSystemSession(context:.init(contextID:"support",allowedStableStates:[.zero]),supportDiagnostics:collector)
    _ = await value.bootstrap(bitString:"000000000")
    _ = await value.transition(transitionID:"unknown")
    let halted = await value.halt(reason:"operator")
    let before = await collector.snapshot()
    _ = await value.recover(); _ = await value.bootstrap(bitString:"000000001"); _ = await value.halt(reason:"repeat")
    let after = await collector.snapshot()
    XCTAssertEqual(before.events,after.events)
    XCTAssertEqual(before.events.count,3)
    XCTAssertEqual(before.events.last?.context["classification"],"SAFE_HALT")
    let frozen = await value.snapshot(); XCTAssertEqual(frozen,halted)
    await collector.shutdown()
  }
  func testSessionRefusesPlanForAnotherStateWithoutPartialMaterialization() async throws {
    let value = try session()
    _ = await value.bootstrap(bitString:"000000000")
    let planning = await value.plan(depth:1), plan = try XCTUnwrap(planning.plan)
    _ = await value.transition(transitionID:"APS-TRANSITION-CW-01")
    let result = await value.emit(plan:plan)
    XCTAssertTrue(result.artifacts.isEmpty); XCTAssertEqual(result.snapshot.diagnostics.last?.disposition,.blocked)
    validate(result.snapshot)
  }
  func testCollectorRefusalDoesNotAlterRecoveryOrFrozenSemanticSnapshot() async throws {
    let collector = try ASHSupportDiagnostics.makeCollector(identity:.init(version:ASHSDKVersion.version,build:ASHSDKVersion.buildNumber))
    let value = try ASHPatternSystemSession(context:.init(contextID:"bounded-support",allowedStableStates:[.zero]),supportDiagnostics:collector)
    _ = await value.bootstrap(bitString:"000011110")
    let recovered = await value.recover(); XCTAssertEqual(recovered.state,.zero); XCTAssertEqual(recovered.stateClass,.stable)
    for _ in 0..<70 { _ = await value.transition(transitionID:"APS-TRANSITION-CW-00") }
    let failures = await value.supportDiagnosticFailureCount(); XCTAssertGreaterThan(failures,0)
    let halted = await value.halt(reason:"operator")
    let repeatResult = await value.halt(reason:"repeat"); XCTAssertEqual(repeatResult,halted)
    validate(halted)
    await collector.shutdown()
  }
  func testPreBootstrapDenialsPreserveRetryableParsePhaseAndExportableChain() async throws {
    let collector = try ASHSupportDiagnostics.makeCollector(identity:.init(version:ASHSDKVersion.version,build:ASHSDKVersion.buildNumber))
    let value = try ASHPatternSystemSession(context:.init(contextID:"pre-bootstrap",allowedStableStates:[.zero]),supportDiagnostics:collector)
    let producer = try session(); _ = await producer.bootstrap(bitString:"000000000")
    let planResult = await producer.plan(depth:0), plan = try XCTUnwrap(planResult.plan)
    let context = ASHOperationalContext(contextID:"replacement",allowedStableStates:[.zero])
    let transition = await value.transition(transitionID:"APS-TRANSITION-CW-00")
    let recovery = await value.recover()
    let resolving = await value.resolveContext(context,authority:"operator")
    let containment = await value.enterContainment(reason:"operator")
    let reporting = await value.reportContainmentAttempt(operation:"WRITE",boundaryBreached:false,attemptPrevented:true,propagationObserved:false)
    let containedResolution = await value.resolveContainment(authority:"operator")
    let failed = await value.markFailed(reason:"external failure")
    let planning = await value.plan(depth:1)
    let emitting = await value.emit(plan:plan)
    for snapshot in [transition,recovery,resolving,containment,reporting,containedResolution,failed,planning.snapshot,emitting.snapshot] {
      XCTAssertNil(snapshot.state); XCTAssertFalse(snapshot.terminal)
      XCTAssertEqual(snapshot.diagnostics.last?.stage,.parse); validate(snapshot)
    }
    let initialized = await value.bootstrap(bitString:"000000000")
    XCTAssertEqual(initialized.state,.zero); XCTAssertEqual(initialized.stateClass,.stable); validate(initialized)
    let failureCount = await value.supportDiagnosticFailureCount(); XCTAssertEqual(failureCount,0)
    let captured = await collector.snapshot(); XCTAssertEqual(captured.events.count,10)
    let temporary = FileManager.default.temporaryDirectory.path
    let physical = temporary.hasPrefix("/var/") ? "/private" + temporary : temporary
    let destination = URL(fileURLWithPath:physical,isDirectory:true).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at:destination,withIntermediateDirectories:false)
    defer { try? FileManager.default.removeItem(at:destination) }
    let exported = try await collector.export(to:destination)
    XCTAssertTrue(FileManager.default.fileExists(atPath:exported.json.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath:exported.markdown.path))
    await collector.shutdown()
  }
  func testExplicitHaltBeforeBootstrapRemainsTerminalWithoutManufacturedState() async throws {
    let value = try session(), halted = await value.halt(reason:"operator")
    XCTAssertNil(halted.state); XCTAssertTrue(halted.terminal); validate(halted)
    let bootstrap = await value.bootstrap(bitString:"000000000"); XCTAssertEqual(bootstrap,halted)
  }
  func testContradictoryContainmentEvidenceIsRejectedWithoutMutationOrHalt() async throws {
    let value = try session(); _ = await value.bootstrap(bitString:"000000001")
    var preceding = await value.enterContainment(reason:"operator")
    for (breached,prevented,propagated) in [(true,true,true),(false,false,true),(true,false,false),(false,true,true),(true,true,false)] {
      let result = await value.reportContainmentAttempt(operation:"WRITE",boundaryBreached:breached,attemptPrevented:prevented,propagationObserved:propagated)
      XCTAssertEqual(result.state,preceding.state); XCTAssertEqual(result.runtimeMode,.contained)
      XCTAssertFalse(result.terminal); XCTAssertFalse(result.breachConfirmed)
      XCTAssertEqual(result.diagnostics.count,preceding.diagnostics.count+1)
      XCTAssertEqual(result.diagnostics.last?.details["observation_validation"],.string("REJECTED_INCONSISTENT_EVIDENCE"))
      validate(result); preceding=result
    }
  }
  func testRepeatedSemanticContentKeepsIdentityIndependentOfOccurrencePlacement() async throws {
    let value = try session(); _ = await value.bootstrap(bitString:"000000000")
    let first = await value.transition(transitionID:"APS-TRANSITION-CW-00")
    let second = await value.transition(transitionID:"APS-TRANSITION-CW-00")
    let a = try XCTUnwrap(first.diagnostics.last), b = try XCTUnwrap(second.diagnostics.last)
    XCTAssertEqual(a.diagnosticReference,b.diagnosticReference)
    XCTAssertNotEqual(a.sequenceNumber,b.sequenceNumber)
    XCTAssertEqual(b.parentDiagnosticReference,a.diagnosticReference)
    validate(second)
  }
  func testCanonicalSafetyRecordsPreserveFullByValueChainsAndStoredOccurrenceTimes() async throws {
    let value = try session(); _ = await value.bootstrap(bitString:"000000001")
    let contained = await value.enterContainment(trigger:.operatorRequest,reason:"operator")
    let containmentJSON = try XCTUnwrap(contained.containmentRecordJSONData)
    let containment = try XCTUnwrap(JSONSerialization.jsonObject(with:containmentJSON) as? [String:Any])
    let containmentData = try XCTUnwrap(containment["data"] as? [String:Any])
    let originalChain = try XCTUnwrap(containmentData["full_diagnostic_chain"] as? [[String:Any]])
    XCTAssertEqual(containment["schema_version"] as? String,"1.0")
    XCTAssertEqual(containment["id"] as? String,contained.diagnostics.last?.diagnosticReference)
    XCTAssertEqual(containmentData["trigger"] as? String,"OPERATOR_REQUEST")
    XCTAssertEqual(containmentData["system_state_class"] as? String,"CONTAINED")
    XCTAssertEqual(containmentData["resolution"] as? String,"PENDING")
    XCTAssertEqual(containmentData["awaiting_resolution"] as? Bool,true)
    XCTAssertEqual(originalChain.count,contained.diagnostics.count)
    XCTAssertEqual(try JSONSerialization.data(withJSONObject:try XCTUnwrap(containmentData["original_diagnostic"]),options:.sortedKeys),try JSONSerialization.data(withJSONObject:originalChain[0],options:.sortedKeys))
    XCTAssertEqual(try JSONSerialization.data(withJSONObject:try XCTUnwrap(containmentData["diagnostic"]),options:.sortedKeys),try JSONSerialization.data(withJSONObject:try XCTUnwrap(originalChain.last),options:.sortedKeys))
    let entryTime = try XCTUnwrap(containmentData["containment_time"] as? String)
    XCTAssertEqual(contained.diagnostics.last?.occurrenceMetadata?["containment_time"],.string(entryTime))
    XCTAssertNotNil(ISO8601DateFormatter().date(from:entryTime))
    let resolved = await value.resolveContainment(authority:"operator")
    let resolutionJSON = try XCTUnwrap(resolved.containmentRecordJSONData)
    let resolution = try XCTUnwrap(JSONSerialization.jsonObject(with:resolutionJSON) as? [String:Any]), resolutionData = try XCTUnwrap(resolution["data"] as? [String:Any])
    XCTAssertEqual(resolutionData["containment_time"] as? String,entryTime)
    XCTAssertEqual(resolutionData["resolution"] as? String,"OPERATOR_DIRECTED")
    XCTAssertEqual(resolutionData["awaiting_resolution"] as? Bool,false)
    let halted = await value.reportContainmentAttempt(operation:"WRITE",boundaryBreached:true,attemptPrevented:false,propagationObserved:true)
    let haltJSON = try XCTUnwrap(halted.safeHaltRecordJSONData), halt = try XCTUnwrap(JSONSerialization.jsonObject(with:haltJSON) as? [String:Any]), haltData = try XCTUnwrap(halt["data"] as? [String:Any])
    let haltChain = try XCTUnwrap(haltData["full_diagnostic_chain"] as? [[String:Any]])
    XCTAssertEqual(halt["id"] as? String,halted.diagnostics.last?.diagnosticReference)
    XCTAssertEqual(haltData["trigger"] as? String,"CONTAINMENT_BREACH")
    XCTAssertEqual(haltData["system_state_class"] as? String,"SAFE_HALT")
    XCTAssertEqual(haltData["is_terminal"] as? Bool,true); XCTAssertEqual(haltData["frozen"] as? Bool,true)
    XCTAssertEqual(haltChain.count,halted.diagnostics.count)
    let haltTime = try XCTUnwrap(haltData["halt_time"] as? String)
    XCTAssertNotNil(ISO8601DateFormatter().date(from:haltTime))
    XCTAssertEqual(halted.diagnostics.last?.occurrenceMetadata?["halt_time"],.string(haltTime))
    let frozen = await value.halt(reason:"repeat")
    XCTAssertEqual(frozen.safeHaltRecordJSONData,haltJSON)
    XCTAssertEqual(frozen.containmentRecordJSONData,halted.containmentRecordJSONData)
    if let path = ProcessInfo.processInfo.environment["ASH_SAFETY_RECORD_EVIDENCE"] {
      let directory = URL(fileURLWithPath:path)
      try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
      try containmentJSON.write(to:directory.appendingPathComponent("containment-entry.json"),options:.atomic)
      try resolutionJSON.write(to:directory.appendingPathComponent("containment-resolution.json"),options:.atomic)
      try XCTUnwrap(halted.containmentRecordJSONData).write(to:directory.appendingPathComponent("containment-breach.json"),options:.atomic)
      try haltJSON.write(to:directory.appendingPathComponent("safe-halt-breach.json"),options:.atomic)
    }
  }
  func testTypedHaltTriggersRequireTheirObservedRuntimePreconditions() async throws {
    let value = try session(); _ = await value.bootstrap(bitString:"000000000")
    for trigger in [ASHSafeHaltTrigger.containmentBreach,.escalationFromFailed,.unresolvableBlockedRecovery] {
      let result = await value.halt(trigger:trigger,reason:"unsubstantiated trigger")
      XCTAssertFalse(result.terminal); XCTAssertEqual(result.state,.zero); validate(result)
    }
    let failed = await value.markFailed(reason:"external report")
    XCTAssertEqual(failed.runtimeMode,.failed)
    let halted = await value.halt(trigger:.escalationFromFailed,reason:"external authority")
    XCTAssertTrue(halted.terminal); validate(halted)

    let model = ASHStateModel(), words = model.codewordSet.sorted()
    let ambiguousContext = ASHOperationalContext(contextID:"halt-ambiguous",allowedStableStates:[.zero,words[1]])
    let blocked = try ASHPatternSystemSession(context:ambiguousContext)
    _ = await blocked.bootstrap(bitString:words[2].description); _ = await blocked.recover()
    let availableContainment = await blocked.halt(trigger:.unresolvableBlockedRecovery,reason:"containment remains available")
    XCTAssertFalse(availableContainment.terminal); XCTAssertEqual(availableContainment.state,words[2]); validate(availableContainment)

    let resolved = try ASHPatternSystemSession(context:ambiguousContext)
    _ = await resolved.bootstrap(bitString:words[2].description); _ = await resolved.recover()
    _ = await resolved.resolveContext(.init(contextID:"halt-resolved",allowedStableStates:[.zero]),authority:"operator")
    let staleBlocked = await resolved.halt(trigger:.unresolvableBlockedRecovery,reason:"historical blocked outcome")
    XCTAssertFalse(staleBlocked.terminal); XCTAssertEqual(staleBlocked.stateClass,.correctable); validate(staleBlocked)

    let contained = try session(); _ = await contained.bootstrap(bitString:"000000001"); _ = await contained.recover()
    let containmentOption = await contained.halt(trigger:.unresolvableBlockedRecovery,reason:"containment already active")
    XCTAssertFalse(containmentOption.terminal); XCTAssertEqual(containmentOption.runtimeMode,.contained); validate(containmentOption)
  }
}
