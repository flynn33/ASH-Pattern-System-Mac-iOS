import Foundation

public final class ASHArtifactEmitter: ASHArtifactEmitterProtocol {
  public init() {}

  public func emit(plan: ASHGenerationPlan) -> ASHArtifactEmissionResult {
    let issues = plan.validationIssues
    guard issues.isEmpty, let identity = try? plan.identity() else {
      return ASHArtifactEmissionResult(artifacts:[], diagnostics:[ASHArtifactEmissionDiagnostic(disposition:.blocked, summary:"EMISSION_REFUSED: plan is incomplete or inconsistent.", ruleIDs:["ASH-EMISSION-001"], notes:issues)])
    }

    let artifacts = plan.artifacts.map { planned in
      let contentLines = [
        "plan_id=\(identity)",
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
        notes: ["Materialized directly from plan artifact \(planned.artifactID)."],
        planID: identity
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
