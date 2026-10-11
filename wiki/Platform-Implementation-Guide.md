# Apple platform guide — 1.0.0

Native Swift source is shared by both manifests and explicit library-evolution framework targets. Runtime dependencies are Apple native modules; per-framework PrivacyInfo.xcprivacy resources cover reviewed SDK behavior. The caller owns context, product UI, signing, permissions, support destinations and any upload.

Archives include macOS arm64/x86_64, device arm64 and simulator arm64/x86_64. Actual native arm64 host/simulator execution is distinguished from cross-build/interface checks. Minimum deployment metadata does not prove oldest-system compatibility. Sample simulator ad-hoc signing is distinct from unsigned publisher frameworks and physical-device signing.

[Compatibility](https://github.com/flynn33/ASH-Pattern-System-Mac-iOS/blob/v1.0.0/docs/sdk-compatibility.md), [security/privacy](https://github.com/flynn33/ASH-Pattern-System-Mac-iOS/blob/v1.0.0/docs/sdk-security.md) and [owner validation](https://github.com/flynn33/ASH-Pattern-System-Mac-iOS/blob/v1.0.0/docs/sdk-owner-validation.md) identify actual toolchain, environment gaps and the hardware procedure.
