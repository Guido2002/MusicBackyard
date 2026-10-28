#!/usr/bin/env python3
"""Derive the next stable version and release notes from committed changes."""
import re
import subprocess

STABLE_TAG = re.compile(r'^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$')
CONVENTIONAL = re.compile(r'^(\w+)(?:\([^\n()]+\))?(!)?:\s*(.+)$')

def latest_stable(tags):
    versions = [(tuple(map(int, match.groups())), tag) for tag in tags if (match := STABLE_TAG.fullmatch(tag))]
    return max(versions)[1] if versions else None

def plan_release(tags, messages, initial_version='0.0.0'):
    tag = latest_stable(tags)
    base = tag[1:] if tag else initial_version
    match = STABLE_TAG.fullmatch('v' + base)
    if not match: raise ValueError('Invalid initial stable version')
    major, minor, patch = map(int, match.groups())
    features, breaking, notes, other = False, False, [], []
    for message in messages:
        lines = message.strip().splitlines()
        if not lines: continue
        subject = lines[0]
        conventional = CONVENTIONAL.fullmatch(subject)
        if re.search(r'^BREAKING[ -]CHANGE:\s*\S', message, re.MULTILINE): breaking = True
        if conventional:
            kind, bang, description = conventional.groups()
            breaking |= bool(bang)
            features |= kind == 'feat'
            if kind in ('feat', 'fix', 'perf', 'revert'):
                label = 'Nieuwe functie' if kind == 'feat' else 'Verbetering'
                notes.append(f'{label}: {description[:400]}')
        else:
            other.append(subject[:400])
    version = f'{major + 1}.0.0' if breaking else f'{major}.{minor + 1}.0' if features else f'{major}.{minor}.{patch + 1}'
    return {'version': version, 'track': 'stable', 'releaseNotes': list(dict.fromkeys(notes or other or ['Onderhoud en stabiliteitsverbeteringen.']))[:50]}

def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()

def automatic_plan(commit, initial_version):
    tags = git('tag', '--list', 'v*').splitlines()
    previous = latest_stable(tags)
    # Include unreleased changes across a batch of commits, including merged PRs.
    revision = f'{previous}..{commit}' if previous else commit
    messages = git('log', '--format=%B%x00', revision).split('\0')
    return plan_release(tags, messages, initial_version)
