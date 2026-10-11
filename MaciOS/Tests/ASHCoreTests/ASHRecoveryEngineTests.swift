import XCTest
import ASHCore

final class ASHRecoveryEngineTests: XCTestCase {
  private let model = ASHStateModel()
  private func engine() -> ASHRecoveryEngine { ASHRecoveryEngine(stateModel:model,transitionRegistry:ASHTransitionRegistry(stateModel:model)) }
  func testCorrectionRecordsExactSameOrbitTargetAndPostAssessment() throws {
    let current = try XCTUnwrap(ASHState(bitString:"000011110")), context = ASHOperationalContext(contextID:"correction",allowedStableStates:[.zero])
    let result = engine().recover(state:current,context:context)
    XCTAssertEqual(result.recoveryCategory,.applyCorrection); XCTAssertEqual(result.outcome,.recovered)
    XCTAssertEqual(result.targetState,.zero); XCTAssertNil(result.replacementState); XCTAssertEqual(result.codewordID,"APS-CW-01")
    XCTAssertEqual(result.preAssessment.state,current); XCTAssertEqual(result.postAssessment?.stateClass,.stable)
    XCTAssertEqual(result.diagnostics.count,2)
  }
  func testAmbiguityBlocksWithoutNearestNeighborMutation() throws {
    let current = try XCTUnwrap(ASHState(bitString:"000011110")), other = try XCTUnwrap(ASHState(bitString:"001100110"))
    let result = engine().recover(state:current,context:ASHOperationalContext(contextID:"ambiguous",allowedStableStates:[.zero,other]))
    XCTAssertEqual(result.outcome,.targetResolutionBlocked); XCTAssertEqual(result.resultingState,current); XCTAssertNil(result.targetState)
  }
  func testFallbackOrdersRankThenRealmAndReassessesWithoutCodewordMotion() throws {
    let current = try XCTUnwrap(ASHState(rawValue:1)), codeword = try XCTUnwrap(ASHState(bitString:"000011110"))
    let instance = ASHFallbackPolicyInstance(policy:.declaredKnownGood,candidates:[.init(state:codeword,configuredRank:2,evidence:"declared"),.init(state:.zero,configuredRank:2,evidence:"declared")])
    let context = ASHOperationalContext(contextID:"fallback",allowedStableStates:[.zero],fallbackPolicyInstance:instance)
    let result = engine().recover(state:current,context:context)
    XCTAssertEqual(result.outcome,.recoveredViaFallbackReplacement); XCTAssertEqual(result.replacementState,.zero)
    XCTAssertNil(result.codewordID); XCTAssertNil(result.targetState); XCTAssertEqual(result.fallbackPolicyID,"FALLBACK-STATE-001")
    XCTAssertFalse(model.isReachable(from:current,to:try XCTUnwrap(result.replacementState)))
  }
  func testLastVerifiedOrdersDescendingSequenceAndPermitsCorrectableReplacement() throws {
    let current = try XCTUnwrap(ASHState(rawValue:1)), codeword = try XCTUnwrap(ASHState(bitString:"000011110"))
    let policy = ASHFallbackPolicyInstance(policy:.lastVerifiedStable,candidates:[.init(state:.zero,verificationSequence:1,evidence:"verified"),.init(state:codeword,verificationSequence:9,evidence:"verified")])
    let result = engine().recover(state:current,context:ASHOperationalContext(contextID:"history",allowedStableStates:[.zero],fallbackPolicyInstance:policy))
    XCTAssertEqual(result.replacementState,codeword); XCTAssertEqual(result.postAssessment?.stateClass,.correctable)
    XCTAssertEqual(result.outcome,.recoveredViaFallbackReplacement)
  }
  func testFallbackAbsentInvalidOrFailedCandidateEscalatesWithEvidence() throws {
    let current = try XCTUnwrap(ASHState(rawValue:1))
    let empty = engine().recover(state:current,context:ASHOperationalContext(contextID:"empty",allowedStableStates:[.zero]))
    XCTAssertEqual(empty.outcome,.escalateToContainment); XCTAssertEqual(empty.resultingState,current)
    let failedCandidate = ASHFallbackPolicyInstance(policy:.declaredKnownGood,candidates:[.init(state:current,evidence:"declared")])
    let result = engine().recover(state:current,context:ASHOperationalContext(contextID:"failed",allowedStableStates:[.zero],fallbackPolicyInstance:failedCandidate))
    XCTAssertEqual(result.outcome,.escalateToContainment); XCTAssertEqual(result.diagnostics.last?.details["candidate_evidence"],.string("declared"))
    XCTAssertEqual(result.resultingState,current); XCTAssertNil(result.replacementState)
    XCTAssertEqual(result.postAssessment?.state,current); XCTAssertEqual(result.postAssessment?.stateClass,.degraded)
    XCTAssertEqual(result.diagnostics.last?.details["attempted_candidate"],.string(current.description))
    XCTAssertEqual(result.diagnostics.last?.details["post_state_class"],.string("DEGRADED"))
    guard case .object(let post)? = result.diagnostics.last?.details["post_assessment"] else { return XCTFail("Failed reassessment must be preserved by value.") }
    XCTAssertEqual(post["state_signature"],.string(current.description))
    XCTAssertThrowsError(try ASHOperationalContext(contextID:"invalid",allowedStableStates:[.zero],fallbackPolicyInstance:.init(policy:.lastVerifiedStable,candidates:[.init(state:.zero,evidence:"verified")])).validate())
  }
  func testFailedAwaitsExternalAuthorityWithoutAutomaticHalt() throws {
    let result = engine().recover(state:.zero,context:ASHOperationalContext(contextID:"failed",allowedStableStates:[.zero]),runtime:.failed)
    XCTAssertEqual(result.recoveryCategory,.externalEscalationRequired); XCTAssertEqual(result.outcome,.targetResolutionBlocked)
    XCTAssertEqual(result.resultingState,.zero); XCTAssertFalse(result.diagnostics.contains { $0.diagnosticKind == .safeHalt })
  }
}
