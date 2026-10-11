import Foundation

public protocol ASHRecoveryEngineProtocol: AnyObject, Sendable {
  func recover(state: ASHState, context: ASHOperationalContext, runtime: ASHRuntimeMode) -> ASHOperationalRecoveryResult
}
