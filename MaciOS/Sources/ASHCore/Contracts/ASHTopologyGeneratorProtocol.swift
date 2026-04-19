import Foundation

public protocol ASHTopologyGeneratorProtocol: AnyObject {
  func generateTopology(
    from state: ASHState,
    depth: Int,
    seedToken: String
  ) -> ASHTopologyGenerationResult
}
