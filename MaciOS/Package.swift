// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "MaciOS",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v16),
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "ASHCore",
      targets: ["ASHCore"]
    ),
    .library(
      name: "ASHPatternSystem",
      targets: ["ASHPatternSystem"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "ASHCore"
    ),
    .target(
      name: "ASHPatternSystem",
      dependencies: [
        "ASHCore"
      ]
    ),
    .testTarget(
      name: "ASHCoreTests",
      dependencies: ["ASHCore"],
      resources: [
        .process("Fixtures")
      ]
    ),
    .testTarget(
      name: "ASHPatternSystemTests",
      dependencies: [
        "ASHPatternSystem"
      ]
    )
  ]
)
