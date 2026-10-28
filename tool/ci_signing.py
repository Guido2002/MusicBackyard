#!/usr/bin/env python3
"""Materialize or clean up a CI-only signing configuration; never print secrets."""
import base64
import hashlib
import subprocess
import shutil
import os
from pathlib import Path
import sys

def main():
    key=Path(os.environ['RUNNER_TEMP'])/'musicbackyard-release.p12'
    properties=Path('android/key.properties')
    if sys.argv[1:] == ['cleanup']:
        properties.unlink(missing_ok=True);key.unlink(missing_ok=True);return
    required=['ANDROID_KEYSTORE_BASE64','ANDROID_STORE_PASSWORD','ANDROID_KEY_ALIAS','ANDROID_KEY_PASSWORD']
    if any(not os.environ.get(name) for name in required): raise SystemExit('Configure the four ANDROID_* signing secrets before releasing')
    key.write_bytes(base64.b64decode(os.environ['ANDROID_KEYSTORE_BASE64'],validate=True));key.chmod(0o600)
    def escape(value): return value.replace('\\','\\\\').replace('\n','\\n').replace('\r','\\r')
    properties.write_text('\n'.join(f'{name}={escape(value)}' for name,value in [('storeFile',str(key)),('storePassword',os.environ['ANDROID_STORE_PASSWORD']),('keyAlias',os.environ['ANDROID_KEY_ALIAS']),('keyPassword',os.environ['ANDROID_KEY_PASSWORD'])])+'\n');properties.chmod(0o600)
    certificate=subprocess.check_output([shutil.which('keytool') or 'keytool','-exportcert','-keystore',str(key),'-alias',os.environ['ANDROID_KEY_ALIAS'],'-storepass:env','ANDROID_STORE_PASSWORD'],stderr=subprocess.PIPE)
    actual=hashlib.sha256(certificate).hexdigest()
    expected=Path('config/android-release-certificate.sha256').read_text().strip().lower()
    if actual!=expected: raise ValueError(f'Configured CI key differs from production certificate: expected {expected}, found {actual}')
    print(f'Production signing key certificate verified: {actual}')
if __name__=='__main__': main()
