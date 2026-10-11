import Foundation

public final class ASHTransitionRegistry: ASHTransitionRegistryProtocol {
  public let orderedTransitions: [ASHTransitionDefinition]

  private let stateModel: any ASHStateModelProtocol
  private let transitionByID: [String: ASHTransitionDefinition]
  private let transitionByCodeword: [ASHState: ASHTransitionDefinition]
  private let configurationIssues: [String]

  public init(
    stateModel: any ASHStateModelProtocol
  ) {
    self.stateModel = stateModel
    self.configurationIssues = stateModel.codewordSet == ASHStateModel.canonicalCodewordSet
      ? [] : ["The state model must expose exactly the sixteen canonical codewords."]
    self.orderedTransitions = Self.makeCanonicalTransitions(codewordSet: ASHStateModel.canonicalCodewordSet)
    self.transitionByID = Dictionary(uniqueKeysWithValues: self.orderedTransitions.map { ($0.transitionID, $0) })
    self.transitionByCodeword = Dictionary(uniqueKeysWithValues: self.orderedTransitions.map { ($0.codeword, $0) })
  }

  public init(stateModel: any ASHStateModelProtocol, validatingTransitions transitions: [ASHTransitionDefinition]) throws {
    var issues: [String] = []
    if stateModel.codewordSet != ASHStateModel.canonicalCodewordSet {
      issues.append("The state model must expose exactly the sixteen canonical codewords.")
    }
    if transitions.count != 16 { issues.append("A complete registry requires sixteen transitions; received \(transitions.count).") }
    let ids = Dictionary(grouping: transitions.enumerated(), by: { $0.element.transitionID })
    for id in ids.keys.sorted() where ids[id]!.count > 1 {
      issues.append("Duplicate transition ID \(id) at indices \(ids[id]!.map(\.offset)).")
    }
    let words = Dictionary(grouping: transitions.enumerated(), by: { $0.element.codeword })
    for word in words.keys.sorted() where words[word]!.count > 1 {
      issues.append("Duplicate codeword \(word) at indices \(words[word]!.map(\.offset)).")
    }
    let canonical = Self.makeCanonicalTransitions(codewordSet: ASHStateModel.canonicalCodewordSet)
    let expected = Dictionary(uniqueKeysWithValues: canonical.map { ($0.codeword, $0) })
    for (index, transition) in transitions.enumerated() {
      guard let reference = expected[transition.codeword] else {
        issues.append("Noncanonical codeword at index \(index).")
        continue
      }
      if transition.transitionID != reference.transitionID || transition.applicability != .always {
        issues.append("Transition at index \(index) contradicts its canonical identity or applicability.")
      }
      if transition.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || transition.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        issues.append("Transition at index \(index) is missing explanatory metadata.")
      }
    }
    guard issues.isEmpty else { throw ASHRegistryValidationError(issues: issues) }
    self.stateModel = stateModel
    self.configurationIssues = []
    self.orderedTransitions = transitions.sorted { $0.codeword < $1.codeword }
    self.transitionByID = Dictionary(uniqueKeysWithValues: self.orderedTransitions.map { ($0.transitionID, $0) })
    self.transitionByCodeword = Dictionary(uniqueKeysWithValues: self.orderedTransitions.map { ($0.codeword, $0) })
  }

  public func availableTransitions(from state: ASHState) -> [ASHTransitionDefinition] {
    guard configurationIssues.isEmpty else { return [] }
    guard isStateEligibleForTransition(state) else {
      return []
    }

    return orderedTransitions.filter { $0.applicability.isApplicable(to: state) }
  }

  public func applyTransition(from state: ASHState, transitionID: String) -> ASHTransitionResolution {
    if let failure = configurationFailure { return .failure(failure) }
    guard let transition = transitionByID[transitionID] else {
      return .failure(
        ASHTransitionFailureDiagnostic(
          reason: .transitionNotFound,
          summary: "Transition \(transitionID) is not registered.",
          ruleIDs: ["ASH-CODEWORD-TRANSITION-001"],
          notes: ["Use an entry from orderedTransitions for deterministic transition resolution."]
        )
      )
    }

    guard transition.applicability.isApplicable(to: state) else {
      return .failure(
        ASHTransitionFailureDiagnostic(
          reason: .transitionNotApplicable,
          summary: "Transition \(transitionID) is not applicable for the provided state.",
          ruleIDs: ["ASH-CODEWORD-TRANSITION-002"],
          notes: [
            "Transition applicability rules are deterministic and state-dependent.",
            "Requested codeword: \(transition.codeword.description)."
          ]
        )
      )
    }

    return applyCodeword(from: state, codeword: transition.codeword)
  }

  public func applyCodeword(from state: ASHState, codeword: ASHState) -> ASHTransitionResolution {
    if let failure = configurationFailure { return .failure(failure) }
    guard isStateEligibleForTransition(state) else {
      return .failure(
        ASHTransitionFailureDiagnostic(
          reason: .invalidInputState,
          summary: "Input state is not eligible for transition processing.",
          ruleIDs: ["ASH-STATE-VALIDITY-001", "ASH-CODEWORD-TRANSITION-003"],
          notes: [
            "Transitions require a valid or transformation-compatible state.",
            "Admissibility status: \(stateModel.classifyAdmissibility(of: state).rawValue)."
          ]
        )
      )
    }

    guard stateModel.codewordSet.contains(codeword) else {
      return .failure(
          ASHTransitionFailureDiagnostic(
            reason: .codewordNotAllowed,
            summary: "Provided codeword is outside the canonical codeword set.",
            ruleIDs: ["ASH-CODEWORD-STRUCTURE-001"],
          notes: ["Transitions are constrained to canonical codewords only."]
        )
      )
    }

    guard let transitionDefinition = transitionByCodeword[codeword] else {
      return .failure(ASHTransitionFailureDiagnostic(
        reason: .transitionNotFound, summary: "No registered transition names this codeword.",
        ruleIDs: ["ASH-TRANSITION-001"], notes: ["The registry never manufactures transition identities."]
      ))
    }
    let transformed = state.xor(codeword)

    return .success(
      ASHTransitionApplied(
        transitionID: transitionDefinition.transitionID,
        fromState: state,
        toState: transformed,
        codeword: codeword
      )
    )
  }

  private var configurationFailure: ASHTransitionFailureDiagnostic? {
    guard !configurationIssues.isEmpty else { return nil }
    return ASHTransitionFailureDiagnostic(reason: .invalidRegistry,
      summary: "Transition registry configuration is invalid.",
      ruleIDs: ["ASH-CODEWORD-001", "ASH-TRANSITION-001"], notes: configurationIssues)
  }

  private func isStateEligibleForTransition(_ state: ASHState) -> Bool {
    let admissibility = stateModel.classifyAdmissibility(of: state)
    return admissibility == .valid || admissibility == .transformationCompatible
  }

  private static func makeCanonicalTransitions(codewordSet: Set<ASHState>) -> [ASHTransitionDefinition] {
    codewordSet
      .sorted()
      .enumerated()
      .map { index, codeword in
        let codewordID = String(format: "APS-CW-%02d", index)
        let transitionID = String(format: "APS-TRANSITION-CW-%02d", index)
        return ASHTransitionDefinition(
          transitionID: transitionID,
          displayName: "Codeword \(codewordID)",
          description: "Apply canonical XOR-by-codeword transition using \(codeword.description)",
          codeword: codeword,
          applicability: .always
        )
      }
  }
}
