#!/usr/bin/env python3
"""Refresh the framework project's explicit production source/resource membership."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / 'MaciOS/ASHSDK.xcodeproj/project.pbxproj'


def identifier(value):
    return hashlib.sha1(value.encode()).hexdigest()[:24].upper()


def synchronize():
    data = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(PROJECT)]))
    objects = data['objects']
    main = objects[objects[data['rootObject']]['mainGroup']]
    for module, folder in [('ASHCore', 'ASHCore'), ('ASHPatternSystem', 'ASHOrchestration')]:
        target = next(v for v in objects.values() if v['isa'] == 'PBXNativeTarget' and v['name'] == module)
        sources = next(objects[k] for k in target['buildPhases'] if objects[k]['isa'] == 'PBXSourcesBuildPhase')
        sources['files'] = []
        for path in sorted((ROOT / 'MaciOS/Sources' / folder).rglob('*.swift')):
            name = path.relative_to(ROOT / 'MaciOS').as_posix()
            reference, build = identifier('file:' + name), identifier('build:' + name)
            objects[reference] = {'isa': 'PBXFileReference', 'lastKnownFileType': 'sourcecode.swift', 'path': name, 'sourceTree': '<group>'}
            objects[build] = {'isa': 'PBXBuildFile', 'fileRef': reference}
            sources['files'].append(build)
            if reference not in main['children']:
                main['children'].append(reference)
        resources = next(objects[k] for k in target['buildPhases'] if objects[k]['isa'] == 'PBXResourcesBuildPhase')
        name = f'Sources/{folder}/Resources/PrivacyInfo.xcprivacy'
        reference, build = identifier('file:' + name), identifier('resource:' + name)
        objects[reference] = {'isa': 'PBXFileReference', 'lastKnownFileType': 'text.xml', 'path': name, 'sourceTree': '<group>'}
        objects[build] = {'isa': 'PBXBuildFile', 'fileRef': reference}
        resources['files'] = [build]
        if reference not in main['children']:
            main['children'].append(reference)

    def render(value, level=0):
        indent = '\t' * level
        if isinstance(value, dict):
            return '{\n' + ''.join(f'{indent}\t{json.dumps(k)} = {render(v, level + 1)};\n' for k, v in value.items()) + indent + '}'
        if isinstance(value, list):
            return '(\n' + ''.join(f'{indent}\t{render(v, level + 1)},\n' for v in value) + indent + ')'
        return str(value) if isinstance(value, int) else json.dumps(value)

    PROJECT.write_text('// !$*UTF8*$!\n' + render(data) + '\n')


if __name__ == '__main__':
    synchronize()
