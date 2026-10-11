#!/bin/bash
set -euo pipefail
[[ $# -eq 3 ]] || { echo "Usage: verify-report.sh REPORT core|composed|dual SDK_VERSION" >&2; exit 2; }
verify_report() {
  local report="$1" mode="$2" sdk_version="$3"
  [[ -s "$report" ]] || { echo 'Missing consumer report' >&2; return 1; }
  python3 - "$report" "$mode" "$sdk_version" <<'PY'
import json,sys
from pathlib import Path
report=json.loads(Path(sys.argv[1]).read_text()); checks=report['checks']
assert isinstance(checks,list) and checks, 'Zero-case consumer runner'
assert all(isinstance(c,str) for c in checks) and len(checks)==len(set(checks)), 'Duplicate/invalid consumer case'
assert report['diagnosticProfile']=='release-minimal' and report['sdkVersion']==sys.argv[3], 'Incorrect SDK/profile'
required={f'state-roundtrip-{n}' for n in range(512)} | {f'invalid-state-{n}' for n in range(512,520)}
required |= {'release-diagnostic-profile','paired-json-snapshot','paired-markdown-identity','controlled-failure-export',
             'collector-shutdown','collector-purge','planner-emitter','emission-determinism','emission-incomplete-plan-rejected',
             'assessment-context-required','assessment-malformed','canonical-reachability','canonical-averaging','averaging-incomplete-rejected',
             'reachable-recovery','fallback-FALLBACK-STATE-001','fallback-FALLBACK-STATE-002',
             'classification-stable','classification-correctable','classification-unstable','classification-degraded',
             'classification-CONTAINED','classification-FAILED','classification-SAFE_HALT','planning-unknown-registry-rejected'}
if sys.argv[2]!='core':
    required |= {'session-safe-halt','session-terminal-all-entry-points','session-terminal-plan-emission','session-isolation',
                 'session-malformed-input','session-fallback-exhaustion','session-fallback-replacement',
                 'session-target-resolution-blocked','session-frozen-chain-export','session-support-collector',
                 'session-prevented-attempt','session-contained-transition','session-containment-resolution','session-failed-mode',
                 'paired-canonical-frozen-chain','paired-canonical-schema-fields','session-prebootstrap-denial','session-canonical-safety-records'}
assert required<=set(checks), 'Missing required public consumer cases: '+str(sorted(required-set(checks)))
assert report['publicOutcomes']['planIdentity'].startswith('APS-PLAN-') and report['publicOutcomes']['artifactContent'], 'Missing deterministic public outputs'
PY
}
verify_report "$1" "$2" "$3"
