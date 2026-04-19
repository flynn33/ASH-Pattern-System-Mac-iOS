import XCTest
@testable import ASHPatternSystem
import ASHCore

final class ASHPatternSystemEngineTests: XCTestCase {
  func testBootstrapProducesDeterministicFoundationReport() throws {
    let engine = ASHPatternSystemEngine()
    let config = ASHPatternSystemEngineConfiguration(topologyDepth: 2, topologySeedToken: "F")

    let first = engine.bootstrap(configuration: config)
    let second = engine.bootstrap(configuration: config)

    XCTAssertEqual(first.requestedState, second.requestedState)
    XCTAssertEqual(first.requestedStateDiagnostic, second.requestedStateDiagnostic)
    XCTAssertEqual(first.startupStatus, second.startupStatus)
    XCTAssertEqual(first.startupNotes, second.startupNotes)
    XCTAssertEqual(first.state, second.state)
    XCTAssertEqual(first.stateDiagnostic, second.stateDiagnostic)
    XCTAssertEqual(first.axiomEvaluation, second.axiomEvaluation)
    XCTAssertEqual(first.availableTransitions, second.availableTransitions)
    XCTAssertEqual(first.topologyResult.topology, second.topologyResult.topology)
    XCTAssertEqual(first.topologyResult.diagnostics, second.topologyResult.diagnostics)

    let topology = try XCTUnwrap(first.topologyResult.topology)
    XCTAssertEqual(topology.nodes.count, 13)
    XCTAssertFalse(first.availableTransitions.isEmpty)
    XCTAssertEqual(first.startupStatus, .usedRequestedState)
  }

  func testDiagnoseStateRejectsMalformedBitString() {
    let engine = ASHPatternSystemEngine()
    XCTAssertNil(engine.diagnoseState(bitString: "bad-input"))
  }

  func testBootstrapFallsBackToKnownValidWhenNormalizationFails() {
    let engine = ASHPatternSystemEngine()
    let incompatible = ASHState(bitString: "000000001")!

    let report = engine.bootstrap(from: incompatible)

    XCTAssertEqual(report.requestedState, incompatible)
    XCTAssertEqual(report.requestedStateDiagnostic.normalizationStatus, .notNormalizable)
    XCTAssertEqual(report.startupStatus, .fallbackToKnownValid)
    XCTAssertEqual(report.state, .zero)
    XCTAssertFalse(report.startupNotes.isEmpty)
  }
}
