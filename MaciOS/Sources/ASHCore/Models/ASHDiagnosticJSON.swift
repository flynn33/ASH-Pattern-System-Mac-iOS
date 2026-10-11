import Foundation

public enum ASHDiagnosticJSONError: Error, Equatable, Sendable {
  case invalid(String)
  case inputTooLarge
  case depthExceeded
}

public extension ASHDiagnosticValue {
  /// Strict UTF-8 JSON with integer-only numbers and byte-exact object keys.
  /// Defaults bound one input to 1 MiB and 64 nested containers.
  static func parseCanonicalJSON(_ data: Data, maximumBytes: Int = 1_048_576,
    maximumDepth: Int = 64) throws -> Self {
    guard maximumBytes > 0, maximumDepth > 0 else {
      throw ASHDiagnosticJSONError.invalid("JSON bounds must be positive")
    }
    guard data.count <= maximumBytes else { throw ASHDiagnosticJSONError.inputTooLarge }
    guard String(data: data, encoding: .utf8) != nil else {
      throw ASHDiagnosticJSONError.invalid("Input is not valid UTF-8")
    }
    var parser = ASHDiagnosticJSONParser(bytes: Array(data), maximumDepth: maximumDepth)
    return try parser.parse()
  }
}

private struct ASHDiagnosticJSONParser {
  let bytes: [UInt8]
  let maximumDepth: Int
  var index = 0

  mutating func parse() throws -> ASHDiagnosticValue {
    let result = try value(depth: 0)
    whitespace()
    guard index == bytes.count else { throw invalid("Trailing input") }
    return result
  }

  func invalid(_ message: String) -> ASHDiagnosticJSONError {
    .invalid("\(message) at byte \(index)")
  }

  var next: UInt8? { index < bytes.count ? bytes[index] : nil }

  mutating func whitespace() {
    while let byte = next, byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
      index += 1
    }
  }

  mutating func consume(_ byte: UInt8) -> Bool {
    guard next == byte else { return false }
    index += 1
    return true
  }

  mutating func literal(_ text: String, value: ASHDiagnosticValue) throws -> ASHDiagnosticValue {
    for byte in text.utf8 {
      guard consume(byte) else { throw invalid("Invalid JSON literal") }
    }
    return value
  }

  mutating func value(depth: Int) throws -> ASHDiagnosticValue {
    whitespace()
    guard let byte = next else { throw invalid("Expected JSON value") }
    switch byte {
    case 0x22: return .string(try string())
    case 0x6E: return try literal("null", value: .null)
    case 0x74: return try literal("true", value: .bool(true))
    case 0x66: return try literal("false", value: .bool(false))
    case 0x5B:
      guard depth < maximumDepth else { throw ASHDiagnosticJSONError.depthExceeded }
      return try array(depth: depth + 1)
    case 0x7B:
      guard depth < maximumDepth else { throw ASHDiagnosticJSONError.depthExceeded }
      return try object(depth: depth + 1)
    case 0x2D, 0x30...0x39: return try integer()
    default: throw invalid("Expected JSON value")
    }
  }

  mutating func array(depth: Int) throws -> ASHDiagnosticValue {
    index += 1
    whitespace()
    var values: [ASHDiagnosticValue] = []
    if consume(0x5D) { return .array(values) }
    while true {
      values.append(try value(depth: depth))
      whitespace()
      if consume(0x5D) { return .array(values) }
      guard consume(0x2C) else { throw invalid("Expected array comma or closing bracket") }
    }
  }

  mutating func object(depth: Int) throws -> ASHDiagnosticValue {
    index += 1
    whitespace()
    var fields: [ASHDiagnosticField] = []
    var keys: Set<Data> = []
    if consume(0x7D) { return .object(ASHDiagnosticObject(fields: fields)) }
    while true {
      whitespace()
      let key = try string()
      guard keys.insert(Data(key.utf8)).inserted else { throw invalid("Duplicate object key") }
      whitespace()
      guard consume(0x3A) else { throw invalid("Expected object colon") }
      fields.append(ASHDiagnosticField(key: key, value: try value(depth: depth)))
      whitespace()
      if consume(0x7D) { return .object(ASHDiagnosticObject(fields: fields)) }
      guard consume(0x2C) else { throw invalid("Expected object comma or closing brace") }
    }
  }

  mutating func integer() throws -> ASHDiagnosticValue {
    let start = index
    _ = consume(0x2D)
    if consume(0x30) {
      if let byte = next, (0x30...0x39).contains(byte) { throw invalid("Leading integer zero") }
    } else {
      guard let first = next, (0x31...0x39).contains(first) else { throw invalid("Expected integer digit") }
      index += 1
      while let byte = next, (0x30...0x39).contains(byte) { index += 1 }
    }
    if next == 0x2E || next == 0x65 || next == 0x45 { throw invalid("Non-integer numbers are unsupported") }
    guard let number = Int64(String(decoding: bytes[start..<index], as: UTF8.self)) else {
      throw invalid("Integer is outside Int64 range")
    }
    return .integer(number)
  }

  mutating func hexScalar() throws -> UInt32 {
    var value: UInt32 = 0
    for _ in 0..<4 {
      guard let byte = next else { throw invalid("Incomplete Unicode escape") }
      let digit: UInt32
      switch byte {
      case 0x30...0x39: digit = UInt32(byte - 0x30)
      case 0x41...0x46: digit = UInt32(byte - 0x41 + 10)
      case 0x61...0x66: digit = UInt32(byte - 0x61 + 10)
      default: throw invalid("Invalid Unicode escape")
      }
      index += 1
      value = value * 16 + digit
    }
    return value
  }

  mutating func string() throws -> String {
    guard consume(0x22) else { throw invalid("Expected JSON string") }
    var utf8: [UInt8] = []
    while let byte = next {
      index += 1
      if byte == 0x22 {
        guard String(bytes: utf8, encoding: .utf8) != nil else { throw invalid("Invalid string UTF-8") }
        // Foundation's encoding initializer consumes a leading U+FEFF. Here it is string content.
        return String(decoding: utf8, as: UTF8.self)
      }
      guard byte >= 0x20 else { throw invalid("Unescaped control character") }
      if byte != 0x5C { utf8.append(byte); continue }
      guard let escape = next else { throw invalid("Incomplete string escape") }
      index += 1
      switch escape {
      case 0x22, 0x5C, 0x2F: utf8.append(escape)
      case 0x62: utf8.append(0x08)
      case 0x66: utf8.append(0x0C)
      case 0x6E: utf8.append(0x0A)
      case 0x72: utf8.append(0x0D)
      case 0x74: utf8.append(0x09)
      case 0x75:
        var scalar = try hexScalar()
        if (0xD800...0xDBFF).contains(scalar) {
          guard consume(0x5C), consume(0x75) else { throw invalid("Missing low Unicode surrogate") }
          let low = try hexScalar()
          guard (0xDC00...0xDFFF).contains(low) else { throw invalid("Invalid low Unicode surrogate") }
          scalar = 0x10000 + (scalar - 0xD800) * 0x400 + low - 0xDC00
        } else if (0xDC00...0xDFFF).contains(scalar) {
          throw invalid("Unpaired low Unicode surrogate")
        }
        guard let unicode = Unicode.Scalar(scalar) else { throw invalid("Invalid Unicode scalar") }
        utf8.append(contentsOf: String(unicode).utf8)
      default: throw invalid("Invalid string escape")
      }
    }
    throw invalid("Unterminated string")
  }
}

public extension ASHDiagnosticEnvelope {
  /// Decode and validate one complete canonical record. Chain ordering is checked separately.
  static func decodeCanonicalJSON(_ data: Data, maximumBytes: Int = 1_048_576,
    maximumDepth: Int = 64) throws -> Self {
    guard case .object(let record) = try ASHDiagnosticValue.parseCanonicalJSON(data,
      maximumBytes: maximumBytes, maximumDepth: maximumDepth) else {
      throw ASHDiagnosticJSONError.invalid("Diagnostic record must be an object")
    }
    let required = ["schema_version", "diagnostic_id", "diagnostic_kind", "severity", "stage",
      "disposition", "subject_reference", "parent_diagnostic_id", "chain_root_diagnostic_id",
      "sequence_number", "rule_ids", "summary", "notes", "details", "occurrence_metadata"]
    guard record.fields.count == required.count,
      record.fields.allSatisfy({ field in required.contains { $0.utf8.elementsEqual(field.key.utf8) } }) else {
      throw ASHDiagnosticJSONError.invalid("Diagnostic record requires exactly the fifteen canonical fields")
    }
    func string(_ key: String) throws -> String {
      guard case .string(let value) = record[key] else { throw ASHDiagnosticJSONError.invalid("\(key) must be a string") }
      return value
    }
    func strings(_ key: String) throws -> [String] {
      guard case .array(let values) = record[key] else { throw ASHDiagnosticJSONError.invalid("\(key) must be a string array") }
      return try values.map {
        guard case .string(let value) = $0 else { throw ASHDiagnosticJSONError.invalid("\(key) must contain strings") }
        return value
      }
    }
    let parent: String?
    switch record["parent_diagnostic_id"] {
    case .null: parent = nil
    case .string(let value): parent = value
    default: throw ASHDiagnosticJSONError.invalid("parent_diagnostic_id must be null or a string")
    }
    let occurrence: ASHDiagnosticObject?
    switch record["occurrence_metadata"] {
    case .null: occurrence = nil
    case .object(let value): occurrence = value
    default: throw ASHDiagnosticJSONError.invalid("occurrence_metadata must be null or an object")
    }
    guard case .integer(let sequence) = record["sequence_number"], let sequenceNumber = Int(exactly: sequence),
      case .object(let details) = record["details"],
      let kind = ASHDiagnosticKind(rawValue: try string("diagnostic_kind")),
      let severity = ASHDiagnosticSeverity(rawValue: try string("severity")),
      let stage = ASHDiagnosticStage(rawValue: try string("stage")),
      let disposition = ASHDiagnosticDisposition(rawValue: try string("disposition")) else {
      throw ASHDiagnosticJSONError.invalid("Invalid sequence, details object, or diagnostic vocabulary")
    }
    let envelope = try Self(diagnosticReference: string("diagnostic_id"), diagnosticKind: kind,
      severity: severity, stage: stage, disposition: disposition, subjectReference: string("subject_reference"),
      parentDiagnosticReference: parent, chainRootReference: string("chain_root_diagnostic_id"),
      ruleIDs: strings("rule_ids"), summary: string("summary"), notes: strings("notes"),
      schemaVersion: string("schema_version"), sequenceNumber: sequenceNumber,
      details: details, occurrenceMetadata: occurrence)
    let validation = ASHDiagnosticsModule().validateEnvelope(envelope)
    guard validation.isValid else {
      throw ASHDiagnosticJSONError.invalid("Invalid diagnostic record: " + validation.issues.map(\.code).joined(separator: ", "))
    }
    return envelope
  }
}
