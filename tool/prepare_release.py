#!/usr/bin/env python3
"""Resolve a stable/beta release without interpolating dispatch input into shell code."""
import json
import os
from pathlib import Path
import re
import subprocess
from automatic_release import automatic_plan

VERSION=re.compile(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*))?$')

def metadata(env):
    version=env.get('RELEASE_VERSION','').strip()
    ref=env.get('GITHUB_REF','')
    if ref.startswith('refs/tags/v'):
        version=ref[len('refs/tags/v'):]
        track='beta' if '-' in version else 'stable'
    else:
        if ref!='refs/heads/main': raise ValueError('Manual releases must use main')
        track=env.get('RELEASE_TRACK','stable')
    if not VERSION.fullmatch(version): raise ValueError('Use a valid semantic version, for example 1.1.1 or 1.1.2-beta.1')
    if track not in ('stable','beta') or ('-' in version)!=(track=='beta'): raise ValueError('Stable versions cannot have a prerelease suffix; beta versions must have one')
    repository=env.get('GITHUB_REPOSITORY','')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+',repository): raise ValueError('Invalid repository')
    number=int(env.get('GITHUB_RUN_NUMBER','0'))
    attempt=int(env.get('GITHUB_RUN_ATTEMPT','1'))
    build=100000+number*100+attempt
    if number<=0 or not 0<attempt<100 or build>2147483647: raise ValueError('Invalid workflow run/attempt number')
    return {'version':version,'track':track,'buildNumber':build,'tag':f'v{version}','repository':repository,'apkName':f'MusicBackyard-{version}.apk','commit':env.get('GITHUB_SHA','')}

def main():
    env=dict(os.environ)
    automatic=env.get('GITHUB_EVENT_NAME')=='push' and env.get('GITHUB_REF')=='refs/heads/main'
    planned=None
    if automatic:
        initial=re.search(r'^version:\s*(\d+\.\d+\.\d+)',Path('pubspec.yaml').read_text(),re.MULTILINE)
        if not initial: raise SystemExit('Missing pubspec version')
        planned=automatic_plan(env['GITHUB_SHA'],initial[1])
        env.update(RELEASE_VERSION=planned['version'],RELEASE_TRACK=planned['track'])
    data=metadata(env)
    subprocess.run(['git','merge-base','--is-ancestor',data['commit'],'origin/main'],check=True)
    notes=Path('docs/releases')/f"{data['version']}.txt"
    if not notes.is_file() and not automatic: raise SystemExit(f'Missing Dutch release notes: {notes}')
    data['releaseNotes']=[v.strip() for v in notes.read_text().splitlines() if v.strip()] if notes.is_file() else planned['releaseNotes']
    if not data['releaseNotes']: raise SystemExit('Release notes cannot be empty')
    destination=Path('build/release');destination.mkdir(parents=True,exist_ok=True)
    (destination/'metadata.json').write_text(json.dumps(data,indent=2)+'\n')
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'],'a') as output:
            for key in ['version','track','buildNumber','apkName']: output.write(f'{key}={data[key]}\n')
    print(f"Prepared {data['track']} {data['version']} (Android build {data['buildNumber']})")
if __name__=='__main__': main()
