import Foundation

public final class ASHAxiomEvaluator: ASHAxiomEvaluatorProtocol {
  public init() {}
  public func evaluate(subject: ASHAxiomSubject) -> ASHAxiomEvaluation {
    func check(_ id: ASHAxiomID, _ measured: Bool?, _ explanation: String, _ rule: String) -> ASHAxiomCheckResult {
      ASHAxiomCheckResult(axiomID: id, status: measured.map { $0 ? .pass : .fail } ?? .indeterminate,
        explanation: measured == nil ? "Required measurement is absent or outside its nonnegative domain." : explanation, ruleIDs: [rule])
    }
    func nonnegative(_ value: Int?) -> Int? { value.flatMap { $0 >= 0 ? $0 : nil } }
    let compressed = nonnegative(subject.compressedMeasure), raw = nonnegative(subject.rawMeasure)
    let relational = nonnegative(subject.relationCount).map { $0 > 0 }
    let structural: Bool? = compressed.flatMap { c in raw.map { c < $0 } }
    let persistence = nonnegative(subject.scaleCount).map { $0 > 1 }
    let erasure = nonnegative(subject.erasureCost).map { $0 > 0 }
    let selfReference: Bool? = subject.selfReferenceCapable.flatMap { c in subject.selfModelAvailable.map { c && $0 } }
    let results = [
      check(.relationalExistence, relational, "relation_count > 0", "ASH-AXIOM-001"),
      check(.structuralCompressibility, structural, "compressed_measure < raw_measure", "ASH-AXIOM-002"),
      check(.multiScalePersistence, persistence, "scale_count > 1", "ASH-AXIOM-003"),
      check(.energeticCostOfErasure, erasure, "erasure_cost > 0", "ASH-AXIOM-004"),
      check(.selfReferenceForConsciousness, selfReference, "self_reference_capable AND self_model_available", "ASH-AXIOM-005")
    ]
    return ASHAxiomEvaluation(subject: subject, results: results, overallPass: results.allSatisfy(\.passed),
      notes: results.map { "\($0.axiomID.rawValue): \($0.status.rawValue) — \($0.explanation)" })
  }
  public func evaluate(state: ASHState) -> ASHAxiomEvaluation { evaluate(subject: .derived(from: state)) }
}
