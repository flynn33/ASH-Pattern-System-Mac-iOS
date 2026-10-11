import Foundation

public enum ASHRuntimeMode: String, Codable, Hashable, Sendable {
  case active = "ACTIVE", contained = "CONTAINED", failed = "FAILED", safeHalt = "SAFE_HALT"
}
public enum ASHFallbackPolicy: String, Codable, Hashable, Sendable {
  case declaredKnownGood = "FALLBACK-STATE-001"
  case lastVerifiedStable = "FALLBACK-STATE-002"
  case containmentEscalation = "FALLBACK-STATE-999"
}
public struct ASHFallbackCandidate: Codable, Hashable, Sendable {
  public let state: ASHState
  public let configuredRank: Int
  public let verificationSequence: Int?
  public let evidence: String
  public let applicable: Bool
  public init(state: ASHState, configuredRank: Int = 0, verificationSequence: Int? = nil, evidence: String, applicable: Bool = true) {
    self.state = state; self.configuredRank = configuredRank; self.verificationSequence = verificationSequence
    self.evidence = evidence; self.applicable = applicable
  }
}
public struct ASHFallbackPolicyInstance: Codable, Hashable, Sendable {
  public let policy: ASHFallbackPolicy
  public let version: String
  public let candidates: [ASHFallbackCandidate]
  public init(policy: ASHFallbackPolicy = .containmentEscalation, version: String = "1.0", candidates: [ASHFallbackCandidate] = []) {
    self.policy = policy; self.version = version; self.candidates = candidates
  }
  public var validationIssues: [String] {
    var issues: [String] = []
    if version != "1.0" { issues.append("Fallback registry version must be 1.0.") }
    if policy == .containmentEscalation && !candidates.isEmpty { issues.append("Containment policy cannot declare replacement candidates.") }
    if Set(candidates.map(\.state)).count != candidates.count { issues.append("Fallback candidate states must be unique.") }
    for (i, c) in candidates.enumerated() {
      if c.configuredRank < 0 || c.evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        issues.append("Fallback candidate \(i) requires a nonnegative rank and declared evidence.")
      }
      if policy == .lastVerifiedStable && (c.verificationSequence == nil || (c.verificationSequence ?? -1) < 0) {
        issues.append("Last Verified Stable candidate \(i) requires nonnegative verification sequence.")
      }
    }
    return issues
  }
  public var orderedCandidates: [ASHFallbackCandidate] {
    guard validationIssues.isEmpty, policy != .containmentEscalation else { return [] }
    return candidates.filter(\.applicable).sorted {
      if policy == .lastVerifiedStable {
        let l = $0.verificationSequence ?? -1, r = $1.verificationSequence ?? -1
        return l == r ? $0.state < $1.state : l > r
      }
      return $0.configuredRank == $1.configuredRank ? $0.state < $1.state : $0.configuredRank < $1.configuredRank
    }
  }
}
public enum ASHPropagationRiskPolicy: String, Codable, Hashable, Sendable { case blockObservedPropagation = "BLOCK_OBSERVED_PROPAGATION" }
public enum ASHContainmentPolicy: String, Codable, Hashable, Sendable { case externalResolutionRequired = "EXTERNAL_RESOLUTION_REQUIRED" }
public enum ASHHaltPolicy: String, Codable, Hashable, Sendable { case terminal = "TERMINAL" }
public struct ASHOperationalContext: Codable, Hashable, Sendable {
  public let contextID: String
  public let contextVersion: String
  public let allowedStableStates: [ASHState]
  public let preferredState: ASHState?
  public let fallbackPolicyInstance: ASHFallbackPolicyInstance
  public let propagationRiskPolicy: ASHPropagationRiskPolicy
  public let containmentPolicy: ASHContainmentPolicy
  public let haltPolicy: ASHHaltPolicy
  public let registryVersions: [String: String]
  public init(contextID: String, contextVersion: String = "1.0", allowedStableStates: [ASHState], preferredState: ASHState? = nil,
    fallbackPolicyInstance: ASHFallbackPolicyInstance = .init(),
    propagationRiskPolicy: ASHPropagationRiskPolicy = .blockObservedPropagation,
    containmentPolicy: ASHContainmentPolicy = .externalResolutionRequired, haltPolicy: ASHHaltPolicy = .terminal,
    registryVersions: [String: String] = ["codewords":"1.0", "transitions":"1.0", "fallback":"1.0"]) {
    self.contextID = contextID; self.contextVersion = contextVersion; self.allowedStableStates = allowedStableStates.sorted()
    self.preferredState = preferredState; self.fallbackPolicyInstance = fallbackPolicyInstance
    self.propagationRiskPolicy = propagationRiskPolicy; self.containmentPolicy = containmentPolicy; self.haltPolicy = haltPolicy
    self.registryVersions = registryVersions
  }
  public var validationIssues: [String] {
    var issues = fallbackPolicyInstance.validationIssues
    if contextID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("Operational context ID must be nonempty.") }
    if contextVersion != "1.0" { issues.append("Operational context version must be 1.0.") }
    if allowedStableStates.isEmpty || Set(allowedStableStates).count != allowedStableStates.count { issues.append("Stable states must be nonempty and unique.") }
    if let preferredState, !allowedStableStates.contains(preferredState) { issues.append("Preferred state must belong to the declared stable set.") }
    if registryVersions != ["codewords":"1.0", "transitions":"1.0", "fallback":"1.0"] { issues.append("Operational registry versions must match the supported 1.0 registry set.") }
    return issues
  }
  public func validate() throws { if !validationIssues.isEmpty { throw ASHRegistryValidationError(issues: validationIssues) } }
}
public enum ASHInputStatus: String, Codable, Hashable, Sendable { case wellFormed = "WELL_FORMED", malformed = "MALFORMED" }
public struct ASHStateAssessment: Codable, Hashable, Sendable {
  public let state: ASHState?
  public let inputStatus: ASHInputStatus
  public let contextID: String?
  public let candidateTargets: [ASHState]
  public let selectedTarget: ASHState?
  public let correctionCodewordID: String?
  public let runtimeMode: ASHRuntimeMode
  public let stateClass: SystemStateClass?
  public let diagnostics: [ASHDiagnosticEnvelope]
  public var assessmentBlocked: Bool { stateClass == nil }
  public var recoveryCategory: RecoveryCategory? { stateClass.map(ASHStateModel().classifyRecovery) }
  public init(state: ASHState?, inputStatus: ASHInputStatus, contextID: String?, candidateTargets: [ASHState], selectedTarget: ASHState?, correctionCodewordID: String?, runtimeMode: ASHRuntimeMode, stateClass: SystemStateClass?, diagnostics: [ASHDiagnosticEnvelope]) {
    self.state = state; self.inputStatus = inputStatus; self.contextID = contextID; self.candidateTargets = candidateTargets
    self.selectedTarget = selectedTarget; self.correctionCodewordID = correctionCodewordID; self.runtimeMode = runtimeMode
    self.stateClass = stateClass; self.diagnostics = diagnostics
  }
}
public enum ASHOperationalRecoveryOutcome: String, Codable, Hashable, Sendable {
  case recovered = "RECOVERED", recoveredViaFallbackReplacement = "RECOVERED_VIA_FALLBACK_REPLACEMENT"
  case targetResolutionBlocked = "TARGET_RESOLUTION_BLOCKED", recoveryFailed = "RECOVERY_FAILED"
  case escalateToContainment = "ESCALATE_TO_CONTAINMENT", notApplicable = "NOT_APPLICABLE"
}
public struct ASHOperationalRecoveryResult: Codable, Hashable, Sendable {
  public let recoveryCategory: RecoveryCategory?
  public let outcome: ASHOperationalRecoveryOutcome
  public let preAssessment: ASHStateAssessment
  public let postAssessment: ASHStateAssessment?
  public let targetState: ASHState?
  public let replacementState: ASHState?
  public let codewordID: String?
  public let fallbackPolicyID: String?
  public let diagnostics: [ASHDiagnosticEnvelope]
  public var resultingState: ASHState? { replacementState ?? targetState ?? preAssessment.state }
}
