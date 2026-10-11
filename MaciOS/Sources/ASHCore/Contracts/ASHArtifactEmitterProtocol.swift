import Foundation

public protocol ASHArtifactEmitterProtocol: AnyObject, Sendable {
  func emit(plan: ASHGenerationPlan) -> ASHArtifactEmissionResult
}
