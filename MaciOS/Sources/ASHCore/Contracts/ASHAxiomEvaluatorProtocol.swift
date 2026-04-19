import Foundation

public protocol ASHAxiomEvaluatorProtocol: AnyObject {
  func evaluate(subject: ASHAxiomSubject) -> ASHAxiomEvaluation
  func evaluate(state: ASHState) -> ASHAxiomEvaluation
}
