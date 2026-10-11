import SwiftUI
import Foundation
import ASHCore
import ASHPatternSystem

@MainActor
final class ConsumerController: ObservableObject {
  @Published var status = "Ready"
  private var running = false

  func run() async {
    guard !running else { return }
    running = true
    defer { running = false }
    do {
      let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      for name in ["ConsumerReport.json", "ConsumerFailure.txt"] {
        let prior = documents.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: prior.path) { try FileManager.default.removeItem(at: prior) }
      }
      let destination = documents.appendingPathComponent("SDKConsumerExports", isDirectory: true)
      try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
      let report = try await ConsumerChecks().run(exportRoot: URL(fileURLWithPath: destination.path.hasPrefix("/var/") ? "/private" + destination.path : destination.path).resolvingSymlinksInPath())
      let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
      try encoder.encode(report).write(to: documents.appendingPathComponent("ConsumerReport.json"), options: .atomic)
      status = "Passed \(report.checks.count) checks; \(report.diagnosticProfile). Exports in Documents/SDKConsumerExports."
    } catch {
      status = "Failed: \(error)"
      let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      try? Data(String(describing: error).utf8).write(to: documents.appendingPathComponent("ConsumerFailure.txt"), options: .atomic)
    }
  }
}

@main
struct ConsumerApp: App {
  @StateObject private var controller = ConsumerController()
  var body: some Scene {
    WindowGroup {
      VStack(spacing: 16) {
        Text("ASH Apple SDK \(ASHSDKVersion.version)").font(.headline)
        Text(controller.status).accessibilityIdentifier("consumer-status")
        Button("Run checks and export") { Task { await controller.run() } }
      }
      .padding()
      .task { await controller.run() }
    }
  }
}
