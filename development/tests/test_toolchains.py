"""Real GCC/Clang integration, independent of the recording-compiler fixture.

CP_RUN_GCC / CP_RUN_CLANG select executables in CI. Locally, installed drivers
are discovered through PATH and checked by their own version banners.
"""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest


from _paths import RELEASE

SCRIPT = RELEASE / 'cp-run.zsh'

SUM = r'''#include <cstdio>
int main() {
    long long a = 0, b = 0;
    if (std::scanf("%lld%lld", &a, &b) != 2) return 2;
    std::printf("%lld\n", a + b);
}
'''
GENERATOR = r'''#include <cstdio>
int main(int argc, char** argv) {
    if (argc != 2) return 2;
    std::printf("%s 2\n", argv[1]);
}
'''
LIBRARY_CHECKS = r'''#include <vector>
#include <cstdio>
#ifndef LOCAL
#error the diagnostic profile must define LOCAL
#endif
#if defined(__GLIBCXX__)
# define LIBRARY_NAME "libstdc++"
# if WANT_EXTRA
#  if !defined(_GLIBCXX_DEBUG) || !defined(_GLIBCXX_DEBUG_PEDANTIC)
#   error extra profile must enable libstdc++ debug checks
#  endif
# elif !defined(_GLIBCXX_ASSERTIONS)
#  error base profile must enable libstdc++ assertions
# endif
#elif defined(_LIBCPP_VERSION)
# define LIBRARY_NAME "libc++"
# if WANT_EXTRA
#  if _LIBCPP_HARDENING_MODE != _LIBCPP_HARDENING_MODE_DEBUG
#   error extra profile must select libc++ debug hardening
#  endif
# elif _LIBCPP_HARDENING_MODE != _LIBCPP_HARDENING_MODE_FAST
#  error base profile must select libc++ fast hardening
# endif
#else
# error a supported standard library must be detected
#endif
int main() {
    const std::vector<int> values{7};
    std::printf("library=%s value=%d\n", LIBRARY_NAME, values.at(0));
}
'''
ARGUMENTS_AND_CLOCK = r'''#include <cstdio>
#include <time.h>
int main(int argc, char** argv) {
    timespec begin{}, end{}, pause{0, 60000000};
    clock_gettime(CLOCK_MONOTONIC, &begin);
    nanosleep(&pause, nullptr);
    clock_gettime(CLOCK_MONOTONIC, &end);
    const double elapsed = static_cast<double>(end.tv_sec - begin.tv_sec) * 1000.0
        + static_cast<double>(end.tv_nsec - begin.tv_nsec) / 1000000.0;
    if (argc != 3) return 2;
    std::printf("argv=<%s><%s> value=%d\nself_ms=%.3f\n", argv[1], argv[2], VALUE, elapsed);
}
'''


def _driver(family):
    configured = os.environ.get('CP_RUN_GCC' if family == 'gcc' else 'CP_RUN_CLANG')
    candidates = [configured] if configured else (
        ['g++'] + ['g++-' + str(n) for n in range(40, 7, -1)]
        if family == 'gcc' else ['clang++'])
    for candidate in candidates:
        if not candidate:
            continue
        executable = shutil.which(candidate)
        if not executable:
            continue
        banner = subprocess.run([executable, '--version'], capture_output=True, text=True,
                                timeout=10).stdout.lower()
        if ('clang' in banner) == (family == 'clang'):
            return executable
    return None


def _standard_rank(name):
    value = name.removeprefix('c++')
    draft = {'0x': 2011, '1y': 2014, '1z': 2017, '2a': 2020, '2b': 2023, '2c': 2026}
    if value in draft:
        return draft[value]
    if value.isdecimal():
        return 1900 + int(value) if value == '98' else 2000 + int(value)
    return -1


class _ToolchainCase(unittest.TestCase):
    FAMILY = None

    @classmethod
    def setUpClass(cls):
        if cls.FAMILY is None:
            return
        cls.driver = _driver(cls.FAMILY)
        if cls.driver is None:
            raise unittest.SkipTest('real ' + cls.FAMILY + ' C++ driver not installed')

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cp-run-real-')
        self.cwd = Path(self.temporary.name)
        self.env = dict(os.environ, CXX=self.driver)
        # LeakSanitizer is unavailable on some Darwin toolchains. These tests
        # exercise the explicitly selected address/undefined checks instead.
        self.env.setdefault('ASAN_OPTIONS', 'detect_leaks=0')

    def tearDown(self):
        self.temporary.cleanup()

    def source(self, code, name='main.cpp'):
        path = self.cwd / name
        path.write_text(code)
        return path

    def invoke(self, *arguments, input=None):
        return subprocess.run([str(SCRIPT), *map(str, arguments), '--compiler=' + self.FAMILY],
                              cwd=self.cwd, env=self.env, input=input, capture_output=True,
                              text=True, timeout=25)

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('Traceback', result.stderr)

    def check_newest_standard(self):
        self.source('#include <cstdio>\nint main() { std::printf("%ld\\n", __cplusplus); }\n')
        result = self.invoke('compile', '--show-command')
        self.assert_ok(result)
        chosen = re.search(r'-std=(c\+\+[0-9]+[a-z]?)', result.stderr)
        self.assertIsNotNone(chosen, result.stderr)
        if self.FAMILY == 'gcc':
            query = subprocess.run([self.driver, '--help=c++'], capture_output=True,
                                   text=True, timeout=10).stdout
        else:
            query = subprocess.run([self.driver, '-std=__cp_run_test_invalid__',
                                    '-fsyntax-only', '-x', 'c++', os.devnull],
                                   capture_output=True, text=True, timeout=10).stderr
        advertised = set(re.findall(r'c\+\+[0-9]+[a-z]?', query))
        self.assertTrue(advertised, query)
        newest = max(map(_standard_rank, advertised))
        self.assertEqual(_standard_rank(chosen.group(1)), newest)
        equivalent_numeric = [name for name in advertised
                              if name[3:].isdecimal() and _standard_rank(name) == newest]
        if equivalent_numeric:
            self.assertIn(chosen.group(1), equivalent_numeric)
        artifact = Path(result.stdout.strip())
        self.assertTrue(artifact.is_absolute() and artifact.is_file())
        direct = subprocess.run([str(artifact)], capture_output=True, text=True, timeout=10)
        self.assertEqual(direct.returncode, 0, direct.stderr)
        self.assertGreaterEqual(int(direct.stdout), 202002)

    def check_arguments_and_monotonic_timing(self):
        self.source(ARGUMENTS_AND_CLOCK)
        # The compiler selector belongs before the first tail, unlike ordinary
        # wrapper options appended by invoke(). Keep tail argv fully literal.
        result = subprocess.run([str(SCRIPT), 'main.cpp', '--compiler=' + self.FAMILY,
                                 '--', '-DVALUE=7', '--', 'a b', ''], cwd=self.cwd,
                                env=self.env, capture_output=True, text=True, timeout=25)
        self.assert_ok(result)
        self.assertIn('argv=<a b><> value=7', result.stdout)
        # Warm the exact executable above so macOS first-execution validation
        # is not confused with the program's own monotonic sleep interval.
        measured = subprocess.run([str(SCRIPT), 'run', './main.out', '-t', '--', 'a b', ''],
                                  cwd=self.cwd, env=self.env, capture_output=True,
                                  text=True, timeout=10)
        self.assert_ok(measured)
        internal = float(re.search(r'self_ms=([0-9.]+)', measured.stdout).group(1))
        observed = float(re.search(r'cp-run: time: ([0-9.]+) ms', measured.stderr).group(1))
        self.assertGreaterEqual(internal, 50)
        self.assertGreaterEqual(observed + 1, internal)
        self.assertLess(observed, internal + 300)

    def check_profile(self, extra):
        self.source(LIBRARY_CHECKS)
        command = 'debug=extra' if extra else 'debug'
        result = subprocess.run([str(SCRIPT), command, 'run', '--compiler=' + self.FAMILY,
                                 '--show-command', '--', '-DWANT_EXTRA=' + str(int(extra))],
                                cwd=self.cwd, env=self.env, capture_output=True,
                                text=True, timeout=25)
        self.assert_ok(result)
        self.assertRegex(result.stdout, r'library=(libstdc\+\+|libc\+\+) value=7')
        self.assertIn('-fsanitize=address,undefined', result.stderr)
        if 'library=libstdc++' in result.stdout:
            expected = '-D_GLIBCXX_DEBUG' if extra else '-D_GLIBCXX_ASSERTIONS'
            self.assertIn(expected, result.stderr)
            self.assertNotIn('-D_LIBCPP_HARDENING_MODE=', result.stderr)
        else:
            expected = '_LIBCPP_HARDENING_MODE_DEBUG' if extra else '_LIBCPP_HARDENING_MODE_FAST'
            self.assertIn('-D_LIBCPP_HARDENING_MODE=' + expected, result.stderr)
            self.assertNotIn('-D_GLIBCXX_DEBUG', result.stderr)
        if extra and self.FAMILY == 'clang' and sys.platform == 'darwin':
            self.assertTrue((self.cwd / 'main.out.dSYM').is_dir(),
                            'installing a staged debug binary must retain its dSYM')
        self.assertEqual(list(self.cwd.glob('.cp-run-build.*')), [])

    def check_answer_blocks(self):
        self.source(SUM)
        (self.cwd / 'in.txt').write_text('2 3\n\n7 8\n')
        (self.cwd / 'ans.txt').write_text('5\n\n15\n')
        result = self.invoke('test=auto', r'--sep=\n\n')
        self.assert_ok(result)
        report = (self.cwd / 'test_out').read_text()
        self.assertIn('PASS', report)
        self.assertIn('2 selected cases executed', report)
        self.assertIn('5', (self.cwd / 'out.txt').read_text())
        self.assertIn('15', (self.cwd / 'out.txt').read_text())

    def stress_sources(self, wrong=False):
        self.source(SUM.replace('a + b', 'a + b + 1') if wrong else SUM)
        self.source(SUM, 'brute.cpp')
        self.source(GENERATOR, 'gen.cpp')

    def check_stress_agreement(self):
        self.stress_sources()
        result = self.invoke('stress', 'main.cpp', 'brute.cpp', 'gen.cpp',
                             '--seed=40', '--test-iters=3', '--stop-on-failure')
        self.assert_ok(result)
        self.assertIn('No difference in 3 generated cases', (self.cwd / 'test_out').read_text())
        self.assertEqual(list(self.cwd.glob('stress-failure*')), [])

    def check_stress_counterexample_and_replay(self):
        self.stress_sources(wrong=True)
        result = self.invoke('stress', 'main.cpp', 'brute.cpp', 'gen.cpp',
                             '--seed=40', '--test-iters=3', '--stop-on-failure')
        self.assertEqual(result.returncode, 3, result.stderr)
        bundles = list(self.cwd.glob('stress-failure*'))
        self.assertEqual(len(bundles), 1)
        bundle = bundles[0]
        manifest = json.loads((bundle / 'manifest.json').read_text())
        self.assertEqual(manifest['seed'], 40)
        self.assertEqual(manifest['iteration'], 1)
        self.assertEqual((bundle / 'in.txt').read_text(), '40 2\n')
        self.assertEqual((bundle / 'ans.txt').read_text(), '42\n')
        self.assertEqual((bundle / 'out.txt').read_text(), '43\n')
        replay = subprocess.run(manifest['replay_argv'], cwd=self.cwd, env=self.env,
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(replay.returncode, 3, replay.stderr)

    def check_undefined_sanitizer_stops(self):
        self.source('#include <cstdio>\nint main() { volatile int a = 2147483647; '
                    'int b = a + 1; std::printf("%d\\n", b); }\n')
        prepared = self.invoke('debug')
        self.assert_ok(prepared)
        self.assertEqual(prepared.stdout, str((self.cwd / 'main.out').resolve()) + '\n')
        result = self.invoke('debug', 'run')
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertIn('runtime error:', result.stderr)
        self.assertIn('signed integer overflow', result.stderr)
        self.assertNotIn('cp-run: compilation failed', result.stderr)


# Expose eight independently named checks per installed driver. Base methods
# deliberately do not start with test_, avoiding accidental third execution.
for _family in ('gcc', 'clang'):
    _methods = {
        'FAMILY': _family,
        'test_newest_advertised_standard': _ToolchainCase.check_newest_standard,
        'test_program_arguments_and_numeric_timing': _ToolchainCase.check_arguments_and_monotonic_timing,
        'test_base_profile_actual_library_checks': lambda self: self.check_profile(False),
        'test_extra_profile_actual_library_and_debug_artifacts': lambda self: self.check_profile(True),
        'test_auto_answer_checking': _ToolchainCase.check_answer_blocks,
        'test_stress_generated_agreement': _ToolchainCase.check_stress_agreement,
        'test_stress_counterexample_replay': _ToolchainCase.check_stress_counterexample_and_replay,
        'test_native_undefined_sanitizer_failure': _ToolchainCase.check_undefined_sanitizer_stops,
    }
    globals()[('Gcc' if _family == 'gcc' else 'Clang') + 'ToolchainTest'] = type(
        ('Gcc' if _family == 'gcc' else 'Clang') + 'ToolchainTest', (_ToolchainCase,), _methods)


if __name__ == '__main__':
    unittest.main()
