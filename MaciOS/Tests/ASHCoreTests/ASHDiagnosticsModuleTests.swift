import Foundation
import CryptoKit
import XCTest
import ASHCore

final class ASHDiagnosticsModuleTests: XCTestCase {
  private let module = ASHDiagnosticsModule()

  func testValidateEnvelopeAcceptsConformantEnvelope() {
    let record = makeRoot()
    let result = module.validateEnvelope(record)
    XCTAssertTrue(result.isValid, "\(result.issues)")
    XCTAssertEqual(result.envelope, record)
  }

  func testValidateEnvelopeRejectsInvalidRuleID() {
    let record = makeRoot(rules: ["INVALID-RULE"])
    XCTAssertTrue(module.validateEnvelope(record).issues.contains { $0.code == "DIAG-INVALID-RULE-ID" })
  }

  func testValidateChainDetectsStageRegression() {
    let root = makeRoot()
    let child = makeRoot(stage: .parse, parent: root)
    XCTAssertTrue(module.validateChain([root, child]).issues.contains { $0.code == "DIAG-STAGE-REGRESSION" })
  }

  func testDetectOmissionsBuildsMetaDiagnostic() {
    let root = makeRoot()
    let original = [root]
    let report = module.detectOmissions(expectedDiagnosticReferences: [root.diagnosticReference, "missing"], actualChain: original, chainRootReference: root.chainRootReference)
    XCTAssertEqual(report?.diagnosticKind, .schemaValidation)
    XCTAssertTrue(module.validateChain([report!]).isValid)
    XCTAssertEqual(original, [root])
    XCTAssertNil(module.detectOmissions(expectedDiagnosticReferences: [root.diagnosticReference], actualChain: original, chainRootReference: root.chainRootReference))
  }

  func testDuplicatesCyclesOrphansMultipleRootsAndOrderingNeverTrap() {
    let root = makeRoot()
    let child = makeRoot(stage: .recover, parent: root)
    let next = makeRoot(stage: .contain, kind: .containment, severity: .error, parent: child)
    let malformed: [[ASHDiagnosticEnvelope]] = [
      [], [root, root], [root, makeRoot()], [child, root],
      [replace(root, parent: next.diagnosticReference), child, next],
      [root, replace(child, parent: "APS-DIAG-000000000000000000000000")],
      [root, replace(child, root: child.diagnosticReference)],
      [root, replace(child, sequence: 3)],
      [replace(root, parent: child.diagnosticReference), replace(child, parent: root.diagnosticReference)]
    ]
    for records in malformed {
      let first = module.validateChain(records), second = module.validateChain(records)
      XCTAssertFalse(first.isValid, "Accepted malformed chain \(records)")
      XCTAssertEqual(first.issues, second.issues)
      XCTAssertEqual(first.metaDiagnostics, second.metaDiagnostics)
      XCTAssertTrue(first.metaDiagnostics.allSatisfy { module.validateChain([$0]).isValid })
    }
  }

  func testRepeatedSemanticIdentityAtDistinctOccurrencesIsValid() {
    let root = makeRoot(stage: .contain, kind: .containment, severity: .error)
    let child = makeRoot(stage: .contain, kind: .containment, severity: .error, parent: root)
    XCTAssertEqual(root.diagnosticReference, child.diagnosticReference)
    XCTAssertEqual(child.parentDiagnosticReference, child.diagnosticReference)
    XCTAssertEqual(child.sequenceNumber, 2)
    XCTAssertTrue(module.validateChain([root, child]).isValid)
  }

  func testCausalSafetyPhasesSeverityAndTerminalFinality() {
    let root = makeRoot()
    let plan = makeRoot(stage: .plan, kind: .generationPlan, parent: root)
    let recovery = makeRoot(stage: .recover, kind: .recovery, severity: .warning, parent: plan)
    let check = makeRoot(stage: .validate, kind: .schemaValidation, severity: .warning, parent: recovery)
    let containment = makeRoot(stage: .contain, kind: .containment, severity: .error, parent: check)
    let denied = makeRoot(stage: .contain, kind: .containment, severity: .error, disposition: .blocked, parent: containment)
    let halt = makeRoot(stage: .halt, kind: .safeHalt, severity: .critical, disposition: .terminal, parent: denied)
    let valid = [root, plan, recovery, check, containment, denied, halt]
    XCTAssertTrue(module.validateChain(valid).isValid, "\(module.validateChain(valid).issues)")
    XCTAssertTrue(module.validateChain([root, makeRoot(stage: .contain, kind: .containment, parent: root)]).isValid)
    XCTAssertFalse(module.validateChain([root, makeRoot(stage: .halt, kind: .safeHalt, parent: root)]).isValid)
    XCTAssertFalse(module.validateChain(Array(valid.prefix(3)) + [makeRoot(stage: .assess, parent: recovery)]).isValid)
    XCTAssertFalse(module.validateChain(Array(valid.prefix(5)) + [makeRoot(stage: .verify, severity: .error, parent: containment)]).isValid)
    XCTAssertFalse(module.validateChain(Array(valid.prefix(5)) + [makeRoot(stage: .contain, kind: .recovery, severity: .error, parent: containment)]).isValid)
    XCTAssertFalse(module.validateChain(valid + [makeRoot(stage: .halt, kind: .safeHalt, severity: .critical, parent: halt)]).isValid)
    XCTAssertFalse(module.validateChain(Array(valid.prefix(3)) + [makeRoot(stage: .validate, severity: .info, parent: recovery)]).isValid)
  }

  func testWhitespaceNotesSummaryIdentityAndTaxonomy() {
    for blank in ["", " ", "\t\r\n", "\u{85}", "\u{A0}", "\u{1C}", "\u{2003}\u{3000}"] {
      XCTAssertFalse(module.validateEnvelope(makeRoot(notes: [blank])).isValid)
      XCTAssertFalse(module.validateEnvelope(makeRoot(summary: blank)).isValid)
    }
    XCTAssertFalse(module.validateEnvelope(makeRoot(notes: ["Valid entry", " "])).isValid)
    XCTAssertFalse(module.validateEnvelope(makeRoot(summary: "Two\nlines")).isValid)
    XCTAssertFalse(module.validateEnvelope(replace(makeRoot(), id: "APS-DIAG-000000000000000000000000")).isValid)
    for family in ["INPUT","STATE","CODEWORD","ORBIT","REALM","TRANSITION","TOPOLOGY","AXIOM","CLASSIFICATION","RECOVERY","FALLBACK","CONTAINMENT","HALT","GENERATION","EMISSION","DIAGNOSTIC","CONFORMANCE","RELEASE","SECURITY","ADMISSIBILITY"] {
      XCTAssertTrue(module.validateEnvelope(makeRoot(rules: ["ASH-\(family)-001", "ASH-\(family)-VALIDITY-001"])).isValid)
    }
    for bad in ["ASH-PLAN-001", "ASH-EMIT-001", "ASH-STATE-X_1-001", "ASH-STATE-01", "ASH-STATE-001\n"] {
      XCTAssertFalse(module.validateEnvelope(makeRoot(rules: [bad])).isValid)
    }
  }

  func testRequiredNullableFieldsAndPortableWireRepresentation() throws {
    let root = makeRoot()
    let encoded = try JSONEncoder().encode(root)
    let value = try ASHDiagnosticValue.parseCanonicalJSON(encoded)
    guard case .object(let object) = value else { return XCTFail("Expected object") }
    XCTAssertEqual(object.fields.count, 15)
    XCTAssertEqual(object["parent_diagnostic_id"], .null)
    XCTAssertEqual(object["occurrence_metadata"], .null)
    XCTAssertEqual(try ASHDiagnosticEnvelope.decodeCanonicalJSON(encoded), root)
    for key in ["parent_diagnostic_id", "occurrence_metadata", "details", "sequence_number"] {
      let missing = ASHDiagnosticObject(fields: object.fields.filter { $0.key != key })
      XCTAssertThrowsError(try ASHDiagnosticEnvelope.decodeCanonicalJSON(Data(missing.canonicalJSONString.utf8)))
    }
  }

  func testValidatorCanBeSharedAcrossConcurrentTasks() async {
    let shared = module, root = makeRoot()
    let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
      for _ in 0..<128 { group.addTask { shared.validateChain([root]).isValid } }
      var results: [Bool] = []
      for await value in group { results.append(value) }
      return results
    }
    XCTAssertEqual(results.count, 128)
    XCTAssertTrue(results.allSatisfy { $0 })
  }

  func testEveryRawCanonicalDiagnosticAndChainMatchesAllFields() throws {
    var ledger: [[String: Any]] = []
    let provenance = try Data(contentsOf: fixture("corpus-provenance", ext: "json"))
    let manifest = try JSONSerialization.jsonObject(with: provenance) as! [String: Any]
    let commit = manifest["canonicalCommit"] as? String ?? manifest["sourceCommit"] as? String
    XCTAssertEqual(commit, "50d7e5ab88932a4a967ffc2c83bd18fae45b73c8")
    for name in ["diagnostics", "diagnostic-chains"] {
      let raw = try Data(contentsOf: fixture(name, ext: "jsonl"))
      let digest = SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
      let cases = try String(decoding: raw, as: UTF8.self).split(separator: "\n").map { try ASHDiagnosticValue.parseCanonicalJSON(Data($0.utf8)) }
      XCTAssertEqual(cases.count, name == "diagnostics" ? 14 : 5)
      for value in cases {
        let c = try object(value), input = try object(try required(c,"input"))
        let id = try string(try required(c,"vector_id")), expected = try required(c,"expected_output")
        let actual: ASHDiagnosticValue
        if name == "diagnostics" {
          let record = try makePayload(input)
          XCTAssertTrue(module.validateEnvelope(record).isValid, id)
          actual = .object(record.canonicalRecord)
        } else {
          let records: [ASHDiagnosticEnvelope]
          if case .array(let payloads) = input["payloads"] {
            var chain: [ASHDiagnosticEnvelope] = []
            for payload in payloads { chain.append(try makePayload(object(payload), parent: chain.last)) }
            XCTAssertTrue(module.validateChain(chain).isValid, "\(id): \(module.validateChain(chain).issues)")
            records = chain
            actual = .object(["chain_valid": .bool(module.validateChain(chain).isValid), "records": .array(chain.map { .object($0.canonicalRecord) })])
          } else {
            let payload = try object(try required(input,"payload"))
            guard case .array(let occurrences) = input["occurrences"] else { throw TestError.invalid }
            records = try occurrences.map { try makePayload(payload, occurrence: $0) }
            XCTAssertTrue(records.allSatisfy { module.validateChain([$0]).isValid })
            actual = .object(["identity_unchanged": .bool(Set(records.map(\.diagnosticReference)).count == 1), "records": .array(records.map { .object($0.canonicalRecord) })])
          }
          XCTAssertFalse(records.isEmpty)
        }
        XCTAssertEqual(actual.canonicalJSONData, expected.canonicalJSONData, id)
        ledger.append(["vectorID":id,"sourceCommit":commit!,"sourcePath":"conformance/1.0/vectors/\(name).jsonl","sourceSHA256":digest,"adapterVersion":"native-diagnostic-1","requirements":try required(c,"requirements").canonicalJSONString,"ruleIDs":try required(c,"rule_ids").canonicalJSONString,"publicOperation":name == "diagnostics" ? "ASHDiagnosticEnvelope.canonical / validateEnvelope" : "ASHDiagnosticEnvelope.canonical / validateChain","expectedOutput":expected.canonicalJSONString,"actualOutput":actual.canonicalJSONString,"comparisonPolicy":"Every field, complete nested objects and arrays, scalar-exact Unicode; no ignored fields","result":actual.canonicalJSONData == expected.canonicalJSONData ? "PASS" : "FAIL"])
      }
    }
    XCTAssertEqual(ledger.count, 19)
    if let destination = ProcessInfo.processInfo.environment["ASH_CANONICAL_LEDGER_ROOT"] {
      let base = URL(fileURLWithPath: destination)
      try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
      try JSONSerialization.data(withJSONObject:ledger,options:[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]).write(to:base.appendingPathComponent("diagnostic-case-ledger.json"),options:.atomic)
    }
  }

  private func makeRoot(stage: ASHDiagnosticStage = .assess, kind: ASHDiagnosticKind = .stateAssessment, severity: ASHDiagnosticSeverity = .info, disposition: ASHDiagnosticDisposition = .recorded, parent: ASHDiagnosticEnvelope? = nil, rules: [String] = ["ASH-STATE-001"], summary: String = "A structural fixture was assessed.", notes: [String] = ["The supplied fixture is a nine-bit state."]) -> ASHDiagnosticEnvelope {
    .canonical(kind:kind,severity:severity,stage:stage,disposition:disposition,subject:"synthetic-fixture",ruleIDs:rules,summary:summary,notes:notes,parent:parent)
  }
  private func replace(_ r: ASHDiagnosticEnvelope, id: String? = nil, parent: String? = nil, root: String? = nil, sequence: Int? = nil) -> ASHDiagnosticEnvelope {
    .init(diagnosticReference:id ?? r.diagnosticReference,diagnosticKind:r.diagnosticKind,severity:r.severity,stage:r.stage,disposition:r.disposition,subjectReference:r.subjectReference,parentDiagnosticReference:parent ?? r.parentDiagnosticReference,chainRootReference:root ?? r.chainRootReference,ruleIDs:r.ruleIDs,summary:r.summary,notes:r.notes,sequenceNumber:sequence ?? r.sequenceNumber,details:r.details,occurrenceMetadata:r.occurrenceMetadata)
  }
  private func fixture(_ name: String, ext: String) throws -> URL {
    try XCTUnwrap(Bundle.module.url(forResource:name,withExtension:ext))
  }
  private enum TestError: Error { case invalid }
  private func required(_ o: ASHDiagnosticObject,_ key: String) throws -> ASHDiagnosticValue { guard let value=o[key] else { throw TestError.invalid }; return value }
  private func object(_ v: ASHDiagnosticValue) throws -> ASHDiagnosticObject { guard case .object(let o)=v else { throw TestError.invalid }; return o }
  private func string(_ v: ASHDiagnosticValue) throws -> String { guard case .string(let s)=v else { throw TestError.invalid }; return s }
  private func strings(_ v: ASHDiagnosticValue) throws -> [String] { guard case .array(let a)=v else { throw TestError.invalid }; return try a.map(string) }
  private func makePayload(_ p: ASHDiagnosticObject, parent: ASHDiagnosticEnvelope? = nil, occurrence: ASHDiagnosticValue? = nil) throws -> ASHDiagnosticEnvelope {
    let metadata: ASHDiagnosticObject?
    switch occurrence ?? p["occurrence_metadata"] ?? .null { case .null: metadata=nil; case .object(let o): metadata=o; default: throw TestError.invalid }
    return try .canonical(kind:XCTUnwrap(ASHDiagnosticKind(rawValue:string(required(p,"diagnostic_kind")))),severity:XCTUnwrap(ASHDiagnosticSeverity(rawValue:string(required(p,"severity")))),stage:XCTUnwrap(ASHDiagnosticStage(rawValue:string(required(p,"stage")))),disposition:XCTUnwrap(ASHDiagnosticDisposition(rawValue:string(required(p,"disposition")))),subject:string(required(p,"subject_reference")),ruleIDs:strings(required(p,"rule_ids")),summary:string(required(p,"summary")),notes:strings(required(p,"notes")),details:object(required(p,"details")),parent:parent,occurrenceMetadata:metadata)
  }
}
