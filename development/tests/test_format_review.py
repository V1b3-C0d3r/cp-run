"""Observable error/review phases, persisted exceptions and temporary notes."""
import io
import json
from pathlib import Path
import shutil
import unittest
from unittest import mock
import test_school_format as fixtures

engine = fixtures.engine


class Terminal(io.StringIO):
    def isatty(self):
        return True


class InputTerminal(Terminal):
    def __init__(self, actions):
        super().__init__()
        self.actions = iter(actions)

    def readline(self, *args):
        action = next(self.actions, '')
        return action() if callable(action) else action


@unittest.skipUnless(shutil.which('clang') and shutil.which('clang-format'), 'needs school frontend')
class InteractiveReviewTest(unittest.TestCase):
    def setUp(self):
        self.case = fixtures.SchoolFormatTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)
        self.source = self.case.source
        self.report = self.case.root / 'report.json'
        self.output = Terminal()

    def run_review(self, code, actions, **options):
        self.source.write_text(code)
        config = dict(protected=[str(self.source)], format_mode='school', prettier='format',
                      review=True, review_report=str(self.report), **options)
        with mock.patch.object(engine.sys, 'stdin', InputTerminal(actions)), \
             mock.patch.object(engine.sys, 'stderr', self.output):
            status = engine.execute_format_review(config)
        return status, json.loads(self.report.read_text())

    def test_errors_hide_warnings_until_real_fix_then_review(self):
        def fix():
            self.assertNotIn('mutable global', self.output.getvalue())
            early = json.loads(self.report.read_text())
            self.assertTrue(all(item['severity'] == 'error' for item in early['findings']))
            self.source.write_text(self.source.read_text().replace('BadName', 'value'))
            return 'a\n'
        status, report = self.run_review('int state;\nint main(){int BadName=0;return BadName;}', [fix, 'd all\n'])
        self.assertEqual(status, 0, self.output.getvalue())
        self.assertEqual([item['phase'] for item in report['initial']], ['errors', 'review'])
        self.assertTrue(any(item['decision'] == 'fixed' for item in report['findings']))
        self.assertTrue(any(item['decision'] == 'deny' for item in report['findings']))

    def test_accept_without_fix_cannot_close_error(self):
        status, report = self.run_review('int main(){int BadName=0;return BadName;}', ['a\n', 'd\n'])
        self.assertEqual(status, 1)
        self.assertEqual(report['state'], 'stopped')
        self.assertNotIn('fixed', [item['decision'] for item in report['findings']])

    def test_accept_warning_rechecks_actual_code_without_markers(self):
        def fix():
            self.source.write_text(self.source.read_text().replace('int state;\n', ''))
            return 'a\n'
        status, report = self.run_review('int state;\nint main(void){return 0;}', [fix])
        self.assertEqual(status, 0, self.output.getvalue())
        self.assertNotIn('school-', self.source.read_text())
        self.assertTrue(any(item['decision'] == 'fixed' for item in report['findings']))

    def test_accept_warning_without_fix_stays_open(self):
        status, report = self.run_review('int state;\nint main(void){return 0;}', ['a\n', 'd\n'])
        self.assertEqual(status, 0)
        self.assertTrue(any(item['decision'] == 'deny' for item in report['findings']))

    def test_justified_all_empty_persists_distinct_error_and_warning_exceptions(self):
        code = 'int state;\nint main(void){int BadName=0;return BadName;}'
        status, report = self.run_review(code, ['j all\n', 'j all\n'])
        self.assertEqual(status, 0, self.output.getvalue())
        actual = self.source.read_text()
        self.assertIn('school-error-justified 3.4 */', actual)
        self.assertIn('school-justified 5.14 */', actual)
        self.assertNotIn(':  */', actual)
        repeated = self.case.invoke('--school', self.source, '--check')
        self.assertEqual(repeated.returncode, 0, repeated.stderr)
        self.assertTrue(all(item['decision'] == 'justified' for item in report['findings']))

    def test_comment_does_not_mute_and_survives_later_justification(self):
        status, report = self.run_review('int main(void){int BadName=0;return BadName;}',
                                        ['c assignment requires this externally defined name\n', 'a\n', 'j externally required identifier\n'])
        self.assertEqual(status, 0, self.output.getvalue())
        actual = self.source.read_text()
        self.assertIn('school-error-comment 3.4:', actual)
        self.assertIn('school-error-justified 3.4:', actual)
        self.assertTrue(any(item['comments'] for item in report['findings']))

    def test_temporary_annotations_visible_during_review_removed_after_deny(self):
        def deny():
            self.assertIn('/* school-warning 5.14:', self.source.read_text())
            return 'd all\n'
        status, _ = self.run_review('int state;\nint main(void){return 0;}', [deny], annotate=True)
        self.assertEqual(status, 0, self.output.getvalue())
        self.assertNotIn('school-warning', self.source.read_text())
        again = self.case.invoke('--school', self.source)
        self.assertIn('5.14 warning', again.stderr)

    def test_eof_cleans_temporary_notes_and_exports_pending(self):
        status, report = self.run_review('int state;\nint main(void){return 0;}', [], annotate=True)
        self.assertEqual(status, 1)
        self.assertEqual(report['state'], 'incomplete')
        self.assertNotIn('school-warning', self.source.read_text())
        self.assertEqual(report['findings'][0]['decision'], 'pending')

    def test_interrupt_cleans_notes_and_writes_partial_report(self):
        def interrupt():
            self.assertIn('/* school-warning 5.14:', self.source.read_text())
            raise KeyboardInterrupt
        status, report = self.run_review('int state;\nint main(void){return 0;}', [interrupt], annotate=True)
        self.assertEqual(status, 130)
        self.assertEqual(report['state'], 'interrupted')
        self.assertNotIn('/* school-warning ', self.source.read_text())

    def test_invalid_quoting_and_comment_are_recoverable(self):
        status, _ = self.run_review('int state;\nint main(void){return 0;}',
                                   ['a "\n', 'j bad */ comment\n', 'd\n'])
        self.assertEqual(status, 0)
        self.assertIn('invalid quoting', self.output.getvalue())
        self.assertIn('invalid comment', self.output.getvalue())

    def test_report_source_alias_rejected_before_source_edit(self):
        self.source.write_text('int main(){return 0;}')
        before = self.source.read_bytes()
        with self.assertRaises(engine.CheckUsageError):
            engine.execute_format_review(dict(format_mode='school', protected=[str(self.source)],
                prettier='format', review_report=str(self.source), overwrite=True))
        self.assertEqual(self.source.read_bytes(), before)

    def test_source_justification_only_affects_one_location(self):
        code = ('int main(void) {\n    int BadName = 0;\n    int OtherName = 0;\n'
                '    return BadName + OtherName;\n}\n')
        status, _ = self.run_review(code, ['j external identifier contract\n', 'd\n'])
        self.assertEqual(status, 1, self.output.getvalue())
        result = engine.school_analyze(dict(protected=[str(self.source)], format_mode='school'))
        remaining = [item for item in result.findings if item.rule == '3.4']
        self.assertEqual(len(remaining), 1, result.findings)
        self.assertIn('OtherName', remaining[0].message)
