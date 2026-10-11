import Foundation
import CryptoKit

public enum ASHDiagnosticKind: String, Codable, Sendable {
  case inputValidation = "INPUT_VALIDATION"
  case stateAssessment = "STATE_ASSESSMENT"
  case classification = "CLASSIFICATION"
  case transition = "TRANSITION"
  case topology = "TOPOLOGY"
  case axiom = "AXIOM"
  case generationPlan = "GENERATION_PLAN"
  case emission = "EMISSION"
  case recovery = "RECOVERY"
  case fallback = "FALLBACK"
  case containment = "CONTAINMENT"
  case safeHalt = "SAFE_HALT"
  case schemaValidation = "SCHEMA_VALIDATION"
  case conformance = "CONFORMANCE"
  case stateValidity = "STATE_VALIDITY"
  public static var planning: Self { .generationPlan }
  public static var meta: Self { .schemaValidation }
}

public enum ASHDiagnosticSeverity: String, Codable, Sendable {
  case info = "INFO", warning = "WARNING", error = "ERROR", critical = "CRITICAL"
  public var rank: Int {
    switch self { case .info: return 0; case .warning: return 1; case .error: return 2; case .critical: return 3 }
  }
}

public enum ASHDiagnosticStage: String, Codable, Sendable {
  case detection = "DETECTION", parse = "PARSE"
  case classification = "CLASSIFICATION", assess = "ASSESS", classify = "CLASSIFY"
  case recovery = "RECOVERY", recover = "RECOVER", fallback = "FALLBACK"
  case escalation = "ESCALATION", contain = "CONTAIN"
  case terminal = "TERMINAL", halt = "HALT"
  case transform = "TRANSFORM", plan = "PLAN", evaluate = "EVALUATE"
  case emit = "EMIT", validate = "VALIDATE", verify = "VERIFY"
  public var safetyPhase: Int? {
    switch self {
    case .detection, .parse: return 0
    case .classification, .assess, .classify: return 1
    case .recovery, .recover, .fallback: return 2
    case .escalation, .contain: return 3
    case .terminal, .halt: return 4
    case .transform, .plan, .evaluate, .emit, .validate, .verify: return nil
    }
  }
}

public enum ASHDiagnosticDisposition: String, Codable, Sendable {
  case recorded = "RECORDED", resolved = "RESOLVED", pending = "PENDING"
  case blocked = "BLOCKED", escalated = "ESCALATED", terminal = "TERMINAL"
}

public struct ASHDiagnosticField: Hashable, Sendable {
  public let key: String
  public let value: ASHDiagnosticValue
  public init(key: String, value: ASHDiagnosticValue) { self.key = key; self.value = value }
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.key.utf8.elementsEqual(rhs.key.utf8) && lhs.value == rhs.value
  }
  public func hash(into hasher: inout Hasher) { hasher.combine(Array(key.utf8)); hasher.combine(value) }
}

/// Objects preserve distinct Unicode scalar keys, including canonically equivalent spellings.
public struct ASHDiagnosticObject: Codable, Hashable, Sendable, ExpressibleByDictionaryLiteral {
  public let fields: [ASHDiagnosticField]
  public init(fields: [ASHDiagnosticField]) {
    self.fields = fields.sorted {
      $0.key.unicodeScalars.lexicographicallyPrecedes($1.key.unicodeScalars)
    }
  }
  public init(_ values: [String: ASHDiagnosticValue]) {
    self.init(fields: values.map { ASHDiagnosticField(key: $0.key, value: $0.value) })
  }
  public init(dictionaryLiteral elements: (String, ASHDiagnosticValue)...) {
    self.init(fields: elements.map { ASHDiagnosticField(key: $0.0, value: $0.1) })
  }
  public subscript(_ key: String) -> ASHDiagnosticValue? {
    fields.first { $0.key.utf8.elementsEqual(key.utf8) }?.value
  }
  public var hasDuplicateKeys: Bool {
    Set(fields.map { Array($0.key.utf8) }).count != fields.count
  }
  public var isPortable: Bool { !hasDuplicateKeys && fields.allSatisfy { $0.value.isPortable } }
  public var canonicalJSONString: String {
    "{" + fields.map { ASHDiagnosticValue.quote($0.key) + ":" + $0.value.canonicalJSONString }.joined(separator: ",") + "}"
  }
  struct CodingObjectKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingObjectKey.self)
    self.init(fields: try c.allKeys.map { ASHDiagnosticField(key: $0.stringValue, value: try c.decode(ASHDiagnosticValue.self, forKey: $0)) })
  }
  public func encode(to encoder: Encoder) throws {
    // Foundation's keyed encoder folds Unicode-equivalent keys. Reject that route;
    // canonicalJSONData encodes them without normalization or loss.
    guard isPortable, Set(fields.map(\.key)).count == fields.count else {
      throw EncodingError.invalidValue(self, .init(codingPath: encoder.codingPath, debugDescription: "Use canonicalJSONData for scalar-distinct object keys; duplicate keys are invalid."))
    }
    var c = encoder.container(keyedBy: CodingObjectKey.self)
    for field in fields { try c.encode(field.value, forKey: CodingObjectKey(stringValue: field.key)) }
  }
}

public indirect enum ASHDiagnosticValue: Codable, Hashable, Sendable {
  case null, bool(Bool), integer(Int64), string(String), array([ASHDiagnosticValue]), object(ASHDiagnosticObject)
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.null, .null): return true
    case (.bool(let a), .bool(let b)): return a == b
    case (.integer(let a), .integer(let b)): return a == b
    case (.string(let a), .string(let b)): return a.utf8.elementsEqual(b.utf8)
    case (.array(let a), .array(let b)): return a == b
    case (.object(let a), .object(let b)): return a == b
    default: return false
    }
  }
  public func hash(into hasher: inout Hasher) {
    switch self {
    case .null: hasher.combine(0)
    case .bool(let v): hasher.combine(1); hasher.combine(v)
    case .integer(let v): hasher.combine(2); hasher.combine(v)
    case .string(let v): hasher.combine(3); hasher.combine(Array(v.utf8))
    case .array(let v): hasher.combine(4); hasher.combine(v)
    case .object(let v): hasher.combine(5); hasher.combine(v)
    }
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() { self = .null }
    else if let value = try? c.decode(Bool.self) { self = .bool(value) }
    else if let value = try? c.decode(Int64.self) { self = .integer(value) }
    else if let value = try? c.decode(String.self) { self = .string(value) }
    else if let value = try? c.decode([ASHDiagnosticValue].self) { self = .array(value) }
    else if let value = try? c.decode(ASHDiagnosticObject.self) { self = .object(value) }
    else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Diagnostic JSON supports null, Boolean, Int64, string, array and object values only.") }
  }
  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .null: try c.encodeNil()
    case .bool(let v): try c.encode(v)
    case .integer(let v): try c.encode(v)
    case .string(let v): try c.encode(v)
    case .array(let v): try c.encode(v)
    case .object(let v): try c.encode(v)
    }
  }
  public var isPortable: Bool {
    switch self { case .array(let values): return values.allSatisfy(\.isPortable); case .object(let value): return value.isPortable; default: return true }
  }
  public var canonicalJSONString: String {
    switch self {
    case .null: return "null"
    case .bool(let value): return value ? "true" : "false"
    case .integer(let value): return String(value)
    case .string(let value): return Self.quote(value)
    case .array(let values): return "[" + values.map(\.canonicalJSONString).joined(separator: ",") + "]"
    case .object(let value): return value.canonicalJSONString
    }
  }
  public var canonicalJSONData: Data { Data(canonicalJSONString.utf8) }
  static func quote(_ string: String) -> String {
    var result = "\""
    for scalar in string.unicodeScalars {
      switch scalar.value {
      case 0x22: result += "\\\""
      case 0x5C: result += "\\\\"
      case 0x08: result += "\\b"
      case 0x0C: result += "\\f"
      case 0x0A: result += "\\n"
      case 0x0D: result += "\\r"
      case 0x09: result += "\\t"
      case 0..<0x20: result += String(format: "\\u%04x", scalar.value)
      default: result.unicodeScalars.append(scalar)
      }
    }
    return result + "\""
  }
}

public struct ASHDiagnosticEnvelope: Codable, Hashable, Sendable {
  public let schemaVersion: String
  public let diagnosticReference: String
  public let diagnosticKind: ASHDiagnosticKind
  public let severity: ASHDiagnosticSeverity
  public let stage: ASHDiagnosticStage
  public let disposition: ASHDiagnosticDisposition
  public let subjectReference: String
  public let parentDiagnosticReference: String?
  public let chainRootReference: String
  public let sequenceNumber: Int
  public let ruleIDs: [String]
  public let summary: String
  public let notes: [String]
  public let details: ASHDiagnosticObject
  public let occurrenceMetadata: ASHDiagnosticObject?

  /// Raw construction preserves caller values. Validate untrusted records before use.
  public init(diagnosticReference: String, diagnosticKind: ASHDiagnosticKind,
    severity: ASHDiagnosticSeverity, stage: ASHDiagnosticStage, disposition: ASHDiagnosticDisposition,
    subjectReference: String, parentDiagnosticReference: String?, chainRootReference: String,
    ruleIDs: [String], summary: String, notes: [String], schemaVersion: String = "1.0",
    sequenceNumber: Int = 1, details: ASHDiagnosticObject = [:], occurrenceMetadata: ASHDiagnosticObject? = nil) {
    self.schemaVersion = schemaVersion; self.diagnosticReference = diagnosticReference
    self.diagnosticKind = diagnosticKind; self.severity = severity; self.stage = stage
    self.disposition = disposition; self.subjectReference = subjectReference
    self.parentDiagnosticReference = parentDiagnosticReference; self.chainRootReference = chainRootReference
    self.sequenceNumber = sequenceNumber; self.ruleIDs = ruleIDs; self.summary = summary
    self.notes = notes; self.details = details; self.occurrenceMetadata = occurrenceMetadata
  }

  public static func canonical(kind: ASHDiagnosticKind, severity: ASHDiagnosticSeverity = .info,
    stage: ASHDiagnosticStage, disposition: ASHDiagnosticDisposition = .recorded,
    subject: String, ruleIDs: [String], summary: String, notes: [String],
    details: ASHDiagnosticObject = [:], parent: ASHDiagnosticEnvelope? = nil,
    occurrenceMetadata: ASHDiagnosticObject? = nil) -> Self {
    let semantic: ASHDiagnosticObject = [
      "diagnostic_kind": .string(kind.rawValue), "disposition": .string(disposition.rawValue),
      "rule_ids": .array(ruleIDs.map(ASHDiagnosticValue.string)), "severity": .string(severity.rawValue),
      "stage": .string(stage.rawValue), "subject_reference": .string(subject),
      "summary": .string(summary), "notes": .array(notes.map(ASHDiagnosticValue.string)), "details": .object(details)
    ]
    let id = semanticIdentity(semantic)
    // A malformed raw parent may carry Int.max; preserve a validation failure without overflow.
    let sequence = parent.map { $0.sequenceNumber == Int.max ? 0 : $0.sequenceNumber + 1 } ?? 1
    return Self(diagnosticReference: id, diagnosticKind: kind, severity: severity, stage: stage,
      disposition: disposition, subjectReference: subject, parentDiagnosticReference: parent?.diagnosticReference,
      chainRootReference: parent?.chainRootReference ?? id, ruleIDs: ruleIDs, summary: summary,
      notes: notes, sequenceNumber: sequence, details: details, occurrenceMetadata: occurrenceMetadata)
  }
  static func semanticIdentity(_ semantic: ASHDiagnosticObject) -> String {
    "APS-DIAG-" + SHA256.hash(data: Data(semantic.canonicalJSONString.utf8)).prefix(12).map { String(format: "%02X", $0) }.joined()
  }
  public var semanticPayload: ASHDiagnosticObject {
    ["diagnostic_kind": .string(diagnosticKind.rawValue), "disposition": .string(disposition.rawValue),
     "rule_ids": .array(ruleIDs.map(ASHDiagnosticValue.string)), "severity": .string(severity.rawValue),
     "stage": .string(stage.rawValue), "subject_reference": .string(subjectReference),
     "summary": .string(summary), "notes": .array(notes.map(ASHDiagnosticValue.string)), "details": .object(details)]
  }
  public var expectedDiagnosticReference: String { Self.semanticIdentity(semanticPayload) }
  public var canonicalRecord: ASHDiagnosticObject {
    ASHDiagnosticObject(fields: semanticPayload.fields + [
      .init(key: "schema_version", value: .string(schemaVersion)),
      .init(key: "diagnostic_id", value: .string(diagnosticReference)),
      .init(key: "parent_diagnostic_id", value: parentDiagnosticReference.map(ASHDiagnosticValue.string) ?? .null),
      .init(key: "chain_root_diagnostic_id", value: .string(chainRootReference)),
      .init(key: "sequence_number", value: .integer(Int64(sequenceNumber))),
      .init(key: "occurrence_metadata", value: occurrenceMetadata.map(ASHDiagnosticValue.object) ?? .null)
    ])
  }
  public var canonicalJSONData: Data { Data(canonicalRecord.canonicalJSONString.utf8) }

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version", diagnosticReference = "diagnostic_id", diagnosticKind = "diagnostic_kind"
    case severity, stage, disposition, subjectReference = "subject_reference"
    case parentDiagnosticReference = "parent_diagnostic_id", chainRootReference = "chain_root_diagnostic_id"
    case sequenceNumber = "sequence_number", ruleIDs = "rule_ids", summary, notes, details
    case occurrenceMetadata = "occurrence_metadata"
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    // Required nullable fields are decoded explicitly; missing is different from null.
    let parent = try c.decode(String?.self, forKey: .parentDiagnosticReference)
    let occurrence = try c.decode(ASHDiagnosticObject?.self, forKey: .occurrenceMetadata)
    self.init(diagnosticReference: try c.decode(String.self, forKey: .diagnosticReference),
      diagnosticKind: try c.decode(ASHDiagnosticKind.self, forKey: .diagnosticKind),
      severity: try c.decode(ASHDiagnosticSeverity.self, forKey: .severity),
      stage: try c.decode(ASHDiagnosticStage.self, forKey: .stage),
      disposition: try c.decode(ASHDiagnosticDisposition.self, forKey: .disposition),
      subjectReference: try c.decode(String.self, forKey: .subjectReference),
      parentDiagnosticReference: parent, chainRootReference: try c.decode(String.self, forKey: .chainRootReference),
      ruleIDs: try c.decode([String].self, forKey: .ruleIDs), summary: try c.decode(String.self, forKey: .summary),
      notes: try c.decode([String].self, forKey: .notes), schemaVersion: try c.decode(String.self, forKey: .schemaVersion),
      sequenceNumber: try c.decode(Int.self, forKey: .sequenceNumber),
      details: try c.decode(ASHDiagnosticObject.self, forKey: .details), occurrenceMetadata: occurrence)
  }
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(schemaVersion, forKey: .schemaVersion); try c.encode(diagnosticReference, forKey: .diagnosticReference)
    try c.encode(diagnosticKind, forKey: .diagnosticKind); try c.encode(severity, forKey: .severity)
    try c.encode(stage, forKey: .stage); try c.encode(disposition, forKey: .disposition)
    try c.encode(subjectReference, forKey: .subjectReference); try c.encode(parentDiagnosticReference, forKey: .parentDiagnosticReference)
    try c.encode(chainRootReference, forKey: .chainRootReference); try c.encode(sequenceNumber, forKey: .sequenceNumber)
    try c.encode(ruleIDs, forKey: .ruleIDs); try c.encode(summary, forKey: .summary); try c.encode(notes, forKey: .notes)
    try c.encode(details, forKey: .details); try c.encode(occurrenceMetadata, forKey: .occurrenceMetadata)
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
