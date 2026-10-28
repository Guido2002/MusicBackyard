#!/usr/bin/env python3
"""Create a durable private Android release key; never overwrite an existing key."""
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SIGNING = ROOT / '.release' / 'signing'

def setup():
    SIGNING.mkdir(parents=True, exist_ok=True, mode=0o700)
    key = SIGNING / 'musicbackyard-release.p12'
    credentials = SIGNING / 'credentials.json'
    properties = ROOT / 'android' / 'key.properties'
    if properties.exists() and not credentials.exists():
        raise SystemExit('Existing signing configuration preserved; supply its key through GitHub Actions secrets.')
    if key.exists() or credentials.exists():
        if not key.exists() or not credentials.exists():
            raise SystemExit('Incomplete signing material: restore the missing file from your private backup.')
        print('Existing release key preserved.')
        return
    keytool = next((str(p) for p in [Path(os.environ.get('JAVA_HOME','/nonexistent'))/'bin/keytool',Path('/opt/homebrew/opt/openjdk@17/bin/keytool')] if p.is_file()),shutil.which('keytool'))
    if not keytool:
        raise SystemExit('Install JDK 17 before generating the release key.')
    password = secrets.token_urlsafe(48)
    alias = 'musicbackyard-release'
    with tempfile.TemporaryDirectory(dir=SIGNING) as temporary:
        generated = Path(temporary) / 'release.p12'
        subprocess.run([keytool,'-genkeypair','-storetype','PKCS12','-keystore',str(generated),'-alias',alias,'-keyalg','RSA','-keysize','4096','-validity','10000','-storepass:env','MB_SIGNING_PASSWORD','-keypass:env','MB_SIGNING_PASSWORD','-dname','CN=MusicBackyard Release'],env={**os.environ,'MB_SIGNING_PASSWORD':password},check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        generated.chmod(0o600)
        generated.replace(key)
    credentials.write_text(json.dumps({'storeFile':str(key),'storePassword':password,'keyAlias':alias,'keyPassword':password})+'\n')
    credentials.chmod(0o600)
    properties.write_text(f'storeFile={key}\nstorePassword={password}\nkeyAlias={alias}\nkeyPassword={password}\n')
    properties.chmod(0o600)
    print('Release key created under .release/signing/. Keep a private backup of this entire directory; it is excluded from Git.')

if __name__ == '__main__':
    setup()
