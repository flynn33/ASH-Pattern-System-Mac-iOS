import Foundation

public protocol ASHRecoveryEngineProtocol: AnyObject {
  var fallbackPolicyRegistry: [ASHFallbackPolicyEntry] { get }

  func recover(
    diagnostic: StateValidityDiagnostic,
    stateClass: SystemStateClass,
    recoveryCategory: RecoveryCategory
  ) -> ASHRecoveryResolution

  func enterContainment(
    diagnostic: StateValidityDiagnostic,
    trigger: ASHContainmentTrigger,
    parentDiagnosticReference: String?
  ) -> ASHContainmentDiagnostic

  func enterSafeHalt(
    diagnostic: StateValidityDiagnostic,
    trigger: ASHSafeHaltTrigger,
    chainReferences: [String]
  ) -> ASHSafeHaltDiagnostic
}
