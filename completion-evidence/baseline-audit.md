# Baseline Audit

## Repository State

- Repository: `https://github.com/flynn33/ASH-Pattern-System-Mac-iOS.git`
- Working branch: `release/aps-ios-1.0.0-completion-clean`
- Base commit: `cb71b06819fff9c32e3fa5ac971557d2a54055dc`
- Canonical baseline commit: `cc253f3d137a27f0eeb471bed62bbdb939e3b6d1`
- Package root: `MaciOS/Package.swift`

## Baseline Commands

| Command | Result |
|---|---|
| `git fetch --all --prune --tags` | PASS |
| `git pull --ff-only origin main` | PASS |
| `python3 .github/scripts/no_attribution_check.py` | PASS |
| `python3 .github/scripts/attribution_guard_check.py --mode ci` | PASS; no refs to evaluate |
| `python3 tools/verify_protected_surface.py --mode product --write-baseline` | PASS |
| `swift package --package-path MaciOS dump-package` | PASS |
| `swift package --package-path MaciOS clean` | PASS, run before each full build/test pass |
| `swift build --package-path MaciOS -c release` | PASS, 2 clean runs |
| `swift test --package-path MaciOS` | PASS, 42 tests, 2 clean runs |
| `xcodebuild -scheme ASHCore -destination 'generic/platform=iOS' -configuration Release build -quiet` | PASS |
| `xcodebuild -scheme ASHPatternSystem -destination 'generic/platform=iOS' -configuration Release build -quiet` | PASS |
| `python3 -m unittest discover -s tools/tests -v` | PASS, 2 tests |
| `gh repo view flynn33/ASH-Pattern-System-Mac-iOS --json defaultBranchRef,isPrivate,nameWithOwner` | PASS, default branch `main` |
| `gh api repos/flynn33/ASH-Pattern-System-Mac-iOS/rulesets --jq 'length'` | PASS, `0` active rulesets |
| `gh api repos/flynn33/ASH-Pattern-System-Mac-iOS/branches/main/protection` | FAIL, HTTP 404 branch not protected |

## Baseline Finding

The native Swift implementation compiled and tested locally, but default state semantics were behind the canonical baseline before remediation: only `.zero` was configured as a valid state, realm IDs used a non-canonical prefix, and transition coverage did not prove the 512 realm by 16 codeword matrix.

## Protected Surface Baseline

The repository-local protected-surface verifier writes `completion-evidence/protected-surface-baseline.json` and fails product verification when tracked or untracked protected-path changes are present.

## Hosted Protection Finding

Authenticated GitHub API reads completed, but the hosted repository is not protected for release: the rulesets endpoint returned zero active rulesets and the default branch protection endpoint returned HTTP 404.
