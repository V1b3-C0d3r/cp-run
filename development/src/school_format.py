"""School policy checks over Clang's parsed source; no candidate is executed."""

SCHOOL_STYLE = {
    'BasedOnStyle': 'LLVM', 'IndentWidth': 4, 'ContinuationIndentWidth': 8,
    'ColumnLimit': 100, 'UseTab': 'Never', 'BreakBeforeBraces': 'Attach',
    'AlwaysBreakAfterReturnType': 'AllDefinitions', 'AlignAfterOpenBracket': 'DontAlign',
    'IndentCaseLabels': False, 'IndentGotoLabels': False, 'PointerAlignment': 'Right',
    'DerivePointerAlignment': False, 'SpaceAfterCStyleCast': True, 'InsertBraces': True,
    'AllowShortFunctionsOnASingleLine': 'None', 'AllowShortLoopsOnASingleLine': False,
    'AllowShortIfStatementsOnASingleLine': 'Never', 'BinPackParameters': False,
    'SortIncludes': 'Never', 'AllowShortEnumsOnASingleLine': False,
}


def school_prepare(source, text, clang):
    """Only unambiguous empty-parameter edits precede layout and policy checking."""
    tree, issues = school_parse(source, text, clang)
    if issues:
        return text, issues
    data = text.encode('utf-8')
    edits = []
    for node in school_nodes(tree):
        if node.get('kind') != 'FunctionDecl' or not any(
                n.get('kind') == 'CompoundStmt' for n in node.get('inner', [])):
            continue
        loc = node.get('loc', {})
        if 'offset' not in loc or 'includedFrom' in loc:
            continue
        start = loc['offset'] + len(node.get('name', '').encode('utf-8'))
        empty = re.match(rb'\s*\(\s*\)', data[start:])
        if empty:
            edits.append((start, start + empty.end(), b'(void)'))
    for start, end, replacement in sorted(set(edits), reverse=True):
        data = data[:start] + replacement + data[end:]
    return data.decode('utf-8'), []



def school_nodes(node):
    yield node
    for child in node.get('inner', []):
        yield from school_nodes(child)


def execute_school_format(config):
    """Prepare and verify every candidate before replacing any source."""
    clang = shutil.which('clang')
    formatter = shutil.which(config.get('native_formatter', 'clang-format'))
    gcc = shutil.which(os.environ.get('CP_RUN_GCC', 'gcc-16')) or shutil.which('gcc')
    if not all((clang, formatter, gcc)):
        raise CheckSetupError('school needs clang-format, clang (AST) and GNU GCC.')
    banner = school_tool([gcc, '--version'], capture_output=True, text=True)
    if 'clang' in banner.stdout.lower():
        raise CheckSetupError('school needs GNU GCC; set CP_RUN_GCC to its executable.')
    jobs, diagnostics = [], []
    for value in dict.fromkeys(config.get('protected', [])):
        source = Path(value).resolve()
        if source.suffix not in ('.c', '.h', '.hpp', '.cc', '.cpp', '.cxx', '.C'):
            raise CheckUsageError('school supports C and C++ sources only')
        original = source.read_bytes()
        try:
            text = original.decode('utf-8')
        except UnicodeDecodeError as error:
            raise CheckSetupError(str(source) + ': school: expected UTF-8 source: ' + str(error)) from error
        candidate, issues = school_prepare(source, text, clang)
        result = school_tool([formatter, '--style=' + json.dumps(SCHOOL_STYLE),
            '--assume-filename=' + str(source)], input=candidate, text=True, capture_output=True)
        if result.returncode:
            raise CheckSetupError(result.stderr)
        candidate = result.stdout
        candidate, tree, parse_issues = school_apply_layout(source, candidate, clang)
        issues.extend(parse_issues)
        if tree is not None:
            issues.extend(SchoolPolicy(source, candidate, tree).run())
        with tempfile.TemporaryDirectory(prefix='cp-school-') as directory:
            path = Path(directory) / source.name
            path.write_text(candidate)
            flags = list(SCHOOL_C_FLAGS if source.suffix in ('.c', '.h') else SCHOOL_CPP_FLAGS)
            driver = gcc
            if source.suffix not in ('.c', '.h'):
                driver = shutil.which(str(Path(gcc).with_name(Path(gcc).name.replace('gcc', 'g++')))) or gcc
            output = str(Path(directory) / 'verify.out')
            compile_only = [] if tree is not None and any(n.get('kind') == 'FunctionDecl' and n.get('name') == 'main' for n in tree.get('inner', [])) else ['-c']
            checked = school_tool([driver, '-x', 'c' if source.suffix in ('.c', '.h') else 'c++',
                str(path), '-iquote', str(source.parent), *flags, *compile_only, '-o', output],
                capture_output=True, text=True)
            if checked.returncode:
                issues.append(str(source) + ': school GCC flags: fix the compiler diagnostics:\n' +
                              checked.stderr.replace(str(path), str(source)))
        diagnostics.extend(issues)
        jobs.append((source, original, candidate.encode('utf-8')))
    if diagnostics:
        print('\n'.join(diagnostics), file=sys.stderr)
        return 1
    print('school: mechanical checks passed; required author reviews are explicit in source comments.', file=sys.stderr)
    changed = [job for job in jobs if job[1] != job[2]]
    if config.get('prettier') == 'check':
        for source, _, _ in changed:
            print(str(source) + ': formatting differs; run cp-run format --school FILE', file=sys.stderr)
        return int(bool(changed))
    # Preflight all sources after running tools. Atomic replacement is per file.
    for source, original, _ in jobs:
        if source.read_bytes() != original:
            raise CheckSetupError('source changed during formatting: ' + str(source))
    for source, _, candidate in changed:
        descriptor, temporary = tempfile.mkstemp(prefix='.cp-format-', dir=source.parent)
        try:
            with os.fdopen(descriptor, 'wb') as stream:
                stream.write(candidate)
            os.chmod(temporary, source.stat().st_mode & 0o777)
            os.replace(temporary, source)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    return 0
