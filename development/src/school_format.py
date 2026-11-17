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
    'CommentPragmas': '^ *school-(reviewed|justified|warning)',
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
    # Other project implementations are outside this formatting action. Compile
    # this unit; the read-only Makefile audit owns the complete-link obligation.
    project = any(item[1] == '"' and (source.parent / item[2]).is_file()
                  for item in school_includes(path.read_text()))
    main = main and not project
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


def school_analyze(config):
    """Publish safe layout first; unresolved obligations still return failure."""
    clang = shutil.which('clang')
    formatter = shutil.which(config.get('native_formatter', 'clang-format'))
    gcc = shutil.which(os.environ.get('CP_RUN_GCC', 'gcc-16')) or shutil.which('gcc')
    if not all((clang, formatter, gcc)):
        raise CheckSetupError('school needs clang-format, clang (AST) and GNU GCC.')
    banner = school_tool([gcc, '--version'], capture_output=True, text=True)
    if banner.returncode or 'clang' in banner.stdout.lower() or not re.search(r'GNU|gcc|g\+\+', banner.stdout):
        raise CheckSetupError('school needs GNU GCC; set CP_RUN_GCC to its executable.')
    jobs, diagnostics, identities, cache_jobs, inputs = [], [], {}, [], set()
    for value in dict.fromkeys(format_source_list(config)):
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
        clean = format_strip_automatic(text)
        cpp_driver = shutil.which(str(Path(gcc).with_name(Path(gcc).name.replace('gcc', 'g++')))) or gcc
        tools = [clang, formatter, gcc, cpp_driver]
        cached = format_cache_load(source, clean, tools, config)
        if cached is not None:
            diagnostics.extend(cached[0])
            inputs.update(cached[1])
            jobs.append((source, original, clean.encode('utf-8')))
            continue
        cpp = source.suffix not in ('.c', '.h')
        language = 'c++' if cpp else 'c'
        search = [*school_header_search(cpp_driver if cpp else gcc, language),
                  *school_header_search(clang, language,
                      [*(school_cpp_context() if cpp else []), '-iquote', str(source.parent)])]
        original_tree, parse_issues = school_parse(source, clean, clang)
        candidate, issues = clean, []
        if original_tree is not None:
            candidate, issues = school_prepare(source, clean, clang, original_tree)
        style = dict(SCHOOL_STYLE)
        if original_tree is None:
            style['InsertBraces'] = False
        formatted = school_tool([formatter, '--style=' + json.dumps(style),
            '--assume-filename=' + str(source)], input=candidate, text=True, capture_output=True)
        if formatted.returncode:
            raise CheckSetupError(formatted.stderr)
        candidate = formatted.stdout
        tree = None
        parser_locations_current = candidate == clean
        if original_tree is not None:
            candidate, tree, final_parse = school_apply_layout(source, candidate, clang, original_tree if candidate == clean else None)
            if tree is None:
                raise CheckSetupError(str(source) + ': school: candidate failed parsing:\n' + '\n'.join(final_parse))
            school_verify_layout(source, clean, original_tree, candidate, tree)
            policy = SchoolPolicy(source, candidate, tree)
            issues.extend(policy.run())
        else:
            if [token for token, _ in school_tokens(clean)] != [token for token, _ in school_tokens(candidate)]:
                raise CheckSetupError(str(source) + ': school: unsupported syntax prevents verifying token changes.')
            if candidate != clean:
                parsed_candidate, current_issues = school_parse(source, candidate, clang)
                if parsed_candidate is None:
                    parse_issues = current_issues
                    parser_locations_current = True
            issues.append(FormatFinding(source, 1, 1, 'frontend', 'error',
                          'token layout only; AST checks unavailable: Clang could not parse this source.\n' + '\n'.join(parse_issues)))
        dependency_identities = original_tree.get('school_dependency_identities', {}) if original_tree else getattr(parse_issues, 'identities', {})
        dependencies = list(tree.get('school_dependencies', [])) if tree is not None else list(getattr(parse_issues, 'dependencies', []))
        with tempfile.TemporaryDirectory(prefix='cp-school-') as directory:
            path = Path(directory) / source.name
            path.write_text(candidate)
            argv, flags, main, input_path, includes = school_gcc_arguments(source, path, directory, gcc, tree)
            output = str(Path(directory) / 'verify.out')
            dependency = Path(directory) / 'gcc.d'
            checked, warning_failure = school_gcc_check(argv, flags, output, dependency, banner.stdout)
            if dependency.exists():
                dependencies.extend(value for value in format_dependency_paths(dependency.read_text())
                                    if not Path(value).is_relative_to(directory))
            if checked.returncode:
                syntax = None if warning_failure else school_syntax_gate(argv, flags)
                if syntax is not None and syntax.returncode:
                    raise CheckSetupError(str(source) + ': school: syntax prevents safe publication:\n' +
                                          syntax.stderr.replace(str(path), str(source)))
                issues.append(FormatFinding(source, 1, 1, 'GCC', 'error', 'fix compiler diagnostics:\n' +
                              checked.stderr.replace(str(path), str(source))))
            if tree is not None and school_needs_resource_analysis(source, candidate, tree):
                for finding in school_resource_analysis(source, path, input_path, clang, includes):
                    if finding.source != str(source) or (finding.rule, finding.line) not in policy.error_justifications:
                        issues.append(finding)
        dependencies = set(dependencies) | {str(source.with_suffix('.h')),
                       str(source.parent / 'Makefile'), str(source.parent / 'makefile')}
        snapshot = None
        if config.get('format_cache', True):
            try:
                expanded = dependencies | format_include_candidates(source, candidate, dependencies, search)
                snapshot = {value: format_file_identity(value) for value in expanded}
                dependencies = expanded
            except (OSError, ValueError):
                pass  # Unusable speculative include paths disable optional result caching.
        for dependency_name, identity in dependency_identities.items():
            if format_file_identity(dependency_name) != identity:
                raise CheckSetupError('dependency changed during formatting: ' + dependency_name)
        inputs.update(dependencies)
        inputs.update(str(value) for value in (source.with_suffix('.h'), source.parent / 'Makefile', source.parent / 'makefile'))
        # A backend limitation remains an error in the cache; only unchanged
        # layout is eligible so parser locations still describe the source.
        if snapshot is not None and (tree is not None or parser_locations_current):
            cache_jobs.append((source, candidate, list(issues), snapshot, tools))
        diagnostics.extend(issues)
        jobs.append((source, original, candidate.encode('utf-8')))
    return FormatResult(diagnostics, jobs, identities, cache_jobs, list(inputs))


def execute_school_format(config):
    return execute_format_review(dict(config, format_mode='school'))
