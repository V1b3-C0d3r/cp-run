"""School policy checks over Clang's parsed source; no candidate is executed."""

SCHOOL_C_FLAGS = (
    '-O2 -Wall -Werror -Wformat-security -Wignored-qualifiers -Winit-self '
    '-Wswitch-default -Wfloat-equal -Wpointer-arith -Wtype-limits -Wempty-body '
    '-Wno-logical-op -Wstrict-prototypes -Wold-style-declaration -Wold-style-definition '
    '-Wmissing-parameter-type -Wmissing-field-initializers -Wnested-externs '
    '-Wno-pointer-sign -Wno-unused-result -std=gnu99 -lm -lm'
).split()
SCHOOL_STYLE = {
    'BasedOnStyle': 'LLVM', 'IndentWidth': 4, 'ContinuationIndentWidth': 8,
    'ColumnLimit': 100, 'UseTab': 'Never', 'BreakBeforeBraces': 'Attach',
    'AlwaysBreakAfterReturnType': 'AllDefinitions', 'AlignAfterOpenBracket': 'DontAlign',
    'IndentCaseLabels': False, 'IndentGotoLabels': False, 'PointerAlignment': 'Right',
    'DerivePointerAlignment': False, 'SpaceAfterCStyleCast': True, 'InsertBraces': True,
    'AllowShortFunctionsOnASingleLine': 'None', 'AllowShortLoopsOnASingleLine': False,
    'AllowShortIfStatementsOnASingleLine': 'Never', 'BinPackParameters': False,
    'SortIncludes': 'Never',
}


def school_prepare(source, text, clang):
    """Return a candidate and actionable policy diagnostics, never regex-rewrite C."""
    cpp = source.suffix != '.c'
    parse = subprocess.run([clang, '-x', 'c++' if cpp else 'c',
        '-std=gnu++17' if cpp else '-std=gnu99', '-iquote', str(source.parent),
        '-Xclang', '-ast-dump=json', '-fsyntax-only', '-'],
        input=text, text=True, capture_output=True)
    if parse.returncode:
        return text, [str(source) + ': cannot parse source; fix syntax/includes:\n' + parse.stderr]
    tree = json.loads(parse.stdout)
    diagnostics, edits = [], []
    encoded = text.encode('utf-8')

    def report(node, rule, suggestion):
        location = node.get('loc') or node.get('range', {}).get('begin', {})
        offset = location.get('offset', 0)
        line = encoded[:offset].count(b'\n') + 1
        diagnostics.append('{}:{}: school {}: {}'.format(source, line, rule, suggestion))

    def local(node):
        loc = node.get('loc') or node.get('range', {}).get('begin', {})
        return ('offset' in loc and 'includedFrom' not in loc
                and loc.get('file', '<stdin>') == '<stdin>'
                and 0 <= loc['offset'] < len(encoded))

    def walk(node, parents=()):
        kind, name = node.get('kind'), node.get('name', '')
        inner = node.get('inner', [])
        if local(node):
            if kind in ('FunctionDecl', 'VarDecl', 'FieldDecl', 'LabelStmt', 'ParmVarDecl') and name and not (kind == 'VarDecl' and 'const ' in node.get('type', {}).get('qualType', '')):
                if not re.fullmatch(r'[a-z][a-z0-9]*(?:_[a-z0-9]+)*', name) or name == 'l':
                    report(node, '3.4–3.7', 'rename {} using readable lower_snake_case; avoid l.'.format(name))
            if kind in ('RecordDecl', 'CXXRecordDecl', 'TypedefDecl') and name:
                if not re.fullmatch(r'[A-Z][A-Za-z0-9]*', name):
                    report(node, '3.6', 'rename type {} using PascalCase.'.format(name))
            if kind == 'EnumConstantDecl' and (not re.fullmatch(r'[A-Z][A-Z0-9_]*', name) or name in ('I', 'O')):
                report(node, '3.3, 3.7', 'rename constant {} using readable UPPER_SNAKE_CASE.'.format(name))
            if kind == 'FunctionDecl' and any(n.get('kind') == 'CompoundStmt' for n in inner):
                body = next(n for n in inner if n.get('kind') == 'CompoundStmt')
                if not any(n.get('kind') == 'ReturnStmt' for n in school_nodes(body)):
                    report(node, '4.5.1, 5.7', 'add an explicit return with the appropriate result.')
                start = node['loc']['offset'] + len(name.encode())
                tail = encoded[start:]
                empty = re.match(rb'\s*\(\s*\)', tail)
                if empty:
                    edits.append((start, start + empty.end(), b'(void)'))
                if name != 'main':
                    header = source.with_suffix('.h')
                    if not header.is_file():
                        report(node, '6.1', 'provide {} with types/prototypes for this module.'.format(header.name))
            if kind in ('IntegerLiteral', 'FloatingLiteral') and 'EnumConstantDecl' not in parents and 'ConstantVar' not in parents:
                value = str(node.get('value', ''))
                if value not in ('0', '1'):
                    # Context-specific exceptions require author review, not a silent rewrite.
                    report(node, '5.1', 'replace literal {} with a named constant, or verify the stderr/error-sentinel exception.'.format(value))
            if kind == 'VarDecl':
                typ = node.get('type', {}).get('qualType', '')
                if '[' in typ and not re.search(r'\[\d*\]', typ):
                    report(node, '5.16', 'replace variable-length array with a fixed bound or managed allocation.')
                if 'const ' in typ and re.search(r'\b(int|long|short|char)\b', typ):
                    report(node, '5.2', 'define integer constants with enum.')
            if kind == 'CallExpr':
                refs = [n.get('referencedDecl', {}).get('name') for n in school_nodes(node)]
                banned = set(refs) & {'gets', 'sprintf', 'strcpy', 'strcat', 'strncpy', 'strncat'}
                if banned:
                    report(node, '5.8', 'replace unsafe {} with bounded input/output or explicit checked copying.'.format(', '.join(sorted(banned))))
                literals = [n.get('value', '') for n in school_nodes(node) if n.get('kind') == 'StringLiteral']
                if set(refs) & {'scanf', 'fscanf'} and any(re.search(r'%(?:\*)?s', v) for v in literals):
                    report(node, '5.8', 'add a field width to every scanf %s conversion.')
                if set(refs) & {'printf', 'fprintf', 'puts', 'fputs'}:
                    if 'puts' not in refs and literals and not literals[0].strip('"').endswith(('\\n', '\n')):
                        report(node, '5.5–5.6', 'ensure the final output/diagnostic ends with a newline; combine split output explicitly.')
                if set(refs) & {'calloc', 'realloc'}:
                    if not any(n.get('kind') == 'UnaryExprOrTypeTraitExpr' and n.get('name') == 'sizeof'
                               for n in school_nodes(node)):
                        report(node, '5.11', 'express allocation bytes as count * sizeof(element).')
                if 'malloc' in refs:
                    report(node, '5.9', 'use calloc; retain malloc only for a documented realloc-based growable array.')
            if kind == 'UnaryExprOrTypeTraitExpr' and node.get('name') == 'sizeof' and node.get('argType'):
                report(node, '5.10', 'prefer sizeof(expression) when an object expression is available.')
            if kind == 'CStyleCastExpr' and not cpp:
                if any(n.get('referencedDecl', {}).get('name') in ('malloc', 'calloc', 'realloc')
                       for n in school_nodes(node)):
                    report(node, '5.18', 'remove the cast on the allocation result.')
            if kind == 'VarDecl' and 'FunctionDecl' not in parents:
                report(node, '5.14', 'justify this global variable or pass it as a parameter.')
            if kind == 'DeclStmt':
                variables = [n for n in inner if n.get('kind') == 'VarDecl']
                if len(variables) > 1 and any(
                        any(c.get('kind') == 'CallExpr' for c in school_nodes(n)) for n in variables):
                    report(node, '4.4.5', 'split initialized variables into separate declarations.')
            if kind == 'RecordDecl' and node.get('tagUsed') == 'struct':
                field_lines = []
                for field in inner:
                    if field.get('kind') == 'FieldDecl' and local(field):
                        line = encoded[:field['loc']['offset']].count(b'\n')
                        if line in field_lines:
                            report(field, '4.1', 'place each structure field declaration on its own line.')
                        field_lines.append(line)
            if kind == 'GotoStmt':
                report(node, '4.6.11', 'verify this is a forward jump for error cleanup or nested-loop exit.')
        parent_kind = 'ConstantVar' if kind == 'VarDecl' and 'const ' in node.get('type', {}).get('qualType', '') else kind
        for child in inner:
            walk(child, (*parents, parent_kind))
    walk(tree)
    for start, end, replacement in sorted(set(edits), reverse=True):
        encoded = encoded[:start] + replacement + encoded[end:]
    # These are source directives, not matches against code hidden in strings/comments.
    directive_text = re.sub(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"',
        lambda match: ''.join('\n' if c == '\n' else ' ' for c in match[0]),
        text, flags=re.S)
    for line_number, line in enumerate(directive_text.splitlines(), 1):
        if re.match(r'^\s*#\s*define\s+\w+\s+[-+]?\d', line):
            diagnostics.append('{}:{}: school 5.2: replace integer #define with enum.'.format(source, line_number))
        if any(ord(c) < 32 and c not in '\t\r\n' or ord(c) == 127 for c in line):
            diagnostics.append('{}:{}: school 1.1: remove control characters.'.format(source, line_number))
    return encoded.decode('utf-8'), diagnostics


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
    banner = subprocess.run([gcc, '--version'], capture_output=True, text=True)
    if 'clang' in banner.stdout.lower():
        raise CheckSetupError('school needs GNU GCC; set CP_RUN_GCC to its executable.')
    jobs, diagnostics = [], []
    for value in dict.fromkeys(config.get('protected', [])):
        source = Path(value).resolve()
        if source.suffix not in ('.c', '.cc', '.cpp', '.cxx', '.C'):
            raise CheckUsageError('school supports C and C++ sources only')
        original = source.read_bytes()
        candidate, issues = school_prepare(source, original.decode('utf-8'), clang)
        result = subprocess.run([formatter, '--style=' + json.dumps(SCHOOL_STYLE),
            '--assume-filename=' + str(source)], input=candidate, text=True, capture_output=True)
        if result.returncode:
            raise CheckSetupError(result.stderr)
        candidate = result.stdout
        for i, line in enumerate(candidate.splitlines(), 1):
            if any(ord(c) < 32 or ord(c) == 127 for c in line):
                issues.append('{}:{}: school 1.1: replace literal control characters with escapes.'.format(source, i))
            if len(line) > 100:
                issues.append('{}:{}: school 2.2: split long literal/comment to at most 100 characters.'.format(source, i))
        with tempfile.TemporaryDirectory(prefix='cp-school-') as directory:
            path = Path(directory) / source.name
            path.write_text(candidate)
            flags = list(SCHOOL_C_FLAGS)
            if source.suffix != '.c':
                c_only = {'-std=gnu99', '-Wstrict-prototypes', '-Wold-style-declaration',
                    '-Wold-style-definition', '-Wmissing-parameter-type', '-Wnested-externs', '-Wno-pointer-sign'}
                flags = [f for f in flags if f not in c_only] + ['-std=gnu++17']
            driver = gcc
            if source.suffix != '.c':
                driver = shutil.which(str(Path(gcc).with_name(Path(gcc).name.replace('gcc', 'g++')))) or gcc
            output = str(Path(directory) / 'verify.out')
            compile_only = [] if re.search(r'\bmain\s*\(', candidate) else ['-c']
            checked = subprocess.run([driver, '-x', 'c' if source.suffix == '.c' else 'c++',
                str(path), '-iquote', str(source.parent), *flags, *compile_only, '-o', output],
                capture_output=True, text=True)
            if checked.returncode:
                issues.append(str(source) + ': school GCC flags: fix the compiler diagnostics:\n' +
                              checked.stderr.replace(str(path), str(source)))
        if source.suffix == '.c' and not re.search(r'\bmain\s*\(', candidate):
            header = source.with_suffix('.h')
            if header.exists() and ('#include "' + header.name + '"') not in candidate:
                issues.append(str(source) + ': school 6.3: include your module header.')
            makefile = source.parent / 'Makefile'
            if not makefile.is_file():
                issues.append(str(source) + ': school 6.6: supply a Makefile with all and clean targets.')
        diagnostics.extend(issues)
        jobs.append((source, original, candidate.encode('utf-8')))
    if diagnostics:
        print('\n'.join(diagnostics), file=sys.stderr)
        return 1
    print('school review: names/intent, resource lifetime, output semantics and module dependencies require author review (see docs/SCHOOL_FORMAT.md).', file=sys.stderr)
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
