# Public API and lifecycle — 1.0.0

## Products and ownership

`ASHCore` exposes validated state values, nine semantic services, deterministic mathematical helpers, canonical diagnostic records and explicit support capture. `ASHPatternSystem` depends on Core and provides the structural engine and operational session actor. Runtime dependencies are Apple modules only. Public immutable values are Sendable. Service protocols are Sendable and implementations keep immutable dependencies; no blanket unchecked conformance is used.

`ASHState` accepts nine bits, raw integers 0...511, and validated Codable input. XOR is mathematical motion, not permission to mutate a contained or halted session. `ASHStateModel.normalize` preserves every valid state and its realm identity. The fixed sixteen-codeword code generates thirty-two orbits; `reachableStates`, `isReachable`, `codewordID` and exact-rational/finite-double `average` operate on that fixed model.

## Structural assessment and operational context

```swift
import Foundation
import ASHCore

let model = ASHStateModel()
let state = ASHState(bitString: "000011110")!
let context = ASHOperationalContext(
  contextID: "consumer-context-1",
  allowedStableStates: [.zero]
)
try context.validate()
let assessment = model.assess(state: state, context: context)
let registry = ASHTransitionRegistry(stateModel: model)
let recovery = ASHRecoveryEngine(stateModel: model, transitionRegistry: registry)
let result = recovery.recover(state: state, context: context)
```

The context is immutable and carries its stable set, optional preferred target, fallback instance, policy identities and exact supported registry versions. Construction retains caller values; owning service/session boundaries validate them. Missing/invalid context blocks operational assessment. Malformed bit strings return explicit input diagnostics without assigning an operational class. Use `assess(bitString:context:runtime:)` for those inputs.

A state already in the stable set is `STABLE`. One reachable stable target, or an explicitly preferred reachable target, permits `CORRECTABLE`; multiple unselected targets yield `UNSTABLE` and no mutation. No reachable stable target yields `DEGRADED`. Runtime-owned containment, failure and terminal modes override ordinary classification. Recovery never uses Hamming distance, a guessed stable state or arbitrary first-target selection.

Correction applies the declared canonical codeword and verifies the selected target immediately. Fallback is a separate replacement operation: policy 001 sorts configured rank then realm, policy 002 descending verification sequence then realm, and policy 999 escalates without a replacement. Only explicit applicable candidates are considered. The selected candidate is reassessed; accepted fallback classes are STABLE, CORRECTABLE or UNSTABLE. Failure records the attempted policy/candidate and escalates. An empty fallback instance never invents domain-safe defaults.

## Operational session

```swift
import Foundation
import ASHCore
import ASHPatternSystem

let context = ASHOperationalContext(
  contextID: "consumer-session-1", allowedStableStates: [.zero]
)
let collector = try ASHSupportDiagnostics.makeCollector(
  identity: .init(version: ASHSDKVersion.version, build: ASHSDKVersion.buildNumber)
)
let session = try ASHPatternSystemSession(context: context, supportDiagnostics: collector)
let initial = await session.bootstrap(bitString: "000011110")
let recovered = await session.recover()
let contained = await session.enterContainment(reason: "Operator inspection")
let halted = await session.reportContainmentAttempt(
  operation: "synthetic denied write", boundaryBreached: true,
  attemptPrevented: false, propagationObserved: true
)
let frozen = await session.snapshot()
let permittedDirectory = URL(fileURLWithPath: "/absolute/existing/private/export-parent", isDirectory: true)
let export = try await collector.export(to: permittedDirectory)
await collector.shutdown()
await collector.purge()
```

These are synthetic observations; a production caller must supply real boundary evidence. Contradictory evidence is rejected without inferring a breach. A successfully prevented unauthorized attempt leaves containment active. Confirmed propagation despite restrictions enters terminal SAFE_HALT and freezes the complete chain before return. Every subsequent mutation entry returns that same snapshot: bootstrap, transition, recovery, context/containment resolution, containment entry/attempt, failure, halt, planning and emission. Pure services remain independently callable and do not reopen the session.

Mutation is actor-isolated and committed before awaiting optional support capture. A return value describes that specific operation; another caller may have advanced the actor during the collector await. Retrieve `snapshot()` for current state. Collector failure is observable through `supportDiagnosticFailureCount()` and never changes an APS decision. A halted session does not capture further support events. Shutdown/purge belong to the caller's collector lifetime; snapshots are immutable values.

Snapshots additionally expose `containmentRecord`, `safeHaltRecord` and their canonical JSON data. Each wrapper retains the original diagnostic, action, complete chain prefix, typed trigger, product/schema identity and once-stored occurrence time. Times remain outside semantic identity; terminal records never recompute them. Typed trigger overloads reject failed or breach claims without their required observed mode. The supported context always permits containment, so UNRESOLVABLE_BLOCKED_RECOVERY cannot truthfully assert its no-containment prerequisite and is refused; explicit operator/policy halt remains available.

Containment resolution records explicit authority while restrictions remain active; a successor session is required to resume ordinary work. Terminal halt permits diagnostic inspection/export only. The session never terminates the host process.

## Topology, axioms, plans and emission

Topology is structural: root R and ordered C/P/N branches, all nodes through the requested depth, stable depth/generation ordering and APS-NODE IDs. Branching preserves state unless a supported profile explicitly names canonical transitions. Depth, shape, overflow, node budget and cancellation are checked before expansion. Invalid configuration returns explanatory failure instead of partial topology.

`ASHAxiomEvaluator` reports PASS, FAIL or INDETERMINATE for all five predicates. Missing required measurements are INDETERMINATE; structural validity does not invent observations. Planning retains those distinctions. `ASHGenerationPlanner` creates a complete abstract plan without filesystem/network effects; `ASHArtifactEmitter` validates it again and materializes in-memory descriptors only. It rejects incomplete, forged and inconsistent topology/realm/role/artifact contracts and unsafe path hints. A path hint is a descriptor, not an SDK write request.

The product-owned generation registry documents DEFAULT/BASELINE profiles, ORDINAL naming and IN_MEMORY emission for APPLE/MACOS/IOS with NATIVE runtime. These names are Apple implementation policy, not invented canonical constants. Supported registry versions are 1.0. Plan identity covers the full encoded request, topology, assignments, predicates, artifacts, constraints and registry versions; computing an identity does not validate a forged plan. Unknown references fail admission.

## Canonical diagnostics

Use `ASHDiagnosticEnvelope.canonical`, `canonicalJSONData`, `decodeCanonicalJSON`, and `ASHDiagnosticsModule`. The complete fifteen-field snake-case wire representation retains required null fields, nine-field SHA-256 semantic identity, occurrence metadata, root/parent IDs and consecutive sequence. The strict parser defaults to 1 MiB/64 containers and rejects duplicate scalar keys, floats and malformed Unicode. `ASHDiagnosticObject` preserves scalar-distinct keys; supply `fields` for keys that Swift dictionaries would normalize together.

Repeated semantic IDs at different occurrences are permitted. Validation checks immediate predecessors, roots/order, nonblank explanations, rule taxonomy, severity, carried safety phases and terminal finality without unique-key traps. Validation and omission reports are standalone SCHEMA_VALIDATION records outside the original chain.

See [diagnostics](sdk-diagnostics.md), [migration](sdk-migration.md) and the public consumer example for exercised integrations.
