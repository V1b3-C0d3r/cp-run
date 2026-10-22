"""Readable checking protocols; file and console share the same renderer."""

class Protocol:
    """Keep report commits atomic and preserve a copy for stress failure bundles."""

    def __init__(self, config):
        self.max_line = positive_setting(config.get('max_line', 1048576), 'row byte limit')
        self.max_details = positive_setting(config.get('max_report', 262144), 'report byte limit')
        self.display_lines = positive_setting(config.get('report_lines', 10000), 'report row limit')
        self.detail_remaining = self.max_details
        self.console = bool(config.get("cout"))
        self.destination = Path(config.get("report", "test_out"))
        directory = self.destination.parent if not self.console else Path.cwd()
        handle = tempfile.NamedTemporaryFile(mode="w+", encoding="utf-8", dir=directory,
                                             prefix=".cp-run-report-", delete=False)
        self.stream, self.path = handle, Path(handle.name)

    def emit(self, text=""):
        self.stream.write(text + "\n")
        if self.console:
            print(text, flush=True)

    def detail(self, text):
        """Count encoded diagnostics, not source bytes that can expand on escaping."""
        size = len((text + '\n').encode('utf-8'))
        if size > self.detail_remaining:
            if self.detail_remaining:
                self.emit('  ... diagnostic byte limit reached; raw data retained')
            self.detail_remaining = 0
            return
        self.detail_remaining -= size
        self.emit(text)

    def finish(self):
        self.stream.flush()
        self.stream.close()
        if self.console:
            self.path.unlink(missing_ok=True)
        else:
            os.replace(self.path, self.destination)

    def copy_to(self, path):
        self.stream.flush()
        shutil.copyfile(self.path, path)

    def abort(self):
        self.stream.close()
        self.path.unlink(missing_ok=True)




def public_verdict(result, comparison=None):
    """Execution errors take precedence over any partial/unfinished output."""
    if result.status:
        return {'RTE': 'RE', 'OK': 'RE'}.get(result.verdict, result.verdict)
    if comparison is not None:
        if comparison.incomplete: return 'INCOMPLETE'
        return 'AC' if comparison.equal else 'WA'
    return 'AC'


def case_protocol(report, config, number, incoming, actual, answer, result, comparison, seed=None):
    """Payloads first, then verdict and metrics; never color saved reports."""
    verdict = public_verdict(result, comparison)
    if config.get('_failed_output') and result.verdict == 'WA': verdict = 'WA'
    report.emit('\n' + '=' * 64)
    report.emit('TEST {}{}'.format(number, ' (seed {})'.format(seed) if seed is not None else ''))
    if config.get('report_tests', 'all') == 'all' or verdict != 'AC':
        comparison = comparison or Comparison(False, False, 0, set(), set(), [])
        _failure_details(report, incoming, actual, answer, comparison, report.display_lines)
    # A hidden failing repeat is evidence, never a replacement for the first stdout.
    failed = config.get('_failed_output')
    if failed and Path(failed).exists():
        report.emit('FAILED REPEAT {}:'.format(config.get('_failed_repeat')))
        _section(report, 'repeat-output', failed, display_limit=report.display_lines)
    stderr_paths = config.get('_stderr_paths', [])
    for label, path in stderr_paths:
        if not Path(path).exists() or not Path(path).stat().st_size: continue
        report.emit('STDERR ({}):'.format(label))
        # Full stderr is exempt from diff caps, but escaping still happens in
        # bounded chunks so one enormous row cannot exhaust checker memory.
        with open(path, 'rb') as source:
            while True:
                chunk = source.readline(65536)
                if not chunk: break
                report.emit('  ' + _quoted(chunk.rstrip(b'\n')))
    report.emit('Test {}: {}{}'.format(number, verdict, ' (status {})'.format(result.status) if result.status else ''))
    report.emit('  TIME: {}    MEMORY: {}{}'.format(
        format_usage(result.elapsed_ns, config.get('time_unit', 'ms')),
        format_usage(result.peak_bytes, config.get('memory_unit', 'KiB'), True),
        '    RUNS: {}'.format(config.get('_series_runs', 1))))
    if verdict in ('TLE', 'MLE'):
        report.emit('  LIMITS: {} ms / {} MiB; kill factors {} / {}'.format(config.get('timeout_ms', 'inf'), config.get('memory_mib', 'inf'), config.get('time_factor', '2'), config.get('memory_factor', '2')))
    return verdict


def final_protocol(report, groups, unfinished=False):
    """One deterministic headline, with every affected ID retained below it."""
    order = ('CE', 'MLE', 'TLE', 'RE', 'WA', 'AC')
    verdict = 'INTERRUPTED' if groups.get('INTERRUPTED') else 'INCOMPLETE' if unfinished else next((name for name in order if groups.get(name)), 'AC')
    report.emit('\n' + '=' * 64)
    report.emit('FINAL VERDICT: ' + verdict)
    for name in (*order, 'INCOMPLETE', 'GENERATOR_ERROR', 'ORACLE_ERROR', 'INTERRUPTED'):
        if groups.get(name): report.emit('  {}: {}'.format(name, ', '.join(map(str, groups[name]))))
    return verdict


def compilation_report(config):
    """Compiler stderr stays live; only its structured outcome reaches here."""
    plan = _load_plan(config)
    report = Protocol(config)
    try:
        report.emit('PREPARATION: CE ({})'.format(config.get('failed_role', 'main')))
        report.emit('NOT RUN: ' + ', '.join(map(str, plan.selected)))
        final_protocol(report, {'CE': plan.selected or ['preparation']})
        report.finish()
    except BaseException:
        report.abort(); raise
    return int(config.get('build_status', 1))
