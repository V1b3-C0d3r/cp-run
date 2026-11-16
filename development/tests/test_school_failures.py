"""Failure paths keep original input safe and report partial publication honestly."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock
import test_school_format as cli_cases

engine = cli_cases.engine


class SchoolFailureTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='school-failure-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def test_missing_tools_fail_before_source_is_read(self):
        with mock.patch.object(engine.shutil, 'which', return_value=None):
            with self.assertRaisesRegex(engine.CheckSetupError, 'needs clang-format'):
                engine.execute_school_format({'protected': ['/missing/main.c']})

    def test_tool_timeout_is_actionable(self):
        with mock.patch.object(engine.subprocess, 'run', side_effect=subprocess.TimeoutExpired('clang', 60)):
            with self.assertRaisesRegex(engine.CheckSetupError, 'tool timed out: clang'):
                engine.school_tool(['clang'])

    def test_malformed_or_unexpected_ast_is_not_accepted(self):
        for output in ('not json', '[]', '{"kind":"FunctionDecl"}'):
            with self.subTest(output=output):
                result = subprocess.CompletedProcess(['clang'], 0, output, '')
                with mock.patch.object(engine, 'school_tool', return_value=result):
                    with self.assertRaises(engine.CheckSetupError):
                        engine.school_parse(self.root / 'main.c', 'int main(void){return 0;}', 'clang')

    def test_concurrent_change_preflights_every_source(self):
        first, second = self.root / 'first.c', self.root / 'second.c'
        first.write_bytes(b'first')
        second.write_bytes(b'user edit')
        jobs = [(first, b'first', b'formatted first'), (second, b'second', b'formatted second')]
        with self.assertRaisesRegex(engine.CheckSetupError, 'source changed'):
            engine.school_publish(jobs)
        self.assertEqual(first.read_bytes(), b'first')
        self.assertEqual(second.read_bytes(), b'user edit')

    def test_replaced_source_with_identical_bytes_is_not_overwritten(self):
        source = self.root / 'main.c'
        source.write_bytes(b'original')
        stat = source.stat()
        replacement = self.root / 'replacement'
        replacement.write_bytes(b'original')
        replacement.replace(source)
        with self.assertRaisesRegex(engine.CheckSetupError, 'source was replaced'):
            engine.school_publish([(source, b'original', b'formatted')],
                                  {source: (stat.st_dev, stat.st_ino)})
        self.assertEqual(source.read_bytes(), b'original')

    def test_permission_failure_preserves_original_and_cleans_staging(self):
        source = self.root / 'main.c'
        source.write_bytes(b'original')
        with mock.patch.object(engine.os, 'replace', side_effect=PermissionError('denied')):
            with self.assertRaisesRegex(engine.CheckSetupError, 'No files were published'):
                engine.school_publish([(source, b'original', b'formatted')])
        self.assertEqual(source.read_bytes(), b'original')
        self.assertFalse(list(self.root.glob('.cp-format-*')))

    def test_later_publication_failure_reports_completed_files(self):
        first, second = self.root / 'first.c', self.root / 'second.c'
        first.write_bytes(b'first')
        second.write_bytes(b'second')
        replace = os.replace

        def fail_second(temporary, target):
            if target == second:
                raise PermissionError('second file denied')
            return replace(temporary, target)

        with mock.patch.object(engine.os, 'replace', side_effect=fail_second):
            with self.assertRaisesRegex(engine.CheckSetupError, 'Already formatted:.*first.c'):
                engine.school_publish([(first, b'first', b'new first'), (second, b'second', b'new second')])
        self.assertEqual(first.read_bytes(), b'new first')
        self.assertEqual(second.read_bytes(), b'second')
        self.assertFalse(list(self.root.glob('.cp-format-*')))

    def test_permissions_are_preserved(self):
        source = self.root / 'main.c'
        source.write_bytes(b'original')
        source.chmod(0o640)
        engine.school_publish([(source, b'original', b'formatted')])
        self.assertEqual(source.stat().st_mode & 0o777, 0o640)


@unittest.skipUnless(shutil.which('clang') and shutil.which('clang-format'), 'needs school tools')
class SchoolInputFailureTest(unittest.TestCase):
    def setUp(self):
        self.case = cli_cases.SchoolFormatTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)

    def test_invalid_utf8_is_reported_and_preserved(self):
        original = b'int main(void) { return 0; }\n// \xff'
        self.case.source.write_bytes(original)
        result = self.case.invoke('--school', self.case.source)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('UTF-8', result.stderr)
        self.assertEqual(self.case.source.read_bytes(), original)

    def test_symlink_remains_a_symlink(self):
        target = self.case.root / 'actual.c'
        target.write_text('int main(){return 0;}\n')
        self.case.source.symlink_to(target)
        result = self.case.invoke('--school', self.case.source)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.case.source.is_symlink())
        self.assertIn('main(void)', target.read_text())
