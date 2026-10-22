"""Optimization profiles: transparent flags, adaptive CPU selection and real code."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from _paths import RELEASE
import test_cli as cli
import test_toolchains as toolchains


SCRIPT = RELEASE / 'cp-run.zsh'
EXAMPLES = RELEASE / ('Examples' if (RELEASE / 'Examples').is_dir() else 'examples')
PROFILES = ('pragma', 'pragma-fast', 'pragma-native')
NAN = r'''#include <cmath>
#include <cstdio>
#include <cstdlib>
int main(int argc, char** argv) {
    if (argc != 2) return 2;
    std::printf("%d\n", static_cast<int>(std::isnan(std::strtod(argv[1], nullptr))));
}
'''
LEVELS = r'''#include <cstdio>
int main() {
#ifdef __OPTIMIZE__
    std::puts("optimized");
#else
    std::puts("unoptimized");
#endif
}
'''


class PragmaCliTest(unittest.TestCase):
    # Reuse the recording fixture helpers without inheriting its test methods.
    setUp = cli.CliTest.setUp
    tearDown = cli.CliTest.tearDown
    environment = cli.CliTest.environment
    calls = cli.CliTest.calls
    output_arg = cli.CliTest.output_arg
    invoke = cli.CliTest.invoke
    build = cli.CliTest.build
    rejected = cli.CliTest.rejected

    def cpu_probes(self):
        return [args for args in self.calls(True) if '-S' in args and '-Werror' in args
                and '/dev/null' in args]

    def test_portable_profile_preserves_fp_and_uses_no_native_or_library_probe(self):
        _, args = self.build('--profile=pragma')
        self.assertIn('-O3', args)
        self.assertIn('-funroll-loops', args)
        self.assertNotIn('-ffast-math', args)
        self.assertNotIn('-fno-stack-protector', args)
        self.assertNotIn(['-dumpmachine'], self.calls(True))
        self.assertFalse(any('-dM' in words for words in self.calls(True)))

    def test_aggressive_driver_flags_match_each_compiler(self):
        for family in ('GCC', 'clang'):
            with self.subTest(family=family):
                _, args = self.build('--profile=pragma-fast', '--compiler=' + family,
                                     env={'FAKE_COMPILER_FAMILY': family})
                for option in ('-funroll-loops', '-ffast-math', '-fno-stack-protector'):
                    self.assertIn(option, args)
                self.assertIn('-Ofast' if family == 'GCC' else '-O3', args)
                if family == 'clang':
                    self.assertNotIn('-Ofast', args)
        self.assertNotIn(['-dumpmachine'], self.calls(True))
        self.assertFalse(any('-dM' in words for words in self.calls(True)))

    def test_native_cpu_switch_follows_the_actual_compiler_target(self):
        for target, expected in (('x86_64-pc-linux-gnu', '-march=native'),
                                 ('i686-linux-gnu', '-march=native'),
                                 ('aarch64-apple-darwin25', '-mcpu=native'),
                                 ('arm64-apple-darwin25', '-mcpu=native'),
                                 ('arm-linux-gnueabihf', '-mcpu=native'),
                                 ('powerpc64le-linux-gnu', '-mcpu=native')):
            with self.subTest(target=target):
                _, args = self.build('--profile=pragma-native', env={'FAKE_TARGET': target})
                self.assertIn(expected, args)
                self.assertFalse(any('-dM' in words for words in self.calls(True)))
        self.assertEqual(len(self.cpu_probes()), 6)

    def test_unrecognized_target_keeps_working_generic_optimization(self):
        _, args = self.build('--profile=pragma-native', env={'FAKE_TARGET': 'riscv64-linux-gnu'})
        self.assertIn('-Ofast', args)
        self.assertFalse(any(word in ('-march=native', '-mcpu=native') for word in args))
        self.assertEqual(self.cpu_probes(), [])

    def test_unsupported_native_cpu_falls_back_without_leaking_probe_streams(self):
        result, args = self.build('--profile=pragma-native', env={
            'FAKE_NATIVE_UNSUPPORTED': '1', 'FAKE_NATIVE_STDOUT': 'private probe output\n',
            'FAKE_NATIVE_STDERR': 'private unsupported native diagnostic\n'})
        self.assertNotIn('-mcpu=native', args)
        self.assertEqual(result.stderr, '')
        self.assertNotIn('private probe output\n', result.stdout)
        self.assertEqual(result.stdout, str(self.cwd / 'main file.out') + '\n')
        self.assertEqual(len(self.cpu_probes()), 1)

    def test_failed_target_query_is_an_optimization_fallback(self):
        result, args = self.build('--profile=pragma-native', env={
            'FAKE_TARGET_STATUS': '1', 'FAKE_TARGET_STDERR': 'private target diagnostic\n'})
        self.assertNotIn('-mcpu=native', args)
        self.assertEqual(result.stderr, '')
        self.assertEqual(self.cpu_probes(), [])

    def test_explicit_target_and_isa_choices_disable_automatic_native_selection(self):
        choices = (('-march=x86-64',), ('-mcpu=cortex-a53',), ('-mtune=generic',),
                   ('-mavx2',), ('-mno-avx2',), ('-m32',),
                   ('-target', 'x86_64-unknown-linux-gnu'), ('-arch', 'x86_64'))
        for choices_in_tail in (False, True):
            for values in choices:
                with self.subTest(tail=choices_in_tail, values=values):
                    self.log.unlink(missing_ok=True)
                    _, args = self.build('--profile=pragma-native',
                                         *(('--',) if choices_in_tail else ()), *values)
                    self.assertFalse(any(word in ('-march=native', '-mcpu=native') for word in args))
                    self.assertNotIn(['-dumpmachine'], self.calls(True))
                    for value in values:
                        self.assertIn(value, args)

    def test_known_option_operand_resembling_a_target_is_not_reinterpreted(self):
        _, args = self.build('--profile=pragma-native', '-I', '-march=directory')
        self.assertIn('-mcpu=native', args)
        self.assertEqual(args[args.index('-I') + 1], '-march=directory')

    def test_opaque_compiler_forwarding_retains_user_control_without_native_additions(self):
        for values in (('@opaque.rsp',), ('-Xclang', '-target-cpu'), ('-Wl,--as-needed',)):
            with self.subTest(values=values):
                self.log.unlink(missing_ok=True)
                _, args = self.build('--profile=pragma-native', '--', *values)
                self.assertFalse(any(word in ('-march=native', '-mcpu=native') for word in args))
                self.assertNotIn(['-dumpmachine'], self.calls(True))
                for value in values:
                    self.assertIn(value, args)

    def test_plain_profiles_preserve_explicit_optimization_and_fp_overrides(self):
        _, args = self.build('--profile=pragma-fast', '--', '-O0', '-fno-fast-math')
        self.assertLess(args.index('-Ofast'), args.index('-O0'))
        self.assertLess(args.index('-ffast-math'), args.index('-fno-fast-math'))

    def test_optimization_profiles_are_not_debug_profiles(self):
        for name in PROFILES:
            result = self.rejected('debug=' + name, self.source.name)
            self.assertIn('--profile=' + name, result.stderr)

    def test_actual_compiler_failure_is_not_replaced_by_capability_probe_errors(self):
        result = self.invoke('compile', self.source.name, '--profile=pragma-native', env={
            'FAKE_NATIVE_UNSUPPORTED': '1', 'FAKE_NATIVE_STDERR': 'hidden native probe\n',
            'FAKE_GCC_STATUS': '7', 'FAKE_GCC_STDERR': 'real compiler error\n'})
        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stderr, 'real compiler error\n')
        self.assertEqual(result.stdout, '')


class _RealPragmaCase(unittest.TestCase):
    FAMILY = None

    @classmethod
    def setUpClass(cls):
        cls.driver = toolchains._driver(cls.FAMILY)
        if cls.driver is None:
            raise unittest.SkipTest('real ' + cls.FAMILY + ' C++ driver not installed')

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cp-run-pragma-real-')
        self.cwd = Path(self.temporary.name)
        self.env = dict(os.environ, CXX=self.driver)
        for name in ('main.cpp', 'nan.cpp', 'gcc-pragmas.hpp'):
            shutil.copy2(EXAMPLES / 'optimization' / name, self.cwd / name)

    def tearDown(self):
        self.temporary.cleanup()

    def run_source(self, profile, compiler=(), runtime=(), source='main.cpp'):
        return subprocess.run([str(SCRIPT), source, '--compiler=' + self.FAMILY,
                               '--profile=' + profile, '--', *compiler, '--', *runtime],
                              cwd=self.cwd, env=self.env, capture_output=True,
                              text=True, timeout=30)

    def check_profiles_run_integer_workload_with_warnings_as_errors(self):
        for name in PROFILES:
            with self.subTest(profile=name):
                result = self.run_source(name, compiler=('-Werror',))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, 'checksum=4128010\n')
                self.assertNotIn('unknown pragma', result.stderr)

    def check_unknown_pragmas_are_diagnosed_in_every_profile(self):
        (self.cwd / 'unknown.cpp').write_text('#pragma cp_run_unknown_directive\nint main(){return 0;}\n')
        for profile in PROFILES:
            result = self.run_source(profile, source='unknown.cpp')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('unknown pragma', result.stderr.lower())
            self.assertIn('-Wunknown-pragmas', result.stderr)

    def check_fast_math_has_explicit_observable_semantics(self):
        (self.cwd / 'nan.cpp').write_text(NAN)
        for name, expected in (('pragma', '1\n'), ('pragma-fast', '0\n'), ('pragma-native', '0\n')):
            with self.subTest(profile=name):
                result = self.run_source(name, source='nan.cpp', runtime=('nan',))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, expected)

    def check_nan_warning_remains_a_compiler_decision(self):
        # Recent Linux Clang diagnoses isnan under fast math; other Clang
        # versions/libraries may not. Compare with the same native compiler
        # instead of suppressing its warning or requiring one header version.
        direct = subprocess.run([self.driver, '-std=c++17', '-O3', '-ffast-math',
                                 '-Werror', 'nan.cpp', '-o', 'direct.out'],
                                cwd=self.cwd, capture_output=True, text=True, timeout=30)
        wrapped = subprocess.run([str(SCRIPT), 'compile', 'nan.cpp', '--compiler=clang',
                                  '-std=17', '--profile=pragma-fast', '--', '-Werror'],
                                 cwd=self.cwd, env=self.env, capture_output=True,
                                 text=True, timeout=30)
        self.assertEqual(wrapped.returncode == 0, direct.returncode == 0, wrapped.stderr)
        if direct.returncode:
            self.assertIn('-Wnan-infinity-disabled', direct.stderr)
            self.assertIn('-Wnan-infinity-disabled', wrapped.stderr)

    def check_guarded_literal_pragma_header_compiles_cleanly(self):
        for name, define in (('pragma', ()), ('pragma-fast', ('-DCP_RUN_FAST_PRAGMAS',))):
            result = self.run_source(name, compiler=('-Werror', '-Wunknown-pragmas', '-include', 'gcc-pragmas.hpp', *define))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, 'checksum=4128010\n')

    def check_literal_gcc_pragmas_change_functions_without_fast_driver_flags(self):
        (self.cwd / 'nan.cpp').write_text(NAN)
        # Starting at -O0 isolates the literal pragma from the driver's fast
        # math option. Clang intentionally skips the guarded GCC directives.
        for fast in (False, True):
            output = self.cwd / 'literal.out'
            build = subprocess.run([self.driver, '-std=c++17', '-O0', '-Werror', '-Wunknown-pragmas',
                                    '-include', 'gcc-pragmas.hpp',
                                    *(('-DCP_RUN_FAST_PRAGMAS',) if fast else ()),
                                    'nan.cpp', '-o', str(output)], cwd=self.cwd,
                                   capture_output=True, text=True, timeout=30)
            self.assertEqual(build.returncode, 0, build.stderr)
            result = subprocess.run([str(output), 'nan'], cwd=self.cwd,
                                    capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            expected = '0\n' if self.FAMILY == 'gcc' and fast else '1\n'
            self.assertEqual(result.stdout, expected)

    def check_explicit_libcxx_keeps_the_same_optimization_profiles(self):
        probe = subprocess.run([self.driver, '-stdlib=libc++', '-std=c++17', '-fsyntax-only',
                                'main.cpp'], cwd=self.cwd, capture_output=True, text=True, timeout=30)
        if probe.returncode:
            self.skipTest('explicit libc++ headers are not installed for this Clang driver')
        for name in PROFILES:
            result = self.run_source(name, compiler=('-stdlib=libc++', '-Werror'))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, 'checksum=4128010\n')

    def check_native_overrides_keep_native_compiler_precedence(self):
        (self.cwd / 'levels.cpp').write_text(LEVELS)
        result = self.run_source('pragma', source='levels.cpp', compiler=('-O0', '-Werror'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'unoptimized\n')
        (self.cwd / 'nan.cpp').write_text(NAN)
        result = self.run_source('pragma-fast', source='nan.cpp',
                                 compiler=('-fno-fast-math', '-Werror'), runtime=('nan',))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '1\n')


for _family in ('gcc', 'clang'):
    _methods = {
        'FAMILY': _family,
        'test_optimized_integer_workload_and_werror': _RealPragmaCase.check_profiles_run_integer_workload_with_warnings_as_errors,
        'test_fast_math_is_an_explicit_semantic_change': _RealPragmaCase.check_fast_math_has_explicit_observable_semantics,
        'test_unknown_pragmas_are_diagnosed': _RealPragmaCase.check_unknown_pragmas_are_diagnosed_in_every_profile,
        'test_guarded_literal_gcc_header': _RealPragmaCase.check_guarded_literal_pragma_header_compiles_cleanly,
        'test_literal_gcc_pragmas_have_independent_effect': _RealPragmaCase.check_literal_gcc_pragmas_change_functions_without_fast_driver_flags,
        'test_user_tail_overrides_are_preserved': _RealPragmaCase.check_native_overrides_keep_native_compiler_precedence,
    }
    _name = ('Gcc' if _family == 'gcc' else 'Clang') + 'PragmaTest'
    if _family == 'clang':
        _methods['test_explicit_libcxx_profiles'] = _RealPragmaCase.check_explicit_libcxx_keeps_the_same_optimization_profiles
        _methods['test_nan_warning_is_not_suppressed'] = _RealPragmaCase.check_nan_warning_remains_a_compiler_decision
    globals()[_name] = type(_name, (_RealPragmaCase,), _methods)


class CrossTargetPragmaTest(unittest.TestCase):
    def test_explicit_clang_cross_target_compiles_without_host_cpu_leakage(self):
        driver = toolchains._driver('clang')
        if driver is None:
            self.skipTest('real Clang C++ driver not installed')
        with tempfile.TemporaryDirectory(prefix='cp-run-cross-target-') as temporary:
            cwd = Path(temporary)
            (cwd / 'main.cpp').write_text('int main() { return 0; }\n')
            result = subprocess.run([str(SCRIPT), 'compile', 'main.cpp', '--compiler=clang++',
                                     '--profile=pragma-native', '--show-command', '-o', 'cross.o', '--',
                                     '-target', 'x86_64-unknown-linux-gnu', '-c'], cwd=cwd,
                                    env=dict(os.environ, CXX=driver), capture_output=True,
                                    text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((cwd / 'cross.o').is_file())
            self.assertNotIn('-march=native', result.stderr)
            self.assertNotIn('-mcpu=native', result.stderr)


if __name__ == '__main__':
    unittest.main()
