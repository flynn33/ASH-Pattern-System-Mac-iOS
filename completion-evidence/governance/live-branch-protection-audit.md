# Live Branch Protection Audit

## Scope

- Repository: `flynn33/ASH-Pattern-System-Mac-iOS`
- Default branch: `main`
- Default branch SHA at audit: `cb71b06819fff9c32e3fa5ac971557d2a54055dc`

## Authenticated API Results

| Command | Result |
|---|---|
| `gh repo view flynn33/ASH-Pattern-System-Mac-iOS --json defaultBranchRef,isPrivate,nameWithOwner` | PASS, default branch `main` |
| `gh api repos/flynn33/ASH-Pattern-System-Mac-iOS/rulesets --jq 'length'` | PASS, `0` active rulesets |
| `gh api repos/flynn33/ASH-Pattern-System-Mac-iOS/branches/main/protection` | FAIL, HTTP 404 branch not protected |
| `gh api repos/flynn33/ASH-Pattern-System-Mac-iOS/actions/workflows` | PASS, two active guard workflows reported |

## Finding

Hosted protection is not active. The repository has no active rulesets, and the default branch protection endpoint reports that `main` is not protected.

## Required Owner Action

- Restore or define the full required hosted check family for this repository.
- Configure GitHub rulesets or branch protection for `main` and active release branches.
- Require pull requests, owner review, CODEOWNER review for protected paths, resolved conversations, up-to-date required checks, force-push blocking, branch deletion blocking, and linear history unless a different merge policy is recorded.
- Do not configure bypass actors for normal operation.
- Re-run authenticated API evidence capture after protection is active.

## Acceptance Impact

Release acceptance is blocked until hosted branch protection is active and verified.
