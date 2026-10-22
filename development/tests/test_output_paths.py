"""Configurable checked output shares file defaults without leaking raw stdout."""

import copy
import errno
import os
from pathlib import Path
import sys
import unittest
from unittest import mock

import test_cli as fixtures
import test_checking as checking


class OutputPathCliTest(unittest.TestCase):
    setUp = fixtures.CliTest.setUp
    tearDown = fixtures.CliTest.tearDown
    environment = fixtures.CliTest.environment
    invoke = fixtures.CliTest.invoke
    calls = fixtures.CliTest.calls
    binary = fixtures.CliTest.binary
    data = fixtures.CliTest.data
    rejected = fixtures.CliTest.rejected

    def test_factory_files_and_cout_never_emit_a_separate_raw_output(self):
        self.data('distinct program payload\n', 'distinct program payload\n')
        result = self.invoke('test', self.source, '--cout', env={'FAKE_PROGRAM_STDIN': '1'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / 'out.txt').read_text(), 'distinct program payload\n')
        self.assertIn('out.txt:1 | "distinct program payload"', result.stdout)
        self.assertNotIn('distinct program payload', result.stdout.splitlines())
        self.assertEqual(result.stdout.count('distinct program payload'), 3)  # input, numbered output, answer
        self.assertFalse((self.cwd / 'test_out').exists())
        self.assertFalse((self.cwd / 'real-out.txt').exists())

    def test_named_workspace_output_in_both_option_forms(self):
        self.data()
        (self.ws / 'results').mkdir()
        for option in (('--out={wsp-dir}/results/result.txt',),
                       ('--out', '{wsp-dir}/results/result.txt')):
            result = self.invoke('test', self.source, '--wsp-dir=..', '--cout', *option,
                                 env={'FAKE_PROGRAM_STDIN': '1'})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((self.ws / 'results/result.txt').read_text(), 'hello\n')
            self.assertIn('result.txt:1', result.stdout)
        self.assertFalse((self.cwd / 'out.txt').exists())

    def test_custom_output_is_preserved_for_auto_and_mult(self):
        source = self.cwd / 'echo.py'
        source.write_text('import sys; sys.stdout.write(sys.stdin.read())\n')
        payload = 'one\n\x1e\ntwo\n'
        self.data(payload, payload)
        args = ['--out=custom.txt', '--cout', '--interpreter=' + sys.executable]
        result = self.invoke('test=auto', source, *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / 'custom.txt').read_text(), payload)
        tests = self.cwd / 'tests'; tests.mkdir()
        for number, text in ((1, 'one'), (2, 'two\n')):
            (tests / (str(number) + '.in')).write_text(text)
            (tests / (str(number) + '.ans')).write_text(text)
        result = self.invoke('test=mult', source, *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / 'custom.txt').read_text(), payload)

    def test_stress_cout_keeps_named_output_and_no_raw_line(self):
        self.binary('candidate', 'cat\n'); self.binary('brute', 'cat\n')
        self.binary('gen', 'printf "stress-payload\\n"\n')
        result = self.invoke('stress', 'run', 'candidate', 'brute', 'gen',
                             '--test-iters=2', '--out=stress-result.txt', '--cout')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / 'stress-result.txt').read_text(), 'stress-payload\n')
        self.assertIn('stress-result.txt:1', result.stdout)
        self.assertNotIn('stress-payload', result.stdout.splitlines())
        self.assertFalse((self.cwd / 'test_out').exists())

    def test_output_aliases_of_readable_roles_are_rejected_before_build(self):
        self.data()
        for target in ('in.txt', 'ans.txt', 'test_out', self.source.name, 'main file.out'):
            with self.subTest(target=target):
                self.rejected('test', self.source, '--out', target)
        self.assertEqual((self.cwd / 'in.txt').read_text(), 'hello\n')
        self.assertEqual((self.cwd / 'ans.txt').read_text(), 'hello\n')

    def test_unsafe_paths_empty_values_and_unconsumed_out_are_rejected(self):
        self.data()
        self.rejected('test', self.source, '--out=')
        self.rejected('test', self.source, '--out')
        self.rejected('test', self.source, '--out={wsp-dir}/../escape.txt')
        self.rejected('compile', self.source, '--out=unused.txt')
        self.rejected(self.source, '--out=unused.txt')
        (self.cwd / 'link').symlink_to(self.cwd / 'ans.txt')
        self.rejected('test', self.source, '--out=link')
        os.link(self.cwd / 'in.txt', self.cwd / 'hardlink')
        self.rejected('test', self.source, '--out=hardlink')
        self.rejected('test', self.source, '--out=missing/out.txt', status=1)

    def test_compiler_sidecar_cannot_overwrite_custom_program_output(self):
        self.data()
        target = self.cwd / 'artifact.map'; target.write_text('previous\n')
        result = self.invoke('test', self.source, '-o', 'artifact', '--out=artifact.map',
                             env={'FAKE_SIDECAR': 'symbols'})
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('protected', result.stderr)
        self.assertEqual(target.read_text(), 'previous\n')

    def test_out_can_select_redirected_output_without_becoming_binary_o(self):
        self.data()
        result = self.invoke(self.source, '-f=auto', '--out=redirected.txt',
                             env={'FAKE_PROGRAM_STDIN': '1'})
        self.assertEqual((result.returncode, result.stdout), (0, ''), result.stderr)
        self.assertEqual((self.cwd / 'redirected.txt').read_text(), 'hello\n')
        self.assertTrue((self.cwd / 'main file.out').is_file())

    def test_out_after_backend_or_runtime_boundary_remains_literal(self):
        result = self.invoke('compile', self.source, '--', '--out=backend-specific.txt')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--out=backend-specific.txt', self.calls()[-1])
        binary = self.binary()
        result = self.invoke('run', binary, '--', '--out=program-specific.txt')
        self.assertEqual((result.returncode, result.stdout), (0, '--out=program-specific.txt\n'), result.stderr)
        self.assertFalse((self.cwd / 'program-specific.txt').exists())


class OutputPublicationTest(unittest.TestCase):
    setUp = checking.CheckingTest.setUp
    tearDown = checking.CheckingTest.tearDown
    program = checking.CheckingTest.program
    execute = checking.CheckingTest.execute

    def test_imported_older_filenames_are_preserved(self):
        values = copy.deepcopy(checking.ENGINE.FACTORY_SETTINGS)
        values.update(DEFAULT_INPUT='input.txt', DEFAULT_OUTPUT='output.txt')
        restored = checking.ENGINE.validate_preferences(values)
        self.assertEqual((restored['DEFAULT_INPUT'], restored['DEFAULT_OUTPUT']), ('input.txt', 'output.txt'))

    def test_cross_device_output_is_published_atomically_beside_target(self):
        original = checking.ENGINE.os.replace
        calls = []

        def replace(source, target):
            calls.append((source, target))
            if Path(source).name == 'combined.stdout':
                raise OSError(errno.EXDEV, 'simulated distinct workspace volume')
            return original(source, target)

        Path('results').mkdir()
        config = dict(self.config, actual='results/chosen.txt', cout=True)
        with mock.patch.object(checking.ENGINE.os, 'replace', side_effect=replace):
            status, stdout, _ = self.execute(config)
        self.assertEqual(status, 0)
        self.assertEqual(Path('results/chosen.txt').read_bytes(), b'hello\n')
        self.assertIn('chosen.txt:1', stdout)
        self.assertTrue(any(Path(source).parent.resolve() == Path('results').resolve() for source, _ in calls))
        self.assertEqual(list(Path('results').glob('.cp-run-*')), [])


if __name__ == '__main__':
    unittest.main()
