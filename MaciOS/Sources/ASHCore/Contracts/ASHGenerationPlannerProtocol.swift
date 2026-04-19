import Foundation

public protocol ASHGenerationPlannerProtocol: AnyObject {
  func buildPlan(
    from state: ASHState,
    topology: ASHTopology,
    axiomEvaluation: ASHAxiomEvaluation,
    targetConstraints: ASHTargetRuntimeConstraints
  ) -> ASHGenerationPlanResult
}
