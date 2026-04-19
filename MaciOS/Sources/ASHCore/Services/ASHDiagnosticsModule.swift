import Foundation

public final class ASHDiagnosticsModule: ASHDiagnosticsModuleProtocol {
  private let ruleIDPattern = try! NSRegularExpression(
    pattern: #"^ASH-(STATE|CODEWORD|ADMISSIBILITY|CLASSIFICATION|RECOVERY|FALLBACK|CONTAINMENT|HALT)-[A-Z0-9_]+-[0-9]{3}$"#
  )

  public init() {}

  public func validateEnvelope(_ envelope: ASHDiagnosticEnvelope) -> ASHDiagnosticValidationResult {
    var issues: [ASHDiagnosticValidationIssue] = []

    if envelope.diagnosticReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      issues.append(
        makeIssue(
          code: "DIAG-MISSING-REFERENCE",
          summary: "Diagnostic reference must be populated.",
          notes: ["diagnostic_reference was empty."]
        )
      )
    }

    if envelope.subjectReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      issues.append(
        makeIssue(
          code: "DIAG-MISSING-SUBJECT",
          summary: "Diagnostic subject reference must be populated.",
          notes: ["subject_reference was empty."]
        )
      )
    }

    if envelope.chainRootReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      issues.append(
        makeIssue(
          code: "DIAG-MISSING-ROOT",
          summary: "Diagnostic chain root reference must be populated.",
          notes: ["chain_root_reference was empty."]
        )
      )
    }

    if envelope.ruleIDs.isEmpty {
      issues.append(
        makeIssue(
          code: "DIAG-MISSING-RULE-IDS",
          summary: "Diagnostics must include at least one rule ID.",
          notes: ["rule_ids list was empty."]
        )
      )
    } else {
      for ruleID in envelope.ruleIDs where !isValidRuleID(ruleID) {
        issues.append(
          makeIssue(
            code: "DIAG-INVALID-RULE-ID",
            summary: "Rule ID '\(ruleID)' does not conform to taxonomy.",
            notes: ["Expected ASH family taxonomy with three-digit suffix."]
          )
        )
      }
    }

    if envelope.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      issues.append(
        makeIssue(
          code: "DIAG-MISSING-SUMMARY",
          summary: "Diagnostic summary must be populated.",
          notes: ["summary was empty."]
        )
      )
    }

    if envelope.notes.isEmpty {
      issues.append(
        makeIssue(
          code: "DIAG-MISSING-NOTES",
          summary: "Diagnostic notes must include at least one entry.",
          notes: ["notes list was empty."]
        )
      )
    }

    if envelope.parentDiagnosticReference == nil {
      if envelope.chainRootReference != envelope.diagnosticReference {
        issues.append(
          makeIssue(
            code: "DIAG-ROOT-MISMATCH",
            summary: "Root diagnostics must self-reference chain root.",
            notes: ["Root diagnostic chain_root_reference must equal diagnostic_reference."]
          )
        )
      }
    } else if envelope.parentDiagnosticReference == envelope.diagnosticReference {
      issues.append(
        makeIssue(
          code: "DIAG-PARENT-SELF-REFERENCE",
          summary: "Diagnostic parent reference cannot point to itself.",
          notes: ["parent_diagnostic_reference matched diagnostic_reference."]
        )
      )
    }

    return ASHDiagnosticValidationResult(
      envelope: issues.isEmpty ? envelope : nil,
      issues: issues
    )
  }

  public func validateChain(_ chain: [ASHDiagnosticEnvelope]) -> ASHDiagnosticChainValidationResult {
    guard !chain.isEmpty else {
      let issue = makeIssue(
        code: "DIAG-EMPTY-CHAIN",
        summary: "Diagnostic chain cannot be empty.",
        notes: ["No diagnostics were provided for validation."]
      )
      return ASHDiagnosticChainValidationResult(
        validatedChain: [],
        issues: [issue],
        metaDiagnostics: [makeMetaDiagnostic(issue: issue, chainRootReference: "DIAG-CHAIN-EMPTY")]
      )
    }

    var issues: [ASHDiagnosticValidationIssue] = []
    for envelope in chain {
      let validation = validateEnvelope(envelope)
      issues.append(contentsOf: validation.issues)
    }

    let byReference = Dictionary(grouping: chain, by: \.diagnosticReference)
    for (reference, entries) in byReference where entries.count > 1 {
      issues.append(
        makeIssue(
          code: "DIAG-DUPLICATE-REFERENCE",
          summary: "Duplicate diagnostic reference '\(reference)' detected.",
          notes: ["diagnostic_reference values must be globally unique in a chain."]
        )
      )
    }

    let references = Set(chain.map(\.diagnosticReference))
    for envelope in chain {
      if let parent = envelope.parentDiagnosticReference, !references.contains(parent) {
        issues.append(
          makeIssue(
            code: "DIAG-MISSING-PARENT",
            summary: "Diagnostic \(envelope.diagnosticReference) has missing parent '\(parent)'.",
            notes: ["Every non-root diagnostic must reference an in-chain parent."]
          )
        )
      }
    }

    let rootReferences = Set(chain.map(\.chainRootReference))
    if rootReferences.count != 1 {
      issues.append(
        makeIssue(
          code: "DIAG-INCONSISTENT-ROOT",
          summary: "Diagnostics in a single chain must share one chain root reference.",
          notes: ["Observed roots: \(rootReferences.sorted().joined(separator: ", "))."]
        )
      )
    }

    let byID = Dictionary(uniqueKeysWithValues: chain.map { ($0.diagnosticReference, $0) })
    for envelope in chain {
      guard let parentReference = envelope.parentDiagnosticReference,
        let parent = byID[parentReference] else {
        continue
      }

      if stageRank(for: envelope.stage) < stageRank(for: parent.stage) {
        issues.append(
          makeIssue(
            code: "DIAG-STAGE-REGRESSION",
            summary: "Diagnostic stages must be monotonic along the chain.",
            notes: [
              "child=\(envelope.diagnosticReference) stage=\(envelope.stage.rawValue)",
              "parent=\(parent.diagnosticReference) stage=\(parent.stage.rawValue)"
            ]
          )
        )
      }
    }

    let sharedRoot = chain.first?.chainRootReference ?? "DIAG-CHAIN-UNKNOWN"
    let metaDiagnostics = issues.map { makeMetaDiagnostic(issue: $0, chainRootReference: sharedRoot) }

    return ASHDiagnosticChainValidationResult(
      validatedChain: issues.isEmpty ? chain : [],
      issues: issues,
      metaDiagnostics: metaDiagnostics
    )
  }

  public func detectOmissions(
    expectedDiagnosticReferences: [String],
    actualChain: [ASHDiagnosticEnvelope],
    chainRootReference: String
  ) -> ASHDiagnosticEnvelope? {
    let actual = Set(actualChain.map(\.diagnosticReference))
    let missing = expectedDiagnosticReferences
      .filter { !actual.contains($0) }
      .sorted()

    guard !missing.isEmpty else {
      return nil
    }

    let signature = missing.joined(separator: "-")
    let diagnosticReference = "DIAG-META-OMISSION-\(signature)"
    let parentReference = actualChain.last?.diagnosticReference
    let resolvedRootReference = parentReference == nil ? diagnosticReference : chainRootReference

    return ASHDiagnosticEnvelope(
      diagnosticReference: diagnosticReference,
      diagnosticKind: .meta,
      severity: .error,
      stage: .escalation,
      disposition: .blocked,
      subjectReference: "diagnostic-chain",
      parentDiagnosticReference: parentReference,
      chainRootReference: resolvedRootReference,
      ruleIDs: ["ASH-RECOVERY-DIAGNOSTICS-001"],
      summary: "Diagnostic chain omission detected.",
      notes: ["Missing diagnostic references: \(missing.joined(separator: ", "))."]
    )
  }

  private func isValidRuleID(_ ruleID: String) -> Bool {
    let range = NSRange(location: 0, length: ruleID.utf16.count)
    return ruleIDPattern.firstMatch(in: ruleID, options: [], range: range) != nil
  }

  private func stageRank(for stage: ASHDiagnosticStage) -> Int {
    switch stage {
    case .detection:
      return 0
    case .classification:
      return 1
    case .recovery:
      return 2
    case .escalation:
      return 3
    case .terminal:
      return 4
    }
  }

  private func makeIssue(
    code: String,
    summary: String,
    notes: [String]
  ) -> ASHDiagnosticValidationIssue {
    ASHDiagnosticValidationIssue(
      code: code,
      summary: summary,
      ruleIDs: ["ASH-RECOVERY-DIAGNOSTICS-001"],
      notes: notes
    )
  }

  private func makeMetaDiagnostic(
    issue: ASHDiagnosticValidationIssue,
    chainRootReference: String
  ) -> ASHDiagnosticEnvelope {
    let diagnosticReference = "DIAG-META-\(issue.code)"
    return ASHDiagnosticEnvelope(
      diagnosticReference: diagnosticReference,
      diagnosticKind: .meta,
      severity: .error,
      stage: .escalation,
      disposition: .blocked,
      subjectReference: "diagnostic-chain",
      parentDiagnosticReference: nil,
      chainRootReference: chainRootReference == "DIAG-CHAIN-EMPTY" ? diagnosticReference : chainRootReference,
      ruleIDs: issue.ruleIDs,
      summary: issue.summary,
      notes: issue.notes
    )
  }
}
