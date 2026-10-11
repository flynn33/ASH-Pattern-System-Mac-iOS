# Build and test — 1.0.0

```bash
swift test -c debug -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift test -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift test --package-path MaciOS -c debug -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift test --package-path MaciOS -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
python3 tools/sdk/sdk.py composition
python3 -m unittest discover -s tools/sdk -p 'test_*.py' -v
```

Both manifests have identical public products/minimums and no external packages. Xcode shared schemes ASHCore/ASHPatternSystem archive macOS, iOS device and simulator. Final tooling checks actual architectures, Mach-O platform/minimums, public interfaces, Core linkage, privacy resources, release collector symbols and dSYM UUIDs. Dirty/stale/source-changing stages cannot become release assets.

[Maintainer procedure](https://github.com/flynn33/ASH-Pattern-System-Mac-iOS/blob/v1.0.0/docs/sdk-maintainer-release.md) gives archive/package/provenance commands; [acceptance](https://github.com/flynn33/ASH-Pattern-System-Mac-iOS/blob/v1.0.0/docs/sdk-acceptance.md) separates current source tests from integrated artifacts and actual downloads.
