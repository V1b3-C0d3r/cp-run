"""Compilation gate checks actual formatting without writing or consuming stdin."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest
import test_school_format as fixtures

engine = fixtures.engine


@unittest.skipUnless(shutil.which('clang-format') and shutil.which('clang'), 'needs formatters')
class StrictFormatTest(unittest.TestCase):
    def setUp(self):
        self.case = fixtures.SchoolFormatTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)
        self.script = fixtures.RELEASE / 'cp-run.zsh'
        self.source = self.case.source
        self.target = self.case.root / 'program.out'

    def compile(self, *flags, script=None):
        return subprocess.run([str(script or self.script), 'compile', str(self.source),
                               '-o', str(self.target), *flags], cwd=self.case.root,
                              env=self.case.env, capture_output=True, text=True, timeout=30)

    def test_bad_layout_preserves_source_and_previous_binary(self):
        self.source.write_text('int main(){return 0;}')
        self.target.write_bytes(b'previous binary')
        result = self.compile('--strict-format=school')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('formatting differs', result.stderr)
        self.assertEqual(self.source.read_text(), 'int main(){return 0;}')
        self.assertEqual(self.target.read_bytes(), b'previous binary')

    def test_clean_style_with_review_warning_compiles(self):
        self.source.write_text('int state;\nint\nmain(void) {\n    return 0;\n}\n')
        result = self.compile('--strict-format=school')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('review>', result.stderr)
        self.assertTrue(self.target.is_file())

    def test_justified_style_error_can_compile_and_comment_does_not_waive_it(self):
        self.source.write_text('int\nmain(void) {\n    /* school-error-justified 3.4 */\n    int BadName = 0;\n    return BadName;\n}\n')
        result = self.compile('--strict-format=school')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.source.write_text(self.source.read_text().replace('school-error-justified', 'school-error-comment'))
        result = self.compile('--strict-format=school')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('3.4 error', result.stderr)

    def test_default_clang_and_personal_mode_override(self):
        self.source.write_text('int main(void) { return 0; }\n')
        self.case.invoke('--clang', self.source)
        self.assertEqual(self.compile('--strict-format').returncode, 0)
        script = self.case.root / 'personal-cp-run'
        shutil.copy2(self.script, script)
        original = script.read_text()
        data = engine.read_settings(original)
        data['FORMAT_MODE'] = 'school'
        engine.save_settings(script, original, data)
        self.assertEqual(self.compile('--strict-format', script=script).returncode, 1)
        self.case.invoke('--school', self.source)
        result = self.compile('--strict-format', script=script)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_gate_report_cannot_replace_binary_or_source(self):
        self.source.write_text('int main(void) { return 0; }\n')
        before = self.source.read_bytes()
        for target in (self.source, self.target):
            result = self.compile('--strict-format=school', '--report=' + str(target), '--overwrite')
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertIn('collides', result.stderr)
            self.assertEqual(self.source.read_bytes(), before)

    def test_report_exports_errors_without_showing_warnings(self):
        self.source.write_text('int state;\nint main(){int BadName=0;return BadName;}\n')
        report = self.case.root / 'report.json'
        result = self.compile('--strict-format=school', '--report=' + str(report))
        self.assertEqual(result.returncode, 1, result.stderr)
        data = json.loads(report.read_text())
        self.assertTrue(data['findings'])
        self.assertTrue(all(item['severity'] == 'error' for item in data['findings']))
        self.assertNotIn('mutable global', result.stderr)

    def test_binary_only_cannot_request_source_check(self):
        binary = self.case.root / 'binary'
        binary.write_text('#!/bin/sh\nexit 0\n')
        binary.chmod(0o755)
        result = subprocess.run([str(self.script), 'run', str(binary), '--strict-format'],
            cwd=self.case.root, env=self.case.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn('source files', result.stderr)

    def test_compilation_remains_unchecked_without_flag(self):
        self.source.write_text('int main(){return 2;}')
        result = self.compile()
        self.assertEqual(result.returncode, 0, result.stderr)
