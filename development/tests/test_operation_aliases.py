"""Extension operation aliases preserve the command's semantics and boundaries."""

import sys
import unittest

import test_cli as fixtures


class OperationAliasTest(unittest.TestCase):
    # Reuse fixture helpers without inheriting and rerunning its entire suite.
    setUp = fixtures.CliTest.setUp
    tearDown = fixtures.CliTest.tearDown
    environment = fixtures.CliTest.environment
    invoke = fixtures.CliTest.invoke
    calls = fixtures.CliTest.calls
    binary = fixtures.CliTest.binary
    rejected = fixtures.CliTest.rejected

    def test_compile_alias_before_and_after_file_never_runs(self):
        for args in (('--compile', self.source), (self.source, '--compile'),
                     ('compile', self.source, '--compile'), ('--compile',)):
            with self.subTest(args=args):
                result = self.invoke(*args, env={'FAKE_PROGRAM_STDOUT': 'must not run\n'})
                self.assertEqual((result.returncode, result.stderr), (0, ''))
                self.assertEqual(result.stdout, str(self.cwd / 'main file.out') + '\n')

    def test_python_compile_alias_only_validates_syntax(self):
        source = self.cwd / 'main.py'
        source.write_text('raise RuntimeError("must not execute")\n')
        result = self.invoke(source, '--compile', '--interpreter=' + sys.executable)
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, str(source) + '\n', ''))
        self.assertEqual(self.calls(), [])

    def test_debug_alias_builds_same_native_profiles_without_running(self):
        counter = self.root / 'must-not-run'
        for option in ('--debug', '--debug=', '--debug=extra'):
            for first in (True, False):
                with self.subTest(option=option, first=first):
                    args = (option, self.source) if first else (self.source, option)
                    result = self.invoke(*args, env={'FAKE_PROGRAM_COUNTER': str(counter),
                                                    'FAKE_PROGRAM_STATUS': '7'})
                    self.assertEqual((result.returncode, result.stdout),
                                     (0, str(self.cwd / 'main file.out') + '\n'), result.stderr)
                    self.assertFalse(counter.exists())
                    call = self.calls()[-1]
                    self.assertIn('-fsanitize=address,undefined', call)
                    self.assertIn('-Og' if option.endswith('extra') else '-O2', call)
                    self.assertFalse(any(arg.startswith('--debug') for arg in call))

    def test_debug_command_only_builds_and_preserves_compiler_diagnostics(self):
        for command in ('debug', 'debug=extra'):
            result = self.invoke(command, self.source, env={
                'FAKE_GCC_STDOUT': 'compiler note\n', 'FAKE_GCC_STDERR': 'warning\n',
                'FAKE_PROGRAM_STDOUT': 'must not run\n', 'FAKE_PROGRAM_STATUS': '9'})
            self.assertEqual((result.returncode, result.stdout),
                             (0, str(self.cwd / 'main file.out') + '\n'), result.stderr)
            # Compiler stdout/stderr may flush in either order into stderr.
            self.assertCountEqual(result.stderr.splitlines(), ['compiler note', 'warning'])

    def test_explicit_debug_run_forms_execute_and_preserve_program_status(self):
        for args in (('debug', 'run', self.source), ('debug=extra', 'run', self.source),
                     ('--debug', '--run', self.source), ('--run', '--debug', self.source),
                     (self.source, '--debug', '--run'), (self.source, '--run', '--debug'),
                     ('--debug=extra', self.source, '--run')):
            with self.subTest(args=args):
                result = self.invoke(*args, env={'FAKE_PROGRAM_STDOUT': 'diagnostic run\n',
                                                'FAKE_PROGRAM_STDERR': 'program stderr\n',
                                                'FAKE_PROGRAM_STATUS': '7'})
                self.assertEqual((result.returncode, result.stdout, result.stderr),
                                 (7, 'diagnostic run\n', 'program stderr\n'))

    def test_debug_run_has_backend_and_program_boundaries(self):
        recorded = self.root / 'debug-runtime.json'
        result = self.invoke('--debug', '--run', self.source, '--', '-DARGUMENT_TEST', '--',
                             '--compile', 'with spaces', env={'FAKE_PROGRAM_ARGS': str(recorded)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('-DARGUMENT_TEST', self.calls()[-1])
        self.assertEqual(recorded.read_text(), '["--compile", "with spaces"]')

    def test_python_debug_only_validates_syntax_but_run_executes(self):
        source = self.cwd / 'main.py'
        source.write_text('raise RuntimeError("only an explicit run may execute")\n')
        result = self.invoke('--debug', source, '--interpreter=' + sys.executable)
        self.assertEqual((result.returncode, result.stdout), (0, str(source) + '\n'), result.stderr)
        source.write_text('def broken(:\n')
        result = self.invoke('--debug', source, '--interpreter=' + sys.executable)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('SyntaxError', result.stderr)
        source.write_text('import sys; print(sys.flags.dev_mode)\n')
        result = self.invoke('--debug', '--run', source, '--interpreter=' + sys.executable)
        self.assertEqual((result.returncode, result.stdout), (0, 'True\n'), result.stderr)

    def test_debug_alias_keeps_profile_kind_and_weakening_checks(self):
        self.rejected('--debug=pragma', self.source)
        self.rejected(self.source, '--debug', '--', '-O3')
        self.rejected(self.source, '--debug', '--no-w')

    def test_run_alias_does_not_compile_and_preserves_runtime_arguments(self):
        binary = self.binary()
        values = ('--compile', '--debug', '--run', '--', 'with spaces', '')
        for args in (('--run', binary), (binary, '--run'), ('run', binary, '--run')):
            with self.subTest(args=args):
                result = self.invoke(*args, '--', *values)
                self.assertEqual((result.returncode, result.stdout), (0, '\n'.join(values) + '\n'), result.stderr)
                self.assertEqual(self.calls(), [])

    def test_run_alias_supports_find_without_a_file(self):
        self.binary('found.out', 'echo found\n')
        result = self.invoke('--run', '--find=found')
        self.assertEqual((result.returncode, result.stdout), (0, 'found\n'), result.stderr)
        self.assertEqual(self.calls(), [])

    def test_backend_tail_and_native_operands_remain_literal(self):
        values = ('--compile', '--debug', '--run')
        result = self.invoke('--compile', self.source, '--', *values)
        self.assertEqual(result.returncode, 0, result.stderr)
        call = self.calls()[-1]
        start = call.index(values[0])
        self.assertEqual(tuple(call[start:start + len(values)]), values)
        result = self.invoke('--compile', self.source, '-I', '--run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1][self.calls()[-1].index('-I') + 1], '--run')

    def test_conflicting_commands_values_and_runtime_options_are_rejected(self):
        for args in (('compile', '--run'), ('run', '--compile'), ('debug', '--compile'),
                     ('test', '--debug'), ('stress', '--run'), ('companion', '--compile'),
                     ('--compile', '--debug'), ('--compile=1',), ('--run=main.out',),
                     ('--compile', '-t'), ('--compile', '-f=auto'), ('--debug', '-t'),
                     ('--debug', '-m'), ('--debug', '-f=auto')):
            with self.subTest(args=args):
                self.rejected(*args)


if __name__ == '__main__':
    unittest.main()
