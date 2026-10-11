# Apple native sources — 1.0.0-rc.1

This nested Swift package and the repository-root package expose exactly `ASHCore` and `ASHPatternSystem`, with Swift tools 5.10, macOS 14/iOS 16 minimums and no external package dependencies. They compile the same production sources. The nested package name is `MaciOS`; that name does not determine SDK version.

`Sources/ASHCore` owns pure semantic services and compile-time-selected support collection. `Sources/ASHOrchestration` produces the public `ASHPatternSystem` module, structural engine and operational session actor. Mutable runtime state is session-owned; the SDK owns no product UI or process shutdown. `ASHSDK.xcodeproj` archives those same source files into separate dynamic frameworks with library evolution, privacy resources and numeric Apple bundle identity.

```bash
swift package --package-path MaciOS dump-package
swift build --package-path MaciOS -c release
swift test --package-path MaciOS -c debug -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift test --package-path MaciOS -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
xcodebuild -list -project MaciOS/ASHSDK.xcodeproj
```

Run from the repository root. See [integration](../docs/sdk-integration.md), [API/lifecycle](../docs/sdk-api-and-lifecycle.md), [diagnostics](../docs/sdk-diagnostics.md), [compatibility](../docs/sdk-compatibility.md), [acceptance](../docs/sdk-acceptance.md), [owner validation](../docs/sdk-owner-validation.md) and [maintainer release](../docs/sdk-maintainer-release.md). Test fixtures record their exact canonical source and adapter hashes; they are excluded from curated binary assets. Prior completion records describe historical application-readiness work and are not current SDK binary evidence.
