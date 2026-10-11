#!/bin/bash
set -euo pipefail
consumer_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -lt 4 || "$1" != --sdk || "$3" != --output ]]; then
  echo 'Usage: verify-consumer.sh --sdk /absolute/extracted/ASH-Apple-SDK-version --output /absolute/empty/evidence [--simulators]' >&2
  exit 2
fi
sdk_root="$2"; evidence="$4"
[[ "$sdk_root" == /* && -f "$sdk_root/Package.swift" && "$evidence" == /* ]] || exit 2
if [[ -d "$evidence" && -n "$(ls -A "$evidence")" ]]; then
  echo 'Refusing stale/nonempty consumer evidence' >&2; exit 1
fi
mkdir -p "$evidence"
if rg -n '@testable|MaciOS/Sources|ASHOrchestration/|tools/product|conformance/1.0' "$consumer_root/app/Sources" "$consumer_root/Sources"; then
  echo 'Consumer crossed the public SDK boundary' >&2; exit 1
fi
for mode in core composed dual; do
  isolated="$evidence/$mode"
  mkdir -p "$isolated/Sources"
  cp -R "$consumer_root/Sources/ConsumerSmoke" "$isolated/Sources/"
  mkdir -p "$isolated/verify"
  cp "$consumer_root/verify/create-consumer-package.sh" "$isolated/verify/"
  "$isolated/verify/create-consumer-package.sh" --sdk "$sdk_root" --products "$mode"
  mkdir "$isolated/Exports"
  profile='(version 1)(allow default)(deny network*)'
  if [[ -n "${ASH_PRODUCER_ROOT:-}" ]]; then
    [[ "$ASH_PRODUCER_ROOT" == /* && "$ASH_PRODUCER_ROOT" != *'"'* ]] || exit 2
    profile="$profile(deny file-read* (subpath \"$ASH_PRODUCER_ROOT\"))"
  fi
  (cd "$isolated"; /usr/bin/sandbox-exec -p "$profile" swift build --disable-sandbox --package-path "$isolated" -c release -Xlinker -rpath -Xlinker @executable_path) > "$isolated/build.log" 2>&1
  executable="$isolated/.build/release/ConsumerSmoke"
  [[ -x "$executable" ]] || { echo 'Consumer executable missing' >&2; exit 1; }
  xcrun otool -L "$executable" > "$isolated/linked-frameworks.log"
  [[ "$(rg -c '^\s+@rpath/ASHCore.framework/' "$isolated/linked-frameworks.log")" == 1 ]] || { echo 'Core linkage missing/duplicated' >&2; exit 1; }
  if [[ "$mode" != core ]]; then
    [[ "$(rg -c '^\s+@rpath/ASHPatternSystem.framework/' "$isolated/linked-frameworks.log")" == 1 ]] || { echo 'Orchestration linkage missing/duplicated' >&2; exit 1; }
  fi
  (cd "$isolated"; /usr/bin/sandbox-exec -p "$profile" "$executable" "$isolated/Exports" "$isolated/report.json"  ) > "$isolated/run.log" 2>&1
  "$consumer_root/verify/verify-report.sh" "$isolated/report.json" "$mode" "$(cat "$sdk_root/VERSION")"
  find "$isolated/.build" -name '*.swiftinterface' -print > "$isolated/interface-inputs.txt"
  if rg -n 'CompileSwift.*ASHCore|SwiftCompile.*ASHCore|MaciOS/Sources|ASH-Pattern-System/' "$isolated/build.log"; then
    echo 'Binary consumer rebuilt/acquired prohibited source' >&2; exit 1
  fi
done
if [[ "${5:-}" == --simulators ]]; then
  isolated="$evidence/application"
  mkdir -p "$isolated"
  cp -R "$consumer_root/app" "$consumer_root/Sources" "$consumer_root/verify" "$isolated/"
  ln -s "$sdk_root" "$isolated/SDK"
  xcodebuild build -project "$isolated/app/SDKConsumer.xcodeproj" -scheme SDKConsumer -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath "$isolated/DeviceDerivedData" CODE_SIGNING_ALLOWED=NO > "$isolated/device-build.log" 2>&1
  xcrun simctl list devices available -j > "$isolated/simulators.json"
  for family in iPhone iPad; do
    udid="$(swift -e 'import Foundation; let o = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [String:Any]; let devices = o["devices"] as! [String:[[String:Any]]]; let family = CommandLine.arguments[2]; let match = devices.keys.sorted().reversed().flatMap { devices[$0]! }.first { ($0["name"] as? String)?.hasPrefix(family) == true && ($0["isAvailable"] as? Bool) == true }; guard let id = match?["udid"] as? String else { exit(1) }; print(id)' "$isolated/simulators.json" "$family")"
    [[ -n "$udid" ]] || { echo "Required $family simulator unavailable" >&2; exit 1; }
    destination="$isolated/$family"
    mkdir -p "$destination"
    xcodebuild build -project "$isolated/app/SDKConsumer.xcodeproj" -scheme SDKConsumer -configuration Release \
      -destination "platform=iOS Simulator,id=$udid" -derivedDataPath "$destination/DerivedData" CODE_SIGN_IDENTITY=- > "$destination/build.log" 2>&1
    xcrun simctl boot "$udid" > "$destination/boot.log" 2>&1 || {
      xcrun simctl list devices | rg -F "$udid" | rg -q Booted || exit 1
    }
    xcrun simctl bootstatus "$udid" -b > "$destination/bootstatus.log" 2>&1
    app="$destination/DerivedData/Build/Products/Release-iphonesimulator/SDKConsumer.app"
    [[ -d "$app" ]] || exit 1
    # Clear only this disposable harness so a prior report cannot satisfy a new run.
    if xcrun simctl get_app_container "$udid" com.flynn33.ash.sdkconsumer data >/dev/null 2>&1; then
      xcrun simctl uninstall "$udid" com.flynn33.ash.sdkconsumer
    fi
    xcrun simctl install "$udid" "$app"
    xcrun simctl launch "$udid" com.flynn33.ash.sdkconsumer > "$destination/launch.log"
    container="$(xcrun simctl get_app_container "$udid" com.flynn33.ash.sdkconsumer data)"
    ready=0
    for attempt in {1..60}; do
      if [[ -f "$container/Documents/ConsumerReport.json" ]]; then ready=1; break; fi
      if [[ -f "$container/Documents/ConsumerFailure.txt" ]]; then cat "$container/Documents/ConsumerFailure.txt" >&2; exit 1; fi
      sleep 1
    done
    [[ "$ready" == 1 ]] || { echo 'Simulator consumer timed out' >&2; exit 1; }
    cp "$container/Documents/ConsumerReport.json" "$destination/report.json"
    cp -R "$container/Documents/SDKConsumerExports" "$destination/Exports"
    "$consumer_root/verify/verify-report.sh" "$destination/report.json" dual "$(cat "$sdk_root/VERSION")"
    xcrun simctl io "$udid" screenshot "$destination/screen.png" >/dev/null
    xcrun simctl terminate "$udid" com.flynn33.ash.sdkconsumer
    printf '%s\n' "$udid" > "$destination/destination-udid.txt"
  done
fi
printf '%s\n' 'Isolated release binary consumer cases passed for all selected destinations'
