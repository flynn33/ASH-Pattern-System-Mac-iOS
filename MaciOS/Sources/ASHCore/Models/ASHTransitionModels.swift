import Foundation

public struct ASHTransitionApplicability: Codable, Hashable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case always = "ALWAYS"
    case requireBitSet = "REQUIRE_BIT_SET"
    case requireBitClear = "REQUIRE_BIT_CLEAR"
  }

  public let kind: Kind
  public let bitIndex: Int?

  public init(kind: Kind, bitIndex: Int? = nil) {
    self.kind = kind
    self.bitIndex = bitIndex
  }

  public static let always = ASHTransitionApplicability(kind: .always)

  public static func requireBitSet(_ bitIndex: Int) -> ASHTransitionApplicability {
    precondition((0..<ASHState.bitCount).contains(bitIndex), "bitIndex must be within 0..<ASHState.bitCount")
    return ASHTransitionApplicability(kind: .requireBitSet, bitIndex: bitIndex)
  }

  public static func requireBitClear(_ bitIndex: Int) -> ASHTransitionApplicability {
    precondition((0..<ASHState.bitCount).contains(bitIndex), "bitIndex must be within 0..<ASHState.bitCount")
    return ASHTransitionApplicability(kind: .requireBitClear, bitIndex: bitIndex)
  }

  public func isApplicable(to state: ASHState) -> Bool {
    switch kind {
    case .always:
      return true
    case .requireBitSet:
      guard let bitIndex, (0..<ASHState.bitCount).contains(bitIndex) else {
        return false
      }
      return state.bits[bitIndex] == 1
    case .requireBitClear:
      guard let bitIndex, (0..<ASHState.bitCount).contains(bitIndex) else {
        return false
      }
      return state.bits[bitIndex] == 0
    }
  }
}

public struct ASHTransitionDefinition: Codable, Hashable, Sendable {
  public let transitionID: String
  public let displayName: String
  public let description: String
  public let codeword: ASHState
  public let applicability: ASHTransitionApplicability

  public init(
    transitionID: String,
    displayName: String,
    description: String,
    codeword: ASHState,
    applicability: ASHTransitionApplicability = .always
  ) {
    self.transitionID = transitionID
    self.displayName = displayName
    self.description = description
    self.codeword = codeword
    self.applicability = applicability
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
