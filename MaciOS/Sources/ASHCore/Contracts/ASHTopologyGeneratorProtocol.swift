import Foundation

public protocol ASHTopologyGeneratorProtocol: AnyObject, Sendable {
  func generateTopology(
    from state: ASHState,
    depth: Int,
    seedToken: String
  ) -> ASHTopologyGenerationResult
}
