import XCTest
import ASHCore

final class ASHStateModelTests: XCTestCase {
  private let model = ASHStateModel()
  func testCanonicalCodewordSetMatchesBaselineProperties() {
    XCTAssertEqual(model.codewordSet.count,16)
    for word in model.codewordSet { XCTAssertEqual(word.bits.count,9); XCTAssertEqual(word.b8,0); XCTAssertEqual(word.hammingWeight()%4,0) }
    XCTAssertThrowsError(try ASHStateModel(validatingCodewordSet:[.zero]))
  }
  func testDefaultStateSpaceCoversAllWellFormedRealms() throws {
    XCTAssertEqual(model.knownValidStates.count,512)
    var representatives:Set<ASHState> = []
    for raw in UInt16(0)..<512 {
      let state = try XCTUnwrap(ASHState(rawValue:raw)), diagnostic = model.diagnose(try XCTUnwrap(ASHState(rawValue:raw)))
      XCTAssertTrue(model.isValid(state)); XCTAssertEqual(model.normalize(state),state)
      XCTAssertEqual(diagnostic.admissibilityStatus,.valid); XCTAssertEqual(diagnostic.normalizationStatus,.alreadyValid)
      XCTAssertEqual(diagnostic.orbitInfo?.orbitSize,16)
      representatives.insert(try XCTUnwrap(diagnostic.orbitInfo?.orbitRepresentative))
    }
    XCTAssertEqual(representatives.count,32)
  }
  func testCompatibleAndDifferentOrbitStatesBothNormalizeWithoutRealmMutation() throws {
    for signature in ["111100000","000000001"] {
      let state = try XCTUnwrap(ASHState(bitString:signature))
      XCTAssertEqual(model.normalize(state),state)
      XCTAssertTrue(model.diagnose(state).isValid)
    }
  }
  func testSystemStateClassificationAndRecoveryMapping() throws {
    let correction = try XCTUnwrap(ASHState(bitString:"000011110")), other = try XCTUnwrap(ASHState(bitString:"001100110"))
    let unique = ASHOperationalContext(contextID:"unique", allowedStableStates:[.zero])
    let ambiguous = ASHOperationalContext(contextID:"ambiguous", allowedStableStates:[.zero,other])
    XCTAssertEqual(model.assess(state:.zero,context:unique).stateClass,.stable)
    XCTAssertEqual(model.assess(state:correction,context:unique).stateClass,.correctable)
    XCTAssertEqual(model.assess(state:correction,context:unique).correctionCodewordID,"APS-CW-01")
    let uncertain = model.assess(state:correction,context:ambiguous)
    XCTAssertEqual(uncertain.stateClass,.unstable); XCTAssertNil(uncertain.selectedTarget)
    XCTAssertEqual(uncertain.recoveryCategory,.targetResolutionRequired)
    XCTAssertEqual(model.assess(state:try XCTUnwrap(ASHState(rawValue:1)),context:unique).stateClass,.degraded)
    for (runtime, classification, category) in [(ASHRuntimeMode.contained,SystemStateClass.contained,RecoveryCategory.containmentActive),(.failed,.failed,.externalEscalationRequired),(.safeHalt,.safeHalt,.terminalNoRecovery)] {
      let result = model.assess(state:correction,context:unique,runtime:runtime)
      XCTAssertEqual(result.stateClass,classification); XCTAssertEqual(result.recoveryCategory,category)
    }
    let preferred = ASHOperationalContext(contextID:"preferred",allowedStableStates:[other,.zero],preferredState:other)
    XCTAssertEqual(model.assess(state:correction,context:preferred).selectedTarget,other)
  }
  func testMalformedAndInvalidContextNeverReceiveOperationalClass() throws {
    let good = ASHOperationalContext(contextID:"good",allowedStableStates:[.zero])
    let malformed = model.assess(bitString:"0101",context:good)
    XCTAssertEqual(malformed.inputStatus,.malformed); XCTAssertTrue(malformed.assessmentBlocked); XCTAssertNil(malformed.stateClass)
    for context in [nil, ASHOperationalContext(contextID:"empty",allowedStableStates:[]), ASHOperationalContext(contextID:"bad-version",allowedStableStates:[.zero], registryVersions:[:])] {
      XCTAssertTrue(model.assess(state:.zero,context:context).assessmentBlocked)
    }
  }
  func testReachabilityAndExactAveragingIncludingNumericalBoundaries() throws {
    let one = Dictionary(uniqueKeysWithValues:model.knownValidStates.map { ($0,Int64(1)) })
    XCTAssertEqual(try model.average(at:.zero,values:one),ASHRationalAverage(numerator:16))
    let overflow = Dictionary(uniqueKeysWithValues:model.reachableStates(from:.zero).map { ($0,Int64.max) })
    XCTAssertThrowsError(try model.average(at:.zero,values:overflow))
    XCTAssertThrowsError(try model.average(at:.zero,values:[: ] as [ASHState:Int64]))
    let nonfinite = Dictionary(uniqueKeysWithValues:model.reachableStates(from:.zero).map { ($0,Double.infinity) })
    XCTAssertThrowsError(try model.average(at:.zero,values:nonfinite))
  }
}
