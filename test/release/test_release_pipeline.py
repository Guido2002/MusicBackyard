import copy
import sys
from pathlib import Path
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tool'))
from prepare_release import metadata
from publish_release import advance_feed
from verify_release import certificate_fingerprints
import base64
import hashlib

class FakeGitHub:
    def __init__(self):
        self.ref=None;self.files={};self.trees={};self.commits={};self.calls=[];self.fail_update=False
    def optional(self,path):
        import base64,json
        if path.startswith('git/ref/'):return {'object':{'sha':self.ref}} if self.ref else None
        name=path.split('contents/',1)[1].split('?')[0]
        if name not in self.files:return None
        return {'content':base64.b64encode(json.dumps(self.files[name]).encode()).decode()}
    def request(self,path,method='GET',data=None):
        import json,urllib.error
        self.calls.append((path,method,copy.deepcopy(data)))
        if path.startswith('git/commits/'):
            return {'tree':{'sha':self.commits[path.rsplit('/',1)[1]]}}
        if path=='git/trees':
            tree=dict(self.trees.get(data.get('base_tree'),{}))
            for item in data['tree']:tree[item['path']]=json.loads(item['content'])
            sha='tree'+str(len(self.trees));self.trees[sha]=tree;return {'sha':sha}
        if path=='git/commits':
            sha='commit'+str(len(self.commits));self.commits[sha]=data['tree'];return {'sha':sha}
        if path.startswith('git/refs'):
            if self.fail_update:
                self.fail_update=False;raise urllib.error.HTTPError('https://api.github.com',422,'Race',{},None)
            self.ref=data['sha'];self.files=self.trees[self.commits[self.ref]];return {}
        raise AssertionError(path)

class ReleasePipelineTests(unittest.TestCase):
    def test_certificate_hash_uses_exported_bytes_independent_of_signer_headings(self):
        certificate=b'public certificate test fixture'
        pem='-----BEGIN CERTIFICATE-----\n'+base64.b64encode(certificate).decode()+'\n-----END CERTIFICATE-----'
        for heading in ['Signer #1', 'Signer (minSdkVersion=24, maxSdkVersion=2147483647)']:
            with self.subTest(heading=heading):
                self.assertEqual(certificate_fingerprints(heading+'\n'+pem+'\n'+pem),{hashlib.sha256(certificate).hexdigest()})
    def test_missing_exported_certificate_fails_closed(self):
        with self.assertRaises(ValueError):certificate_fingerprints('Verifies\nSigner #1 certificate SHA-256 digest: abc')
    def env(self,**changes):
        return {'GITHUB_REF':'refs/heads/main','GITHUB_REPOSITORY':'Guido2002/MusicBackyard','GITHUB_RUN_NUMBER':'5','GITHUB_SHA':'a'*40,'RELEASE_VERSION':'1.1.1','RELEASE_TRACK':'stable',**changes}
    def test_manual_stable_version_and_global_build(self):
        value=metadata(self.env());self.assertEqual(value['version'],'1.1.1');self.assertEqual(value['buildNumber'],100501)
    def test_run_attempts_and_later_runs_have_increasing_android_builds(self):
        builds=[metadata(self.env(GITHUB_RUN_NUMBER=run,GITHUB_RUN_ATTEMPT=attempt))['buildNumber'] for run,attempt in [('5','1'),('5','2'),('5','99'),('6','1')]]
        self.assertEqual(builds,[100501,100502,100599,100601])
        for values in [{'GITHUB_RUN_ATTEMPT':'0'},{'GITHUB_RUN_ATTEMPT':'100'},{'GITHUB_RUN_NUMBER':'21474837'}]:
            with self.subTest(values=values):
                with self.assertRaises(ValueError): metadata(self.env(**values))
    def test_beta_tag_determines_track(self):
        value=metadata(self.env(GITHUB_REF='refs/tags/v1.2.0-beta.1'));self.assertEqual(value['track'],'beta');self.assertEqual(value['version'],'1.2.0-beta.1')
    def test_untrusted_versions_tracks_and_refs_are_rejected(self):
        for changes in [{'RELEASE_VERSION':'$(echo bad)'},{'RELEASE_VERSION':'1.2.3-beta..1'},{'RELEASE_VERSION':'1.2.3-beta.01','RELEASE_TRACK':'beta'},{'RELEASE_TRACK':'beta'},{'RELEASE_VERSION':'1.2.3-beta.1'},{'GITHUB_REF':'refs/heads/untrusted'},{'GITHUB_RUN_NUMBER':'0'},{'GITHUB_REPOSITORY':'x/../../evil'}]:
            with self.subTest(changes=changes):
                with self.assertRaises(ValueError):metadata(self.env(**changes))
    def test_publishing_a_channel_preserves_the_other_channel(self):
        api=FakeGitHub();advance_feed(api,{'track':'beta','version':'1.2.0-beta.1','buildNumber':100002});advance_feed(api,{'track':'stable','version':'1.1.1','buildNumber':100001})
        self.assertEqual(api.files['beta.json']['buildNumber'],100002);self.assertEqual(api.files['stable.json']['buildNumber'],100001)
    def test_rollback_and_mutation_of_an_existing_build_are_rejected(self):
        api=FakeGitHub();value={'track':'stable','version':'1.1.1','buildNumber':100005};advance_feed(api,value)
        advance_feed(api,value)
        for changed in [{**value,'buildNumber':100004},{**value,'version':'changed'}]:
            with self.assertRaises(ValueError):advance_feed(api,changed)
        self.assertEqual(api.files['stable.json'],value)
    def test_ref_race_retries_without_force_push(self):
        api=FakeGitHub();advance_feed(api,{'track':'stable','version':'1.1.1','buildNumber':100001});api.fail_update=True
        with patch('publish_release.time.sleep'):advance_feed(api,{'track':'stable','version':'1.1.2','buildNumber':100002})
        self.assertEqual(api.files['stable.json']['buildNumber'],100002)
        self.assertTrue(all(not call[2].get('force',False) for call in api.calls if call[0].startswith('git/refs')))
if __name__=='__main__':unittest.main()
