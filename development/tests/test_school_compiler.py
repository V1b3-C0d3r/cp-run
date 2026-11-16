"""Real-GCC contracts for every flag in the supplied school command."""
import json
import os
import re
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest
from _paths import RELEASE, load_engine

engine = load_engine('school_compiler_contracts')
EXPECTED_C = shlex.split(
    '-O2 -Wall -Werror -Wformat-security -Wignored-qualifiers -Winit-self '
    '-Wswitch-default -Wfloat-equal -Wpointer-arith -Wtype-limits -Wempty-body '
    '-Wno-logical-op -Wstrict-prototypes -Wold-style-declaration -Wold-style-definition '
    '-Wmissing-parameter-type -Wmissing-field-initializers -Wnested-externs '
    '-Wno-pointer-sign -Wno-unused-result -std=gnu99 -lm -lm')


class SchoolCompilerTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='school-compiler-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.gcc = os.environ.get('CP_RUN_GCC') or shutil.which('gcc-16') or shutil.which('gcc')
        if not self.gcc:
            self.skipTest('needs GNU GCC')
        self.banner = subprocess.check_output([self.gcc, '--version'], text=True)
        if 'clang' in self.banner.lower():
            self.skipTest('needs GNU GCC')
        self.source = self.root / 'main.c'

    def compile(self, code, extra=(), flags=None):
        self.source.write_text(code)
        return subprocess.run([self.gcc, '-x', 'c', str(self.source),
            *(engine.SCHOOL_C_FLAGS if flags is None else flags), *extra,
            '-o', str(self.root / 'verified.out')], text=True, capture_output=True, timeout=45)

    def test_G01_G21_optimization_language_and_G23_order(self):
        self.assertEqual(engine.SCHOOL_C_FLAGS, EXPECTED_C)
        code = ('#ifndef __OPTIMIZE__\n#error optimization missing\n#endif\n'
                '#if __STDC_VERSION__ != 199901L\n#error wrong C standard\n#endif\n'
                'int main(void) { __typeof__(0) value = 0; __asm__ volatile(""); return value; }\n')
        result = self.compile(code)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(engine.SCHOOL_C_FLAGS[-2:], ['-lm', '-lm'])

    def test_reference_GNU_11_3_0_when_required(self):
        required = os.environ.get('SCHOOL_REFERENCE_VERSION')
        if not required:
            self.skipTest('reference version is exercised by the dedicated CI job')
        self.assertRegex(self.banner.splitlines()[0], r'\b' + re.escape(required) + r'\b')

    def test_warning_flags_G02_G11_G13_G18(self):
        cases = [
            ('G02/G03', 'int main(void) { int unused; return 0; }'),
            ('G04', '#include <stdio.h>\nint main(int argc, char **argv) { printf(argv[argc - 1]); return 0; }'),
            ('G05', 'const int value(void) { return 0; } int main(void) { return value(); }'),
            ('G06', 'int value(void) { int number = number; return number; } int main(void) { return value(); }'),
            ('G07', 'int value(int number) { switch (number) { case 0: return 0; } return 1; } int main(void) { return value(0); }'),
            ('G08', 'int main(void) { volatile double left = 0, right = 1; return left == right; }'),
            ('G09', 'int main(void) { void *ptr = 0; ++ptr; return ptr != 0; }'),
            ('G10', 'int value(unsigned int number) { return number < 0; } int main(void) { return value(0); }'),
            ('G11', 'int main(void) { int value = 0; if (value); return 0; }'),
            ('G13', 'int value(); int value(void) { return 0; } int main(void) { return value(); }'),
            ('G14', 'int static value = 0; int main(void) { return value; }'),
            ('G15', 'int value(int); int value(number) int number; { return number; } int main(void) { return value(0); }'),
            ('G16', 'int value(number) { return number; } int main(void) { return value(0); }'),
            ('G17', 'struct Pair { int first, second; }; struct Pair value = {1}; int main(void) { return value.first; }'),
            ('G18', 'int value = 0; int main(void) { extern int value; return value; }'),
        ]
        for identifier, code in cases:
            with self.subTest(flag=identifier):
                result = self.compile(code)
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertIn('error:', result.stderr)

    def test_G12_G19_G20_disabled_warnings_are_actual_exceptions(self):
        cases = [
            ('G12', 'int value(int number) { return number && number; } int main(void) { return value(0); }', '-Wlogical-op'),
            ('G19', 'int value(const char *text) { return text[0]; } int main(void) { unsigned char text[1] = {0}; return value(text); }', '-Wpointer-sign'),
            ('G20', '__attribute__((warn_unused_result)) int value(void) { return 0; } int main(void) { value(); return 0; }', '-Wunused-result'),
        ]
        for identifier, code, enabled in cases:
            with self.subTest(flag=identifier):
                result = self.compile(code)
                self.assertEqual(result.returncode, 0, result.stderr)
                probe = self.compile(code, (enabled,))
                self.assertNotEqual(probe.returncode, 0, probe.stderr)

    def test_G22_math_link_and_complete_positive_program(self):
        code = ('#include <math.h>\n#include <stdio.h>\n'
                'int main(int argc, char **argv) { (void)argv; '
                'volatile double first = argc, second = 1; '
                'double (*operation)(double, double) = hypot; '
                'printf("%f\\n", operation(first, second)); return 0; }\n')
        result = self.compile(code)
        self.assertEqual(result.returncode, 0, result.stderr)
        if sys.platform.startswith('linux'):
            probe = self.compile(code, flags=[flag for flag in engine.SCHOOL_C_FLAGS if flag != '-lm'])
            self.assertNotEqual(probe.returncode, 0, probe.stderr)

    @unittest.skipUnless(shutil.which('clang-format') and shutil.which('clang'), 'needs school frontend tools')
    def test_P_school_sync_real_profile_and_verifier_arguments(self):
        log = self.root / 'compiler.jsonl'
        wrapper = self.root / 'school-gcc'
        wrapper.write_text('#!' + sys.executable + '\nimport json,os,sys\n'
            'with open(' + repr(str(log)) + ', "a") as stream: stream.write(json.dumps(sys.argv[1:])+"\\n")\n'
            'os.execv(' + repr(self.gcc) + ', [' + repr(self.gcc) + ', *sys.argv[1:]])\n')
        wrapper.chmod(0o755)
        script = self.root / 'cp-run'
        shutil.copy2(RELEASE / 'cp-run.zsh', script)
        original = script.read_text()
        data = engine.read_settings(original)
        data.update(DEFAULT_COMPILER='clang++', DEFAULT_FLAGS=['-O0'], WARNINGS_GCC=['-Wconversion'])
        engine.save_settings(script, original, data)
        env = dict(os.environ, CC=str(wrapper), CXX=str(wrapper), CP_RUN_GCC=str(wrapper),
                   XDG_STATE_HOME=str(self.root / 'state'))
        for language, extension, expected in (
            ('c', '.c', engine.SCHOOL_C_FLAGS), ('c++', '.cpp', engine.SCHOOL_CPP_FLAGS)):
            with self.subTest(language=language):
                self.source = self.root / ('main' + extension)
                self.source.write_text('int\nmain(void) {\n    return 0;\n}\n')
                before = len(log.read_text().splitlines()) if log.exists() else 0
                build = subprocess.run([str(script), 'compile', str(self.source), '--profile=school',
                    '-o', str(self.root / 'program.out')], env=env, text=True, capture_output=True)
                self.assertEqual(build.returncode, 0, build.stderr)
                verify = subprocess.run([str(script), 'format', '--school', str(self.source), '--check'],
                    env=env, text=True, capture_output=True)
                self.assertEqual(verify.returncode, 0, verify.stderr)
                calls = [json.loads(line) for line in log.read_text().splitlines()[before:]]
                compilations = [argv for argv in calls if '-o' in argv and '-O2' in argv]
                self.assertEqual(len(compilations), 2, compilations)
                for argv in compilations:
                    start = argv.index('-O2')
                    self.assertEqual(argv[start:start + len(expected)], expected)
                    self.assertNotIn('-O0', argv)
                    self.assertNotIn('-Wconversion', argv)

