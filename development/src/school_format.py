"""School policy checks over Clang's parsed source; no candidate is executed."""

SCHOOL_STYLE = {
    'BasedOnStyle': 'LLVM', 'IndentWidth': 4, 'ContinuationIndentWidth': 8,
    'ColumnLimit': 100, 'UseTab': 'Never', 'BreakBeforeBraces': 'Attach',
    'AlwaysBreakAfterReturnType': 'AllDefinitions', 'AlignAfterOpenBracket': 'DontAlign',
    'IndentCaseLabels': False, 'IndentGotoLabels': False, 'PointerAlignment': 'Right',
    'DerivePointerAlignment': False, 'SpaceAfterCStyleCast': True, 'InsertBraces': True,
    'AllowShortFunctionsOnASingleLine': 'None', 'AllowShortLoopsOnASingleLine': False,
    'AllowShortIfStatementsOnASingleLine': 'Never', 'BinPackParameters': False,
    'SortIncludes': 'Never', 'BreakStringLiterals': False, 'AllowShortEnumsOnASingleLine': False,
    'CommentPragmas': '^ *school-reviewed',
}


def school_prepare(source, text, clang, tree=None):
    """Plan only parsed, local parameter/body edits; retain original expressions."""
    if tree is None:
        tree, issues = school_parse(source, text, clang)
        if issues:
            return text, issues
    data = text.encode('utf-8')
    tokens = school_tokens(text)
    edits = []
    probe = SchoolPolicy(source, text, tree)
    # Calls supplying arguments to a prototype-less definition need an author
    # decision before a void signature can be introduced.
    with_arguments = {probe.canonical_declaration(probe.callee_declaration(node).get('id')) for node in school_nodes(tree)
                      if node.get('kind') == 'CallExpr' and len(node.get('inner', [])) > 1}
    for node in school_definitions(tree):
        parameters = school_definition_parameters(text, node, tokens)
        if not parameters or probe.canonical_declaration(node.get('id')) in with_arguments:
            continue
        opening, closing = parameters
        if closing == opening + 1:
            position = len(text[:tokens[closing][1]].encode('utf-8'))
            edits.append((position, position, b'void'))
    for position in school_empty_body_positions(text, tree):
        offset = len(text[:position].encode('utf-8'))
        edits.append((offset, offset + 1, b'{}'))
    for start, end, replacement in sorted(set(edits), reverse=True):
        data = data[:start] + replacement + data[end:]
    return data.decode('utf-8'), []



def school_nodes(node):
    yield node
    for child in node.get('inner', []):
        yield from school_nodes(child)


def school_gcc_arguments(source, path, directory, gcc, tree):
    language = 'c' if source.suffix in ('.c', '.h') else 'c++'
    flags = list(SCHOOL_C_FLAGS if language == 'c' else SCHOOL_CPP_FLAGS)
    driver = gcc
    if language == 'c++':
        driver = shutil.which(str(Path(gcc).with_name(Path(gcc).name.replace('gcc', 'g++')))) or gcc
    input_path, includes = path, []
    if source.suffix in ('.h', '.hpp'):
        input_path = Path(directory) / ('unit.c' if language == 'c' else 'unit.cpp')
        input_path.write_text('')
        includes = ['-include', str(path)]
    main = tree is not None and any(n.get('kind') == 'FunctionDecl' and n.get('name') == 'main'
                                   for n in tree.get('inner', []))
    argv = [driver, '-x', language, *includes, str(input_path), '-iquote', str(source.parent)]
    return argv, flags, main, input_path, includes


def school_syntax_gate(argv, flags):
    syntax = [flag for flag in flags if flag != '-Werror']
    return school_tool([*argv, *syntax, '-w', '-fsyntax-only'], text=True, capture_output=True)


def school_publish(jobs, identities=None):
    for source, original, _ in jobs:
        if source.read_bytes() != original:
            raise CheckSetupError('source changed during formatting: ' + str(source))
        current = source.stat()
        if identities and identities[source] != (current.st_dev, current.st_ino):
            raise CheckSetupError('source was replaced during formatting: ' + str(source))
    published = []
    for source, original, candidate in jobs:
        if original == candidate:
            continue
        temporary = None
        try:
            descriptor, temporary = tempfile.mkstemp(prefix='.cp-format-', dir=source.parent)
            with os.fdopen(descriptor, 'wb') as stream:
                stream.write(candidate)
            os.chmod(temporary, source.stat().st_mode & 0o777)
            os.replace(temporary, source)
            published.append(str(source))
        except OSError as error:
            previous = '\nAlready formatted: ' + ', '.join(published) if published else '\nNo files were published.'
            raise CheckSetupError('cannot publish formatted file ' + str(source) + ': ' + str(error) + previous) from error
        finally:
            if temporary and os.path.exists(temporary):
                os.unlink(temporary)


def execute_school_format(config):
    """Publish safe layout first; unresolved obligations still return failure."""
    clang = shutil.which('clang')
    formatter = shutil.which(config.get('native_formatter', 'clang-format'))
    gcc = shutil.which(os.environ.get('CP_RUN_GCC', 'gcc-16')) or shutil.which('gcc')
    if not all((clang, formatter, gcc)):
        raise CheckSetupError('school needs clang-format, clang (AST) and GNU GCC.')
    banner = school_tool([gcc, '--version'], capture_output=True, text=True)
    if banner.returncode or 'clang' in banner.stdout.lower() or not re.search(r'GNU|gcc|g\+\+', banner.stdout):
        raise CheckSetupError('school needs GNU GCC; set CP_RUN_GCC to its executable.')
    jobs, diagnostics, identities = [], [], {}
    for value in dict.fromkeys(config.get('protected', [])):
        source = Path(value).resolve()
        if source.suffix not in ('.c', '.h', '.hpp', '.cc', '.cpp', '.cxx', '.C'):
            raise CheckUsageError('school supports C and C++ sources only')
        original = source.read_bytes()
        metadata = source.stat()
        identities[source] = metadata.st_dev, metadata.st_ino
        try:
            text = original.decode('utf-8')
        except UnicodeDecodeError as error:
            raise CheckSetupError(str(source) + ': school: expected UTF-8 source: ' + str(error)) from error
        original_tree, parse_issues = school_parse(source, text, clang)
        candidate, issues = text, []
        if original_tree is not None:
            candidate, issues = school_prepare(source, text, clang, original_tree)
        style = dict(SCHOOL_STYLE)
        if original_tree is None:
            style['InsertBraces'] = False
        formatted = school_tool([formatter, '--style=' + json.dumps(style),
            '--assume-filename=' + str(source)], input=candidate, text=True, capture_output=True)
        if formatted.returncode:
            raise CheckSetupError(formatted.stderr)
        candidate = formatted.stdout
        tree = None
        if original_tree is not None:
            candidate, tree, final_parse = school_apply_layout(source, candidate, clang)
            if tree is None:
                raise CheckSetupError(str(source) + ': school: candidate failed parsing:\n' + '\n'.join(final_parse))
            school_verify_layout(source, text, original_tree, candidate, tree)
            issues.extend(SchoolPolicy(source, candidate, tree).run())
        else:
            if [token for token, _ in school_tokens(text)] != [token for token, _ in school_tokens(candidate)]:
                raise CheckSetupError(str(source) + ': school: unsupported syntax prevents verifying token changes.')
            issues.append(str(source) + ': school frontend error: token layout only; rewrite the GNU-only construct to enable all AST checks.\n' +
                          '\n'.join(parse_issues))
        with tempfile.TemporaryDirectory(prefix='cp-school-') as directory:
            path = Path(directory) / source.name
            path.write_text(candidate)
            argv, flags, main, input_path, includes = school_gcc_arguments(source, path, directory, gcc, tree)
            output = str(Path(directory) / 'verify.out')
            checked = school_tool([*argv, *flags, *([] if main else ['-c']), '-o', output],
                                  capture_output=True, text=True)
            if checked.returncode:
                syntax = school_syntax_gate(argv, flags)
                if syntax.returncode:
                    raise CheckSetupError(str(source) + ': school: syntax prevents safe publication:\n' +
                                          syntax.stderr.replace(str(path), str(source)))
                issues.append(str(source) + ': school GCC policy error: fix compiler diagnostics:\n' +
                              checked.stderr.replace(str(path), str(source)))
            if tree is not None:
                issues.extend(school_resource_analysis(source, path, input_path, clang, includes))
        diagnostics.extend(issues)
        jobs.append((source, original, candidate.encode('utf-8')))
    changed = [job for job in jobs if job[1] != job[2]]
    check = config.get('prettier') == 'check'
    if check:
        for source, _, _ in changed:
            print(str(source) + ': formatting differs; run cp-run format --school FILE. Policy locations below refer to the formatted candidate.', file=sys.stderr)
    else:
        school_publish(jobs, identities)
        for source, _, _ in changed:
            print(str(source) + ': school layout applied', file=sys.stderr)
    for diagnostic in school_compact_diagnostics(diagnostics):
        print(diagnostic, file=sys.stderr)
    if diagnostics:
        print('school: resolve the reported errors/reviews and run format again.', file=sys.stderr)
        if any('review required:' in item for item in diagnostics):
            print('After inspecting a review, add a file comment: // school-reviewed RULE: specific reason', file=sys.stderr)
    else:
        print('school: automatic checks passed; required author reviews are explicit in source comments.', file=sys.stderr)
    return int(bool(diagnostics) or check and bool(changed))
