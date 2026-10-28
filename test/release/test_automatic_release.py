import subprocess
import sys
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tool'))
from automatic_release import automatic_plan, latest_stable, plan_release


class AutomaticReleaseTests(unittest.TestCase):
    def test_highest_stable_version_ignores_beta_and_invalid_tags(self):
        self.assertEqual(latest_stable(['v1.9.9', 'v1.10.0', 'v2.0.0-beta.1', 'v01.99.0', 'unrelated']), 'v1.10.0')

    def test_fix_increments_patch_and_creates_notes(self):
        result = plan_release(['v1.1.1'], ['fix(pdf): Akkoorden boven de tekst'])
        self.assertEqual(result['version'], '1.1.2')
        self.assertEqual(result['track'], 'stable')
        self.assertEqual(result['releaseNotes'], ['Verbetering: Akkoorden boven de tekst'])

    def test_feature_in_a_batch_increments_minor_once(self):
        result = plan_release(['v1.1.1'], ['fix: Correctie', 'feat(notes): Checklist', 'feat: Markering'])
        self.assertEqual(result['version'], '1.2.0')
        self.assertEqual(len(result['releaseNotes']), 3)

    def test_breaking_subject_or_footer_increments_major(self):
        for message in ['feat(api)!: Nieuw formaat', 'fix!: Nieuw formaat', 'feat: Formaat\n\nBREAKING CHANGE: oude versies niet ondersteund', 'fix: Formaat\n\nBREAKING-CHANGE: nieuw formaat']:
            with self.subTest(message=message):
                self.assertEqual(plan_release(['v1.9.8'], [message])['version'], '2.0.0')

    def test_regular_app_commits_default_to_patch(self):
        result = plan_release(['v1.1.1'], ['Herstel de PDF-uitlijning'])
        self.assertEqual(result['version'], '1.1.2')
        self.assertEqual(result['releaseNotes'], ['Herstel de PDF-uitlijning'])

    def test_notes_prefer_features_and_fixes_and_do_not_execute_subjects(self):
        result = plan_release(['v1.1.1'], ['docs: Documentatie', 'fix: $(echo literal)', 'fix: $(echo literal)'])
        self.assertEqual(result['releaseNotes'], ['Verbetering: $(echo literal)'])

    def test_no_stable_tag_uses_the_initial_app_version(self):
        self.assertEqual(plan_release([], ['fix: Eerste correctie'], '1.3.4')['version'], '1.3.5')
        with self.assertRaises(ValueError): plan_release([], [], 'untrusted')

    def test_real_git_history_uses_changes_after_the_stable_tag(self):
        with tempfile.TemporaryDirectory() as directory:
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=directory, text=True, stderr=subprocess.DEVNULL).strip()
            git('init', '--initial-branch=main')
            git('config', 'user.name', 'Release Test')
            git('config', 'user.email', 'test@example.invalid')
            git('commit', '--allow-empty', '-m', 'feat!: Ancient change')
            git('tag', 'v1.1.1')
            git('commit', '--allow-empty', '-m', 'feat(notes): Checklist')
            git('tag', 'v1.2.0-beta.1')
            git('commit', '--allow-empty', '-m', 'fix(pdf): Uitlijning')
            with patch('automatic_release.git', side_effect=git):
                result = automatic_plan(git('rev-parse', 'HEAD'), '1.1.1')
            self.assertEqual(result['version'], '1.2.0')
            self.assertEqual(len(result['releaseNotes']), 2)
            self.assertFalse(any('Ancient' in note for note in result['releaseNotes']))


if __name__ == '__main__': unittest.main()
