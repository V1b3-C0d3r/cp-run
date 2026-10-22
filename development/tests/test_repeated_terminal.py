"""Ordinary measurements record one visible terminal run, then replay silently."""

import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

from _paths import RELEASE, load_engine

engine = load_engine('cp_run_repeated_terminal')


class RepeatedTerminalTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cp-run-live-repeat-')
        self.root = Path(self.temporary.name).resolve()
        self.env = dict(os.environ, XDG_STATE_HOME=str(self.root / 'state'))
        self.source = self.root / 'main.py'
        self.script = RELEASE / 'cp-run.zsh'

    def tearDown(self):
        self.temporary.cleanup()

    def program(self, reads=True, fail=0):
        self.source.write_text(
            'from pathlib import Path\nimport sys\n'
            'p=Path("count"); i=int(p.read_text())+1 if p.exists() else 1; p.write_text(str(i))\n'
            + ('data=sys.stdin.readline().rstrip("\\n")\n' if reads else 'data="no input"\n')
            + 'print(f"stdout {i}: {data}", flush=True)\n'
              'print(f"stderr {i}", file=sys.stderr, flush=True)\n'
            + 'raise SystemExit(7 if i == ' + str(fail) + ' else 0)\n')

    def args(self, average=3, warmup=1):
        return [str(self.script), 'run', str(self.source), '--interpreter=' + sys.executable,
                '-tm', '--average=' + str(average), '--warm-up=' + str(warmup)]

    def terminal(self, data=None, average=3, warmup=1):
        master, slave = pty.openpty()
        process = None
        try:
            process = subprocess.Popen(self.args(average, warmup), cwd=self.root, env=self.env,
                                       stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                       text=True)
            if data is not None: os.write(master, data)
            stdout, stderr = process.communicate(timeout=15)
            return process.returncode, stdout, stderr
        finally:
            os.close(master); os.close(slave)
            if process is not None and process.poll() is None:
                process.kill(); process.communicate()

    def test_terminal_input_is_replayed_without_waiting_for_eof(self):
        self.program()
        status, stdout, stderr = self.terminal(b'hello world\n')
        self.assertEqual((status, stdout), (0, 'stdout 1: hello world\n'), stderr)
        self.assertEqual((self.root / 'count').read_text(), '5')  # visible + warm-up + 3 measurements
        self.assertIn('stderr 1\n', stderr)
        for number in range(2, 6): self.assertNotIn('stderr ' + str(number), stderr)
        self.assertIn('3 measured runs', stderr)

    def test_no_input_program_finishes_with_an_open_terminal(self):
        self.program(reads=False)
        status, stdout, stderr = self.terminal()
        self.assertEqual((status, stdout), (0, 'stdout 1: no input\n'), stderr)
        self.assertEqual((self.root / 'count').read_text(), '5')

    def test_hidden_failure_returns_its_status_and_complete_stderr(self):
        self.program(fail=3)
        status, stdout, stderr = self.terminal(b'once\n', average=5, warmup=0)
        self.assertEqual((status, stdout), (7, 'stdout 1: once\n'), stderr)
        self.assertEqual((self.root / 'count').read_text(), '3')
        self.assertIn('stderr 3\n', stderr)
        self.assertNotIn('stderr 2\n', stderr)
        self.assertNotIn('stdout 3', stdout)

    def test_first_visible_failure_stops_without_repetitions(self):
        self.program(fail=1)
        status, stdout, stderr = self.terminal(b'first\n')
        self.assertEqual((status, stdout), (7, 'stdout 1: first\n'), stderr)
        self.assertIn('stderr 1\n', stderr)
        self.assertEqual((self.root / 'count').read_text(), '1')

    def test_replayed_warmup_failure_is_not_discarded(self):
        self.program(fail=2)
        status, stdout, stderr = self.terminal(b'first\n')
        self.assertEqual((status, stdout), (7, 'stdout 1: first\n'), stderr)
        self.assertIn('stderr 2\n', stderr)
        self.assertEqual((self.root / 'count').read_text(), '2')

    def test_pipe_keeps_one_visible_measured_stdout_and_hides_later_stderr(self):
        self.program()
        result = subprocess.run(self.args(), cwd=self.root, env=self.env, input='pipe\n',
                                capture_output=True, text=True, timeout=15)
        self.assertEqual((result.returncode, result.stdout), (0, 'stdout 2: pipe\n'), result.stderr)
        self.assertEqual((self.root / 'count').read_text(), '4')
        self.assertIn('stderr 2\n', result.stderr)
        for number in (1, 3, 4): self.assertNotIn('stderr ' + str(number), result.stderr)

    def test_single_measurement_with_warmup_reuses_recorded_terminal_input(self):
        self.program()
        status, stdout, stderr = self.terminal(b'one measurement\n', average=1, warmup=1)
        self.assertEqual((status, stdout), (0, 'stdout 1: one measurement\n'), stderr)
        self.assertEqual((self.root / 'count').read_text(), '3')

    def test_input_relay_descriptors_do_not_leak_to_the_program(self):
        self.source.write_text('import os\nfor fd in range(3, 64):\n'
            ' try: os.fstat(fd)\n except OSError: continue\n'
            ' raise SystemExit("leaked fd " + str(fd))\nprint("OK")\n')
        status, stdout, stderr = self.terminal(warmup=0)
        self.assertEqual((status, stdout), (0, 'OK\n'), stderr)

    def test_terminal_input_spool_is_bounded(self):
        script = self.root / 'small-spool.zsh'
        text = self.script.read_text()
        script.write_text(text); script.chmod(0o755)
        data = engine.read_settings(text); data['MAX_SPOOL_BYTES'] = '4'
        engine.save_settings(script, text, data)
        self.script = script
        self.program()
        status, stdout, stderr = self.terminal(b'too much input\n', warmup=0)
        self.assertEqual(status, 1, stderr)
        self.assertIn('spool byte limit', stderr)
        self.assertEqual((self.root / 'count').read_text(), '1')

    def test_terminal_capture_is_outside_the_reported_median(self):
        initial = engine.Result(0, 9_000_000_000, 100, 'OK')
        runner = mock.Mock()
        runner.run.side_effect = [engine.Result(0, n, 10, 'OK') for n in (10, 30, 20)]
        config = {'executable': '/controlled/program', 'average': 3, 'warmup': False,
                  'show_time': True, 'show_memory': False, 'runtime_args': []}
        with mock.patch.object(engine, '_runner', return_value=runner), \
                mock.patch.object(engine.os, 'isatty', return_value=True), \
                mock.patch.object(engine, 'record_terminal_input', return_value=initial):
            self.assertEqual(engine.supervise(config), 0)
        self.assertEqual(runner.run.call_count, 3)
        shown = runner.display.call_args[0][0]
        self.assertEqual(shown.elapsed_ns, 20)

    def test_capture_cancellation_does_not_start_hidden_runs(self):
        self.source.write_text('from pathlib import Path\nimport sys\nPath("started").touch()\nprint("ready",flush=True)\nsys.stdin.read()\n')
        master, slave = pty.openpty()
        process = subprocess.Popen(self.args(), cwd=self.root, env=self.env, stdin=slave,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                   start_new_session=True)
        try:
            ready, _, _ = select.select([process.stdout], [], [], 10)
            self.assertTrue(ready)
            self.assertEqual(process.stdout.readline(), 'ready\n')
            os.killpg(process.pid, signal.SIGTERM)
            stdout, stderr = process.communicate(timeout=5)
            self.assertIn(process.returncode, (143, -signal.SIGTERM), stderr)
            self.assertNotIn('measured runs', stderr)
        finally:
            os.close(master); os.close(slave)
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL); process.communicate()


if __name__ == '__main__':
    unittest.main()
