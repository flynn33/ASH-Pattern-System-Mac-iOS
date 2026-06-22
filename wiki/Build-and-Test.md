# Build And Test

## Prerequisites

- Swift 5.10.
- Xcode with package build support for macOS and iOS generic destinations.

## SwiftPM

```bash
swift package --package-path MaciOS dump-package
swift build --package-path MaciOS -c release
swift test --package-path MaciOS
```

## Xcode Package Builds

```bash
xcodebuild -scheme ASHCore -destination 'generic/platform=macOS' -configuration Release build -quiet
xcodebuild -scheme ASHPatternSystem -destination 'generic/platform=macOS' -configuration Release build -quiet
xcodebuild -scheme ASHCore -destination 'generic/platform=iOS' -configuration Release build -quiet
xcodebuild -scheme ASHPatternSystem -destination 'generic/platform=iOS' -configuration Release build -quiet
```

## Current Evidence

The current evidence records SwiftPM release builds, Swift tests, and Xcode package-scheme builds for generic macOS and iOS. It does not record app archives, notarization, App Store/TestFlight distribution, simulator matrix, physical-device matrix, accessibility audits, performance budgets, or clean install/upgrade/removal validation.
