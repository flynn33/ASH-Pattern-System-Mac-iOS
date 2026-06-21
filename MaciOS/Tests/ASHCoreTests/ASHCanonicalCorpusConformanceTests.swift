import Foundation
import XCTest
@testable import ASHCore

final class ASHCanonicalCorpusConformanceTests: XCTestCase {
  private let stateModel = ASHStateModel()

  func testCanonicalCodewordOrderingAndTransitionIdentifiers() throws {
    let codewordCorpus = try loadJSON("canonical-codewords.json", as: CanonicalCodewordCorpus.self)
    let transitionCorpus = try loadJSON("canonical-transitions.json", as: CanonicalTransitionCorpus.self)
    let codewordRecords = codewordCorpus.codewords.sorted { $0.orderingRank < $1.orderingRank }
    let transitionRecords = transitionCorpus.transitions.sorted { $0.orderingRank < $1.orderingRank }

    let codewords = stateModel.codewordSet.sorted()
    XCTAssertEqual(codewords.map(\.description), codewordRecords.map(\.signature))

    let registry = ASHTransitionRegistry(stateModel: stateModel)
    XCTAssertEqual(registry.orderedTransitions.count, codewordRecords.count)
    XCTAssertEqual(registry.orderedTransitions.count, transitionRecords.count)

    for (index, transition) in registry.orderedTransitions.enumerated() {
      let codewordRecord = codewordRecords[index]
      let transitionRecord = transitionRecords[index]

      XCTAssertEqual(transition.codeword.description, codewordRecord.signature)
      XCTAssertEqual(transition.transitionID, transitionRecord.transitionID)
      XCTAssertEqual(transition.displayName, "Codeword \(codewordRecord.codewordID)")
      XCTAssertEqual(transitionRecord.codewordID, codewordRecord.codewordID)
      XCTAssertEqual(transitionRecord.codewordSignature, codewordRecord.signature)
      XCTAssertEqual(transition.applicability, .always)
    }
  }

  func testCanonicalOrbitIdentifiersPartitionEveryRealm() throws {
    let realmCorpus = try loadJSON("canonical-realms.json", as: CanonicalRealmCorpus.self)
    let orbitCorpus = try loadJSON("canonical-orbits.json", as: CanonicalOrbitCorpus.self)

    var membersByOrbitID: [String: Set<ASHState>] = [:]
    var representativeByOrbitID: [String: ASHState] = [:]

    XCTAssertEqual(realmCorpus.realms.count, Int(ASHState.maxRawValue))

    for realmRecord in realmCorpus.realms {
      let state = try XCTUnwrap(ASHState(bitString: realmRecord.stateSignature))
      let orbitInfo = try XCTUnwrap(stateModel.diagnose(state).orbitInfo)
      let orbitID = try XCTUnwrap(orbitInfo.orbitID)
      let realmIdentity = try XCTUnwrap(ASHRealmEncoder(stateModel: stateModel).encode(state: state).identity)

      XCTAssertEqual(state.rawValue, UInt16(realmRecord.realmIndex))
      XCTAssertEqual(realmIdentity.realmID, realmRecord.realmID)
      XCTAssertEqual(realmIdentity.stateSignature, realmRecord.stateSignature)
      XCTAssertEqual(orbitID, realmRecord.orbitID)
      membersByOrbitID[orbitID, default: []].insert(state)
      representativeByOrbitID[orbitID] = orbitInfo.orbitRepresentative
    }

    XCTAssertEqual(membersByOrbitID.count, orbitCorpus.orbits.count)

    for orbitRecord in orbitCorpus.orbits.sorted(by: { $0.orderingRank < $1.orderingRank }) {
      let members = try XCTUnwrap(membersByOrbitID[orbitRecord.orbitID])
      let representative = try XCTUnwrap(representativeByOrbitID[orbitRecord.orbitID])
      let memberSignatures = Set(members.map(\.description))
      let expectedMemberSignatures = Set(orbitRecord.members.map(\.stateSignature))

      XCTAssertEqual(members.count, orbitRecord.memberCount)
      XCTAssertEqual(representative, members.sorted().first)
      XCTAssertEqual(representative.description, orbitRecord.representativeSignature)
      XCTAssertEqual(memberSignatures, expectedMemberSignatures)

      for member in members {
        let expectedOrbit = Set(stateModel.codewordSet.map { member.xor($0) })
        XCTAssertEqual(expectedOrbit, members)
      }
    }
  }

  func testCanonicalTransitionApplicationsUseRegisteredIdentifiers() throws {
    let transitionRecords = try loadJSON("canonical-transitions.json", as: CanonicalTransitionCorpus.self).transitions
    let transformations = try loadJSONLines("canonical-transformations.jsonl", as: CanonicalTransformationRecord.self)
    let registry = ASHTransitionRegistry(stateModel: stateModel)
    let codewordByID = Dictionary(
      uniqueKeysWithValues: transitionRecords.compactMap { record -> (String, ASHState)? in
        guard let codeword = ASHState(bitString: record.codewordSignature) else { return nil }
        return (record.codewordID, codeword)
      }
    )

    XCTAssertEqual(transformations.count, 8_192)
    XCTAssertEqual(codewordByID.count, 16)

    for transformation in transformations {
      let source = try XCTUnwrap(ASHState(bitString: transformation.sourceSignature))
      let codeword = try XCTUnwrap(codewordByID[transformation.codewordID])
      let result = registry.applyCodeword(from: source, codeword: codeword)
      let applied = try XCTUnwrap(result.applied)
      let targetOrbit = try XCTUnwrap(stateModel.diagnose(applied.toState).orbitInfo?.orbitID)

      XCTAssertEqual(applied.transitionID, transformation.transitionID)
      XCTAssertEqual(applied.fromState.description, transformation.sourceSignature)
      XCTAssertEqual(applied.toState.description, transformation.targetSignature)
      XCTAssertEqual(ASHRealmEncoder(stateModel: stateModel).encode(state: applied.fromState).identity?.realmID, transformation.sourceRealmID)
      XCTAssertEqual(ASHRealmEncoder(stateModel: stateModel).encode(state: applied.toState).identity?.realmID, transformation.targetRealmID)
      XCTAssertEqual(targetOrbit, transformation.targetOrbitID)
    }
  }

  func testPrimaryRecordsRoundTripThroughJSON() throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let decoder = JSONDecoder()

    let state = try XCTUnwrap(ASHState(bitString: "101010100"))
    try assertRoundTrip(state, encoder: encoder, decoder: decoder)

    let diagnostic = stateModel.diagnose(state)
    try assertRoundTrip(diagnostic, encoder: encoder, decoder: decoder)

    let realm = try XCTUnwrap(ASHRealmEncoder(stateModel: stateModel).encode(state: state).identity)
    try assertRoundTrip(realm, encoder: encoder, decoder: decoder)

    let transition = ASHTransitionRegistry(stateModel: stateModel).orderedTransitions[3]
    try assertRoundTrip(transition, encoder: encoder, decoder: decoder)

    let topologyNode = ASHTopologyNode(
      nodeID: "F-d0-o0",
      parentID: nil,
      depth: 0,
      ordinal: 0,
      branchKind: .root,
      pathToken: "F",
      state: state
    )
    try assertRoundTrip(topologyNode, encoder: encoder, decoder: decoder)

    let axiomEvaluation = ASHAxiomEvaluator().evaluate(state: state)
    try assertRoundTrip(axiomEvaluation, encoder: encoder, decoder: decoder)
  }

  private func assertRoundTrip<T: Codable & Equatable>(
    _ value: T,
    encoder: JSONEncoder,
    decoder: JSONDecoder,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    let data = try encoder.encode(value)
    let decoded = try decoder.decode(T.self, from: data)
    XCTAssertEqual(decoded, value, file: file, line: line)
  }

  private func loadJSON<T: Decodable>(_ fileName: String, as type: T.Type) throws -> T {
    let url = try fixtureURL(fileName)
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
  }

  private func loadJSONLines<T: Decodable>(_ fileName: String, as type: T.Type) throws -> [T] {
    let url = try fixtureURL(fileName)
    let contents = try String(contentsOf: url, encoding: .utf8)
    let decoder = JSONDecoder()
    return try contents.split(separator: "\n").map { line in
      try decoder.decode(T.self, from: Data(line.utf8))
    }
  }

  private func fixtureURL(_ fileName: String) throws -> URL {
    if let nestedURL = Bundle.module.url(
      forResource: fileName,
      withExtension: nil,
      subdirectory: "Fixtures/CanonicalReference"
    ) {
      return nestedURL
    }

    return try XCTUnwrap(Bundle.module.url(forResource: fileName, withExtension: nil))
  }
}

private struct CanonicalCodewordCorpus: Decodable {
  let codewords: [CanonicalCodewordRecord]
}

private struct CanonicalCodewordRecord: Decodable {
  let codewordID: String
  let orderingRank: Int
  let signature: String

  enum CodingKeys: String, CodingKey {
    case codewordID = "codeword_id"
    case orderingRank = "ordering_rank"
    case signature
  }
}

private struct CanonicalRealmCorpus: Decodable {
  let realms: [CanonicalRealmRecord]
}

private struct CanonicalRealmRecord: Decodable {
  let orbitID: String
  let realmID: String
  let realmIndex: Int
  let stateSignature: String

  enum CodingKeys: String, CodingKey {
    case orbitID = "orbit_id"
    case realmID = "realm_id"
    case realmIndex = "realm_index"
    case stateSignature = "state_signature"
  }
}

private struct CanonicalOrbitCorpus: Decodable {
  let orbits: [CanonicalOrbitRecord]
}

private struct CanonicalOrbitRecord: Decodable {
  let memberCount: Int
  let members: [CanonicalOrbitMemberRecord]
  let orbitID: String
  let orderingRank: Int
  let representativeSignature: String

  enum CodingKeys: String, CodingKey {
    case memberCount = "member_count"
    case members
    case orbitID = "orbit_id"
    case orderingRank = "ordering_rank"
    case representativeSignature = "representative_signature"
  }
}

private struct CanonicalOrbitMemberRecord: Decodable {
  let stateSignature: String

  enum CodingKeys: String, CodingKey {
    case stateSignature = "state_signature"
  }
}

private struct CanonicalTransitionCorpus: Decodable {
  let transitions: [CanonicalTransitionRecord]
}

private struct CanonicalTransitionRecord: Decodable {
  let codewordID: String
  let codewordSignature: String
  let orderingRank: Int
  let transitionID: String

  enum CodingKeys: String, CodingKey {
    case codewordID = "codeword_id"
    case codewordSignature = "codeword_signature"
    case orderingRank = "ordering_rank"
    case transitionID = "transition_id"
  }
}

private struct CanonicalTransformationRecord: Decodable {
  let codewordID: String
  let sourceOrbitID: String
  let sourceRealmID: String
  let sourceSignature: String
  let targetOrbitID: String
  let targetRealmID: String
  let targetSignature: String
  let transitionID: String

  enum CodingKeys: String, CodingKey {
    case codewordID = "codeword_id"
    case sourceOrbitID = "source_orbit_id"
    case sourceRealmID = "source_realm_id"
    case sourceSignature = "source_signature"
    case targetOrbitID = "target_orbit_id"
    case targetRealmID = "target_realm_id"
    case targetSignature = "target_signature"
    case transitionID = "transition_id"
  }
}
