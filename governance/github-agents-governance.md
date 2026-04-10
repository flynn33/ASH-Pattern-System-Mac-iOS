# GitHub Governance Agents

This document defines the GitHub-native sentinel agent layer that guards the canonical ASH Pattern System repository against drift. The agents are implemented as GitHub Actions workflows under `.github/workflows/` and small Python scripts under `.github/scripts/`.

## Role

The agents are **sentinels and gatekeepers**, not canonical authorities.

- Agents detect deviations from already-documented canonical state. They do not invent, redefine, or extend canonical math or semantics.
- Agents may block commits, pushes, and pull requests at the CI boundary and require human review.
- The canonical source of truth is the specification layer under `specs/` and the governance documents under `governance/`. The agents enforce that source of truth; they do not constitute it.
- If an agent's output conflicts with the canonical specification, the specification wins and the agent must be corrected.

## Canonical file-type policy

The canonical ASH Pattern System repository **may** contain:

- Markdown (`.md`)
- JSON (`.json`) for manifest or configuration purposes only
- Plain text (`.txt`)
- Pseudocode files (`.pseudo.md`)
- GitHub Actions workflow YAML under `.github/workflows/`
- Small governance and sentinel Python scripts under `.github/scripts/`

The canonical repository **may not** contain platform, product, build, or runtime implementation code anywhere outside `.github/scripts/`. This includes source files in any general-purpose programming language, build manifests, package manifests, lockfiles, platform source trees, and binary artifacts.

The Alignment Agent enforces this policy.

## Agents

Four agents are defined. Three guard the canonical repository; the fourth is a reusable workflow for downstream implementation repositories.

### 1. Alignment Agent

**Workflow:** `.github/workflows/alignment-agent.yml`
**Script:** `.github/scripts/alignment_check.py`
**Behavior:** blocking on hard boundary violations.
**Triggers:** every `push` and `pull_request` on any branch.

Checks:

- **(a) Implementation code anywhere in the repo.** Walks the entire repo and flags any file whose extension is in the implementation-code set unless its path is in the explicit allowlist. The allowlist is:
  - `.github/scripts/**` — the sentinel scripts themselves.
  - No other paths are allowlisted in the initial landing.
- **(b) Build / package / platform-tree files.** Flags `Cargo.toml`, `package.json`, `pom.xml`, `Makefile`, `CMakeLists.txt`, `pyproject.toml`, `go.mod`, `Gemfile`, `composer.json`, `Package.swift`, and similar, plus top-level platform directories like `src/`, `lib/`, `build/`, `dist/`, `target/`, `bin/`, `out/`, `node_modules/`, `vendor/`.
- **(c) Hierarchy-inversion language.** Scans `README.md`, `docs/**.md`, `governance/**.md`, and `handoff-templates/**.md` for any sentence containing both a downstream referent (`aeostara`, `downstream repo`, `implementation repo`, etc.) and a canonical-authority claim (`source of truth`, `authoritative`, `defines canonical semantics`, `overrides canonical`, `canonical authority`) within 200 characters. The check is direction-agnostic and does not fire on legitimate sentences that lack either half of the pair.

### 2. Canonical Semantic Integrity Agent

**Workflow:** `.github/workflows/canonical-semantic-integrity-agent.yml`
**Script:** `.github/scripts/semantic_integrity_check.py`
**Behavior:** blocking on (a) and (b); the status-contradiction check in (c) has an explicit warning vs blocking rule.
**Triggers:** every `push` and `pull_request` on any branch.

Checks:

- **(a) Superseded 8+1 canonical language reintroduction** in active canonical files. Scans `README.md`, `specs/**.md`, `docs/**.md`, `governance/**.md`, `handoff-templates/**.md`. The scan uses a prohibition-context skip rule: a match is not flagged if the 400-character window preceding it (with markdown emphasis stripped) contains a negation, prohibition, or superseded marker. This correctly allows sentences that explicitly rebut, prohibit, or historically discuss the 8+1 formalization.
- **(b) Handoff-template authority inversion.** Scans all Markdown files for phrases claiming that handoff templates are canonical authority, override canonical semantics, define canonical semantics, or own canonical semantics. Any match is a blocking violation.
- **(c) Status-language contradiction across three status files** (`README.md`, `docs/03-design-roadmap.md`, `governance/ai-coding-handoff.md`). Rule:
  - **Warning (never blocking, even outside report-only mode):** the broad completion phrase `All specification layers are complete` appears alone, with no Phase-4-active phrase in any of the three files.
  - **Blocking:** the broad completion phrase AND a Phase-4-active phrase (e.g. `Phase 4 ... active`, `Phase 4 ... in progress`, `Phase 4 ... current`) both appear across the three files. This is the concrete contradiction that has already had to be fixed twice in this repository; the rule exists to detect any re-emergence immediately.

### Narrow superseded-file exemption

Active canonical file scans exempt a file **only if** its first ten lines contain the literal token `SUPERSEDED`. This file-local exemption is narrow by design:

- It does not propagate. Every other file, including files that reference the exempted file, is still scanned.
- It does not permit reintroduction of 8+1 language into active canonical files. The `SUPERSEDED` banner marks a historical record; it does not authorize new canonical claims elsewhere.
- Currently exempted files: `specs/core/control-bit-derivation.pseudo.md`, `specs/core/core-admissibility.pseudo.md` (both explicitly carry the banner).

### 3. Math Integrity Agent

**Workflow:** `.github/workflows/math-integrity-agent.yml`
**Script:** `.github/scripts/math_integrity_check.py`
**Behavior:** blocking.
**Triggers:** every `push` and `pull_request` on any branch. Only activates when a math-critical path is in the changed set; otherwise exits 0 with no findings.

#### Protected math-critical paths

When any of the following files is in the changed set, the Math Integrity Agent enforces its full rule set:

- `specs/core/ash-state-space.pseudo.md`
- `specs/core/codeword-set.pseudo.md`
- `specs/core/realm-identity.pseudo.md`
- `specs/core/recoverability-semantics.pseudo.md`
- `specs/core/state-admissibility.pseudo.md`
- `specs/core/state-validity-diagnostics.pseudo.md`
- `specs/core/system-state-classification.pseudo.md`
- `specs/algorithms/averaging-operator-semantics.pseudo.md`
- `specs/algorithms/branching-semantics.pseudo.md`
- `specs/algorithms/codeword-transformation-semantics.pseudo.md`
- `specs/algorithms/containment-safe-failure-semantics.pseudo.md`
- `specs/algorithms/recovery-fallback-semantics.pseudo.md`
- `specs/algorithms/transition-system.pseudo.md`
- `specs/algorithms/topology-expansion.pseudo.md`
- `specs/algorithms/axiom-evaluation.pseudo.md`
- `specs/algorithms/generation-planning.pseudo.md`
- `specs/verification/invariant-spec.md`
- `specs/verification/conformance-categories.md`
- `specs/verification/implementation-acceptance.md`

The two superseded historical files (`specs/core/control-bit-derivation.pseudo.md`, `specs/core/core-admissibility.pseudo.md`) are deliberately **not** protected — they are historical and bear the `SUPERSEDED` banner.

#### Baseline-marker paths (narrow subset)

The following subset is checked additionally for continued presence of 9D baseline markers (`F2^9`, `F_2^9`, `9D`, `9-dimensional`, `full 9`) after any edit:

- `specs/core/ash-state-space.pseudo.md`
- `specs/core/codeword-set.pseudo.md`
- `specs/core/realm-identity.pseudo.md`
- `specs/algorithms/codeword-transformation-semantics.pseudo.md`
- `specs/algorithms/averaging-operator-semantics.pseudo.md`
- `specs/algorithms/branching-semantics.pseudo.md`

These are the files where the 9D baseline is directly restated algebraically. Verification documents, acceptance documents, and downstream-semantics files (recovery, containment, classification) are **not** in this set: a legitimate edit to a verification or acceptance doc may not restate baseline markers in-line, and requiring them there would cause false positives.

#### Why math changes require human review

The canonical ASH Pattern System math is a locked research baseline. The 9D state space, the specific codeword set `C ⊂ F2^9`, the averaging operator, and the branching topology all carry cascade effects across admissibility, recovery, classification, verification, and downstream conformance. An unreviewed algebraic change in any protected file can silently invalidate invariants, acceptance categories, and downstream conformance guarantees. For this reason, every edit to a math-critical path must be documented in a change note and, on pull requests, gated behind a human-review label.

#### Math-change note requirement

When any math-critical path is in the changed set, the Math Integrity Agent requires a math-change note in the same push or pull request:

- The note must live under `governance/math-change-notes/` and be a `.md` file other than `README.md`.
- The note must contain exactly these three headings: `## What changed`, `## Why`, `## Baseline preservation statement`.
- The note must be committed in the same push or pull request as the math-critical edit. No filename date or SHA convention is enforced; see `governance/math-change-notes/README.md` for the suggested convention.

#### PR human-review gating

When the triggering event is a pull request and the PR payload is available, at least one of the following labels must be present on the PR: `math-reviewed`, `human-reviewed`, `baseline-approved`. If none are present, the agent blocks with `Add a human-review label after review`.

### 4. Downstream Conformance Agent

**Workflow:** `.github/workflows/downstream-conformance-agent.yml`
**Script:** `.github/scripts/downstream_conformance_check.py`
**Behavior:** reusable workflow for downstream implementation repositories.
**Triggers:** `workflow_call` only. This workflow does **not** run on the canonical repository's own `push` or `pull_request` events.

The agent validates the six canonical downstream conformance artifacts defined in `handoff-templates/common-downstream-handoff-requirements.md`:

1. Module mapping
2. Verification plan/report
3. Diagnostics conformance
4. Materialization boundary
5. Deviation log
6. Acceptance judgment

All six artifact paths are configurable via workflow inputs, with documented defaults under `conformance/`. A `require-all` boolean input controls whether missing artifacts are blocking or warning-only.

#### Acceptance judgment language

The acceptance judgment artifact must contain exactly one of the three canonical judgment strings:

- `CONFORMANT`
- `CONFORMANT WITH CAVEATS`
- `NON-CONFORMANT`

These are defined in `specs/verification/implementation-acceptance.md` line 69 ("There is no 'partial conformance.' An implementation is CONFORMANT, CONFORMANT WITH CAVEATS, or NON-CONFORMANT."). The reusable workflow's accepted set is **intentionally aligned** with the canonical acceptance document — neither broader nor narrower. If the canonical document ever changes the acceptance tiers, the script must be updated to match, not the other way around.

#### Invocation from a downstream repository

```yaml
jobs:
  conformance:
    uses: flynn33/ASH-Pattern-System/.github/workflows/downstream-conformance-agent.yml@main
    with:
      conformance-root: conformance/
      # optional per-artifact overrides
      # module-mapping-path: custom/path/module-mapping.md
      # require-all: false
```

## Relationship to `no-ai-attribution.yml`

The existing `.github/workflows/no-ai-attribution.yml` workflow is a separate concern and is not modified by this agent layer. It continues to enforce its own rules on commit authors, committers, message bodies, and file contents.

## Rollout state

The agent layer lands in **report-only mode** on first commit. Each agent workflow declares `env: REPORT_ONLY: "1"`. The Python scripts honor this environment variable and always exit 0 when it is set, while still printing the full violation report and GitHub annotations so maintainers can see what would have been blocked.

Promotion from report-only to blocking is a separate follow-up commit that flips `REPORT_ONLY: "1"` to `REPORT_ONLY: "0"` in each of the four workflow files. Promotion may only happen after a clean run on `main` — that is, after report-only output on `main` shows zero unexpected findings. A first-pass regex or path rule that fires incorrectly must be tightened (in intermediate commits) before promotion.

### Known report-only findings at initial landing

On first report-only run the Canonical Semantic Integrity Agent flags three pre-existing occurrences of superseded 8+1 canonical language in `specs/registries/fallback-policy-registry.md` (references to the locked `[8,4,4]` normative codeword set and the locked parity formula as canonical eligibility rules). These findings are correct: the file was not rewritten during the R1/R2/R3 research-math realignment and still contains superseded-era canonical assertions. Remediation of that content is **out of scope** for the agent-layer package itself. Promotion of the semantic-integrity agent from report-only to blocking is gated on resolving those findings in a separate canonical-content pass.
