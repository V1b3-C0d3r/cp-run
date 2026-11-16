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

    def test_G01(self):
        result = self.compile('#ifndef __OPTIMIZE__\n#error optimization missing\n#endif\nint main(void) { return 0; }')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_G03(self):
        code = 'int main(void) { int unused; return 0; }'
        error = self.compile(code)
        warning = self.compile(code, flags=[flag for flag in engine.SCHOOL_C_FLAGS if flag != '-Werror'])
        self.assertNotEqual(error.returncode, 0, error.stderr)
        self.assertEqual(warning.returncode, 0, warning.stderr)
        self.assertIn('warning:', warning.stderr)

    def test_G21(self):
        result = self.compile('#if __STDC_VERSION__ != 199901L\n#error wrong C standard\n#endif\n'
            'int main(void) { __typeof__(0) value = 0; __asm__ volatile(""); return value; }')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_G22(self):
        code = ('#include <math.h>\n#include <stdio.h>\n'
                'int main(int argc, char **argv) { (void)argv; '
                'volatile double first = argc, second = 1; '
                'double (*operation)(double, double) = hypot; '
                'printf("%f\\n", operation(first, second)); return 0; }')
        result = self.compile(code)
        self.assertEqual(result.returncode, 0, result.stderr)
        if sys.platform.startswith('linux'):
            probe = self.compile(code, flags=[flag for flag in engine.SCHOOL_C_FLAGS if flag != '-lm'])
            self.assertNotEqual(probe.returncode, 0, probe.stderr)

    def test_G23(self):
        self.assertEqual(engine.SCHOOL_C_FLAGS, EXPECTED_C)
        self.assertEqual(engine.SCHOOL_C_FLAGS[-2:], ['-lm', '-lm'])
        self.assertEqual(engine.SCHOOL_C_FLAGS.count('-lm'), 2)

    def test_reference_GNU_11_3_0_when_required(self):
        required = os.environ.get('SCHOOL_REFERENCE_VERSION')
        if not required:
            self.skipTest('reference version is exercised by the dedicated CI job')
        self.assertRegex(self.banner.splitlines()[0], r'\b' + re.escape(required) + r'\b')

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



WARNING_CASES = {
    'G02': ('unused-variable',
        'int main(void) { int unused; return 0; }',
        'int main(void) { int value = 0; return value; }'),
    'G04': ('format-security',
        '#include <stdio.h>\nint main(int argc, char **argv) { printf(argv[argc - 1]); return 0; }',
        '#include <stdio.h>\nint main(int argc, char **argv) { printf("%s", argv[argc - 1]); return 0; }'),
    'G05': ('ignored-qualifiers',
        'const int value(void) { return 0; } int main(void) { return value(); }',
        'const int *value(void) { return 0; } int main(void) { return value() != 0; }'),
    'G06': ('uninitialized',
        'int value(void) { int number = number; return number; } int main(void) { return value(); }',
        'int value(void) { int number = 0; return number; } int main(void) { return value(); }'),
    'G07': ('switch-default',
        'int value(int number) { switch (number) { case 0: return 0; } return 1; } int main(void) { return value(0); }',
        'int value(int number) { switch (number) { case 0: return 0; default: return 1; } } int main(void) { return value(0); }'),
    'G08': ('float-equal',
        'int main(void) { volatile double left = 0, right = 1; return left == right; }',
        'int main(void) { volatile int left = 0, right = 1; return left == right; }'),
    'G09': ('pointer-arith',
        'int main(void) { void *ptr = 0; ++ptr; return ptr != 0; }',
        'int main(void) { char values[2] = {0}; char *ptr = values; ++ptr; return ptr != 0; }'),
    'G10': ('type-limits',
        'int value(unsigned int number) { return number < 0; } int main(void) { return value(0); }',
        'int value(unsigned int number) { return number < 1; } int main(void) { return value(0); }'),
    'G11': ('empty-body',
        'int main(void) { int value = 0; if (value); return 0; }',
        'int main(void) { int value = 0; if (value) {} return 0; }'),
    'G13': ('strict-prototypes',
        'int value(); int value(void) { return 0; } int main(void) { return value(); }',
        'int value(void); int value(void) { return 0; } int main(void) { return value(); }'),
    'G14': ('old-style-declaration',
        'int static value = 0; int main(void) { return value; }',
        'static int value = 0; int main(void) { return value; }'),
    'G15': ('old-style-definition',
        'int value(int); int value(number) int number; { return number; } int main(void) { return value(0); }',
        'int value(int); int value(int number) { return number; } int main(void) { return value(0); }'),
    'G16': ('(?:missing-parameter-type|implicit-int)',
        'int value(number) { return number; } int main(void) { return value(0); }',
        'int value(int number) { return number; } int main(void) { return value(0); }'),
    'G17': ('missing-field-initializers',
        'struct Pair { int first, second; }; struct Pair value = {1}; int main(void) { return value.first; }',
        'struct Pair { int first, second; }; struct Pair value = {1, 0}; int main(void) { return value.first; }'),
    'G18': ('nested-externs',
        'int value = 0; int main(void) { extern int value; return value; }',
        'int value = 0; int main(void) { return value; }'),
}
DISABLED_CASES = {
    'G12': ('int value(int number) { return number && number; } int main(void) { return value(0); }', '-Wlogical-op'),
    'G19': ('int value(const char *text) { return text[0]; } int main(void) { unsigned char text[1] = {0}; return value(text); }', '-Wpointer-sign'),
    'G20': ('__attribute__((warn_unused_result)) int value(void) { return 0; } int main(void) { value(); return 0; }', '-Wunused-result'),
}


def warning_contract(diagnostic, bad, good):
    def test(self):
        negative = self.compile(bad)
        self.assertNotEqual(negative.returncode, 0, negative.stderr)
        self.assertRegex(negative.stderr, diagnostic)
        positive = self.compile(good)
        self.assertEqual(positive.returncode, 0, positive.stderr)
    return test


def disabled_warning_contract(code, enabled):
    def test(self):
        accepted = self.compile(code)
        self.assertEqual(accepted.returncode, 0, accepted.stderr)
        rejected = self.compile(code, (enabled,))
        self.assertNotEqual(rejected.returncode, 0, rejected.stderr)
    return test


for _identifier, _case in WARNING_CASES.items():
    setattr(SchoolCompilerTest, 'test_' + _identifier, warning_contract(*_case))
for _identifier, _case in DISABLED_CASES.items():
    setattr(SchoolCompilerTest, 'test_' + _identifier, disabled_warning_contract(*_case))


class SchoolFlagInventoryTest(unittest.TestCase):
    def test_each_flag_occurrence_has_an_individual_behavioral_test(self):
        methods = unittest.defaultTestLoader.getTestCaseNames(SchoolCompilerTest)
        actual = {name for name in methods if re.fullmatch(r'test_G\d\d', name)}
        self.assertEqual(actual, {'test_G%02d' % number for number in range(1, 24)})
