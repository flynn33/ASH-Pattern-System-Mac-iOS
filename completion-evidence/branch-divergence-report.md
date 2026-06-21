# Branch Divergence Report

## Resolved Branch

- Selected platform base: `origin/main` at `cb71b06819fff9c32e3fa5ac971557d2a54055dc`
- Completion branch: `release/aps-macos-1.0.0-completion-clean`
- Canonical baseline: `upstream/main` at `cc253f3d137a27f0eeb471bed62bbdb939e3b6d1`
- Merge base: `6c84ac0ddde8b22c502276b471906aaf0c8d4f71`

## Divergence Summary

The platform branch and canonical baseline intentionally diverge after `6c84ac0`.
The platform branch contains `MaciOS/Package.swift`, native source modules, native tests, and the local attribution guard.
The canonical baseline contains specification, conformance corpus, release evidence, and product manifest artifacts that are not platform implementation source.

`git diff --name-status origin/main..upstream/main` shows that blindly using `upstream/main` as the product branch would delete the `MaciOS/` implementation tree and replace it with canonical specification/release artifacts. That is not a valid preservation path for the Mac/iOS platform branch.

## Reconciliation Decision

The implementation work remains on the platform branch. Canonical `upstream/main` is used as the semantic baseline for conformance. Product source changes must reconcile platform behavior to canonical semantics without merging sibling platform implementation code or replacing the platform branch with canonical-only artifacts.

## Open Divergence Items

- Canonical release tag is not visible in the fetched local tag set.
- The split platform repository does not currently contain the package-named `tools/verify_protected_surface.py` verifier.
- Product branch work has not produced signed macOS or iOS distribution artifacts.
- Server-side ruleset state was not independently re-queried during this local implementation pass.
