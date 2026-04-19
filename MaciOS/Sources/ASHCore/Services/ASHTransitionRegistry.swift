import Foundation

public final class ASHTransitionRegistry: ASHTransitionRegistryProtocol {
  public let orderedTransitions: [ASHTransitionDefinition]

  private let stateModel: any ASHStateModelProtocol
  private let transitionByID: [String: ASHTransitionDefinition]
  private let transitionByCodeword: [ASHState: ASHTransitionDefinition]

  public init(
    stateModel: any ASHStateModelProtocol,
    orderedTransitions: [ASHTransitionDefinition]? = nil
  ) {
    self.stateModel = stateModel

    let transitions = orderedTransitions
      ?? ASHTransitionRegistry.makeCanonicalTransitions(codewordSet: stateModel.codewordSet)

    self.orderedTransitions = transitions.sorted { lhs, rhs in
      if lhs.codeword.rawValue == rhs.codeword.rawValue {
        return lhs.transitionID < rhs.transitionID
      }
      return lhs.codeword.rawValue < rhs.codeword.rawValue
    }

    self.transitionByID = Dictionary(uniqueKeysWithValues: self.orderedTransitions.map { ($0.transitionID, $0) })
    self.transitionByCodeword = Dictionary(uniqueKeysWithValues: self.orderedTransitions.map { ($0.codeword, $0) })
  }

  public func availableTransitions(from state: ASHState) -> [ASHTransitionDefinition] {
    isStateEligibleForTransition(state) ? orderedTransitions : []
  }

  public func applyTransition(from state: ASHState, transitionID: String) -> ASHTransitionResolution {
    guard let transition = transitionByID[transitionID] else {
      return .failure(
        ASHTransitionFailureDiagnostic(
          reason: .transitionNotFound,
          summary: "Transition \(transitionID) is not registered.",
          ruleIDs: ["ASH-TRANSITION-RESOLUTION-001"],
          notes: ["Use an entry from orderedTransitions for deterministic transition resolution."]
        )
      )
    }

    return applyCodeword(from: state, codeword: transition.codeword)
  }

  public func applyCodeword(from state: ASHState, codeword: ASHState) -> ASHTransitionResolution {
    guard isStateEligibleForTransition(state) else {
      return .failure(
        ASHTransitionFailureDiagnostic(
          reason: .invalidInputState,
          summary: "Input state is not eligible for transition processing.",
          ruleIDs: ["ASH-STATE-VALIDITY-001", "ASH-TRANSITION-APPLICABILITY-001"],
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

    let transformed = state.xor(codeword)
    let transitionDefinition = transitionByCodeword[codeword]
      ?? ASHTransitionDefinition(
        transitionID: "CW-\(codeword.description)",
        displayName: "Codeword \(codeword.description)",
        description: "Canonical XOR-by-codeword transition",
        codeword: codeword
      )

    return .success(
      ASHTransitionApplied(
        transitionID: transitionDefinition.transitionID,
        fromState: state,
        toState: transformed,
        codeword: codeword
      )
    )
  }

  private func isStateEligibleForTransition(_ state: ASHState) -> Bool {
    let admissibility = stateModel.classifyAdmissibility(of: state)
    return admissibility == .valid || admissibility == .transformationCompatible
  }

  private static func makeCanonicalTransitions(codewordSet: Set<ASHState>) -> [ASHTransitionDefinition] {
    codewordSet
      .sorted()
      .map { codeword in
        let transitionID = "CW-\(codeword.description)"
        return ASHTransitionDefinition(
          transitionID: transitionID,
          displayName: "Codeword \(codeword.description)",
          description: "Apply canonical XOR-by-codeword transition using \(codeword.description)",
          codeword: codeword
        )
      }
  }
}
