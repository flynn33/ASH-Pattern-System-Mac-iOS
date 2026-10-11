import Foundation
import XCTest
import ASHCore

final class ASHStateDecodingTests: XCTestCase {
  func testAll512StatesRoundTripWithoutChangingWireShape() throws {
    for value in UInt16(0)..<512 {
      let state = try XCTUnwrap(ASHState(rawValue: value))
      let data = try JSONEncoder().encode(state)
      XCTAssertEqual(try JSONDecoder().decode(ASHState.self, from: data), state)
      XCTAssertEqual(try JSONSerialization.jsonObject(with: data) as? [String: Int], ["rawValue": Int(value)])
    }
  }

  func testMalformedRepresentationsThrowAtStateBoundary() {
    let invalid = ["{\"rawValue\":512}", "{\"rawValue\":65535}", "{\"rawValue\":-1}", "{\"rawValue\":0.5}", "{}", "{\"rawValue\":null}", "{\"rawValue\":\"1\"}", "{\"rawValue\":true}"]
    for json in invalid {
      XCTAssertThrowsError(try JSONDecoder().decode(ASHState.self, from: Data(json.utf8)), json)
    }
  }

  func testBitStringBoundaryRefusesOversizedAndNonASCIIInput() {
    for input in [String(repeating:"0",count:1_000_000), String(repeating:"𝟎",count:9), "00000000é", "00000000", "0000000000", "000000002"] {
      XCTAssertNil(ASHState(bitString:input))
      XCTAssertTrue(ASHStateModel().assess(bitString:input,context:nil).assessmentBlocked)
    }
    XCTAssertEqual(ASHState(bitString:"000000000"),.zero)
  }

  func testInvalidNestedAndCorruptedSavedStatesThrow() throws {
    let model = ASHStateModel()
    let state = ASHState.zero
    try rejectsNestedState(model.diagnose(state))
    try rejectsNestedState(ASHTransitionRegistry(stateModel: model).orderedTransitions[0])
    try rejectsNestedState(ASHTopologyNode(nodeID: "root", parentID: nil, depth: 0, ordinal: 0, branchKind: .root, pathToken: "R", state: state))
    let data = try JSONEncoder().encode(model.diagnose(state))
    XCTAssertThrowsError(try JSONDecoder().decode(StateValidityDiagnostic.self, from: Data(data.dropLast())))
  }

  func testXORIsClosedForEveryStatePair() throws {
    for left in UInt16(0)..<512 {
      let lhs = try XCTUnwrap(ASHState(rawValue: left))
      for right in UInt16(0)..<512 {
        let rhs = try XCTUnwrap(ASHState(rawValue: right))
        let result = lhs.xor(rhs)
        XCTAssertEqual(result.rawValue, left ^ right)
        XCTAssertLessThan(result.rawValue, 512)
      }
    }
  }

  private func rejectsNestedState<T: Codable & Equatable>(_ value: T) throws {
    let data = try JSONEncoder().encode(value)
    XCTAssertEqual(try JSONDecoder().decode(T.self, from: data), value)
    let json = try XCTUnwrap(String(data: data, encoding: .utf8))
    XCTAssertTrue(json.contains("\"rawValue\":0"))
    let corrupted = json.replacingOccurrences(of: "\"rawValue\":0", with: "\"rawValue\":512")
    XCTAssertThrowsError(try JSONDecoder().decode(T.self, from: Data(corrupted.utf8)))
  }
}
