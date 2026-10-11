# SDK diagnostics — 1.0.0-rc.1

## Two separate contracts

Canonical semantic diagnostics describe APS decisions. Use `ASHDiagnosticEnvelope.decodeCanonicalJSON` for untrusted canonical wire input and `canonicalJSONData` for lossless output. These APIs preserve Unicode scalar distinctions, reject floats and duplicate keys, and require exactly fifteen fields. Foundation Codable is a convenience for trusted ordinary values; its keyed containers can normalize distinct Unicode keys and its numeric decoding can accept floating syntax. Strict parsing defaults to 1 MiB and 64 container levels; callers may explicitly choose other positive bounds. `ASHDiagnosticEnvelope` uses the canonical fifteen-field JSON record; semantic identity excludes occurrence metadata and chain placement. A session owns its ordered causal chain. Terminal safe halt freezes that chain; independent diagnostic validation reports remain outside it.

Support diagnostics describe consumer-authorized execution observations. They have their own versioned JSON/Markdown schema, event IDs, UTC capture times, environment, coverage limits and export identity. They do not replace canonical records or alter classification, fallback, containment or halt decisions.

## Capture, export and cleanup

```swift
import Foundation
import ASHCore

let collector = try ASHSupportDiagnostics.makeCollector(
  identity: ASHSupportIdentity(
    version: ASHSDKVersion.version,
    build: ASHSDKVersion.buildNumber
  )
)
try await collector.capture(ASHSupportEventInput(
  operation: "decode-test-fixture",
  correlation: "consumer-attempt-1",
  expected: "A nine-bit state or a decoding error",
  actual: "Malformed input rejected",
  context: ["fixture": "synthetic-invalid-state"],
  failure: ASHSupportFailure(
    domain: "ConsumerFixture", code: "INVALID_STATE",
    message: "The deliberately invalid fixture was rejected"
  )
))
let permittedDirectory = URL(fileURLWithPath: "/absolute/existing/private/export-parent", isDirectory: true)
let exported = try await collector.export(to: permittedDirectory)
// exported.json, exported.markdown and exported.snapshot describe one capture.
await collector.shutdown()
await collector.purge()
```

The caller creates and authorizes `permittedDirectory`. Use a physical absolute directory, with no symbolic-link path components. On macOS, `/var` is a system symlink; use its physical `/private/var` destination when applicable. The collector never creates an arbitrary parent directory. A new `ASH-Support-<UUID>` directory contains `Diagnostics.json` and `Diagnostics.md`; publication of the pair is atomic within that parent. Existing exports are not overwritten. Export failure throws, retains captured events and records a collector failure for the next snapshot. Cancellation also throws. Inspect the thrown error; the absence of a published pair is a failed export.

Export is synchronous work isolated by the collector actor. Session mutation completes before awaiting optional support capture; support failure cannot rewrite an APS result. Independent collectors and sessions do not share storage. Concurrent capture/export yields a coherent snapshot, whose sequence IDs can be matched in both files. Consumers own any upload, retention or deletion after export.

## Startup failure retrieval

Construct the collector early with validated identity. If startup or bootstrap fails after construction, catch the actual error, submit only authorized error/context fields, retrieve `collector.snapshot()` and attempt a paired export to an existing permitted parent. Keep the thrown export error separately; a missing pair is not successful capture. If collector construction itself fails, use the caller's startup log or stderr because no SDK collector exists yet. Nothing depends on the normal UI completing.

The example CLI writes `Consumer failure:` to stderr and exits nonzero on a failed check or export. The native sample writes `Documents/ConsumerFailure.txt` and displays its failure; any completed pairs remain in `Documents/SDKConsumerExports`. The simulator harness checks that failure file while waiting and retains logs. An early failure may leave no pair, and the caller must preserve the failure evidence explicitly. Exported files remain caller-owned after shutdown or purge.

## Development and Release composition

Debug compiles the development collector and excludes the Release collector. Release compiles a separate minimal collector and excludes the development implementation. The factory exposes the same actor protocol. There is no runtime switch that loads the rich implementation into a Release SDK.

| Limit | Debug development | Release minimal |
|---|---:|---:|
| Retained events | 4,096 | 256 |
| Retained event bytes | 8 MiB | 1 MiB |
| Single incoming record | 16 KiB | 16 KiB |
| Context fields per event | 32 | 32 |
| Error causes per event | 16 | 16 |

Overflow discards oldest support events and increments `droppedEvents`. It never truncates the canonical causal chain. Oversized incoming records throw before retention. Release permits only the `state`, `fixture`, `classification`, `rule`, and `outcome` context keys; Debug additionally permits `registry`, `source`, `attempt`, and `reproduction`. Other context fields are excluded before retention. The snapshot records excluded fields, redactions, drops, retained bytes, shutdown state and coverage limitations. Each support event may contain `canonicalDiagnostics`, a complete validated fifteen-field canonical chain. Canonical evidence is limited to 64 records and the same 16 KiB event budget; larger evidence fails support capture explicitly. The session keeps its complete chain independently. Recognized secret syntax in canonical records fails capture rather than rewriting semantic IDs or persisting secrets. Callers can always retrieve the session snapshot; support omissions never claim that missing evidence was exported.

Essential Release exports retain incident operation, correlation, expected/actual outcome and explicitly supplied error/cause strings. Snapshots include SDK identity and operating-system/platform/architecture metadata. No ambient filesystem, keychain, network, process dump or application-data capture occurs. Stack traces, CPU/memory measurements and automated causal diagnosis are unavailable unless a future separately reviewed contract provides them; the current export says so.

## Privacy and interpretation

Known secret syntax and sensitive paths are redacted before retention and checked again before export. Context uses a strict allowlist. Do not submit credentials, private payloads, personal data or arbitrary production logs. Redaction cannot identify every unlabeled secret in free text. Use synthetic fixtures and explicitly permitted observations. Review the resulting pair before sharing it.

Markdown escapes untrusted content; observations are data, not instructions. A support record reports what a caller supplied. It is evidence of capture and export, not proof of the caller's causal explanation. A consumer's exported source commit is optional; absence is explicit and never replaced with an invented commit. The SDK release's own source identity is in `SDK-MANIFEST.json`.

See [security and privacy](https://github.com/flynn33/ASH-Pattern-System-Mac-iOS/blob/v1.0.0-rc.1/docs/sdk-security.md), [API and lifecycle](sdk-api-and-lifecycle.md), and [owner validation](https://github.com/flynn33/ASH-Pattern-System-Mac-iOS/blob/v1.0.0-rc.1/docs/sdk-owner-validation.md). Raw diagnostic captures are execution evidence outside the repository and are excluded from SDK assets.
