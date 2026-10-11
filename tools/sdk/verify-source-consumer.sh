#!/bin/bash
set -euo pipefail
sdk_source_root="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ $# -ne 4 || ("$1" != --revision && "$1" != --exact-version) || "$3" != --output ]]; then
  echo 'Usage: verify-source-consumer.sh --revision SHA|--exact-version VERSION --output /absolute/empty/evidence' >&2
  exit 2
fi
mode="$1"; identity="$2"; evidence="$4"
[[ "$evidence" == /* ]] || exit 2
[[ ! -d "$evidence" || -z "$(ls -A "$evidence")" ]] || { echo 'Refusing stale source-consumer stage' >&2; exit 1; }
mkdir -p "$evidence"
expected_commit="$identity"
if [[ "$mode" == --exact-version ]]; then
  [[ "$identity" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?$ ]] || exit 2
  expected_commit="$(git -C "$sdk_source_root" rev-parse "v$identity^{commit}")"
else
  [[ "$identity" =~ ^[0-9a-f]{40}$ ]] || exit 2
fi
for products in core composed dual; do
  isolated="$evidence/$products"
  mkdir -p "$isolated/Sources" "$isolated/verify" "$isolated/Exports"
  cp -R "$sdk_source_root/Examples/SDKConsumer/Sources/ConsumerSmoke" "$isolated/Sources/"
  cp "$sdk_source_root/Examples/SDKConsumer/verify/create-consumer-package.sh" "$isolated/verify/"
  "$isolated/verify/create-consumer-package.sh" "$mode" "$identity" --products "$products"
  (cd "$isolated"; swift package resolve) > "$isolated/resolve.log" 2>&1
  python3 - "$isolated/Package.resolved" "$expected_commit" <<'PY'
import json,sys
from pathlib import Path
p=json.loads(Path(sys.argv[1]).read_text())['pins']
assert len(p)==1, 'Unexpected dependency graph'
assert p[0]['identity']=='ash-pattern-system-mac-ios', 'Incorrect package identity'
assert p[0]['location']=='https://github.com/flynn33/ASH-Pattern-System-Mac-iOS', 'Unexpected acquisition'
assert p[0]['state']['revision']==sys.argv[2], 'Resolved source identity mismatch'
PY
  profile="(version 1)(allow default)(deny network*)(deny file-read* (subpath \"$sdk_source_root\"))"
  (cd "$isolated"; /usr/bin/sandbox-exec -p "$profile" swift build --disable-sandbox -c release -v) > "$isolated/build.log" 2>&1
  executable="$isolated/.build/release/ConsumerSmoke"
  [[ -x "$executable" ]] || exit 1
  (cd "$isolated"; /usr/bin/sandbox-exec -p "$profile" "$executable" "$isolated/Exports" "$isolated/report.json") > "$isolated/run.log" 2>&1
  "$sdk_source_root/Examples/SDKConsumer/verify/verify-report.sh" "$isolated/report.json" "$products" "$(cat "$sdk_source_root/VERSION")"
  if rg -n 'Forsetti|Aeostara|ASH-Pattern-System/|canonical-data' "$isolated/Package.swift"; then
    echo 'Source consumer crossed allowlisted product graph' >&2; exit 1
  fi
done
printf '%s\n' 'Exact Git source public consumers passed'
