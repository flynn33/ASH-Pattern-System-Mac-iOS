import Foundation
import CryptoKit

extension ASHGenerationPlan {
  /// SHA-256 of the complete UTF-8 sorted-key JSON encoding, without escaped slashes.
  /// No identity is included in this payload; all request and registry fields are encoded.
  public func identity() throws -> String {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return "APS-PLAN-" + SHA256.hash(data: try encoder.encode(self)).map { String(format: "%02x", $0) }.joined()
  }
  public var validationIssues: [String] {
    var issues = targetConstraints.validationIssues
    func unique(_ values: [String], _ name: String) {
      if values.isEmpty || Set(values).count != values.count || values.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { issues.append("\(name) must be nonempty and unique.") }
    }
    unique(topologyNodes.map(\.nodeID), "Topology node IDs")
    unique(roleAssignments.map(\.roleID), "Role IDs")
    unique(artifacts.map(\.artifactID), "Artifact IDs")
    let model = ASHStateModel()
    if sourceRealm.stateSignature != normalizedState.description || sourceRealm.realmID != String(format:"APS-REALM-%03d", normalizedState.rawValue) { issues.append("Source realm does not match planning state.") }
    if let destination = ASHState(bitString: destinationRealm.stateSignature) {
      if destinationRealm.realmID != String(format:"APS-REALM-%03d", destination.rawValue) { issues.append("Destination realm identity is inconsistent.") }
      if let id = metadata["transition_id"], let transition = ASHTransitionRegistry(stateModel:model).applyTransition(from: normalizedState, transitionID:id).applied {
        if transition.toState != destination { issues.append("Destination realm differs from the requested transition.") }
      } else { issues.append("Requested canonical transition identity is missing or invalid.") }
    } else { issues.append("Destination state signature is malformed.") }
    let nodeIDs = Set(topologyNodes.map(\.nodeID)), roleIDs = Set(roleAssignments.map(\.roleID))
    if roleAssignments.count != topologyNodes.count || Set(roleAssignments.map(\.nodeID)) != nodeIDs { issues.append("Each topology node requires exactly one role assignment.") }
    if Set(axiomSummaries.map(\.axiomID)) != Set(ASHAxiomID.allCases) || axiomSummaries.count != 5 { issues.append("Plan requires five distinct axiom summaries.") }
    if artifacts.count != roleAssignments.count || artifacts.contains(where: { $0.requiredRoleIDs.count != 1 }) || Set(artifacts.flatMap(\.requiredRoleIDs)) != roleIDs { issues.append("Plan requires exactly one artifact per role.") }
    for (registry, metadataKey) in [("profiles", "profile_registry_version"), ("naming", "naming_registry_version"), ("targets", "target_registry_version")] {
      if metadata[metadataKey] != targetConstraints.registryVersions[registry] { issues.append("Plan registry metadata differs from its owned reference: \(registry).") }
    }
    for role in roleAssignments {
      if !nodeIDs.contains(role.nodeID) || role.roleName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || role.rationale.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || role.ruleIDs.isEmpty { issues.append("Role references an unknown node or lacks explanatory semantics.") }
    }
    if axiomSummaries.contains(where: { $0.explanation.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || $0.ruleIDs.isEmpty }) { issues.append("Axiom summaries require explanation and rule identities.") }
    for artifact in artifacts {
      let components = artifact.targetPathHint.split(separator:"/", omittingEmptySubsequences:false)
      if artifact.targetPathHint.isEmpty || artifact.targetPathHint.hasPrefix("/") || artifact.targetPathHint.contains("\\") || components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) { issues.append("Artifact path must be a safe relative path.") }
      if artifact.summary.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || artifact.ruleIDs.isEmpty { issues.append("Artifact description requires explanation and rule identities.") }
      if artifact.artifactKind != "STATE_FRAGMENT" || artifact.requiredRoleIDs.isEmpty || Set(artifact.requiredRoleIDs).count != artifact.requiredRoleIDs.count || !Set(artifact.requiredRoleIDs).isSubset(of:roleIDs) { issues.append("Artifact kind or role mapping is incomplete.") }
    }
    guard let depthString = metadata["topology_depth"], let depth = Int(depthString), depth >= 0, depth <= 10 else {
      issues.append("Topology depth is missing or exceeds the supported resource bound."); return issues
    }
    let registry = ASHTransitionRegistry(stateModel:model)
    guard let reference = ASHTopologyGenerator(stateModel:model, transitionRegistry:registry).generateTopology(from: normalizedState, depth:depth).topology else {
      issues.append("Topology structure cannot be validated."); return issues
    }
    if topologyNodes.count != reference.nodes.count { issues.append("Topology node count differs from its declared depth.") }
    let parents = Dictionary(grouping: topologyNodes, by: \.nodeID)
    for (index, node) in topologyNodes.enumerated() {
      guard index < reference.nodes.count else { break }
      let expected = reference.nodes[index]
      if node.nodeID != expected.nodeID || node.parentID != expected.parentID || node.pathToken != expected.pathToken || node.branchKind != expected.branchKind || node.depth != expected.depth || node.ordinal != expected.ordinal || node.generationOrdinal != expected.generationOrdinal { issues.append("Topology lineage or ordering differs at ordinal \(index).") }
      if index == 0 {
        if node.state != normalizedState || node.transitionID != nil { issues.append("Root must preserve source state without an edge transition.") }
      } else if let parentID = node.parentID, let parentGroup = parents[parentID], parentGroup.count == 1, let parent = parentGroup.first {
        if let transitionID = node.transitionID {
          if registry.applyTransition(from:parent.state, transitionID:transitionID).applied?.toState != node.state { issues.append("Explicit node transition does not produce its state.") }
        } else if node.state != parent.state { issues.append("Structural branching cannot mutate state without an explicit transition.") }
      } else { issues.append("Node parent is missing or ambiguous.") }
    }
    if metadata["node_count"] != String(topologyNodes.count) || metadata["artifact_count"] != String(artifacts.count) || metadata["topology_seed_token"] != "R" { issues.append("Plan topology metadata is inconsistent.") }
    return issues
  }
}
extension ASHTargetRuntimeConstraints {
  public var validationIssues: [String] {
    var issues:[String] = []
    if !["DEFAULT","BASELINE"].contains(profileID) { issues.append("PROFILE_REFERENCE_INVALID") }
    if namingPolicyID != "ORDINAL" { issues.append("NAMING_REFERENCE_INVALID") }
    if emissionTargetKind != "IN_MEMORY" || !["APPLE","MACOS","IOS"].contains(platform) || runtime != "NATIVE" { issues.append("TARGET_REFERENCE_INVALID") }
    if registryVersions != ["profiles":"1.0","naming":"1.0","targets":"1.0"] { issues.append("REGISTRY_REFERENCE_INVALID") }
    if capabilityTags.contains(where: { $0.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty }) || Set(capabilityTags).count != capabilityTags.count { issues.append("CAPABILITY_REFERENCE_INVALID") }
    return issues
  }
}
