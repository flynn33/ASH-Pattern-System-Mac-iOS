import Foundation
import ASHCore

public enum ASHPatternSystemStartupStatus: String, Codable, Hashable, Sendable {
  case usedRequestedState = "USED_REQUESTED_STATE"
  case normalizedRequestedState = "NORMALIZED_REQUESTED_STATE"
  case fallbackToKnownValid = "FALLBACK_TO_KNOWN_VALID"
}

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
  public let requestedState: ASHState
  public let requestedStateDiagnostic: StateValidityDiagnostic
  public let startupStatus: ASHPatternSystemStartupStatus
  public let startupNotes: [String]
  public let state: ASHState
  public let stateDiagnostic: StateValidityDiagnostic
  public let axiomEvaluation: ASHAxiomEvaluation
  public let availableTransitions: [ASHTransitionDefinition]
  public let topologyResult: ASHTopologyGenerationResult

  public init(
    requestedState: ASHState,
    requestedStateDiagnostic: StateValidityDiagnostic,
    startupStatus: ASHPatternSystemStartupStatus,
    startupNotes: [String],
    state: ASHState,
    stateDiagnostic: StateValidityDiagnostic,
    axiomEvaluation: ASHAxiomEvaluation,
    availableTransitions: [ASHTransitionDefinition],
    topologyResult: ASHTopologyGenerationResult
  ) {
    self.requestedState = requestedState
    self.requestedStateDiagnostic = requestedStateDiagnostic
    self.startupStatus = startupStatus
    self.startupNotes = startupNotes
    self.state = state
    self.stateDiagnostic = stateDiagnostic
    self.axiomEvaluation = axiomEvaluation
    self.availableTransitions = availableTransitions
    self.topologyResult = topologyResult
  }
}
