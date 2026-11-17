"""GNU-compatible Clang parsing with dependency-validated precompiled preambles."""
SCHOOL_CPP_CONTEXTS = {}
SCHOOL_HEADER_SEARCHES = {}
SCHOOL_PREAMBLES = {}
SCHOOL_FRONTEND_ENVIRONMENT = (
    'CPATH', 'C_INCLUDE_PATH', 'CPLUS_INCLUDE_PATH', 'SDKROOT', 'DEVELOPER_DIR',
    'GCC_EXEC_PREFIX', 'COMPILER_PATH', 'SOURCE_DATE_EPOCH', 'LANG', 'LC_ALL',
)


class SchoolParseIssues(list):
    def __init__(self, messages=(), dependencies=()):
        super().__init__(messages)
        self.dependencies = list(dependencies)
        self.identities = {value: format_file_identity(value) for value in self.dependencies}



def school_header_search(compiler, language, arguments=()):
    """Read real search roots, including framework and nonexistent env roots."""
    key = (str(Path(compiler).resolve()), tuple(format_file_identity(compiler) or ()),
           language, tuple(arguments), str(Path.cwd()),
           tuple(os.environ.get(name) for name in SCHOOL_FRONTEND_ENVIRONMENT))
    if key not in SCHOOL_HEADER_SEARCHES:
        probe = school_tool([compiler, '-E', '-x', language, '-v', *arguments, '-'],
                            input='', text=True, capture_output=True, env=dict(os.environ, LC_ALL='C'))
        paths, inside = [], False
        if not probe.returncode:
            for line in probe.stderr.splitlines():
                value = line.strip()
                if value in ('#include <...> search starts here:', '#include "..." search starts here:'):
                    inside = True
                    continue
                if value == 'End of search list.':
                    break
                if inside and value:
                    framework = value.endswith(' (framework directory)')
                    path = value.removesuffix(' (framework directory)')
                    paths.append((str(Path(path).absolute()), framework))
        # Clang also emits SDK configuration as a prerequisite. Its directory
        # is a conservative dependency root, not an extra compiler include flag.
        for line in probe.stderr.splitlines():
            try:
                words = shlex.split(line)
            except ValueError:
                continue
            for word in words:
                if word.startswith('-fdepfile-entry='):
                    paths.append((str(Path(word.split('=', 1)[1]).absolute().parent), False))
        for name in ('CPATH', 'CPLUS_INCLUDE_PATH' if language == 'c++' else 'C_INCLUDE_PATH'):
            if name in os.environ:
                paths.extend((str(Path(value or '.').absolute()), False)
                             for value in os.environ[name].split(os.pathsep))
        SCHOOL_HEADER_SEARCHES[key] = list(dict.fromkeys(paths))
    return SCHOOL_HEADER_SEARCHES[key]


def school_cpp_context():
    """Query the selected GNU driver; never mix its headers with libc++."""
    gcc = shutil.which(os.environ.get('CP_RUN_GCC', 'gcc-16')) or shutil.which('gcc')
    if not gcc:
        return []
    driver = shutil.which(str(Path(gcc).with_name(Path(gcc).name.replace('gcc', 'g++')))) or gcc
    key = (str(Path(driver).resolve()), tuple(format_file_identity(driver) or ()),
           str(Path.cwd()), tuple(os.environ.get(name) for name in SCHOOL_FRONTEND_ENVIRONMENT))
    if key not in SCHOOL_CPP_CONTEXTS:
        paths = [str(Path(value).resolve()) for value, _ in school_header_search(driver, 'c++')
                 if '/c++/' in value and Path(value).is_dir()]
        SCHOOL_CPP_CONTEXTS[key] = ['-nostdinc++', *[arg for value in dict.fromkeys(paths)
                                                  for arg in ('-isystem', value)]] if paths else []
    return SCHOOL_CPP_CONTEXTS[key]


def school_preamble_prefixes(text):
    """End at the last balanced include, leaving later source macros editable."""
    code, end, depth, prefixes = school_mask(text), 0, 0, []
    pending_include = False
    for start, finish in school_directive_spans(text):
        if code[end:start].strip():
            break
        directive = re.match(r'\s*#\s*([A-Za-z_]\w*)', code[start:finish])
        if not directive or directive[1] == 'line':
            return []
        name = directive[1]
        if name in ('if', 'ifdef', 'ifndef'):
            depth += 1
        elif name == 'endif':
            depth -= 1
        if depth < 0:
            return []
        if name == 'include':
            pending_include = True
        end = finish
        if depth == 0 and pending_include:
            if school_includes(text[:end]):
                prefixes.append(text[:end])
            pending_include = False
    return prefixes



def school_preamble_prefix(text):
    prefixes = school_preamble_prefixes(text)
    return prefixes[-1] if prefixes else ''


def school_json_roots(output):
    decoder, roots, position = json.JSONDecoder(), [], 0
    while position < len(output):
        while position < len(output) and output[position].isspace():
            position += 1
        if position >= len(output):
            break
        value, position = decoder.raw_decode(output, position)
        roots.append(value)
    return roots



def school_ast_root(output):
    try:
        tree = json.loads(output)
    except (ValueError, TypeError) as error:
        raise CheckSetupError('school: Clang returned invalid AST JSON: ' + str(error)) from error
    if not isinstance(tree, dict) or tree.get('kind') != 'TranslationUnitDecl':
        raise CheckSetupError('school: Clang returned an unsupported AST root')
    return tree


def school_cpp_preamble(source, text, clang, args):
    prefix = school_preamble_prefix(text)
    if not prefix or format_volatile_inputs(prefix, []):
        return None
    key = (str(source.parent), prefix, tuple(args), tuple(format_file_identity(clang) or ()),
           str(Path.cwd()), tuple(os.environ.get(name) for name in SCHOOL_FRONTEND_ENVIRONMENT))
    entry = SCHOOL_PREAMBLES.get(key)
    if entry and all(format_file_identity(value) == identity for value, identity in entry['identities'].items()):
        return entry
    if entry:
        entry['temporary'].cleanup()
        del SCHOOL_PREAMBLES[key]
    search = school_header_search(clang, 'c++', [*args, '-iquote', str(source.parent)])
    cache_key = school_preamble_cache_key(source, prefix, clang, ['clang-pch', *args, search])
    restored = school_preamble_cache_load(source, prefix, cache_key)
    if restored is not None:
        SCHOOL_PREAMBLES[key] = restored
        school_preamble_trim()
        return restored
    temporary = tempfile.TemporaryDirectory(prefix='cp-format-preamble-')
    pch, dependency = Path(temporary.name) / 'prefix.pch', Path(temporary.name) / 'prefix.d'
    prefixes = school_preamble_prefixes(text)
    attempts = list(dict.fromkeys([prefix, prefixes[0]]))
    for prepared in attempts:
        result = school_tool([clang, '-x', 'c++-header', '-std=gnu++17', *args,
                             '-iquote', str(source.parent), '-MD', '-MF', str(dependency),
                             '-MT', 'cp_source', '-o', str(pch), '-'],
                            input=prepared, text=True, capture_output=True)
        if not result.returncode and pch.is_file() and dependency.is_file():
            break
    else:
        temporary.cleanup()
        return None
    dependencies = [str(Path(value).absolute()) for value in format_dependency_paths(dependency.read_text())]
    if format_volatile_inputs(prefix, dependencies):
        temporary.cleanup()
        return None
    dependencies = list(dict.fromkeys(dependencies))
    cacheable = True
    try:
        watched = set(dependencies) | format_include_candidates(source, prefix, dependencies, search)
        identities = {value: format_file_identity(value) for value in watched}
    except (OSError, ValueError):
        # Still use this invocation's PCH; unknown lookup alternatives only
        # prevent reuse, not full source analysis.
        identities = {value: format_file_identity(value) for value in dependencies}
        cacheable = False
    entry = dict(temporary=temporary, pch=str(pch), prefix=prepared,
                 dependencies=dependencies, identities=identities)
    if cacheable:
        school_preamble_cache_store(source, cache_key, entry)
        SCHOOL_PREAMBLES[key] = entry
        school_preamble_trim()
    return entry


def school_preamble_trim():
    while len(SCHOOL_PREAMBLES) > 4:
        key = next(iter(SCHOOL_PREAMBLES))
        SCHOOL_PREAMBLES.pop(key)['temporary'].cleanup()


def school_preamble_input(text, entry):
    # Mask bytes, not Unicode code points: AST offsets are UTF-8 byte offsets.
    prefix = entry['prefix'].encode('utf-8')
    blank = bytes(byte if byte in (10, 13) else 32 for byte in prefix)
    return (blank + text.encode('utf-8')[len(prefix):]).decode('utf-8')


def school_query_ast(source, text, clang, args, entry, name, appended=''):
    result = school_tool([clang, '-x', 'c++', '-std=gnu++17', *args,
                         '-iquote', str(source.parent), '-include-pch', entry['pch'],
                         '-Xclang', '-ast-dump=json', '-Xclang', '-ast-dump-filter=' + name,
                         '-fsyntax-only', '-'],
                        input=school_preamble_input(text, entry) + appended,
                        text=True, capture_output=True)
    if result.returncode:
        return None
    try:
        return school_json_roots(result.stdout)
    except (ValueError, TypeError):
        return None


def school_preamble_semantics(source, text, clang, args, entry, tree):
    """Recover only used external enum values and catch ancestry, not header bodies."""
    local_ids = {node.get('id') for node in school_nodes(tree) if node.get('kind') == 'EnumConstantDecl'}
    references = {}
    catch_types = set()
    for node in school_nodes(tree):
        reference = node.get('referencedDecl', {})
        if reference.get('kind') == 'EnumConstantDecl' and reference.get('id') not in local_ids:
            references[reference['id']] = reference
        if node.get('kind') == 'CXXTryStmt':
            handlers = [child for child in node.get('inner', []) if child.get('kind') == 'CXXCatchStmt']
            if len(handlers) > 1:
                for handler in handlers:
                    for child in handler.get('inner', []):
                        if child.get('kind') == 'VarDecl':
                            typ = child.get('type', {}).get('desugaredQualType', child.get('type', {}).get('qualType', ''))
                            catch_types.add(re.sub(r'\bconst\b|[&* ]', '', typ))
    values = {}
    if references:
        tag = '__cp_format_value_' + hashlib.sha256(text.encode()).hexdigest()[:16]
        while tag in text:
            tag += '_'
        declarations = []
        identifiers = list(references)
        for index, reference in enumerate(references.values()):
            typ, name = reference.get('type', {}).get('qualType', ''), reference.get('name', '')
            if not re.fullmatch(r'[A-Za-z_]\w*(?:::[A-Za-z_]\w*)*', name):
                return False
            if '(unnamed enum' in typ or '(anonymous enum' in typ:
                scope = typ.split('(', 1)[0].rstrip(': ')
                expression = (scope + '::' if scope else '') + name
            elif re.fullmatch(r'[A-Za-z_]\w*(?:::[A-Za-z_]\w*)*', typ):
                expression = typ + '::' + name
            else:
                return False
            declarations.append('enum { ' + tag + str(index) +
                                ' = static_cast<__underlying_type(decltype(' + expression + '))>(' + expression + ') };')
        roots = school_query_ast(source, text, clang, args, entry, tag, '\n' + '\n'.join(declarations) + '\n')
        if roots is None:
            return False
        for root in roots:
            name = root.get('name', '')
            if root.get('kind') == 'EnumConstantDecl' and name.startswith(tag):
                try:
                    index = int(name[len(tag):])
                    value = next(node['value'] for node in school_nodes(root)
                                 if node.get('kind') == 'ConstantExpr' and 'value' in node)
                    values[identifiers[index]] = int(value)
                except (ValueError, IndexError, StopIteration):
                    return False
        if len(values) != len(references):
            return False
    bases, pending = {}, list(catch_types)
    builtin = {'int', 'char', 'long', 'short', 'bool', 'float', 'double', 'unsigned', '...'}
    while pending:
        name = pending.pop()
        if name in bases or name in builtin:
            continue
        if len(bases) >= 32 or not re.fullmatch(r'[A-Za-z_]\w*(?:::[A-Za-z_]\w*)*', name):
            return False
        roots = school_query_ast(source, text, clang, args, entry, name)
        if roots is None:
            return False
        records = [node for root in roots for node in school_nodes(root)
                   if node.get('kind') == 'CXXRecordDecl' and node.get('completeDefinition')
                   and node.get('name') == name.rsplit('::', 1)[-1]]
        if len(records) != 1:
            return False
        inherited = [base.get('type', {}).get('desugaredQualType', base.get('type', {}).get('qualType', '')) for base in records[0].get('bases', [])]
        bases[name] = inherited
        bases.setdefault(records[0]['name'], inherited)
        pending.extend(inherited)
    tree['school_external_values'] = values
    tree['school_external_bases'] = bases
    return True


def school_frontend_parse(source, text, clang, cpp):
    args = school_cpp_context() if cpp else []
    entry = school_cpp_preamble(source, text, clang, args) if cpp else None
    with tempfile.TemporaryDirectory(prefix='cp-format-deps-') as directory:
        dependency = Path(directory) / 'source.d'
        invocation = [clang, '-x', 'c++' if cpp else 'c', '-std=gnu++17' if cpp else '-std=gnu99',
                      *args, '-iquote', str(source.parent), '-Xclang', '-ast-dump=json',
                      '-fsyntax-only', '-MD', '-MF', str(dependency), '-MT', 'cp_source']
        if cpp and entry is None and school_preamble_prefix(text):
            probe = school_tool([clang, '-x', 'c++', '-std=gnu++17', *args,
                                 '-iquote', str(source.parent), '-fsyntax-only', '-MD',
                                 '-MF', str(dependency), '-MT', 'cp_source', '-'],
                                input=text, text=True, capture_output=True)
            if probe.returncode:
                dependencies = format_dependency_paths(dependency.read_text()) if dependency.exists() else []
                return None, SchoolParseIssues([str(source) + ': school parser error:\n' + probe.stderr], dependencies)
        result = school_tool([*invocation, *(['-include-pch', entry['pch']] if entry else []), '-'],
                             input=school_preamble_input(text, entry) if entry else text,
                             text=True, capture_output=True)
        dependencies = format_dependency_paths(dependency.read_text()) if dependency.exists() else []
        if entry:
            dependencies = [value for value in dependencies if value != entry['pch']]
            dependencies.extend(entry['dependencies'])
        if entry:
            for value, identity in entry['identities'].items():
                if format_file_identity(value) != identity:
                    raise CheckSetupError('dependency changed during formatting: ' + value)
        if result.returncode:
            return None, SchoolParseIssues([str(source) + ': school parser error:\n' + result.stderr], dependencies)
        tree = school_ast_root(result.stdout)
        if entry and not school_preamble_semantics(source, text, clang, args, entry, tree):
            # An uncommon expression inaccessible to the small metadata probes
            # must receive full analysis, never an optimistic partial result.
            result = school_tool([*invocation, '-'], input=text, text=True, capture_output=True)
            if result.returncode:
                return None, SchoolParseIssues([str(source) + ': school parser error:\n' + result.stderr], dependencies)
            tree = school_ast_root(result.stdout)
            if dependency.exists():
                dependencies.extend(format_dependency_paths(dependency.read_text()))
            for value, identity in entry['identities'].items():
                if format_file_identity(value) != identity:
                    raise CheckSetupError('dependency changed during formatting: ' + value)
            entry = None
    reduced = school_reduce_tree(tree, list(dict.fromkeys(dependencies)))
    if entry:
        for value, identity in entry['identities'].items():
            if format_file_identity(value) != identity:
                raise CheckSetupError('dependency changed during formatting: ' + value)
        reduced['school_dependency_identities'].update(entry['identities'])
    return reduced, SchoolParseIssues()
