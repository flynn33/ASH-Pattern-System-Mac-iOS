# ASH Pattern System — Apple SDK

Version **1.0.0**, Apple marketing version **1.0.0**, build **2**.

The SDK provides the public Swift products `ASHCore` and `ASHPatternSystem` for macOS 14+ and iOS 16+. Both the root and nested Swift packages use the same native sources and have no external package dependencies. The binary distribution contains two dynamic XCFrameworks with public Swift interfaces and matching archive dSYMs.

`ASHCore` owns the fixed nine-dimensional state model, nine semantic services, canonical diagnostics and bounded support exports. `ASHPatternSystem` composes Core and provides an actor-owned operational session with explicit context, containment and terminal snapshots. Generation and emission produce abstract plans and in-memory descriptors. The standalone example owns its UI and application lifecycle.

## Integration

```swift
.package(url: "https://github.com/flynn33/ASH-Pattern-System-Mac-iOS", exact: "1.0.0")
```

Use package identity `ash-pattern-system-mac-ios` with `.product(name: "ASHCore", package: "ash-pattern-system-mac-ios")` or `.product(name: "ASHPatternSystem", package: "ash-pattern-system-mac-ios")`. The composed product supplies Core transitively. For binary integration, obtain the curated `ASH-Apple-SDK-1.0.0.zip` from [the SDK release](https://github.com/flynn33/ASH-Pattern-System-Mac-iOS/releases/tag/v1.0.0), verify its checksums and add the extracted package locally. GitHub's automatic source archives contain source rather than the precompiled SDK.

Read [integration](docs/sdk-integration.md), [public API and lifecycle](docs/sdk-api-and-lifecycle.md), [diagnostics](docs/sdk-diagnostics.md), [migration](docs/sdk-migration.md), [compatibility](docs/sdk-compatibility.md), [security](docs/sdk-security.md) and [release notes](docs/sdk-release-notes.md). [Owner validation](docs/sdk-owner-validation.md) separates physical-device acceptance from the SDK's automated qualification. The public-only example is [Examples/SDKConsumer](Examples/SDKConsumer/docs/ConsumerAcceptance.md).

## Build and verify

```bash
swift build -c debug
swift test -c debug -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift build -c release
swift test -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift test --package-path MaciOS -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
python3 tools/sdk/sdk.py composition
python3 -m unittest discover -s tools/sdk -p 'test_*.py' -v
```

The explicit archive project is `MaciOS/ASHSDK.xcodeproj`, with shared `ASHCore` and `ASHPatternSystem` schemes. See [maintainer release procedure](docs/sdk-maintainer-release.md) for clean-source archives, immutable provenance, isolated consumer tests and release transaction gates.

## Authority and qualification

The canonical semantic authority is [ASH-Pattern-System at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8](https://github.com/flynn33/ASH-Pattern-System/tree/50d7e5ab88932a4a967ffc2c83bd18fae45b73c8), canonical 1.0.0-rc.3. Raven Forge Development method remains 0.7.0 at `8dd6e75a06336491b249fac3577db75458db8c13`; successor profiles are independently versioned policy inputs, never runtime dependencies. [Authority binding](docs/sdk-authority-and-conformance.md) describes the precedence and coverage.

The [current source acceptance record](docs/sdk-acceptance.md) distinguishes source tests from final integrated binary, consumer and publication evidence. The final asset manifests identify the exact integrated source, canonical and profile revisions. Host/simulator execution does not establish physical-device, older-system, older-compiler or translated Intel runtime qualification. Publisher frameworks are unsigned; the sample's local simulator signing is separate. This SDK release does not claim a signed application, notarization, App Store or TestFlight delivery. Historical reports under `completion-evidence/` retain their original dates and scope.

## Repository

- `Package.swift`, `MaciOS/Package.swift`: equivalent public product graph.
- `MaciOS/Sources/ASHCore`, `MaciOS/Sources/ASHOrchestration`: native implementation; the internal folder name does not change the `ASHPatternSystem` module.
- `MaciOS/Tests`: maintained tests and explicitly acquired, pinned reference fixtures.
- `tools/sdk`: archive, curation, checksum and consumer gates.
- `docs`, `wiki`: active Apple SDK documentation and maintained wiki source.
- `specs`, `handoff-templates`: retained historical reference with explicit current-authority precedence.

## Contributing and license

Copyright (c) 2026 James Daley, Raven Forge Software. Licensed under the Apache License, Version 2.0; see [LICENSE](LICENSE). Outside contributions are not accepted; see [CONTRIBUTING.md](CONTRIBUTING.md).
