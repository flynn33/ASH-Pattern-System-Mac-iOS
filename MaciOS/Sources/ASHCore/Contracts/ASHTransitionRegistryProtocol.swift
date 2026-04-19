import Foundation

public protocol ASHTransitionRegistryProtocol: AnyObject {
  var orderedTransitions: [ASHTransitionDefinition] { get }

  func availableTransitions(from state: ASHState) -> [ASHTransitionDefinition]
  func applyTransition(from state: ASHState, transitionID: String) -> ASHTransitionResolution
  func applyCodeword(from state: ASHState, codeword: ASHState) -> ASHTransitionResolution
}
