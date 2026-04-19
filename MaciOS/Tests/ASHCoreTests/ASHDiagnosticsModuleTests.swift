import XCTest
@testable import ASHCore

final class ASHDiagnosticsModuleTests: XCTestCase {
  private let module = ASHDiagnosticsModule()

  func testValidateEnvelopeAcceptsConformantEnvelope() {
    let envelope = makeRootEnvelope()

    let result = module.validateEnvelope(envelope)

    XCTAssertTrue(result.isValid)
    XCTAssertEqual(result.envelope, envelope)
    XCTAssertTrue(result.issues.isEmpty)
  }

  func testValidateEnvelopeRejectsInvalidRuleID() {
    let envelope = ASHDiagnosticEnvelope(
      diagnosticReference: "DIAG-ROOT-001",
      diagnosticKind: .stateValidity,
      severity: .info,
      stage: .detection,
      disposition: .resolved,
      subjectReference: "state:000000000",
      parentDiagnosticReference: nil,
      chainRootReference: "DIAG-ROOT-001",
      ruleIDs: ["INVALID-RULE"],
      summary: "Invalid rule ID sample.",
      notes: ["Used for rule ID validation."]
    )

    let result = module.validateEnvelope(envelope)

    XCTAssertFalse(result.isValid)
    XCTAssertTrue(result.issues.contains { $0.code == "DIAG-INVALID-RULE-ID" })
  }

  func testValidateChainDetectsStageRegression() {
    let root = ASHDiagnosticEnvelope(
      diagnosticReference: "DIAG-ROOT-001",
      diagnosticKind: .stateValidity,
      severity: .info,
      stage: .classification,
      disposition: .resolved,
      subjectReference: "state:000000000",
      parentDiagnosticReference: nil,
      chainRootReference: "DIAG-ROOT-001",
      ruleIDs: ["ASH-STATE-VALIDITY-001"],
      summary: "Root diagnostic for classification stage.",
      notes: ["Root classification diagnostic."]
    )
    let regressedChild = ASHDiagnosticEnvelope(
      diagnosticReference: "DIAG-CHILD-001",
      diagnosticKind: .recovery,
      severity: .warning,
      stage: .detection,
      disposition: .pending,
      subjectReference: "state:000000000",
      parentDiagnosticReference: root.diagnosticReference,
      chainRootReference: root.chainRootReference,
      ruleIDs: ["ASH-RECOVERY-ACTION-001"],
      summary: "Regression sample.",
      notes: ["Child stage should not regress behind parent stage."]
    )

    let result = module.validateChain([root, regressedChild])

    XCTAssertFalse(result.isValid)
    XCTAssertTrue(result.issues.contains { $0.code == "DIAG-STAGE-REGRESSION" })
  }

  func testDetectOmissionsBuildsMetaDiagnostic() {
    let root = makeRootEnvelope()

    let meta = module.detectOmissions(
      expectedDiagnosticReferences: [root.diagnosticReference, "DIAG-STEP-002"],
      actualChain: [root],
      chainRootReference: root.chainRootReference
    )

    XCTAssertNotNil(meta)
    XCTAssertEqual(meta?.diagnosticKind, .meta)
  }

  private func makeRootEnvelope() -> ASHDiagnosticEnvelope {
    ASHDiagnosticEnvelope(
      diagnosticReference: "DIAG-ROOT-001",
      diagnosticKind: .stateValidity,
      severity: .info,
      stage: .detection,
      disposition: .resolved,
      subjectReference: "state:000000000",
      parentDiagnosticReference: nil,
      chainRootReference: "DIAG-ROOT-001",
      ruleIDs: ["ASH-STATE-VALIDITY-001"],
      summary: "Root diagnostic for stable state.",
      notes: ["Stable state diagnostic."]
    )
  }
}
