#!/usr/bin/env python3
"""Verify actual APK identity/version/signature before publishing its manifest."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

def android_tool(name):
    root=Path(os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or Path.home()/'Library/Android/sdk')/'build-tools'
    candidates=sorted(root.glob(f'*/{name}'),key=lambda p:tuple(int(n) for n in re.findall(r'\d+',p.parent.name)),reverse=True)
    if not candidates: raise SystemExit(f'Android build-tool {name} not found')
    return str(candidates[0])

def verify(apk,metadata):
    if apk.stat().st_size>500*1024*1024: raise ValueError('APK exceeds the app download limit')
    badging=subprocess.check_output([android_tool('aapt'),'dump','badging',str(apk)],text=True)
    identity=re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'",badging)
    if not identity or identity[1]!='nl.musicbackyard.music_backyard' or int(identity[2])!=metadata['buildNumber'] or identity[3]!=metadata['version']: raise ValueError('Actual APK package/version differs from release metadata')
    java_env=dict(os.environ)
    if not java_env.get('JAVA_HOME') and Path('/opt/homebrew/opt/openjdk@17').is_dir():java_env['JAVA_HOME']='/opt/homebrew/opt/openjdk@17'
    signed=subprocess.check_output([android_tool('apksigner'),'verify','--verbose','--print-certs',str(apk)],text=True,env=java_env)
    fingerprints=[value.lower() for value in re.findall(r'Signer #\d+ certificate SHA-256 digest:\s*([a-fA-F0-9]+)',signed)]
    expected=Path('config/android-release-certificate.sha256').read_text().strip().lower()
    if set(fingerprints)!={expected}: raise ValueError(f'Production certificate mismatch: expected {expected}; verified APK signers {fingerprints}')
    with apk.open('rb') as source:
        digest=hashlib.sha256()
        for chunk in iter(lambda:source.read(1048576),b''): digest.update(chunk)
    return {'version':metadata['version'],'buildNumber':metadata['buildNumber'],'platform':'android','channel':'direct','track':metadata['track'],'downloadUrl':f"https://github.com/{metadata['repository']}/releases/download/{metadata['tag']}/{metadata['apkName']}",'sha256':digest.hexdigest(),'sizeBytes':apk.stat().st_size,'releaseNotes':metadata['releaseNotes'],'mandatory':False}

def main():
    metadata=json.loads(Path('build/release/metadata.json').read_text())
    apk=Path('build/release')/metadata['apkName']
    manifest=verify(apk,metadata)
    (apk.parent/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(f"Verified {metadata['version']} build {metadata['buildNumber']}, production signature and SHA-256")
if __name__=='__main__': main()
