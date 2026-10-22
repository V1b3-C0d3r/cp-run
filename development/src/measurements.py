"""Repeated runs reuse one supervisor and expose one measured stdout only."""

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
        if warm.verdict in ('INTERRUPTED', 'TLE', 'MLE') or (config.get('operation') in ('test', 'stress') and warm.status):
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


def supervise(config):
    """Snapshot only input needing replay; opening/copying is outside child timing."""
    runner = _runner(config)
    argv = [*config.get('main_argv', [config['executable']]), *config.get('runtime_args', [])]
    observed = bool(config.get('show_time') or config.get('show_memory'))
    count = repetition_count(config.get('average', 1)) if observed else 1
    if count > 1 and os.isatty(0):
        raise CheckUsageError('repeated measurements need redirected input, not a terminal')
    with ExitStack() as stack:
        sink = stack.enter_context(open(os.devnull, 'wb'))
        no_input = stack.enter_context(open(os.devnull, 'rb'))
        replay = None
        replay_offset = 0
        if count > 1:
            source = stack.enter_context(os.fdopen(os.dup(0), 'rb'))
            if stat.S_ISREG(os.fstat(0).st_mode):
                replay = source; replay_offset = source.tell()
            else:
                replay = stack.enter_context(tempfile.TemporaryFile())
                maximum = positive_setting(config.get('max_spool', 268435456), 'spool limit')
                copied = 0
                while True:
                    block = source.read(65536)
                    if not block: break
                    copied += len(block)
                    if copied > maximum: raise CheckSetupError('replayed input exceeds spool byte limit')
                    replay.write(block)
        def launch(index):
            if replay is not None:
                replay.seek(replay_offset); incoming = replay
            elif index < 0:
                incoming = no_input
                if config.get('warmup_input'):
                    incoming = stack.enter_context(open(config['warmup_input'], 'rb'))
            else: incoming = None
            if index == 0 and config.get('show_command'):
                print(shlex.join(argv), file=sys.stderr, flush=True)
            runner.on_launch = (lambda: remember_launch(config)) if index >= 0 else None
            return runner.run(argv, stdin=incoming, stdout=None if index == 0 else sink,
                              stderr=sink if index < 0 else None, report=False)
        return run_series(runner, config, launch).status


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
