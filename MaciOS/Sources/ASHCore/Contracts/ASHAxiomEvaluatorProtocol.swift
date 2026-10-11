import Foundation

public protocol ASHAxiomEvaluatorProtocol: AnyObject, Sendable {
  func evaluate(subject: ASHAxiomSubject) -> ASHAxiomEvaluation
  func evaluate(state: ASHState) -> ASHAxiomEvaluation
}
