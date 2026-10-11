#!/bin/bash
set -euo pipefail
consumer_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -ne 4 ]]; then
  echo 'Usage: create-consumer-package.sh --sdk PATH|--revision SHA|--exact-version VERSION --products core|composed|dual' >&2
  exit 2
fi
mode="$1"; identity="$2"
[[ "$3" == --products ]] || exit 2
products="$4"
case "$products" in
 core) dependencies='.product(name: "ASHCore", package: "SDK")'; conditions='' ;;
 composed) dependencies='.product(name: "ASHPatternSystem", package: "SDK")'; conditions=', swiftSettings: [.define("CONSUME_ORCHESTRATION")]' ;;
 dual) dependencies='.product(name: "ASHCore", package: "SDK"), .product(name: "ASHPatternSystem", package: "SDK")'; conditions=', swiftSettings: [.define("CONSUME_ORCHESTRATION")]' ;;
 *) exit 2 ;;
esac
case "$mode" in
 --sdk)
   [[ "$identity" == /* && -f "$identity/Package.swift" ]] || exit 2
   if [[ -e "$consumer_root/SDK" && ! -L "$consumer_root/SDK" ]]; then
     echo 'Refusing to replace consumer SDK directory' >&2; exit 1
   fi
   ln -sfn "$identity" "$consumer_root/SDK"
   declaration='.package(name: "SDK", path: "SDK")'
   ;;
 --revision)
   [[ "$identity" =~ ^[0-9a-f]{40}$ ]] || exit 2
   declaration=".package(url: \"https://github.com/flynn33/ASH-Pattern-System-Mac-iOS\", revision: \"$identity\")"
   dependencies="${dependencies//\"SDK\"/\"ash-pattern-system-mac-ios\"}"
   ;;
 --exact-version)
   [[ "$identity" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?$ ]] || exit 2
   declaration=".package(url: \"https://github.com/flynn33/ASH-Pattern-System-Mac-iOS\", exact: \"$identity\")"
   dependencies="${dependencies//\"SDK\"/\"ash-pattern-system-mac-ios\"}"
   ;;
 *) exit 2 ;;
esac
cat > "$consumer_root/Package.swift" <<SWIFT
// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "SDKConsumer", platforms: [.macOS(.v14), .iOS(.v16)],
  products: [.executable(name: "ConsumerSmoke", targets: ["ConsumerSmoke"])],
  dependencies: [$declaration],
  targets: [.executableTarget(name: "ConsumerSmoke", dependencies: [$dependencies]$conditions)])
SWIFT
