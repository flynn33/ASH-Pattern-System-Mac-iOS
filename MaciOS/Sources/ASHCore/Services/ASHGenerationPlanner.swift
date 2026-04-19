import Foundation

public final class ASHGenerationPlanner: ASHGenerationPlannerProtocol {
  private let stateModel: any ASHStateModelProtocol
  private let realmEncoder: any ASHRealmEncoderProtocol

  public init(
    stateModel: any ASHStateModelProtocol,
    realmEncoder: any ASHRealmEncoderProtocol
  ) {
    self.stateModel = stateModel
    self.realmEncoder = realmEncoder
  }

  public func buildPlan(
    from state: ASHState,
    topology: ASHTopology,
    axiomEvaluation: ASHAxiomEvaluation,
    targetConstraints: ASHTargetRuntimeConstraints = .init()
  ) -> ASHGenerationPlanResult {
    guard !topology.nodes.isEmpty else {
      return ASHGenerationPlanResult(
        plan: nil,
        diagnostics: [
          ASHGenerationPlanDiagnostic(
            summary: "Generation planning requires non-empty topology.",
            ruleIDs: ["ASH-STATE-PLANNING-001"],
            notes: ["No topology nodes were provided to the planner."]
          )
        ]
      )
    }

    guard let normalizedState = stateModel.normalize(state) else {
      return ASHGenerationPlanResult(
        plan: nil,
        diagnostics: [
          ASHGenerationPlanDiagnostic(
            summary: "Generation planning requires a normalizable state.",
            ruleIDs: ["ASH-STATE-VALIDITY-001", "ASH-STATE-PLANNING-002"],
            notes: ["Planner cannot proceed with a non-normalizable state input."]
          )
        ]
      )
    }

    guard let sourceRealm = realmEncoder.encode(state: normalizedState).identity else {
      return ASHGenerationPlanResult(
        plan: nil,
        diagnostics: [
          ASHGenerationPlanDiagnostic(
            summary: "Generation planning could not encode source realm identity.",
            ruleIDs: ["ASH-STATE-REALM-001", "ASH-STATE-PLANNING-003"],
            notes: ["Realm encoding failed for normalized planning state."]
          )
        ]
      )
    }

    let sortedNodes = topology.nodes.sorted { lhs, rhs in
      if lhs.depth == rhs.depth {
        return lhs.ordinal < rhs.ordinal
      }
      return lhs.depth < rhs.depth
    }

    let destinationStateCandidate = sortedNodes.last?.state ?? normalizedState
    guard let destinationState = stateModel.normalize(destinationStateCandidate) else {
      return ASHGenerationPlanResult(
        plan: nil,
        diagnostics: [
          ASHGenerationPlanDiagnostic(
            summary: "Generation planning could not normalize destination state for realm encoding.",
            ruleIDs: ["ASH-STATE-PLANNING-004"],
            notes: ["Destination topology node state must normalize before encoding."]
          )
        ]
      )
    }

    guard let destinationRealm = realmEncoder.encode(state: destinationState).identity else {
      return ASHGenerationPlanResult(
        plan: nil,
        diagnostics: [
          ASHGenerationPlanDiagnostic(
            summary: "Generation planning could not encode destination realm identity from normalized state.",
            ruleIDs: ["ASH-STATE-REALM-001", "ASH-STATE-PLANNING-009"],
            notes: ["Destination topology node state must encode deterministically."]
          )
        ]
      )
    }

    let roleAssignments = makeRoleAssignments(nodes: sortedNodes)
    let axiomSummaries = axiomEvaluation.results.map {
      ASHAxiomSummary(
        axiomID: $0.axiomID,
        passed: $0.passed,
        explanation: $0.explanation,
        ruleIDs: $0.ruleIDs
      )
    }

    let plannedArtifacts = makeArtifactDescriptions(
      roleAssignments: roleAssignments,
      targetConstraints: targetConstraints
    )

    let warnings = axiomEvaluation.results
      .filter { !$0.passed }
      .map { "\($0.axiomID.rawValue) failed: \($0.explanation)" }

    let plan = ASHGenerationPlan(
      normalizedState: normalizedState,
      sourceRealm: sourceRealm,
      destinationRealm: destinationRealm,
      topologyNodes: sortedNodes,
      roleAssignments: roleAssignments,
      axiomSummaries: axiomSummaries,
      artifacts: plannedArtifacts,
      targetConstraints: targetConstraints,
      warnings: warnings,
      metadata: [
        "topology_depth": String(topology.depth),
        "topology_seed_token": topology.seedToken,
        "node_count": String(sortedNodes.count),
        "artifact_count": String(plannedArtifacts.count)
      ]
    )

    return ASHGenerationPlanResult(
      plan: plan,
      diagnostics: [
        ASHGenerationPlanDiagnostic(
          summary: "Abstract generation plan constructed without side effects.",
          ruleIDs: [
            "ASH-STATE-PLANNING-005",
            "ASH-STATE-PLANNING-006"
          ],
          notes: [
            "Plan includes topology, role assignments, axiom summaries, and artifact descriptions.",
            "Planning remained target-aware but non-materialized."
          ]
        )
      ]
    )
  }

  private func makeRoleAssignments(nodes: [ASHTopologyNode]) -> [ASHRoleAssignment] {
    nodes.map { node in
      let roleName: String
      switch node.branchKind {
      case .root:
        roleName = "ANCHOR"
      case .continuation:
        roleName = "THREAD"
      case .positive:
        roleName = "AMPLIFIER"
      case .negative:
        roleName = "DAMPER"
      }

      return ASHRoleAssignment(
        nodeID: node.nodeID,
        roleID: "ROLE-\(node.nodeID)",
        roleName: roleName,
        rationale: "Role derived deterministically from branch kind \(node.branchKind.rawValue).",
        ruleIDs: ["ASH-STATE-PLANNING-007"]
      )
    }
  }

  private func makeArtifactDescriptions(
    roleAssignments: [ASHRoleAssignment],
    targetConstraints: ASHTargetRuntimeConstraints
  ) -> [ASHPlannedArtifactDescription] {
    roleAssignments.enumerated().map { index, role in
      let artifactOrdinal = String(format: "%03d", index + 1)
      return ASHPlannedArtifactDescription(
        artifactID: "ART-\(artifactOrdinal)",
        artifactKind: "STATE_FRAGMENT",
        targetPathHint: "artifacts/\(targetConstraints.platform.lowercased())/\(artifactOrdinal).json",
        summary: "Materialize role \(role.roleName) for node \(role.nodeID).",
        requiredRoleIDs: [role.roleID],
        ruleIDs: ["ASH-STATE-PLANNING-008"],
        metadata: [
          "role_name": role.roleName,
          "target_runtime": targetConstraints.runtime,
          "target_kind": targetConstraints.emissionTargetKind
        ]
      )
    }
  }
}
