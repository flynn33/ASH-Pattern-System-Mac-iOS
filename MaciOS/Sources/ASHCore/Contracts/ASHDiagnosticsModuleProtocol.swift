import Foundation

public protocol ASHDiagnosticsModuleProtocol: AnyObject {
  func validateEnvelope(_ envelope: ASHDiagnosticEnvelope) -> ASHDiagnosticValidationResult
  func validateChain(_ chain: [ASHDiagnosticEnvelope]) -> ASHDiagnosticChainValidationResult
  func detectOmissions(
    expectedDiagnosticReferences: [String],
    actualChain: [ASHDiagnosticEnvelope],
    chainRootReference: String
  ) -> ASHDiagnosticEnvelope?
}
