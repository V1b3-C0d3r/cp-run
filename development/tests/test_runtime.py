"""Numerical timing and real-process regressions for the embedded observer."""

import contextlib
import errno
import importlib.util
import io
import os
from pathlib import Path
import re
import signal
import shutil
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest import mock


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src'))
SOURCE = Path(__file__).resolve().parents[1] / "src/runtime.py"
SPEC = importlib.util.spec_from_file_location("cp_run_runtime", SOURCE)
runtime = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = runtime
SPEC.loader.exec_module(runtime)


class RuntimeTest(unittest.TestCase):
    def python(self, code, **options):
        return runtime.Runner(**options).run([sys.executable, "-c", code])

    def test_sleep_wall_time_is_in_milliseconds(self):
        messages = io.StringIO()
        with contextlib.redirect_stderr(messages):
            result = self.python("import time; time.sleep(.12)", show_time=True)
        shown = float(re.search(r"time: (\d+\.\d{3}) ms", messages.getvalue())[1])
        self.assertEqual(result.status, 0)
        self.assertGreaterEqual(shown, 115)
        self.assertLess(shown, 500)
        self.assertAlmostEqual(shown, result.elapsed_ns / 1e6, delta=.001)

    def test_cpu_work_uses_elapsed_time_not_just_sleep(self):
        result = self.python("import time\nend=time.monotonic()+.08\nwhile time.monotonic()<end: pass")
        self.assertGreaterEqual(result.elapsed_ns, 75_000_000)
        self.assertLess(result.elapsed_ns, 500_000_000)

    def test_external_monotonic_clock_bounds_reported_interval(self):
        runner = runtime.Runner()
        start = time.monotonic_ns()
        result = runner.run(["/bin/sleep", ".06"])
        outer = time.monotonic_ns() - start
        self.assertGreaterEqual(result.elapsed_ns, 55_000_000)
        self.assertLessEqual(result.elapsed_ns, outer)
        self.assertLess(outer - result.elapsed_ns, 100_000_000)

    def test_fast_exit_before_spawn_returns_excludes_history_callback_latency(self):
        clock = mock.Mock(return_value=1_000_000_000)
        pid, duration = 123456789, 30_000_000
        usage = SimpleNamespace(ru_maxrss=0)
        events = []

        def spawn(*_args, **_options):
            clock.return_value += duration
            # Deliver exit before Runner receives the PID, deterministically.
            signal.getsignal(signal.SIGCHLD)(signal.SIGCHLD, None)
            return pid

        def wait(child_pid, options):
            self.assertEqual((child_pid, options), (pid, os.WNOHANG))
            events.append('reap')
            return pid, 0, usage

        def history():
            events.append('history')
            clock.return_value += 250_000_000  # This I/O delay is not program time.

        runner = runtime.Runner()
        runner.on_launch = history
        with mock.patch.object(runtime.time, 'monotonic_ns', clock), \
                mock.patch.object(runtime.os, 'posix_spawnp', side_effect=spawn), \
                mock.patch.object(runtime.os, 'wait4', side_effect=wait), \
                mock.patch.object(runtime.os, 'killpg') as kill:
            result = runner.run(['/controlled/child'])
        self.assertEqual((result.status, result.elapsed_ns), (0, duration))
        self.assertEqual(events, ['reap', 'history'])
        kill.assert_not_called()

    def test_preparation_and_reused_runner_do_not_accumulate(self):
        # An exact virtual interval tests clock ownership independently of
        # loaded CI workers, cold executable startup and scheduler pauses.
        clock = mock.Mock(return_value=1_000_000_000)
        usage = SimpleNamespace(ru_maxrss=0)
        pid, duration = 123456789, 20_000_000

        def completed_child(child_pid, _options):
            self.assertEqual(child_pid, pid)
            clock.return_value += duration
            return pid, 0, usage

        with mock.patch.object(runtime.time, 'monotonic_ns', clock), \
                mock.patch.object(runtime.os, 'posix_spawnp', return_value=pid), \
                mock.patch.object(runtime.os, 'wait4', completed_child), \
                mock.patch.object(runtime.os, 'killpg') as kill:
            runner = runtime.Runner()
            results = []
            for _ in range(3):
                clock.return_value += 10_000_000_000  # Compilation/preparation is outside each run.
                results.append(runner.run(['/controlled/child']))
        self.assertEqual([result.elapsed_ns for result in results], [duration] * 3)
        self.assertEqual([result.status for result in results], [0] * 3)
        kill.assert_not_called()

    def test_silent_run_redirects_both_streams_and_hides_observer_reports(self):
        messages = io.StringIO()
        with tempfile.TemporaryDirectory() as directory:
            output, errors = Path(directory) / 'stdout', Path(directory) / 'stderr'
            with output.open('wb') as stdout, errors.open('wb') as stderr, contextlib.redirect_stderr(messages):
                result = runtime.Runner(show_time=True, show_memory=True, show_command=True).run(
                    [sys.executable, '-c', 'import sys;print("out");print("err",file=sys.stderr)'],
                    stdout=stdout, stderr=stderr, report=False)
            self.assertEqual(result.status, 0)
            self.assertEqual(output.read_bytes(), b'out\n')
            self.assertEqual(errors.read_bytes(), b'err\n')
            self.assertEqual(messages.getvalue(), '')

    def test_silent_timeout_retains_verdict_without_printing_a_warmup_diagnostic(self):
        messages = io.StringIO()
        with contextlib.redirect_stderr(messages):
            result = runtime.Runner(timeout_ms='30', show_time=True).run(['/bin/sleep', '3'], report=False)
        self.assertEqual((result.status, result.verdict), (124, 'TLE'))
        self.assertEqual(messages.getvalue(), '')

    def test_fallback_preserves_stderr_redirection_for_a_silent_run(self):
        with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as errors, \
                mock.patch.object(runtime.os, 'posix_spawnp', side_effect=NotImplementedError):
            result = runtime.Runner().run([sys.executable, '-c', 'import sys;print("err",file=sys.stderr)'],
                                          stdout=output, stderr=errors, report=False)
            self.assertEqual(result.status, 0)
            errors.seek(0)
            self.assertEqual(errors.read(), b'err\n')

    def test_fast_program_is_not_rounded_to_zero_or_sample_period(self):
        runner = runtime.Runner()
        results = [runner.run(["/usr/bin/true"]) for _ in range(5)]
        self.assertTrue(all(0 < result.elapsed_ns < 150_000_000 for result in results))
        # Preserve nanoseconds internally: never quantize to integer ms/ticks.
        self.assertTrue(any(result.elapsed_ns % 1_000_000 for result in results))

    def test_exit_during_slow_memory_sample_does_not_inflate_time(self):
        clock = mock.Mock(return_value=1_000_000_000)
        pid, exited = 123456789, False
        usage = SimpleNamespace(ru_maxrss=0)

        def sample(child_pid):
            nonlocal exited
            self.assertEqual(child_pid, pid)
            clock.return_value += 30_000_000
            exited = True
            signal.getsignal(signal.SIGCHLD)(signal.SIGCHLD, None)
            clock.return_value += 150_000_000  # Sampling continues after child exit.
            return 0

        def wait(child_pid, options):
            self.assertEqual((child_pid, options), (pid, os.WNOHANG))
            return (pid, 0, usage) if exited else (0, 0, None)

        # Deliver completion inside the sample, without assuming a real child
        # can start and finish inside a narrow window on a loaded CI worker.
        runner = runtime.Runner()
        runner.sampler = SimpleNamespace(sample=sample)
        with mock.patch.object(runtime.time, 'monotonic_ns', clock), \
                mock.patch.object(runtime.os, 'posix_spawnp', return_value=pid), \
                mock.patch.object(runtime.os, 'wait4', wait), \
                mock.patch.object(runtime.os, 'killpg') as kill:
            result = runner.run(['/controlled/child'])
        self.assertEqual((result.status, result.elapsed_ns), (0, 30_000_000))
        kill.assert_not_called()

    def test_exit_between_limit_check_and_kill_never_signals_reaped_group(self):
        pid, now, armed, exited = 123456789, 0, False, False
        usage = SimpleNamespace(ru_maxrss=0)

        def sample(child_pid):
            nonlocal armed
            self.assertEqual(child_pid, pid)
            armed = True
            return 0

        def race_clock():
            nonlocal now, armed, exited
            now += 10_000_000
            if armed:
                # Deliver SIGCHLD after the post-sample exit check but before
                # the expired-deadline branch. No sleep assumes child speed.
                armed, exited = False, True
                signal.getsignal(signal.SIGCHLD)(signal.SIGCHLD, None)
            return now

        def wait(child_pid, options):
            self.assertEqual((child_pid, options), (pid, os.WNOHANG))
            return (pid, 0, usage) if exited else (0, 0, None)

        runner = runtime.Runner(timeout_ms='10')
        runner.sampler = SimpleNamespace(sample=sample)
        with mock.patch.object(runtime.time, 'monotonic_ns', race_clock), \
                mock.patch.object(runtime.os, 'posix_spawnp', return_value=pid), \
                mock.patch.object(runtime.os, 'wait4', wait), \
                mock.patch.object(runtime.os, 'killpg') as kill, \
                contextlib.redirect_stderr(io.StringIO()):
            result = runner.run(['/controlled/child'])
        self.assertTrue(exited, 'the controlled SIGCHLD race must have occurred')
        self.assertEqual(result.verdict, 'TLE')
        kill.assert_not_called()

    def test_signal_after_reaping_before_publication_never_signals_reaped_group(self):
        # A cancellation may interrupt wait4 after the kernel has reaped the
        # leader but before Runner has stored its outcome. Defer that signal
        # and discard it once the completed identity is known.
        pid = 123456789
        usage = SimpleNamespace(ru_maxrss=0)

        def wait(child_pid, options):
            self.assertEqual((child_pid, options), (pid, os.WNOHANG))
            signal.getsignal(signal.SIGTERM)(signal.SIGTERM, None)
            kill.assert_not_called()
            return pid, 0, usage

        with mock.patch.object(runtime.os, 'posix_spawnp', return_value=pid), \
                mock.patch.object(runtime.os, 'wait4', wait), \
                mock.patch.object(runtime.os, 'killpg') as kill:
            result = runtime.Runner().run(['/controlled/child'])
        self.assertEqual((result.status, result.verdict), (143, 'INTERRUPTED'))
        kill.assert_not_called()

    def test_signal_during_reap_is_deferred_until_child_identity_is_known(self):
        actual_wait = os.wait4
        injected = False

        def race_wait(pid, options):
            nonlocal injected
            if not injected:
                injected = True
                # The first wait has not returned whether it reaped the child.
                # A cancellation here must not send a signal with stale state.
                signal.getsignal(signal.SIGTERM)(signal.SIGTERM, None)
                self.assertFalse(kill.called)
            return actual_wait(pid, options)

        with mock.patch.object(runtime.os, 'wait4', race_wait), \
                mock.patch.object(runtime.os, 'killpg', wraps=os.killpg) as kill:
            result = runtime.Runner().run(['/bin/sleep', '.05'])
        self.assertEqual(result.verdict, 'INTERRUPTED')
        self.assertEqual(result.status, 143)
        self.assertTrue(kill.called, 'the deferred signal must still be forwarded')

    def test_timeout_grace_kills_at_double_budget(self):
        with contextlib.redirect_stderr(io.StringIO()) as errors:
            result = self.python("import time; time.sleep(8)", timeout_ms="70")
        self.assertEqual((result.status, result.verdict), (124, "TLE"))
        self.assertGreaterEqual(result.elapsed_ns, 135_000_000)
        self.assertLess(result.elapsed_ns, 600_000_000)
        self.assertIn("exceeds 70 ms", errors.getvalue())

    def test_nominal_timeout_can_fail_before_double_budget(self):
        clock = mock.Mock(return_value=1_000_000_000)
        pid, duration = 123456789, 110_000_000
        usage = SimpleNamespace(ru_maxrss=0)

        def wait(child_pid, options):
            self.assertEqual((child_pid, options), (pid, os.WNOHANG))
            clock.return_value += duration
            return pid, 0, usage  # Natural successful exit, before the kill threshold.

        with mock.patch.object(runtime.time, 'monotonic_ns', clock), \
                mock.patch.object(runtime.os, 'posix_spawnp', return_value=pid), \
                mock.patch.object(runtime.os, 'wait4', wait), \
                mock.patch.object(runtime.os, 'killpg') as kill, \
                contextlib.redirect_stderr(io.StringIO()):
            result = runtime.Runner(timeout_ms='90').run(['/controlled/child'])
        self.assertEqual((result.status, result.verdict, result.elapsed_ns), (124, 'TLE', duration))
        kill.assert_not_called()

    def test_group_permission_error_requires_confirmed_child_exit(self):
        # Model Darwin's EPERM for a zombie-only group separately from a real
        # permission failure against a live child. Only the former is benign.
        for completes in (True, False):
            with self.subTest(child_completed=completes):
                clock = mock.Mock(return_value=1_000_000_000)
                pid, exited = 123456789, False
                usage = SimpleNamespace(ru_maxrss=0)
                denied = PermissionError(errno.EPERM, 'group signalling denied')
                old_handler = signal.getsignal(signal.SIGCHLD)

                def sample(child_pid):
                    self.assertEqual(child_pid, pid)
                    clock.return_value += 30_000_000  # Cross the 20 ms kill threshold.
                    return 0

                def wait(child_pid, options):
                    self.assertEqual((child_pid, options), (pid, os.WNOHANG))
                    return (pid, 0, usage) if exited else (0, 0, None)

                def deny(child_pid, signum):
                    nonlocal exited
                    self.assertEqual((child_pid, signum), (pid, signal.SIGKILL))
                    exited = completes
                    raise denied

                runner = runtime.Runner(timeout_ms='10')
                runner.sampler = SimpleNamespace(sample=sample)
                with mock.patch.object(runtime.time, 'monotonic_ns', clock), \
                        mock.patch.object(runtime.os, 'posix_spawnp', return_value=pid), \
                        mock.patch.object(runtime.os, 'wait4', wait), \
                        mock.patch.object(runtime.os, 'killpg', side_effect=deny) as kill, \
                        mock.patch.object(runtime.os, 'kill', side_effect=denied), \
                        contextlib.redirect_stderr(io.StringIO()):
                    if completes:
                        result = runner.run(['/controlled/child'])
                        self.assertEqual((result.status, result.verdict), (124, 'TLE'))
                        kill.assert_called_once_with(pid, signal.SIGKILL)
                    else:
                        with self.assertRaises(PermissionError) as error:
                            runner.run(['/controlled/child'])
                        self.assertIs(error.exception, denied)
                self.assertFalse(runner._running)
                self.assertIs(signal.getsignal(signal.SIGCHLD), old_handler)

    def test_group_eperm_before_exit_is_waitable_uses_owned_leader(self):
        pid, signalled, wait_after_signal = 123456789, False, 0
        clock = mock.Mock(return_value=1_000_000_000)
        usage = SimpleNamespace(ru_maxrss=0)

        def sample(_pid):
            clock.return_value += 30_000_000
            return 0

        def kill_leader(child_pid, signum):
            nonlocal signalled
            self.assertEqual((child_pid, signum), (pid, signal.SIGKILL))
            signalled = True

        def wait(child_pid, options):
            nonlocal wait_after_signal
            self.assertEqual((child_pid, options), (pid, os.WNOHANG))
            if signalled:
                wait_after_signal += 1
                if wait_after_signal >= 2:
                    return pid, signal.SIGKILL, usage
            return 0, 0, None

        runner = runtime.Runner(timeout_ms='10')
        runner.sampler = SimpleNamespace(sample=sample)
        with mock.patch.object(runtime.time, 'monotonic_ns', clock), \
                mock.patch.object(runtime.os, 'posix_spawnp', return_value=pid), \
                mock.patch.object(runtime.os, 'wait4', side_effect=wait), \
                mock.patch.object(runtime.os, 'killpg', side_effect=PermissionError(errno.EPERM, 'exiting group')), \
                mock.patch.object(runtime.os, 'kill', side_effect=kill_leader) as direct, \
                mock.patch.object(runtime.select, 'select', return_value=([], [], [])):
            result = runner.run(['/controlled/child'], report=False)
        self.assertEqual((result.status, result.verdict), (124, 'TLE'))
        direct.assert_called_once_with(pid, signal.SIGKILL)
        self.assertEqual(wait_after_signal, 2)

    def test_group_timeout_stops_grandchild(self):
        script = (
            "import os,time,sys\n"
            "sys.path.insert(0, {!r})\n"
            "from runtime import Runner\n"
            "r=Runner(timeout_ms='70').run([sys.executable,'-c',"
            "'import os,time; os.fork(); time.sleep(8)'])\n"
            "raise SystemExit(r.status)\n"
        ).format(str(SOURCE.parent))
        result = subprocess.run([sys.executable, "-c", script], capture_output=True,
                                text=True, timeout=3)
        self.assertEqual(result.returncode, 124, result.stderr)

    def test_kernel_peak_catches_brief_allocation(self):
        with contextlib.redirect_stderr(io.StringIO()):
            result = self.python("a=bytearray(64*1024*1024)", memory_mib="24")
        self.assertEqual((result.status, result.verdict), (125, "MLE"))
        self.assertGreater(result.peak_bytes, 48 * runtime.MIB)

    def test_time_has_priority_when_both_nominal_budgets_exceeded(self):
        with contextlib.redirect_stderr(io.StringIO()):
            result = self.python("import time; a=bytearray(24*1024*1024); time.sleep(.11)",
                                 timeout_ms="90", memory_mib="24")
        self.assertEqual(result.verdict, "TLE")

    def test_stream_files_and_literal_arguments(self):
        with tempfile.TemporaryDirectory() as folder:
            incoming = Path(folder) / "input"
            outgoing = Path(folder) / "output"
            incoming.write_bytes(b"native input\n")
            with incoming.open("rb") as source, outgoing.open("wb") as target:
                result = runtime.Runner().run([sys.executable, "-c",
                    "import sys; print(repr(sys.argv[1:])); print(sys.stdin.read(),end='')",
                    "a b", "--", ""], stdin=source, stdout=target)
            self.assertEqual(result.status, 0)
            self.assertEqual(outgoing.read_text(), "['a b', '--', '']\nnative input\n")

    def test_signal_exit_remains_native(self):
        result = self.python("import os,signal; os.kill(os.getpid(),signal.SIGTERM)")
        self.assertEqual((result.status, result.verdict), (143, "RTE"))

    def test_nonzero_exit_is_not_wrong_answer(self):
        result = self.python("raise SystemExit(3)")
        self.assertEqual((result.status, result.verdict), (3, "RTE"))

    def test_invalid_budgets_and_streams(self):
        for value in ("0", "-1", "1.5", "INF", "", "١", "1" * 13):
            with self.assertRaises(ValueError):
                runtime.Runner(timeout_ms=value)
        with self.assertRaises(ValueError):
            runtime.Runner().run(["/usr/bin/true"], stdout=-1)

    def test_missing_executable_raises_without_leaking_handlers(self):
        old = signal.getsignal(signal.SIGCHLD)
        with self.assertRaises(FileNotFoundError):
            runtime.Runner().run(["/does/not/exist"])
        self.assertIs(signal.getsignal(signal.SIGCHLD), old)
        self.assertEqual(runtime.Runner().run(["/usr/bin/true"]).status, 0)

    def test_cancel_escalates_when_program_ignores_signal(self):
        with tempfile.TemporaryDirectory() as folder:
            ready = Path(folder) / "ready"
            child = ("import signal,time,pathlib; signal.signal(signal.SIGTERM,signal.SIG_IGN); "
                     "pathlib.Path({!r}).touch(); time.sleep(8)").format(str(ready))
            script = ("import sys; sys.path.insert(0,{!r}); from runtime import Runner; "
                      "r=Runner().run([sys.executable,'-c',{!r}]); raise SystemExit(r.status)").format(
                          str(SOURCE.parent), child)
            process = subprocess.Popen([sys.executable, "-c", script], stdout=subprocess.PIPE,
                                       stderr=subprocess.PIPE, text=True)
            try:
                deadline = time.monotonic() + 3
                while not ready.exists() and time.monotonic() < deadline:
                    time.sleep(.005)
                self.assertTrue(ready.exists())
                process.terminate()
                _, errors = process.communicate(timeout=3)
                self.assertEqual(process.returncode, 143, errors)
            finally:
                if process.poll() is None:
                    process.kill(); process.communicate()

    def test_terminal_input_is_not_replaced_by_a_pipe(self):
        master, slave = os.openpty()
        script = ("import sys; sys.path.insert(0,{!r}); from runtime import Runner; "
                  "r=Runner().run([sys.executable,'-c',"
                  "'import os; print(os.isatty(0)); print(input())']); "
                  "raise SystemExit(r.status)").format(str(SOURCE.parent))
        process = subprocess.Popen([sys.executable, "-c", script], stdin=slave,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        os.close(slave)
        try:
            os.write(master, b"terminal input\n")
            output, errors = process.communicate(timeout=3)
            self.assertEqual(process.returncode, 0, errors)
            self.assertEqual(output, "True\nterminal input\n")
        finally:
            os.close(master)
            if process.poll() is None:
                process.kill(); process.communicate()

    def test_fresh_cpp_binary_cold_and_warm_match_external_timer(self):
        compiler = shutil.which('clang++') or shutil.which('g++')
        if compiler is None:
            self.skipTest('a real C++ compiler is not installed')
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / 'timer.cpp'
            binary = Path(folder) / 'timer'
            source.write_text(
                '#include <chrono>\n#include <cstdio>\n#include <thread>\n'
                'int main(){auto a=std::chrono::steady_clock::now();'
                'std::this_thread::sleep_for(std::chrono::milliseconds(80));'
                'auto n=std::chrono::duration_cast<std::chrono::nanoseconds>('
                'std::chrono::steady_clock::now()-a).count();'
                'std::printf("%lld\\n",(long long)n);}\n')
            built = subprocess.run([compiler, '-std=c++17', str(source), '-o', str(binary)],
                                   capture_output=True, text=True, timeout=30)
            self.assertEqual(built.returncode, 0, built.stderr)
            runner = runtime.Runner()
            for launch in ('cold', 'warm'):
                with self.subTest(launch=launch), tempfile.TemporaryFile() as output:
                    start = time.monotonic_ns()
                    result = runner.run([str(binary)], stdout=output)
                    external_ns = time.monotonic_ns() - start
                    output.seek(0)
                    main_ns = int(output.read())
                    # Main's own timer excludes loader/signature validation.
                    # Both external timers include it, including a cold run.
                    self.assertGreaterEqual(result.elapsed_ns, main_ns)
                    self.assertGreaterEqual(main_ns, 75_000_000)
                    self.assertLessEqual(result.elapsed_ns, external_ns)
                    self.assertLess(external_ns - result.elapsed_ns, 150_000_000)


if __name__ == "__main__":
    unittest.main()
