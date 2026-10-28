#!/usr/bin/env python3
"""Encrypt signing secrets for this repository using its GitHub Actions public key.
Requires PyNaCl. Authentication uses GH_TOKEN/GITHUB_TOKEN or the git credential helper.
Credentials are never printed or persisted by this script.
"""
import base64
import json
import os
from pathlib import Path
import subprocess
import urllib.request
from nacl.public import PublicKey, SealedBox

ROOT=Path(__file__).resolve().parents[1]
REPOSITORY='Guido2002/MusicBackyard'

def token():
    value=os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')
    if value: return value
    result=subprocess.run(['git','credential','fill'],input='protocol=https\nhost=github.com\n\n',capture_output=True,text=True,check=True,env={**os.environ,'GIT_TERMINAL_PROMPT':'0'})
    values=dict(line.split('=',1) for line in result.stdout.splitlines() if '=' in line)
    if not values.get('password'): raise SystemExit('GitHub authentication is required.')
    return values['password']

def configure():
    credential=token()
    def request(path,method='GET',data=None):
        req=urllib.request.Request(f'https://api.github.com/repos/{REPOSITORY}/{path}',method=method,data=None if data is None else json.dumps(data).encode(),headers={'Authorization':f'Bearer {credential}','Accept':'application/vnd.github+json','Content-Type':'application/json'})
        with urllib.request.urlopen(req,timeout=30) as response:
            body=response.read()
            return json.loads(body) if body else None
    public=request('actions/secrets/public-key')
    box=SealedBox(PublicKey(base64.b64decode(public['key'])))
    values=json.loads((ROOT/'.release/signing/credentials.json').read_text())
    secrets={'ANDROID_KEYSTORE_BASE64':base64.b64encode(Path(values['storeFile']).read_bytes()).decode(),'ANDROID_STORE_PASSWORD':values['storePassword'],'ANDROID_KEY_ALIAS':values['keyAlias'],'ANDROID_KEY_PASSWORD':values['keyPassword']}
    for name,value in secrets.items():
        encrypted=base64.b64encode(box.encrypt(value.encode())).decode()
        request(f'actions/secrets/{name}','PUT',{'encrypted_value':encrypted,'key_id':public['key_id']})
        print(f'Configured encrypted secret: {name}')

if __name__=='__main__': configure()
