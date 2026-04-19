import Foundation

public enum ASHTopologyBranchKind: String, Codable, Sendable {
  case root = "ROOT"
  case continuation = "CONTINUATION"
  case positive = "POSITIVE"
  case negative = "NEGATIVE"
}

public struct ASHTopologyNode: Codable, Hashable, Sendable {
  public let nodeID: String
  public let parentID: String?
  public let depth: Int
  public let ordinal: Int
  public let branchKind: ASHTopologyBranchKind
  public let pathToken: String
  public let state: ASHState

  public init(
    nodeID: String,
    parentID: String?,
    depth: Int,
    ordinal: Int,
    branchKind: ASHTopologyBranchKind,
    pathToken: String,
    state: ASHState
  ) {
    self.nodeID = nodeID
    self.parentID = parentID
    self.depth = depth
    self.ordinal = ordinal
    self.branchKind = branchKind
    self.pathToken = pathToken
    self.state = state
  }
}

public struct ASHTopology: Codable, Hashable, Sendable {
  public let seedToken: String
  public let depth: Int
  public let nodes: [ASHTopologyNode]

  public init(seedToken: String, depth: Int, nodes: [ASHTopologyNode]) {
    self.seedToken = seedToken
    self.depth = depth
    self.nodes = nodes
  }
}

public struct ASHTopologyDiagnostic: Codable, Hashable, Sendable {
  public let summary: String
  public let ruleIDs: [String]
  public let notes: [String]

  public init(summary: String, ruleIDs: [String], notes: [String]) {
    self.summary = summary
    self.ruleIDs = ruleIDs
    self.notes = notes
  }
}

public struct ASHTopologyGenerationResult: Sendable {
  public let topology: ASHTopology?
  public let diagnostics: [ASHTopologyDiagnostic]

  public init(topology: ASHTopology?, diagnostics: [ASHTopologyDiagnostic]) {
    self.topology = topology
    self.diagnostics = diagnostics
  }
}
