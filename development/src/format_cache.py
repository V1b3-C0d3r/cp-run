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



def format_include_candidates(source, text, dependencies, search_directories=()):
    """Conservatively watch lookup alternatives without caching compiler output."""
    candidates, macro_owners, names, directories = set(), set(), set(), set()
    roots = list(dict.fromkeys([*search_directories, (str(source.parent), False)]))
    roots = [(Path(value), framework) for value, framework in roots]
    canonical_roots = [(root, framework, root.resolve()) for root, framework in roots]
    project = source.parent.resolve()
    local = {}

    def in_project(directory):
        if directory not in local:
            local[directory] = directory.resolve().is_relative_to(project)
        return local[directory]

    gap = r'(?:[ \t\v\f]|/\*.*?\*/)*'
    literal = re.compile(r'#' + gap + r'include(?:_next)?\b' + gap + r'([<"])([^>"\r\n\0]+)[>"]', re.S)
    macro = re.compile(r'#' + gap + r'include(?:_next)?\b' + gap + r'[A-Za-z_]', re.S)
    presence = re.compile(r'__has_(?:include(?:_next)?|embed)\s*\(\s*([<"])([^>"\r\n\0]+)[>"]', re.S)
    opaque_presence = re.compile(r'__has_(?:include(?:_next)?|embed)\s*\(\s*[A-Za-z_]', re.S)

    def watch(candidate, directory=False):
        if directory and not in_project(candidate.parent):
            directories.add(candidate.parent)
        else:
            candidates.add(str(candidate.absolute()))

    def search_candidates(name, owner, directory=False):
        watch(owner / name, directory)
        for root, framework in roots:
            if framework:
                library, separator, remainder = name.partition('/')
                if separator:
                    for folder in ('Headers', 'PrivateHeaders'):
                        watch(root / (library + '.framework') / folder / remainder, directory)
            else:
                watch(root / name, directory)

    uncovered = False
    for owner in [source, *(Path(value) for value in dependencies)]:
        try:
            contents = text if owner == source else owner.read_text()
        except (OSError, UnicodeDecodeError):
            continue
        contents = contents.replace('\\\r\n', '').replace('\\\n', '')
        for directive in literal.finditer(contents):
            search_candidates(directive[2], owner.parent, directory=True)
        for expression in presence.finditer(contents):
            search_candidates(expression[2], owner.parent, directory=True)
        unknown = list(opaque_presence.finditer(contents))
        if unknown:
            ignored = [(token.start(), token.end()) for token in SCHOOL_LEXER.finditer(contents)]
            for expression in unknown:
                before = contents[contents.rfind('\n', 0, expression.start()) + 1:expression.start()]
                signature = re.fullmatch(r'\s*#\s*define\s+', before)
                if not signature and not any(start <= expression.start() < end for start, end in ignored):
                    raise ValueError('nonliteral file-presence expression requires fresh preprocessing')
        if macro.search(contents):
            macro_owners.add(owner.parent)
        if owner != source:
            names.add(owner.name)
            covered = False
            resolved = owner.resolve()
            for root, framework, canonical in canonical_roots:
                if owner.is_relative_to(root):
                    covered = True
                    relative = owner.relative_to(root)
                elif resolved.is_relative_to(canonical):
                    covered = True
                    relative = resolved.relative_to(canonical)
                else:
                    continue
                if not framework:
                    names.add(str(relative))
                elif relative.parts[0].endswith('.framework'):
                    for folder in ('Headers', 'PrivateHeaders'):
                        if folder in relative.parts:
                            position = relative.parts.index(folder)
                            names.add(relative.parts[0][:-len('.framework')] + '/' +
                                      '/'.join(relative.parts[position + 1:]))
            uncovered = uncovered or not covered
    if macro_owners and uncovered:
        raise ValueError('macro include has prerequisites outside the known search roots')
    # Macro spellings cannot always be reconstructed. Watch external lookup
    # directories; keep exact paths in the project so atomic editor saves do
    # not discard reusable preparation.
    for owner in macro_owners:
        for name in names:
            search_candidates(name, owner, directory=True)
    for directory in directories:
        candidates.add(str(directory.absolute()))
        try:
            with os.scandir(directory) as entries:
                for entry in entries:
                    # A dangling file link can become usable when its target
                    # appears without any change to this directory's entries.
                    if entry.is_symlink():
                        candidates.add(str(Path(entry.path).absolute()))
        except (FileNotFoundError, NotADirectoryError):
            continue
    return candidates


def format_volatile_inputs(text, dependencies):
    """Clock-dependent preprocessing must never become a reusable result."""
    names = ('__DATE__', '__TIME__', '__TIMESTAMP__')
    if any(name in text for name in names):
        return True
    for value in dependencies:
        try:
            if Path(value).is_dir():
                continue
            contents = Path(value).read_bytes()
        except FileNotFoundError:
            continue
        except (OSError, ValueError):
            return True
        if any(name.encode() in contents for name in names):
            return True
    return False


def format_cache_store(source, candidate, findings, dependencies, tools, config):
    path = format_cache_location(source, config)
    if (path is None or len(candidate.encode('utf-8')) > 2 * 1024 * 1024
            or format_volatile_inputs(candidate, dependencies)):
        return
    # Production callers pass the snapshot captured by the analysis, not a
    # fresh identity that could accidentally bless a concurrent header edit.
    try:
        if isinstance(dependencies, dict):
            snapshot = dict(dependencies)
        else:
            dependencies = set(dependencies) | {str(source.with_suffix('.h')),
                            str(source.parent / 'Makefile'), str(source.parent / 'makefile')}
            headers = [value for value in dependencies if Path(value).suffix in ('.h', '.hpp', '.hh', '.hxx')]
            dependencies.update(format_include_candidates(source, candidate, headers))
            snapshot = {value: format_file_identity(value) for value in dependencies}
        if any(format_file_identity(value) != identity for value, identity in snapshot.items()):
            return
        record = dict(key=format_cache_key(candidate, tools), candidate=candidate,
                      dependencies=snapshot, findings=[item.record() for item in findings])
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
