import Foundation

public struct ASHTargetRuntimeConstraints: Codable, Hashable, Sendable {
  public let platform: String
  public let runtime: String
  public let profileID: String
  public let emissionTargetKind: String
  public let capabilityTags: [String]

  public init(
    platform: String = "APPLE",
    runtime: String = "NATIVE",
    profileID: String = "DEFAULT",
    emissionTargetKind: String = "IN_MEMORY",
    capabilityTags: [String] = []
  ) {
    self.platform = platform
    self.runtime = runtime
    self.profileID = profileID
    self.emissionTargetKind = emissionTargetKind
    self.capabilityTags = capabilityTags.sorted()
  }
}

public struct ASHRoleAssignment: Codable, Hashable, Sendable {
  public let nodeID: String
  public let roleID: String
  public let roleName: String
  public let rationale: String
  public let ruleIDs: [String]

  public init(
    nodeID: String,
    roleID: String,
    roleName: String,
    rationale: String,
    ruleIDs: [String]
  ) {
    self.nodeID = nodeID
    self.roleID = roleID
    self.roleName = roleName
    self.rationale = rationale
    self.ruleIDs = ruleIDs
  }
}

public struct ASHAxiomSummary: Codable, Hashable, Sendable {
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

public struct ASHPlannedArtifactDescription: Codable, Hashable, Sendable {
  public let artifactID: String
  public let artifactKind: String
  public let targetPathHint: String
  public let summary: String
  public let requiredRoleIDs: [String]
  public let ruleIDs: [String]
  public let metadata: [String: String]

  public init(
    artifactID: String,
    artifactKind: String,
    targetPathHint: String,
    summary: String,
    requiredRoleIDs: [String],
    ruleIDs: [String],
    metadata: [String: String]
  ) {
    self.artifactID = artifactID
    self.artifactKind = artifactKind
    self.targetPathHint = targetPathHint
    self.summary = summary
    self.requiredRoleIDs = requiredRoleIDs.sorted()
    self.ruleIDs = ruleIDs
    self.metadata = metadata
  }
}

public struct ASHGenerationPlan: Codable, Hashable, Sendable {
  public let normalizedState: ASHState
  public let sourceRealm: ASHRealmIdentity
  public let destinationRealm: ASHRealmIdentity
  public let topologyNodes: [ASHTopologyNode]
  public let roleAssignments: [ASHRoleAssignment]
  public let axiomSummaries: [ASHAxiomSummary]
  public let artifacts: [ASHPlannedArtifactDescription]
  public let targetConstraints: ASHTargetRuntimeConstraints
  public let warnings: [String]
  public let metadata: [String: String]

  public init(
    normalizedState: ASHState,
    sourceRealm: ASHRealmIdentity,
    destinationRealm: ASHRealmIdentity,
    topologyNodes: [ASHTopologyNode],
    roleAssignments: [ASHRoleAssignment],
    axiomSummaries: [ASHAxiomSummary],
    artifacts: [ASHPlannedArtifactDescription],
    targetConstraints: ASHTargetRuntimeConstraints,
    warnings: [String],
    metadata: [String: String]
  ) {
    self.normalizedState = normalizedState
    self.sourceRealm = sourceRealm
    self.destinationRealm = destinationRealm
    self.topologyNodes = topologyNodes
    self.roleAssignments = roleAssignments
    self.axiomSummaries = axiomSummaries
    self.artifacts = artifacts
    self.targetConstraints = targetConstraints
    self.warnings = warnings
    self.metadata = metadata
  }
}

public struct ASHGenerationPlanDiagnostic: Codable, Hashable, Sendable {
  public let summary: String
  public let ruleIDs: [String]
  public let notes: [String]

  public init(
    summary: String,
    ruleIDs: [String],
    notes: [String]
  ) {
    self.summary = summary
    self.ruleIDs = ruleIDs
    self.notes = notes
  }
}

public struct ASHGenerationPlanResult: Sendable {
  public let plan: ASHGenerationPlan?
  public let diagnostics: [ASHGenerationPlanDiagnostic]

  public init(
    plan: ASHGenerationPlan?,
    diagnostics: [ASHGenerationPlanDiagnostic]
  ) {
    self.plan = plan
    self.diagnostics = diagnostics
  }
}
