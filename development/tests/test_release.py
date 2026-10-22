"""End-user regressions for the modular one-file release, streams and state."""

import copy
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest
from unittest import mock

from _paths import ROOT, RELEASE, load_engine
import test_cli as cli_fixtures
SCRIPT = RELEASE / "cp-run.zsh"

engine = load_engine('cp_run_release_engine')


class ReleaseCliTest(unittest.TestCase):
    # Compose fixture helpers without inheriting/rerunning the old test suite.
    setUp = cli_fixtures.CliTest.setUp
    tearDown = cli_fixtures.CliTest.tearDown
    environment = cli_fixtures.CliTest.environment
    invoke = cli_fixtures.CliTest.invoke
    binary = cli_fixtures.CliTest.binary
    data = cli_fixtures.CliTest.data
    calls = cli_fixtures.CliTest.calls

    def counter_program(self, failing=False):
        counter = self.cwd / 'count'
        program = self.cwd / 'counter.out'
        program.write_text('#!' + sys.executable + '\n'
            'from pathlib import Path\nimport sys\n'
            'p=Path("count"); n=int(p.read_text())+1 if p.exists() else 1\np.write_text(str(n))\n'
            'data=sys.stdin.buffer.read()\n'
            + ('sys.stdout.buffer.write(data if n == 1 else b"wrong\\n")\n' if failing else
               'sys.stdout.write("run="+str(n)+"\\n"); sys.stdout.flush(); sys.stdout.buffer.write(data)\n'))
        program.chmod(0o755)
        return program, counter

    def test_average_warmup_have_one_stdout_and_replay_pipe(self):
        program, counter = self.counter_program()
        result = self.invoke('run', program, '-tm', '--average=3', input='same\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '4')
        self.assertEqual(result.stdout, 'run=2\nsame\n')
        self.assertEqual(result.stderr.count('cp-run: time:'), 1)
        self.assertEqual(result.stderr.count('cp-run: peak RSS:'), 1)
        self.assertIn('3 measured runs', result.stderr)

    def test_zero_average_and_warmup_disable_extra_runs(self):
        for value in ('0', '1'):
            program, counter = self.counter_program()
            counter.unlink(missing_ok=True)
            result = self.invoke('run', program, '-t', '--warm-up', '0', '--average', value, input='x')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(counter.read_text(), '1')
            self.assertEqual(result.stdout, 'run=1\nx')

    def test_bare_options_keep_file_operands_and_use_saved_average(self):
        program, counter = self.counter_program()
        result = self.invoke('run', program, '-t', '--warm-up', '--average', input='x')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '2')

    def test_auto_io_keeps_first_visible_output_only(self):
        program, counter = self.counter_program()
        self.data('hello\n', 'hello\n')
        result = self.invoke('run', program, '--file-io', 'auto', '-tm', '--average=3')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '')
        self.assertEqual(counter.read_text(), '4')
        self.assertEqual((self.cwd / 'out.txt').read_text(), 'run=2\nhello\n')

    def test_file_io_long_alias_matches_macro_and_redirection(self):
        result = self.invoke('compile', self.source.name, '--file-io')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('-DFILEO', self.calls()[-1])
        self.data()
        for option in ('--file-io=auto', '-f=auto'):
            result = self.invoke(self.source.name, option, env={'FAKE_PROGRAM_STDIN': '1'})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((self.cwd / 'out.txt').read_text(), 'hello\n')

    def test_invalid_measurement_controls_and_units(self):
        for arguments in (('--average=',), ('--average=-1',), ('--average=abc',),
                          ('--average=100001',), ('--warm-up=2',), ('--warm-up=',),
                          ('--warm-up', '-1'), ('--time-unit=sec',), ('--memory-unit=kb',)):
            with self.subTest(arguments=arguments):
                result = self.invoke(self.source.name, '-t', *arguments)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertNotIn('Traceback', result.stderr)
        self.assertEqual(self.invoke(self.source.name, '--average=2').returncode, 2)

    def test_units_and_runtime_arguments_stay_separate(self):
        binary = self.binary()
        result = self.invoke('run', binary, '-tm', '--warm-up=0', '--time-unit=s', '--memory-unit=MB', '--', '-', 'a b')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '-\na b\n')
        self.assertIn(' s\n', result.stderr)
        self.assertIn(' MB\n', result.stderr)

    def test_history_keeps_source_binary_and_failed_compile(self):
        first = self.invoke('compile', self.source.name)
        self.assertEqual(first.returncode, 0, first.stderr)
        second = self.invoke('compile', '-')
        self.assertEqual(second.returncode, 0, second.stderr)
        binary = self.binary('chosen.bin', 'printf "last\\n"\n')
        self.assertEqual(self.invoke('run', binary).stdout, 'last\n')
        failed = self.invoke(self.source.name, env={'FAKE_GCC_STATUS': '9'})
        self.assertEqual(failed.returncode, 9)
        result = self.invoke('run', '-')
        self.assertEqual((result.returncode, result.stdout), (0, 'last\n'), result.stderr)
        binary.unlink()
        self.assertEqual(self.invoke('run', '-').returncode, 1)

    def test_history_is_scoped_and_dash_can_be_literal(self):
        other = self.cwd / 'other'; other.mkdir()
        self.invoke('run', self.binary())
        self.assertEqual(self.invoke('run', '-', cwd=other).returncode, 1)
        literal = self.binary('-', 'printf "literal\\n"\n')
        result = self.invoke('run', './-')
        self.assertEqual((result.returncode, result.stdout), (0, 'literal\n'))

    def test_tr_sr_expand_without_changing_tails(self):
        main = self.binary('solver.bin', 'cat\n')
        self.invoke('run', main)
        self.data()
        checked = self.invoke('tr')
        self.assertEqual(checked.returncode, 0, checked.stderr)
        brute = self.binary('brute.bin', 'cat\n')
        generator = self.binary('gen.bin', 'printf "hello\\n"\n')
        stressed = self.invoke('sr', brute, generator, '--test-iters=2')
        self.assertEqual(stressed.returncode, 0, stressed.stderr)

    def test_import_export_roundtrip_without_compiler(self):
        script = self.cwd / 'installed copy'; shutil.copy2(SCRIPT, script)
        export = self.cwd / 'preferences.json'
        result = self.invoke('--export-settings', export, script=script, env={'CXX': '/missing'})
        self.assertEqual(result.returncode, 0, result.stderr)
        record = json.loads(export.read_text())
        record['settings']['DEFAULT_AVERAGE'] = '3'
        record['settings']['DEFAULT_WARMUP'] = '0'
        export.write_text(json.dumps(record))
        result = self.invoke('--import-settings=' + str(export), script=script, env={'CXX': '/missing'})
        self.assertEqual(result.returncode, 0, result.stderr)
        program, counter = self.counter_program()
        result = self.invoke('run', program, '-t', '--average', script=script)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '3')
        self.assertEqual(result.stdout, 'run=1\n')

    def test_bad_import_is_atomic_and_never_executes_text(self):
        script = self.cwd / 'installed copy'; shutil.copy2(SCRIPT, script)
        export = self.cwd / 'settings.json'
        self.invoke('--export-settings', export, script=script)
        original = script.read_bytes(); record = json.loads(export.read_text())
        for bad in ({**record, 'schema': 999}, {**record, 'settings': {'UNKNOWN': 'x'}},
                    {**record, 'settings': {'TIME_KILL_FACTOR': 'nan'}},
                    {**record, 'settings': {'DEFAULT_AVERAGE': '-1'}}):
            export.write_text(json.dumps(bad))
            result = self.invoke('--import-settings', export, script=script)
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertEqual(script.read_bytes(), original)

    def test_invalid_standard_rejected_before_user_compilation(self):
        result = self.invoke('compile', self.source.name, '-std=999')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn('unsupported C++ standard', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_large_embedded_payload_preserves_binary_stdin(self):
        script = self.cwd / 'large script'
        text = SCRIPT.read_text().replace('# Source: bridge.py', '#' + 'x' * 200000 + '\n# Source: bridge.py')
        script.write_text(text); script.chmod(0o755)
        program = self.binary('copy.out', 'cat\n')
        result = subprocess.run([str(script), 'run', str(program), '-t', '--warm-up=0', '--average=2'],
            cwd=self.cwd, env=self.environment(), input=b'a\0b\xff\n', capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b'a\0b\xff\n')

    def test_later_wrong_repeat_is_not_hidden_by_median(self):
        program, counter = self.counter_program(failing=True)
        self.data()
        result = self.invoke('test', 'run', program, '-t', '--warm-up=0', '--average=3')
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertEqual(counter.read_text(), '2')
        self.assertEqual((self.cwd / 'out.txt').read_text(), 'hello\n')
        self.assertIn('FAILED REPEAT 2', (self.cwd / 'test_out').read_text())

    def test_repeated_terminal_input_is_recorded_once_and_replayed(self):
        program, counter = self.counter_program()
        master, slave = os.openpty()
        process = None
        try:
            process = subprocess.Popen([str(SCRIPT), 'run', str(program), '-t', '--average=2'],
                stdin=slave, cwd=self.cwd, env=self.environment(),
                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            os.write(master, b'terminal input\n\x04')
            stdout, stderr = process.communicate(timeout=20)
            self.assertEqual(process.returncode, 0, stderr)
            self.assertEqual(stdout, b'run=1\nterminal input\n')
            self.assertEqual(counter.read_text(), '4')
        finally:
            os.close(master); os.close(slave)
            if process is not None and process.poll() is None:
                process.kill(); process.communicate()

    def test_setup_failure_does_not_replace_binary_history(self):
        first = self.binary('first.bin', 'printf "first\\n"\n')
        second = self.binary('second.bin')
        self.invoke('run', first)
        failed = self.invoke('run', second, '--file-io=auto', 'missing.input')
        self.assertNotEqual(failed.returncode, 0)
        self.assertEqual(self.invoke('run', '-').stdout, 'first\n')

    def test_fd_transport_does_not_leak_source_descriptor(self):
        program = self.cwd / 'descriptors.out'
        program.write_text('#!' + sys.executable + '\nimport os\n'
            'for fd in range(3, 32):\n'
            ' try: os.fstat(fd)\n'
            ' except OSError: continue\n'
            ' raise SystemExit("unexpected inherited descriptor: "+str(fd))\nprint("OK")\n')
        program.chmod(0o755)
        result = self.invoke('run', program, '-tm', '--warm-up=0')
        self.assertEqual((result.returncode, result.stdout), (0, 'OK\n'), result.stderr)

    def test_saved_repetitions_are_inactive_without_measurement(self):
        script = self.cwd / 'saved defaults'; shutil.copy2(SCRIPT, script)
        original = script.read_text(); data = engine.read_settings(original)
        data['DEFAULT_AVERAGE'] = '3'
        engine.save_settings(script, original, data)
        program, counter = self.counter_program()
        master, slave = os.openpty()
        try:
            # Finite limits need a supervisor, but must not activate repetition
            # or reject a terminal just because a saved average is greater than 1.
            os.write(master, b'input\n\x04')
            process = subprocess.Popen([str(script), 'run', str(program), '--TLE=5000'],
                cwd=self.cwd, env=self.environment(), stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            stdout, stderr = process.communicate(timeout=20)
            self.assertEqual(process.returncode, 0, stderr)
            self.assertEqual(counter.read_text(), '1')
            self.assertIn(b'run=1', stdout)
        finally:
            os.close(master); os.close(slave)

    def test_concurrent_history_fields_remain_readable(self):
        processes = [subprocess.Popen([str(SCRIPT), 'compile', self.source.name, '-o', str(self.cwd / ('b' + str(i)))],
            cwd=self.cwd, env=self.environment(), stdout=subprocess.PIPE, stderr=subprocess.PIPE) for i in range(3)]
        for process in processes:
            _, stderr = process.communicate(timeout=20)
            self.assertEqual(process.returncode, 0, stderr)
        result = self.invoke('compile', '-')
        self.assertEqual(result.returncode, 0, result.stderr)


class ReleaseEngineTest(unittest.TestCase):
    def test_exact_units_and_secondary_prefixes(self):
        self.assertEqual(engine.format_usage(1536000000, 'ms'), '1536.000 ms (1.536 s)')
        self.assertEqual(engine.format_usage(1536 * 1024, 'KiB', True), '1536 KiB (1.500 MiB)')
        self.assertEqual(engine.format_usage(1500000, 'KB', True), '1500.000 KB (1.500 MB)')
        self.assertNotIn('(', engine.format_usage(999999999, 'ms'))

    def test_integer_median_and_maximum_ignore_warmup(self):
        class Observer:
            show_time = True; show_memory = True
            def display(self, result, *args): self.result = result
            def diagnostic(self, result, *args): self.result = result
        observer = Observer()
        values = {-1: (900, 900), 0: (11, 10), 1: (20, 50), 2: (50, 30), 3: (31, 20)}
        result = engine.run_series(observer, {'show_time': True, 'warmup': True, 'average': 4},
            lambda index: engine.Result(0, *values[index], 'OK'))
        self.assertEqual((result.elapsed_ns, result.peak_bytes), (26, 50))

    def test_limits_use_exact_separate_multipliers(self):
        runner = engine.Runner('3', '2', time_factor='1.25', memory_factor='1.5')
        self.assertEqual(runner.kill_time_ns, 3750000)
        self.assertEqual(runner.kill_memory_bytes, 3 * 1024 * 1024)
        for value in ('nan', 'inf', '-2', '0', '.5', '0.9'):
            with self.subTest(value=value), self.assertRaises(ValueError): engine.Runner(time_factor=value)

    def test_long_rows_and_combined_byte_budget_are_incomplete(self):
        result = engine.compare_streams(io.BytesIO(b'x' * 1000000), io.BytesIO(b'x'), 100, max_line=100)
        self.assertTrue(result.incomplete)
        self.assertIn('row', result.reason)
        result = engine.compare_streams(io.BytesIO(b'a\n' * 20), io.BytesIO(b'a\n' * 20), 100, max_bytes=10)
        self.assertTrue(result.incomplete)
        self.assertIn('checked data', result.reason)

    def test_separator_across_chunk_boundary_is_indexed_exactly(self):
        import tempfile
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'cases'; path.write_bytes(b'x' * 65535 + b'\n\nlast\n\n')
            cases = engine.index_cases(path, b'\n\n')
            self.assertEqual([case.length for case in cases], [65535, 4])

    def test_factory_budget_policy_preserves_native_ordinary_path(self):
        settings = engine.FACTORY_SETTINGS
        self.assertEqual((settings['DEFAULT_TIMEOUT'], settings['DEFAULT_MEMORY_LIMIT']), ('inf', 'inf'))
        self.assertEqual((settings['CHECK_TIMEOUT'], settings['CHECK_MEMORY_LIMIT']), ('1500', '256'))

    def test_stress_survives_thousand_successes_over_old_global_budget(self):
        import tempfile
        from contextlib import redirect_stderr
        old = Path.cwd()
        with tempfile.TemporaryDirectory() as temp:
            try:
                os.chdir(temp)
                generator = Path('gen').resolve()
                generator.write_text('#!/bin/sh\ni=0; while [ "$i" -lt 100 ]; do echo same; i=$((i+1)); done\n')
                generator.chmod(0o755)
                config = {'operation': 'stress', 'executable': '/bin/cat', 'brute': '/bin/cat',
                          'generator': str(generator), 'iterations': 1000}
                with redirect_stderr(io.StringIO()):
                    self.assertEqual(engine.execute_stress(config), 0)
                self.assertIn('No difference in 1000 generated cases', Path('test_out').read_text())
            finally: os.chdir(old)

    def test_bounded_diagnostics_do_not_escape_an_entire_megabyte_row(self):
        import tempfile
        old = Path.cwd()
        with tempfile.TemporaryDirectory() as temp:
            try:
                os.chdir(temp)
                Path('input').write_bytes(b'\x01' * 1000000 + b'\n')
                Path('actual').write_bytes(b'wrong\n'); Path('answer').write_bytes(b'expected\n')
                report = engine.Protocol({'report': 'report', 'max_report': 4096})
                comparison = engine.compare_case('actual', 'answer', {})
                engine._failure_details(report, 'input', 'actual', 'answer', comparison, 10000)
                report.finish()
                self.assertLess(Path('report').stat().st_size, 5000)
                self.assertEqual(Path('input').stat().st_size, 1000001)
            finally: os.chdir(old)

    def test_console_capture_limit_is_enforced_incrementally(self):
        with self.assertRaises(engine.CheckSetupError):
            engine._frame_console(io.BytesIO(b'x' * 100000), (io.BytesIO(), io.BytesIO()), maximum=1000)

    def test_incomplete_case_does_not_skip_next_case(self):
        import tempfile
        from contextlib import redirect_stderr
        old = Path.cwd()
        with tempfile.TemporaryDirectory() as temp:
            try:
                os.chdir(temp)
                Path('in.txt').write_bytes(b'x' * 100 + b'\n\nsmall\n')
                Path('ans.txt').write_bytes(Path('in.txt').read_bytes())
                with redirect_stderr(io.StringIO()):
                    status = engine.execute_test({'executable': '/bin/cat', 'auto': True, 'max_line': 10})
                self.assertEqual(status, 4)
                self.assertIn('Test 2: AC', Path('test_out').read_text())
            finally: os.chdir(old)

    def test_console_marker_is_exact_not_multiple_cr_normalization(self):
        incoming, answer = engine.console_payloads(io.BytesIO(b':::answer:::\r\r\n:::answer:::\nanswer\n'))
        self.assertEqual(incoming, b':::answer:::\r\r\n')
        self.assertEqual(answer, b'answer\n')
