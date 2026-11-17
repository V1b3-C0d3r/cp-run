"""Structured findings, temporary annotations and two-phase interactive review."""
from dataclasses import dataclass, field
import difflib
import hashlib


def format_source_list(config):
    return config.get('format_sources', config.get('protected', []))


class FormatFinding(str):
    """Render findings without making callers parse text to discover severity."""
    def __new__(cls, source, line, column, rule, severity, message):
        value = str.__new__(cls, '{}:{}:{}: school {} {}: {}'.format(
            source, line, column, rule, severity, message))
        value.source, value.line, value.column = str(source), int(line), int(column)
        value.rule, value.severity, value.message = rule, severity, message
        return value

    def record(self):
        return dict(file=self.source, line=self.line, column=self.column, rule=self.rule,
                    severity=self.severity, message=self.message)


@dataclass
class FormatResult:
    findings: list = field(default_factory=list)
    jobs: list = field(default_factory=list)
    identities: dict = field(default_factory=dict)
    cache_jobs: list = field(default_factory=list)
    inputs: list = field(default_factory=list)

    @property
    def errors(self):
        return [item for item in self.findings if item.severity == 'error']

    @property
    def warnings(self):
        return [item for item in self.findings if item.severity != 'error']


FORMAT_MARKER = re.compile(
    r'/\*\s*(school-(?:error-justified|justified|error-comment|warning-comment|error|warning))'
    r'\s+([0-9.]+)(?:\s*:\s*(.*?))?\s*\*/', re.S)


def format_annotations(text):
    """Only real comments create annotations; consecutive markers share a target."""
    tokens = list(SCHOOL_LEXER.finditer(text))
    for token in tokens:
        if not token.group('comment'):
            continue
        marker = FORMAT_MARKER.fullmatch(token[0])
        if not marker:
            continue
        end = token.end()
        while True:
            while end < len(text) and text[end].isspace():
                end += 1
            following = next((item for item in tokens if item.start() == end), None)
            if following and FORMAT_MARKER.fullmatch(following[0]):
                end = following.end()
            else:
                break
        yield token, marker, text[:end].count('\n') + 1


def format_strip_automatic(text):
    """Remove only managed temporary notes, including leftovers after SIGKILL."""
    edits = []
    for token, marker, _ in format_annotations(text):
        if marker[1] not in ('school-error', 'school-warning'):
            continue
        start, end = token.span()
        left = text.rfind('\n', 0, start) + 1
        right = text.find('\n', end)
        right = len(text) if right < 0 else right + 1
        if not text[left:start].strip() and not text[end:right].strip():
            edits.append((left, right))
        else:
            if text[end:end + 1] == ' ':
                end += 1
            edits.append((start, end))
    for start, end in sorted(set(edits), reverse=True):
        text = text[:start] + text[end:]
    return text


def format_report_target(value, protected, overwrite=False):
    target = Path(value).expanduser().absolute()
    for name in protected:
        source = Path(name)
        if target.resolve() == source.resolve() or target.exists() and source.exists() and os.path.samefile(target, source):
            raise CheckUsageError('report collides with a protected file: ' + str(target))
    if target.is_symlink() or target.exists() and not target.is_file():
        raise CheckUsageError('report must be a regular file: ' + str(target))
    if target.exists() and not overwrite:
        raise CheckUsageError('report exists; use --overwrite: ' + str(target))
    if not target.parent.is_dir():
        raise CheckUsageError('report directory not found: ' + str(target.parent))
    return target


class FormatReport:
    """Write initial snapshots before decisions and update the final audit trail."""
    def __init__(self, config):
        self.protected = config.get('protected', [])
        self.overwrite = config.get('overwrite', False)
        value = config.get('review_report')
        self.target = format_report_target(value, self.protected, self.overwrite) if value else None
        self.owned = {}
        self.initial, self.records = [], []
        self.build_interrupted = False
        self.state, self.phase = 'pending', ''

    def write(self, target=None):
        target = target or self.target
        if target is None:
            return
        if target in self.owned and target.read_bytes() != self.owned[target]:
            raise CheckSetupError('report changed during review: ' + str(target))
        data = (json.dumps(dict(schema=1, state=self.state, phase=self.phase, build_interrupted=self.build_interrupted,
                               initial=self.initial, findings=self.records),
                           ensure_ascii=False, indent=2) + '\n').encode('utf-8')
        descriptor, temporary = tempfile.mkstemp(prefix='.cp-review-', dir=target.parent)
        try:
            with os.fdopen(descriptor, 'wb') as stream:
                stream.write(data)
            if target in self.owned or self.overwrite:
                os.replace(temporary, target)
            else:
                os.link(temporary, target)  # Exclusive creation closes a preflight race.
            self.owned[target] = data
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


def format_comment(source, finding, text='', kind='comment'):
    """Place metadata before the affected physical line without touching tokens."""
    if any(ord(char) < 32 for char in text) or '*/' in text:
        raise CheckUsageError('comment contains a control character or */')
    original = source.read_bytes()
    decoded = original.decode('utf-8')
    lines = decoded.splitlines(keepends=True)
    if not 1 <= finding.line <= len(lines):
        raise CheckSetupError('annotation location changed: ' + str(source))
    position = sum(len(line) for line in lines[:finding.line - 1])
    for token in SCHOOL_LEXER.finditer(decoded):
        if token.start() < position < token.end():
            raise CheckSetupError('cannot annotate inside a multiline literal/comment: ' + str(source))
    if any(left < position < right for left, right in school_directive_spans(decoded)):
        raise CheckSetupError('cannot annotate inside a continued directive: ' + str(source))
    if kind == 'justified':
        marker = 'school-error-justified' if finding.severity == 'error' else 'school-justified'
    else:
        marker = 'school-' + ('error' if finding.severity == 'error' else 'warning')
        if kind == 'comment':
            marker += '-comment'
    line = lines[finding.line - 1]
    indent = line[:len(line) - len(line.lstrip(' '))]
    note = indent + '/* {} {}{} */\n'.format(marker, finding.rule, ': ' + text.strip() if text.strip() else '')
    candidate = decoded[:position] + note + decoded[position:]
    if [value for value, _ in school_tokens(decoded)] != [value for value, _ in school_tokens(candidate)]:
        raise CheckSetupError('annotation would change source tokens')
    school_publish([(source, original, candidate.encode('utf-8'))])


def format_cleanup(paths):
    jobs = []
    for value in dict.fromkeys(paths):
        source = Path(value)
        if source.is_file():
            original = source.read_bytes()
            try:
                candidate = format_strip_automatic(original.decode('utf-8')).encode('utf-8')
            except UnicodeDecodeError:
                continue
            jobs.append((source, original, candidate))
    school_publish(jobs)


def format_map_line(before, after, line):
    old, new = before.splitlines(), after.splitlines()
    for tag, start, end, other, finish in difflib.SequenceMatcher(None, old, new, autojunk=False).get_opcodes():
        if start <= line - 1 < end:
            return other + (line - 1 - start if tag == 'equal' else 0) + 1
    return max(1, min(line, len(new)))


def format_snapshot(config):
    return {str(Path(value).resolve()): Path(value).read_bytes().decode('utf-8', errors='replace')
            for value in [*format_source_list(config), *config.get('review_related', [])] if Path(value).is_file()}


def format_collect(config):
    """Analyze all roles, then publish safe layout; check mode remains read-only."""
    result = school_analyze(config) if config.get('format_mode') == 'school' else format_clang_analyze(config)
    if config.get('review_report'):
        format_report_target(config['review_report'], [*config.get('protected', []), *result.inputs], True)
    check = config.get('prettier') == 'check'
    if check:
        for source, before, after in result.jobs:
            if format_strip_automatic(before.decode('utf-8')) != format_strip_automatic(after.decode('utf-8')):
                result.findings.append(FormatFinding(source, 1, 1, 'layout', 'error', 'formatting differs'))
    else:
        school_publish(result.jobs, result.identities)
    for source, candidate, findings, dependencies, tools in result.cache_jobs:
        format_cache_store(source, candidate, findings, dependencies, tools, config)
    return result


def execute_format_review(config, report=None):
    """Resolve errors first; only then expose and process review warnings."""
    if config.get('review') and config.get('prettier') == 'check':
        raise CheckUsageError('--review conflicts with --check')
    if config.get('review') and not (sys.stdin.isatty() and sys.stderr.isatty()):
        raise CheckUsageError('--review needs a terminal')
    report = report or FormatReport(config)
    result, snapshots = None, format_snapshot(config)
    active, seen_phases = [], set()

    def refresh():
        nonlocal result, snapshots, active
        before = snapshots
        try:
            result = format_collect(config)
        except (CheckSetupError, OSError) as error:
            if not config.get('review') and not report.target:
                raise
            source = config.get('protected', ['format'])[0]
            result = FormatResult([FormatFinding(source, 1, 1, 'backend', 'error', str(error))])
        config.setdefault('review_related', set()).update(item.source for item in result.findings if Path(item.source).is_file())
        report.protected = [*config.get('protected', []), *result.inputs]
        snapshots = format_snapshot(config)
        for record in report.records:
            source = record['file']
            if source in before and source in snapshots:
                record['line'] = format_map_line(before[source], snapshots[source], record['line'])
        phase = 'errors' if result.errors else 'review'
        visible = result.errors if result.errors else result.warnings
        active = []
        reused = set()
        for finding in visible:
            candidates = [entry for entry in report.records if
                (entry['file'], entry['rule'], entry['severity'], entry['message']) ==
                (finding.source, finding.rule, finding.severity, finding.message)
                and entry['decision'] not in ('fixed', 'justified') and entry['id'] not in reused]
            record = min(candidates, key=lambda entry: abs(entry['line'] - finding.line)) if candidates else None
            if record is not None:
                record.update(line=finding.line, column=finding.column)
                reused.add(record['id'])
            if record is None:
                record = finding.record()
                record.update(id=len(report.records) + 1, decision='pending', reviewer_comment='', comments=[])
                report.records.append(record)
                reused.add(record["id"])
            active.append((finding, record))
        if result.jobs:  # A backend failure cannot prove that previous findings were fixed.
            current = {(item.source, item.line, item.rule, item.severity, item.message) for item in result.findings}
            for record in report.records:
                identity = tuple(record[key] for key in ('file', 'line', 'rule', 'severity', 'message'))
                if identity not in current and record['decision'] == 'pending':
                    record['decision'] = 'fixed'
        report.phase = phase
        if phase not in seen_phases:
            report.initial.append(dict(phase=phase, findings=[item.record() for item in visible]))
            seen_phases.add(phase)
        for finding in visible:
            print(finding, file=sys.stderr)
        report.state = 'errors' if result.errors else 'review'
        report.write()

    def annotate(pairs, kind, text=''):
        # Removing temporary notes first keeps offsets unambiguous and makes cleanup idempotent.
        old = format_snapshot(config)
        format_cleanup([*format_source_list(config), *config.get('review_related', [])])
        clean = format_snapshot(config)
        for finding, record in sorted(pairs, key=lambda pair: (pair[0].source, pair[0].line), reverse=True):
            if finding.rule not in SCHOOL_RULES:
                print('this diagnostic cannot be annotated', file=sys.stderr)
                continue
            line = format_map_line(old[finding.source], clean[finding.source], finding.line)
            location = FormatFinding(finding.source, line, 1, finding.rule, finding.severity, finding.message)
            format_comment(Path(finding.source), location, finding.message if kind == 'auto' else text, kind)

    try:
        refresh()
        if not config.get('review'):
            report.state = 'errors' if result.errors else 'complete'
            return int(bool(result.errors))
        while True:
            pending = [(item, record) for item, record in active if record['decision'] == 'pending']
            if not pending:
                report.state = 'complete'
                return int(bool(result.errors))
            if config.get('annotate'):
                annotate(pending, 'auto')
                snapshots = format_snapshot(config)
            finding, record = pending[0]
            print('{}> '.format('error' if result.errors else 'review'), end='', file=sys.stderr, flush=True)
            entered = sys.stdin.readline()
            if not entered:
                report.state = 'incomplete'
                return 1
            try:
                parts = shlex.split(entered)
            except ValueError:
                print('invalid quoting', file=sys.stderr)
                continue
            if not parts:
                continue
            command = {'a': 'accept', 'd': 'deny', 'j': 'justified', 'c': 'comment', 'q': 'quit'}.get(parts[0], parts[0])
            if command == 'quit':
                report.state = 'incomplete'
                return 1
            if command == 'export':
                if len(parts) != 2:
                    print('expected a file', file=sys.stderr)
                    continue
                try:
                    requested = Path(parts[1]).expanduser().absolute()
                    target = requested if requested in report.owned else format_report_target(
                        parts[1], report.protected, config.get('overwrite', False))
                    report.write(target)
                except (CheckUsageError, CheckSetupError, OSError) as error:
                    print(str(error), file=sys.stderr)
                continue
            all_remaining = command in ('accept-all', 'deny-all', 'justified-all')
            if all_remaining:
                command = command.removesuffix('-all')
            elif len(parts) > 1 and parts[1] == 'all':
                all_remaining = True
                parts.pop(1)
            if command not in ('accept', 'deny', 'justified', 'comment'):
                print('invalid decision', file=sys.stderr)
                continue
            local_annotate = bool({'--annotate', '--anotate'} & set(parts[1:]))
            text = ' '.join(part for part in parts[1:] if part not in ('--annotate', '--anotate'))
            if any(ord(char) < 32 for char in text) or '*/' in text:
                print('invalid comment', file=sys.stderr)
                continue
            selected = pending if all_remaining else [(finding, record)]
            if command == 'deny' and result.errors:
                report.state = 'stopped'
                return 1
            if command == 'deny':
                for _, entry in selected:
                    entry.update(decision='deny', reviewer_comment=text)
                report.write()
                continue
            if command in ('comment', 'justified') or local_annotate:
                eligible = [(item, entry) for item, entry in selected if item.rule in SCHOOL_RULES]
                if len(eligible) != len(selected):
                    print('parser/compiler diagnostics cannot be justified or annotated; fix the code or toolchain, then accept.',
                          file=sys.stderr)
                if not eligible and command != 'accept':
                    continue
                if command in ('comment', 'justified'):
                    selected = eligible
            if command == 'comment':
                for _, entry in selected:
                    entry['comments'].append(text)
                annotate(selected, 'comment', text)
            elif command == 'justified':
                eligible = [(item, entry) for item, entry in selected if item.rule in SCHOOL_RULES]
                for _, entry in eligible:
                    entry.update(decision='justified', reviewer_comment=text)
                annotate(eligible, 'justified', text)
            elif local_annotate:
                annotate(selected, 'auto')
            if command == 'accept':
                for _, entry in selected:
                    entry['reviewer_comment'] = text
            refresh()
    except KeyboardInterrupt:
        report.state = 'interrupted'
        return 130
    finally:
        if config.get('review'):
            format_cleanup([*format_source_list(config), *config.get('review_related', [])])
        report.write()


def execute_strict_format(config):
    read_only = dict(config, prettier='check', review=False, annotate=False)
    report = FormatReport(config)
    result = format_collect(read_only)
    report.build_interrupted = bool(result.errors)
    if result.errors and sys.stdin.isatty() and sys.stderr.isatty():
        execute_format_review(dict(config, prettier='format', review=True), report)
        # The original build is always interrupted, even after a clean review.
        return 1
    visible = result.errors if result.errors else result.warnings
    report.phase = 'errors' if result.errors else 'check'
    report.state = 'errors' if result.errors else 'complete'
    report.initial = [dict(phase=report.phase, findings=[item.record() for item in visible])]
    report.records = [dict(item.record(), decision='pending' if result.errors else 'not-reviewed',
                           reviewer_comment='', comments=[]) for item in visible]
    for item in result.errors:
        print(item, file=sys.stderr)
    report.write()
    return int(bool(result.errors))


def format_clang_analyze(config):
    """Use stdin to stage project-style formatting without editing any role."""
    tools, jobs = [], []
    for value in dict.fromkeys(format_source_list(config)):
        source = Path(value).resolve()
        python = source.suffix == '.py'
        tool = config.get('python_formatter', 'ruff') if python else config.get('native_formatter', 'clang-format')
        executable = shutil.which(tool)
        if not executable:
            raise CheckSetupError('formatter not found: ' + tool)
        if python:
            argv = [executable, *([] if Path(tool).name.startswith('black') else ['format']),
                    '--stdin-filename=' + str(source), '-']
        else:
            argv = [executable, '--style=file', '--fallback-style=LLVM', '--sort-includes=false',
                    '--assume-filename=' + str(source)]
        tools.append((source, argv))
    findings, identities = [], {}
    for source, argv in tools:
        original = source.read_bytes()
        metadata = source.stat()
        identities[source] = metadata.st_dev, metadata.st_ino
        result = school_tool(argv, input=original, capture_output=True)
        if result.returncode:
            findings.append(FormatFinding(source, 1, 1, 'formatter', 'error',
                            result.stderr.decode('utf-8', errors='replace')))
        else:
            jobs.append((source, original, result.stdout))
    return FormatResult(findings, jobs, identities)
