import Foundation

public protocol ASHStateModelProtocol: AnyObject, Sendable {
  var codewordSet: Set<ASHState> { get }
  var knownValidStates: Set<ASHState> { get }
  func transform(_ state: ASHState, by codeword: ASHState) -> ASHState?
  func normalize(_ state: ASHState) -> ASHState?
  func isValid(_ state: ASHState) -> Bool
  func classifyAdmissibility(of state: ASHState) -> AdmissibilityStatus
  func diagnose(_ state: ASHState) -> StateValidityDiagnostic
  func reachableStates(from state: ASHState) -> [ASHState]
  func isReachable(from source: ASHState, to target: ASHState) -> Bool
  func codewordID(for word: ASHState) -> String?
  func assess(state: ASHState, context: ASHOperationalContext?, runtime: ASHRuntimeMode) -> ASHStateAssessment
  func assess(bitString: String, context: ASHOperationalContext?, runtime: ASHRuntimeMode) -> ASHStateAssessment
  func classifyRecovery(for stateClass: SystemStateClass) -> RecoveryCategory
}
extension ASHStateModelProtocol {
  public func assess(state: ASHState, context: ASHOperationalContext?) -> ASHStateAssessment { assess(state: state, context: context, runtime: .active) }
  public func assess(bitString: String, context: ASHOperationalContext?) -> ASHStateAssessment { assess(bitString: bitString, context: context, runtime: .active) }
}
