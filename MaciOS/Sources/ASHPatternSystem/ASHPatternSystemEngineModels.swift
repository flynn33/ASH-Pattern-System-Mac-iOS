import Foundation
import ASHCore

public struct ASHPatternSystemEngineConfiguration: Codable, Hashable, Sendable {
  public let topologyDepth: Int
  public let topologySeedToken: String

  public init(
    topologyDepth: Int = 1,
    topologySeedToken: String = "F"
  ) {
    self.topologyDepth = topologyDepth
    self.topologySeedToken = topologySeedToken
  }
}

public struct ASHPatternSystemBootstrapReport: Sendable {
  public let state: ASHState
  public let stateDiagnostic: StateValidityDiagnostic
  public let axiomEvaluation: ASHAxiomEvaluation
  public let availableTransitions: [ASHTransitionDefinition]
  public let topologyResult: ASHTopologyGenerationResult

  public init(
    state: ASHState,
    stateDiagnostic: StateValidityDiagnostic,
    axiomEvaluation: ASHAxiomEvaluation,
    availableTransitions: [ASHTransitionDefinition],
    topologyResult: ASHTopologyGenerationResult
  ) {
    self.state = state
    self.stateDiagnostic = stateDiagnostic
    self.axiomEvaluation = axiomEvaluation
    self.availableTransitions = availableTransitions
    self.topologyResult = topologyResult
  }
}
