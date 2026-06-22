# Apple Platform Implementation Reference Templates

## Purpose

This directory is retained as APS implementation reference material for the Mac/iOS edition.

The active targets for this repository are macOS and iOS. The common, desktop, and mobile files describe the deliverables this repository uses for module mapping, verification, diagnostics, materialization, packaging, release evidence, and acceptance status.

The service file is retained only to make target-class boundaries explicit. It is not an active release target for this repository.

## Apple Platform Boundary

The Mac/iOS edition must satisfy the APS semantic contract files under `specs/`, the module contracts under `specs/interfaces/`, and the verification requirements under `specs/verification/`.

These reference files describe how the Apple-platform repository organizes proof of implementation. They do not change APS behavior.

## Contents

| File | Mac/iOS edition role |
|---|---|
| `common-platform-handoff-requirements.md` | Shared Apple-platform implementation deliverable checklist |
| `desktop-implementation-handoff-template.md` | Active macOS target checklist |
| `mobile-implementation-handoff-template.md` | Active iOS target checklist |
| `service-implementation-handoff-template.md` | Not applicable to this repository |

## Usage

For Mac/iOS work:

1. Read the APS semantic contract files in `specs/`.
2. Use `common-platform-handoff-requirements.md` for the required Apple-platform evidence set.
3. Use `desktop-implementation-handoff-template.md` for macOS-specific release gates.
4. Use `mobile-implementation-handoff-template.md` for iOS-specific release gates.
5. Treat service files as out-of-scope markers for this repository.
