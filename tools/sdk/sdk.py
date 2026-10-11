#!/usr/bin/env python3
"""Build, curate and inspect the two public dynamic Apple SDK products."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unicodedata
import zipfile
from urllib.parse import unquote, urlsplit, urlunsplit

from version import identities, generated

ROOT = Path(__file__).resolve().parents[2]
MODULES = ('ASHCore', 'ASHPatternSystem')
MATRIX = {
    'macos-arm64_x86_64': ('macos', '', ['arm64', 'x86_64'], 'MACOS', '14.0'),
    'ios-arm64': ('ios', '', ['arm64'], 'IOS', '16.0'),
    'ios-arm64_x86_64-simulator': ('ios', 'simulator', ['arm64', 'x86_64'], 'IOSSIMULATOR', '16.0'),
}
DOCUMENTS = {
    'sdk-integration.md': 'Getting-Started.md',
    'sdk-api-and-lifecycle.md': 'API-and-Lifecycle.md',
    'sdk-migration.md': 'Migration.md',
    'sdk-diagnostics.md': 'Diagnostics.md',
    'sdk-compatibility.md': 'Compatibility.md',
    'sdk-release-notes.md': 'Release-Notes.md',
}
BINARY_PACKAGE = '''// swift-tools-version: 5.10
import PackageDescription
let package = Package(
  name: "ASHAppleBinarySDK",
  platforms: [.macOS(.v14), .iOS(.v16)],
  products: [
    .library(name: "ASHCore", targets: ["ASHCore"]),
    .library(name: "ASHPatternSystem", targets: ["ASHPatternSystem", "ASHCore"])
  ],
  targets: [
    .binaryTarget(name: "ASHCore", path: "Frameworks/ASHCore.xcframework"),
    .binaryTarget(name: "ASHPatternSystem", path: "Frameworks/ASHPatternSystem.xcframework")
  ]
)
'''
REQUIRED_PROVENANCE = ('sourceCommit', 'canonicalCommit', 'canonicalVersion', 'canonicalSchemaVersion',
                       'canonicalCorpusVersion', 'methodCommit', 'canonicalProfileCommit',
                       'canonicalProfileSHA256', 'nativeProfileCommit', 'nativeProfileSHA256',
                       'contractSHA256', 'testedEnvironments', 'untestedEnvironments')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def run(command, log=None, cwd=ROOT):
    command = [str(x) for x in command]
    result = subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if log:
        Path(log).write_text(json.dumps(command) + '\n' + result.stdout + f'\nExit code: {result.returncode}\n')
    require(result.returncode == 0, f'Command failed ({result.returncode}): {command}\n{result.stdout[-6000:]}')
    return result.stdout


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, data):
    Path(path).write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')


def fresh_directory(path):
    path = Path(path).resolve()
    require(not path.exists() or not any(path.iterdir()), f'Refusing stale/nonempty output stage: {path}')
    path.mkdir(parents=True, exist_ok=True)
    return path


def checked_version():
    for name, text in generated().items():
        require((ROOT / name).is_file() and (ROOT / name).read_text() == text, f'Stale version identity: {name}')
    return identities()


def composition():
    root = json.loads(run(['swift', 'package', '--package-path', ROOT, 'dump-package']))
    nested = json.loads(run(['swift', 'package', '--package-path', ROOT / 'MaciOS', 'dump-package']))
    for key in ('products', 'platforms', 'toolsVersion', 'dependencies'):
        require(root[key] == nested[key], f'Root/nested package {key} differ')
    require(not root['dependencies'], 'Base SDK has external package dependencies')
    require(sorted(p['name'] for p in root['products']) == sorted(MODULES), 'Unexpected public products')
    require(all(p['targets'] == [p['name']] for p in root['products']), 'Source public product target graph drift')
    project = json.loads(run(['plutil', '-convert', 'json', '-o', '-', ROOT / 'MaciOS/ASHSDK.xcodeproj/project.pbxproj']))
    objects = project['objects']
    for module, folder in [('ASHCore', 'ASHCore'), ('ASHPatternSystem', 'ASHOrchestration')]:
        target = next(v for v in root['targets'] if v['name'] == module)
        nt = next(v for v in nested['targets'] if v['name'] == module)
        expected_dependencies = [] if module == 'ASHCore' else [{'byName': ['ASHCore', None]}]
        require(target['dependencies'] == nt['dependencies'] == expected_dependencies, 'Source runtime dependency graph drift')
        rp = (ROOT / target['path']).resolve()
        np = (ROOT / 'MaciOS' / nt.get('path', 'Sources/' + module)).resolve()
        require(rp == np and target['resources'] == nt['resources'], f'{module} source/resource membership differs')
        require(target['resources'] == [{'path': 'Resources/PrivacyInfo.xcprivacy', 'rule': {'copy': {}}}], 'Runtime resource allowlist drift')
        require((rp / 'Resources/PrivacyInfo.xcprivacy').is_file(), f'{module}: required privacy resource missing')
        native = next(v for v in objects.values() if v['isa'] == 'PBXNativeTarget' and v['name'] == module)
        resources = next(objects[k] for k in native['buildPhases'] if objects[k]['isa'] == 'PBXResourcesBuildPhase')
        resource_members = {objects[objects[k]['fileRef']]['path'] for k in resources['files']}
        require(resource_members == {f'Sources/{folder}/Resources/PrivacyInfo.xcprivacy'}, 'Xcode privacy resource membership drift')
        phase = next(objects[k] for k in native['buildPhases'] if objects[k]['isa'] == 'PBXSourcesBuildPhase')
        members = {objects[objects[k]['fileRef']]['path'] for k in phase['files']}
        expected = {str(p.relative_to(ROOT / 'MaciOS')) for p in rp.rglob('*.swift')}
        require(members == expected, f'{module} Xcode source membership drift: missing={expected-members}, extra={members-expected}')
        for config in objects[native['buildConfigurationList']]['buildConfigurations']:
            c = objects[config]
            conditions = c['buildSettings']['SWIFT_ACTIVE_COMPILATION_CONDITIONS']
            require(conditions == ('DEBUG' if c['name'] == 'Debug' else ''), 'Diagnostic build composition drift')
            excluded = c['buildSettings'].get('EXCLUDED_SOURCE_FILE_NAMES', '')
            require(excluded == ('ASHReleaseDiagnostics.swift' if c['name'] == 'Debug' else 'ASHDevelopmentDiagnostics.swift'), 'Diagnostic source exclusion drift')
    return {'products': list(MODULES), 'platforms': root['platforms'], 'sourceMembership': 'equal', 'diagnostics': 'Debug development / Release essential'}


def source_inputs():
    files = list((ROOT / 'MaciOS/Sources').rglob('*')) + list((ROOT / 'Config').rglob('*')) + list((ROOT / 'MaciOS/ASHSDK.xcodeproj').rglob('*'))
    files += [ROOT / n for n in ('VERSION', 'BUILD_NUMBER', 'Package.swift', 'MaciOS/Package.swift')]
    return {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(files) if p.is_file()}


def build(args):
    checked_version()
    starting_inputs = source_inputs()
    source_commit = run(['git', 'rev-parse', 'HEAD']).strip()
    source_status = run(['git', 'status', '--porcelain']).splitlines()
    comp = composition()
    output = fresh_directory(args.output)
    write_json(output / 'composition.json', comp)
    run(['xcodebuild', '-version'], output / 'toolchain.log')
    run(['xcodebuild', '-showsdks'], output / 'sdks.log')
    archive_info = {}
    executable = os.environ.get('ASH_XCODEBUILD', 'xcodebuild')
    for platform, destination in [('macos', 'generic/platform=macOS'), ('ios', 'generic/platform=iOS'), ('simulator', 'generic/platform=iOS Simulator')]:
        for module in MODULES:
            archive = output / 'archives' / f'{module}-{platform}.xcarchive'
            archive.parent.mkdir(exist_ok=True)
            command = [executable, 'archive', '-project', ROOT / 'MaciOS/ASHSDK.xcodeproj', '-scheme', module,
                       '-configuration', 'Release', '-destination', destination, '-archivePath', archive,
                       '-derivedDataPath', output / 'DerivedData' / f'{module}-{platform}',
                       'CODE_SIGNING_ALLOWED=NO', 'BUILD_LIBRARY_FOR_DISTRIBUTION=YES', 'SKIP_INSTALL=NO', 'ONLY_ACTIVE_ARCH=NO']
            run(command, output / f'{module}-{platform}-archive.log')
            framework = archive / 'Products/Library/Frameworks' / f'{module}.framework'
            require(framework.is_dir(), f'Archive omitted {module} framework')
            symbols = archive / 'dSYMs' / f'{module}.framework.dSYM'
            require(symbols.is_dir(), f'Archive omitted matching {module} dSYM')
            archive_info[(module, platform)] = (framework, symbols)
    frameworks = output / 'Frameworks'; frameworks.mkdir()
    for module in MODULES:
        command = [executable, '-create-xcframework']
        for platform in ('macos', 'ios', 'simulator'):
            framework, symbols = archive_info[module, platform]
            command += ['-framework', framework]
            if symbols.exists():
                command += ['-debug-symbols', symbols]
        command += ['-output', frameworks / f'{module}.xcframework']
        run(command, output / f'{module}-xcframework.log')
    inspection = inspect_frameworks(frameworks, *identities())
    write_json(output / 'framework-inspection.json', inspection)
    require(starting_inputs == source_inputs(), 'Production build inputs changed during archiving')
    write_json(output / 'BUILD-PROVENANCE.json', {'sourceCommit': source_commit, 'sourceStatus': source_status,
        'sourceInputsSHA256': starting_inputs, 'frameworkFilesSHA256': {p.relative_to(frameworks).as_posix(): sha(p) for p in payload_files(frameworks) if not p.is_symlink()},
        'frameworkSymlinks': {p.relative_to(frameworks).as_posix(): os.readlink(p) for p in payload_files(frameworks) if p.is_symlink()}})
    print(output)


def inspect_frameworks(frameworks, version, marketing, build):
    with tempfile.TemporaryDirectory(prefix='ASH interface cache ') as cache:
        return inspect_frameworks_with_cache(frameworks, version, marketing, build, cache)


def inspect_frameworks_with_cache(frameworks, version, marketing, build, cache):
    result = {}
    for module in MODULES:
        xc = Path(frameworks) / f'{module}.xcframework'
        require(xc.is_dir(), f'Missing framework: {module}')
        info = plistlib.loads((xc / 'Info.plist').read_bytes())
        libraries = info.get('AvailableLibraries', [])
        require(len(libraries) == 3, f'{module}: expected three distinct platform libraries')
        require({x['LibraryIdentifier'] for x in libraries} == set(MATRIX), f'{module}: incorrect architecture/platform matrix')
        libraries.sort(key=lambda item: list(MATRIX).index(item['LibraryIdentifier']))
        for lib in libraries:
            name = lib['LibraryIdentifier']
            platform, variant, arches, mach_platform, minimum = MATRIX[name]
            require(lib['SupportedPlatform'] == platform and lib.get('SupportedPlatformVariant', '') == variant,
                    f'{module}/{name}: platform variant mismatch')
            require(sorted(lib['SupportedArchitectures']) == arches, f'{module}/{name}: architectures mismatch')
            require(lib['LibraryPath'] == f'{module}.framework', f'{module}: unexpected module composition')
            require(lib.get('DebugSymbolsPath', 'dSYMs') == 'dSYMs', f'{module}: unexpected symbol path')
            framework = xc / name / lib['LibraryPath']
            binary = framework / module
            require(binary.is_file(), f'{module}/{name}: binary missing')
            actual_arches = sorted(run(['xcrun', 'lipo', '-archs', binary]).split())
            require(actual_arches == arches, f'{module}/{name}: actual architectures mismatch')
            load = run(['xcrun', 'vtool', '-show-build', binary])
            require(load.count('platform ' + mach_platform) == len(arches), f'{module}/{name}: actual Mach-O platform mismatch')
            require(load.count('minos ' + minimum) == len(arches), f'{module}/{name}: actual minimum OS mismatch')
            deps = run(['xcrun', 'otool', '-L', binary])
            require(f'@rpath/{module}.framework/' in deps, f'{module}/{name}: nonportable install name')
            if module == 'ASHPatternSystem':
                require('@rpath/ASHCore.framework/' in deps, f'{name}: orchestration omitted dynamic core dependency')
            require(not list(framework.rglob('*.framework')), 'Framework contains a duplicated embedded framework')
            plist = framework / 'Info.plist'
            if not plist.exists():
                plist = framework / 'Resources/Info.plist'
            privacy = framework / 'PrivacyInfo.xcprivacy'
            if not privacy.exists():
                privacy = framework / 'Resources/PrivacyInfo.xcprivacy'
            require(privacy.is_file(), f'{module}/{name}: privacy manifest missing')
            privacy_fields = plistlib.loads(privacy.read_bytes())
            require(privacy_fields.get('NSPrivacyTracking') is False, 'Unexpected SDK tracking declaration')
            fields = plistlib.loads(plist.read_bytes())
            require(fields.get('CFBundleShortVersionString') == marketing and fields.get('CFBundleVersion') == build,
                    f'{module}/{name}: stale bundle identity')
            require(fields.get('CFBundleExecutable') == module, 'Wrong executable/module name')
            interfaces = list((framework / 'Modules' / f'{module}.swiftmodule').glob('*.swiftinterface'))
            for arch in arches:
                public = [p for p in interfaces if p.name.startswith(arch + '-') and '.private.' not in p.name]
                require(len(public) == 1, f'{module}/{name}: missing/duplicate public {arch} interface')
                text = public[0].read_text()
                require(text.startswith('// swift-interface-format-version:') and '-enable-library-evolution' in text
                        and f'-module-name {module}' in text, 'Damaged public swiftinterface')
                require('ASHDevelopmentDiagnostics' not in text, 'Development diagnostic interface shipped')
                sdk_name = 'macosx' if platform == 'macos' else ('iphonesimulator' if variant else 'iphoneos')
                triple = f'{arch}-apple-macosx{minimum}' if platform == 'macos' else f'{arch}-apple-ios{minimum}' + ('-simulator' if variant else '')
                sdk_path = run(['xcrun', '--sdk', sdk_name, '--show-sdk-path']).strip()
                command = ['xcrun', 'swift-frontend', '-typecheck-module-from-interface', public[0], '-module-name', module, '-target', triple, '-sdk', sdk_path, '-module-cache-path', cache]
                for dependency in MODULES:
                    command += ['-F', Path(frameworks) / f'{dependency}.xcframework' / name]
                run(command)
            symbols = run(['xcrun', 'nm', binary])
            require('ASHDevelopmentDiagnostics' not in symbols, 'Development diagnostic symbols shipped')
            require('ASHReleaseDiagnostics' in symbols if module == 'ASHCore' else True,
                    'Release diagnostic implementation is absent')
            actual_uuid = run(['xcrun', 'dwarfdump', '--uuid', binary])
            dsym = xc / name / 'dSYMs' / f'{module}.framework.dSYM'
            if lib.get('DebugSymbolsPath'):
                dsym = xc / name / lib['DebugSymbolsPath'] / f'{module}.framework.dSYM'
            require(dsym.is_dir(), f'{module}/{name}: matching dSYM missing')
            if dsym.exists():
                dsym_uuid = run(['xcrun', 'dwarfdump', '--uuid', dsym])
                require(re.findall(r'UUID: ([A-F0-9-]+) \(([^)]+)\)', actual_uuid)
                        == re.findall(r'UUID: ([A-F0-9-]+) \(([^)]+)\)', dsym_uuid), 'dSYM UUID mismatch')
            signature = subprocess.run(['codesign', '-dv', str(binary)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            require((signature.returncode != 0 and 'code object is not signed at all' in signature.stdout) or
                    (signature.returncode == 0 and 'Signature=adhoc' in signature.stdout),
                    'Unexpected publisher signature requires explicit provenance')
            result[f'{module}/{name}'] = {'architectures': arches, 'platform': platform, 'variant': variant,
                                          'minimumOS': minimum, 'bundleVersion': marketing, 'buildNumber': build,
                                          'signature': 'ad-hoc linker' if 'Signature=adhoc' in signature.stdout else 'unsigned publisher',
                                          'dSYM': dsym.exists(), 'loadCommands': '\n'.join(line for line in load.splitlines() if '/' not in line), 'dependencies': '\n'.join(line.strip() for line in deps.splitlines() if line.startswith('\t'))}
    return result


def payload_files(root):
    root = Path(root)
    for p in sorted(root.rglob('*')):
        if p.is_symlink() or p.is_file():
            yield p


def markdown_destinations(text):
    expression = r'!?\[[^\]\n]*\]\(\s*(<[^>\n]+>|[^\s)]+)|(?m:^ {0,3}\[[^\]\n]+\]:\s*(<[^>\n]+>|[^\s]+))'
    return re.finditer(expression, text)


def rebase_document_links(text):
    replacements = []
    for match in markdown_destinations(text):
        group = 1 if match.group(1) is not None else 2
        raw = match.group(group)
        target = raw[1:-1] if raw.startswith('<') else raw
        url = urlsplit(target)
        if not url.scheme and not url.netloc and url.path.removeprefix('./') in DOCUMENTS:
            replacement = urlunsplit(('', '', DOCUMENTS[url.path.removeprefix('./')], url.query, url.fragment))
            replacements.append((match.start(group), match.end(group), '<' + replacement + '>' if raw.startswith('<') else replacement))
    for start, end, replacement in reversed(replacements):
        text = text[:start] + replacement + text[end:]
    return text


def verify_document_links(root):
    root = Path(root).resolve()
    for document in list((root / 'Documentation').rglob('*.md')) + list((root / 'Examples').rglob('*.md')):
        for match in markdown_destinations(document.read_text()):
            raw = match.group(1) if match.group(1) is not None else match.group(2)
            url = urlsplit(raw[1:-1] if raw.startswith('<') else raw)
            if url.scheme or url.netloc or not url.path:
                continue
            target = (document.parent / unquote(url.path)).resolve()
            require(target.is_relative_to(root) and target.exists(),
                    f'Unresolved shipped relative document link: {document.relative_to(root)} -> {raw}')


def framework_payload_allowlist(frameworks):
    for module in MODULES:
        xc = Path(frameworks) / f'{module}.xcframework'
        for p in payload_files(xc):
            rel = p.relative_to(xc).as_posix()
            if rel == 'Info.plist':
                continue
            pieces = rel.split('/', 1)
            require(len(pieces) == 2 and pieces[0] in MATRIX, f'Unexpected XCFramework path: {rel}')
            inner = pieces[1]
            if p.is_symlink():
                allowed_links = {f'{module}.framework/{x}': f'Versions/Current/{x}' for x in (module, 'Headers', 'Modules', 'Resources')}
                allowed_links[f'{module}.framework/Versions/Current'] = 'A'
                require(pieces[0].startswith('macos-') and inner in allowed_links and os.readlink(p) == allowed_links[inner], f'Unexpected framework symlink: {rel}')
                continue
            framework_prefix = f'{module}.framework/'
            if inner.startswith(framework_prefix):
                inner = inner[len(framework_prefix):]
                if pieces[0].startswith('macos-'):
                    require(inner.startswith('Versions/A/'), f'Unexpected macOS framework version path: {rel}')
                    inner = inner[len('Versions/A/'):]
                basic = {module, 'Info.plist', 'PrivacyInfo.xcprivacy', 'Resources/Info.plist', 'Resources/PrivacyInfo.xcprivacy',
                         f'Headers/{module}-Swift.h', 'Modules/module.modulemap'}
                if inner in basic:
                    continue
                expression = rf'Modules/{module}\.swiftmodule/(arm64|x86_64)-apple-(macos|ios|ios-simulator)\.(swiftinterface|swiftdoc|abi\.json)'
                require(re.fullmatch(expression, inner) is not None, f'Unexpected framework resource/file: {rel}')
            else:
                prefix = f'dSYMs/{module}.framework.dSYM/Contents/'
                require(inner.startswith(prefix), f'Unexpected XCFramework payload: {rel}')
                inner = inner[len(prefix):]
                require(inner in {'Info.plist', f'Resources/DWARF/{module}'} or re.fullmatch(rf'Resources/Relocations/(aarch64|arm64|x86_64)/{module}\.yml', inner), f'Unexpected symbol payload: {rel}')


def safe_payload(root):
    root = Path(root).resolve()
    allowed = {'Package.swift', 'Frameworks', 'Documentation', 'Examples', 'LICENSE', 'VERSION', 'SDK-MANIFEST.json', 'COMPONENTS.json', 'CONTENTS.sha256'}
    require({p.name for p in root.iterdir()} == allowed, 'SDK root allowlist mismatch')
    forbidden = {'.git', '.build', 'DerivedData', '__pycache__', 'CanonicalReference', 'Fixtures', 'Tests', 'completion-evidence', 'xcuserdata', 'conformance', 'execution'}
    for p in root.rglob('*'):
        rel = p.relative_to(root)
        require(not forbidden.intersection(rel.parts), f'Forbidden payload path: {rel}')
        require(p.name != '.DS_Store' and p.suffix not in {'.py', '.pyc'}, f'Forbidden payload file: {rel}')
        require(not (p.suffix == '.swift' and rel.parts[0] not in {'Examples', 'Package.swift'}), f'Producer source shipped: {rel}')
        if p.is_symlink():
            require(p.exists() and p.resolve().is_relative_to(root), f'Unsafe/dangling payload symlink: {rel}')
        elif p.is_file():
            require(not p.name.startswith('.'), f'Unexpected hidden payload: {rel}')
            if p.suffix in {'.swiftinterface', '.md', '.json', '.swift'}:
                require('ASHDevelopmentDiagnostics' not in p.read_text(errors='replace'), f'Development implementation shipped: {rel}')
    require((root / 'LICENSE').stat().st_size > 0, 'License missing/empty')
    require((root / 'Package.swift').read_text() == BINARY_PACKAGE, 'Binary public product graph drift')
    require({p.name for p in (root / 'Frameworks').iterdir()} == {m + '.xcframework' for m in MODULES}, 'Duplicate/missing binary module composition')
    framework_payload_allowlist(root / 'Frameworks')
    require({p.name for p in (root / 'Documentation').iterdir()} == set(DOCUMENTS.values()), 'Documentation payload allowlist mismatch')
    verify_document_links(root)
    require({p.name for p in (root / 'Examples').iterdir()} == {'SDKConsumer'}, 'Example root allowlist mismatch')
    example_files = {'app/Sources/ConsumerApp.swift', 'app/SDKConsumer.xcodeproj/project.pbxproj', 'app/SDKConsumer.xcodeproj/xcshareddata/xcschemes/SDKConsumer.xcscheme', 'Sources/ConsumerSmoke/ConsumerChecks.swift', 'Sources/ConsumerSmoke/ConsumerCLI.swift', 'verify/verify-consumer.sh', 'verify/verify-report.sh', 'verify/create-consumer-package.sh', 'docs/ConsumerAcceptance.md'}
    require({p.relative_to(root / 'Examples/SDKConsumer').as_posix() for p in payload_files(root / 'Examples/SDKConsumer')} == example_files, 'Example payload allowlist mismatch')
    example_directories = {str(parent) for file in example_files for parent in PurePosixPath(file).parents if str(parent) != '.'}
    require({p.relative_to(root / 'Examples/SDKConsumer').as_posix() for p in (root / 'Examples/SDKConsumer').rglob('*') if p.is_dir()} == example_directories, 'Example directory allowlist mismatch')


def digests(root):
    return {p.relative_to(root).as_posix(): sha(p) for p in payload_files(root) if p.name != 'CONTENTS.sha256' and not p.is_symlink()}


def verify_contents(root):
    recorded = {}
    for line in (root / 'CONTENTS.sha256').read_text().splitlines():
        digest, name = line.split('  ', 1)
        require(name not in recorded, 'Duplicate digest path')
        recorded[name] = digest
    require(recorded == digests(root), 'Internal checksum mismatch or final file added after checksums')


def make_zip(source, destination, epoch, include_root=True):
    source = Path(source)
    dt = datetime.fromtimestamp(max(epoch, 315532800), timezone.utc)
    date = (dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second)
    with zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for p in sorted(source.rglob('*')):
            rel = p.relative_to(source.parent if include_root else source).as_posix()
            entry = zipfile.ZipInfo(rel + ('/' if p.is_dir() and not p.is_symlink() else ''), date)
            entry.create_system = 3
            entry.external_attr = p.lstat().st_mode << 16
            if p.is_symlink():
                z.writestr(entry, os.readlink(p).encode())
            elif p.is_file():
                z.writestr(entry, p.read_bytes(), compress_type=zipfile.ZIP_DEFLATED)
            elif p.is_dir():
                z.writestr(entry, b'')


def safe_extract(archive, output):
    output = fresh_directory(output)
    with zipfile.ZipFile(archive) as z:
        require(z.testzip() is None, 'Corrupt ZIP')
        seen = set(); filesystem_names = {}; links = []
        for entry in z.infolist():
            raw = entry.filename
            path = PurePosixPath(raw)
            require(raw and not path.is_absolute() and '..' not in path.parts and '\\' not in raw and '\x00' not in raw,
                    f'Unsafe ZIP path: {raw}')
            require(raw == path.as_posix() + ('/' if entry.is_dir() else ''), f'Noncanonical ZIP path: {raw}')
            canonical = path.as_posix()
            require(canonical not in seen, f'Duplicate ZIP entry: {raw}'); seen.add(canonical)
            for count in range(1, len(path.parts) + 1):
                prefix = '/'.join(path.parts[:count])
                filesystem_name = unicodedata.normalize('NFD', prefix).casefold()
                require(filesystem_name not in filesystem_names or filesystem_names[filesystem_name] == prefix,
                        f'Aliased ZIP entry: {raw}')
                filesystem_names[filesystem_name] = prefix
            target = output.joinpath(*path.parts)
            require(target.resolve().is_relative_to(output), 'ZIP escaped output')
            mode = entry.external_attr >> 16
            if stat.S_ISLNK(mode):
                value = z.read(entry).decode()
                require(not Path(value).is_absolute() and (target.parent / value).resolve().is_relative_to(output), 'Unsafe ZIP symlink')
                links.append((target, value))
            elif entry.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                require(stat.S_ISREG(mode) or mode == 0, 'Unsupported ZIP entry type')
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(z.read(entry)); target.chmod(mode & 0o777 or 0o644)
        for target, value in links:
            target.parent.mkdir(parents=True, exist_ok=True); target.symlink_to(value)
        for target, _ in links:
            require(target.exists() and target.resolve().is_relative_to(output), 'Dangling/outside ZIP symlink')


def checked_provenance(path):
    data = json.loads(Path(path).read_text())
    require(all(key in data for key in REQUIRED_PROVENANCE), 'Partial provenance metadata')
    for key in ('sourceCommit', 'canonicalCommit', 'methodCommit', 'canonicalProfileCommit', 'nativeProfileCommit'):
        require(isinstance(data[key], str) and re.fullmatch('[0-9a-f]{40}', data[key]) is not None, f'Invalid immutable provenance: {key}')
    for key in ('canonicalProfileSHA256', 'nativeProfileSHA256', 'contractSHA256'):
        require(isinstance(data[key], str) and re.fullmatch('[0-9a-f]{64}', data[key]) is not None, f'Invalid profile hash: {key}')
    require(data['methodCommit'] == '8dd6e75a06336491b249fac3577db75458db8c13', 'Wrong adopted method')
    require(all(isinstance(data[k], str) and data[k].strip() for k in ('canonicalVersion', 'canonicalSchemaVersion', 'canonicalCorpusVersion')), 'Missing canonical version identity')
    require(isinstance(data['testedEnvironments'], list) and data['testedEnvironments'], 'Missing actual test environments')
    require(isinstance(data['untestedEnvironments'], list), 'Untested environments must be explicit')
    return data


def checked_build_record(directory, commit):
    directory = Path(directory)
    frameworks = directory / 'Frameworks'
    record = json.loads((directory / 'BUILD-PROVENANCE.json').read_text())
    require(record['sourceCommit'] == commit and not record['sourceStatus'] and record['sourceInputsSHA256'] == source_inputs(),
            'Stale or uncommitted build stage provenance')
    require(record['frameworkFilesSHA256'] == {p.relative_to(frameworks).as_posix(): sha(p) for p in payload_files(frameworks) if not p.is_symlink()},
            'Framework stage changed after verified build')
    require(record.get('frameworkSymlinks') == {p.relative_to(frameworks).as_posix(): os.readlink(p) for p in payload_files(frameworks) if p.is_symlink()},
            'Framework symlinks changed after verified build')
    return frameworks


def package(args):
    version, marketing, build = checked_version()
    provenance = checked_provenance(args.provenance)
    commit = run(['git', 'rev-parse', 'HEAD']).strip()
    require(provenance['sourceCommit'] == commit, 'Stale source provenance')
    require(not run(['git', 'status', '--porcelain']).strip(), 'Release packaging requires a clean integrated source checkout')
    output = fresh_directory(args.output)
    stage = output / f'ASH-Apple-SDK-{version}'; stage.mkdir()
    frameworks = checked_build_record(args.build, commit)
    inspection = inspect_frameworks(frameworks, version, marketing, build)
    shutil.copytree(frameworks, stage / 'Frameworks', symlinks=True)
    # Public interfaces are distributed; private compiler interfaces are not public SDK payload.
    for p in (stage / 'Frameworks').rglob('*.private.swiftinterface'):
        p.unlink()
    for name in ('LICENSE', 'VERSION'):
        shutil.copy2(ROOT / name, stage / name)
    (stage / 'Package.swift').write_text(BINARY_PACKAGE)
    (stage / 'Documentation').mkdir()
    for original, released in DOCUMENTS.items():
        source = ROOT / 'docs' / original
        require(source.is_file(), f'Missing integration document: {original}')
        (stage / 'Documentation' / released).write_text(rebase_document_links(source.read_text()))
    example = stage / 'Examples' / 'SDKConsumer'; example.mkdir(parents=True)
    for relative in ('app/Sources', 'app/SDKConsumer.xcodeproj', 'verify', 'docs', 'Sources'):
        source = ROOT / 'Examples/SDKConsumer' / relative
        require(source.exists(), f'Missing public example: {relative}')
        shutil.copytree(source, example / relative)
    metadata = dict(provenance, sdkVersion=version, marketingVersion=marketing, buildNumber=build,
                    diagnosticProfile='release-minimal', publisherSigning='unsigned', toolchain=run(['xcodebuild', '-version']).strip(),
                    minimumPlatforms={'macOS': '14.0', 'iOS': '16.0'}, architectureMatrix=inspection,
                    sourceEpoch=int(run(['git', 'show', '-s', '--format=%ct', 'HEAD']).strip()),
                    symbols='matching archive dSYMs are included in XCFramework platform entries')
    write_json(stage / 'SDK-MANIFEST.json', metadata)
    write_json(stage / 'COMPONENTS.json', {'format': 'ASH custom component inventory 1.0', 'components':
                                          [{'name': m, 'kind': 'dynamic-xcframework', 'version': version, 'license': 'repository LICENSE'} for m in MODULES],
                                          'runtimeDependencies': ['Apple supported frameworks', 'Swift runtime']})
    (stage / 'CONTENTS.sha256').write_text(''.join(f'{v}  {k}\n' for k, v in digests(stage).items()))
    safe_payload(stage); verify_contents(stage)
    epoch = metadata['sourceEpoch']
    aggregate = output / f'ASH-Apple-SDK-{version}.zip'; make_zip(stage, aggregate, epoch)
    assets = [aggregate]
    for module in MODULES:
        dest = output / f'{module}-{version}.xcframework.zip'
        make_zip(stage / 'Frameworks' / f'{module}.xcframework', dest, epoch); assets.append(dest)
    manifest = output / f'RELEASE-MANIFEST-{version}.json'
    write_json(manifest, {'schemaVersion': '1.0', 'sdkVersion': version, 'sourceCommit': commit,
                          'canonicalCommit': provenance['canonicalCommit'], 'publisherSigning': 'unsigned',
                          'assets': [{'name': p.name, 'size': p.stat().st_size, 'sha256': sha(p)} for p in assets],
                          'symbols': 'Included matching dSYMs; no separate symbols ZIP'})
    assets.append(manifest)
    (output / 'SHA256SUMS').write_text(''.join(f'{sha(p)}  {p.name}\n' for p in assets))
    verify_assets(output, provenance)
    print(output)


def verify_stage(root, provenance=None):
    root = Path(root)
    safe_payload(root); verify_contents(root)
    manifest = checked_provenance(root / 'SDK-MANIFEST.json')
    version = (root / 'VERSION').read_text().strip()
    require(manifest['sdkVersion'] == version, 'Stale SDK version metadata')
    require(root.name == f'ASH-Apple-SDK-{version}', 'Versioned stage name mismatch')
    require(manifest['diagnosticProfile'] == 'release-minimal' and manifest['publisherSigning'] == 'unsigned', 'Wrong diagnostic/signing profile')
    require(set(manifest['minimumPlatforms'].items()) == {('macOS', '14.0'), ('iOS', '16.0')}, 'Wrong platform minimum identity')
    if provenance:
        for key in REQUIRED_PROVENANCE:
            require(manifest[key] == provenance[key], f'Stale provenance: {key}')
    inspect_frameworks(root / 'Frameworks', version, manifest['marketingVersion'], manifest['buildNumber'])
    run(['swift', 'package', '--package-path', root, 'dump-package'])
    return manifest


def verify_assets(directory, provenance=None):
    directory = Path(directory)
    sums = directory / 'SHA256SUMS'
    require(sums.is_file(), 'Missing release checksums')
    entries = {}
    for line in sums.read_text().splitlines():
        digest, name = line.split('  ', 1)
        require(name not in entries and '/' not in name and '\\' not in name, 'Unsafe/duplicate asset checksum')
        require(re.fullmatch('[0-9a-f]{64}', digest) is not None, 'Invalid SHA256 checksum')
        entries[name] = digest
        require((directory / name).is_file() and sha(directory / name) == digest, f'Asset checksum mismatch: {name}')
    manifests = [p for p in entries if p.startswith('RELEASE-MANIFEST-') and p.endswith('.json')]
    require(len(manifests) == 1, 'Missing/duplicate release manifest')
    m = json.loads((directory / manifests[0]).read_text()); version = m['sdkVersion']
    require(manifests[0] == f'RELEASE-MANIFEST-{version}.json' and m['schemaVersion'] == '1.0'
            and m['publisherSigning'] == 'unsigned', 'External release manifest identity mismatch')
    expected = {f'ASH-Apple-SDK-{version}.zip', f'ASHCore-{version}.xcframework.zip', f'ASHPatternSystem-{version}.xcframework.zip', manifests[0]}
    require(set(entries) == expected, 'Curated release asset inventory mismatch')
    require({p.name for p in directory.iterdir() if p.is_file()} == expected | {'SHA256SUMS'}, 'Unexpected release asset')
    require(len(m['assets']) == 3 and {a['name'] for a in m['assets']} == expected - {manifests[0]}, 'Release manifest asset inventory mismatch')
    for asset in m['assets']:
        require(asset['sha256'] == entries[asset['name']] and asset['size'] == (directory / asset['name']).stat().st_size, 'External manifest digest/size mismatch')
    with tempfile.TemporaryDirectory(prefix='ASH isolated SDK extraction ') as tmp:
        safe_extract(directory / f'ASH-Apple-SDK-{version}.zip', tmp)
        stage = Path(tmp) / f'ASH-Apple-SDK-{version}'
        manifest = verify_stage(stage, provenance)
        require(m['sourceCommit'] == manifest['sourceCommit'] and m['canonicalCommit'] == manifest['canonicalCommit'], 'External/internal provenance differs')
        for module in MODULES:
            target = Path(tmp) / module; safe_extract(directory / f'{module}-{version}.xcframework.zip', target)
            require({p.name for p in target.iterdir()} == {module + '.xcframework'}, 'Individual framework ZIP root mismatch')
            original = stage / 'Frameworks' / f'{module}.xcframework'
            require({p.relative_to(original).as_posix(): sha(p) for p in payload_files(original) if not p.is_symlink()}
                    == {p.relative_to(target / f'{module}.xcframework').as_posix(): sha(p) for p in payload_files(target / f'{module}.xcframework') if not p.is_symlink()}, 'Individual/aggregate frameworks differ')
            require({p.relative_to(original).as_posix(): os.readlink(p) for p in payload_files(original) if p.is_symlink()}
                    == {p.relative_to(target / f'{module}.xcframework').as_posix(): os.readlink(p) for p in payload_files(target / f'{module}.xcframework') if p.is_symlink()}, 'Individual/aggregate framework symlinks differ')
    print('Curated SDK assets, archives, checksums and provenance verified')


def main():
    p = argparse.ArgumentParser(description=__doc__); sub = p.add_subparsers(dest='operation', required=True)
    b = sub.add_parser('build'); b.add_argument('--output', required=True); b.set_defaults(handler=build)
    c = sub.add_parser('package'); c.add_argument('--build', required=True); c.add_argument('--provenance', required=True); c.add_argument('--output', required=True); c.set_defaults(handler=package)
    v = sub.add_parser('verify'); v.add_argument('path'); v.add_argument('--provenance'); v.set_defaults(handler=lambda a: verify_assets(Path(a.path), checked_provenance(a.provenance) if a.provenance else None) if (Path(a.path) / 'SHA256SUMS').exists() else verify_stage(Path(a.path), checked_provenance(a.provenance) if a.provenance else None))
    s = sub.add_parser('composition'); s.set_defaults(handler=lambda _: print(json.dumps(composition(), indent=2)))
    args = p.parse_args()
    try:
        args.handler(args)
    except (ValueError, OSError, KeyError, zipfile.BadZipFile, json.JSONDecodeError) as error:
        print(f'SDK gate failed: {error}', file=sys.stderr); return 1
    return 0

if __name__ == '__main__':
    sys.exit(main())
