import Foundation

public protocol ASHGenerationPlannerProtocol: AnyObject, Sendable {
  func buildPlan(
    from state: ASHState,
    topology: ASHTopology,
    axiomEvaluation: ASHAxiomEvaluation,
    targetConstraints: ASHTargetRuntimeConstraints
  ) -> ASHGenerationPlanResult
}
