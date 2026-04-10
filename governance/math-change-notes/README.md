# Math Change Notes

This directory holds the change notes that the Math Integrity Agent requires when any math-critical file in the canonical ASH Pattern System repository is edited.

See `governance/github-agents-governance.md` for the agent's full policy and for the current list of math-critical paths.

## When a note is required

A math-change note must be committed **in the same push or pull request** as any edit to a file in the protected math-critical set. Editing a math-critical file without a corresponding note will block CI once the Math Integrity Agent is promoted from report-only to blocking mode.

The two historical `SUPERSEDED` files (`specs/core/control-bit-derivation.pseudo.md`, `specs/core/core-admissibility.pseudo.md`) are **not** math-critical and do not require a note.

## Required note structure

Every note in this directory (other than this README) must contain all three of the following headings, in any order:

```
## What changed
## Why
## Baseline preservation statement
```

The Math Integrity Agent's check is literal: each heading string must appear verbatim.

### What each section is for

- **## What changed** — a concrete description of the math-critical edit. Name the files touched, the algebraic structures or invariants affected, and the specific lines or sections that moved.
- **## Why** — the motivation for the change. This is where the research grounding, incident response, or spec-clarification rationale lives. A note without a *why* is not reviewable.
- **## Baseline preservation statement** — an explicit statement about whether the edit preserves the full 9D research baseline (`F2^9`, XOR-by-codeword transformations, `T² = T` averaging operator, first-class branching). If the edit does not preserve the baseline, the statement must say so plainly and the PR must carry a human-review label before it can merge.

## Suggested filename convention

Filenames are not enforced by the agent, but the recommended convention is:

```
YYYY-MM-DD-short-slug.md
```

For example:

```
2026-05-12-normalize-codeword-index-ordering.md
```

This keeps the directory chronologically ordered without requiring any tooling beyond `ls`.

## Human review on pull requests

When a math-critical edit is proposed via a pull request (as opposed to a direct push), the Math Integrity Agent additionally requires one of the following labels on the PR before it will pass:

- `math-reviewed`
- `human-reviewed`
- `baseline-approved`

The label must be added by a reviewer, not by the author of the PR.

## Scope boundary

A math-change note exists only to document what changed in the locked research baseline and to record human sign-off. It is **not** a design document, a roadmap entry, or a specification. It does not override the specifications themselves. If the change requires a spec rewrite, the rewrite goes into the appropriate file under `specs/` and the note simply records that fact.
