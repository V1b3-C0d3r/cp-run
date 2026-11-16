"""Real-tool tests of format command, school checks and source preservation."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from _paths import RELEASE, load_engine

engine = load_engine('cp_school_tests')


@unittest.skipUnless(shutil.which('clang-format') and shutil.which('clang'), 'needs clang-format and clang')
class SchoolFormatTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='school-format-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'main.c'
        self.env = dict(os.environ)
        gcc = os.environ.get('CP_RUN_GCC') or shutil.which('gcc-16') or shutil.which('gcc')
        if not gcc or 'clang' in subprocess.check_output([gcc, '--version'], text=True).lower():
            self.skipTest('needs GNU GCC')
        self.env['CP_RUN_GCC'] = gcc

    def invoke(self, *args):
        return subprocess.run([str(RELEASE / 'cp-run.zsh'), 'format', *args],
            cwd=self.root, env=self.env, text=True, capture_output=True, timeout=30)

    def test_explicit_mode_before_file_and_idempotence(self):
        self.source.write_text('int main(){return 0;}\n')
        formatted = self.invoke('--school', self.source)
        self.assertEqual(formatted.returncode, 0, formatted.stderr)
        self.assertEqual(self.source.read_text(), 'int\nmain(void) {\n    return 0;\n}\n')
        before = self.source.read_bytes()
        checked = self.invoke(self.source, '--school', '--check')
        self.assertEqual(checked.returncode, 0, checked.stderr)
        self.assertEqual(self.source.read_bytes(), before)
        self.assertFalse((self.root / 'main.out').exists())

    def test_check_never_writes_and_policy_errors_allow_safe_layout(self):
        self.source.write_text('int main(){return 0;}\n')
        before = self.source.read_bytes()
        self.assertEqual(self.invoke('--school', '--check', self.source).returncode, 1)
        self.assertEqual(self.source.read_bytes(), before)
        self.source.write_text('int main(void) { return 37; }\n')
        before = self.source.read_bytes()
        result = self.invoke('--school', self.source)
        self.assertEqual(result.returncode, 1)
        self.assertIn('5.1', result.stderr)
        self.assertIn('named constant', result.stderr)
        self.assertNotEqual(self.source.read_bytes(), before)
        self.assertIn('return 37;', self.source.read_text())

    def test_compiler_warnings_are_errors(self):
        self.source.write_text('int main(void) { int unused; return 0; }\n')
        before = self.source.read_bytes()
        result = self.invoke('--school', self.source)
        self.assertEqual(result.returncode, 1)
        self.assertIn('unused', result.stderr)
        self.assertNotEqual(self.source.read_bytes(), before)
        self.assertIn('int unused;', self.source.read_text())

    def test_unsafe_call_and_identifier_diagnostics(self):
        self.source.write_text('char *strcpy(char *, const char *);\n'
            'int main(void) { char *BadName = 0; strcpy(BadName, ""); return 0; }\n')
        result = self.invoke('--school', self.source)
        self.assertEqual(result.returncode, 1)
        self.assertIn('3.4', result.stderr)
        self.assertIn('5.8', result.stderr)

    def test_clang_mode_and_school_rejects_python(self):
        self.source.write_text('int main(){return 0;}\n')
        self.assertEqual(self.invoke('--clang', self.source).returncode, 0)
        python = self.root / 'main.py'
        python.write_text('print("not executed")')
        result = self.invoke('--school', python)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('C and C++', result.stderr)

    def test_saved_default_and_explicit_override(self):
        script = self.root / 'configured'
        shutil.copy2(RELEASE / 'cp-run.zsh', script)
        original = script.read_text()
        data = engine.read_settings(original)
        self.assertEqual(data['FORMAT_MODE'], 'clang')
        data['FORMAT_MODE'] = 'school'
        engine.save_settings(script, original, data)
        self.source.write_text('int main(){return 0;}\n')
        result = subprocess.run([str(script), 'format', str(self.source)],
            env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('main(void)', self.source.read_text())
        result = subprocess.run([str(script), 'format', '--clang', str(self.source)],
            env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_numeric_define_inside_comment_is_not_code(self):
        self.source.write_text('/*\n#define SIZE 42\n*/\nint main(void) { return 0; }\n')
        result = self.invoke('--school', self.source)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_flag_policy_keeps_duplicate_math_libraries(self):
        self.assertEqual(engine.SCHOOL_C_FLAGS.count('-lm'), 2)
        self.assertIn('-std=gnu99', engine.SCHOOL_C_FLAGS)
        self.assertIn('-Werror', engine.SCHOOL_C_FLAGS)

    def test_resource_analyzer_finds_leak_despite_author_review(self):
        code = ('#include <stdlib.h>\n'
                '// school-reviewed 3.2, 3.5: buffer is an English name without a type prefix.\n'
                '// school-reviewed 5.17: This assertion must not hide an actual leak.\n'
                'int main(void) { char *buffer = calloc(1, sizeof(*buffer)); '
                'if (!buffer) { return 1; } buffer[0] = 0; return buffer[0]; }\n')
        self.source.write_text(code)
        result = self.invoke('--school', self.source)
        self.assertEqual(result.returncode, 1)
        self.assertIn('5.17 error', result.stderr)
        self.assertIn('leak', result.stderr.lower())
        self.assertNotEqual(self.source.read_text(), code)
        self.assertNotIn('free(buffer)', self.source.read_text())

    def test_empty_pragma_once_header_compiles_as_an_include(self):
        source = self.root / 'empty.h'
        source.write_text('#pragma once\n')
        result = self.invoke('--school', source, '--check')
        self.assertEqual(result.returncode, 0, result.stderr)


    def test_multimodule_main_compiles_unit_and_audits_makefile_without_running_it(self):
        (self.root / 'module.h').write_text('#pragma once\nvoid run(void);\n')
        (self.root / 'module.c').write_text('#include "module.h"\nvoid run(void) { return; }\n')
        self.source.write_text('#include "module.h"\nint main(void) { run(); return 0; }\n')
        result = self.invoke('--school', self.source)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('6.6 error', result.stderr)
        self.assertNotIn('undefined reference', result.stderr)
        (self.root / 'Makefile').write_text('all:\n\ttouch must-not-exist\nclean:\n\trm -f must-not-exist\n')
        reviews = ('// school-reviewed 6.4: all consumers of run include module.h directly.\n'
                   '// school-reviewed 6.6: the recipes are explicit author assertions, never executed by the formatter.\n')
        self.source.write_text(reviews + self.source.read_text())
        checked = self.invoke('--school', self.source, '--check')
        self.assertEqual(checked.returncode, 0, checked.stderr)
        self.assertFalse((self.root / 'must-not-exist').exists())
