import Foundation

public enum ASHAxiomID: String, CaseIterable, Codable, Sendable {
  case relationalExistence = "A1_RELATIONAL_EXISTENCE"
  case structuralCompressibility = "A2_STRUCTURAL_COMPRESSIBILITY"
  case multiScalePersistence = "A3_MULTI_SCALE_PERSISTENCE"
  case energeticCostOfErasure = "A4_ENERGETIC_COST_OF_ERASURE"
  case selfReferenceForConsciousness = "A5_SELF_REFERENCE_FOR_CONSCIOUSNESS"
}

public struct ASHAxiomSubject: Codable, Hashable, Sendable {
  public let relationCount: Int
  public let compressedMeasure: Int
  public let rawMeasure: Int
  public let scaleCount: Int
  public let erasureCost: Int
  public let selfReferenceCapable: Bool
  public let selfModelAvailable: Bool

  public init(
    relationCount: Int,
    compressedMeasure: Int,
    rawMeasure: Int,
    scaleCount: Int,
    erasureCost: Int,
    selfReferenceCapable: Bool,
    selfModelAvailable: Bool
  ) {
    self.relationCount = relationCount
    self.compressedMeasure = compressedMeasure
    self.rawMeasure = rawMeasure
    self.scaleCount = scaleCount
    self.erasureCost = erasureCost
    self.selfReferenceCapable = selfReferenceCapable
    self.selfModelAvailable = selfModelAvailable
  }

  public static func derived(from state: ASHState) -> ASHAxiomSubject {
    let bits = state.bits
    let relationCount = state.hammingWeight()
    let rawMeasure = max(relationCount + 1, 1)
    let compressedMeasure = max(rawMeasure - Int(bits[0]) - Int(bits[3]), 0)
    let scaleCount = 1 + Int(bits[1]) + Int(bits[4]) + Int(bits[7])
    let erasureCost = Int(bits[2]) + Int(bits[5]) + Int(bits[8])
    let selfReferenceCapable = bits[0] == 1 || bits[6] == 1
    let selfModelAvailable = bits[3] == 1 || bits[4] == 1

    return ASHAxiomSubject(
      relationCount: relationCount,
      compressedMeasure: compressedMeasure,
      rawMeasure: rawMeasure,
      scaleCount: scaleCount,
      erasureCost: erasureCost,
      selfReferenceCapable: selfReferenceCapable,
      selfModelAvailable: selfModelAvailable
    )
  }
}

public struct ASHAxiomCheckResult: Codable, Hashable, Sendable {
  public let axiomID: ASHAxiomID
  public let passed: Bool
  public let explanation: String
  public let ruleIDs: [String]

  public init(
    axiomID: ASHAxiomID,
    passed: Bool,
    explanation: String,
    ruleIDs: [String]
  ) {
    self.axiomID = axiomID
    self.passed = passed
    self.explanation = explanation
    self.ruleIDs = ruleIDs
  }
}

public struct ASHAxiomEvaluation: Codable, Hashable, Sendable {
  public let subject: ASHAxiomSubject
  public let results: [ASHAxiomCheckResult]
  public let overallPass: Bool
  public let notes: [String]

  public init(
    subject: ASHAxiomSubject,
    results: [ASHAxiomCheckResult],
    overallPass: Bool,
    notes: [String]
  ) {
    self.subject = subject
    self.results = results
    self.overallPass = overallPass
    self.notes = notes
  }
}
