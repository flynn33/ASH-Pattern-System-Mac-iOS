#if !DEBUG
import Foundation

actor ASHReleaseDiagnostics: ASHSupportDiagnosticCollecting {
  private var buffer: ASHSupportBuffer
  init(identity: ASHSupportIdentity) {
    buffer = ASHSupportBuffer(identity: identity, profile: "release-minimal", eventLimit: 256, byteLimit: 1024 * 1024)
  }
  func capture(_ event: ASHSupportEventInput) throws { try buffer.capture(event) }
  func snapshot() -> ASHSupportSnapshot { buffer.snapshot() }
  func export(to destination: URL) throws -> ASHSupportExport {
    do { return try ASHSupportExporter.export(buffer.snapshot(), to: destination) }
    catch { buffer.failures += 1; throw error }
  }
  func purge() { buffer.purge() }
  func shutdown() { buffer.closed = true }
}
#endif
