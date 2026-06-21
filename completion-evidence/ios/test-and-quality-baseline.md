# Test And Quality Baseline

## Local Verification

| Command | Result |
|---|---|
| `swift package --package-path MaciOS dump-package` | PASS |
| `swift package --package-path MaciOS clean` | PASS, run before each full build/test pass |
| `swift build --package-path MaciOS -c release` | PASS, 2 clean runs |
| `swift test --package-path MaciOS` | PASS, 42 tests, 2 clean runs |
| `xcodebuild -scheme ASHCore -destination 'generic/platform=iOS' -configuration Release build -quiet` | PASS |
| `xcodebuild -scheme ASHPatternSystem -destination 'generic/platform=iOS' -configuration Release build -quiet` | PASS |
| `python3 .github/scripts/no_attribution_check.py` | PASS |
| `python3 .github/scripts/attribution_guard_check.py --mode ci` | PASS; no refs to evaluate |
| `python3 tools/verify_protected_surface.py --mode product --write-baseline` | PASS |
| `python3 -m unittest discover -s tools/tests -v` | PASS, 2 tests |

## Added Coverage

- 512 well-formed realm states under default `ASHStateModel`
- 32 orbit representatives observed from canonical codeword partitioning
- 512 canonical realm identifiers from `ASHRealmEncoder`
- 8,192 state/codeword transformations from `ASHTransitionRegistry`
- Exact canonical codeword signatures, transition identifiers, orbit identifiers, and public-record JSON round trips
- Corpus-backed checks decode canonical codewords, realms, orbits, transitions, and transformations from SwiftPM test resources

## Not Run

- iOS simulator matrix
- iOS physical-device matrix
- Accessibility audits
- Performance budgets
- Clean install, upgrade, and removal validation
