import XCTest
import ASHCore

private func supportEvent(_ n: Int = 0) -> ASHSupportEventInput {
    ASHSupportEventInput(operation: "state-assessment", correlation: "operation-\(n)", expected: "Reject raw 512",
      actual: "Controlled invalid input", context: ["fixture": "synthetic-512", "private_payload": "customer secret"],
      failure: ASHSupportFailure(domain: "ASHState", code: "invalid-state", message: "Malformed 9-bit input", causes: ["raw=512"]))
  }


final class ASHSupportDiagnosticsTests: XCTestCase {
  private func collector() throws -> any ASHSupportDiagnosticCollecting {
    try ASHSupportDiagnostics.makeCollector(identity: ASHSupportIdentity(version: "1.0.0-rc.1", build: "1"))
  }
  private func directory() throws -> URL {
    if let evidence = ProcessInfo.processInfo.environment["ASH_SUPPORT_EVIDENCE_ROOT"] {
      let directory = URL(fileURLWithPath: evidence).appendingPathComponent(UUID().uuidString)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      return directory
    }
    // Foundation preserves the system /var alias even after resolvingSymlinksInPath.
    let temporary = FileManager.default.temporaryDirectory.path
    let physical = temporary.hasPrefix("/var/") ? "/private" + temporary : temporary
    let directory = URL(fileURLWithPath: physical).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    addTeardownBlock { try FileManager.default.removeItem(at: directory) }
    return directory
  }

  func testControlledFailurePairedExportAndShutdown() async throws {
    let collector = try collector()
    do {
      _ = try JSONDecoder().decode(ASHState.self, from: Data("{\"rawValue\":512}".utf8))
      XCTFail("Controlled invalid state was accepted")
    } catch DecodingError.dataCorrupted { }
    try await collector.capture(supportEvent())
    let export = try await collector.export(to: directory())
    let parsed = try JSONDecoder().decode(ASHSupportSnapshot.self, from: Data(contentsOf: export.json))
    XCTAssertEqual(parsed, export.snapshot)
    let markdown = try String(contentsOf: export.markdown, encoding: .utf8)
    XCTAssertTrue(markdown.contains(parsed.bundleID))
    XCTAssertTrue(markdown.contains(parsed.events[0].id))
    XCTAssertTrue(markdown.contains("Reject raw 512"))
    XCTAssertTrue(markdown.contains("Malformed 9-bit input"))
    XCTAssertFalse(markdown.contains("customer secret"))
    XCTAssertEqual(parsed.excludedFields, 1)
    #if DEBUG
    XCTAssertEqual(parsed.profile, "development")
    #else
    XCTAssertEqual(parsed.profile, "release-minimal")
    #endif
    await collector.shutdown()
    do { try await collector.capture(supportEvent()); XCTFail("Capture after shutdown accepted") }
    catch { XCTAssertEqual(error as? ASHSupportError, .closed) }
    await collector.purge()
    let purged = await collector.snapshot()
    XCTAssertTrue(purged.events.isEmpty)
  }

  func testSecretsExcludedBeforeRetentionAndBothExports() async throws {
    let collector = try collector()
    let secrets = ["hiddenBearerValue", "hiddenPasswordValue", "hiddenURLValue", "hiddenNestedValue", "private-name", "sk-secretvalue"]
    try await collector.capture(ASHSupportEventInput(operation: "decode", correlation: "secret-test", expected: "safe redaction",
      actual: "Authorization: Bearer hiddenBearerValue", context: ["password": "hiddenPasswordValue", "fixture": "https://user:pass@example.com/?token=hiddenURLValue", "state": "/Users/private-name/secrets"],
      failure: ASHSupportFailure(domain: "test", code: "sk-secretvalue", message: "{\"password\":\"hiddenNestedValue\"}", causes: ["password=hiddenPasswordValue"])))
    let retained = await collector.snapshot()
    let encoded = String(decoding: try JSONEncoder().encode(retained), as: UTF8.self)
    let export = try await collector.export(to: directory())
    let persisted = try String(contentsOf: export.json, encoding: .utf8) + String(contentsOf: export.markdown, encoding: .utf8)
    for secret in secrets { XCTAssertFalse(encoded.contains(secret)); XCTAssertFalse(persisted.contains(secret)) }
    XCTAssertGreaterThan(retained.redactions, 0)
  }

  func testConcurrentCaptureSnapshotAndOverflowAreBounded() async throws {
    let collector = try collector()
    try await withThrowingTaskGroup(of: Void.self) { group in
      for n in 0..<4400 { group.addTask { try await collector.capture(supportEvent(n)) } }
      for _ in 0..<20 { group.addTask { _ = await collector.snapshot() } }
      try await group.waitForAll()
    }
    let snapshot = await collector.snapshot()
    XCTAssertLessThanOrEqual(snapshot.events.count, snapshot.eventLimit)
    XCTAssertLessThanOrEqual(snapshot.retainedBytes, snapshot.byteLimit)
    XCTAssertEqual(UInt64(snapshot.events.count) + snapshot.droppedEvents, 4400)
    XCTAssertEqual(Set(snapshot.events.map(\.id)).count, snapshot.events.count)
    XCTAssertEqual(snapshot.events.map(\.sequence), snapshot.events.map(\.sequence).sorted())
  }

  func testExportFailuresKeepSnapshotAndRejectSymlinkEscape() async throws {
    let collector = try collector()
    try await collector.capture(supportEvent())
    let directory = try directory()
    let outside = try self.directory()
    let link = directory.appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
    for destination in [link, directory.appendingPathComponent("missing"), URL(fileURLWithPath: "/dev/null")] {
      do { _ = try await collector.export(to: destination); XCTFail("Invalid destination accepted") } catch { }
    }
    let snapshot = await collector.snapshot()
    XCTAssertEqual(snapshot.events.count, 1)
    XCTAssertEqual(snapshot.collectorFailures, 3)
    XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: outside.path).isEmpty)
  }

  func testOversizedAndCancelledOperations() async throws {
    let collector = try collector()
    do {
      try await collector.capture(ASHSupportEventInput(operation: "large", correlation: "x", expected: "bounded", actual: String(repeating: "x", count: 20000)))
      XCTFail("Oversized record accepted")
    } catch { XCTAssertEqual(error as? ASHSupportError, .recordTooLarge) }
    let task = Task { try Task.checkCancellation(); try await collector.capture(supportEvent()) }
    task.cancel()
    do { try await task.value; XCTFail("Cancelled capture accepted") } catch is CancellationError { }
    let snapshot = await collector.snapshot()
    XCTAssertTrue(snapshot.events.isEmpty)
    XCTAssertEqual(snapshot.collectorFailures, 1)
  }

  func testConcurrentCaptureAndPairedExportsUseConsistentSnapshots() async throws {
    let collector = try collector()
    let destination = try directory()
    try await withThrowingTaskGroup(of: Void.self) { group in
      for n in 0..<300 { group.addTask { try await collector.capture(supportEvent(n)) } }
      for _ in 0..<4 {
        group.addTask {
          let export = try await collector.export(to: destination)
          let decoded = try JSONDecoder().decode(ASHSupportSnapshot.self, from: Data(contentsOf: export.json))
          XCTAssertEqual(decoded, export.snapshot)
          let markdown = try String(contentsOf: export.markdown, encoding: .utf8)
          for event in decoded.events { XCTAssertTrue(markdown.contains(event.id)) }
        }
      }
      try await group.waitForAll()
    }
  }
  func testStartupIdentityRejectsMalformedMetadataBeforeCapture() {
    for identity in [
      ASHSupportIdentity(version: "", build: "1"),
      ASHSupportIdentity(version: "1.0.0-rc.1\n", build: "1"),
      ASHSupportIdentity(version: "1.0.0-rc.1", build: "1\n"),
      ASHSupportIdentity(version: "1.0.0-rc.1", build: "1", sourceCommit: String(repeating: "f", count: 40) + "\n"),
      ASHSupportIdentity(version: "1.0.0-rc.1", build: "1", sourceCommit: "unverified")
    ] { XCTAssertThrowsError(try ASHSupportDiagnostics.makeCollector(identity: identity)) }
  }

  func testFullCanonicalHaltChainIsPreservedInBothExports() async throws {
    let collector = try collector()
    let assessment = ASHDiagnosticEnvelope.canonical(kind: .classification, severity: .warning, stage: .classify, subject: "synthetic-state", ruleIDs: ["ASH-CLASSIFICATION-001"], summary: "Declared correction is required.", notes: ["The state is outside the declared stable set."])
    let recovery = ASHDiagnosticEnvelope.canonical(kind: .recovery, severity: .error, stage: .recover, disposition: .blocked, subject: "synthetic-state", ruleIDs: ["ASH-RECOVERY-001"], summary: "Correction attempt failed post-validation.", notes: ["The synthetic runtime returned the original candidate."], parent: assessment)
    let containment = ASHDiagnosticEnvelope.canonical(kind: .containment, severity: .error, stage: .contain, disposition: .escalated, subject: "synthetic-state", ruleIDs: ["ASH-CONTAINMENT-001"], summary: "Only diagnostic inspection is permitted.", notes: ["Propagation is restricted pending resolution."], parent: recovery)
    let halt = ASHDiagnosticEnvelope.canonical(kind: .safeHalt, severity: .critical, stage: .halt, disposition: .terminal, subject: "synthetic-state", ruleIDs: ["ASH-HALT-001"], summary: "Confirmed breach caused terminal safe halt.", notes: ["Propagation was explicitly observed despite containment."], parent: containment)
    let chain = [assessment, recovery, containment, halt]
    try await collector.capture(ASHSupportEventInput(operation: "synthetic-halt-chain", correlation: "synthetic-session", expected: "Preserve the complete terminal chain", actual: "Terminal safe halt", failure: ASHSupportFailure(domain: "SyntheticRuntime", code: "CONTAINMENT_BREACH", message: "Explicit synthetic propagation observation"), canonicalDiagnostics: chain))
    let export = try await collector.export(to: directory())
    let decoded = try JSONDecoder().decode(ASHSupportSnapshot.self, from: Data(contentsOf: export.json))
    XCTAssertEqual(decoded, export.snapshot)
    XCTAssertEqual(decoded.events[0].canonicalDiagnostics, chain)
    let markdown = try String(contentsOf: export.markdown, encoding: .utf8)
    for record in chain { XCTAssertTrue(markdown.contains(record.diagnosticReference)) }
    XCTAssertTrue(markdown.contains("SAFE&#95;HALT"))
    XCTAssertTrue(ASHDiagnosticsModule().validateChain(decoded.events[0].canonicalDiagnostics).isValid)
  }

  func testUnsafeDuplicateAndOversizedCanonicalEvidenceFailBeforeRetention() async throws {
    let collector = try collector()
    let valid = ASHDiagnosticEnvelope.canonical(kind: .stateAssessment, stage: .assess, subject: "synthetic", ruleIDs: ["ASH-STATE-001"], summary: "State was assessed.", notes: ["Explicit fixture observed."])
    let unsafe = ASHDiagnosticEnvelope.canonical(kind: .stateAssessment, stage: .assess, subject: "synthetic", ruleIDs: ["ASH-STATE-001"], summary: "State was assessed.", notes: ["password=hiddenCanonicalSecret"])
    for (chain, expected) in [([valid,valid], ASHSupportError.invalidCanonicalEvidence), ([unsafe], .unsafeCanonicalEvidence), (Array(repeating:valid,count:65), .recordTooLarge)] {
      do { try await collector.capture(.init(operation:"canonical-check",correlation:"synthetic",expected:"reject",actual:"controlled failure",canonicalDiagnostics:chain)); XCTFail("Invalid/unsafe evidence retained") }
      catch { XCTAssertEqual(error as? ASHSupportError,expected) }
    }
    let snapshot = await collector.snapshot()
    XCTAssertTrue(snapshot.events.isEmpty)
    XCTAssertEqual(snapshot.collectorFailures,3)
    let export = try await collector.export(to: directory())
    XCTAssertFalse(try String(contentsOf:export.json,encoding:.utf8).contains("hiddenCanonicalSecret"))
  }

  func testScalarDistinctCanonicalKeysSurviveSupportJSON() async throws {
    let collector = try collector()
    let object = ASHDiagnosticObject(fields:[.init(key:"é",value:.string("é")),.init(key:"e\u{301}",value:.string("e\u{301}"))])
    let record = ASHDiagnosticEnvelope.canonical(kind:.stateAssessment,stage:.assess,subject:"Unicode fixture",ruleIDs:["ASH-STATE-001"],summary:"Scalar-distinct keys retained.",notes:["No Unicode normalization is applied."],details:object)
    try await collector.capture(.init(operation:"Unicode-capture",correlation:"fixture",expected:"Preserve both keys",actual:"Two distinct keys",canonicalDiagnostics:[record]))
    let export = try await collector.export(to:directory())
    guard case .object(let root) = try ASHDiagnosticValue.parseCanonicalJSON(Data(contentsOf:export.json)),
      case .array(let events) = root["events"], case .object(let event) = events[0],
      case .array(let diagnostics) = event["canonicalDiagnostics"] else { return XCTFail("Missing typed canonical evidence") }
    let decoded = try ASHDiagnosticEnvelope.decodeCanonicalJSON(diagnostics[0].canonicalJSONData)
    XCTAssertEqual(decoded.details.fields.count,2)
    XCTAssertEqual(decoded.canonicalJSONData,record.canonicalJSONData)
    XCTAssertNotEqual(ASHDiagnosticValue.string("é"), .string("e\u{301}"))
  }

  func testCancelledExportAndUnwritableDestinationKeepEvidence() async throws {
    let collector = try collector(), destination = try directory()
    try await collector.capture(supportEvent())
    let task = Task { try Task.checkCancellation(); return try await collector.export(to:destination) }
    task.cancel()
    do { _ = try await task.value; XCTFail("Cancelled export accepted") } catch is CancellationError { }
    try FileManager.default.setAttributes([.posixPermissions:0o500],ofItemAtPath:destination.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:destination.path) }
    do { _ = try await collector.export(to:destination); XCTFail("Unwritable directory accepted") } catch { }
    let snapshot = await collector.snapshot()
    XCTAssertEqual(snapshot.events.count,1)
    XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath:destination.path).isEmpty)
  }

  func testRawEvidenceCardinalityAndDepthAreBoundedBeforeProjection() async throws {
    let collector = try collector()
    let root = ASHDiagnosticEnvelope.canonical(kind:.stateAssessment,stage:.assess,subject:"fixture",ruleIDs:["ASH-STATE-001"],summary:"Fixture assessed.",notes:["A declared synthetic fixture."])
    var deep: ASHDiagnosticValue = .null
    for _ in 0..<66 { deep = .object(["nested":deep]) }
    func raw(notes: [String] = ["A declared synthetic fixture."], rules: [String] = ["ASH-STATE-001"], details: ASHDiagnosticObject = [:]) -> ASHDiagnosticEnvelope {
      .init(diagnosticReference:root.diagnosticReference,diagnosticKind:root.diagnosticKind,severity:root.severity,stage:root.stage,disposition:root.disposition,subjectReference:root.subjectReference,parentDiagnosticReference:nil,chainRootReference:root.chainRootReference,ruleIDs:rules,summary:root.summary,notes:notes,details:details)
    }
    let inputs = [
      ASHSupportEventInput(operation:"count",correlation:"fixture",expected:"bounded",actual:"33 fields",context:Dictionary(uniqueKeysWithValues:(0..<33).map{("field-\($0)","value")})),
      ASHSupportEventInput(operation:"count",correlation:"fixture",expected:"bounded",actual:"17 causes",failure:.init(domain:"fixture",code:"bounded",message:"Controlled error",causes:Array(repeating:"cause",count:17))),
      ASHSupportEventInput(operation:"count",correlation:"fixture",expected:"bounded",actual:"4097 notes",canonicalDiagnostics:[raw(notes:Array(repeating:"",count:4097))]),
      ASHSupportEventInput(operation:"count",correlation:"fixture",expected:"bounded",actual:"4097 rules",canonicalDiagnostics:[raw(rules:Array(repeating:"",count:4097))]),
      ASHSupportEventInput(operation:"depth",correlation:"fixture",expected:"bounded",actual:"66 containers",canonicalDiagnostics:[raw(details:["nested":deep])])
    ]
    for input in inputs {
      do { try await collector.capture(input); XCTFail("Unbounded raw evidence accepted") }
      catch { XCTAssertEqual(error as? ASHSupportError,.recordTooLarge) }
    }
    let snapshot = await collector.snapshot()
    XCTAssertTrue(snapshot.events.isEmpty)
    XCTAssertEqual(snapshot.collectorFailures,5)
  }

}
