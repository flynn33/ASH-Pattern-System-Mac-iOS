import Foundation

/// Stateless validation of canonical records and their ordered causal occurrences.
public final class ASHDiagnosticsModule: ASHDiagnosticsModuleProtocol {
  public init() {}

  public func validateEnvelope(_ envelope: ASHDiagnosticEnvelope) -> ASHDiagnosticValidationResult {
    var issues: [ASHDiagnosticValidationIssue] = []
    func reject(_ code: String, _ summary: String, _ note: String) {
      issues.append(makeIssue(code: code, summary: summary, notes: [note]))
    }
    if envelope.schemaVersion != "1.0" {
      reject("DIAG-SCHEMA-VERSION", "Unsupported diagnostic schema version.", "schema_version must be 1.0.")
    }
    if !isDiagnosticID(envelope.diagnosticReference) {
      reject("DIAG-MISSING-REFERENCE", "Diagnostic identity must use the canonical SHA-256 format.", "Expected APS-DIAG- followed by 24 uppercase hexadecimal characters.")
    }
    if envelope.diagnosticReference != envelope.expectedDiagnosticReference {
      reject("DIAG-STALE-IDENTITY", "Diagnostic identity does not match its semantic payload.", "Identity covers nine semantic fields; occurrence and chain placement are excluded.")
    }
    if isBlank(envelope.subjectReference) {
      reject("DIAG-MISSING-SUBJECT", "Diagnostic subject must be meaningful.", "subject_reference was empty or whitespace-only.")
    }
    if !isDiagnosticID(envelope.chainRootReference) {
      reject("DIAG-MISSING-ROOT", "Diagnostic chain root must use a canonical identity.", "chain_root_diagnostic_id was missing or malformed.")
    }
    if let parent = envelope.parentDiagnosticReference, !isDiagnosticID(parent) {
      reject("DIAG-MISSING-PARENT", "Diagnostic parent identity is malformed.", "parent_diagnostic_id must be null or a canonical identity.")
    }
    if envelope.sequenceNumber < 1 {
      reject("DIAG-SEQUENCE", "Diagnostic sequence must be positive.", "sequence_number must be an integer greater than or equal to 1.")
    }
    if envelope.ruleIDs.isEmpty {
      reject("DIAG-MISSING-RULE-IDS", "Diagnostics require at least one rule ID.", "rule_ids was empty.")
    }
    for rule in envelope.ruleIDs where !isValidRuleID(rule) {
      reject("DIAG-INVALID-RULE-ID", "Rule ID does not conform to canonical taxonomy.", "Rejected rule ID: \(rule).")
    }
    if isBlank(envelope.summary) {
      reject("DIAG-MISSING-SUMMARY", "Diagnostic summary must be meaningful.", "summary was empty or whitespace-only.")
    }
    if envelope.summary.contains("\r") || envelope.summary.contains("\n") {
      reject("DIAG-MULTILINE-SUMMARY", "Diagnostic summary must be one line.", "summary contained a carriage return or newline.")
    }
    if envelope.notes.isEmpty || envelope.notes.contains(where: isBlank) {
      reject("DIAG-MISSING-NOTES", "Every diagnostic note must be meaningful.", "notes must contain at least one nonblank explanatory entry and no blank entries.")
    }
    if !envelope.details.isPortable || envelope.occurrenceMetadata?.isPortable == false {
      reject("DIAG-JSON-VALUE", "Diagnostic objects must have distinct scalar keys and portable values.", "Duplicate object keys are not valid canonical JSON.")
    }
    return ASHDiagnosticValidationResult(envelope: issues.isEmpty ? envelope : nil, issues: issues)
  }

  public func validateChain(_ chain: [ASHDiagnosticEnvelope]) -> ASHDiagnosticChainValidationResult {
    var issues: [ASHDiagnosticValidationIssue] = []
    func reject(_ code: String, _ summary: String, _ notes: [String]) {
      issues.append(makeIssue(code: code, summary: summary, notes: notes))
    }
    guard let root = chain.first else {
      let issue = makeIssue(code: "DIAG-EMPTY-CHAIN", summary: "Diagnostic chain cannot be empty.", notes: ["No records were supplied."])
      return ASHDiagnosticChainValidationResult(validatedChain: [], issues: [issue], metaDiagnostics: [makeMetaDiagnostic(issue)])
    }
    if root.parentDiagnosticReference != nil || root.sequenceNumber != 1 {
      reject("DIAG-INVALID-ROOT", "The first diagnostic must be the root occurrence.", ["Root requires null parent and sequence 1."])
    }
    var previousPhase: Int?
    var occurrences: [String: Set<Int>] = [:]
    for (index, record) in chain.enumerated() {
      issues.append(contentsOf: validateEnvelope(record).issues)
      if occurrences[record.diagnosticReference, default: []].contains(record.sequenceNumber) {
        reject("DIAG-DUPLICATE-REFERENCE", "Duplicate diagnostic occurrence.", ["Identity and sequence pair repeats at index \(index)."])
      }
      occurrences[record.diagnosticReference, default: []].insert(record.sequenceNumber)
      if record.chainRootReference != root.diagnosticReference {
        reject("DIAG-INCONSISTENT-ROOT", "All occurrences must reference the first diagnostic as root.", ["Invalid root at index \(index)."])
      }
      if record.sequenceNumber != index + 1 {
        reject("DIAG-SEQUENCE", "Diagnostic occurrences must be consecutive and ordered.", ["Expected sequence \(index + 1) at index \(index); observed \(record.sequenceNumber)."])
      }
      let phase = record.stage.safetyPhase
      if index > 0 {
        let parent = chain[index - 1]
        if record.parentDiagnosticReference != parent.diagnosticReference {
          reject("DIAG-MISSING-PARENT", "A child must reference its immediate predecessor.", ["Invalid parent at index \(index); orphan, cycle or multiple root detected."])
        }
        if record.severity.rank < parent.severity.rank {
          reject("DIAG-SEVERITY-REGRESSION", "Severity cannot decrease within a causal chain.", ["Severity decreased at index \(index)."])
        }
        if parent.stage == .terminal || parent.stage == .halt || parent.diagnosticKind == .safeHalt || parent.disposition == .terminal {
          reject("DIAG-TERMINAL-CHILD", "Terminal diagnostics forbid further occurrences.", ["Child at index \(index) follows a terminal parent."])
        }
        if phase == nil, let previousPhase, previousPhase >= 3 {
          reject("DIAG-OPERATION-AFTER-CONTAINMENT", "Ordinary operations are forbidden after containment.", ["Operation stage \(record.stage.rawValue) at index \(index)."])
        }
        if let phase, let previousPhase, phase < previousPhase {
          reject("DIAG-STAGE-REGRESSION", "Safety phases cannot move backwards.", ["Phase decreased at index \(index)."])
        }
        if phase == 3 && previousPhase != 3 && previousPhase != 1 && previousPhase != 2 {
          reject("DIAG-CONTAINMENT-PRECONDITION", "Containment requires preceding assessment or recovery.", ["Invalid containment entry at index \(index)."])
        }
        if phase == 3 && previousPhase == 3 && record.diagnosticKind != .containment {
          reject("DIAG-CONTAINMENT-KIND", "Containment management requires CONTAINMENT kind.", ["Invalid same-phase management at index \(index)."])
        }
        if phase == 4 && previousPhase != 2 && previousPhase != 3 {
          reject("DIAG-HALT-PRECONDITION", "Halt requires preceding recovery or containment.", ["Invalid terminal entry at index \(index)."])
        }
      }
      if let phase { previousPhase = phase }
    }
    return ASHDiagnosticChainValidationResult(validatedChain: issues.isEmpty ? chain : [], issues: issues, metaDiagnostics: issues.map(makeMetaDiagnostic))
  }

  /// Omission reports are standalone validation records, outside the preserved input chain.
  public func detectOmissions(expectedDiagnosticReferences: [String], actualChain: [ASHDiagnosticEnvelope], chainRootReference: String) -> ASHDiagnosticEnvelope? {
    let actual = Set(actualChain.map(\.diagnosticReference))
    let missing = Set(expectedDiagnosticReferences.filter { !actual.contains($0) }).sorted()
    guard !missing.isEmpty else { return nil }
    return .canonical(kind: .schemaValidation, severity: .error, stage: .validate, disposition: .blocked,
      subject: "diagnostic-chain", ruleIDs: ["ASH-DIAGNOSTIC-001"], summary: "Diagnostic chain omission detected.",
      notes: ["Expected occurrences are missing; the original chain was preserved."],
      details: ["missing": .array(missing.map(ASHDiagnosticValue.string)), "reported_chain_root": .string(chainRootReference)])
  }

  private func makeIssue(code: String, summary: String, notes: [String]) -> ASHDiagnosticValidationIssue {
    .init(code: code, summary: summary, ruleIDs: ["ASH-DIAGNOSTIC-001"], notes: notes)
  }
  private func makeMetaDiagnostic(_ issue: ASHDiagnosticValidationIssue) -> ASHDiagnosticEnvelope {
    .canonical(kind: .schemaValidation, severity: .error, stage: .validate, disposition: .blocked,
      subject: "diagnostic-chain", ruleIDs: issue.ruleIDs, summary: issue.summary, notes: issue.notes,
      details: ["validation_code": .string(issue.code)])
  }
  private func isDiagnosticID(_ value: String) -> Bool {
    let bytes = Array(value.utf8)
    return bytes.count == 33 && bytes.prefix(9).elementsEqual("APS-DIAG-".utf8) && bytes.dropFirst(9).allSatisfy { (48...57).contains($0) || (65...70).contains($0) }
  }
  private func isValidRuleID(_ value: String) -> Bool {
    let pattern = #"^ASH-(?:INPUT|STATE|CODEWORD|ORBIT|REALM|TRANSITION|TOPOLOGY|AXIOM|CLASSIFICATION|RECOVERY|FALLBACK|CONTAINMENT|HALT|GENERATION|EMISSION|DIAGNOSTIC|CONFORMANCE|RELEASE|SECURITY|ADMISSIBILITY)(?:-[A-Z]+)*-[0-9]{3}$"#
    guard let range = value.range(of: pattern, options: .regularExpression) else { return false }
    return range.lowerBound == value.startIndex && range.upperBound == value.endIndex
  }
  private func isBlank(_ value: String) -> Bool {
    value.unicodeScalars.allSatisfy { scalar in
      let c = scalar.value
      return (9...13).contains(c) || (28...32).contains(c) || c == 0x85 || c == 0xA0 || c == 0x1680 || (0x2000...0x200A).contains(c) || c == 0x2028 || c == 0x2029 || c == 0x202F || c == 0x205F || c == 0x3000
    }
  }
}
