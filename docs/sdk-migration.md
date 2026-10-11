# Migration — 1.0.0

This is the first Apple SDK release. The earlier unversioned repository package is not a published compatible SDK baseline. Source, wire and behavior corrections are deliberate and require migration; they are not presented as a compatible patch.

| Earlier behavior | Current contract | Migration |
|---|---|---|
| Root Git URL lacked Package.swift | Root and nested manifests compile the same sources | Select only public products; use the repository root for Git dependencies. |
| Decoding bypassed nine-bit validation | Direct and nested decode reject invalid states | Handle decoding errors; do not retain invalid values. |
| Structural normalization selected orbit representatives | All 512 valid states retain identity | Use reachability helpers for orbit mathematics; explicit operational context for stability/correction. |
| Boolean system context/unchecked alternate codewords | Fixed model and validated operational context | Declare stable states, target preference, fallback candidates/evidence and supported registry versions. |
| Trusted pre-classified recovery parameters | Recovery assesses actual state/context itself | Use recover(state:context:runtime:). Preserve pre/post diagnostics and explicit replacement outcomes. |
| Diagnostic eleven-field camel-case envelope, PLANNING/META wire values | Complete canonical fifteen-field snake-case record, GENERATION_PLAN/SCHEMA_VALIDATION | Use canonical factory/lossless data APIs; transform old records explicitly rather than pretending their IDs remain canonical. Swift planning/meta aliases map to current kinds. |
| Unique-key duplicate crashes | Deterministic validation issues | Inspect validation results. Equal semantic IDs are valid at distinct ordered occurrences. |
| Implicit state-derived/leaf-only topology | Structural R+C/P/N all-node topology with bounds | Inspect nodes/leaves separately; depth two means thirteen nodes and nine leaves. |
| Missing axiom evidence appeared as Boolean success/failure | PASS/FAIL/INDETERMINATE | Supply real predicate measurements and preserve uncertainty. |
| Stateless bootstrap used as operational control | Structural engine plus session actor | Use ASHPatternSystemSession for mutation/containment/terminal ownership. |
| Support capture/export absent | Explicit actor and build-selected development/minimal profiles | Caller creates destinations, captures permitted evidence, exports pairs, then shuts down/purges. |

Internal orchestration files moved from Sources/ASHPatternSystem to Sources/ASHOrchestration to satisfy the canonical import guard. The public module/product remains ASHPatternSystem; consumers must not bind internal source paths.

Existing specification mirrors and completion receipts remain historical. Canonical rc.3 at `50d7e5ab88932a4a967ffc2c83bd18fae45b73c8` owns current reconciliation. Do not consume older contradictory prose as an exception to the updated runtime contract.

The minimum metadata is macOS14/iOS16. Release framework binaries were produced using Xcode27/Swift6.4 and library evolution. Older Swift compilers and oldest declared OS runtimes require separate verification; minimum deployment metadata is not proof they were executed. Publisher binaries are unsigned. See [compatibility](sdk-compatibility.md) and [owner validation](https://github.com/flynn33/ASH-Pattern-System-Mac-iOS/blob/v1.0.0/docs/sdk-owner-validation.md).
