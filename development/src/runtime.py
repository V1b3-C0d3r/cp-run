"""Accurate process execution, measurements and soft local-runner limits.

This module is embedded into cp-run.zsh at release time. It deliberately uses
only Python's standard library and never captures or replays program stderr.
Elapsed time is wall time around the child launch/wait, not CPU time or the
time spent importing Python, preparing cases, compiling, or writing reports.
"""

from dataclasses import dataclass
import os
import select
import shlex
import signal
import subprocess
import sys
import time


# @SOURCE_IMPORT_BEGIN@
from memory import MacMemory, LinuxMemory
# @SOURCE_IMPORT_END@

MIB = 1024 * 1024
POLL_NS = 5_000_000  # RSS is sampled every 5 ms; child exit is signal-driven.


@dataclass(frozen=True)
class Result:
    """One process outcome; verdict is separate from its numeric exit code."""

    status: int
    elapsed_ns: int
    peak_bytes: int
    verdict: str


def _budget(value, scale):
    """Return an integer budget, or None for infinity; avoid float clocks."""
    text = str(value)
    if text == "inf":
        return None
    if (not text.isascii() or not text.isdecimal() or len(text) > 12
            or int(text) <= 0):
        raise ValueError("budgets must be positive integers of up to 12 digits or inf")
    return int(text) * scale


def _factor(value):
    """Exact bounded decimal ratio; grace factors must be finite and >= 1."""
    import re
    text = str(value)
    if len(text) > 12 or not re.fullmatch(r'[0-9]+(?:\.[0-9]+)?', text):
        raise ValueError('kill factor must be a finite decimal >= 1 (up to 12 characters)')
    whole, _, fraction = text.partition('.')
    denominator = 10 ** len(fraction)
    numerator = int(whole) * denominator + int(fraction or '0')
    if numerator < denominator: raise ValueError('kill factor must be >= 1')
    return numerator, denominator


def format_usage(value, unit, memory=False):
    """Convert integer base units only for display, using decimal half-up rounding."""
    scales = {'s': 1_000_000_000, 'ms': 1_000_000} if not memory else {
        'B': 1, 'KB': 1000, 'KiB': 1024, 'MB': 1_000_000, 'MiB': MIB}
    if unit not in scales: raise ValueError('unsupported measurement unit: ' + str(unit))
    def shown(target):
        scale = scales[target]
        if memory and target in ('B', 'KiB'):
            return '{} {}'.format((value + scale - 1) // scale, target)
        thousandths = (value * 1000 * 2 + scale) // (2 * scale)
        return '{}.{:03d} {}'.format(thousandths // 1000, thousandths % 1000, target)
    result = shown(unit)
    larger = ({'ms': 's'} if not memory else {'B': 'KiB', 'KiB': 'MiB', 'KB': 'MB'}).get(unit)
    if larger and unit == 'B' and value >= MIB: larger = 'MiB'
    if larger and value >= scales[larger]: result += ' (' + shown(larger) + ')'
    return result


class Runner:
    """Reuse one observer for sequential runs without sharing their clocks.

    stdin/stdout/stderr may be None (inherit), file descriptors or open files.
    Caller owns those files. Exceptions are ValueError/OSError; process errors
    remain Result outcomes. Signal handling requires execution on the main
    Python thread, as it does for the command-line application's entry point.
    """

    def __init__(self, timeout_ms="inf", memory_mib="inf", show_time=False,
                 show_memory=False, show_command=False, time_factor='2', memory_factor='2',
                 time_unit='ms', memory_unit='KiB'):
        self.timeout_text, self.memory_text = str(timeout_ms), str(memory_mib)
        self.timeout_ns = _budget(timeout_ms, 1_000_000)
        self.memory_bytes = _budget(memory_mib, MIB)
        self.show_time, self.show_memory = bool(show_time), bool(show_memory)
        self.show_command = bool(show_command)
        self.time_unit, self.memory_unit = time_unit, memory_unit
        format_usage(0, time_unit); format_usage(0, memory_unit, True)
        self.kill_time_ns = self._threshold(self.timeout_ns, time_factor)
        self.kill_memory_bytes = self._threshold(self.memory_bytes, memory_factor)
        self._running = False
        self.on_launch = None  # Set only for the candidate's first visible execution.
        self.sampler = None
        if self.memory_bytes is not None or self.show_memory:
            if sys.platform == "darwin":
                self.sampler = MacMemory()
            elif sys.platform.startswith("linux"):
                self.sampler = LinuxMemory()
            else:
                raise ValueError("RSS measurement requires macOS or Linux")

    @staticmethod
    def _threshold(budget, factor):
        numerator, denominator = _factor(factor)
        return None if budget is None else (budget * numerator + denominator - 1) // denominator

    def display(self, result, label=None, count=1):
        prefix = 'cp-run: ' + (str(label) + ': ' if label else '')
        suffix = ' ({} measured runs)'.format(count) if count > 1 else ''
        if self.show_time:
            print(prefix + 'time: ' + format_usage(result.elapsed_ns, self.time_unit) + suffix, file=sys.stderr)
        if self.show_memory:
            print(prefix + 'peak RSS: ' + format_usage(result.peak_bytes, self.memory_unit, True) + suffix, file=sys.stderr)
        self.diagnostic(result, label)

    def diagnostic(self, result, label=None):
        prefix = 'cp-run: ' + (str(label) + ': ' if label else '')
        if result.verdict == 'TLE':
            print(prefix + 'TLE: ' + format_usage(result.elapsed_ns, 'ms') + ' exceeds ' + self.timeout_text + ' ms', file=sys.stderr)
        if result.verdict == 'MLE':
            print(prefix + 'MLE: ' + format_usage(result.peak_bytes, 'MiB', True) + ' exceeds ' + self.memory_text + ' MiB', file=sys.stderr)

    @staticmethod
    def _fd(stream):
        if stream is None:
            return None
        fd = stream if isinstance(stream, int) else stream.fileno()
        if fd < 0:
            raise ValueError("program streams must be open file descriptors")
        return fd

    def run(self, argv, stdin=None, stdout=None, label=None, stderr=None, report=True):
        """Launch exactly one argv, then measure until that child exits.

        The clock includes OS launch/wait overhead, as an external wall-clock
        command timer does. It excludes this method's stream validation,
        signal setup and display formatting. No observer can promise a zero
        scheduling error; SIGCHLD avoids introducing a fixed polling delay.
        report=False suppresses observer messages; stream redirection remains
        explicit so callers cannot accidentally hide a measured-run error.
        """
        if self._running:
            raise ValueError("Runner cannot execute concurrent/reentrant calls")
        argv = [os.fspath(arg) for arg in argv]
        if not argv or not argv[0]:
            raise ValueError("expected a nonempty program argv")
        input_fd, output_fd, error_fd = self._fd(stdin), self._fd(stdout), self._fd(stderr)
        prefix = "cp-run: " + (str(label) + ": " if label else "")
        if report and self.show_command:
            display = shlex.join(argv)
            for operator, stream in (("<", stdin), (">", stdout), ("2>", stderr)):
                name = getattr(stream, "name", None)
                if isinstance(name, (str, bytes, os.PathLike)):
                    display += " {} {}".format(operator, shlex.quote(os.fsdecode(name)))
            print(display, file=sys.stderr, flush=True)

        # CLOEXEC pipes wake select on SIGCHLD/signals without capturing any
        # program output. All setup happens before the measurement starts.
        reader, writer = os.pipe()
        os.set_blocking(reader, False)
        os.set_blocking(writer, False)
        handlers, old_wakeup = {}, None
        pid, child, outcome, finished_ns = None, None, None, None
        interrupted, interrupt_deadline = 0, None
        collecting, signalling, pending_signal = False, False, 0
        killed, peak, started_ns = False, 0, None
        early_exit = False
        self._running = True

        def send_group(signum):
            nonlocal signalling, pending_signal
            if pid is None or outcome is not None:
                return
            if collecting:
                pending_signal = signum  # wait4 may already have reaped it.
                return
            if signalling:
                return  # A nested signal is covered by the pending deadline.
            denied = None
            signalling = True
            try:
                # Keep the leader unreaped through this short check+kill
                # section, so its PID cannot become another group's ID.
                if outcome is None:
                    try:
                        os.killpg(pid, signum)
                    except ProcessLookupError:
                        pass
                    except PermissionError as error:
                        denied = error
            finally:
                signalling = False
            if denied is not None:
                # Darwin can report EPERM for a group containing only zombies.
                # Reap after releasing the signal guard; suppress the error only
                # if this child really exited. Never hide a live-child denial.
                collect_exit()
                if outcome is None:
                    raise denied

        def collect_exit():
            nonlocal collecting, outcome, finished_ns, pending_signal
            if pid is None or outcome is not None or collecting or signalling:
                return
            collecting = True  # A Python signal can interrupt a wait4 call.
            try:
                waited, status, usage = os.wait4(pid, os.WNOHANG)
                if waited:
                    finished_ns = time.monotonic_ns()
                    outcome = (status, usage)
            finally:
                collecting = False
                if pending_signal:
                    signum, pending_signal = pending_signal, 0
                    send_group(signum)

        def child_changed(_signum, _frame):
            nonlocal early_exit
            # Record exit promptly, even if SIGCHLD interrupted an RSS sample.
            # The reentrancy guard prevents two wait4 calls reaping one child.
            if pid is None: early_exit = True
            else: collect_exit()

        def forward(signum, _frame):
            nonlocal interrupted, interrupt_deadline
            interrupted = signum
            interrupt_deadline = time.monotonic_ns() + 100_000_000
            send_group(signum)

        try:
            old_wakeup = signal.set_wakeup_fd(writer)
            handlers[signal.SIGCHLD] = signal.signal(signal.SIGCHLD, child_changed)
            for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP, signal.SIGQUIT):
                handlers[signum] = signal.signal(signum, forward)

            # posix_spawn avoids copying an observer's Python address space.
            # Streams stay inherited unless explicitly redirected. A hidden
            # warm-up supplies all three descriptors; measured runs retain
            # the normal stderr contract. report controls observer text only.
            actions = [(os.POSIX_SPAWN_DUP2, fd, target)
                       for fd, target in ((input_fd, 0), (output_fd, 1), (error_fd, 2))
                       if fd is not None and fd != target]
            started_ns = time.monotonic_ns()
            try:
                pid = os.posix_spawnp(argv[0], argv, os.environ,
                                      file_actions=actions, setsid=True)
            except (NotImplementedError, TypeError):
                # Older secondary systems may lack the spawn setsid extension.
                # Keep grouping correct there, even if launch costs more.
                child = subprocess.Popen(argv, stdin=stdin, stdout=stdout, stderr=stderr,
                                         start_new_session=True)
                pid = child.pid
            # A very fast child can exit before posix_spawn returns its PID.
            # Reap immediately, before history I/O: its earlier SIGCHLD could
            # not identify the child, and callback latency is not program time.
            if early_exit: collect_exit()
            if self.on_launch is not None:
                self.on_launch()
            if interrupted:
                forward(interrupted, None)

            while outcome is None:
                # Reap before sampling: completed programs need no extra RSS
                # scan, and their elapsed time must not include its duration.
                collect_exit()
                if outcome is not None:
                    break
                now = time.monotonic_ns()
                if self.sampler is not None and not killed:
                    peak = max(peak, self.sampler.sample(pid))
                if outcome is not None:
                    break
                now = time.monotonic_ns()
                hard_time = (started_ns + self.kill_time_ns
                             if self.kill_time_ns is not None else None)
                force_stop = ((hard_time is not None and now >= hard_time)
                              or (self.memory_bytes is not None
                                  and peak >= self.kill_memory_bytes)
                              or (interrupt_deadline is not None
                                  and now >= interrupt_deadline))
                if force_stop and not killed:
                    send_group(signal.SIGKILL)
                    killed = True
                if outcome is not None:
                    break

                deadlines = [] if killed else [d for d in (
                    hard_time, interrupt_deadline,
                    now + POLL_NS if self.sampler is not None else None,
                ) if d is not None]
                delay = max(0, min(deadlines) - time.monotonic_ns()) / 1e9 if deadlines else None
                ready, _, _ = select.select([reader], [], [], delay)
                if ready:
                    try:
                        os.read(reader, 4096)
                    except BlockingIOError:
                        pass
        except BaseException:
            # Broken accounting must not silently disable a requested limit.
            if pid is not None and outcome is None:
                send_group(signal.SIGKILL)
                while outcome is None:
                    try:
                        waited, status, usage = os.wait4(pid, 0)
                        outcome = (status, usage)
                    except InterruptedError:
                        continue
                    except ChildProcessError:
                        break
            raise
        finally:
            if old_wakeup is not None:
                signal.set_wakeup_fd(old_wakeup)
            for signum, handler in handlers.items():
                signal.signal(signum, handler)
            os.close(reader)
            os.close(writer)
            self._running = False
            if child is not None and outcome is not None:
                child.returncode = os.waitstatus_to_exitcode(outcome[0])

        status, usage = outcome
        elapsed_ns = finished_ns - started_ns
        # Darwin's kernel reports peak RSS in bytes; Linux reports KiB. Kernel
        # accounting catches a brief leader allocation between group samples.
        peak = max(peak, int(usage.ru_maxrss) * (1 if sys.platform == "darwin" else 1024))
        returncode = os.waitstatus_to_exitcode(status)
        native_status = returncode if returncode >= 0 else 128 - returncode
        # User cancellation is an interruption, not a candidate wrong answer.
        # Otherwise nominal budgets decide verdicts, independently of grace.
        if interrupted:
            result = Result(128 + interrupted, elapsed_ns, peak, 'INTERRUPTED')
        elif self.timeout_ns is not None and elapsed_ns > self.timeout_ns:
            result = Result(124, elapsed_ns, peak, 'TLE')
        elif self.memory_bytes is not None and peak > self.memory_bytes:
            result = Result(125, elapsed_ns, peak, 'MLE')
        else:
            result = Result(native_status, elapsed_ns, peak, 'OK' if native_status == 0 else 'RTE')
        if report: self.display(result, label)
        return result
