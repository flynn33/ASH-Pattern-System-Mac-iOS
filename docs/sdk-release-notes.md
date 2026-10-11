# Release notes — 1.0.0

First Apple SDK release. Apple marketing version 1.0.0, build 2. Canonical semantics are independently pinned to ASH-Pattern-System 1.0.0-rc.3 at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8.

The public products are ASHCore and ASHPatternSystem, available from the root Git Swift package and a curated binary package containing two Release dynamic XCFrameworks with public interfaces, privacy manifests and matching dSYMs. Assets include the aggregate SDK ZIP, individual framework ZIPs, release manifest and SHA256SUMS. Frameworks are unsigned.

State decoding now rejects values outside 0...511 at the owning boundary, including nested records. Structural normalization preserves all 512 states. Operational assessment uses a validated explicit context, seven classes and declared target/fallback policy. Duplicate registries and invalid topology shapes return meaningful failures. Missing axiom evidence is INDETERMINATE. Plans and emitters validate complete abstract contracts and unknown registry references.

Canonical diagnostics preserve the complete fifteen-field wire record, nine-field semantic identity, strict scalar-preserving JSON, ordered chains and terminal finality. The operational session owns mutable state and produces canonical containment/safe-halt records and a frozen terminal snapshot. Caller-owned bounded support collection exports one immutable JSON/Markdown pair with redaction, transactional publication and observable failures. Release selects the minimal collector at compilation.

These are deliberate source, wire and behavioral changes from the earlier unpublished implementation. Read Migration before adapting existing local code. The acquired test corpus contains 10,340 pinned raw vectors with explicit adapters and case ledgers; native tests and public consumer checks exercise the actual implementation rather than deriving expectations from it.

Qualification is scoped to the recorded arm64 macOS host and available iPhone/iPad simulators, plus architecture/interface/device-SDK cross-build checks. Physical-device runtime, oldest supported OS versions, older compilers and translated Intel execution remain unverified. This release does not include a signed product application, notarization or App Store/TestFlight publication. Detailed final identities and downloaded-byte verification belong to the published release record and asset manifests.
