#!/usr/bin/env python3
"""Compare observed public results from source and binary consumer acquisitions."""
import argparse
import json
from pathlib import Path


def compare(source, binary):
    results = {}
    for mode in ('core', 'composed', 'dual'):
        a = json.loads((Path(source) / mode / 'report.json').read_text())
        b = json.loads((Path(binary) / mode / 'report.json').read_text())
        for key in ('sdkVersion', 'diagnosticProfile', 'checks', 'publicOutcomes'):
            if a[key] != b[key]:
                raise ValueError(f'{mode}: source/binary observable mismatch: {key}')
        if not a['checks'] or len(a['checks']) != len(set(a['checks'])):
            raise ValueError(f'{mode}: zero/duplicate observations')
        results[mode] = {'caseCount': len(a['checks']), 'publicOutcomes': a['publicOutcomes']}
    return results


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True)
    parser.add_argument('--binary', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    Path(args.output).write_text(json.dumps(compare(args.source, args.binary), indent=2, sort_keys=True) + '\n')
    print('Source/binary public observations match for core, composed and dual products')
