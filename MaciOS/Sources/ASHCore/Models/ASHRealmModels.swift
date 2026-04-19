import Foundation

public struct ASHRealmIdentity: Codable, Hashable, Sendable {
  public let stateSignature: String
  public let realmID: String

  public init(
    stateSignature: String,
    realmID: String
  ) {
    self.stateSignature = stateSignature
    self.realmID = realmID
  }
}

public enum ASHRealmEncodingFailureReason: String, Codable, Sendable {
  case invalidInputState = "INVALID_INPUT_STATE"
}

public struct ASHRealmEncodingFailureDiagnostic: Codable, Hashable, Sendable {
  public let reason: ASHRealmEncodingFailureReason
  public let summary: String
  public let ruleIDs: [String]
  public let notes: [String]

  public init(
    reason: ASHRealmEncodingFailureReason,
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

public enum ASHRealmEncodingResult: Sendable {
  case success(ASHRealmIdentity)
  case failure(ASHRealmEncodingFailureDiagnostic)

  public var identity: ASHRealmIdentity? {
    if case let .success(value) = self {
      return value
    }
    return nil
  }

  public var failureDiagnostic: ASHRealmEncodingFailureDiagnostic? {
    if case let .failure(value) = self {
      return value
    }
    return nil
  }
}
