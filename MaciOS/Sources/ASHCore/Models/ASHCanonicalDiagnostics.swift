import Foundation

extension StateValidityDiagnostic {
  public func canonicalDiagnostic(parent: ASHDiagnosticEnvelope? = nil) -> ASHDiagnosticEnvelope {
    .canonical(kind:.stateAssessment, stage:.assess, disposition:.recorded, subject:inputState.description,
      ruleIDs:["ASH-STATE-001"], summary:"Structural state assessment preserves realm identity.", notes:notes,
      details:["state_signature":.string(inputState.description), "structurally_valid":.bool(isValid), "orbit_id":orbitInfo?.orbitID.map(ASHDiagnosticValue.string) ?? .null], parent:parent)
  }
}
extension ASHRealmEncodingResult {
  public func canonicalDiagnostics(subject: String, parent: ASHDiagnosticEnvelope? = nil) -> [ASHDiagnosticEnvelope] {
    [.canonical(kind:.stateAssessment, stage:.verify, disposition:identity == nil ? .blocked : .recorded,
      subject:subject, ruleIDs:["ASH-REALM-001"], summary:identity == nil ? "Realm encoding refused." : "Canonical realm identity encoded.",
      notes:failureDiagnostic?.notes ?? ["The successful result contains deterministic state and canonical identity fields."], details:["realm_id":identity.map { .string($0.realmID) } ?? .null], parent:parent)]
  }
}
extension ASHTransitionResolution {
  public func canonicalDiagnostics(subject: String, parent: ASHDiagnosticEnvelope? = nil) -> [ASHDiagnosticEnvelope] {
    [.canonical(kind:.transition, stage:.transform, disposition:applied == nil ? .blocked : .resolved,
      subject:subject, ruleIDs:["ASH-TRANSITION-001"], summary:failureDiagnostic?.summary ?? "Canonical codeword transition applied.", notes:failureDiagnostic?.notes ?? ["The successful result contains deterministic state and canonical identity fields."],
      details:["transition_id":applied.map { .string($0.transitionID) } ?? .null, "target_state":applied.map { .string($0.toState.description) } ?? .null, "codeword":applied.map { .string($0.codeword.description) } ?? .null], parent:parent)]
  }
}
extension ASHAxiomEvaluation {
  public func canonicalDiagnostics(subject: String, parent: ASHDiagnosticEnvelope? = nil) -> [ASHDiagnosticEnvelope] {
    [.canonical(kind:.axiom, stage:.evaluate, disposition:.recorded, subject:subject, ruleIDs:["ASH-AXIOM-001"],
      summary:"Axiom evidence evaluated against the five documented predicates.", notes:notes,
      details:["axiom_result":.string(status.rawValue), "results":.array(results.map { .object(["axiom_id":.string($0.axiomID.rawValue), "status":.string($0.status.rawValue), "explanation":.string($0.explanation)]) })], parent:parent)]
  }
}
extension ASHTopologyGenerationResult {
  public func canonicalDiagnostics(subject: String, parent: ASHDiagnosticEnvelope? = nil) -> [ASHDiagnosticEnvelope] {
    let nodeCount: ASHDiagnosticValue = topology.map { .integer(Int64($0.nodes.count)) } ?? .null
    let leafCount: ASHDiagnosticValue = topology.map { .integer(Int64($0.leaves.count)) } ?? .null
    let fields: ASHDiagnosticObject = ["node_count":nodeCount,"leaf_count":leafCount]
    let record = ASHDiagnosticEnvelope.canonical(kind:.topology, stage:.validate, disposition:topology == nil ? .blocked : .recorded,
      subject:subject, ruleIDs:["ASH-TOPOLOGY-001"], summary:topology == nil ? "Topology generation refused." : "Canonical structural topology generated.",
      notes:diagnostics.flatMap(\.notes).isEmpty ? ["Paths and breadth-first ordinals follow structural C/P/N expansion without implicit state mutation."] : diagnostics.flatMap(\.notes), details:fields, parent:parent)
    return [record]
  }
}
extension ASHGenerationPlanResult {
  public func canonicalDiagnostics(subject: String, parent: ASHDiagnosticEnvelope? = nil) -> [ASHDiagnosticEnvelope] {
    [.canonical(kind:.generationPlan, stage:.plan, disposition:plan == nil ? .blocked : .recorded, subject:subject, ruleIDs:["ASH-GENERATION-001"],
      summary:plan == nil ? "Generation planning refused." : "Complete abstract generation plan constructed without side effects.", notes:diagnostics.flatMap(\.notes).isEmpty ? ["The complete result retains its source plan and declared output references."] : diagnostics.flatMap(\.notes),
      details:["plan_id":(try? plan?.identity()).flatMap { $0 }.map(ASHDiagnosticValue.string) ?? .null], parent:parent)]
  }
}
extension ASHArtifactEmissionResult {
  public func canonicalDiagnostics(subject: String, parent: ASHDiagnosticEnvelope? = nil) -> [ASHDiagnosticEnvelope] {
    [.canonical(kind:.emission, stage:.emit, disposition:artifacts.isEmpty ? .blocked : .resolved, subject:subject, ruleIDs:["ASH-EMISSION-001"],
      summary:artifacts.isEmpty ? "Artifact emission refused." : "Validated plan-derived artifacts materialized in memory.", notes:diagnostics.flatMap(\.notes).isEmpty ? ["The complete result retains its source plan and declared output references."] : diagnostics.flatMap(\.notes),
      details:["artifact_count":.integer(Int64(artifacts.count)), "plan_ids":.array(artifacts.map { .string($0.planID) })], parent:parent)]
  }
}
