import Foundation

public final class ASHStateModel: ASHStateModelProtocol {
  public let codewordSet: Set<ASHState>
  public let knownValidStates: Set<ASHState>

  public init(
    codewordSet: Set<ASHState> = ASHStateModel.canonicalCodewordSet,
    knownValidStates: Set<ASHState> = [.zero]
  ) {
    precondition(!codewordSet.isEmpty, "Codeword set cannot be empty")
    precondition(codewordSet.contains(.zero), "Codeword set must include zero")
    precondition(!knownValidStates.isEmpty, "Known valid states cannot be empty")

    self.codewordSet = codewordSet
    self.knownValidStates = knownValidStates
  }

  public func transform(_ state: ASHState, by codeword: ASHState) -> ASHState? {
    guard codewordSet.contains(codeword) else {
      return nil
    }
    return state.xor(codeword)
  }

  public func normalize(_ state: ASHState) -> ASHState? {
    let admissibility = classifyAdmissibility(of: state)
    switch admissibility {
    case .valid:
      return state
    case .transformationCompatible:
      return normalizedAnchor(for: state)
    case .transformationIncompatible, .unclassified:
      return nil
    }
  }

  public func isValid(_ state: ASHState) -> Bool {
    knownValidStates.contains(state)
  }

  public func classifyAdmissibility(of state: ASHState) -> AdmissibilityStatus {
    if isValid(state) {
      return .valid
    }

    if isTransformationCompatible(state) {
      return .transformationCompatible
    }

    return .transformationIncompatible
  }

  public func diagnose(_ state: ASHState) -> StateValidityDiagnostic {
    let admissibility = classifyAdmissibility(of: state)

    let transformationCompatibility: TransformationCompatibility
    switch admissibility {
    case .valid, .transformationCompatible:
      transformationCompatibility = .compatible
    case .transformationIncompatible:
      transformationCompatibility = .incompatible
    case .unclassified:
      transformationCompatibility = .unknown
    }

    let normalizationStatus: NormalizationStatus
    switch admissibility {
    case .valid:
      normalizationStatus = .alreadyValid
    case .transformationCompatible:
      normalizationStatus = .normalizable
    case .transformationIncompatible:
      normalizationStatus = .notNormalizable
    case .unclassified:
      normalizationStatus = .blocked
    }

    let recoverabilityRelevance: RecoverabilityRelevance
    switch normalizationStatus {
    case .alreadyValid:
      recoverabilityRelevance = .noRecoveryNeeded
    case .normalizable:
      recoverabilityRelevance = .recoveryApplicable
    case .notNormalizable:
      recoverabilityRelevance = .notRecoverable
    case .blocked:
      recoverabilityRelevance = .containmentNeeded
    }

    let notes = notesFor(
      state: state,
      admissibility: admissibility,
      normalizationStatus: normalizationStatus,
      recoverability: recoverabilityRelevance
    )

    return StateValidityDiagnostic(
      inputState: state,
      admissibilityStatus: admissibility,
      transformationCompatibility: transformationCompatibility,
      normalizationStatus: normalizationStatus,
      recoverabilityRelevance: recoverabilityRelevance,
      isValid: admissibility == .valid && normalizationStatus == .alreadyValid,
      orbitInfo: computeOrbitInfo(for: state),
      ruleIDs: ruleIDs(for: admissibility),
      notes: notes
    )
  }

  public func classifySystemState(
    for diagnostic: StateValidityDiagnostic,
    context: ASHSystemContext
  ) -> SystemStateClass {
    if context.isInSafeHalt {
      return .safeHalt
    }

    if context.isInContainment {
      return .contained
    }

    if diagnostic.admissibilityStatus == .valid
      && diagnostic.normalizationStatus == .alreadyValid {
      return .stable
    }

    if diagnostic.admissibilityStatus == .transformationCompatible,
      diagnostic.normalizationStatus == .normalizable {
      return context.correctionPathKnown ? .correctable : .unstable
    }

    if diagnostic.admissibilityStatus == .transformationIncompatible {
      return context.fallbackAvailable ? .degraded : .failed
    }

    return .degraded
  }

  public func classifyRecovery(for stateClass: SystemStateClass) -> RecoveryCategory {
    switch stateClass {
    case .stable:
      return .noAction
    case .unstable:
      return .normalizeState
    case .correctable:
      return .applyCorrection
    case .degraded:
      return .fallbackRequired
    case .contained:
      return .containmentRequired
    case .failed:
      return .escalationRequired
    case .safeHalt:
      return .terminalNoRecovery
    }
  }

  private func isTransformationCompatible(_ state: ASHState) -> Bool {
    for validState in knownValidStates {
      let delta = state.xor(validState)
      if codewordSet.contains(delta) {
        return true
      }
    }
    return false
  }

  private func normalizedAnchor(for state: ASHState) -> ASHState? {
    let candidates = knownValidStates
      .filter { codewordSet.contains(state.xor($0)) }
      .sorted { lhs, rhs in
        let lhsDistance = state.xor(lhs).hammingWeight()
        let rhsDistance = state.xor(rhs).hammingWeight()
        if lhsDistance == rhsDistance {
          return lhs.rawValue < rhs.rawValue
        }
        return lhsDistance < rhsDistance
      }

    return candidates.first
  }

  private func computeOrbitInfo(for state: ASHState) -> OrbitInfo? {
    let orbitStates = Set(codewordSet.map { state.xor($0) })
    guard let representative = orbitStates.min() else {
      return nil
    }

    let containsKnownValid = !orbitStates.isDisjoint(with: knownValidStates)
    return OrbitInfo(
      orbitRepresentative: representative,
      orbitSize: orbitStates.count,
      containsKnownValidState: containsKnownValid
    )
  }

  private func notesFor(
    state: ASHState,
    admissibility: AdmissibilityStatus,
    normalizationStatus: NormalizationStatus,
    recoverability: RecoverabilityRelevance
  ) -> [String] {
    var notes: [String] = []

    switch admissibility {
    case .valid:
      notes.append("State is a recognized valid state in the configured valid-state set.")
    case .transformationCompatible:
      notes.append("State is transformation-compatible via canonical codeword orbit membership.")
    case .transformationIncompatible:
      notes.append("State is outside configured codeword orbits for known valid states.")
    case .unclassified:
      notes.append("State admissibility could not be determined.")
    }

    switch normalizationStatus {
    case .alreadyValid:
      notes.append("No normalization required.")
    case .normalizable:
      if let anchor = normalizedAnchor(for: state) {
        notes.append("State can normalize to valid anchor \(anchor.description).")
      } else {
        notes.append("State appears compatible but no deterministic anchor was found.")
      }
    case .notNormalizable:
      notes.append("No codeword-based normalization path exists for the configured valid-state set.")
    case .blocked:
      notes.append("Normalization is blocked due to unclassified admissibility.")
    }

    if recoverability == .notRecoverable {
      notes.append("Recovery requires fallback or escalation outside codeword-only correction.")
    }

    return notes
  }

  private func ruleIDs(for admissibility: AdmissibilityStatus) -> [String] {
    switch admissibility {
    case .valid:
      return [
        "ASH-STATE-VALIDITY-001",
        "ASH-CODEWORD-STRUCTURE-001"
      ]
    case .transformationCompatible:
      return [
        "ASH-ADMISSIBILITY-CLASSIFICATION-001",
        "ASH-STATE-VALIDITY-001"
      ]
    case .transformationIncompatible:
      return [
        "ASH-ADMISSIBILITY-CLASSIFICATION-001",
        "ASH-RECOVERY-ACTION-001"
      ]
    case .unclassified:
      return [
        "ASH-STATE-GENERAL-001"
      ]
    }
  }
}

extension ASHStateModel {
  public static let canonicalCodewordSet: Set<ASHState> = {
    let vectors: [[UInt8]] = [
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 1, 1, 1, 1, 0],
      [0, 0, 1, 1, 0, 0, 1, 1, 0],
      [0, 0, 1, 1, 1, 1, 0, 0, 0],
      [0, 1, 0, 1, 0, 1, 0, 1, 0],
      [0, 1, 0, 1, 1, 0, 1, 0, 0],
      [0, 1, 1, 0, 0, 1, 1, 0, 0],
      [0, 1, 1, 0, 1, 0, 0, 1, 0],
      [1, 0, 0, 1, 0, 1, 1, 0, 0],
      [1, 0, 0, 1, 1, 0, 0, 1, 0],
      [1, 0, 1, 0, 0, 1, 0, 1, 0],
      [1, 0, 1, 0, 1, 0, 1, 0, 0],
      [1, 1, 0, 0, 0, 0, 1, 1, 0],
      [1, 1, 0, 0, 1, 1, 0, 0, 0],
      [1, 1, 1, 1, 0, 0, 0, 0, 0],
      [1, 1, 1, 1, 1, 1, 1, 1, 0]
    ]
    return Set(vectors.compactMap(ASHState.init(bits:)))
  }()
}
