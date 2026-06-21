import XCTest
@testable import ASHCore

final class ASHTransitionRegistryTests: XCTestCase {
  private let stateModel = ASHStateModel()

  func testAvailableTransitionsAreDeterministicAndNonEmptyForValidState() {
    let registry = ASHTransitionRegistry(stateModel: stateModel)

    let first = registry.availableTransitions(from: .zero)
    let second = registry.availableTransitions(from: .zero)

    XCTAssertEqual(first.count, 16)
    XCTAssertEqual(first, second)
  }

  func testCanonicalTransitionMatrixCoversEveryRealmAndCodeword() throws {
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    let codewords = stateModel.codewordSet.sorted()
    XCTAssertEqual(codewords.count, 16)

    var transitionCount = 0
    for rawValue in UInt16(0)..<ASHState.maxRawValue {
      let state = try XCTUnwrap(ASHState(rawValue: rawValue))
      let availableTransitions = registry.availableTransitions(from: state)
      XCTAssertEqual(availableTransitions.count, codewords.count)

      for codeword in codewords {
        let result = registry.applyCodeword(from: state, codeword: codeword)
        let applied = try XCTUnwrap(result.applied)

        XCTAssertEqual(applied.fromState, state)
        XCTAssertEqual(applied.codeword, codeword)
        XCTAssertEqual(applied.toState, state.xor(codeword))
        transitionCount += 1
      }
    }

    XCTAssertEqual(transitionCount, 8_192)
  }

  func testApplyCodewordTransitionAndInvolution() throws {
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    let codeword = stateModel.codewordSet
      .filter { $0 != .zero }
      .sorted()
      .first!

    let first = registry.applyCodeword(from: .zero, codeword: codeword)
    let firstApplied = try XCTUnwrap(first.applied)

    let second = registry.applyCodeword(from: firstApplied.toState, codeword: codeword)
    let secondApplied = try XCTUnwrap(second.applied)

    XCTAssertEqual(secondApplied.toState, .zero)
  }

  func testUnknownTransitionIDReturnsFailureDiagnostic() {
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    let result = registry.applyTransition(from: .zero, transitionID: "missing")

    let failure = try? XCTUnwrap(result.failureDiagnostic)
    XCTAssertEqual(failure?.reason, .transitionNotFound)
  }

  func testUnknownCodewordReturnsFailureDiagnostic() {
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    let unknownCodeword = ASHState(bitString: "000000001")!

    let result = registry.applyCodeword(from: .zero, codeword: unknownCodeword)
    let failure = try? XCTUnwrap(result.failureDiagnostic)

    XCTAssertEqual(failure?.reason, .codewordNotAllowed)
  }

  func testStateSpecificApplicabilityCanRejectTransition() {
    let registry = ASHTransitionRegistry(
      stateModel: stateModel,
      orderedTransitions: [
        ASHTransitionDefinition(
          transitionID: "restricted",
          displayName: "Restricted Transition",
          description: "Requires b0 to be set",
          codeword: .zero,
          applicability: .requireBitSet(0)
        )
      ]
    )

    let stateWithB0Clear = ASHState(bitString: "000000000")!
    let result = registry.applyTransition(from: stateWithB0Clear, transitionID: "restricted")
    let failure = try? XCTUnwrap(result.failureDiagnostic)

    XCTAssertEqual(failure?.reason, .transitionNotApplicable)
  }
}
