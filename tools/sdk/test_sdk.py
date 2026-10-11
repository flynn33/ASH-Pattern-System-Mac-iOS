#!/usr/bin/env python3
"""Focused failure-path tests for payload, provenance, ZIP and build gates."""
import argparse
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import sdk

class SDKGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ASH SDK gate cases ')
        self.root = Path(self.temp.name)
    def tearDown(self):
        self.temp.cleanup()
    def base(self):
        root = self.root / 'ASH-Apple-SDK-1.0.0'; root.mkdir()
        for name in ('Frameworks','Documentation','Examples'):(root/name).mkdir()
        for module in sdk.MODULES:(root/'Frameworks'/f'{module}.xcframework').mkdir()
        for name in ('VERSION','SDK-MANIFEST.json','COMPONENTS.json','CONTENTS.sha256'):(root/name).write_text('1.0.0\n' if name=='VERSION' else '{}')
        (root/'LICENSE').write_text('License')
        (root/'Package.swift').write_text(sdk.BINARY_PACKAGE)
        return root
    def archive(self, names):
        path=self.root/'test.zip'
        with zipfile.ZipFile(path,'w') as z:
            for name, value, mode in names:
                i=zipfile.ZipInfo(name);i.create_system=3;i.external_attr=mode<<16;z.writestr(i,value)
        return path
    def test_stale_output_is_rejected(self):
        (self.root/'stale').write_text('old bytes')
        with self.assertRaisesRegex(ValueError,'stale/nonempty'):sdk.fresh_directory(self.root)
    def test_command_nonzero_is_not_a_pass(self):
        with self.assertRaisesRegex(ValueError,'Command failed'):sdk.run(['/bin/sh','-c','exit 19'])
    def test_missing_framework_rejected(self):
        with self.assertRaisesRegex(ValueError,'Missing framework'):sdk.inspect_frameworks(self.root,'1.0.0','1.0.0','2')
    def test_wrong_architecture_matrix_rejected(self):
        root=self.root/'ASHCore.xcframework';root.mkdir()
        import plistlib
        (root/'Info.plist').write_bytes(plistlib.dumps({'AvailableLibraries':[{'LibraryIdentifier':'ios-arm64'}]}))
        with self.assertRaisesRegex(ValueError,'three distinct'):sdk.inspect_frameworks(self.root,'1.0.0','1.0.0','2')
    def test_omitted_license_rejected(self):
        root=self.base();(root/'LICENSE').unlink()
        with self.assertRaisesRegex(ValueError,'allowlist'):sdk.safe_payload(root)
    def test_empty_license_rejected(self):
        root=self.base();(root/'LICENSE').write_text('')
        with self.assertRaisesRegex(ValueError,'License'):sdk.safe_payload(root)
    def test_partial_provenance_rejected(self):
        p=self.root/'provenance.json';p.write_text('{"sourceCommit":"abc"}')
        with self.assertRaisesRegex(ValueError,'Partial'):sdk.checked_provenance(p)
    def test_unfilled_provenance_template_rejected(self):
        p=self.root/'template.json';p.write_text(json.dumps({key:None for key in sdk.REQUIRED_PROVENANCE}))
        with self.assertRaisesRegex(ValueError,'Invalid immutable'):sdk.checked_provenance(p)
    def test_curated_document_links_rebased(self):
        text='[API](sdk-api-and-lifecycle.md#session) [web](https://example.com/sdk-diagnostics.md)\n[ref]: ./sdk-migration.md\n'
        actual=sdk.rebase_document_links(text)
        self.assertIn('[API](API-and-Lifecycle.md#session)',actual)
        self.assertIn('https://example.com/sdk-diagnostics.md',actual)
        self.assertIn('[ref]: Migration.md',actual)
    def test_unresolved_shipped_document_link_rejected(self):
        (self.root/'Documentation').mkdir();(self.root/'Examples').mkdir()
        (self.root/'Documentation/Getting-Started.md').write_text('[unshipped](sdk-security.md)')
        with self.assertRaisesRegex(ValueError,'Unresolved shipped'):sdk.verify_document_links(self.root)
    def test_shipped_document_local_anchor_link_accepted(self):
        (self.root/'Documentation').mkdir();(self.root/'Examples').mkdir()
        (self.root/'Documentation/Getting-Started.md').write_text('[API](API-and-Lifecycle.md#session) [anchor](#intro)')
        (self.root/'Documentation/API-and-Lifecycle.md').write_text('Session')
        sdk.verify_document_links(self.root)
    def test_stale_build_commit_rejected(self):
        (self.root/'Frameworks').mkdir()
        (self.root/'BUILD-PROVENANCE.json').write_text(json.dumps({'sourceCommit':'0'*40,'sourceStatus':[],'sourceInputsSHA256':{},'frameworkFilesSHA256':{}}))
        with self.assertRaisesRegex(ValueError,'Stale or uncommitted'):sdk.checked_build_record(self.root,'1'*40)
    def test_changed_framework_after_build_rejected(self):
        framework=self.root/'Frameworks';framework.mkdir();(framework/'binary').write_bytes(b'actual changed bytes')
        (self.root/'BUILD-PROVENANCE.json').write_text(json.dumps({'sourceCommit':'1'*40,'sourceStatus':[],'sourceInputsSHA256':{},'frameworkFilesSHA256':{'binary':'0'*64}}))
        with patch.object(sdk,'source_inputs',return_value={}):
            with self.assertRaisesRegex(ValueError,'changed after verified build'):sdk.checked_build_record(self.root,'1'*40)
    def test_changed_framework_symlink_after_build_rejected(self):
        framework=self.root/'Frameworks';framework.mkdir();(framework/'binary').write_bytes(b'bytes');(framework/'link').symlink_to('binary')
        (self.root/'BUILD-PROVENANCE.json').write_text(json.dumps({'sourceCommit':'1'*40,'sourceStatus':[],
            'sourceInputsSHA256':{},'frameworkFilesSHA256':{'binary':sdk.sha(framework/'binary')},'frameworkSymlinks':{'link':'old-target'}}))
        with patch.object(sdk,'source_inputs',return_value={}):
            with self.assertRaisesRegex(ValueError,'symlinks changed'):sdk.checked_build_record(self.root,'1'*40)
    def test_forbidden_producer_source_rejected(self):
        root=self.base();(root/'Frameworks/producer.swift').write_text('')
        with self.assertRaisesRegex(ValueError,'Producer source'):sdk.safe_payload(root)
    def test_forbidden_corpus_rejected(self):
        root=self.base();(root/'Examples/CanonicalReference').mkdir()
        with self.assertRaisesRegex(ValueError,'Forbidden payload path'):sdk.safe_payload(root)
    def test_empty_fixture_directory_rejected(self):
        root=self.base();(root/'Examples/Fixtures').mkdir()
        with self.assertRaisesRegex(ValueError,'Forbidden payload path'):sdk.safe_payload(root)
    def test_hidden_dev_file_rejected(self):
        root=self.base();(root/'Frameworks/.collector').write_text('')
        with self.assertRaisesRegex(ValueError,'hidden payload'):sdk.safe_payload(root)
    def test_development_interface_rejected(self):
        root=self.base();(root/'Frameworks/collector.swiftinterface').write_text('ASHDevelopmentDiagnostics')
        with self.assertRaisesRegex(ValueError,'Development implementation'):sdk.safe_payload(root)
    def test_duplicate_core_composition_rejected(self):
        root=self.base();(root/'Frameworks/ASHCoreDuplicate.xcframework').mkdir()
        with self.assertRaisesRegex(ValueError,'Duplicate/missing'):sdk.safe_payload(root)
    def test_symlink_escape_rejected(self):
        root=self.base();(root/'Frameworks/escape').symlink_to('/etc/passwd')
        with self.assertRaisesRegex(ValueError,'Unsafe/dangling'):sdk.safe_payload(root)
    def test_dangling_symlink_rejected(self):
        root=self.base();(root/'Frameworks/escape').symlink_to('absent')
        with self.assertRaisesRegex(ValueError,'Unsafe/dangling'):sdk.safe_payload(root)
    def test_checksum_final_payload_mutation_rejected(self):
        root=self.base();(root/'CONTENTS.sha256').write_text(''.join(f'{v}  {k}\n' for k,v in sdk.digests(root).items()))
        sdk.verify_contents(root);(root/'VERSION').write_text('stale')
        with self.assertRaisesRegex(ValueError,'checksum mismatch'):sdk.verify_contents(root)
    def test_checksum_omitted_final_file_rejected(self):
        root=self.base();(root/'CONTENTS.sha256').write_text(''.join(f'{v}  {k}\n' for k,v in sdk.digests(root).items()))
        (root/'Documentation/final.md').write_text('after checksum')
        with self.assertRaisesRegex(ValueError,'checksum mismatch'):sdk.verify_contents(root)
    def test_missing_core_package_product_rejected(self):
        root=self.base();(root/'Package.swift').write_text(sdk.BINARY_PACKAGE.replace('targets: ["ASHPatternSystem", "ASHCore"]','targets: ["ASHPatternSystem"]'))
        with self.assertRaisesRegex(ValueError,'graph drift'):sdk.safe_payload(root)
    def test_zip_absolute_path_rejected(self):
        z=self.archive([('/absolute',b'a',stat.S_IFREG|0o644)])
        with self.assertRaisesRegex(ValueError,'Unsafe ZIP path'):sdk.safe_extract(z,self.root/'extract')
    def test_zip_stale_extraction_rejected(self):
        z=self.archive([('root/file',b'a',stat.S_IFREG|0o644)])
        extract=self.root/'extract';extract.mkdir();(extract/'existing').write_text('preserved')
        with self.assertRaisesRegex(ValueError,'stale/nonempty'):sdk.safe_extract(z,extract)
        self.assertEqual((extract/'existing').read_text(),'preserved')
    def test_zip_traversal_rejected(self):
        z=self.archive([('root/../../escape',b'a',stat.S_IFREG|0o644)])
        with self.assertRaisesRegex(ValueError,'Unsafe ZIP path'):sdk.safe_extract(z,self.root/'extract')
    def test_zip_symlink_escape_rejected(self):
        z=self.archive([('root/link',b'../../outside',stat.S_IFLNK|0o777)])
        with self.assertRaisesRegex(ValueError,'Unsafe ZIP symlink'):sdk.safe_extract(z,self.root/'extract')
    def test_zip_duplicate_path_rejected(self):
        with self.assertWarns(UserWarning):z=self.archive([('root/file',b'a',stat.S_IFREG|0o644),('root/file',b'b',stat.S_IFREG|0o644)])
        with self.assertRaisesRegex(ValueError,'Duplicate ZIP entry'):sdk.safe_extract(z,self.root/'extract')
    def test_zip_case_alias_rejected(self):
        z=self.archive([('root/Payload',b'a',stat.S_IFREG|0o644),('root/payload',b'b',stat.S_IFREG|0o644)])
        with self.assertRaisesRegex(ValueError,'Aliased ZIP entry'):sdk.safe_extract(z,self.root/'extract')
    def test_zip_unicode_alias_rejected(self):
        z=self.archive([('root/caf\u00e9',b'a',stat.S_IFREG|0o644),('root/cafe\u0301',b'b',stat.S_IFREG|0o644)])
        with self.assertRaisesRegex(ValueError,'Aliased ZIP entry'):sdk.safe_extract(z,self.root/'extract')
    def test_zip_parent_component_alias_rejected(self):
        z=self.archive([('root/Folder/a',b'a',stat.S_IFREG|0o644),('root/folder/b',b'b',stat.S_IFREG|0o644)])
        with self.assertRaisesRegex(ValueError,'Aliased ZIP entry'):sdk.safe_extract(z,self.root/'extract')
    def test_release_manifest_duplicate_asset_rejected(self):
        version='1.0.0'
        names=[f'ASH-Apple-SDK-{version}.zip',f'ASHCore-{version}.xcframework.zip',f'ASHPatternSystem-{version}.xcframework.zip']
        assets=[]
        for name in names:
            p=self.root/name;p.write_bytes(b'fixture')
            assets.append({'name':name,'size':p.stat().st_size,'sha256':sdk.sha(p)})
        manifest=self.root/f'RELEASE-MANIFEST-{version}.json'
        manifest.write_text(json.dumps({'schemaVersion':'1.0','sdkVersion':version,'publisherSigning':'unsigned','assets':assets+[assets[1]]}))
        (self.root/'SHA256SUMS').write_text(''.join(f'{sdk.sha(self.root/name)}  {name}\n' for name in names+[manifest.name]))
        with self.assertRaisesRegex(ValueError,'Release manifest asset inventory mismatch'):sdk.verify_assets(self.root)
    def test_zip_normalized_alias_path_rejected(self):
        z=self.archive([('root/./file',b'a',stat.S_IFREG|0o644)])
        with self.assertRaisesRegex(ValueError,'Noncanonical ZIP path'):sdk.safe_extract(z,self.root/'extract')
    def test_unapproved_framework_symlink_target_rejected(self):
        xc=self.root/'ASHCore.xcframework/macos-arm64_x86_64/ASHCore.framework'
        xc.mkdir(parents=True);(xc/'Modules').symlink_to('Versions/Current/Headers')
        with self.assertRaisesRegex(ValueError,'Unexpected framework symlink'):sdk.framework_payload_allowlist(self.root)
    def test_corrupt_archive_rejected(self):
        z=self.root/'bad.zip';z.write_bytes(b'not a zip')
        with self.assertRaises(zipfile.BadZipFile):sdk.safe_extract(z,self.root/'extract')
    def test_macos_version_symlinks_preserved(self):
        root=self.root/'ASHCore.framework';(root/'Versions/A').mkdir(parents=True)
        (root/'Versions/A/ASHCore').write_bytes(b'binary');(root/'Versions/Current').symlink_to('A')
        (root/'ASHCore').symlink_to('Versions/Current/ASHCore')
        dest=self.root/'valid.zip';sdk.make_zip(root,dest,1750000000);sdk.safe_extract(dest,self.root/'extract')
        copied=self.root/'extract/ASHCore.framework'
        self.assertTrue((copied/'ASHCore').is_symlink());self.assertEqual((copied/'ASHCore').read_bytes(),b'binary')
    def test_zero_case_consumer_report_rejected(self):
        report=self.root/'zero.json';report.write_text(json.dumps({'sdkVersion':'1.0.0','diagnosticProfile':'release-minimal','checks':[]}))
        result=subprocess.run([str(sdk.ROOT/'Examples/SDKConsumer/verify/verify-report.sh'),str(report),'core','1.0.0'],capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0);self.assertIn('Zero-case',result.stderr)
    def test_failed_archive_stops_build(self):
        fake=self.root/'xcodebuild';fake.write_text('#!/bin/sh\nexit 23\n');fake.chmod(0o755)
        def observed(command,log=None,cwd=sdk.ROOT):
            if str(command[0]) == str(fake):return original(command,log,cwd)
            return ''
        original=sdk.run
        with patch.object(sdk,'checked_version',return_value=('1.0.0','1.0.0','2')),patch.object(sdk,'composition',return_value={}),patch.object(sdk,'run',side_effect=observed),patch.dict(os.environ,{'ASH_XCODEBUILD':str(fake)}):
            with self.assertRaisesRegex(ValueError,'Command failed'):sdk.build(argparse.Namespace(output=str(self.root/'build')))
        self.assertFalse((self.root/'build/Frameworks').exists())

if __name__=='__main__':unittest.main()
