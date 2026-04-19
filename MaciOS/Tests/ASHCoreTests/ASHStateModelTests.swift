import XCTest
@testable import ASHCore

final class ASHStateModelTests: XCTestCase {
  private let model = ASHStateModel()

  func testCanonicalCodewordSetMatchesBaselineProperties() {
    XCTAssertEqual(model.codewordSet.count, 16)

    for codeword in model.codewordSet {
      XCTAssertEqual(codeword.bits.count, 9)
      XCTAssertEqual(codeword.b8, 0)
      XCTAssertEqual(codeword.hammingWeight() % 4, 0)
    }
  }

  func testAdmissibilityAndNormalizationForCompatibleState() {
    let compatible = ASHState(bits: [1, 1, 1, 1, 0, 0, 0, 0, 0])!
    let diagnostic = model.diagnose(compatible)

    XCTAssertEqual(diagnostic.admissibilityStatus, .transformationCompatible)
    XCTAssertEqual(diagnostic.transformationCompatibility, .compatible)
    XCTAssertEqual(diagnostic.normalizationStatus, .normalizable)
    XCTAssertEqual(diagnostic.recoverabilityRelevance, .recoveryApplicable)
    XCTAssertFalse(diagnostic.isValid)

    XCTAssertEqual(model.normalize(compatible), .zero)
  }

  func testIncompatibleStateProducesNotRecoverableDiagnostic() {
    let incompatible = ASHState(bits: [0, 0, 0, 0, 0, 0, 0, 0, 1])!
    let diagnostic = model.diagnose(incompatible)

    XCTAssertEqual(diagnostic.admissibilityStatus, .transformationIncompatible)
    XCTAssertEqual(diagnostic.transformationCompatibility, .incompatible)
    XCTAssertEqual(diagnostic.normalizationStatus, .notNormalizable)
    XCTAssertEqual(diagnostic.recoverabilityRelevance, .notRecoverable)
    XCTAssertNil(model.normalize(incompatible))
  }

  func testSystemStateClassificationAndRecoveryMapping() {
    let stableDiagnostic = model.diagnose(.zero)
    let stableState = model.classifySystemState(
      for: stableDiagnostic,
      context: ASHSystemContext()
    )
    XCTAssertEqual(stableState, .stable)
    XCTAssertEqual(model.classifyRecovery(for: stableState), .noAction)

    let compatible = ASHState(bits: [1, 1, 1, 1, 0, 0, 0, 0, 0])!
    let compatibleDiagnostic = model.diagnose(compatible)

    let unstableState = model.classifySystemState(
      for: compatibleDiagnostic,
      context: ASHSystemContext(correctionPathKnown: false)
    )
    XCTAssertEqual(unstableState, .unstable)
    XCTAssertEqual(model.classifyRecovery(for: unstableState), .normalizeState)

    let correctableState = model.classifySystemState(
      for: compatibleDiagnostic,
      context: ASHSystemContext(correctionPathKnown: true)
    )
    XCTAssertEqual(correctableState, .correctable)
    XCTAssertEqual(model.classifyRecovery(for: correctableState), .applyCorrection)

    let incompatible = ASHState(bits: [0, 0, 0, 0, 0, 0, 0, 0, 1])!
    let incompatibleDiagnostic = model.diagnose(incompatible)

    let degradedState = model.classifySystemState(
      for: incompatibleDiagnostic,
      context: ASHSystemContext(fallbackAvailable: true)
    )
    XCTAssertEqual(degradedState, .degraded)
    XCTAssertEqual(model.classifyRecovery(for: degradedState), .fallbackRequired)

    let failedState = model.classifySystemState(
      for: incompatibleDiagnostic,
      context: ASHSystemContext(fallbackAvailable: false)
    )
    XCTAssertEqual(failedState, .failed)
    XCTAssertEqual(model.classifyRecovery(for: failedState), .escalationRequired)

    let containedState = model.classifySystemState(
      for: incompatibleDiagnostic,
      context: ASHSystemContext(isInContainment: true)
    )
    XCTAssertEqual(containedState, .contained)
    XCTAssertEqual(model.classifyRecovery(for: containedState), .containmentRequired)

    let safeHaltState = model.classifySystemState(
      for: incompatibleDiagnostic,
      context: ASHSystemContext(isInSafeHalt: true)
    )
    XCTAssertEqual(safeHaltState, .safeHalt)
    XCTAssertEqual(model.classifyRecovery(for: safeHaltState), .terminalNoRecovery)
  }
}
