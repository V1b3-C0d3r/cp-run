"""Repeated runs reuse one supervisor and expose one visible stdout only."""

from contextlib import ExitStack
import stat
import tempfile


def repetition_count(value):
    text = str(value)
    if not text.isascii() or not text.isdecimal() or len(text) > 6:
        raise ValueError('average must be an integer from 0 to 100000')
    number = int(text)
    if number > 100000: raise ValueError('average must not exceed 100000')
    return max(1, number)


def run_series(runner, config, launch, validate=None, label=None):
    """Warm once, then aggregate valid executions; failures never disappear in a median."""
    config['_series_runs'] = 0
    observed = bool(config.get('show_time') or config.get('show_memory'))
    count = repetition_count(config.get('average', 1)) if observed else 1
    if observed and config.get('warmup'):
        warm = launch(-1)
        if warm.verdict in ('INTERRUPTED', 'TLE', 'MLE') or ((config.get('operation') in ('test', 'stress') or config.get('_strict_warmup')) and warm.status):
            if config.get('operation') not in ('test', 'stress'): runner.diagnostic(warm, label)
            return warm
    durations, peak, result = [], 0, None
    for index in range(count):
        result = launch(index)
        config['_series_runs'] = index + 1
        durations.append(result.elapsed_ns); peak = max(peak, result.peak_bytes)
        if not result.status and validate is not None:
            verdict = validate(index)
            if verdict:
                result = Result(4 if verdict == 'INCOMPLETE' else 3,
                                result.elapsed_ns, result.peak_bytes, verdict)
        if result.status: break
    if not result.status:
        durations.sort(); middle = len(durations) // 2
        median = durations[middle] if len(durations) % 2 else (durations[middle - 1] + durations[middle] + 1) // 2
        result = Result(0, median, peak, 'OK')
    else:
        result = Result(result.status, result.elapsed_ns, peak, result.verdict)
    if config.get('operation') not in ('test', 'stress'): runner.display(result, label, len(durations))
    return result


def record_terminal_input(runner, argv, recording, maximum):
    """Run visibly while teeing terminal input to a bounded replay file.

    The relay reads only while the child runs, so a program needing no input
    never waits for terminal EOF. A stop pipe wakes it immediately on exit or
    cancellation. Only this explicit repeated-TTY path starts a helper thread.
    """
    import threading

    failures = []
    with ExitStack() as stack:
        reader_fd, writer_fd = os.pipe()
        incoming = stack.enter_context(os.fdopen(reader_fd, 'rb', buffering=0))
        outgoing = stack.enter_context(os.fdopen(writer_fd, 'wb', buffering=0))
        stop_reader, stop_writer = os.pipe()
        stack.callback(os.close, stop_reader)
        stack.callback(os.close, stop_writer)
        os.set_blocking(writer_fd, False)

        def relay():
            pending, copied = b'', 0
            try:
                while True:
                    readable, writable, _ = select.select(
                        [stop_reader] + ([] if pending else [0]),
                        [writer_fd] if pending else [], [], None)
                    if stop_reader in readable:
                        return
                    if 0 in readable:
                        block = os.read(0, 65536)
                        if not block:
                            return
                        copied += len(block)
                        if copied > maximum:
                            raise CheckSetupError('replayed input exceeds spool byte limit')
                        recording.write(block)
                        pending = block
                    if writer_fd in writable:
                        try:
                            pending = pending[os.write(writer_fd, pending):]
                        except BlockingIOError:
                            continue
            except BrokenPipeError:
                pass  # Child exited or deliberately closed stdin.
            except BaseException as error:
                failures.append(error)
            finally:
                outgoing.close()  # Deliver EOF when the terminal supplied EOF.

        thread = threading.Thread(target=relay, name='cp-run-input', daemon=True)
        thread.start()
        try:
            result = runner.run(argv, stdin=incoming, report=False)
        finally:
            os.write(stop_writer, b'!')
            thread.join()
        if failures:
            raise failures[0]
        recording.flush()
        recording.seek(0)
        return result


def replay_stderr(source):
    """Replay a failed hidden run byte-for-byte without buffering it in RAM."""
    source.seek(0)
    with os.fdopen(os.dup(2), 'wb') as destination:
        shutil.copyfileobj(source, destination)


def supervise(config):
    """One visible run; copied input and hidden repetitions share one observer."""
    runner = _runner(config)
    argv = [*config.get('main_argv', [config['executable']]), *config.get('runtime_args', [])]
    observed = bool(config.get('show_time') or config.get('show_memory'))
    count = repetition_count(config.get('average', 1)) if observed else 1
    with ExitStack() as stack:
        sink = stack.enter_context(open(os.devnull, 'wb'))
        errors = stack.enter_context(tempfile.TemporaryFile())
        replay, replay_offset, captured_terminal = None, 0, False
        if count > 1 or (observed and config.get('warmup')):
            maximum = positive_setting(config.get('max_spool', 268435456), 'spool limit')
            if os.isatty(0):
                replay = stack.enter_context(tempfile.TemporaryFile())
                if config.get('show_command'):
                    print(shlex.join(argv), file=sys.stderr, flush=True)
                runner.on_launch = lambda: remember_launch(config)
                # This visible capture is not a measurement: human typing must
                # not contaminate the median. Its errors still stop the job.
                initial = record_terminal_input(runner, argv, replay, maximum)
                if initial.status:
                    runner.diagnostic(initial)
                    return initial.status
                captured_terminal = True
            else:
                source = stack.enter_context(os.fdopen(os.dup(0), 'rb'))
                if stat.S_ISREG(os.fstat(0).st_mode):
                    replay = source; replay_offset = source.tell()
                else:
                    replay = stack.enter_context(tempfile.TemporaryFile())
                    copied = 0
                    while True:
                        block = source.read(65536)
                        if not block: break
                        copied += len(block)
                        if copied > maximum: raise CheckSetupError('replayed input exceeds spool byte limit')
                        replay.write(block)
        # Ordinary warm-ups now receive the same recorded data as measurements;
        # every nonzero execution must stop the series and expose its stderr.
        series_config = dict(config, _strict_warmup=True)

        def launch(index):
            if replay is not None:
                replay.seek(replay_offset); incoming = replay
            else:
                incoming = None
            visible = index == 0 and not captured_terminal
            if visible and config.get('show_command'):
                print(shlex.join(argv), file=sys.stderr, flush=True)
            runner.on_launch = (lambda: remember_launch(config)) if index >= 0 else None
            errors.seek(0); errors.truncate()
            result = runner.run(argv, stdin=incoming, stdout=None if visible else sink,
                                stderr=None if visible else errors, report=False)
            if not visible and result.status:
                replay_stderr(errors)
            return result
        return run_series(runner, series_config, launch).status


def run_candidate(runner, config, argv, incoming, outgoing, answer, label):
    """Check every repeat; preserve a failing repeat for useful diagnostics/replay."""
    hidden = Path(outgoing).with_name('repeat.stdout')
    comparisons = []
    config['_stderr_paths'] = []; config.pop('_failed_output', None)
    config.pop('_failed_repeat', None)
    with open(os.devnull, 'wb') as sink:
        def launch(index):
            target = outgoing if index == 0 else hidden
            if index >= 0: _show_run(config, argv, incoming, target)
            runner.on_launch = (lambda: remember_launch(config)) if index >= 0 else None
            stderr_path = Path(outgoing).with_name('stderr-{}.txt'.format(index))
            config['_stderr_paths'].append(('warm-up' if index < 0 else 'run {}'.format(index + 1), str(stderr_path)))
            with open(incoming, 'rb') as stdin, open(target, 'wb') as stdout, open(stderr_path, 'wb') as stderr:
                result = runner.run(argv, stdin=stdin, stdout=stdout, stderr=stderr, report=False)
            if index > 0 and result.status:
                config['_failed_output'] = str(hidden); config['_failed_repeat'] = index + 1
            return result
        def validate(index):
            target = outgoing if index == 0 else hidden
            comparison = compare_case(target, answer, config)
            if index == 0 or not comparisons: comparisons[:] = [comparison]
            if not comparison.equal:
                if index > 0:
                    config['_failed_output'] = str(hidden); config['_failed_repeat'] = index + 1
                return 'INCOMPLETE' if comparison.incomplete else 'WA'
            return None
        result = run_series(runner, config, launch, validate, label)
    if not Path(outgoing).exists(): Path(outgoing).touch()
    if not config.get('_failed_output'): hidden.unlink(missing_ok=True)
    comparison = comparisons[-1] if comparisons else None
    return result, comparison
