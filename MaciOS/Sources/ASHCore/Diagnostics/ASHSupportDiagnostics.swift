import Foundation
import Darwin

public struct ASHSupportIdentity: Codable, Equatable, Sendable {
  public let version: String
  public let build: String
  public let sourceCommit: String?
  public init(version: String, build: String, sourceCommit: String? = nil) {
    self.version = version; self.build = build; self.sourceCommit = sourceCommit
  }
}

public struct ASHSupportFailure: Codable, Equatable, Sendable {
  public let domain: String
  public let code: String
  public let message: String
  public let causes: [String]
  public init(domain: String, code: String, message: String, causes: [String] = []) {
    self.domain = domain; self.code = code; self.message = message; self.causes = causes
  }
}

public struct ASHSupportEventInput: Sendable {
  public let operation: String
  public let correlation: String
  public let expected: String
  public let actual: String
  public let context: [String: String]
  public let failure: ASHSupportFailure?
  public let canonicalDiagnostics: [ASHDiagnosticEnvelope]
  public init(operation: String, correlation: String, expected: String, actual: String,
              context: [String: String] = [:], failure: ASHSupportFailure? = nil,
              canonicalDiagnostics: [ASHDiagnosticEnvelope] = []) {
    self.operation = operation; self.correlation = correlation; self.expected = expected
    self.actual = actual; self.context = context; self.failure = failure
    self.canonicalDiagnostics = canonicalDiagnostics
  }
}

public struct ASHSupportEvent: Codable, Equatable, Sendable {
  public let id: String
  public let sequence: UInt64
  public let timeUTC: String
  public let operation: String
  public let correlation: String
  public let expected: String
  public let actual: String
  public let context: [String: String]
  public let failure: ASHSupportFailure?
  public let canonicalDiagnostics: [ASHDiagnosticEnvelope]
}

public struct ASHSupportSnapshot: Codable, Equatable, Sendable {
  public let schemaVersion: String
  public let bundleID: String
  public let sessionID: String
  public let identity: ASHSupportIdentity
  public let profile: String
  public let environment: String
  public let captureStartUTC: String
  public let captureEndUTC: String
  public let events: [ASHSupportEvent]
  public let eventLimit: Int
  public let byteLimit: Int
  public let retainedBytes: Int
  public let droppedEvents: UInt64
  public let excludedFields: UInt64
  public let redactions: UInt64
  public let collectorFailures: UInt64
  public let closed: Bool
  public let coverageLimits: [String]
}

public struct ASHSupportExport: Sendable {
  public let directory: URL
  public let json: URL
  public let markdown: URL
  public let snapshot: ASHSupportSnapshot
}

public enum ASHSupportError: Error, Equatable, Sendable {
  case closed
  case recordTooLarge
  case invalidIdentity
  case unsafeDestination
  case storage(operation: String, code: Int32)
  case exportTooLarge
  case invalidCanonicalEvidence
  case unsafeCanonicalEvidence
}

/// Actor isolation serializes capture, snapshots, purge, export and shutdown.
/// Canonical chains belong to the session, independently of this support buffer.
public protocol ASHSupportDiagnosticCollecting: Actor {
  func capture(_ event: ASHSupportEventInput) throws
  func snapshot() -> ASHSupportSnapshot
  func export(to destination: URL) throws -> ASHSupportExport
  func purge()
  func shutdown()
}

public enum ASHSupportDiagnostics {
  public static func makeCollector(identity: ASHSupportIdentity) throws -> any ASHSupportDiagnosticCollecting {
    func matches(_ value: String, _ pattern: String) -> Bool {
      guard let range = value.range(of: pattern, options: .regularExpression) else { return false }
      return range.lowerBound == value.startIndex && range.upperBound == value.endIndex
    }
    guard identity.version.utf8.count <= 64,
      matches(identity.version, "^[0-9]+\\.[0-9]+\\.[0-9]+(?:-[A-Za-z0-9.-]+)?$"),
      identity.build.utf8.count <= 18, matches(identity.build, "^[0-9]{1,18}$") else {
      throw ASHSupportError.invalidIdentity
    }
    if let source = identity.sourceCommit {
      guard source.utf8.count == 40, matches(source, "^[0-9a-f]{40}$") else {
        throw ASHSupportError.invalidIdentity
      }
    }
    #if DEBUG
    return ASHDevelopmentDiagnostics(identity: identity)
    #else
    return ASHReleaseDiagnostics(identity: identity)
    #endif
  }
}

struct ASHSupportBuffer {
  let identity: ASHSupportIdentity
  let profile: String
  let eventLimit: Int
  let byteLimit: Int
  let recordLimit = 16 * 1024
  let sessionID = UUID().uuidString
  let start = ASHSupportBuffer.now()
  var events: [ASHSupportEvent] = []
  var eventSizes: [Int] = []
  var bytes = 0
  var sequence: UInt64 = 0
  var dropped: UInt64 = 0
  var excluded: UInt64 = 0
  var redactions: UInt64 = 0
  var failures: UInt64 = 0
  var closed = false

  mutating func capture(_ input: ASHSupportEventInput) throws {
    guard !closed else { throw ASHSupportError.closed }
    guard !Task.isCancelled else { throw CancellationError() }
    // Reject cardinality before traversal or allocating canonical projection arrays.
    guard input.context.count <= 32, (input.failure?.causes.count ?? 0) <= 16,
      input.canonicalDiagnostics.count <= 64 else { failures += 1; throw ASHSupportError.recordTooLarge }
    // Check before copying or regex work, including data excluded by the policy.
    let textSize = input.operation.utf8.count + input.correlation.utf8.count
      + input.expected.utf8.count + input.actual.utf8.count
    let contextSize = input.context.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count }
    let failureSize = input.failure.map { $0.domain.utf8.count + $0.code.utf8.count + $0.message.utf8.count + $0.causes.reduce(0) { $0 + $1.utf8.count } } ?? 0
    guard textSize <= recordLimit, contextSize <= recordLimit - textSize,
          failureSize <= recordLimit - textSize - contextSize, input.context.count <= 32,
          (input.failure?.causes.count ?? 0) <= 16 else {
      failures += 1; throw ASHSupportError.recordTooLarge
    }
    var canonicalBudget = recordLimit - textSize - contextSize - failureSize
    guard input.canonicalDiagnostics.allSatisfy({ ASHSupportSerialization.fitsEnvelope($0, remaining: &canonicalBudget) }) else {
      failures += 1; throw ASHSupportError.recordTooLarge
    }
    if !input.canonicalDiagnostics.isEmpty {
      guard ASHDiagnosticsModule().validateChain(input.canonicalDiagnostics).isValid else {
        failures += 1; throw ASHSupportError.invalidCanonicalEvidence
      }
      guard input.canonicalDiagnostics.allSatisfy({ ASHSupportRedaction.text($0.canonicalRecord.canonicalJSONString) == $0.canonicalRecord.canonicalJSONString }) else {
        failures += 1; throw ASHSupportError.unsafeCanonicalEvidence
      }
    }
    #if DEBUG
    let permitted: Set<String> = ["state", "fixture", "registry", "classification", "rule", "outcome", "source", "attempt", "reproduction"]
    #else
    let permitted: Set<String> = ["state", "fixture", "classification", "rule", "outcome"]
    #endif
    var context: [String: String] = [:]
    for (key, value) in input.context {
      if permitted.contains(key) { context[key] = sanitize(value) } else { excluded += 1 }
    }
    let failure = input.failure.map {
      ASHSupportFailure(domain: sanitize($0.domain), code: sanitize($0.code), message: sanitize($0.message), causes: $0.causes.map { sanitize($0) })
    }
    sequence += 1
    let event = ASHSupportEvent(id: "\(sessionID):\(sequence)", sequence: sequence,
      timeUTC: Self.now(), operation: sanitize(input.operation), correlation: sanitize(input.correlation),
      expected: sanitize(input.expected), actual: sanitize(input.actual), context: context, failure: failure, canonicalDiagnostics: input.canonicalDiagnostics)
    let encoded = ASHSupportSerialization.event(event).canonicalJSONData
    guard encoded.count <= recordLimit else { failures += 1; throw ASHSupportError.recordTooLarge }
    while events.count >= eventLimit || bytes + encoded.count > byteLimit {
      bytes -= eventSizes.removeFirst(); events.removeFirst(); dropped += 1
    }
    events.append(event); eventSizes.append(encoded.count); bytes += encoded.count
  }

  mutating func sanitize(_ value: String) -> String {
    let result = ASHSupportRedaction.text(value)
    if result != value { redactions += 1 }
    return result
  }

  func snapshot() -> ASHSupportSnapshot {
    #if targetEnvironment(simulator)
    let host = "simulator"
    #elseif os(macOS)
    let host = "macOS-host"
    #else
    let host = "iOS-runtime; physical execution not inferred"
    #endif
    #if arch(arm64)
    let architecture = "arm64"
    #else
    let architecture = "x86_64"
    #endif
    return ASHSupportSnapshot(schemaVersion: "1.0", bundleID: UUID().uuidString,
      sessionID: sessionID, identity: identity, profile: profile,
      environment: "\(host)/\(architecture); \(ProcessInfo.processInfo.operatingSystemVersionString)",
      captureStartUTC: start, captureEndUTC: Self.now(), events: events, eventLimit: eventLimit,
      byteLimit: byteLimit, retainedBytes: bytes, droppedEvents: dropped, excludedFields: excluded,
      redactions: redactions, collectorFailures: failures, closed: closed,
      coverageLimits: ["SDK identity and OS/platform/architecture metadata are captured; event/failure data is caller-supplied and allowlisted. No ambient payload or network collection.",
        "Canonical chains remain owned by the APS session; support retention never modifies them.",
        "No crash-time flush, stack capture, CPU/memory measurement, external attachments or persistence before explicit export.",
        "Canonical evidence must be a valid complete chain, free of recognized secret syntax; unsafe records fail capture without changing session-owned evidence.",
        identity.sourceCommit == nil ? "Source commit unavailable: caller did not supply verified build provenance." : "Source identity supplied by caller; export does not authenticate it."])
  }

  mutating func purge() { events.removeAll(); eventSizes.removeAll(); bytes = 0 }
  static func now() -> String { ISO8601DateFormatter().string(from: Date()) }
}

/// Typed serialization preserves canonical inner record bytes without Foundation key folding.
enum ASHSupportSerialization {
  static func fitsEnvelope(_ record: ASHDiagnosticEnvelope, remaining: inout Int) -> Bool {
    // Do not construct canonicalRecord until raw envelope strings/arrays fit.
    guard record.ruleIDs.count <= 4096, record.notes.count <= 4096 else { return false }
    let text = [record.schemaVersion, record.diagnosticReference, record.diagnosticKind.rawValue,
      record.severity.rawValue, record.stage.rawValue, record.disposition.rawValue,
      record.subjectReference, record.parentDiagnosticReference ?? "", record.chainRootReference, record.summary]
    for value in text { if !fits(.string(value), remaining: &remaining, depth: 0) { return false } }
    for value in record.ruleIDs { if !fits(.string(value), remaining: &remaining, depth: 0) { return false } }
    for value in record.notes { if !fits(.string(value), remaining: &remaining, depth: 0) { return false } }
    guard fits(.object(record.details), remaining: &remaining, depth: 0) else { return false }
    if let metadata = record.occurrenceMetadata, !fits(.object(metadata), remaining: &remaining, depth: 0) { return false }
    return true
  }
  static func fits(_ value: ASHDiagnosticValue, remaining: inout Int, depth: Int) -> Bool {
    guard depth <= 64, remaining > 0 else { return false }
    remaining -= 1
    switch value {
    case .string(let text): remaining -= text.utf8.count
    case .integer: remaining -= 20
    case .bool: remaining -= 5
    case .null: remaining -= 4
    case .array(let values):
      for value in values { if !fits(value, remaining: &remaining, depth: depth + 1) { return false } }
    case .object(let object):
      for field in object.fields {
        remaining -= field.key.utf8.count + 3
        if !fits(field.value, remaining: &remaining, depth: depth + 1) { return false }
      }
    }
    return remaining >= 0
  }
  static func event(_ e: ASHSupportEvent) -> ASHDiagnosticValue {
    .object([
      "id": .string(e.id), "sequence": .integer(Int64(e.sequence)), "timeUTC": .string(e.timeUTC),
      "operation": .string(e.operation), "correlation": .string(e.correlation),
      "expected": .string(e.expected), "actual": .string(e.actual),
      "context": .object(ASHDiagnosticObject(e.context.mapValues(ASHDiagnosticValue.string))),
      "failure": e.failure.map { .object([
        "domain": .string($0.domain), "code": .string($0.code), "message": .string($0.message),
        "causes": .array($0.causes.map(ASHDiagnosticValue.string))
      ]) } ?? .null,
      "canonicalDiagnostics": .array(e.canonicalDiagnostics.map { .object($0.canonicalRecord) })
    ])
  }
  static func snapshot(_ s: ASHSupportSnapshot) -> ASHDiagnosticValue {
    .object([
      "schemaVersion": .string(s.schemaVersion), "bundleID": .string(s.bundleID), "sessionID": .string(s.sessionID),
      "identity": .object(["version": .string(s.identity.version), "build": .string(s.identity.build),
        "sourceCommit": s.identity.sourceCommit.map(ASHDiagnosticValue.string) ?? .null]),
      "profile": .string(s.profile), "environment": .string(s.environment),
      "captureStartUTC": .string(s.captureStartUTC), "captureEndUTC": .string(s.captureEndUTC),
      "events": .array(s.events.map(event)), "eventLimit": .integer(Int64(s.eventLimit)),
      "byteLimit": .integer(Int64(s.byteLimit)), "retainedBytes": .integer(Int64(s.retainedBytes)),
      "droppedEvents": .integer(Int64(s.droppedEvents)), "excludedFields": .integer(Int64(s.excludedFields)),
      "redactions": .integer(Int64(s.redactions)), "collectorFailures": .integer(Int64(s.collectorFailures)),
      "closed": .bool(s.closed), "coverageLimits": .array(s.coverageLimits.map(ASHDiagnosticValue.string))
    ])
  }
}

enum ASHSupportRedaction {
  static func text(_ value: String) -> String {
    var text = value
    for pattern in [
      "(?i)(authorization|password|passwd|secret|api[_-]?key|access[_-]?token|refresh[_-]?token|cookie|private[_-]?payload)[\"']?\\s*[:=]\\s*[^\\r\\n,;&]+",
      "(?i)bearer\\s+[A-Za-z0-9._~+/=-]+",
      "(?i)(https?://)[^/@\\s]+:[^/@\\s]+@",
      "(?i)([?&](token|key|password|secret|auth)=)[^&#\\s]+",
      "\\b(sk-|ghp_|gho_)[A-Za-z0-9_-]+",
      "/(?:Users|home|private|var|tmp)/[^\\s,;]+",
      "(?s)-----BEGIN [^-]*PRIVATE KEY-----.*?-----END [^-]*PRIVATE KEY-----"
    ] {
      text = text.replacingOccurrences(of: pattern, with: "[REDACTED]", options: .regularExpression)
    }
    return text
  }
}

enum ASHSupportExporter {
  static func export(_ snapshot: ASHSupportSnapshot, to destination: URL) throws -> ASHSupportExport {
    guard !Task.isCancelled else { throw CancellationError() }
    guard destination.isFileURL, destination.path.hasPrefix("/"),
          !destination.pathComponents.contains("..") else { throw ASHSupportError.unsafeDestination }
    // A second redaction pass precedes either persisted representation.
    let safeEvents = snapshot.events.map { event in
      ASHSupportEvent(id: event.id, sequence: event.sequence, timeUTC: event.timeUTC,
        operation: ASHSupportRedaction.text(event.operation), correlation: ASHSupportRedaction.text(event.correlation),
        expected: ASHSupportRedaction.text(event.expected), actual: ASHSupportRedaction.text(event.actual),
        context: event.context.mapValues(ASHSupportRedaction.text), failure: event.failure.map {
          ASHSupportFailure(domain: ASHSupportRedaction.text($0.domain), code: ASHSupportRedaction.text($0.code),
            message: ASHSupportRedaction.text($0.message), causes: $0.causes.map(ASHSupportRedaction.text))
        }, canonicalDiagnostics: event.canonicalDiagnostics)
    }
    guard safeEvents.allSatisfy({ event in event.canonicalDiagnostics.allSatisfy { ASHSupportRedaction.text($0.canonicalRecord.canonicalJSONString) == $0.canonicalRecord.canonicalJSONString } }) else { throw ASHSupportError.unsafeCanonicalEvidence }
    let safe = ASHSupportSnapshot(schemaVersion: snapshot.schemaVersion, bundleID: snapshot.bundleID,
      sessionID: snapshot.sessionID, identity: snapshot.identity, profile: snapshot.profile,
      environment: snapshot.environment, captureStartUTC: snapshot.captureStartUTC, captureEndUTC: snapshot.captureEndUTC,
      events: safeEvents, eventLimit: snapshot.eventLimit, byteLimit: snapshot.byteLimit, retainedBytes: snapshot.retainedBytes,
      droppedEvents: snapshot.droppedEvents, excludedFields: snapshot.excludedFields, redactions: snapshot.redactions,
      collectorFailures: snapshot.collectorFailures, closed: snapshot.closed, coverageLimits: snapshot.coverageLimits)
    let json = ASHSupportSerialization.snapshot(safe).canonicalJSONData
    let markdown = Data(render(safe).utf8)
    guard json.count + markdown.count <= snapshot.byteLimit * 4 else { throw ASHSupportError.exportTooLarge }
    let base = try openDirectory(destination)
    defer { close(base) }
    let name = "ASH-Support-\(safe.bundleID)"
    let temporary = ".\(name).partial"
    guard mkdirat(base, temporary, 0o700) == 0 else { throw storage("create-bundle") }
    let folder = openat(base, temporary, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard folder >= 0 else { throw storage("open-bundle") }
    defer { close(folder) }
    do {
      try write(json, name: "Diagnostics.json", directory: folder)
      try write(markdown, name: "Diagnostics.md", directory: folder)
      guard !Task.isCancelled else { throw CancellationError() }
      guard fsync(folder) == 0 else { throw storage("sync-bundle") }
      guard renameatx_np(base, temporary, base, name, UInt32(RENAME_EXCL)) == 0 else { throw storage("publish-bundle") }
    } catch {
      // The immutable actor snapshot remains available; no success for a partial pair.
      unlinkat(folder, "Diagnostics.json", 0); unlinkat(folder, "Diagnostics.md", 0)
      unlinkat(base, temporary, AT_REMOVEDIR)
      throw error
    }
    let directory = destination.appendingPathComponent(name, isDirectory: true)
    return ASHSupportExport(directory: directory, json: directory.appendingPathComponent("Diagnostics.json"),
      markdown: directory.appendingPathComponent("Diagnostics.md"), snapshot: safe)
  }

  private static func openDirectory(_ url: URL) throws -> Int32 {
    var current = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
    guard current >= 0 else { throw storage("open-root") }
    for component in url.pathComponents.dropFirst() {
      guard component != ".", component != "..", !component.isEmpty else { close(current); throw ASHSupportError.unsafeDestination }
      let next = openat(current, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
      let saved = errno; close(current)
      guard next >= 0 else { throw ASHSupportError.storage(operation: "open-destination", code: saved) }
      current = next
    }
    return current
  }

  private static func write(_ data: Data, name: String, directory: Int32) throws {
    let fd = openat(directory, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard fd >= 0 else { throw storage("open-file") }
    defer { close(fd) }
    try data.withUnsafeBytes { bytes in
      var offset = 0
      while offset < bytes.count {
        let count = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
        if count < 0 && errno == EINTR { continue }
        guard count > 0 else { throw storage("write-file") }
        offset += count
      }
    }
    guard fsync(fd) == 0 else { throw storage("sync-file") }
  }
  private static func storage(_ operation: String) -> ASHSupportError { .storage(operation: operation, code: errno) }

  private static func render(_ snapshot: ASHSupportSnapshot) -> String {
    func escape(_ text: String) -> String {
      var output = ""
      for scalar in text.unicodeScalars {
        switch scalar.value {
        case 0x26: output += "&amp;"
        case 0x3C: output += "&lt;"
        case 0x3E: output += "&gt;"
        case 0x60: output += "&#96;"
        case 0x5B: output += "&#91;"
        case 0x5D: output += "&#93;"
        case 0x5C: output += "&#92;"
        case 0x2A: output += "&#42;"
        case 0x5F: output += "&#95;"
        case 0x23: output += "&#35;"
        default: output.unicodeScalars.append(scalar)
        }
      }
      return output
    }
    var output = "# ASH support evidence\n\nBundle: \(snapshot.bundleID)\n\nSchema: \(snapshot.schemaVersion); SDK: \(snapshot.identity.version); build: \(snapshot.identity.build); source: \(snapshot.identity.sourceCommit ?? "unavailable")\n\nProfile: \(snapshot.profile); environment: \(escape(snapshot.environment))\n\nCapture: \(snapshot.captureStartUTC) to \(snapshot.captureEndUTC); session: \(snapshot.sessionID)\n\nRetained: \(snapshot.events.count) events / \(snapshot.retainedBytes) bytes; capacity: \(snapshot.eventLimit) / \(snapshot.byteLimit) bytes; dropped: \(snapshot.droppedEvents); excluded fields: \(snapshot.excludedFields); redactions: \(snapshot.redactions); collector/export failures: \(snapshot.collectorFailures).\n\n"
    output += "## Coverage limits\n\n" + snapshot.coverageLimits.map { "- \(escape($0))" }.joined(separator: "\n") + "\n\n## Full retained event and incident evidence\n\n"
    for event in snapshot.events {
      output += "### Event \(event.sequence): \(escape(event.operation))\n\nID: \(event.id); correlation: \(escape(event.correlation)); UTC: \(event.timeUTC)\n\nExpected: \(escape(event.expected))\n\nObserved: \(escape(event.actual))\n\n"
      for key in event.context.keys.sorted() { output += "- \(escape(key)): \(escape(event.context[key]!))\n" }
      if !event.canonicalDiagnostics.isEmpty {
        output += "\nCanonical schema 1.0: full retained causal chain (\(event.canonicalDiagnostics.count) records).\n\n"
        for record in event.canonicalDiagnostics {
          output += "- Canonical occurrence \(record.sequenceNumber): \(record.diagnosticReference); parent: \(record.parentDiagnosticReference ?? "null"); root: \(record.chainRootReference).\n"
          output += "\n" + escape(record.canonicalRecord.canonicalJSONString) + "\n\n"
        }
      }
      if let failure = event.failure {
        output += "\nIncident \(event.id): \(escape(failure.domain))/\(escape(failure.code)): \(escape(failure.message))\n\n"
        for cause in failure.causes { output += "- Cause supplied by caller: \(escape(cause))\n" }
        output += "\nHypothesis: unavailable; no automated causal conclusion. Stack: unavailable.\n\n"
      } else { output += "\nIncident/error: absent from this caller-supplied event.\n\n" }
    }
    return output
  }
}
