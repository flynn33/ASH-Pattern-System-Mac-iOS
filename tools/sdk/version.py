#!/usr/bin/env python3
"""Check or regenerate SDK identity from the two version authorities."""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]

def identities(root=ROOT):
    version = (root / 'VERSION').read_text().strip()
    build = (root / 'BUILD_NUMBER').read_text().strip()
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:-rc\.\d+)?', version):
        raise ValueError('VERSION must be a semantic version or numeric RC')
    if not re.fullmatch(r'[1-9]\d*', build):
        raise ValueError('BUILD_NUMBER must be a positive decimal integer')
    return version, version.split('-')[0], build

def generated(root=ROOT):
    version, marketing, build = identities(root)
    return {
        'Config/SDKVersion.xcconfig': f'// Derived from VERSION and BUILD_NUMBER by tools/sdk/version.py.\nASH_SDK_VERSION = {version}\nMARKETING_VERSION = {marketing}\nCURRENT_PROJECT_VERSION = {build}\n',
        'MaciOS/Sources/ASHCore/ASHSDKVersion.swift': f'/// Public SDK identity. Generated from the repository version authorities.\npublic enum ASHSDKVersion {{\n  public static let version = "{version}"\n  public static let marketingVersion = "{marketing}"\n  public static let buildNumber = "{build}"\n}}\n'
    }

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--write', action='store_true')
    args = p.parse_args()
    for name, text in generated().items():
        path = ROOT / name
        if args.write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        elif not path.is_file() or path.read_text() != text:
            raise SystemExit(f'Stale generated SDK identity: {name}')
    print('SDK version identities agree')

if __name__ == '__main__':
    main()
