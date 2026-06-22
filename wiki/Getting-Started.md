# Getting Started

Use this sequence to understand the Mac/iOS repository from package shape to release status.

## Recommended Reading Order

1. [Home](Home)
2. [Architecture](Architecture)
3. [Build and Test](Build-and-Test)
4. [Conformance and Release Status](Conformance-and-Release-Status)
5. [Specification Layers](Specification-Layers)
6. [Recovery and Safety Semantics](Recovery-and-Safety-Semantics)
7. [Contracts and Verification](Contracts-and-Verification)
8. [Platform Implementation Guide](Platform-Implementation-Guide)

## Fast Orientation

| Question | Mac/iOS answer |
|---|---|
| What is this repository? | An Apple-platform Swift package implementation of APS semantics. |
| What products does it build? | `ASHCore` and `ASHPatternSystem`. |
| Which platforms are declared? | iOS 16+ and macOS 14+. |
| Does it include app targets? | No. App targets and distribution workflows remain release blockers. |
| What state model is implemented? | Full `F2^9`, 512-state space. |
| What transformation is implemented? | XOR-by-codeword with `C subset F2^9`. |
| What proves conformance? | Invariants, category coverage, contract satisfaction, diagnostic completeness, and platform evidence. |

## What To Read In The Repository

- Platform package:
  - `README.md`
  - `MaciOS/README.md`
  - `MaciOS/Package.swift`
- Repository docs:
  - `docs/00-repository-purpose.md`
  - `docs/01-design-philosophy.md`
  - `docs/02-target-repository-shape.md`
  - `docs/03-design-roadmap.md`
- Semantic contract material:
  - `specs/core/*.md`
  - `specs/algorithms/*.md`
  - `specs/interfaces/*.md`
  - `specs/verification/*.md`
- Platform evidence:
  - `completion-evidence/*.md`
  - `completion-evidence/ios/*.md`

## Contributor Rule

If a platform decision conflicts with APS semantics, record the blocker and resolve the semantic issue before claiming release readiness.
