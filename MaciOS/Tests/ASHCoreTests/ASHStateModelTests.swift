import XCTest
@testable import ASHCore

final class ASHStateModelTests: XCTestCase {
  private let model = ASHStateModel()
  private let restrictedModel = ASHStateModel(knownValidStates: [.zero])

  func testCanonicalCodewordSetMatchesBaselineProperties() {
    XCTAssertEqual(model.codewordSet.count, 16)

    for codeword in model.codewordSet {
      XCTAssertEqual(codeword.bits.count, 9)
      XCTAssertEqual(codeword.b8, 0)
      XCTAssertEqual(codeword.hammingWeight() % 4, 0)
    }
  }

  func testDefaultStateSpaceCoversAllWellFormedRealms() throws {
    XCTAssertEqual(model.knownValidStates.count, Int(ASHState.maxRawValue))

    var orbitRepresentatives: Set<ASHState> = []
    for rawValue in UInt16(0)..<ASHState.maxRawValue {
      let state = try XCTUnwrap(ASHState(rawValue: rawValue))
      let diagnostic = model.diagnose(state)

      XCTAssertTrue(model.isValid(state))
      XCTAssertEqual(model.normalize(state), state)
      XCTAssertEqual(diagnostic.admissibilityStatus, .valid)
      XCTAssertEqual(diagnostic.normalizationStatus, .alreadyValid)
      XCTAssertEqual(diagnostic.orbitInfo?.orbitSize, 16)

      if let representative = diagnostic.orbitInfo?.orbitRepresentative {
        orbitRepresentatives.insert(representative)
      }
    }

    XCTAssertEqual(orbitRepresentatives.count, 32)
  }

  func testAdmissibilityAndNormalizationForCompatibleState() {
    let compatible = ASHState(bits: [1, 1, 1, 1, 0, 0, 0, 0, 0])!
    let diagnostic = restrictedModel.diagnose(compatible)

    XCTAssertEqual(diagnostic.admissibilityStatus, .transformationCompatible)
    XCTAssertEqual(diagnostic.transformationCompatibility, .compatible)
    XCTAssertEqual(diagnostic.normalizationStatus, .normalizable)
    XCTAssertEqual(diagnostic.recoverabilityRelevance, .recoveryApplicable)
    XCTAssertFalse(diagnostic.isValid)

    XCTAssertEqual(restrictedModel.normalize(compatible), .zero)
  }

  func testIncompatibleStateProducesNotRecoverableDiagnostic() {
    let incompatible = ASHState(bits: [0, 0, 0, 0, 0, 0, 0, 0, 1])!
    let diagnostic = restrictedModel.diagnose(incompatible)

    XCTAssertEqual(diagnostic.admissibilityStatus, .transformationIncompatible)
    XCTAssertEqual(diagnostic.transformationCompatibility, .incompatible)
    XCTAssertEqual(diagnostic.normalizationStatus, .notNormalizable)
    XCTAssertEqual(diagnostic.recoverabilityRelevance, .notRecoverable)
    XCTAssertNil(restrictedModel.normalize(incompatible))
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
    let compatibleDiagnostic = restrictedModel.diagnose(compatible)

    let unstableState = restrictedModel.classifySystemState(
      for: compatibleDiagnostic,
      context: ASHSystemContext(correctionPathKnown: false)
    )
    XCTAssertEqual(unstableState, .unstable)
    XCTAssertEqual(restrictedModel.classifyRecovery(for: unstableState), .normalizeState)

    let correctableState = restrictedModel.classifySystemState(
      for: compatibleDiagnostic,
      context: ASHSystemContext(correctionPathKnown: true)
    )
    XCTAssertEqual(correctableState, .correctable)
    XCTAssertEqual(restrictedModel.classifyRecovery(for: correctableState), .applyCorrection)

    let incompatible = ASHState(bits: [0, 0, 0, 0, 0, 0, 0, 0, 1])!
    let incompatibleDiagnostic = restrictedModel.diagnose(incompatible)

    let degradedState = restrictedModel.classifySystemState(
      for: incompatibleDiagnostic,
      context: ASHSystemContext(fallbackAvailable: true)
    )
    XCTAssertEqual(degradedState, .degraded)
    XCTAssertEqual(restrictedModel.classifyRecovery(for: degradedState), .fallbackRequired)

    let failedState = restrictedModel.classifySystemState(
      for: incompatibleDiagnostic,
      context: ASHSystemContext(fallbackAvailable: false)
    )
    XCTAssertEqual(failedState, .failed)
    XCTAssertEqual(restrictedModel.classifyRecovery(for: failedState), .escalationRequired)

    let containedState = restrictedModel.classifySystemState(
      for: incompatibleDiagnostic,
      context: ASHSystemContext(isInContainment: true)
    )
    XCTAssertEqual(containedState, .contained)
    XCTAssertEqual(restrictedModel.classifyRecovery(for: containedState), .containmentRequired)

    let safeHaltState = restrictedModel.classifySystemState(
      for: incompatibleDiagnostic,
      context: ASHSystemContext(isInSafeHalt: true)
    )
    XCTAssertEqual(safeHaltState, .safeHalt)
    XCTAssertEqual(restrictedModel.classifyRecovery(for: safeHaltState), .terminalNoRecovery)
  }
}
