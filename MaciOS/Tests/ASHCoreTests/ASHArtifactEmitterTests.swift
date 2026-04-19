import XCTest
@testable import ASHCore

final class ASHArtifactEmitterTests: XCTestCase {
  private let stateModel = ASHStateModel()

  func testEmitMaterializesArtifactsDeterministically() throws {
    let plan = try makePlan()
    let emitter = ASHArtifactEmitter()

    let first = emitter.emit(plan: plan)
    let second = emitter.emit(plan: plan)

    XCTAssertEqual(first.artifacts, second.artifacts)
    XCTAssertEqual(first.diagnostics, second.diagnostics)
    XCTAssertFalse(first.artifacts.isEmpty)
    XCTAssertEqual(first.artifacts.count, plan.artifacts.count)
  }

  func testEmitBlocksIncompletePlan() throws {
    let plan = try makePlan()
    let emitter = ASHArtifactEmitter()
    let invalidArtifact = ASHPlannedArtifactDescription(
      artifactID: "ART-999",
      artifactKind: "STATE_FRAGMENT",
      targetPathHint: "artifacts/invalid.json",
      summary: "Invalid artifact with missing role reference.",
      requiredRoleIDs: ["ROLE-MISSING"],
      ruleIDs: ["ASH-STATE-PLANNING-008"],
      metadata: [:]
    )
    let invalidPlan = ASHGenerationPlan(
      normalizedState: plan.normalizedState,
      sourceRealm: plan.sourceRealm,
      destinationRealm: plan.destinationRealm,
      topologyNodes: plan.topologyNodes,
      roleAssignments: plan.roleAssignments,
      axiomSummaries: plan.axiomSummaries,
      artifacts: plan.artifacts + [invalidArtifact],
      targetConstraints: plan.targetConstraints,
      warnings: plan.warnings,
      metadata: plan.metadata
    )

    let result = emitter.emit(plan: invalidPlan)

    XCTAssertTrue(result.artifacts.isEmpty)
    XCTAssertEqual(result.diagnostics.first?.disposition, .blocked)
  }

  private func makePlan() throws -> ASHGenerationPlan {
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    let topologyGenerator = ASHTopologyGenerator(
      stateModel: stateModel,
      transitionRegistry: registry
    )
    let topology = try XCTUnwrap(
      topologyGenerator.generateTopology(from: .zero, depth: 1, seedToken: "F").topology
    )
    let planner = ASHGenerationPlanner(
      stateModel: stateModel,
      realmEncoder: ASHRealmEncoder(stateModel: stateModel)
    )
    let planResult = planner.buildPlan(
      from: .zero,
      topology: topology,
      axiomEvaluation: ASHAxiomEvaluator().evaluate(state: .zero),
      targetConstraints: .init()
    )
    return try XCTUnwrap(planResult.plan)
  }
}
