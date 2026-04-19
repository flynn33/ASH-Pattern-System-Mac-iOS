import XCTest
@testable import ASHCore

final class ASHRecoveryEngineTests: XCTestCase {
  private let stateModel = ASHStateModel()

  func testNormalizeStateRecoveryReturnsRecovered() {
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    let engine = ASHRecoveryEngine(
      stateModel: stateModel,
      transitionRegistry: registry
    )
    let compatibleState = ASHState(bitString: "111100000")!
    let diagnostic = stateModel.diagnose(compatibleState)
    let stateClass = stateModel.classifySystemState(
      for: diagnostic,
      context: ASHSystemContext(correctionPathKnown: false)
    )

    let resolution = engine.recover(
      diagnostic: diagnostic,
      stateClass: stateClass,
      recoveryCategory: .normalizeState
    )
    let recovery = resolution.recoveryDiagnostic

    XCTAssertEqual(recovery?.outcome, .recovered)
    XCTAssertEqual(recovery?.correctedState, .zero)
  }

  func testFallbackRecoveryUsesCanonicalRegistry() {
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    let engine = ASHRecoveryEngine(
      stateModel: stateModel,
      transitionRegistry: registry
    )
    let incompatibleState = ASHState(bitString: "000000001")!
    let diagnostic = stateModel.diagnose(incompatibleState)

    let resolution = engine.recover(
      diagnostic: diagnostic,
      stateClass: .degraded,
      recoveryCategory: .fallbackRequired
    )
    let recovery = resolution.recoveryDiagnostic

    XCTAssertEqual(recovery?.outcome, .recoveredViaFallback)
    XCTAssertEqual(recovery?.correctedState, .zero)
    XCTAssertNotNil(recovery?.fallbackPolicyID)
  }

  func testFallbackEscalatesToContainmentWhenRegistryHasNoCandidates() {
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    let engine = ASHRecoveryEngine(
      stateModel: stateModel,
      transitionRegistry: registry,
      fallbackPolicyRegistry: []
    )
    let incompatibleState = ASHState(bitString: "000000001")!
    let diagnostic = stateModel.diagnose(incompatibleState)

    let resolution = engine.recover(
      diagnostic: diagnostic,
      stateClass: .degraded,
      recoveryCategory: .fallbackRequired
    )
    let containment = resolution.containmentDiagnostic

    XCTAssertEqual(containment?.systemStateClass, .contained)
    XCTAssertEqual(containment?.trigger, .fallbackFailure)
  }

  func testEscalationRequiredTransitionsToSafeHalt() {
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    let engine = ASHRecoveryEngine(
      stateModel: stateModel,
      transitionRegistry: registry
    )
    let failedState = ASHState(bitString: "000000001")!
    let diagnostic = stateModel.diagnose(failedState)

    let resolution = engine.recover(
      diagnostic: diagnostic,
      stateClass: .failed,
      recoveryCategory: .escalationRequired
    )
    let safeHalt = resolution.safeHaltDiagnostic

    XCTAssertEqual(safeHalt?.systemStateClass, .safeHalt)
    XCTAssertEqual(safeHalt?.isTerminal, true)
  }
}
