import XCTest
@testable import ASHCore

final class ASHTopologyGeneratorTests: XCTestCase {
  private let stateModel = ASHStateModel()

  func testGenerateTopologyProducesDeterministicTernaryStructure() throws {
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    let generator = ASHTopologyGenerator(
      stateModel: stateModel,
      transitionRegistry: registry
    )

    let first = generator.generateTopology(from: .zero, depth: 2, seedToken: "F")
    let second = generator.generateTopology(from: .zero, depth: 2, seedToken: "F")

    let firstTopology = try XCTUnwrap(first.topology)
    let secondTopology = try XCTUnwrap(second.topology)

    XCTAssertTrue(first.diagnostics.isEmpty)
    XCTAssertEqual(firstTopology, secondTopology)
    XCTAssertEqual(firstTopology.nodes.count, 13)

    let rootNode = try XCTUnwrap(firstTopology.nodes.first)
    XCTAssertEqual(rootNode.branchKind, .root)
    XCTAssertEqual(rootNode.pathToken, "F")

    for node in firstTopology.nodes where node.depth > 0 {
      XCTAssertNotNil(node.parentID)
    }
  }

  func testGenerateTopologyRejectsUnnormalizableSeed() {
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    let generator = ASHTopologyGenerator(
      stateModel: stateModel,
      transitionRegistry: registry
    )
    let unnormalizable = ASHState(bitString: "000000001")!

    let result = generator.generateTopology(from: unnormalizable, depth: 1, seedToken: "F")

    XCTAssertNil(result.topology)
    XCTAssertFalse(result.diagnostics.isEmpty)
  }
}
