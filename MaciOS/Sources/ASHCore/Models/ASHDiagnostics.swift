import Foundation

public enum AdmissibilityStatus: String, Codable, Sendable {
  case valid = "VALID"
  case transformationCompatible = "TRANSFORMATION_COMPATIBLE"
  case transformationIncompatible = "TRANSFORMATION_INCOMPATIBLE"
  case unclassified = "UNCLASSIFIED"
}

public enum TransformationCompatibility: String, Codable, Sendable {
  case compatible = "COMPATIBLE"
  case incompatible = "INCOMPATIBLE"
  case unknown = "UNKNOWN"
}

public enum NormalizationStatus: String, Codable, Sendable {
  case alreadyValid = "ALREADY_VALID"
  case normalizable = "NORMALIZABLE"
  case notNormalizable = "NOT_NORMALIZABLE"
  case blocked = "BLOCKED"
}

public enum RecoverabilityRelevance: String, Codable, Sendable {
  case noRecoveryNeeded = "NO_RECOVERY_NEEDED"
  case recoveryApplicable = "RECOVERY_APPLICABLE"
  case fallbackNeeded = "FALLBACK_NEEDED"
  case containmentNeeded = "CONTAINMENT_NEEDED"
  case notRecoverable = "NOT_RECOVERABLE"
}

public enum SystemStateClass: String, Codable, Sendable {
  case stable = "STABLE"
  case unstable = "UNSTABLE"
  case correctable = "CORRECTABLE"
  case degraded = "DEGRADED"
  case contained = "CONTAINED"
  case failed = "FAILED"
  case safeHalt = "SAFE_HALT"
}

public enum RecoveryCategory: String, Codable, Sendable {
  case noAction = "NO_ACTION"
  case normalizeState = "NORMALIZE_STATE"
  case applyCorrection = "APPLY_CORRECTION"
  case fallbackRequired = "FALLBACK_REQUIRED"
  case containmentRequired = "CONTAINMENT_REQUIRED"
  case escalationRequired = "ESCALATION_REQUIRED"
  case terminalNoRecovery = "TERMINAL_NO_RECOVERY"
}

public struct OrbitInfo: Codable, Hashable, Sendable {
  public let orbitRepresentative: ASHState
  public let orbitSize: Int
  public let containsKnownValidState: Bool

  public init(
    orbitRepresentative: ASHState,
    orbitSize: Int,
    containsKnownValidState: Bool
  ) {
    self.orbitRepresentative = orbitRepresentative
    self.orbitSize = orbitSize
    self.containsKnownValidState = containsKnownValidState
  }
}

public struct StateValidityDiagnostic: Codable, Hashable, Sendable {
  public let inputState: ASHState
  public let admissibilityStatus: AdmissibilityStatus
  public let transformationCompatibility: TransformationCompatibility
  public let normalizationStatus: NormalizationStatus
  public let recoverabilityRelevance: RecoverabilityRelevance
  public let isValid: Bool
  public let orbitInfo: OrbitInfo?
  public let ruleIDs: [String]
  public let notes: [String]

  public init(
    inputState: ASHState,
    admissibilityStatus: AdmissibilityStatus,
    transformationCompatibility: TransformationCompatibility,
    normalizationStatus: NormalizationStatus,
    recoverabilityRelevance: RecoverabilityRelevance,
    isValid: Bool,
    orbitInfo: OrbitInfo?,
    ruleIDs: [String],
    notes: [String]
  ) {
    self.inputState = inputState
    self.admissibilityStatus = admissibilityStatus
    self.transformationCompatibility = transformationCompatibility
    self.normalizationStatus = normalizationStatus
    self.recoverabilityRelevance = recoverabilityRelevance
    self.isValid = isValid
    self.orbitInfo = orbitInfo
    self.ruleIDs = ruleIDs
    self.notes = notes
  }
}

public struct ASHSystemContext: Codable, Hashable, Sendable {
  public var isInContainment: Bool
  public var isInSafeHalt: Bool
  public var correctionPathKnown: Bool
  public var fallbackAvailable: Bool

  public init(
    isInContainment: Bool = false,
    isInSafeHalt: Bool = false,
    correctionPathKnown: Bool = false,
    fallbackAvailable: Bool = false
  ) {
    self.isInContainment = isInContainment
    self.isInSafeHalt = isInSafeHalt
    self.correctionPathKnown = correctionPathKnown
    self.fallbackAvailable = fallbackAvailable
  }
}
