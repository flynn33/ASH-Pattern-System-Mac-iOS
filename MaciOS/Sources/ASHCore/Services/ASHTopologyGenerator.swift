import Foundation

public final class ASHTopologyGenerator: ASHTopologyGeneratorProtocol {
  private let stateModel: any ASHStateModelProtocol
  private let transitionRegistry: any ASHTransitionRegistryProtocol
  private let branchCodewords: [ASHState]?
  private let configurationIssues: [String]
  public let maximumNodes: Int
  public init(stateModel: any ASHStateModelProtocol, transitionRegistry: any ASHTransitionRegistryProtocol,
    branchCodewords: [ASHState]? = nil, maximumNodes: Int = 100_000) {
    self.stateModel = stateModel; self.transitionRegistry = transitionRegistry
    self.branchCodewords = branchCodewords; self.maximumNodes = maximumNodes
    var issues: [String] = []
    if maximumNodes < 1 { issues.append("maximumNodes must be positive.") }
    if let words = branchCodewords {
      if words.count != 3 { issues.append("Explicit C/P/N state assignment requires exactly three codewords.") }
      if words.contains(where: { !ASHStateModel.canonicalCodewordSet.contains($0) }) { issues.append("Explicit state assignment contains a noncanonical codeword.") }
    }
    self.configurationIssues = issues
  }
  public func generateTopology(from state: ASHState, depth: Int, seedToken: String = "R") -> ASHTopologyGenerationResult {
    guard configurationIssues.isEmpty else { return failure("Topology configuration is invalid.", notes: configurationIssues) }
    guard seedToken == "R" else { return failure("Canonical structural topology requires root path R.", notes: ["seed_token=\(seedToken)"]) }
    guard depth >= 0 else { return failure("Topology depth must be nonnegative.", notes: ["requested_depth=\(depth)"]) }
    guard let projection = projectedSize(depth: depth) else {
      return failure("Topology size exceeds representable resource counts.", notes: ["requested_depth=\(depth)", "maximum_nodes=\(maximumNodes)", "projected_nodes=overflow", "projected_leaves=overflow"])
    }
    guard projection.nodes <= maximumNodes else {
      return failure("Topology request exceeds the configured node budget.", notes: ["requested_depth=\(depth)", "maximum_nodes=\(maximumNodes)", "projected_nodes=\(projection.nodes)", "projected_leaves=\(projection.leaves)"])
    }
    guard !Task.isCancelled else { return failure("Topology generation was cancelled.", notes: ["No partial topology is returned."]) }
    guard stateModel.normalize(state) == state else { return failure("Structural normalization must preserve the seed.", notes: []) }
    let root = ASHTopologyNode(nodeID: "APS-NODE-R", parentID: nil, depth: 0, ordinal: 0, branchKind: .root, pathToken: "R", state: state)
    var all = [root], frontier = [root]
    all.reserveCapacity(projection.nodes)
    let branches: [(ASHTopologyBranchKind, String)] = [(.continuation, "C"), (.positive, "P"), (.negative, "N")]
    for level in 0..<depth {
      var next: [ASHTopologyNode] = []
      for parent in frontier {
        guard !Task.isCancelled else { return failure("Topology generation was cancelled.", notes: ["No partial topology is returned."]) }
        for (index, branch) in branches.enumerated() {
          var childState = parent.state, transitionID: String?
          if let words = branchCodewords {
            let resolution = transitionRegistry.applyCodeword(from: parent.state, codeword: words[index])
            guard let applied = resolution.applied else { return failure("Explicit branch state assignment failed.", notes: resolution.failureDiagnostic?.notes ?? []) }
            childState = applied.toState; transitionID = applied.transitionID
          }
          let path = parent.pathToken + "/" + branch.1
          let child = ASHTopologyNode(nodeID: "APS-NODE-" + path.replacingOccurrences(of: "/", with: "."), parentID: parent.nodeID,
            depth: level + 1, ordinal: all.count, branchKind: branch.0, pathToken: path, state: childState,
            generationOrdinal: next.count, transitionID: transitionID)
          next.append(child); all.append(child)
        }
      }
      frontier = next
    }
    return ASHTopologyGenerationResult(topology: ASHTopology(seedToken: "R", depth: depth, nodes: all), diagnostics: [])
  }
  private func failure(_ summary: String, notes: [String]) -> ASHTopologyGenerationResult {
    ASHTopologyGenerationResult(topology: nil, diagnostics: [ASHTopologyDiagnostic(summary: summary, ruleIDs: ["ASH-TOPOLOGY-001"], notes: notes)])
  }
  private func projectedSize(depth: Int) -> (nodes: Int, leaves: Int)? {
    guard depth <= 39 else { return nil }
    var leaves = 1, nodes = 1
    for _ in 0..<depth {
      let next = leaves.multipliedReportingOverflow(by: 3)
      guard !next.overflow else { return nil }; leaves = next.partialValue
      let total = nodes.addingReportingOverflow(leaves)
      guard !total.overflow else { return nil }; nodes = total.partialValue
    }
    return (nodes, leaves)
  }
}
