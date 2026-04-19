import XCTest
@testable import ASHCore

final class ASHGenerationPlannerTests: XCTestCase {
  private let stateModel = ASHStateModel()

  func testBuildPlanProducesDeterministicInspectablePlan() throws {
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    let topologyGenerator = ASHTopologyGenerator(
      stateModel: stateModel,
      transitionRegistry: registry
    )
    let topology = try XCTUnwrap(
      topologyGenerator.generateTopology(from: .zero, depth: 1, seedToken: "F").topology
    )
    let axiomEvaluation = ASHAxiomEvaluator().evaluate(state: .zero)
    let planner = ASHGenerationPlanner(
      stateModel: stateModel,
      realmEncoder: ASHRealmEncoder(stateModel: stateModel)
    )
    let constraints = ASHTargetRuntimeConstraints(
      platform: "APPLE",
      runtime: "NATIVE",
      profileID: "BASELINE",
      emissionTargetKind: "IN_MEMORY",
      capabilityTags: ["diagnostics", "swift"]
    )

    let first = planner.buildPlan(
      from: .zero,
      topology: topology,
      axiomEvaluation: axiomEvaluation,
      targetConstraints: constraints
    )
    let second = planner.buildPlan(
      from: .zero,
      topology: topology,
      axiomEvaluation: axiomEvaluation,
      targetConstraints: constraints
    )

    let firstPlan = try XCTUnwrap(first.plan)
    let secondPlan = try XCTUnwrap(second.plan)

    XCTAssertEqual(firstPlan, secondPlan)
    XCTAssertEqual(firstPlan.topologyNodes.count, topology.nodes.count)
    XCTAssertEqual(firstPlan.roleAssignments.count, firstPlan.topologyNodes.count)
    XCTAssertEqual(firstPlan.artifacts.count, firstPlan.roleAssignments.count)
    XCTAssertFalse(first.diagnostics.isEmpty)
  }

  func testBuildPlanRejectsUnnormalizableState() {
    let topology = ASHTopology(
      seedToken: "F",
      depth: 0,
      nodes: [
        ASHTopologyNode(
          nodeID: "F-d0-o0",
          parentID: nil,
          depth: 0,
          ordinal: 0,
          branchKind: .root,
          pathToken: "F",
          state: .zero
        )
      ]
    )
    let planner = ASHGenerationPlanner(
      stateModel: stateModel,
      realmEncoder: ASHRealmEncoder(stateModel: stateModel)
    )
    let axiomEvaluation = ASHAxiomEvaluator().evaluate(state: .zero)
    let unnormalizable = ASHState(bitString: "000000001")!

    let result = planner.buildPlan(
      from: unnormalizable,
      topology: topology,
      axiomEvaluation: axiomEvaluation,
      targetConstraints: .init()
    )

    XCTAssertNil(result.plan)
    XCTAssertFalse(result.diagnostics.isEmpty)
  }
}
