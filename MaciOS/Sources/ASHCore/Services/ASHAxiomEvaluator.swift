import Foundation

public final class ASHAxiomEvaluator: ASHAxiomEvaluatorProtocol {
  public init() {}

  public func evaluate(subject: ASHAxiomSubject) -> ASHAxiomEvaluation {
    let results = [
      evaluateRelationalExistence(subject: subject),
      evaluateStructuralCompressibility(subject: subject),
      evaluateMultiScalePersistence(subject: subject),
      evaluateEnergeticCostOfErasure(subject: subject),
      evaluateSelfReference(subject: subject)
    ]

    let overallPass = results.allSatisfy(\.passed)
    let notes = results.map { result in
      let status = result.passed ? "PASS" : "FAIL"
      return "\(result.axiomID.rawValue): \(status) — \(result.explanation)"
    }

    return ASHAxiomEvaluation(
      subject: subject,
      results: results,
      overallPass: overallPass,
      notes: notes
    )
  }

  public func evaluate(state: ASHState) -> ASHAxiomEvaluation {
    evaluate(subject: ASHAxiomSubject.derived(from: state))
  }

  private func evaluateRelationalExistence(subject: ASHAxiomSubject) -> ASHAxiomCheckResult {
    let passed = subject.relationCount > 0
    let explanation = passed
      ? "relation_count=\(subject.relationCount) satisfies relation_count > 0"
      : "relation_count=\(subject.relationCount) violates relation_count > 0"

    return ASHAxiomCheckResult(
      axiomID: .relationalExistence,
      passed: passed,
      explanation: explanation,
      ruleIDs: ["ASH-STATE-AXIOM-001"]
    )
  }

  private func evaluateStructuralCompressibility(subject: ASHAxiomSubject) -> ASHAxiomCheckResult {
    let passed = subject.compressedMeasure < subject.rawMeasure
    let explanation = passed
      ? "compressed_measure=\(subject.compressedMeasure) is less than raw_measure=\(subject.rawMeasure)"
      : "compressed_measure=\(subject.compressedMeasure) is not less than raw_measure=\(subject.rawMeasure)"

    return ASHAxiomCheckResult(
      axiomID: .structuralCompressibility,
      passed: passed,
      explanation: explanation,
      ruleIDs: ["ASH-STATE-AXIOM-002"]
    )
  }

  private func evaluateMultiScalePersistence(subject: ASHAxiomSubject) -> ASHAxiomCheckResult {
    let passed = subject.scaleCount > 1
    let explanation = passed
      ? "scale_count=\(subject.scaleCount) satisfies scale_count > 1"
      : "scale_count=\(subject.scaleCount) violates scale_count > 1"

    return ASHAxiomCheckResult(
      axiomID: .multiScalePersistence,
      passed: passed,
      explanation: explanation,
      ruleIDs: ["ASH-STATE-AXIOM-003"]
    )
  }

  private func evaluateEnergeticCostOfErasure(subject: ASHAxiomSubject) -> ASHAxiomCheckResult {
    let passed = subject.erasureCost > 0
    let explanation = passed
      ? "erasure_cost=\(subject.erasureCost) satisfies erasure_cost > 0"
      : "erasure_cost=\(subject.erasureCost) violates erasure_cost > 0"

    return ASHAxiomCheckResult(
      axiomID: .energeticCostOfErasure,
      passed: passed,
      explanation: explanation,
      ruleIDs: ["ASH-STATE-AXIOM-004"]
    )
  }

  private func evaluateSelfReference(subject: ASHAxiomSubject) -> ASHAxiomCheckResult {
    let passed = subject.selfReferenceCapable && subject.selfModelAvailable
    let explanation = passed
      ? "self_reference_capable and self_model_available are both true"
      : "self_reference_capable=\(subject.selfReferenceCapable), self_model_available=\(subject.selfModelAvailable)"

    return ASHAxiomCheckResult(
      axiomID: .selfReferenceForConsciousness,
      passed: passed,
      explanation: explanation,
      ruleIDs: ["ASH-STATE-AXIOM-005"]
    )
  }
}
