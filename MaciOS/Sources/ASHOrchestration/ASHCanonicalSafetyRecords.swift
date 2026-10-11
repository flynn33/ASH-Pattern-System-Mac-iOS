import Foundation
import ASHCore

struct ASHSafetyRecordPlacement: Sendable {
  let actionIndex: Int
  let trigger: String
  let timeUTC: String
  let awaitingResolution: Bool
  let resolution: String
}

enum ASHCanonicalSafetyRecords {
  static func record(chain:[ASHDiagnosticEnvelope], placement:ASHSafetyRecordPlacement, safeHalt:Bool) -> ASHDiagnosticValue? {
    guard !chain.isEmpty, chain.indices.contains(placement.actionIndex) else { return nil }
    let action = chain[placement.actionIndex]
    let prefix = Array(chain.prefix(placement.actionIndex + 1))
    var fields = [
      ASHDiagnosticField(key:"trigger",value:.string(placement.trigger)),
      ASHDiagnosticField(key:"original_diagnostic",value:.object(chain[0].canonicalRecord)),
      ASHDiagnosticField(key:"diagnostic",value:.object(action.canonicalRecord)),
      ASHDiagnosticField(key:"system_state_class",value:.string(safeHalt ? "SAFE_HALT":"CONTAINED")),
      ASHDiagnosticField(key:"full_diagnostic_chain",value:.array(prefix.map { .object($0.canonicalRecord) }))
    ]
    if safeHalt {
      fields += [ASHDiagnosticField(key:"halt_time",value:.string(placement.timeUTC)),
        ASHDiagnosticField(key:"is_terminal",value:.bool(true)), ASHDiagnosticField(key:"frozen",value:.bool(true))]
    } else {
      fields += [ASHDiagnosticField(key:"containment_time",value:.string(placement.timeUTC)),
        ASHDiagnosticField(key:"restricted_operations",value:.array([.string("DIAGNOSTIC_READ"),.string("STATE_INSPECTION"),.string("EXTERNAL_RESOLUTION")])),
        ASHDiagnosticField(key:"awaiting_resolution",value:.bool(placement.awaitingResolution)),
        ASHDiagnosticField(key:"resolution",value:.string(placement.resolution))]
    }
    return .object(["schema_version":.string("1.0"), "product_version":.string(ASHSDKVersion.version),
      "id":.string(action.diagnosticReference), "data":.object(ASHDiagnosticObject(fields:fields))])
  }
  static func timestamp() -> String { ISO8601DateFormatter().string(from:Date()) }
}
