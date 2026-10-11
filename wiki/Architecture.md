# Architecture — 1.0.0

Consumer → ASHPatternSystem → ASHCore → Apple modules. Core-only integration is supported. Root/nested SwiftPM and explicit Xcode framework schemes compile the same production files. Internal ASHOrchestration folder supplies the unchanged public ASHPatternSystem module. No canonical or policy runtime is acquired.

Core owns fixed state/math, nine immutable semantic services, complete diagnostic records and caller-created support collectors. The composed actor owns mutable operational context/state/chain and frozen terminal snapshots. Pure services do not reopen a contained or halted session. Plans and emitted descriptors are in-memory; support export writes only to an explicit permitted destination.

[Public API/lifecycle](https://github.com/flynn33/ASH-Pattern-System-Mac-iOS/blob/v1.0.0/docs/sdk-api-and-lifecycle.md) and [source graph](https://github.com/flynn33/ASH-Pattern-System-Mac-iOS/blob/v1.0.0/docs/02-target-repository-shape.md) describe concrete ownership and member paths.
