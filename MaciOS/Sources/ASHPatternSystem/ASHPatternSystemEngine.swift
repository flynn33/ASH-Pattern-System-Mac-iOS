import Foundation
import ASHCore

public final class ASHPatternSystemEngine {
  public let stateModel: any ASHStateModelProtocol
  public let axiomEvaluator: any ASHAxiomEvaluatorProtocol
  public let transitionRegistry: any ASHTransitionRegistryProtocol
  public let topologyGenerator: any ASHTopologyGeneratorProtocol

  public init(
    stateModel: any ASHStateModelProtocol = ASHStateModel(),
    axiomEvaluator: (any ASHAxiomEvaluatorProtocol)? = nil,
    transitionRegistry: (any ASHTransitionRegistryProtocol)? = nil,
    topologyGenerator: (any ASHTopologyGeneratorProtocol)? = nil
  ) {
    self.stateModel = stateModel
    self.axiomEvaluator = axiomEvaluator ?? ASHAxiomEvaluator()

    let resolvedTransitionRegistry = transitionRegistry
      ?? ASHTransitionRegistry(stateModel: stateModel)
    self.transitionRegistry = resolvedTransitionRegistry

    self.topologyGenerator = topologyGenerator
      ?? ASHTopologyGenerator(
        stateModel: stateModel,
        transitionRegistry: resolvedTransitionRegistry
      )
  }

  public func bootstrap(
    from requestedState: ASHState? = nil,
    configuration: ASHPatternSystemEngineConfiguration = .init()
  ) -> ASHPatternSystemBootstrapReport {
    let candidate = requestedState ?? stateModel.knownValidStates.sorted().first ?? .zero
    let requestedStateDiagnostic = stateModel.diagnose(candidate)

    let bootState: ASHState
    let startupStatus: ASHPatternSystemStartupStatus
    var startupNotes: [String] = []

    if let normalized = stateModel.normalize(candidate) {
      bootState = normalized
      if normalized == candidate {
        startupStatus = .usedRequestedState
        startupNotes.append("Requested state was already suitable for bootstrap.")
      } else {
        startupStatus = .normalizedRequestedState
        startupNotes.append(
          "Requested state normalized from \(candidate.description) to \(normalized.description)."
        )
      }
    } else {
      let fallbackState = stateModel.knownValidStates.sorted().first ?? candidate
      bootState = fallbackState
      startupStatus = .fallbackToKnownValid
      startupNotes.append(
        "Requested state \(candidate.description) could not be normalized."
      )
      startupNotes.append(
        "Fallback bootstrap state selected: \(fallbackState.description)."
      )
      startupNotes.append(
        "Requested-state normalization status: \(requestedStateDiagnostic.normalizationStatus.rawValue)."
      )
    }

    let stateDiagnostic = stateModel.diagnose(bootState)
    let axiomEvaluation = axiomEvaluator.evaluate(state: bootState)
    let availableTransitions = transitionRegistry.availableTransitions(from: bootState)
    let topologyResult = topologyGenerator.generateTopology(
      from: bootState,
      depth: configuration.topologyDepth,
      seedToken: configuration.topologySeedToken
    )

    return ASHPatternSystemBootstrapReport(
      requestedState: candidate,
      requestedStateDiagnostic: requestedStateDiagnostic,
      startupStatus: startupStatus,
      startupNotes: startupNotes,
      state: bootState,
      stateDiagnostic: stateDiagnostic,
      axiomEvaluation: axiomEvaluation,
      availableTransitions: availableTransitions,
      topologyResult: topologyResult
    )
  }

  public func diagnoseState(bitString: String) -> StateValidityDiagnostic? {
    guard let state = ASHState(bitString: bitString) else {
      return nil
    }

    return stateModel.diagnose(state)
  }
}
