# Compatibility — 1.0.0

| Property | Declared or observed identity |
|---|---|
| SDK semantic version | 1.0.0 |
| Apple marketing/build | 1.0.0 / 2 |
| Public modules | ASHCore, ASHPatternSystem |
| Swift package manifest | tools 5.10; no external package dependencies |
| Deployment minimums | macOS 14.0, iOS 16.0 |
| Archive toolchain | Xcode 27.0 (27A266a), Apple Swift 6.4 |
| Qualification host | arm64 macOS 27.0.1 (26A434) |
| Publisher signature | unsigned; archive linker ad-hoc signature where present is not owner signing |

| Platform | Release binary contents | Runtime qualification boundary |
|---|---|---|
| macOS | arm64 + x86_64 | Native arm64 host; translated x86_64 runtime unavailable on this host |
| iOS device | arm64 | Unsigned generic-device compile/link; physical runtime pending owner validation |
| iOS Simulator | arm64 + x86_64 | Available native arm64 iPhone/iPad runtimes; x86_64 cross-build/interface checks only |

Both frameworks are dynamic, use library evolution and distribute public `.swiftinterface` files. Qualification typechecks the public interfaces independently, inspects actual Mach-O platform/minimum/architecture metadata, checks Core linkage and matching dSYM UUIDs, and exercises public consumers. Swift tools 5.10 in a manifest does not prove that Swift 5.10 can import interfaces emitted by Swift 6.4. Older compiler, macOS 14 runtime and iOS 16 runtime are untested. Do not substitute deployment metadata for those missing executions.

The final release manifests and external verification record name the exact integrated source, canonical authority, method and successor profiles, actual simulator identifiers/runtime versions, and successful consumer case counts. A historical source-only receipt is not binary qualification. Source and binary consumers exercise the same deterministic outcomes and are compared explicitly. No third-party runtime acquisition, network service or canonical/policy checkout is required by the shipped SDK.

See `Release-Notes.md`, `Migration.md` and the supplied consumer acceptance document in binary assets; the source equivalents are `sdk-release-notes.md`, `sdk-migration.md` and `Examples/SDKConsumer/docs/ConsumerAcceptance.md`.
