"""Bounded result cache; unchanged source, tools and dependencies are mandatory."""
SCHOOL_ENGINE_ID = '@SCHOOL_ENGINE_ID@'


def format_file_identity(value):
    path = Path(value)
    try:
        info = path.stat()
    except FileNotFoundError:
        return None
    return [str(path.resolve()), info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns]


def format_dependency_paths(text):
    """Decode compiler-generated Make prerequisites without shell expansion."""
    body = text.replace('\\\n', '')
    _, separator, prerequisites = body.partition(':')
    if not separator:
        raise ValueError('invalid compiler dependency record')
    return [value.replace('$$', '$') for value in shlex.split(prerequisites, comments=False) if value != '-']


def format_cache_location(source, config):
    if not config.get('format_cache', True):
        return None
    root = os.environ.get('XDG_CACHE_HOME')
    if not root:
        state = os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))
        root = str(Path(state) / 'cp-run')
    root = Path(root) / 'format-cache'
    try:
        root.mkdir(parents=True, exist_ok=True, mode=0o700)
        metadata = root.stat()
        if root.is_symlink() or metadata.st_uid != os.getuid() or metadata.st_mode & 0o022:
            return None
    except OSError:
        return None  # A cache is optional; all checks still run with a read-only home.
    digest = hashlib.sha256(str(source).encode()).hexdigest()
    return root / ('school-' + digest + '.json')


def format_cache_key(text, tools):
    record = dict(engine=SCHOOL_ENGINE_ID, cwd=str(Path.cwd()),
                  environment={key: os.environ.get(key) for key in ('CPATH', 'C_INCLUDE_PATH', 'CPLUS_INCLUDE_PATH', 'SDKROOT', 'DEVELOPER_DIR', 'GCC_EXEC_PREFIX', 'COMPILER_PATH', 'LIBRARY_PATH', 'SOURCE_DATE_EPOCH', 'LANG', 'LC_ALL', 'TZ')}, source=hashlib.sha256(text.encode('utf-8')).hexdigest(),
                  tools=[format_file_identity(value) for value in tools])
    return hashlib.sha256(json.dumps(record, sort_keys=True).encode()).hexdigest()


def format_cache_load(source, text, tools, config):
    path = format_cache_location(source, config)
    if path is None or any(value in text for value in ('__DATE__', '__TIME__', '__TIMESTAMP__')):
        return None
    try:
        if path.is_symlink() or path.stat().st_size > 4 * 1024 * 1024:
            return None
        record = json.loads(path.read_text())
        if not isinstance(record, dict) or not isinstance(record.get('dependencies'), dict) or not isinstance(record.get('findings'), list):
            return None
        if record['key'] != format_cache_key(text, tools) or record['candidate'] != text:
            return None
        if any(format_file_identity(value) != identity for value, identity in record['dependencies'].items()):
            return None
        allowed = set(SCHOOL_RULES) | {'review-comment', 'frontend', 'GCC'}
        findings = []
        for item in record['findings']:
            if not isinstance(item, dict):
                return None
            if (item['rule'] not in allowed or item['severity'] not in ('error', 'warning') or
                    item['file'] != str(source) and not Path(item['file']).is_absolute() or
                    type(item['line']) is not int or type(item['column']) is not int or
                    not isinstance(item['message'], str)):
                return None
            findings.append(FormatFinding(item['file'], item['line'], item['column'], item['rule'],
                                          item['severity'], item['message']))
        return findings, list(record['dependencies'])
    except (OSError, ValueError, KeyError, TypeError):
        return None



def format_include_candidates(source, text, dependencies):
    """Conservatively track include shadows, without lexing header bodies."""
    candidates = set()
    gap = r'(?:[ \t\v\f]|/\*.*?\*/)*'
    literal = re.compile(r'#' + gap + r'include' + gap + r'([<"])([^>"\r\n\0]+)[>"]', re.S)
    for owner in [source, *(Path(value) for value in dependencies)]:
        try:
            contents = text if owner == source else owner.read_text()
        except (OSError, UnicodeDecodeError):
            continue
        # This is a dependency superset, not a policy diagnostic: apparent
        # includes inside comments/strings only cause extra invalidation.
        contents = contents.replace('\\\r\n', '').replace('\\\n', '')
        for directive in literal.finditer(contents):
            candidates.add(str((owner.parent / directive[2]).absolute()))
    return candidates


def format_cache_store(source, candidate, findings, dependencies, tools, config):
    path = format_cache_location(source, config)
    if path is None or len(candidate.encode('utf-8')) > 2 * 1024 * 1024:
        return
    # Parent/negative dependencies cover files consulted by the project auditor.
    dependencies = set(dependencies) | {str(source.with_suffix('.h')),
                    str(source.parent / 'Makefile'), str(source.parent / 'makefile')}
    headers = [value for value in dependencies if Path(value).suffix in ('.h', '.hpp', '.hh', '.hxx')]
    try:
        dependencies.update(format_include_candidates(source, candidate, headers))
        record = dict(key=format_cache_key(candidate, tools), candidate=candidate,
                      dependencies={value: format_file_identity(value) for value in dependencies},
                      findings=[item.record() for item in findings])
    except (OSError, ValueError):
        return  # An unusable conservative candidate disables optional caching.
    temporary = None
    try:
        descriptor, temporary = tempfile.mkstemp(prefix='.school-cache-', dir=path.parent)
        with os.fdopen(descriptor, 'w', encoding='utf-8') as stream:
            json.dump(record, stream, ensure_ascii=False)
        os.replace(temporary, path)
        temporary = None
        entries = sorted(path.parent.glob('school-*.json'), key=lambda item: item.stat().st_mtime_ns)
        for old in entries[:-64]:
            if old != path and old.is_file() and not old.is_symlink():
                old.unlink()
    except OSError:
        pass  # Failed caching never substitutes for failed or skipped verification.
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)
