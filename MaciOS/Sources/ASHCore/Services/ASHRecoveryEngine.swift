import Foundation

public final class ASHRecoveryEngine: ASHRecoveryEngineProtocol {
  private let stateModel: any ASHStateModelProtocol
  private let transitionRegistry: any ASHTransitionRegistryProtocol
  public init(stateModel: any ASHStateModelProtocol, transitionRegistry: any ASHTransitionRegistryProtocol) {
    self.stateModel = stateModel; self.transitionRegistry = transitionRegistry
  }
  public func recover(state: ASHState, context: ASHOperationalContext, runtime: ASHRuntimeMode = .active) -> ASHOperationalRecoveryResult {
    let before = stateModel.assess(state: state, context: context, runtime: runtime)
    let category = before.recoveryCategory
    var chain = before.diagnostics
    var outcome: ASHOperationalRecoveryOutcome = .notApplicable
    var target: ASHState?, replacement: ASHState?, wordID: String?, policyID: String?, after: ASHStateAssessment?
    var summary = "Recovery requires no mutation."
    var details: [String: ASHDiagnosticValue] = ["original_state":.string(state.description), "recovery_category":category.map { .string($0.rawValue) } ?? .null]
    switch category {
    case .applyCorrection:
      if let selected = before.selectedTarget,
        let identifier = before.correctionCodewordID,
        let applied = transitionRegistry.applyCodeword(from: state, codeword: state.xor(selected)).applied,
        applied.toState == selected {
        let post = stateModel.assess(state: applied.toState, context: context, runtime: .active)
        after = post
        if post.stateClass == .stable {
          target = selected; wordID = identifier; outcome = .recovered
          summary = "Canonical correction reached the selected same-orbit stable target."
        } else { outcome = .recoveryFailed; summary = "Correction failed immediate operational reassessment." }
      } else { outcome = .recoveryFailed; summary = "Correction target or codeword validation failed." }
    case .fallbackRequired:
      policyID = context.fallbackPolicyInstance.policy.rawValue
      let candidates = context.fallbackPolicyInstance.orderedCandidates
      if let candidate = candidates.first {
        let post = stateModel.assess(state: candidate.state, context: context, runtime: .active)
        after = post
        details["attempted_candidate"] = .string(candidate.state.description)
        details["candidate_evidence"] = .string(candidate.evidence)
        details["configured_rank"] = .integer(Int64(candidate.configuredRank))
        details["verification_sequence"] = candidate.verificationSequence.map { .integer(Int64($0)) } ?? .null
        if let cls = post.stateClass, [.stable, .correctable, .unstable].contains(cls) {
          replacement = candidate.state; outcome = .recoveredViaFallbackReplacement
          summary = "Authorized fallback replacement passed immediate operational reassessment."
        } else { outcome = .escalateToContainment; summary = "Selected fallback candidate failed immediate reassessment." }
      } else { outcome = .escalateToContainment; summary = "Fallback policy declares no applicable replacement." }
    case .targetResolutionRequired:
      outcome = .targetResolutionBlocked; summary = "Target policy cannot select one stable candidate; state remains unchanged."
    case .externalEscalationRequired:
      outcome = .targetResolutionBlocked; summary = "Failed runtime awaits external authority; automated recovery is blocked."
    case .containmentActive, .terminalNoRecovery:
      outcome = .targetResolutionBlocked; summary = "Runtime restrictions prohibit recovery mutation."
    case .noAction: after = before
    case nil:
      outcome = .recoveryFailed; summary = "Invalid operational context blocks recovery."
    }
    details["outcome"] = .string(outcome.rawValue)
    details["target_state"] = target.map { .string($0.description) } ?? .null
    details["replacement_state"] = replacement.map { .string($0.description) } ?? .null
    details["codeword_id"] = wordID.map(ASHDiagnosticValue.string) ?? .null
    details["fallback_policy_id"] = policyID.map(ASHDiagnosticValue.string) ?? .null
    details["context_id"] = .string(context.contextID)
    details["context_version"] = .string(context.contextVersion)
    details["target_policy_decision"] = .string(before.selectedTarget == nil ? "NO_SELECTED_TARGET" : "UNIQUE_OR_EXPLICIT_PREFERRED_TARGET")
    details["pre_assessment"] = .object(["state_class":before.stateClass.map { .string($0.rawValue) } ?? .null, "candidate_targets":.array(before.candidateTargets.map { .string($0.description) }), "selected_target":before.selectedTarget.map { .string($0.description) } ?? .null])
    details["post_assessment"] = after.map { assessment in .object(["state_signature":assessment.state.map { .string($0.description) } ?? .null, "state_class":assessment.stateClass.map { .string($0.rawValue) } ?? .null, "context_id":assessment.contextID.map(ASHDiagnosticValue.string) ?? .null, "candidate_targets":.array(assessment.candidateTargets.map { .string($0.description) })]) } ?? .null
    details["post_state_class"] = after?.stateClass.map { .string($0.rawValue) } ?? .null
    let record = ASHDiagnosticEnvelope.canonical(kind: category == .fallbackRequired ? .fallback : .recovery,
      severity: outcome == .recoveryFailed || outcome == .escalateToContainment ? .error : .info,
      stage: category == .fallbackRequired ? .fallback : .recover,
      disposition: [.recovered, .recoveredViaFallbackReplacement].contains(outcome) ? .resolved : (outcome == .notApplicable ? .recorded : .blocked),
      subject: state.description, ruleIDs: [category == .fallbackRequired ? "ASH-FALLBACK-001" : "ASH-RECOVERY-001"], summary: summary, notes: ["Correction and fallback are distinct policy actions; blocked recovery preserves the original state."], details: ASHDiagnosticObject(details), parent: chain.last)
    chain.append(record)
    return ASHOperationalRecoveryResult(recoveryCategory: category, outcome: outcome, preAssessment: before, postAssessment: after,
      targetState: target, replacementState: replacement, codewordID: wordID, fallbackPolicyID: policyID, diagnostics: chain)
  }
}
