import Foundation
import Darwin

@main
struct ConsumerCLI {
  static func main() async {
    do {
      let arguments = CommandLine.arguments
      guard arguments.count == 3 else { throw ConsumerCheckError.failed("Usage: ConsumerSmoke EXPORT_DIRECTORY REPORT_JSON") }
      let path = arguments[1].hasPrefix("/var/") ? "/private" + arguments[1] : arguments[1]
      let destination = URL(fileURLWithPath: path, isDirectory: true).resolvingSymlinksInPath()
      let report = try await ConsumerChecks().run(exportRoot: destination)
      let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
      try encoder.encode(report).write(to: URL(fileURLWithPath: arguments[2]), options: .atomic)
      print("Executed \(report.checks.count) public SDK cases; \(report.sdkVersion); \(report.diagnosticProfile)")
    } catch {
      FileHandle.standardError.write(Data("Consumer failure: \(error)\n".utf8))
      exit(1)
    }
  }
}
