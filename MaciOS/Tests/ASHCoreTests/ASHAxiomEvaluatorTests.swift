import XCTest
@testable import ASHCore

final class ASHAxiomEvaluatorTests: XCTestCase {
  private let evaluator = ASHAxiomEvaluator()

  func testEvaluateSubjectProducesFiveExplainableResults() {
    let subject = ASHAxiomSubject(
      relationCount: 8,
      compressedMeasure: 3,
      rawMeasure: 8,
      scaleCount: 3,
      erasureCost: 2,
      selfReferenceCapable: true,
      selfModelAvailable: true
    )

    let evaluation = evaluator.evaluate(subject: subject)

    XCTAssertEqual(evaluation.results.count, ASHAxiomID.allCases.count)
    XCTAssertTrue(evaluation.overallPass)

    for result in evaluation.results {
      XCTAssertFalse(result.explanation.isEmpty)
      XCTAssertFalse(result.ruleIDs.isEmpty)
    }
  }

  func testEvaluateStateIsDeterministic() {
    let state = ASHState(bitString: "111100000")!

    let first = evaluator.evaluate(state: state)
    let second = evaluator.evaluate(state: state)

    XCTAssertEqual(first, second)
  }

  func testEvaluationFailsExpectedAxiomsForLowSignalSubject() {
    let subject = ASHAxiomSubject(
      relationCount: 0,
      compressedMeasure: 2,
      rawMeasure: 2,
      scaleCount: 1,
      erasureCost: 0,
      selfReferenceCapable: false,
      selfModelAvailable: true
    )

    let evaluation = evaluator.evaluate(subject: subject)

    XCTAssertFalse(evaluation.overallPass)
    XCTAssertEqual(
      Set(evaluation.results.filter { !$0.passed }.map(\.axiomID)),
      Set([
        .relationalExistence,
        .structuralCompressibility,
        .multiScalePersistence,
        .energeticCostOfErasure,
        .selfReferenceForConsciousness
      ])
    )
  }
}
