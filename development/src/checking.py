"""Shared case execution, continuation, and output publication."""

import errno


def _runner(config):
    return Runner(timeout_ms=str(config.get('timeout_ms', 'inf')),
                  memory_mib=str(config.get('memory_mib', 'inf')),
                  show_time=bool(config.get('show_time')), show_memory=bool(config.get('show_memory')) or config.get('operation') in ('test', 'stress'),
                  show_command=False, time_factor=config.get('time_factor', '2'),
                  memory_factor=config.get('memory_factor', '2'),
                  time_unit=config.get('time_unit', 'ms'), memory_unit=config.get('memory_unit', 'KiB'))


def _show_run(config, argv, incoming, outgoing):
    if config.get('show_command'):
        print('{} < {} > {}'.format(shlex.join([str(x) for x in argv]),
              shlex.quote(str(incoming)), shlex.quote(str(outgoing))), file=sys.stderr)


def _run_files(runner, config, argv, incoming, outgoing, label, stderr=None):
    _show_run(config, argv, incoming, outgoing)
    with open(incoming, 'rb') as stdin, open(outgoing, 'wb') as stdout:
        return runner.run([str(x) for x in argv], stdin=stdin, stdout=stdout,
                          label=label, stderr=stderr, report=False)


def _publish_actual(source, destination):
    target = Path(destination)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=target.parent, prefix='.cp-run-output-', delete=False) as output:
            temporary = Path(output.name)
            with open(source, 'rb') as incoming: shutil.copyfileobj(incoming, output)
        os.replace(temporary, target)
    finally:
        if temporary is not None: temporary.unlink(missing_ok=True)


def _aggregate(verdicts):
    for verdict, status in verdicts:
        if verdict == 'INTERRUPTED': return status or 130
    for verdict, status in verdicts:
        if verdict in ('GENERATOR_ERROR', 'ORACLE_ERROR'): return status or 1
    if any(verdict == 'INCOMPLETE' for verdict, _ in verdicts): return 4
    for name, code in (('CE', 1), ('MLE', 125), ('TLE', 124)):
        if any(verdict == name for verdict, _ in verdicts): return code
    for verdict, status in verdicts:
        if verdict == 'RE': return status or 1
    return 3 if any(verdict == 'WA' for verdict, _ in verdicts) else 0


def execute_test(config):
    """Every auto/mult case owns an independent process budget and series."""
    plan = _load_plan(config)
    if not config.get('executable'): raise CheckUsageError('test execution needs a launch target')
    if not config.get('auto') and not config.get('mult') and config.get('num_test'):
        count = positive_setting(config['num_test'], '--test-iters')
        if str(config.get('timeout_ms', 'inf')) != 'inf':
            config['timeout_ms'] = str(int(config['timeout_ms']) * count)
    runner = _runner(config)
    argv = [*config.get('main_argv', [config['executable']]), *config.get('runtime_args', [])]
    verdicts, groups = [], {}
    positions = {number: i for i, number in enumerate(plan.ids or range(1, len(plan.inputs) + 1))}
    with check_lock(), tempfile.TemporaryDirectory(prefix='.cp-run-test-', dir='.') as temporary:
        directory = Path(temporary)
        report, combined = Protocol(config), directory / 'combined.stdout'
        try:
            if plan.zero_notice: print('cp-run: tests use 1-based indices; using 1 instead of 0', file=sys.stderr)
            report.emit('cp-run test: selected {} of {} cases'.format(len(plan.selected), len(plan.inputs)))
            with open(combined, 'wb') as all_output:
                for position, number in enumerate(plan.selected):
                    incoming, answer, actual = (directory / name for name in ('in.txt', 'ans.txt', 'actual.txt'))
                    index = positions[number]
                    plan.inputs[index].copy_to(incoming); plan.answers[index].copy_to(answer)
                    actual.unlink(missing_ok=True)
                    result, comparison = run_candidate(runner, config, argv, incoming, actual, answer, 'test {}'.format(number))
                    if position and (config.get('auto') or config.get('mult')): all_output.write(plan.separator)
                    with open(actual, 'rb') as stream: shutil.copyfileobj(stream, all_output)
                    retain_failed_repeat(config, number)
                    verdict = case_protocol(report, config, number, incoming, actual, answer, result, comparison)
                    groups.setdefault(verdict, []).append(number)
                    for violation in config.get('_resource_violations', []):
                        if violation != verdict: groups.setdefault(violation, []).append(number)
                    verdicts.append((verdict, result.status))
                    if verdict == 'INTERRUPTED': break
            status = _aggregate(verdicts)
            final_protocol(report, groups, any(v in ('INCOMPLETE', 'INTERRUPTED') for v, _ in verdicts))
            summary = '{}: {} selected cases executed; {} failed'.format(
                'PASS' if not status else 'INCOMPLETE' if status == 4 else 'FAIL',
                len(verdicts), sum(v != 'AC' for v, _ in verdicts))
            report.emit(summary)
            if not config.get('cout'): print('cp-run: ' + summary + '; report: ' + str(config.get('report', 'test_out')), file=sys.stderr)
            # Keep same-filesystem publication cheap; a workspace output may
            # live on another mount, where replacement needs sibling staging.
            try:
                os.replace(combined, config['actual'])
            except OSError as error:
                if error.errno != errno.EXDEV: raise
                _publish_actual(combined, config['actual'])
            report.finish()
            return status
        except BaseException:
            report.abort(); raise
