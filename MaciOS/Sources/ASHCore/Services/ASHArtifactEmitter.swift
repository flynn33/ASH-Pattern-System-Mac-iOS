import Foundation

public final class ASHArtifactEmitter: ASHArtifactEmitterProtocol {
  public init() {}

  public func emit(plan: ASHGenerationPlan) -> ASHArtifactEmissionResult {
    let roleIDs = Set(plan.roleAssignments.map(\.roleID))
    let invalidArtifacts = plan.artifacts.filter { artifact in
      artifact.requiredRoleIDs.isEmpty || !Set(artifact.requiredRoleIDs).isSubset(of: roleIDs)
    }

    guard invalidArtifacts.isEmpty else {
      let missingIDs = invalidArtifacts.map(\.artifactID).sorted().joined(separator: ",")
      return ASHArtifactEmissionResult(
        artifacts: [],
        diagnostics: [
          ASHArtifactEmissionDiagnostic(
            disposition: .blocked,
            summary: "Artifact emission blocked because plan references incomplete role mappings.",
            ruleIDs: ["ASH-STATE-EMISSION-001"],
            notes: [
              "Emitter must fail on incomplete plans and must not invent missing semantics.",
              "Invalid artifact IDs: \(missingIDs)"
            ]
          )
        ]
      )
    }

    let artifacts = plan.artifacts.map { planned in
      let contentLines = [
        "artifact_id=\(planned.artifactID)",
        "artifact_kind=\(planned.artifactKind)",
        "state=\(plan.normalizedState.description)",
        "source_realm=\(plan.sourceRealm.realmID)",
        "destination_realm=\(plan.destinationRealm.realmID)",
        "required_roles=\(planned.requiredRoleIDs.joined(separator: ","))",
        "summary=\(planned.summary)"
      ]

      return ASHMaterializedArtifact(
        artifactID: "MAT-\(planned.artifactID)",
        planArtifactID: planned.artifactID,
        artifactKind: planned.artifactKind,
        targetPathHint: planned.targetPathHint,
        content: contentLines.joined(separator: "\n"),
        ruleIDs: ["ASH-STATE-EMISSION-002"],
        notes: ["Materialized directly from plan artifact \(planned.artifactID)."]
      )
    }

    let diagnostics = artifacts.map { artifact in
      ASHArtifactEmissionDiagnostic(
        disposition: .emitted,
        summary: "Artifact emitted from plan element \(artifact.planArtifactID).",
        ruleIDs: ["ASH-STATE-EMISSION-003"],
        notes: ["Emission preserved plan-defined semantics without augmentation."]
      )
    }

    return ASHArtifactEmissionResult(
      artifacts: artifacts,
      diagnostics: diagnostics
    )
  }
}
