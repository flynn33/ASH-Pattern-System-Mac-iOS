import XCTest
import ASHCore

final class ASHCanonicalProjectionTests: XCTestCase {
  func testEveryOwnedServiceProducesValidCanonicalSuccessAndFailureRecords() throws {
    let model = ASHStateModel(), registry = ASHTransitionRegistry(stateModel:ASHStateModel())
    let realm = ASHRealmEncoder(stateModel:model), evaluator = ASHAxiomEvaluator()
    let topologyResult = ASHTopologyGenerator(stateModel:model,transitionRegistry:registry).generateTopology(from:.zero,depth:1)
    let topology = try XCTUnwrap(topologyResult.topology)
    let planner = ASHGenerationPlanner(stateModel:model,realmEncoder:realm)
    let planResult = planner.buildPlan(from:.zero,topology:topology,axiomEvaluation:evaluator.evaluate(state:.zero))
    let plan = try XCTUnwrap(planResult.plan)
    let records = [model.diagnose(.zero).canonicalDiagnostic()]
      + realm.encode(state:.zero).canonicalDiagnostics(subject:"000000000")
      + registry.applyTransition(from:.zero,transitionID:"APS-TRANSITION-CW-01").canonicalDiagnostics(subject:"000000000")
      + registry.applyTransition(from:.zero,transitionID:"unknown").canonicalDiagnostics(subject:"000000000")
      + evaluator.evaluate(subject:.init()).canonicalDiagnostics(subject:"evidence")
      + topologyResult.canonicalDiagnostics(subject:"000000000")
      + ASHTopologyGenerator(stateModel:model,transitionRegistry:registry).generateTopology(from:.zero,depth:Int.max).canonicalDiagnostics(subject:"000000000")
      + planResult.canonicalDiagnostics(subject:"000000000")
      + planner.buildPlan(from:.zero,topology:topology,axiomEvaluation:evaluator.evaluate(state:.zero),targetConstraints:.init(profileID:"unknown")).canonicalDiagnostics(subject:"000000000")
      + ASHArtifactEmitter().emit(plan:plan).canonicalDiagnostics(subject:"000000000")
    for record in records {
      let validation = ASHDiagnosticsModule().validateEnvelope(record)
      XCTAssertTrue(validation.isValid,"\(record.diagnosticKind): \(validation.issues)")
    }
  }
}
