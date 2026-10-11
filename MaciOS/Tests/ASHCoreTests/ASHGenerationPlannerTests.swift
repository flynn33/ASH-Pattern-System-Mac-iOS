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
      topologyGenerator.generateTopology(from: .zero, depth: 1, seedToken: "R").topology
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

  func testBuildPlanRejectsInconsistentTopologySourceState() {
    let restrictedStateModel = ASHStateModel()
    let topology = ASHTopology(
      seedToken: "R",
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
      stateModel: restrictedStateModel,
      realmEncoder: ASHRealmEncoder(stateModel: restrictedStateModel)
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
  func testBuildPlanRejectsForgedAxiomSuccessWithoutMeasurements() throws {
    let registry = ASHTransitionRegistry(stateModel:stateModel)
    let topology = try XCTUnwrap(ASHTopologyGenerator(stateModel:stateModel,transitionRegistry:registry).generateTopology(from:.zero,depth:0).topology)
    let forged = ASHAxiomEvaluation(subject:.init(),results:ASHAxiomID.allCases.map { .init(axiomID:$0,passed:true,explanation:"claimed without measurements",ruleIDs:["ASH-AXIOM-001"]) },overallPass:true,notes:["claimed"])
    let result = ASHGenerationPlanner(stateModel:stateModel,realmEncoder:ASHRealmEncoder(stateModel:stateModel)).buildPlan(from:.zero,topology:topology,axiomEvaluation:forged)
    XCTAssertNil(result.plan); XCTAssertFalse(result.diagnostics.isEmpty)
    let observedMissing = ASHAxiomEvaluator().evaluate(subject:.init())
    let allowed = ASHGenerationPlanner(stateModel:stateModel,realmEncoder:ASHRealmEncoder(stateModel:stateModel)).buildPlan(from:.zero,topology:topology,axiomEvaluation:observedMissing)
    let plan = try XCTUnwrap(allowed.plan)
    XCTAssertEqual(plan.warnings.count,5)
    XCTAssertTrue(plan.warnings.allSatisfy { $0.contains("INDETERMINATE:") })
  }
}
