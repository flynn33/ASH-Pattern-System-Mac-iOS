import Foundation

public final class ASHTopologyGenerator: ASHTopologyGeneratorProtocol {
  private struct BranchRule {
    let kind: ASHTopologyBranchKind
    let token: String
    let codeword: ASHState
  }

  private let stateModel: any ASHStateModelProtocol
  private let transitionRegistry: any ASHTransitionRegistryProtocol
  private let branchRules: [BranchRule]

  public init(
    stateModel: any ASHStateModelProtocol,
    transitionRegistry: any ASHTransitionRegistryProtocol,
    branchCodewords: [ASHState]? = nil
  ) {
    self.stateModel = stateModel
    self.transitionRegistry = transitionRegistry

    let selectedCodewords = branchCodewords ?? Self.defaultBranchCodewords(from: stateModel.codewordSet)
    self.branchRules = [
      BranchRule(kind: .continuation, token: "C", codeword: selectedCodewords[0]),
      BranchRule(kind: .positive, token: "P", codeword: selectedCodewords[1]),
      BranchRule(kind: .negative, token: "N", codeword: selectedCodewords[2])
    ]
  }

  public func generateTopology(
    from state: ASHState,
    depth: Int,
    seedToken: String = "F"
  ) -> ASHTopologyGenerationResult {
    guard depth >= 0 else {
      return ASHTopologyGenerationResult(
        topology: nil,
        diagnostics: [
          ASHTopologyDiagnostic(
            summary: "Topology depth must be non-negative.",
            ruleIDs: ["ASH-TOPOLOGY-GENERATION-001"],
            notes: ["Received depth=\(depth)."]
          )
        ]
      )
    }

    guard let normalizedSeed = stateModel.normalize(state) else {
      return ASHTopologyGenerationResult(
        topology: nil,
        diagnostics: [
          ASHTopologyDiagnostic(
            summary: "Seed state could not be normalized for topology generation.",
            ruleIDs: ["ASH-STATE-VALIDITY-001", "ASH-TOPOLOGY-GENERATION-002"],
            notes: ["Topology generation requires normalized seed state."]
          )
        ]
      )
    }

    let rootNode = ASHTopologyNode(
      nodeID: "\(seedToken)-d0-o0",
      parentID: nil,
      depth: 0,
      ordinal: 0,
      branchKind: .root,
      pathToken: seedToken,
      state: normalizedSeed
    )

    var allNodes = [rootNode]
    var frontier = [rootNode]
    var nextOrdinal = 1
    var diagnostics: [ASHTopologyDiagnostic] = []

    if depth > 0 {
      for level in 1...depth {
        var nextFrontier: [ASHTopologyNode] = []

        for parent in frontier.sorted(by: { $0.ordinal < $1.ordinal }) {
          for rule in branchRules {
            let resolution = transitionRegistry.applyCodeword(from: parent.state, codeword: rule.codeword)
            guard let applied = resolution.applied else {
              if let failure = resolution.failureDiagnostic {
                diagnostics.append(
                  ASHTopologyDiagnostic(
                    summary: "Topology expansion failed while applying branch transition.",
                    ruleIDs: failure.ruleIDs + ["ASH-TOPOLOGY-GENERATION-003"],
                    notes: failure.notes + [
                      "parent_id=\(parent.nodeID)",
                      "branch_kind=\(rule.kind.rawValue)",
                      "branch_codeword=\(rule.codeword.description)"
                    ]
                  )
                )
              }
              return ASHTopologyGenerationResult(topology: nil, diagnostics: diagnostics)
            }

            let childPathToken = "\(parent.pathToken).\(rule.token)"
            let childNode = ASHTopologyNode(
              nodeID: "\(childPathToken)-d\(level)-o\(nextOrdinal)",
              parentID: parent.nodeID,
              depth: level,
              ordinal: nextOrdinal,
              branchKind: rule.kind,
              pathToken: childPathToken,
              state: applied.toState
            )
            nextOrdinal += 1

            nextFrontier.append(childNode)
            allNodes.append(childNode)
          }
        }

        frontier = nextFrontier
      }
    }

    return ASHTopologyGenerationResult(
      topology: ASHTopology(seedToken: seedToken, depth: depth, nodes: allNodes),
      diagnostics: diagnostics
    )
  }

  private static func defaultBranchCodewords(from codewordSet: Set<ASHState>) -> [ASHState] {
    let nonIdentity = codewordSet
      .filter { $0 != .zero }
      .sorted()

    precondition(nonIdentity.count >= 3, "At least 3 non-identity codewords are required.")
    return Array(nonIdentity.prefix(3))
  }
}
