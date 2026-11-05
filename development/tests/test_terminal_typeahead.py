"""Queued terminal input survives preparation with exactly one kernel echo."""

import errno
import json
import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import sys
import tempfile
import termios
import time
import unittest

from _paths import RELEASE


class TerminalTypeaheadTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cp-run-typeahead-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.script = RELEASE / 'cp-run.zsh'
        self.source = self.root / 'main.cpp'
        self.source.write_text('int main() {}\n')
        self.program = self.root / 'reader.py'
        self.program.write_text('#!' + sys.executable + '\n'
            'import os, pathlib, sys\n'
            'print("READY", flush=True)\n'
            'data = b"".join(sys.stdin.buffer.readline() for _ in range(int(os.environ.get("INPUT_LINES", "1"))))\n'
            'pathlib.Path("received").write_bytes(data)\n'
            'with open("runs", "ab") as f: f.write(b"run\\n")\n')
        self.program.chmod(0o755)
        self.compiler = self.root / 'compiler'
        # The gate proves input arrived during compilation, independently of
        # compiler speed or CI load. The generated executable stays silent
        # after READY, so every displayed input byte must be terminal echo.
        self.compiler.write_text('#!' + sys.executable + '\n'
            'import os, pathlib, shutil, sys\n'
            'args = sys.argv[1:]\n'
            'if args == ["--version"]: print("GNU GCC fixture"); sys.exit(0)\n'
            'if args == ["--help=c++"]: print("-std=c++17"); sys.exit(0)\n'
            'if os.environ.get("COMPILER_GATE"):\n'
            ' print("COMPILING", flush=True)\n'
            ' with open(os.environ["COMPILER_GATE"], "rb", buffering=0) as f: f.read(1)\n'
            'if os.environ.get("COMPILE_FAIL"): sys.exit(9)\n'
            'target = pathlib.Path(args[args.index("-o") + 1])\n'
            'shutil.copyfile(os.environ["READER_PROGRAM"], target)\n'
            'target.chmod(0o755)\n')
        self.compiler.chmod(0o755)
        self.env = dict(os.environ, CXX=str(self.compiler),
                        READER_PROGRAM=str(self.program),
                        XDG_STATE_HOME=str(self.root / 'state'))
        self.binary = self.root / 'main.out'
        # The bug needs an existing history scope, as in a real workspace.
        result = self.invoke('compile', self.source, '-o', self.binary)
        self.assertEqual(result.returncode, 0, result.stderr)

    def invoke(self, *args, **kwargs):
        return subprocess.run([str(self.script), *map(str, args)], cwd=self.root,
                              env=self.env, capture_output=True, timeout=15, **kwargs)

    def terminal(self, args=(), early=b'27491\n', late=b'', before_launch=False,
                 fail=False, cancel=False, lines=1):
        gate = self.root / 'gate'
        os.mkfifo(gate)
        gate_fd = os.open(gate, os.O_RDWR | os.O_NONBLOCK)
        self.addCleanup(os.close, gate_fd)
        env = dict(self.env, INPUT_LINES=str(lines))
        argv = [str(self.script), *map(str, args)]
        if before_launch:
            # Plain newline read from a FIFO does not touch tty modes. Queue
            # bytes before exec to exercise both source and binary recall.
            argv = ['zsh', '-f', '-c',
                    'print STARTING; IFS= read -r release < "$1"; shift; exec "$@"',
                    'gate', str(gate), *argv]
            marker = b'STARTING\r\n'
        else:
            env['COMPILER_GATE'] = str(gate)
            marker = b'COMPILING\r\n'
        if fail:
            env['COMPILE_FAIL'] = '1'
        pid, master = pty.fork()
        if pid == 0:
            os.chdir(self.root)
            os.execvpe(argv[0], argv, env)
        output = bytearray()
        waited = False
        deadline = time.monotonic() + 15

        def read_chunk():
            remaining = deadline - time.monotonic()
            self.assertGreater(remaining, 0, bytes(output))
            ready, _, _ = select.select([master], [], [], remaining)
            self.assertTrue(ready, bytes(output))
            try:
                data = os.read(master, 65536)
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                data = b''  # Linux PTYs report EIO when the slave closes.
            output.extend(data)
            return bool(data)

        def until(text):
            while text not in output:
                self.assertTrue(read_chunk(), bytes(output))

        try:
            initial = termios.tcgetattr(master)
            until(marker)
            if early:
                os.write(master, early)
                until(early.replace(b'\n', b'\r\n'))
            if cancel:
                os.killpg(pid, signal.SIGINT)
            else:
                os.write(gate_fd, b'!\n')
                if not fail:
                    if '-t' in args:
                        until(b'Ctrl-D')
                        if late:
                            os.write(master, late)
                            late = b''
                        os.write(master, b'\x04')
                    until(b'READY\r\n')
                    if late:
                        os.write(master, late)
            while read_chunk():
                pass
            _, status = os.waitpid(pid, 0)
            waited = True
            final = termios.tcgetattr(master)
            self.assertEqual(final, initial, bytes(output))
            return os.waitstatus_to_exitcode(status), bytes(output).split(marker, 1)[1].replace(b'\r\n', b'\n')
        finally:
            if not waited:
                try:
                    os.killpg(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                os.waitpid(pid, 0)
            os.close(master)

    def check_input(self, early, late=b'', args=(), **kwargs):
        status, output = self.terminal(args, early, late, **kwargs)
        self.assertEqual(status, 0, output)
        self.assertEqual(output, early + b'READY\n' + late)
        self.assertEqual((self.root / 'received').read_bytes(), early + late)

    def test_complete_line_during_compilation(self):
        self.check_input(b'27491\n')

    def test_multiline_paste_during_compilation(self):
        self.check_input(b'27491\nsecond line\n', lines=2)

    def test_partial_line_spans_compilation_and_execution(self):
        self.check_input(b'274', b'91\n')

    def test_input_after_execution_starts(self):
        self.check_input(b'', b'27491\n')

    def test_input_before_cp_run_starts(self):
        self.check_input(b'27491\n', before_launch=True)

    def test_source_history_recall_preserves_queued_input(self):
        self.check_input(b'27491\n', args=('-',), before_launch=True)

    def test_binary_history_recall_preserves_queued_input(self):
        first = self.invoke('run', self.binary, input=b'seed\n')
        self.assertEqual(first.returncode, 0, first.stderr)
        self.check_input(b'27491\n', args=('run', '-'), before_launch=True)

    def test_measured_run_preserves_queued_input(self):
        status, output = self.terminal(('-t', '--warm-up=0'))
        self.assertEqual(status, 0, output)
        self.assertEqual(output.count(b'27491\n'), 1, output)
        self.assertEqual((self.root / 'received').read_bytes(), b'27491\n')
        self.assertEqual((self.root / 'runs').read_bytes(), b'run\n' * 2)

    def test_repeated_runs_replay_input_with_one_visible_echo(self):
        status, output = self.terminal(('-t', '--average=3', '--warm-up=1'))
        self.assertEqual(status, 0, output)
        self.assertEqual(output.count(b'27491\n'), 1, output)
        self.assertEqual(output.count(b'READY\n'), 1, output)
        self.assertEqual((self.root / 'received').read_bytes(), b'27491\n')
        self.assertEqual((self.root / 'runs').read_bytes(), b'run\n' * 5)

    def test_compile_failure_preserves_terminal_and_does_not_run(self):
        status, output = self.terminal(fail=True)
        self.assertEqual(status, 9, output)
        self.assertEqual(output, b'27491\n')
        self.assertFalse((self.root / 'received').exists())

    def test_compile_cancellation_preserves_terminal_and_does_not_run(self):
        status, output = self.terminal(cancel=True)
        self.assertIn(status, (130, -signal.SIGINT), output)
        self.assertEqual(output.count(b'27491\n'), 1, output)
        self.assertNotIn(b'READY', output)
        self.assertFalse((self.root / 'received').exists())

    def binary_record(self):
        result = self.invoke('run', self.binary, input=b'seed\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        return next((self.root / 'state').rglob('binary'))

    def test_history_preserves_newlines_and_empty_interpreter_arguments(self):
        source = self.root / 'reader with spaces\nand newline.py'
        source.write_text('import json, sys\nprint(json.dumps(sys.warnoptions))\n')
        record = self.binary_record()
        fields = [str(source), 'CP_RUN_ARGV_V1', sys.executable, '-W', '', str(source)]
        record.write_bytes(('\0'.join(fields) + '\0').encode())
        result = self.invoke('run', '-')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), [''])

    def test_truncated_history_is_rejected_before_launch(self):
        record = self.binary_record()
        record.write_bytes(record.read_bytes().rstrip(b'\0'))
        (self.root / 'received').unlink()
        result = self.invoke('run', '-')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn(b'invalid history record', result.stderr)
        self.assertFalse((self.root / 'received').exists())

    def test_unknown_history_format_is_rejected_before_launch(self):
        record = self.binary_record()
        record.write_bytes((str(self.binary) + '\0UNKNOWN\0').encode())
        result = self.invoke('run', '-')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn(b'unsupported launch history record', result.stderr)

    def test_history_argument_limit_is_retained(self):
        record = self.binary_record()
        record.write_bytes(('\0'.join([str(self.program), 'CP_RUN_ARGV_V1']
                                     + ['argument'] * 257) + '\0').encode())
        result = self.invoke('run', '-')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn(b'launch history has too many arguments', result.stderr)


if __name__ == '__main__':
    unittest.main()
