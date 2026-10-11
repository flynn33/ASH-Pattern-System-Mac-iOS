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

  func testMalformedInjectedRegistriesThrowInsteadOfTrapping() throws {
    let canonical = ASHTransitionRegistry(stateModel: stateModel).orderedTransitions
    for invalid in [[], Array(canonical.dropLast()), canonical + [canonical[0]], [canonical[0], canonical[0]]] {
      XCTAssertThrowsError(try ASHTransitionRegistry(stateModel: stateModel, validatingTransitions: invalid))
    }
    var duplicateID = canonical
    duplicateID[1] = ASHTransitionDefinition(transitionID: canonical[0].transitionID, displayName: "Duplicate", description: "Contradictory ID", codeword: canonical[1].codeword)
    XCTAssertThrowsError(try ASHTransitionRegistry(stateModel: stateModel, validatingTransitions: duplicateID))
    var arbitraryWord = canonical
    arbitraryWord[0] = ASHTransitionDefinition(transitionID: canonical[0].transitionID, displayName: "Wrong word", description: "Not canonical", codeword: ASHState(rawValue: 1)!)
    XCTAssertThrowsError(try ASHTransitionRegistry(stateModel: stateModel, validatingTransitions: arbitraryWord))
    var alteredApplicability = canonical
    alteredApplicability[0] = ASHTransitionDefinition(transitionID: canonical[0].transitionID, displayName: "Altered applicability", description: "Not the canonical registry", codeword: .zero, applicability: .requireBitSet(-1))
    XCTAssertThrowsError(try ASHTransitionRegistry(stateModel: stateModel, validatingTransitions: alteredApplicability))
    XCTAssertFalse(ASHTransitionApplicability.requireBitSet(-1).isApplicable(to: .zero))
    let reordered = try ASHTransitionRegistry(stateModel: stateModel, validatingTransitions: Array(canonical.reversed()))
    XCTAssertEqual(reordered.orderedTransitions, canonical)
  }
}
