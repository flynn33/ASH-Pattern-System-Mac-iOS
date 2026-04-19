import Foundation

public protocol ASHStateModelProtocol: AnyObject {
  var codewordSet: Set<ASHState> { get }
  var knownValidStates: Set<ASHState> { get }

  func transform(_ state: ASHState, by codeword: ASHState) -> ASHState?
  func normalize(_ state: ASHState) -> ASHState?
  func isValid(_ state: ASHState) -> Bool
  func classifyAdmissibility(of state: ASHState) -> AdmissibilityStatus
  func diagnose(_ state: ASHState) -> StateValidityDiagnostic
  func classifySystemState(
    for diagnostic: StateValidityDiagnostic,
    context: ASHSystemContext
  ) -> SystemStateClass
  func classifyRecovery(for stateClass: SystemStateClass) -> RecoveryCategory
}
