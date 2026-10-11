import Foundation
import XCTest
@testable import ASHCore

final class ASHDiagnosticJSONTests: XCTestCase {
  private func parse(_ text: String) throws -> ASHDiagnosticValue {
    try ASHDiagnosticValue.parseCanonicalJSON(Data(text.utf8))
  }

  func testScalarDistinctUnicodeKeysRemainDistinct() throws {
    let value = try parse(#"{"\u00e9":1,"e\u0301":2}"#)
    guard case .object(let object) = value else { return XCTFail("Expected object") }
    XCTAssertEqual(object.fields.count, 2)
    XCTAssertEqual(object.fields.map { Array($0.key.unicodeScalars.map(\.value)) }, [[101, 769], [233]])
    XCTAssertEqual(object["\u{00e9}"], .integer(1))
    XCTAssertEqual(object["e\u{0301}"], .integer(2))
    XCTAssertFalse(object.hasDuplicateKeys)
    XCTAssertEqual(try ASHDiagnosticValue.parseCanonicalJSON(value.canonicalJSONData), value)
    XCTAssertEqual(Array(value.canonicalJSONString.utf8), Array("{\"e\u{0301}\":2,\"\u{00e9}\":1}".utf8))
  }

  func testEscapedAndLiteralDuplicateKeysAreRejected() {
    for text in [#"{"a":1,"a":2}"#, #"{"a":1,"\u0061":2}"#,
      #"{"é":1,"\u00e9":2}"#, #"{"nested":{"x":true,"x":false}}"#] {
      XCTAssertThrowsError(try parse(text), text)
    }
  }

  func testControlAndSupplementaryCharactersPreserveExactScalars() throws {
    let value = try parse(#""\u0000\b\f\n\r\t\"\\\/\ud83d\ude80éе́""#)
    guard case .string(let string) = value else { return XCTFail("Expected string") }
    XCTAssertEqual(string.unicodeScalars.map(\.value), [0, 8, 12, 10, 13, 9, 34, 92, 47, 0x1F680, 233, 0x435, 769])
    XCTAssertEqual(try ASHDiagnosticValue.parseCanonicalJSON(value.canonicalJSONData), value)
  }

  func testUnicodeScalarKeyOrderingIncludesSupplementaryPlane() throws {
    let value = try parse(#"{"\ud83d\ude80":4,"\ue000":3,"a":1,"é":2}"#)
    guard case .object(let object) = value else { return XCTFail("Expected object") }
    XCTAssertEqual(object.fields.map { $0.key.unicodeScalars.first!.value }, [97, 233, 0xE000, 0x1F680])
  }

  func testByteOrderMarkWithinStringAndKeyIsPreserved() throws {
    for input in [#""\ufeff""#, "\"\u{FEFF}\""] {
      guard case .string(let string) = try parse(input) else { return XCTFail("Expected string") }
      XCTAssertEqual(string.unicodeScalars.map(\.value), [0xFEFF])
    }
    let value = try parse(#"{"":0,"\ufeff":1}"#)
    guard case .object(let object) = value else { return XCTFail("Expected object") }
    XCTAssertEqual(object.fields.count, 2)
    XCTAssertEqual(object[""], .integer(0))
    XCTAssertEqual(object["\u{FEFF}"], .integer(1))
    XCTAssertEqual(try ASHDiagnosticValue.parseCanonicalJSON(value.canonicalJSONData), value)
  }

  func testInvalidUTF8SurrogatesAndEscapesAreRejected() {
    for bytes: [UInt8] in [[0x22, 0xC0, 0xAF, 0x22], [0x22, 0xED, 0xA0, 0x80, 0x22], [0xFF]] {
      XCTAssertThrowsError(try ASHDiagnosticValue.parseCanonicalJSON(Data(bytes)))
    }
    for text in [#""\ud800""#, #""\udc00""#, #""\ud800\u0041""#,
      #""\ud800\ud800""#, #""\u00x0""#, #""\q""#, "\"unescaped\ncontrol\""] {
      XCTAssertThrowsError(try parse(text), text)
    }
  }

  func testIntegerLimitsAndBooleanValuesStayTyped() throws {
    XCTAssertEqual(try parse("9223372036854775807"), .integer(Int64.max))
    XCTAssertEqual(try parse("-9223372036854775808"), .integer(Int64.min))
    XCTAssertEqual(try parse("-0"), .integer(0))
    XCTAssertEqual(try parse("[null,true,false,0,1]"), .array([.null, .bool(true), .bool(false), .integer(0), .integer(1)]))
    for text in ["9223372036854775808", "-9223372036854775809", "1.0", "1e0", "1E+2", "01", "-00", "+1", "-"] {
      XCTAssertThrowsError(try parse(text), text)
    }
  }

  func testJSONWhitespaceAndNestedEmptyContainers() throws {
    XCTAssertEqual(try parse(" \t\r\n{\"a\" : [ {}, [] ]}\r\n "),
      .object(["a": .array([.object([:]), .array([])])]))
    XCTAssertThrowsError(try parse("\u{00A0}null"))
    XCTAssertThrowsError(try parse("\u{FEFF}null"))
  }

  func testMalformedStructuresAndTrailingInputAreRejected() {
    for text in ["", " ", "[", "{", "[1,]", "[,1]", "{\"a\":1,}", "{a:1}",
      "{\"a\" 1}", "null true", "truex", "null\u{0000}", "[1 2]", "\"unterminated"] {
      XCTAssertThrowsError(try parse(text), text)
    }
  }

  func testDepthAndByteLimitsAreEnforcedAtExactBoundary() throws {
    let atLimit = String(repeating: "[", count: 64) + "0" + String(repeating: "]", count: 64)
    XCTAssertNoThrow(try parse(atLimit))
    let overLimit = "[" + atLimit + "]"
    XCTAssertThrowsError(try parse(overLimit)) { XCTAssertEqual($0 as? ASHDiagnosticJSONError, .depthExceeded) }
    XCTAssertNoThrow(try ASHDiagnosticValue.parseCanonicalJSON(Data("[]".utf8), maximumBytes: 2, maximumDepth: 1))
    XCTAssertThrowsError(try ASHDiagnosticValue.parseCanonicalJSON(Data("[[]]".utf8), maximumDepth: 1))
    XCTAssertThrowsError(try ASHDiagnosticValue.parseCanonicalJSON(Data("[]".utf8), maximumBytes: 1)) {
      XCTAssertEqual($0 as? ASHDiagnosticJSONError, .inputTooLarge)
    }
    XCTAssertThrowsError(try ASHDiagnosticValue.parseCanonicalJSON(Data(repeating: 0x20, count: 1_048_577))) {
      XCTAssertEqual($0 as? ASHDiagnosticJSONError, .inputTooLarge)
    }
    XCTAssertThrowsError(try ASHDiagnosticValue.parseCanonicalJSON(Data("0".utf8), maximumBytes: 0))
    XCTAssertThrowsError(try ASHDiagnosticValue.parseCanonicalJSON(Data("0".utf8), maximumDepth: 0))
  }

  private func envelope() -> ASHDiagnosticEnvelope {
    ASHDiagnosticEnvelope.canonical(kind: .inputValidation, stage: .parse,
      subject: "APS-UNICODE-STRICT", ruleIDs: ["ASH-DIAGNOSTIC-001"],
      summary: "Unicode evidence retained", notes: ["Both Unicode spellings were recorded exactly."],
      details: ASHDiagnosticObject(fields: [
        .init(key: "é", value: .integer(1)), .init(key: "e\u{0301}", value: .integer(2)),
        .init(key: "control", value: .string("\u{0000}\n🚀"))]))
  }

  func testStrictEnvelopeRoundTripPreservesUnicodeDetailsAndIdentity() throws {
    let original = envelope()
    let decoded = try ASHDiagnosticEnvelope.decodeCanonicalJSON(original.canonicalJSONData)
    XCTAssertEqual(decoded, original)
    XCTAssertEqual(decoded.details.fields.count, 3)
    XCTAssertEqual(decoded.diagnosticReference, decoded.expectedDiagnosticReference)
    XCTAssertEqual(decoded.canonicalJSONData, original.canonicalJSONData)
  }

  func testStrictEnvelopeRequiresAllFifteenFieldsIncludingNullableFields() {
    let original = envelope().canonicalRecord
    for missing in ["parent_diagnostic_id", "occurrence_metadata", "details", "notes"] {
      let changed = ASHDiagnosticObject(fields: original.fields.filter { $0.key != missing })
      XCTAssertThrowsError(try ASHDiagnosticEnvelope.decodeCanonicalJSON(Data(changed.canonicalJSONString.utf8)))
    }
    let extra = ASHDiagnosticObject(fields: original.fields + [.init(key: "extra", value: .null)])
    XCTAssertThrowsError(try ASHDiagnosticEnvelope.decodeCanonicalJSON(Data(extra.canonicalJSONString.utf8)))
  }

  func testStrictEnvelopeRejectsWrongTypesVocabularyAndStaleIdentity() {
    let original = envelope().canonicalRecord
    let mutations: [(String, ASHDiagnosticValue)] = [
      ("sequence_number", .bool(true)), ("details", .array([])),
      ("occurrence_metadata", .string("invalid")), ("parent_diagnostic_id", .integer(1)),
      ("notes", .array([.integer(1)])), ("rule_ids", .array([.bool(true)])),
      ("stage", .string("UNKNOWN")), ("summary", .string("Changed semantic content")),
      ("schema_version", .string("2.0")), ("notes", .array([.string(" \n\t")]))]
    for (key, value) in mutations {
      let changed = ASHDiagnosticObject(fields: original.fields.map {
        $0.key == key ? ASHDiagnosticField(key: key, value: value) : $0
      })
      XCTAssertThrowsError(try ASHDiagnosticEnvelope.decodeCanonicalJSON(Data(changed.canonicalJSONString.utf8)), key)
    }
  }
}
