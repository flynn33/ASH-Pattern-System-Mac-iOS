import Foundation

public enum ASHDiagnosticKind: String, Codable, Sendable {
  case stateValidity = "STATE_VALIDITY"
  case recovery = "RECOVERY"
  case fallback = "FALLBACK"
  case containment = "CONTAINMENT"
  case safeHalt = "SAFE_HALT"
  case planning = "PLANNING"
  case emission = "EMISSION"
  case meta = "META"
}

public enum ASHDiagnosticSeverity: String, Codable, Sendable {
  case info = "INFO"
  case warning = "WARNING"
  case error = "ERROR"
  case critical = "CRITICAL"
}

public enum ASHDiagnosticStage: String, Codable, Sendable {
  case detection = "DETECTION"
  case classification = "CLASSIFICATION"
  case recovery = "RECOVERY"
  case escalation = "ESCALATION"
  case terminal = "TERMINAL"
}

public enum ASHDiagnosticDisposition: String, Codable, Sendable {
  case resolved = "RESOLVED"
  case pending = "PENDING"
  case blocked = "BLOCKED"
  case escalated = "ESCALATED"
  case terminal = "TERMINAL"
}

public struct ASHDiagnosticEnvelope: Codable, Hashable, Sendable {
  public let diagnosticReference: String
  public let diagnosticKind: ASHDiagnosticKind
  public let severity: ASHDiagnosticSeverity
  public let stage: ASHDiagnosticStage
  public let disposition: ASHDiagnosticDisposition
  public let subjectReference: String
  public let parentDiagnosticReference: String?
  public let chainRootReference: String
  public let ruleIDs: [String]
  public let summary: String
  public let notes: [String]

  public init(
    diagnosticReference: String,
    diagnosticKind: ASHDiagnosticKind,
    severity: ASHDiagnosticSeverity,
    stage: ASHDiagnosticStage,
    disposition: ASHDiagnosticDisposition,
    subjectReference: String,
    parentDiagnosticReference: String?,
    chainRootReference: String,
    ruleIDs: [String],
    summary: String,
    notes: [String]
  ) {
    self.diagnosticReference = diagnosticReference
    self.diagnosticKind = diagnosticKind
    self.severity = severity
    self.stage = stage
    self.disposition = disposition
    self.subjectReference = subjectReference
    self.parentDiagnosticReference = parentDiagnosticReference
    self.chainRootReference = chainRootReference
    self.ruleIDs = ruleIDs
    self.summary = summary
    self.notes = notes
  }
}

public struct ASHDiagnosticValidationIssue: Codable, Hashable, Sendable {
  public let code: String
  public let summary: String
  public let ruleIDs: [String]
  public let notes: [String]

  public init(
    code: String,
    summary: String,
    ruleIDs: [String],
    notes: [String]
  ) {
    self.code = code
    self.summary = summary
    self.ruleIDs = ruleIDs
    self.notes = notes
  }
}

public struct ASHDiagnosticValidationResult: Sendable {
  public let envelope: ASHDiagnosticEnvelope?
  public let issues: [ASHDiagnosticValidationIssue]

  public init(
    envelope: ASHDiagnosticEnvelope?,
    issues: [ASHDiagnosticValidationIssue]
  ) {
    self.envelope = envelope
    self.issues = issues
  }

  public var isValid: Bool {
    issues.isEmpty
  }
}

public struct ASHDiagnosticChainValidationResult: Sendable {
  public let validatedChain: [ASHDiagnosticEnvelope]
  public let issues: [ASHDiagnosticValidationIssue]
  public let metaDiagnostics: [ASHDiagnosticEnvelope]

  public init(
    validatedChain: [ASHDiagnosticEnvelope],
    issues: [ASHDiagnosticValidationIssue],
    metaDiagnostics: [ASHDiagnosticEnvelope]
  ) {
    self.validatedChain = validatedChain
    self.issues = issues
    self.metaDiagnostics = metaDiagnostics
  }

  public var isValid: Bool {
    issues.isEmpty
  }
}
