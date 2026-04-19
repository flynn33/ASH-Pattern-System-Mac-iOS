import Foundation

public final class ASHRecoveryEngine: ASHRecoveryEngineProtocol {
  public let fallbackPolicyRegistry: [ASHFallbackPolicyEntry]

  private let stateModel: any ASHStateModelProtocol
  private let transitionRegistry: any ASHTransitionRegistryProtocol

  public init(
    stateModel: any ASHStateModelProtocol,
    transitionRegistry: any ASHTransitionRegistryProtocol,
    fallbackPolicyRegistry: [ASHFallbackPolicyEntry]? = nil
  ) {
    self.stateModel = stateModel
    self.transitionRegistry = transitionRegistry

    if let fallbackPolicyRegistry {
      self.fallbackPolicyRegistry = fallbackPolicyRegistry
        .sorted(by: Self.sortFallbackPolicy)
    } else {
      self.fallbackPolicyRegistry = Self.makeDefaultFallbackRegistry(
        knownValidStates: stateModel.knownValidStates
      )
    }
  }

  public func recover(
    diagnostic: StateValidityDiagnostic,
    stateClass: SystemStateClass,
    recoveryCategory: RecoveryCategory
  ) -> ASHRecoveryResolution {
    switch recoveryCategory {
    case .noAction:
      return .recovery(
        ASHRecoveryDiagnostic(
          diagnosticReference: makeDiagnosticReference(
            prefix: "RECOVERY",
            state: diagnostic.inputState,
            suffix: "NO_ACTION"
          ),
          chainRootReference: makeChainRootReference(for: diagnostic),
          recoveryCategory: recoveryCategory,
          originalStateClass: stateClass,
          originalDiagnostic: diagnostic,
          steps: [
            ASHRecoveryStep(
              stepID: "no-action",
              status: .completed,
              summary: "State is stable; no recovery action required.",
              ruleIDs: ["ASH-RECOVERY-ACTION-001"],
              notes: ["RecoveryCategory.NO_ACTION for STABLE state class."]
            )
          ],
          outcome: .notApplicable,
          correctedState: diagnostic.inputState,
          fallbackPolicyID: nil,
          reason: "System is stable.",
          ruleIDs: ["ASH-RECOVERY-ACTION-001"],
          notes: ["No escalation required."]
        )
      )

    case .normalizeState:
      return performNormalizationRecovery(
        diagnostic: diagnostic,
        stateClass: stateClass,
        recoveryCategory: recoveryCategory
      )

    case .applyCorrection:
      return performCorrectionRecovery(
        diagnostic: diagnostic,
        stateClass: stateClass,
        recoveryCategory: recoveryCategory
      )

    case .fallbackRequired:
      return performFallbackRecovery(
        diagnostic: diagnostic,
        stateClass: stateClass,
        recoveryCategory: recoveryCategory
      )

    case .containmentRequired:
      return .containment(
        enterContainment(
          diagnostic: diagnostic,
          trigger: .operatorRequest,
          parentDiagnosticReference: nil
        )
      )

    case .escalationRequired:
      return .safeHalt(
        enterSafeHalt(
          diagnostic: diagnostic,
          trigger: .escalationFromFailed,
          chainReferences: [makeChainRootReference(for: diagnostic)]
        )
      )

    case .terminalNoRecovery:
      return .safeHalt(
        enterSafeHalt(
          diagnostic: diagnostic,
          trigger: .unresolvableBlockedRecovery,
          chainReferences: [makeChainRootReference(for: diagnostic)]
        )
      )
    }
  }

  public func enterContainment(
    diagnostic: StateValidityDiagnostic,
    trigger: ASHContainmentTrigger,
    parentDiagnosticReference: String?
  ) -> ASHContainmentDiagnostic {
    let diagnosticReference = makeDiagnosticReference(
      prefix: "CONTAINMENT",
      state: diagnostic.inputState,
      suffix: trigger.rawValue
    )

    var notes = [
      "Containment entered due to trigger \(trigger.rawValue).",
      "Operations restricted to non-mutating diagnostic and inspection paths."
    ]
    if let parentDiagnosticReference {
      notes.append("Parent diagnostic reference: \(parentDiagnosticReference).")
    }

    return ASHContainmentDiagnostic(
      diagnosticReference: diagnosticReference,
      chainRootReference: makeChainRootReference(for: diagnostic),
      trigger: trigger,
      originalDiagnostic: diagnostic,
      systemStateClass: .contained,
      restrictedOperations: [
        "DIAGNOSTIC_READ",
        "STATE_INSPECTION",
        "NO_TRANSITIONS"
      ],
      awaitingResolution: true,
      ruleIDs: ["ASH-CONTAINMENT-TRIGGER-001"],
      notes: notes
    )
  }

  public func enterSafeHalt(
    diagnostic: StateValidityDiagnostic,
    trigger: ASHSafeHaltTrigger,
    chainReferences: [String]
  ) -> ASHSafeHaltDiagnostic {
    ASHSafeHaltDiagnostic(
      diagnosticReference: makeDiagnosticReference(
        prefix: "SAFE_HALT",
        state: diagnostic.inputState,
        suffix: trigger.rawValue
      ),
      chainRootReference: makeChainRootReference(for: diagnostic),
      trigger: trigger,
      originalDiagnostic: diagnostic,
      systemStateClass: .safeHalt,
      fullDiagnosticChainReferences: chainReferences,
      isTerminal: true,
      ruleIDs: ["ASH-HALT-TRIGGER-001"],
      notes: [
        "Safe halt entered due to trigger \(trigger.rawValue).",
        "No further transitions are permitted in SAFE_HALT."
      ]
    )
  }

  private func performNormalizationRecovery(
    diagnostic: StateValidityDiagnostic,
    stateClass: SystemStateClass,
    recoveryCategory: RecoveryCategory
  ) -> ASHRecoveryResolution {
    guard let normalized = stateModel.normalize(diagnostic.inputState) else {
      return .containment(
        enterContainment(
          diagnostic: diagnostic,
          trigger: .recoveryValidationFailure,
          parentDiagnosticReference: nil
        )
      )
    }

    let postDiagnostic = stateModel.diagnose(normalized)
    if postDiagnostic.isValid {
      return .recovery(
        ASHRecoveryDiagnostic(
          diagnosticReference: makeDiagnosticReference(
            prefix: "RECOVERY",
            state: diagnostic.inputState,
            suffix: "NORMALIZE"
          ),
          chainRootReference: makeChainRootReference(for: diagnostic),
          recoveryCategory: recoveryCategory,
          originalStateClass: stateClass,
          originalDiagnostic: diagnostic,
          steps: [
            ASHRecoveryStep(
              stepID: "normalize",
              status: .completed,
              summary: "State normalized via canonical codeword structure.",
              ruleIDs: ["ASH-RECOVERY-ACTION-001"],
              notes: ["normalized_state=\(normalized.description)"]
            ),
            ASHRecoveryStep(
              stepID: "validate-recovery",
              status: .completed,
              summary: "Post-recovery validation classified state as valid.",
              ruleIDs: ["ASH-STATE-VALIDITY-001"],
              notes: ["post_state_class=\(SystemStateClass.stable.rawValue)"]
            )
          ],
          outcome: .recovered,
          correctedState: normalized,
          fallbackPolicyID: nil,
          reason: "Normalization succeeded and validated as stable.",
          ruleIDs: ["ASH-RECOVERY-ACTION-001", "ASH-STATE-VALIDITY-001"],
          notes: ["Deterministic normalization path completed."]
        )
      )
    }

    return .containment(
      enterContainment(
        diagnostic: diagnostic,
        trigger: .recoveryValidationFailure,
        parentDiagnosticReference: nil
      )
    )
  }

  private func performCorrectionRecovery(
    diagnostic: StateValidityDiagnostic,
    stateClass: SystemStateClass,
    recoveryCategory: RecoveryCategory
  ) -> ASHRecoveryResolution {
    if let normalized = stateModel.normalize(diagnostic.inputState),
      stateModel.isValid(normalized) {
      return .recovery(
        ASHRecoveryDiagnostic(
          diagnosticReference: makeDiagnosticReference(
            prefix: "RECOVERY",
            state: diagnostic.inputState,
            suffix: "CORRECTION"
          ),
          chainRootReference: makeChainRootReference(for: diagnostic),
          recoveryCategory: recoveryCategory,
          originalStateClass: stateClass,
          originalDiagnostic: diagnostic,
          steps: [
            ASHRecoveryStep(
              stepID: "find-correction-sequence",
              status: .completed,
              summary: "Correction sequence resolved deterministically.",
              ruleIDs: ["ASH-RECOVERY-ACTION-001"],
              notes: ["Applied single-step codeword normalization sequence."]
            ),
            ASHRecoveryStep(
              stepID: "apply-correction",
              status: .completed,
              summary: "Correction sequence applied.",
              ruleIDs: ["ASH-CODEWORD-STRUCTURE-001"],
              notes: ["corrected_state=\(normalized.description)"]
            )
          ],
          outcome: .recovered,
          correctedState: normalized,
          fallbackPolicyID: nil,
          reason: "Correction sequence produced valid state.",
          ruleIDs: ["ASH-RECOVERY-ACTION-001", "ASH-CODEWORD-STRUCTURE-001"],
          notes: ["Correction remained within canonical codeword transitions."]
        )
      )
    }

    return performFallbackRecovery(
      diagnostic: diagnostic,
      stateClass: stateClass,
      recoveryCategory: .fallbackRequired
    )
  }

  private func performFallbackRecovery(
    diagnostic: StateValidityDiagnostic,
    stateClass: SystemStateClass,
    recoveryCategory: RecoveryCategory
  ) -> ASHRecoveryResolution {
    let orderedCandidates = fallbackPolicyRegistry
      .sorted(by: Self.sortFallbackPolicy)

    guard !orderedCandidates.isEmpty else {
      return .containment(
        enterContainment(
          diagnostic: diagnostic,
          trigger: .fallbackFailure,
          parentDiagnosticReference: nil
        )
      )
    }

    var steps: [ASHRecoveryStep] = []

    for candidate in orderedCandidates {
      let candidateDiagnostic = stateModel.diagnose(candidate.candidateStateReference)

      if candidateDiagnostic.isValid {
        steps.append(
          ASHRecoveryStep(
            stepID: "select-\(candidate.policyID)",
            status: .completed,
            summary: "Fallback candidate \(candidate.policyID) selected.",
            ruleIDs: ["ASH-FALLBACK-SELECTION-001"],
            notes: candidate.notes + ["candidate_state=\(candidate.candidateStateReference.description)"]
          )
        )

        let transitionProbe = transitionRegistry.availableTransitions(from: candidate.candidateStateReference)
        steps.append(
          ASHRecoveryStep(
            stepID: "validate-\(candidate.policyID)",
            status: .completed,
            summary: "Fallback candidate validated as stable.",
            ruleIDs: ["ASH-STATE-VALIDITY-001"],
            notes: ["available_transition_count=\(transitionProbe.count)"]
          )
        )

        return .recovery(
          ASHRecoveryDiagnostic(
            diagnosticReference: makeDiagnosticReference(
              prefix: "RECOVERY",
              state: diagnostic.inputState,
              suffix: "FALLBACK"
            ),
            chainRootReference: makeChainRootReference(for: diagnostic),
            recoveryCategory: recoveryCategory,
            originalStateClass: stateClass,
            originalDiagnostic: diagnostic,
            steps: steps,
            outcome: .recoveredViaFallback,
            correctedState: candidate.candidateStateReference,
            fallbackPolicyID: candidate.policyID,
            reason: "Fallback selected from canonical registry and validated.",
            ruleIDs: ["ASH-FALLBACK-SELECTION-001", "ASH-STATE-VALIDITY-001"],
            notes: ["Fallback ordering: ordering_rank then policy_id."]
          )
        )
      }

      steps.append(
        ASHRecoveryStep(
          stepID: "select-\(candidate.policyID)",
          status: .failed,
          summary: "Fallback candidate \(candidate.policyID) failed validation.",
          ruleIDs: ["ASH-FALLBACK-SELECTION-001"],
          notes: candidate.notes + ["candidate did not classify as valid."]
        )
      )

      if candidate.escalationOnFailure == .escalateToContainment {
        break
      }
    }

    return .containment(
      enterContainment(
        diagnostic: diagnostic,
        trigger: .fallbackFailure,
        parentDiagnosticReference: steps.last?.stepID
      )
    )
  }

  private static func sortFallbackPolicy(
    lhs: ASHFallbackPolicyEntry,
    rhs: ASHFallbackPolicyEntry
  ) -> Bool {
    if lhs.orderingRank == rhs.orderingRank {
      return lhs.policyID < rhs.policyID
    }
    return lhs.orderingRank < rhs.orderingRank
  }

  private static func makeDefaultFallbackRegistry(
    knownValidStates: Set<ASHState>
  ) -> [ASHFallbackPolicyEntry] {
    let states = knownValidStates.sorted()
    if states.isEmpty {
      return []
    }

    return states.enumerated().map { index, state in
      let sequence = String(format: "%03d", index + 1)
      return ASHFallbackPolicyEntry(
        policyID: "FALLBACK-CORE-\(sequence)",
        candidateStateReference: state,
        orderingRank: index,
        escalationOnFailure: .tryNext,
        notes: ["Default canonical fallback candidate."]
      )
    }
  }

  private func makeChainRootReference(for diagnostic: StateValidityDiagnostic) -> String {
    "CHAIN-\(diagnostic.inputState.description)"
  }

  private func makeDiagnosticReference(
    prefix: String,
    state: ASHState,
    suffix: String
  ) -> String {
    "\(prefix)-\(state.description)-\(suffix)"
  }
}
