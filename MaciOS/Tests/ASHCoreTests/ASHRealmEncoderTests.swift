import XCTest
@testable import ASHCore

final class ASHRealmEncoderTests: XCTestCase {
  private let stateModel = ASHStateModel()

  func testEncodeValidStateIsDeterministic() throws {
    let encoder = ASHRealmEncoder(stateModel: stateModel)

    let first = try XCTUnwrap(encoder.encode(state: .zero).identity)
    let second = try XCTUnwrap(encoder.encode(state: .zero).identity)

    XCTAssertEqual(first, second)
    XCTAssertEqual(first.stateSignature, "000000000")
    XCTAssertEqual(first.realmID, "APS-REALM-000")
  }

  func testEncodeCoversCanonicalRealmIdentifiers() throws {
    let encoder = ASHRealmEncoder(stateModel: stateModel)

    var realmIDs: Set<String> = []
    for rawValue in UInt16(0)..<ASHState.maxRawValue {
      let state = try XCTUnwrap(ASHState(rawValue: rawValue))
      let identity = try XCTUnwrap(encoder.encode(state: state).identity)

      XCTAssertEqual(identity.stateSignature, state.description)
      XCTAssertEqual(identity.realmID, String(format: "APS-REALM-%03d", rawValue))
      realmIDs.insert(identity.realmID)
    }

    XCTAssertEqual(realmIDs.count, Int(ASHState.maxRawValue))
  }

  func testEncodeRejectsStateOutsideConfiguredValidSet() {
    let restrictedStateModel = ASHStateModel(knownValidStates: [.zero])
    let encoder = ASHRealmEncoder(stateModel: restrictedStateModel)
    let stateOutsideConfiguredSet = ASHState(bitString: "111100000")!

    let result = encoder.encode(state: stateOutsideConfiguredSet)
    let failure = try? XCTUnwrap(result.failureDiagnostic)

    XCTAssertEqual(failure?.reason, .invalidInputState)
  }
}
