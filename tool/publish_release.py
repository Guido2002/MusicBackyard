#!/usr/bin/env python3
"""Publish staged assets first, then atomically advance exactly one channel feed."""
import base64
import hashlib
import json
import os
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request

class GitHub:
    def __init__(self,repository,token): self.repository,self.token=repository,token
    def request(self,path,method='GET',data=None,raw=False):
        url=path if path.startswith('https://') else f'https://api.github.com/repos/{self.repository}/{path}'
        payload=data if raw else None if data is None else json.dumps(data).encode()
        request=urllib.request.Request(url,method=method,data=payload,headers={'Authorization':f'Bearer {self.token}','Accept':'application/vnd.github+json','Content-Type':'application/octet-stream' if raw else 'application/json','X-GitHub-Api-Version':'2022-11-28'})
        with urllib.request.urlopen(request,timeout=180) as response:
            body=response.read();return json.loads(body) if body else None
    def optional(self,path):
        try: return self.request(path)
        except urllib.error.HTTPError as error:
            if error.code==404:return None
            raise

def advance_feed(api,manifest):
    path=f"{manifest['track']}.json"
    for attempt in range(3):
        ref=api.optional('git/ref/heads/update-channels')
        parent=ref['object']['sha'] if ref else None
        old=api.optional(f'contents/{path}?ref=update-channels') if parent else None
        if old:
            previous=json.loads(base64.b64decode(old['content']))
            if previous['buildNumber']>manifest['buildNumber']:raise ValueError('Refusing to roll back a channel build number')
            if previous['buildNumber']==manifest['buildNumber']:
                if previous==manifest:return
                raise ValueError('Cannot replace a published build with different content')
        tree_sha=api.request(f'git/commits/{parent}')['tree']['sha'] if parent else None
        payload={'tree':[{'path':path,'mode':'100644','type':'blob','content':json.dumps(manifest,ensure_ascii=False,indent=2)+'\n'}]}
        if tree_sha:payload['base_tree']=tree_sha
        tree=api.request('git/trees','POST',payload)
        commit=api.request('git/commits','POST',{'message':f"Publish {manifest['track']} {manifest['version']} ({manifest['buildNumber']})",'tree':tree['sha'],'parents':[parent] if parent else []})
        try:
            if parent:api.request('git/refs/heads/update-channels','PATCH',{'sha':commit['sha'],'force':False})
            else:api.request('git/refs','POST',{'ref':'refs/heads/update-channels','sha':commit['sha']})
            return
        except urllib.error.HTTPError as error:
            if error.code not in (409,422) or attempt==2:raise
            time.sleep(1)

def main():
    root=Path('build/release');metadata=json.loads((root/'metadata.json').read_text());manifest=json.loads((root/'manifest.json').read_text())
    api=GitHub(metadata['repository'],os.environ.get('GH_TOKEN') or os.environ['GITHUB_TOKEN'])
    release=api.optional('releases/tags/'+urllib.parse.quote(metadata['tag'],safe=''))
    if release is None:
        release=api.request('releases','POST',{'tag_name':metadata['tag'],'target_commitish':metadata['commit'],'name':f"MusicBackyard {metadata['version']}",'body':'\n'.join('- '+v for v in manifest['releaseNotes']),'draft':True,'prerelease':metadata['track']=='beta'})
    assets={a['name']:a for a in release.get('assets',[])}
    for path in [root/metadata['apkName'],root/'manifest.json']:
        content=path.read_bytes();digest='sha256:'+hashlib.sha256(content).hexdigest();existing=assets.get(path.name)
        if existing and existing.get('digest')==digest:continue
        if not release['draft']:raise ValueError('A published release is immutable; use a new version')
        if existing:api.request(f"releases/assets/{existing['id']}",'DELETE')
        url=f"https://uploads.github.com/repos/{metadata['repository']}/releases/{release['id']}/assets?"+urllib.parse.urlencode({'name':path.name})
        api.request(url,'POST',content,raw=True)
    if release['draft']:api.request(f"releases/{release['id']}",'PATCH',{'draft':False,'make_latest':'true' if metadata['track']=='stable' else 'false'})
    advance_feed(api,manifest)
    print(f"Published https://github.com/{metadata['repository']}/releases/tag/{metadata['tag']}")
    print(f"Updated https://raw.githubusercontent.com/{metadata['repository']}/update-channels/{metadata['track']}.json")
if __name__=='__main__':main()
