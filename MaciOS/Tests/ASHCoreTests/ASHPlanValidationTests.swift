import XCTest
import Foundation
import ASHCore

final class ASHPlanValidationTests: XCTestCase {
  private func makePlan(_ constraints:ASHTargetRuntimeConstraints = .init(), transitionID:String = "APS-TRANSITION-CW-00") throws -> ASHGenerationPlan {
    let model = ASHStateModel(), registry = ASHTransitionRegistry(stateModel:ASHStateModel())
    let topology = try XCTUnwrap(ASHTopologyGenerator(stateModel:model,transitionRegistry:registry).generateTopology(from:.zero,depth:1).topology)
    return try XCTUnwrap(ASHGenerationPlanner(stateModel:model,realmEncoder:ASHRealmEncoder(stateModel:model)).buildPlan(from:.zero,topology:topology,axiomEvaluation:ASHAxiomEvaluator().evaluate(state:.zero),targetConstraints:constraints,transitionID:transitionID).plan)
  }
  func testForgedIncompletePlansFailAtomicallyAtOwningEmissionBoundary() throws {
    let valid = try makePlan()
    let encoded = try JSONEncoder().encode(valid), original = try XCTUnwrap(JSONSerialization.jsonObject(with:encoded) as? [String:Any])
    let changes:[(String,([String:Any])->[String:Any])] = [
      ("empty artifacts",{ var p=$0; p["artifacts"]=[]; return p }),
      ("missing axioms",{ var p=$0; p["axiomSummaries"]=[]; return p }),
      ("duplicate roles",{ var p=$0; var roles=p["roleAssignments"] as! [[String:Any]]; roles[1]["roleID"]=roles[0]["roleID"];p["roleAssignments"]=roles;return p }),
      ("unknown role",{ var p=$0;var artifacts=p["artifacts"] as! [[String:Any]];artifacts[0]["requiredRoleIDs"]=["missing"];p["artifacts"]=artifacts;return p }),
      ("uncovered role",{ var p=$0;var artifacts=p["artifacts"] as! [[String:Any]];artifacts[1]["requiredRoleIDs"]=artifacts[0]["requiredRoleIDs"];p["artifacts"]=artifacts;return p }),
      ("registry metadata mismatch",{ var p=$0;var metadata=p["metadata"] as! [String:Any];metadata["profile_registry_version"]="1.1";p["metadata"]=metadata;return p }),
      ("registry metadata missing",{ var p=$0;var metadata=p["metadata"] as! [String:Any];metadata.removeValue(forKey:"naming_registry_version");p["metadata"]=metadata;return p }),
      ("duplicate artifact",{ var p=$0;var artifacts=p["artifacts"] as! [[String:Any]];artifacts[1]["artifactID"]=artifacts[0]["artifactID"];p["artifacts"]=artifacts;return p }),
      ("unsafe path",{ var p=$0;var artifacts=p["artifacts"] as! [[String:Any]];artifacts[0]["targetPathHint"]="../escape";p["artifacts"]=artifacts;return p }),
      ("profile",{ var p=$0;var c=p["targetConstraints"] as! [String:Any];c["profileID"]="unknown";p["targetConstraints"]=c;return p }),
      ("source realm",{ var p=$0;var r=p["sourceRealm"] as! [String:Any];r["realmID"]="APS-REALM-001";p["sourceRealm"]=r;return p }),
      ("destination realm",{ var p=$0;var r=p["destinationRealm"] as! [String:Any];r["stateSignature"]="000000001";p["destinationRealm"]=r;return p }),
      ("node cycle",{ var p=$0;var n=p["topologyNodes"] as! [[String:Any]];n[1]["parentID"]=n[1]["nodeID"];p["topologyNodes"]=n;return p }),
      ("duplicate node",{ var p=$0;var n=p["topologyNodes"] as! [[String:Any]];n[1]["nodeID"]=n[0]["nodeID"];p["topologyNodes"]=n;return p }),
      ("implicit mutation",{ var p=$0;var n=p["topologyNodes"] as! [[String:Any]];n[1]["state"]=["rawValue":1];p["topologyNodes"]=n;return p }),
      ("node ordering",{ var p=$0;var n=p["topologyNodes"] as! [[String:Any]];n.swapAt(1,2);p["topologyNodes"]=n;return p }),
      ("unknown transition",{ var p=$0;var m=p["metadata"] as! [String:Any];m["transition_id"]="unknown";p["metadata"]=m;return p }),
      ("node count",{ var p=$0;var m=p["metadata"] as! [String:Any];m["node_count"]="999";p["metadata"]=m;return p })
    ]
    for (name,change) in changes {
      let forged = try JSONDecoder().decode(ASHGenerationPlan.self,from:JSONSerialization.data(withJSONObject:change(original)))
      let result = ASHArtifactEmitter().emit(plan:forged)
      XCTAssertFalse(forged.validationIssues.isEmpty,name); XCTAssertTrue(result.artifacts.isEmpty,name)
      XCTAssertEqual(result.diagnostics.first?.disposition,.blocked,name)
      for record in result.canonicalDiagnostics(subject:"plan") { XCTAssertTrue(ASHDiagnosticsModule().validateEnvelope(record).isValid,name) }
    }
  }
  func testEveryBehaviorAffectingRequestAndRegistryIdentityChangesDocumentedPlanHash() throws {
    let original = try makePlan(), identity = try original.identity()
    XCTAssertEqual(identity,try makePlan().identity())
    for constraints in [ASHTargetRuntimeConstraints(platform:"IOS"),.init(profileID:"BASELINE"),.init(capabilityTags:["diagnostics"])] {
      XCTAssertNotEqual(identity,try makePlan(constraints).identity())
    }
    for versions in [["profiles":"1.1","naming":"1.0","targets":"1.0"],["profiles":"1.0","naming":"1.1","targets":"1.0"],["profiles":"1.0","naming":"1.0","targets":"1.1"]] {
      let constraints = ASHTargetRuntimeConstraints(registryVersions:versions)
      let raw = ASHGenerationPlan(normalizedState:original.normalizedState,sourceRealm:original.sourceRealm,destinationRealm:original.destinationRealm,topologyNodes:original.topologyNodes,roleAssignments:original.roleAssignments,axiomSummaries:original.axiomSummaries,artifacts:original.artifacts,targetConstraints:constraints,warnings:original.warnings,metadata:original.metadata)
      XCTAssertNotEqual(identity,try raw.identity())
      XCTAssertTrue(raw.validationIssues.contains("REGISTRY_REFERENCE_INVALID"))
      XCTAssertTrue(ASHArtifactEmitter().emit(plan:raw).artifacts.isEmpty)
      let model = ASHStateModel(), registry = ASHTransitionRegistry(stateModel:ASHStateModel())
      let topology = try XCTUnwrap(ASHTopologyGenerator(stateModel:model,transitionRegistry:registry).generateTopology(from:.zero,depth:1).topology)
      let refusal = ASHGenerationPlanner(stateModel:model,realmEncoder:ASHRealmEncoder(stateModel:model)).buildPlan(from:.zero,topology:topology,axiomEvaluation:ASHAxiomEvaluator().evaluate(state:.zero),targetConstraints:constraints)
      XCTAssertNil(refusal.plan)
    }
    XCTAssertNotEqual(identity,try makePlan(transitionID:"APS-TRANSITION-CW-01").identity())
    let result = ASHArtifactEmitter().emit(plan:original)
    XCTAssertEqual(Set(result.artifacts.map(\.planID)),[identity])
    XCTAssertTrue(result.artifacts.allSatisfy { $0.content.contains("plan_id=\(identity)") })
  }
}
