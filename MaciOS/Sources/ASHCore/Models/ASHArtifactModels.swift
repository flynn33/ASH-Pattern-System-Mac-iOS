import Foundation

public enum ASHArtifactEmissionDisposition: String, Codable, Sendable {
  case emitted = "EMITTED"
  case blocked = "BLOCKED"
}

public struct ASHMaterializedArtifact: Codable, Hashable, Sendable {
  public let artifactID: String
  public let planArtifactID: String
  public let artifactKind: String
  public let targetPathHint: String
  public let content: String
  public let ruleIDs: [String]
  public let notes: [String]

  public init(
    artifactID: String,
    planArtifactID: String,
    artifactKind: String,
    targetPathHint: String,
    content: String,
    ruleIDs: [String],
    notes: [String]
  ) {
    self.artifactID = artifactID
    self.planArtifactID = planArtifactID
    self.artifactKind = artifactKind
    self.targetPathHint = targetPathHint
    self.content = content
    self.ruleIDs = ruleIDs
    self.notes = notes
  }
}

public struct ASHArtifactEmissionDiagnostic: Codable, Hashable, Sendable {
  public let disposition: ASHArtifactEmissionDisposition
  public let summary: String
  public let ruleIDs: [String]
  public let notes: [String]

  public init(
    disposition: ASHArtifactEmissionDisposition,
    summary: String,
    ruleIDs: [String],
    notes: [String]
  ) {
    self.disposition = disposition
    self.summary = summary
    self.ruleIDs = ruleIDs
    self.notes = notes
  }
}

public struct ASHArtifactEmissionResult: Sendable {
  public let artifacts: [ASHMaterializedArtifact]
  public let diagnostics: [ASHArtifactEmissionDiagnostic]

  public init(
    artifacts: [ASHMaterializedArtifact],
    diagnostics: [ASHArtifactEmissionDiagnostic]
  ) {
    self.artifacts = artifacts
    self.diagnostics = diagnostics
  }
}
