# Wiki Maintenance Playbook

This playbook defines how wiki content is maintained for the Mac/iOS edition.

## Tracked Wiki Content

The `wiki/` directory in this repository is the source-controlled wiki mirror. The live GitHub Wiki is a separate repository and must be checked separately before publication.

## Required Wiki Pages

- `Home.md`
- `_Sidebar.md`
- `Getting-Started.md`
- `Architecture.md`
- `Build-and-Test.md`
- `Conformance-and-Release-Status.md`
- `Specification-Layers.md`
- `Recovery-and-Safety-Semantics.md`
- `Contracts-and-Verification.md`
- `Governance-and-Repository-Checks.md`
- `Platform-Implementation-Guide.md`
- `Glossary.md`
- `Wiki-Maintenance-Playbook.md`

## Update Triggers

Update wiki pages when any of these change materially:

- `README.md`
- `docs/*.md`
- `MaciOS/README.md`
- `MaciOS/Package.swift`
- `specs/**/*.md`
- `completion-evidence/**/*.md`

## Maintenance Workflow

1. Update repository docs and package docs first.
2. Update affected pages in `wiki/`.
3. Update the separate live wiki checkout when publication is requested.
4. Verify internal wiki links resolve.
5. Ensure `Home.md` and `_Sidebar.md` include current pages.

## Guardrail

The tracked wiki and live wiki must describe the same platform state. If one surface is updated without the other, record the mismatch and finish the missing surface before claiming publication.
