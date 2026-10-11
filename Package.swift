// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "ASHPatternSystemApple",
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
      name: "ASHCore",
      path: "MaciOS/Sources/ASHCore",
      resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
    ),
    .target(
      name: "ASHPatternSystem",
      dependencies: [
        "ASHCore"
      ],
      path: "MaciOS/Sources/ASHOrchestration",
      resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
    ),
    .testTarget(
      name: "ASHCoreTests",
      dependencies: ["ASHCore", "ASHPatternSystem"],
      path: "MaciOS/Tests/ASHCoreTests",
      resources: [
        .process("Fixtures")
      ]
    ),
    .testTarget(
      name: "ASHPatternSystemTests",
      dependencies: [
        "ASHPatternSystem"
      ],
      path: "MaciOS/Tests/ASHPatternSystemTests"
    )
  ]
)
