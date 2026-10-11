#!/usr/bin/env python3
"""Exercise rejection gates using mutated copies of actually built frameworks."""
import argparse
from pathlib import Path
import plistlib
import shutil

import sdk


def execute(frameworks, output):
    frameworks = Path(frameworks).resolve()
    output = sdk.fresh_directory(output)
    version = sdk.identities()
    sdk.write_json(output / 'baseline.json', sdk.inspect_frameworks(frameworks, *version))
    results = []

    def case(name, mutate, expected, allowlist=False):
        copied = output / name / 'Frameworks'
        copied.parent.mkdir()
        shutil.copytree(frameworks, copied, symlinks=True)
        mutate(copied)
        try:
            if allowlist:
                for p in copied.rglob('*.private.swiftinterface'):
                    p.unlink()
                sdk.framework_payload_allowlist(copied)
            else:
                sdk.inspect_frameworks(copied, *version)
        except ValueError as error:
            sdk.require(expected in str(error), f'{name}: wrong rejection: {error}')
            (copied.parent / 'rejection.txt').write_text(str(error) + '\n')
            results.append({'case': name, 'rejection': str(error)})
        else:
            raise ValueError(f'{name}: invalid framework was accepted')

    def core(root):
        return root / 'ASHCore.xcframework/macos-arm64_x86_64/ASHCore.framework'

    def outer_field(root, key, value):
        path = root / 'ASHCore.xcframework/Info.plist'
        fields = plistlib.loads(path.read_bytes())
        library = next(v for v in fields['AvailableLibraries'] if v['LibraryIdentifier'] == 'macos-arm64_x86_64')
        library[key] = value
        path.write_bytes(plistlib.dumps(fields))

    def stale_version(root):
        path = core(root) / 'Resources/Info.plist'
        fields = plistlib.loads(path.read_bytes()); fields['CFBundleVersion'] = '0'
        path.write_bytes(plistlib.dumps(fields))

    def public_interface(root):
        return core(root) / 'Modules/ASHCore.swiftmodule/arm64-apple-macos.swiftinterface'

    def corrupt_interface(root):
        path = public_interface(root)
        path.write_text(path.read_text() + '\npublic struct DeliberatelyMalformed {\n')

    def alter_macho(root, platform, minimum):
        binary = core(root) / 'ASHCore'
        actual = binary.resolve(); temporary = actual.with_name('mutated-binary')
        sdk.run(['xcrun', 'vtool', '-arch', 'arm64', '-set-build-version', platform, minimum, '27.0', '-replace', '-output', temporary, actual])
        temporary.replace(actual)

    def remove_dependency(root):
        binary = root / 'ASHPatternSystem.xcframework/macos-arm64_x86_64/ASHPatternSystem.framework/ASHPatternSystem'
        sdk.run(['xcrun', 'install_name_tool', '-change', '@rpath/ASHCore.framework/Versions/A/ASHCore', '@rpath/MissingCore.framework/Versions/A/MissingCore', binary.resolve()])

    case('incorrect-architectures', lambda r: outer_field(r, 'SupportedArchitectures', ['arm64']), 'architectures mismatch')
    case('incorrect-platform-metadata', lambda r: outer_field(r, 'SupportedPlatform', 'tvos'), 'platform variant mismatch')
    case('incorrect-macho-platform', lambda r: alter_macho(r, 'ios', '16.0'), 'actual Mach-O platform mismatch')
    case('incorrect-macho-minimum', lambda r: alter_macho(r, 'macos', '13.0'), 'actual minimum OS mismatch')
    case('stale-bundle-version', stale_version, 'stale bundle identity')
    case('missing-public-interface', lambda r: public_interface(r).unlink(), 'missing/duplicate public arm64 interface')
    case('damaged-public-interface', corrupt_interface, 'Command failed')
    case('missing-privacy-manifest', lambda r: (core(r) / 'Resources/PrivacyInfo.xcprivacy').unlink(), 'privacy manifest missing')
    case('missing-core-dependency', remove_dependency, 'orchestration omitted dynamic core dependency')
    case('unexpected-runtime-resource', lambda r: (core(r) / 'Resources/secret.txt').write_text('unapproved'), 'Unexpected framework resource/file', True)
    sdk.write_json(output / 'results.json', results)
    print(f'{len(results)} actual framework mutation cases rejected')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--frameworks', required=True)
    parser.add_argument('--output', required=True)
    arguments = parser.parse_args()
    execute(arguments.frameworks, arguments.output)
