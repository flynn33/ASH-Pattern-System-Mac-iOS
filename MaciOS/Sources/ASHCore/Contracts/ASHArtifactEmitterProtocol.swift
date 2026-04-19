import Foundation

public protocol ASHArtifactEmitterProtocol: AnyObject {
  func emit(plan: ASHGenerationPlan) -> ASHArtifactEmissionResult
}
