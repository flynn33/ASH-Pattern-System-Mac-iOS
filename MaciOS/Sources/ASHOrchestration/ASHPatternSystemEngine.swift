import Foundation
import ASHCore

public final class ASHPatternSystemEngine: Sendable {
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
    let candidate = requestedState ?? .zero
    let requestedStateDiagnostic = stateModel.diagnose(candidate)
    let bootState = candidate
    let startupStatus: ASHPatternSystemStartupStatus = .usedRequestedState
    let startupNotes = ["Structural bootstrap preserves the requested realm. Operational mutation is owned by ASHPatternSystemSession under a validated context."]

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

  public func assessState(bitString: String, context: ASHOperationalContext?) -> ASHStateAssessment {
    stateModel.assess(bitString:bitString,context:context)
  }

  @available(*, deprecated, message:"Use assessState(bitString:context:) for explicit malformed-input diagnostics.")
  public func diagnoseState(bitString: String) -> StateValidityDiagnostic? {
    guard let state = ASHState(bitString: bitString) else {
      return nil
    }

    return stateModel.diagnose(state)
  }
}
