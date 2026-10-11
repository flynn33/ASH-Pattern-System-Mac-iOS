# Getting started — 1.0.0-rc.1

## Select the acquisition route

The public products are `ASHCore` and `ASHPatternSystem`. Core is usable independently; the composed product depends on Core. Declaring both products must not introduce a second Core module. Neither route adds canonical or policy repositories as runtime dependencies.

For source SwiftPM integration:

```swift
// swift-tools-version: 5.10
import PackageDescription
let package = Package(
  name: "MyConsumer",
  platforms: [.macOS(.v14), .iOS(.v16)],
  dependencies: [
    .package(url: "https://github.com/flynn33/ASH-Pattern-System-Mac-iOS", exact: "1.0.0-rc.1")
  ],
  targets: [.target(name: "MyConsumer", dependencies: [
    .product(name: "ASHPatternSystem", package: "ash-pattern-system-mac-ios")
  ])]
)
```

For an immutable pre-tag qualification, replace `exact:` with `revision:` and the actual forty-character source commit from the release manifest. Inspect `Package.resolved`; the only package identity is `ash-pattern-system-mac-ios` and its revision must equal the qualified source. A floating branch does not identify released source.

For binary integration, download the curated aggregate ZIP and `SHA256SUMS`, verify the aggregate digest, then extract into a fresh directory. The extracted root contains `Package.swift`, `Frameworks`, six integration documents, a public example, license, version, component inventory, provenance and internal checksums. Verify `CONTENTS.sha256` before using it. Add the extracted package directory in Xcode or with `.package(name: "ASHAppleSDK", path: "/absolute/extracted/ASH-Apple-SDK-1.0.0-rc.1")`; refer to its public products with package name `ASHAppleSDK`. Keep both framework files together. The individual framework ZIPs are alternatives for explicit manual integration, each rooted at its named XCFramework. Link Core alongside the composed framework and embed each dynamic framework once in the consuming application.

The XCFrameworks contain macOS arm64/x86_64, iOS device arm64 and simulator arm64/x86_64 slices. Xcode selects the correct platform entry. Do not combine an iOS device binary with a simulator target. See [compatibility](sdk-compatibility.md) for actual build/runtime distinctions.

## Own context and lifetime

```swift
import ASHCore
import ASHPatternSystem
let context = ASHOperationalContext(contextID: "my-session", allowedStableStates: [.zero])
let session = try ASHPatternSystemSession(context: context)
let initial = await session.bootstrap(bitString: "000011110")
let recovered = await session.recover()
let snapshot = await session.snapshot()
```

Choose stable targets and fallback evidence from your domain. A syntactically valid state does not provide that policy. The session's immutable snapshots expose the actual class, restrictions, complete canonical chain and recovery outcome. Terminal SAFE_HALT freezes that session; start a separately authorized successor session rather than retrying mutations on a terminal one. Read [API and lifecycle](sdk-api-and-lifecycle.md) and [diagnostics](sdk-diagnostics.md).

## Exercise the example

From the extracted `Examples/SDKConsumer`, run:

```bash
./verify/verify-consumer.sh --sdk /absolute/extracted/ASH-Apple-SDK-1.0.0-rc.1   --output '/absolute/empty/Consumer Evidence' --simulators
```

The supplied harness builds and runs Core-only, composed-only and dual-product Release consumers, then an iPhone and an iPad simulator sample and an unsigned generic iOS device build. It requires macOS, Xcode with available runtimes, Python 3 and ripgrep. Set `ASH_PRODUCER_ROOT` to a producer checkout to deny its reads during command-line binary build/runtime; networking is denied after acquisition. Every report must contain nonzero unique observations and the real SDK version/profile. Actual qualification results belong to the release verification record, not this procedure. Physical-device execution remains an owner phase.
