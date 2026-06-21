import Foundation
import XCTest

final class NativeImplementationConformanceTests: XCTestCase {
  private var packageRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  func testNoExternalSwiftPackageDependencies() throws {
    let packageFile = packageRoot.appendingPathComponent("Package.swift")
    let contents = try String(contentsOf: packageFile, encoding: .utf8)

    XCTAssertFalse(
      contents.contains(".package("),
      "External Swift package dependencies are not allowed in the ASH Pattern System base layer."
    )
  }

  func testOnlyAllowedSourceArtifactTypesExist() throws {
    let files = try enumerateTrackedImplementationFiles()
    let allowedExtensions: Set<String> = ["swift", "json", "md"]

    for fileURL in files {
      let ext = fileURL.pathExtension.lowercased()
      let isCanonicalJSONLFixture = ext == "jsonl"
        && fileURL.pathComponents.contains("Fixtures")
        && fileURL.pathComponents.contains("CanonicalReference")

      XCTAssertTrue(
        allowedExtensions.contains(ext) || isCanonicalJSONLFixture,
        "Disallowed file type detected: \(fileURL.path)"
      )
    }
  }

  func testImportsAreAppleOrInternalModulesOnly() throws {
    let files = try enumerateTrackedImplementationFiles()
      .filter { $0.pathExtension == "swift" }

    let allowedImports: Set<String> = [
      "Foundation",
      "XCTest",
      "PackageDescription",
      "SwiftUI",
      "Combine",
      "Observation",
      "SwiftData",
      "CoreData",
      "CloudKit",
      "CryptoKit",
      "Accelerate",
      "Network",
      "OSLog",
      "Dispatch",
      "Security",
      "MapKit",
      "AVFoundation",
      "CoreGraphics",
      "CoreImage",
      "UIKit",
      "AppKit",
      "UserNotifications",
      "StoreKit",
      "WidgetKit",
      "Vision",
      "Metal",
      "MetalKit",
      "RealityKit",
      "SceneKit",
      "SpriteKit",
      "PDFKit",
      "UniformTypeIdentifiers",
      "LocalAuthentication",
      "CoreLocation",
      "Intents",
      "Contacts",
      "CoreML",
      "Photos",
      "WebKit",
      "ASHCore",
      "ASHPatternSystem"
    ]

    for fileURL in files {
      let contents = try String(contentsOf: fileURL, encoding: .utf8)
      for line in contents.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        let moduleName: String?
        if trimmed.hasPrefix("import ") {
          moduleName = String(trimmed.dropFirst("import ".count)).split(separator: " ").first.map(String.init)
        } else if trimmed.hasPrefix("@testable import ") {
          moduleName = String(trimmed.dropFirst("@testable import ".count)).split(separator: " ").first.map(String.init)
        } else {
          moduleName = nil
        }

        if let moduleName {
          XCTAssertTrue(
            allowedImports.contains(moduleName),
            "Non-native or non-internal import '\(moduleName)' found in \(fileURL.path)"
          )
        }
      }
    }
  }

  func testNoProductOrRuntimeCouplingTermsInImplementationSurface() throws {
    let files = try enumerateTrackedImplementationFiles()
      .filter { $0.lastPathComponent != "NativeImplementationConformanceTests.swift" }
    let runtimeNameToken = String(decoding: [102, 111, 114, 115, 101, 116, 116, 105], as: UTF8.self)
    let productNameToken = String(decoding: [97, 101, 111, 115, 116, 97, 114, 97], as: UTF8.self)
    let forbiddenTerms = [runtimeNameToken, productNameToken]

    for fileURL in files {
      let content = try String(contentsOf: fileURL, encoding: .utf8)
      let lowercased = content.lowercased()

      for term in forbiddenTerms {
        XCTAssertFalse(
          lowercased.contains(term),
          "Forbidden coupling term '\(term)' found in \(fileURL.path)"
        )
      }
    }
  }

  private func enumerateTrackedImplementationFiles() throws -> [URL] {
    let fm = FileManager.default
    let roots = [
      packageRoot.appendingPathComponent("Sources"),
      packageRoot.appendingPathComponent("Tests"),
      packageRoot.appendingPathComponent("README.md"),
      packageRoot.appendingPathComponent("Package.swift")
    ]

    var files: [URL] = []
    for root in roots {
      var isDirectory: ObjCBool = false
      guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory) else {
        continue
      }

      if !isDirectory.boolValue {
        files.append(root)
        continue
      }

      let enumerator = fm.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )

      while let file = enumerator?.nextObject() as? URL {
        if file.pathComponents.contains(".build") {
          continue
        }
        let values = try file.resourceValues(forKeys: [.isRegularFileKey])
        if values.isRegularFile == true {
          files.append(file)
        }
      }
    }

    return files.sorted { $0.path < $1.path }
  }
}
