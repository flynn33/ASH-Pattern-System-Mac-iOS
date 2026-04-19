import Foundation

public enum ASHFallbackEscalationAction: String, Codable, Sendable {
  case tryNext = "TRY_NEXT"
  case escalateToContainment = "ESCALATE_TO_CONTAINMENT"
}

public struct ASHFallbackPolicyEntry: Codable, Hashable, Sendable {
  public let policyID: String
  public let candidateStateReference: ASHState
  public let orderingRank: Int
  public let escalationOnFailure: ASHFallbackEscalationAction
  public let notes: [String]

  public init(
    policyID: String,
    candidateStateReference: ASHState,
    orderingRank: Int,
    escalationOnFailure: ASHFallbackEscalationAction,
    notes: [String]
  ) {
    self.policyID = policyID
    self.candidateStateReference = candidateStateReference
    self.orderingRank = orderingRank
    self.escalationOnFailure = escalationOnFailure
    self.notes = notes
  }
}

public enum ASHRecoveryStepStatus: String, Codable, Sendable {
  case completed = "COMPLETED"
  case blocked = "BLOCKED"
  case failed = "FAILED"
  case skipped = "SKIPPED"
}

public struct ASHRecoveryStep: Codable, Hashable, Sendable {
  public let stepID: String
  public let status: ASHRecoveryStepStatus
  public let summary: String
  public let ruleIDs: [String]
  public let notes: [String]

  public init(
    stepID: String,
    status: ASHRecoveryStepStatus,
    summary: String,
    ruleIDs: [String],
    notes: [String]
  ) {
    self.stepID = stepID
    self.status = status
    self.summary = summary
    self.ruleIDs = ruleIDs
    self.notes = notes
  }
}

public enum ASHRecoveryOutcome: String, Codable, Sendable {
  case recovered = "RECOVERED"
  case recoveredViaFallback = "RECOVERED_VIA_FALLBACK"
  case blocked = "BLOCKED"
  case recoveryFailed = "RECOVERY_FAILED"
  case escalateToContainment = "ESCALATE_TO_CONTAINMENT"
  case notApplicable = "NOT_APPLICABLE"
}

public struct ASHRecoveryDiagnostic: Codable, Hashable, Sendable {
  public let diagnosticReference: String
  public let chainRootReference: String
  public let recoveryCategory: RecoveryCategory
  public let originalStateClass: SystemStateClass
  public let originalDiagnostic: StateValidityDiagnostic
  public let steps: [ASHRecoveryStep]
  public let outcome: ASHRecoveryOutcome
  public let correctedState: ASHState?
  public let fallbackPolicyID: String?
  public let reason: String
  public let ruleIDs: [String]
  public let notes: [String]

  public init(
    diagnosticReference: String,
    chainRootReference: String,
    recoveryCategory: RecoveryCategory,
    originalStateClass: SystemStateClass,
    originalDiagnostic: StateValidityDiagnostic,
    steps: [ASHRecoveryStep],
    outcome: ASHRecoveryOutcome,
    correctedState: ASHState?,
    fallbackPolicyID: String?,
    reason: String,
    ruleIDs: [String],
    notes: [String]
  ) {
    self.diagnosticReference = diagnosticReference
    self.chainRootReference = chainRootReference
    self.recoveryCategory = recoveryCategory
    self.originalStateClass = originalStateClass
    self.originalDiagnostic = originalDiagnostic
    self.steps = steps
    self.outcome = outcome
    self.correctedState = correctedState
    self.fallbackPolicyID = fallbackPolicyID
    self.reason = reason
    self.ruleIDs = ruleIDs
    self.notes = notes
  }
}

public enum ASHContainmentTrigger: String, Codable, Sendable {
  case fallbackFailure = "FALLBACK_FAILURE"
  case propagationRisk = "PROPAGATION_RISK"
  case operatorRequest = "OPERATOR_REQUEST"
  case recoveryValidationFailure = "RECOVERY_VALIDATION_FAILURE"
}

public struct ASHContainmentDiagnostic: Codable, Hashable, Sendable {
  public let diagnosticReference: String
  public let chainRootReference: String
  public let trigger: ASHContainmentTrigger
  public let originalDiagnostic: StateValidityDiagnostic
  public let systemStateClass: SystemStateClass
  public let restrictedOperations: [String]
  public let awaitingResolution: Bool
  public let ruleIDs: [String]
  public let notes: [String]

  public init(
    diagnosticReference: String,
    chainRootReference: String,
    trigger: ASHContainmentTrigger,
    originalDiagnostic: StateValidityDiagnostic,
    systemStateClass: SystemStateClass,
    restrictedOperations: [String],
    awaitingResolution: Bool,
    ruleIDs: [String],
    notes: [String]
  ) {
    self.diagnosticReference = diagnosticReference
    self.chainRootReference = chainRootReference
    self.trigger = trigger
    self.originalDiagnostic = originalDiagnostic
    self.systemStateClass = systemStateClass
    self.restrictedOperations = restrictedOperations
    self.awaitingResolution = awaitingResolution
    self.ruleIDs = ruleIDs
    self.notes = notes
  }
}

public enum ASHSafeHaltTrigger: String, Codable, Sendable {
  case escalationFromFailed = "ESCALATION_FROM_FAILED"
  case containmentBreach = "CONTAINMENT_BREACH"
  case operatorHaltRequest = "OPERATOR_HALT_REQUEST"
  case policyHaltRequest = "POLICY_HALT_REQUEST"
  case unresolvableBlockedRecovery = "UNRESOLVABLE_BLOCKED_RECOVERY"
}

public struct ASHSafeHaltDiagnostic: Codable, Hashable, Sendable {
  public let diagnosticReference: String
  public let chainRootReference: String
  public let trigger: ASHSafeHaltTrigger
  public let originalDiagnostic: StateValidityDiagnostic
  public let systemStateClass: SystemStateClass
  public let fullDiagnosticChainReferences: [String]
  public let isTerminal: Bool
  public let ruleIDs: [String]
  public let notes: [String]

  public init(
    diagnosticReference: String,
    chainRootReference: String,
    trigger: ASHSafeHaltTrigger,
    originalDiagnostic: StateValidityDiagnostic,
    systemStateClass: SystemStateClass,
    fullDiagnosticChainReferences: [String],
    isTerminal: Bool,
    ruleIDs: [String],
    notes: [String]
  ) {
    self.diagnosticReference = diagnosticReference
    self.chainRootReference = chainRootReference
    self.trigger = trigger
    self.originalDiagnostic = originalDiagnostic
    self.systemStateClass = systemStateClass
    self.fullDiagnosticChainReferences = fullDiagnosticChainReferences
    self.isTerminal = isTerminal
    self.ruleIDs = ruleIDs
    self.notes = notes
  }
}

public enum ASHRecoveryResolution: Sendable {
  case recovery(ASHRecoveryDiagnostic)
  case containment(ASHContainmentDiagnostic)
  case safeHalt(ASHSafeHaltDiagnostic)

  public var recoveryDiagnostic: ASHRecoveryDiagnostic? {
    if case let .recovery(value) = self {
      return value
    }
    return nil
  }

  public var containmentDiagnostic: ASHContainmentDiagnostic? {
    if case let .containment(value) = self {
      return value
    }
    return nil
  }

  public var safeHaltDiagnostic: ASHSafeHaltDiagnostic? {
    if case let .safeHalt(value) = self {
      return value
    }
    return nil
  }
}
