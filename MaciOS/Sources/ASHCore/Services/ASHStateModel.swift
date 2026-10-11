import Foundation

public final class ASHStateModel: ASHStateModelProtocol {
  public let codewordSet = ASHStateModel.canonicalCodewordSet
  public let knownValidStates = ASHStateModel.canonicalStateSpace
  public init() {}
  public convenience init(validatingCodewordSet: Set<ASHState>) throws {
    guard validatingCodewordSet == Self.canonicalCodewordSet else {
      throw ASHRegistryValidationError(issues: ["The canonical codeword set is fixed; alternate models are not supported."])
    }
    self.init()
  }
  public func transform(_ state: ASHState, by codeword: ASHState) -> ASHState? {
    codewordSet.contains(codeword) ? state.xor(codeword) : nil
  }
  public func normalize(_ state: ASHState) -> ASHState? { state }
  public func isValid(_ state: ASHState) -> Bool { Self.canonicalStateSpace.contains(state) }
  public func classifyAdmissibility(of state: ASHState) -> AdmissibilityStatus { .valid }
  public func diagnose(_ state: ASHState) -> StateValidityDiagnostic {
    let representative = reachableStates(from: state).min() ?? state
    return StateValidityDiagnostic(inputState: state, admissibilityStatus: .valid, transformationCompatibility: .compatible,
      normalizationStatus: .alreadyValid, recoverabilityRelevance: .noRecoveryNeeded, isValid: true,
      orbitInfo: OrbitInfo(orbitRepresentative: representative, orbitID: Self.canonicalOrbitIDByRepresentative[representative], orbitSize: 16, containsKnownValidState: true),
      ruleIDs: ["ASH-INPUT-001", "ASH-STATE-001", "ASH-CODEWORD-001"],
      notes: ["Nine-bit structural normalization preserves state and realm identity; operational stability requires a validated context."])
  }
  public func reachableStates(from state: ASHState) -> [ASHState] { codewordSet.map { state.xor($0) }.sorted() }
  public func isReachable(from source: ASHState, to target: ASHState) -> Bool { codewordSet.contains(source.xor(target)) }
  public func codewordID(for word: ASHState) -> String? {
    guard let index = codewordSet.sorted().firstIndex(of: word) else { return nil }
    return String(format: "APS-CW-%02d", index)
  }
  public func assess(bitString: String, context: ASHOperationalContext?, runtime: ASHRuntimeMode = .active) -> ASHStateAssessment {
    guard let state = ASHState(bitString: bitString) else {
      let record = ASHDiagnosticEnvelope.canonical(kind: .inputValidation, severity: .error, stage: .parse, disposition: .blocked,
        subject: "input", ruleIDs: ["ASH-INPUT-001"], summary: "Malformed input blocks state assessment.", notes: ["No operational class is assigned to malformed input."],
        details: ["input_status":.string("MALFORMED"), "assessment_blocked":.bool(true)])
      return ASHStateAssessment(state: nil, inputStatus: .malformed, contextID: context?.contextID, candidateTargets: [], selectedTarget: nil, correctionCodewordID: nil, runtimeMode: runtime, stateClass: nil, diagnostics: [record])
    }
    return assess(state: state, context: context, runtime: runtime)
  }
  public func assess(state: ASHState, context: ASHOperationalContext?, runtime: ASHRuntimeMode = .active) -> ASHStateAssessment {
    let issues = context?.validationIssues ?? ["A validated operational context is required."]
    guard issues.isEmpty, let context else {
      let record = ASHDiagnosticEnvelope.canonical(kind: .stateAssessment, severity: .error, stage: .assess, disposition: .blocked,
        subject: state.description, ruleIDs: ["ASH-CLASSIFICATION-001"], summary: "Operational context blocks state assessment.", notes: issues,
        details: ["assessment_blocked":.bool(true)])
      return ASHStateAssessment(state: state, inputStatus: .wellFormed, contextID: context?.contextID, candidateTargets: [], selectedTarget: nil, correctionCodewordID: nil, runtimeMode: runtime, stateClass: nil, diagnostics: [record])
    }
    let candidates = context.allowedStableStates.filter { isReachable(from: state, to: $0) }.sorted()
    let selected = candidates.count == 1 ? candidates.first : context.preferredState.flatMap { candidates.contains($0) ? $0 : nil }
    let classification: SystemStateClass
    switch runtime {
    case .safeHalt: classification = .safeHalt
    case .contained: classification = .contained
    case .failed: classification = .failed
    case .active:
      if context.allowedStableStates.contains(state) { classification = .stable }
      else if candidates.isEmpty { classification = .degraded }
      else if selected == nil { classification = .unstable }
      else { classification = .correctable }
    }
    let target = classification == .correctable ? selected : nil
    let correctionID = target.flatMap { codewordID(for: state.xor($0)) }
    let record = ASHDiagnosticEnvelope.canonical(kind: .classification, stage: .classify, disposition: .recorded,
      subject: state.description, ruleIDs: ["ASH-CLASSIFICATION-001"], summary: "State assessed under validated operational context.", notes: ["Target selection requires a unique reachable candidate or an explicitly preferred candidate."],
      details: ["state_class":.string(classification.rawValue), "context_id":.string(context.contextID),
        "candidate_targets":.array(candidates.map { .string($0.description) }), "selected_target":target.map { .string($0.description) } ?? .null,
        "correction_codeword_id":correctionID.map(ASHDiagnosticValue.string) ?? .null, "runtime_mode":.string(runtime.rawValue)])
    return ASHStateAssessment(state: state, inputStatus: .wellFormed, contextID: context.contextID, candidateTargets: candidates,
      selectedTarget: target, correctionCodewordID: correctionID, runtimeMode: runtime, stateClass: classification, diagnostics: [record])
  }
  public func classifyRecovery(for stateClass: SystemStateClass) -> RecoveryCategory {
    switch stateClass {
    case .stable: return .noAction
    case .unstable: return .targetResolutionRequired
    case .correctable: return .applyCorrection
    case .degraded: return .fallbackRequired
    case .contained: return .containmentActive
    case .failed: return .externalEscalationRequired
    case .safeHalt: return .terminalNoRecovery
    }
  }
}

extension ASHStateModel {
  public static let canonicalStateSpace: Set<ASHState> = {
    Set((UInt16(0)..<ASHState.maxRawValue).compactMap(ASHState.init(rawValue:)))
  }()

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

  private static let canonicalOrbitIDByRepresentative: [ASHState: String] = {
    let representatives = Set(canonicalStateSpace.compactMap { state in
      Set(canonicalCodewordSet.map { state.xor($0) }).min()
    })
    return Dictionary(
      uniqueKeysWithValues: representatives.sorted().enumerated().map { index, representative in
        (representative, String(format: "APS-ORBIT-%02d", index))
      }
    )
  }()
}
