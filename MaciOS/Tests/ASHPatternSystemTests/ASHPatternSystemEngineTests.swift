import XCTest
@testable import ASHPatternSystem

final class ASHPatternSystemEngineTests: XCTestCase {
  func testBootstrapProducesDeterministicFoundationReport() throws {
    let engine = ASHPatternSystemEngine()
    let config = ASHPatternSystemEngineConfiguration(topologyDepth: 2, topologySeedToken: "F")

    let first = engine.bootstrap(configuration: config)
    let second = engine.bootstrap(configuration: config)

    XCTAssertEqual(first.state, second.state)
    XCTAssertEqual(first.stateDiagnostic, second.stateDiagnostic)
    XCTAssertEqual(first.axiomEvaluation, second.axiomEvaluation)
    XCTAssertEqual(first.availableTransitions, second.availableTransitions)
    XCTAssertEqual(first.topologyResult.topology, second.topologyResult.topology)
    XCTAssertEqual(first.topologyResult.diagnostics, second.topologyResult.diagnostics)

    let topology = try XCTUnwrap(first.topologyResult.topology)
    XCTAssertEqual(topology.nodes.count, 13)
    XCTAssertFalse(first.availableTransitions.isEmpty)
  }

  func testDiagnoseStateRejectsMalformedBitString() {
    let engine = ASHPatternSystemEngine()
    XCTAssertNil(engine.diagnoseState(bitString: "bad-input"))
  }
}
