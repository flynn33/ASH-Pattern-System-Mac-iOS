# Governance and Repository Checks

This page summarizes the repository checks and protected boundaries that apply to the Mac/iOS edition.

## Governance Scope

Primary governance documents:

- `governance/repository-governance.md`
- protected workflow and ruleset governance documents
- local completion-package protected-boundary documents

## Protected Surfaces

Product documentation work must not modify:

- inherited workflow files;
- inherited governance scripts;
- `.github/CODEOWNERS`;
- protected governance documents;
- branch-protection or ruleset definitions.

## Required Checks

The current package evidence records:

- SwiftPM package dump, release build, and tests;
- Xcode package-scheme builds for generic macOS and iOS;
- repository-local protected-surface verification;
- attribution-marker checks;
- Python unit tests for protected-surface tooling.

## Handling Check Failures

A failed repository check is evidence. Do not weaken the check, bypass it, or edit protected control files inside product documentation work. Record the failure, fix the product surface when appropriate, or route governance changes through an owner-reviewed governance-only path.
