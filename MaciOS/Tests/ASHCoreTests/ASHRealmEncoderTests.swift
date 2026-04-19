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
    XCTAssertEqual(first.realmID, "ASH-RLM-000000000")
  }

  func testEncodeRejectsNonValidState() {
    let encoder = ASHRealmEncoder(stateModel: stateModel)
    let nonValidState = ASHState(bitString: "111100000")!

    let result = encoder.encode(state: nonValidState)
    let failure = try? XCTUnwrap(result.failureDiagnostic)

    XCTAssertEqual(failure?.reason, .invalidInputState)
  }
}
