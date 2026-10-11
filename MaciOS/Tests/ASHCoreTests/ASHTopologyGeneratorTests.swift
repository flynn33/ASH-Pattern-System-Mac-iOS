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

    let first = generator.generateTopology(from: .zero, depth: 2, seedToken: "R")
    let second = generator.generateTopology(from: .zero, depth: 2, seedToken: "R")

    let firstTopology = try XCTUnwrap(first.topology)
    let secondTopology = try XCTUnwrap(second.topology)

    XCTAssertTrue(first.diagnostics.isEmpty)
    XCTAssertEqual(firstTopology, secondTopology)
    XCTAssertEqual(firstTopology.nodes.count, 13)

    let rootNode = try XCTUnwrap(firstTopology.nodes.first)
    XCTAssertEqual(rootNode.branchKind, .root)
    XCTAssertEqual(rootNode.pathToken, "R")

    for node in firstTopology.nodes where node.depth > 0 {
      XCTAssertNotNil(node.parentID)
    }
  }

  func testGenerateTopologyRejectsNoncanonicalRootPath() {
    let restrictedStateModel = ASHStateModel()
    let registry = ASHTransitionRegistry(stateModel: restrictedStateModel)
    let generator = ASHTopologyGenerator(
      stateModel: restrictedStateModel,
      transitionRegistry: registry
    )
    let unnormalizable = ASHState(bitString: "000000001")!

    let result = generator.generateTopology(from: unnormalizable, depth: 1, seedToken: "F")

    XCTAssertNil(result.topology)
    XCTAssertFalse(result.diagnostics.isEmpty)
  }
  func testInvalidBranchConfigurationReturnsDiagnosticsWithoutTrapping() {
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    for words in [[], [.zero], [.zero, .zero], [.zero, .zero, ASHState(rawValue: 1)!]] {
      let generator = ASHTopologyGenerator(stateModel: stateModel, transitionRegistry: registry, branchCodewords: words)
      let result = generator.generateTopology(from: .zero, depth: 1)
      XCTAssertNil(result.topology)
      XCTAssertFalse(result.diagnostics.isEmpty)
    }
  }

  func testNodeBudgetBoundaryAndHugeDepthFailBeforePartialOutput() throws {
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    let exact = ASHTopologyGenerator(stateModel: stateModel, transitionRegistry: registry, maximumNodes: 13)
    XCTAssertEqual(try XCTUnwrap(exact.generateTopology(from: .zero, depth: 2).topology).nodes.count, 13)
    for depth in [-1, 3, 40, Int.max] {
      let result = exact.generateTopology(from: .zero, depth: depth)
      XCTAssertNil(result.topology)
      XCTAssertFalse(result.diagnostics.isEmpty)
    }
    let invalid = ASHTopologyGenerator(stateModel: stateModel, transitionRegistry: registry, maximumNodes: 0)
    XCTAssertNil(invalid.generateTopology(from: .zero, depth: 0).topology)
  }

  func testCancelledOperationReturnsNoPartialTopology() async {
    let generator = ASHTopologyGenerator(stateModel:stateModel,transitionRegistry:ASHTransitionRegistry(stateModel:stateModel))
    let task = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      return generator.generateTopology(from:.zero,depth:3)
    }
    let result = await task.value
    XCTAssertNil(result.topology); XCTAssertTrue(result.diagnostics.contains { $0.summary.contains("cancelled") })
  }
}
