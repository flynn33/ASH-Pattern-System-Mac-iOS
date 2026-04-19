import Foundation

public struct ASHTransitionDefinition: Codable, Hashable, Sendable {
  public let transitionID: String
  public let displayName: String
  public let description: String
  public let codeword: ASHState

  public init(
    transitionID: String,
    displayName: String,
    description: String,
    codeword: ASHState
  ) {
    self.transitionID = transitionID
    self.displayName = displayName
    self.description = description
    self.codeword = codeword
  }
}

public struct ASHTransitionApplied: Codable, Hashable, Sendable {
  public let transitionID: String
  public let fromState: ASHState
  public let toState: ASHState
  public let codeword: ASHState

  public init(
    transitionID: String,
    fromState: ASHState,
    toState: ASHState,
    codeword: ASHState
  ) {
    self.transitionID = transitionID
    self.fromState = fromState
    self.toState = toState
    self.codeword = codeword
  }
}

public enum ASHTransitionFailureReason: String, Codable, Sendable {
  case invalidInputState = "INVALID_INPUT_STATE"
  case transitionNotFound = "TRANSITION_NOT_FOUND"
  case transitionNotApplicable = "TRANSITION_NOT_APPLICABLE"
  case codewordNotAllowed = "CODEWORD_NOT_ALLOWED"
}

public struct ASHTransitionFailureDiagnostic: Codable, Hashable, Sendable {
  public let reason: ASHTransitionFailureReason
  public let summary: String
  public let ruleIDs: [String]
  public let notes: [String]

  public init(
    reason: ASHTransitionFailureReason,
    summary: String,
    ruleIDs: [String],
    notes: [String]
  ) {
    self.reason = reason
    self.summary = summary
    self.ruleIDs = ruleIDs
    self.notes = notes
  }
}

public enum ASHTransitionResolution: Sendable {
  case success(ASHTransitionApplied)
  case failure(ASHTransitionFailureDiagnostic)

  public var applied: ASHTransitionApplied? {
    if case let .success(value) = self {
      return value
    }
    return nil
  }

  public var failureDiagnostic: ASHTransitionFailureDiagnostic? {
    if case let .failure(value) = self {
      return value
    }
    return nil
  }
}
