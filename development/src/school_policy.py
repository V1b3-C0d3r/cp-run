"""Per-rule school checks. Author review cannot suppress mechanical errors."""

import ast as school_python_ast

SCHOOL_RULES = (
    tuple('1.' + str(i) for i in range(1, 3)) +
    tuple('2.' + str(i) for i in range(1, 4)) +
    tuple('3.' + str(i) for i in range(1, 8)) +
    ('4.1', '4.2', '4.3') +
    tuple('4.4.' + str(i) for i in range(1, 6)) +
    tuple('4.5.' + str(i) for i in range(1, 4)) +
    tuple('4.6.' + str(i) for i in range(1, 13)) +
    tuple('4.7.' + str(i) for i in range(1, 10)) +
    tuple('5.' + str(i) for i in range(1, 19)) +
    tuple('6.' + str(i) for i in range(1, 7))
)
SCHOOL_REVIEW_RULES = {
    '3.1', '3.2', '3.4', '3.5', '3.7', '4.4.1', '4.4.4', '4.5.1',
    '4.6.11', '4.6.12', '4.7.9', '5.1', '5.2', '5.3', '5.4', '5.5', '5.6',
    '5.7', '5.8', '5.9', '5.10', '5.11', '5.12', '5.13', '5.14',
    '5.15', '5.17', '6.1', '6.4', '6.5', '6.6',
}
# A scanner keeps comments and literals out of directive/code checks.
SCHOOL_LEXER = re.compile(
    r'(?P<raw>(?:u8|[uUL])?R"(?P<raw_delimiter>[^ ()\\\t\r\n]{0,16})'
    r'\(.*?\)(?P=raw_delimiter)")|'
    r'(?P<comment>/\*.*?\*/|//(?:[^\r\n\\]|\\[^\r\n]|\\(?:\r\n|\r|\n))*)|'
    r'(?P<string>(?:u8|[uUL])?"(?:\\.|[^"\\])*")|'
    r"(?P<char>(?<![\w.])(?:u8|[uUL])?'(?:\\.|[^'\\])*')", re.S)
SCHOOL_STANDARD_HEADERS = set((
    'assert.h complex.h ctype.h errno.h fenv.h float.h inttypes.h iso646.h limits.h '
    'locale.h math.h setjmp.h signal.h stdalign.h stdarg.h stdatomic.h stdbool.h '
    'stddef.h stdint.h stdio.h stdlib.h stdnoreturn.h string.h tgmath.h threads.h '
    'time.h uchar.h wchar.h wctype.h unistd.h fcntl.h stdio_ext.h'
).split())
SCHOOL_OUTPUT_CALLS = {'printf', 'fprintf', 'vprintf', 'vfprintf', 'puts', 'fputs',
                       'putchar', 'putc', 'fputc', 'write', 'dprintf', 'perror'}
SCHOOL_ALLOCATORS = {'malloc', 'calloc', 'realloc'}
SCHOOL_UNSAFE_CALLS = {'gets', 'sprintf', 'strcpy', 'strcat', 'strncpy', 'strncat'}


def school_mask(text):
    return SCHOOL_LEXER.sub(
        lambda match: ''.join('\n' if c == '\n' else ' ' for c in match[0]), text)


def school_parse(source, text, clang, cpp=None):
    if cpp is None:
        cpp = source.suffix not in ('.c', '.h')
    result = school_tool(
        [clang, '-x', 'c++' if cpp else 'c',
         '-std=gnu++17' if cpp else '-std=gnu99', '-iquote', str(source.parent),
         '-Xclang', '-ast-dump=json', '-fsyntax-only', '-'],
        input=text, text=True, capture_output=True)
    if result.returncode:
        return None, [str(source) + ': school syntax/5.3/6.4: fix compiler diagnostics:\n' +
                      result.stderr]
    try:
        tree = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise CheckSetupError('school: Clang returned invalid AST JSON: ' + str(error)) from error
    if not isinstance(tree, dict) or tree.get('kind') != 'TranslationUnitDecl':
        raise CheckSetupError('school: Clang returned an unsupported AST root')
    return tree, []


def school_tool(argv, **options):
    try:
        return subprocess.run(argv, timeout=60, **options)
    except subprocess.TimeoutExpired as error:
        raise CheckSetupError('school: tool timed out: ' + str(argv[0])) from error


def school_location(node):
    location = node.get('loc') or node.get('range', {}).get('begin', {})
    return location.get('expansionLoc', location)


def school_unwrap(node):
    while node.get('kind') in ('ImplicitCastExpr', 'ParenExpr', 'ConstantExpr',
                               'ExprWithCleanups', 'MaterializeTemporaryExpr'):
        children = node.get('inner', [])
        if len(children) != 1:
            break
        node = children[0]
    return node



def school_integer(node, constants):
    if not node:
        return None
    node = school_unwrap(node)
    if node.get('kind') in ('IntegerLiteral', 'CharacterLiteral', 'ConstantExpr') and 'value' in node:
        try:
            return int(node['value'])
        except ValueError:
            return None
    node = school_unwrap(node)
    if node.get('kind') == 'DeclRefExpr':
        return constants.get(node.get('referencedDecl', {}).get('id'))
    inner = node.get('inner', [])
    if node.get('kind') in ('CStyleCastExpr', 'UnaryOperator') and len(inner) == 1:
        value = school_integer(inner[0], constants)
        if value is not None:
            if node.get('kind') == 'CStyleCastExpr':
                return value
            if node.get('opcode') == '-':
                return -value
            if node.get('opcode') == '+':
                return value
    if node.get('kind') == 'BinaryOperator' and len(inner) == 2:
        left, right = (school_integer(child, constants) for child in inner)
        if left is not None and right is not None:
            operation = node.get('opcode')
            if operation == '+': return left + right
            if operation == '-': return left - right
            if operation == '*': return left * right
    return None


class SchoolPolicy:
    def __init__(self, source, text, tree, cpp=None):
        self.source, self.text, self.tree = source, text, tree
        self.data = text.encode('utf-8')
        self.cpp = source.suffix not in ('.c', '.h') if cpp is None else cpp
        self.code = school_mask(text)
        self.findings = []
        self.reviews = {}
        self.accepted = set()
        self.constants = {}
        self.labels = {}
        self.functions = []
        self.symbols = {node['id']: node for node in school_nodes(tree)
                        if 'id' in node and node.get('kind', '').endswith('Decl')}
        self.record_bases = {
            node.get('name'): [base.get('type', {}).get('qualType', '')
                               for base in node.get('bases', [])]
            for node in school_nodes(tree) if node.get('kind') == 'CXXRecordDecl'
            and node.get('completeDefinition')}
        for node in school_nodes(tree):
            if node.get('kind') == 'EnumDecl':
                value = -1
                for member in node.get('inner', []):
                    if member.get('kind') == 'EnumConstantDecl':
                        explicit = next(iter(member.get('inner', [])), None)
                        current = school_integer(explicit, self.constants)
                        value = value + 1 if current is None else current
                        self.constants[member.get('id')] = value
            if self.local(node) and node.get('kind') == 'LabelStmt':
                self.labels[node.get('declId')] = self.offset(node)
            if self.local(node) and node.get('kind') == 'FunctionDecl':
                if any(child.get('kind') == 'CompoundStmt' for child in node.get('inner', [])):
                    self.functions.append(node)
        self.has_main = any(node.get('name') == 'main' for node in self.functions)
        self.resource_ids = set()
        acquisitions = SCHOOL_ALLOCATORS | {'fopen', 'fdopen', 'freopen', 'open', 'socket', 'opendir', 'dup', 'popen'}
        releases = {'free', 'fclose', 'close', 'closedir', 'pclose'}
        for node in school_nodes(tree):
            kind, children = node.get('kind'), node.get('inner', [])
            if kind == 'VarDecl' and any(
                    child.get('kind') == 'CXXNewExpr' or
                    child.get('kind') == 'CallExpr' and self.callee(child) in acquisitions
                    for child in school_nodes(node)):
                self.resource_ids.add(node.get('id'))
            if kind == 'BinaryOperator' and node.get('opcode') == '=' and len(children) == 2:
                if any(child.get('kind') == 'CallExpr' and self.callee(child) in acquisitions
                       for child in school_nodes(children[1])):
                    self.resource_ids.add(school_unwrap(children[0]).get('referencedDecl', {}).get('id'))
            if kind == 'CallExpr' and self.callee(node) in releases and len(children) > 1:
                self.resource_ids.add(school_unwrap(children[1]).get('referencedDecl', {}).get('id'))
        self.read_reviews()

    def offset(self, node):
        return school_location(node).get('offset', 0)

    def local(self, node):
        if node.get('isImplicit'):
            return False
        loc = school_location(node)
        return ('offset' in loc and 'includedFrom' not in loc and
                loc.get('file', '<stdin>') == '<stdin>' and
                0 <= loc['offset'] < len(self.data))

    def excerpt(self, node):
        span = node.get('range', {})
        start, end = span.get('begin', {}), span.get('end', {})
        start, end = start.get('expansionLoc', start), end.get('expansionLoc', end)
        if 'offset' not in start or 'offset' not in end:
            return ''
        return self.data[start['offset']:end['offset'] + end.get('tokLen', 1)].decode('utf-8')

    def emit(self, rule, message, node=None, line=None, review=False, source=None):
        if rule not in SCHOOL_RULES:
            raise ValueError('unregistered school rule: ' + rule)
        if review and rule in self.reviews and (source is None or source == self.source):
            self.accepted.add(rule)
            return
        if line is None:
            line = self.data[:self.offset(node or {})].count(b'\n') + 1
        severity = 'review required' if review else 'error'
        offset = self.offset(node or {})
        start = self.data.rfind(b'\n', 0, offset) + 1
        column = len(self.data[start:offset].decode('utf-8', errors='replace')) + 1 if node else 1
        self.findings.append('{}:{}:{}: school {} {}: {}'.format(
            source or self.source, line, column, rule, severity, message))

    def callee_declaration(self, node):
        children = node.get('inner', [])
        if not children:
            return {}
        target = school_unwrap(children[0])
        seen = set()
        while True:
            if target.get('kind') == 'UnaryOperator' and target.get('opcode') in ('*', '&'):
                target = school_unwrap(target['inner'][0])
            reference = target.get('referencedDecl', {})
            if reference.get('kind') in ('FunctionDecl', 'CXXMethodDecl'):
                return reference
            identifier = reference.get('id')
            if not identifier or identifier in seen:
                return {}
            seen.add(identifier)
            declaration = self.symbols.get(identifier, {})
            values = declaration.get('inner', [])
            if declaration.get('kind') != 'VarDecl' or not values:
                return {}
            target = school_unwrap(values[-1])

    def callee(self, node):
        name = self.callee_declaration(node).get('name', '').removeprefix('__builtin_')
        fortified = name.removeprefix('__').removesuffix('_chk')
        return fortified if name.endswith('_chk') and fortified in SCHOOL_UNSAFE_CALLS else name

    def canonical_declaration(self, identifier):
        seen = set()
        while identifier not in seen:
            seen.add(identifier)
            previous = self.symbols.get(identifier, {}).get('previousDecl')
            if not previous:
                break
            identifier = previous
        return identifier

    def read_reviews(self):
        for token in SCHOOL_LEXER.finditer(self.text):
            if not token.group('comment'):
                continue
            line_number = self.text[:token.start()].count('\n') + 1
            for index, raw_line in enumerate(token[0].splitlines()):
                line = re.sub(r'^\s*(?://|/\*|\*)?\s*', '', raw_line).removesuffix('*/').strip()
                if not line.startswith('school-reviewed'):
                    continue
                match = re.fullmatch(r'school-reviewed\s+([0-9., ]+):\s*(.+)', line)
                problem = None
                if match is None:
                    problem = 'expected school-reviewed RULE[, RULE]: a specific rationale'
                elif len(match[2].strip()) < 12:
                    problem = 'provide a specific rationale of at least 12 characters'
                if problem:
                    self.findings.append('{}:{}:1: school-review error: {}'.format(
                        self.source, line_number + index, problem))
                    continue
                for rule in (value.strip() for value in match[1].split(',')):
                    if rule not in SCHOOL_RULES:
                        problem = 'unknown rule ' + rule
                    elif rule not in SCHOOL_REVIEW_RULES:
                        problem = 'cannot waive mechanical rule ' + rule
                    else:
                        self.reviews[rule] = match[2].strip()
                        continue
                    self.findings.append('{}:{}:1: school-review error: {}'.format(
                        self.source, line_number + index, problem))

    def declarations(self, node, ancestors):
        kind, name = node.get('kind'), node.get('name', '')
        typ = node.get('type', {}).get('desugaredQualType',
                                     node.get('type', {}).get('qualType', ''))
        declaration = kind in ('FunctionDecl', 'CXXMethodDecl', 'VarDecl', 'FieldDecl',
                               'ParmVarDecl', 'EnumConstantDecl', 'TypedefDecl',
                               'RecordDecl', 'CXXRecordDecl', 'EnumDecl', 'LabelStmt')
        if kind == 'CXXMethodDecl' and name.startswith('operator'):
            declaration = False  # Operator spellings are imposed by the language.
        if declaration and name and name not in ('main', 'argc', 'argv'):
            forbidden = (not name.isascii() or name == 'vychislenie_kornya' or
                         kind in ('FunctionDecl', 'CXXMethodDecl') and name == 'f')
            if forbidden:
                self.emit('3.2', 'use an English identifier; this spelling is explicitly prohibited by the policy.', node)
            self.emit('3.2', 'confirm that "{}" is English or a conventional abbreviation, not transliteration.'.format(name),
                      node, review=True)
        if kind in ('FunctionDecl', 'VarDecl') and name and name != 'main':
            global_decl = kind == 'FunctionDecl' or not any(
                p.get('kind') in ('FunctionDecl', 'CXXMethodDecl', 'LambdaExpr') for p in ancestors)
            if global_decl:
                self.emit('3.1', 'justify the meaning and length of global name "{}".'.format(name), node, review=True)
        constant = kind == 'EnumConstantDecl' or kind == 'VarDecl' and 'const' in typ and '*' not in typ
        if declaration and name:
            if constant:
                if not re.fullmatch(r'[A-Z][A-Z0-9_]*', name):
                    self.emit('3.3', 'use UPPER_SNAKE_CASE for constant ' + name, node)
            elif kind in ('RecordDecl', 'CXXRecordDecl', 'TypedefDecl', 'EnumDecl'):
                if not re.fullmatch(r'[A-Z][A-Za-z0-9]*', name):
                    self.emit('3.6', 'use PascalCase for type/tag ' + name, node)
            elif not re.fullmatch(r'[a-z][a-z0-9_]*', name):
                teacher_exception = kind in ('FunctionDecl', 'CXXMethodDecl')
                self.emit('3.4', 'use lower_snake_case for {}; a function exception needs teacher approval.'.format(name),
                          node, review=teacher_exception)
            if name in ('l', 'I', 'O'):
                self.emit('3.7', 'rename visually ambiguous identifier ' + name, node)
            elif re.search(r'[IlO0]{2,}', name):
                self.emit('3.7', 'verify visual readability of ' + name, node, review=True)
        if kind in ('VarDecl', 'ParmVarDecl', 'FieldDecl') and name not in ('argc', 'argv') and name:
            self.emit('3.5', 'confirm "{}" does not encode its type in a prefix or suffix.'.format(name),
                      node, review=True)
        if kind == 'FieldDecl' and name and self.cpp and (name.startswith('m_') or name.endswith('_')):
            self.emit('4.1', 'remove the m_ prefix or trailing underscore from this class field.', node)
        if kind == 'VarDecl':
            local = any(p.get('kind') in ('FunctionDecl', 'CXXMethodDecl', 'LambdaExpr') for p in ancestors)
            if constant and re.search(r'\b(char|short|int|long|bool)\b', typ):
                self.emit('5.2', 'define integer constants with enum, not const.', node)
            if not local and node.get('storageClass') != 'extern' and not constant:
                self.emit('5.14', 'justify this global variable or pass state as a parameter.', node, review=True)
            if local and '[' in typ and not re.search(r'\(\s*\*[^)]*\)\s*\[', typ):
                dimensions = re.findall(r'\[([^]]*)\]', typ)
                if any(not dimension.isdecimal() for dimension in dimensions):
                    self.emit('5.16', 'replace this variable-length array with fixed-size storage or allocation.', node)
            init = node.get('inner', [])
            if local and typ.startswith(('struct ', 'union ')) and '*' not in typ and '[' not in typ:
                if init:
                    self.emit('4.4.4', 'zero the local structure with memset before assigning fields.', node,
                              review=self.cpp)
                else:
                    self.structure_zeroing(node, ancestors)
            resource_calls = {self.callee(n) for n in school_nodes(node)
                              if n.get('kind') == 'CallExpr'} & (
                                  SCHOOL_ALLOCATORS | {'fopen', 'fdopen', 'open', 'socket', 'opendir', 'dup'})
            owned = node.get('id') in self.resource_ids or resource_calls or re.search(r'\b(?:FILE|DIR)\s*\*', typ)
            if local and owned:
                body = next((n for n in reversed(ancestors) if n.get('kind') == 'CompoundStmt'), None)
                function_body = next((n for n in ancestors if n.get('kind') == 'CompoundStmt'), None)
                if body is not function_body:
                    self.emit('5.17', 'move resource-holding declarations to the beginning of the function.', node)
                elif body:
                    declaration = next((p for p in reversed(ancestors) if p.get('kind') == 'DeclStmt'), None)
                    statements = body.get('inner', [])
                    if declaration in statements:
                        before = statements[:statements.index(declaration)]
                        if any(n.get('kind') != 'DeclStmt' for n in before):
                            self.emit('5.17', 'declare this resource before executable statements.', node)
                if not node.get('init'):
                    self.emit('5.17', 'initialize the resource to a valid handle or its unallocated sentinel.', node)
                self.emit('5.17', 'prove ownership/borrowing, initialization and timely cleanup on every exit.', node,
                          review=True)
            elif local and ('*' in typ or any(child.get('kind') == 'CXXConstructExpr' for child in init)):
                self.emit('5.17', 'verify this borrowed pointer/custom object lifetime and any RAII cleanup.', node,
                          review=True)

    def structure_zeroing(self, node, ancestors):
        """Require the first real use to zero the whole object, without inventing a memset."""
        function = next((parent for parent in reversed(ancestors)
                         if parent.get('kind') in ('FunctionDecl', 'CXXMethodDecl')), {})
        identifier = node.get('id')

        def first_use(current, parents=()):
            if current.get('kind') == 'DeclRefExpr' and current.get('referencedDecl', {}).get('id') == identifier:
                return parents
            for child in current.get('inner', []):
                result = first_use(child, (*parents, current))
                if result is not None:
                    return result
            return None

        parents = first_use(function)
        if parents is None:
            return  # No initialization is needed for an object which is never used.
        call = next((parent for parent in reversed(parents) if parent.get('kind') == 'CallExpr'), {})
        arguments = call.get('inner', [])[1:]
        zeroed = self.callee(call) in ('memset', '__memset_chk') and len(arguments) >= 3
        if zeroed:
            address, count = school_unwrap(arguments[0]), school_unwrap(arguments[2])
            zeroed = (address.get('kind') == 'UnaryOperator' and address.get('opcode') == '&' and
                      any(child.get('referencedDecl', {}).get('id') == identifier for child in school_nodes(address)) and
                      school_integer(arguments[1], self.constants) == 0 and count.get('name') == 'sizeof' and
                      any(child.get('referencedDecl', {}).get('id') == identifier for child in school_nodes(count)))
        if not zeroed:
            self.emit('4.4.4', 'memset the entire local structure to zero before its first use/field assignment.',
                      node, review=self.cpp)
        elif any(parent.get('kind') in ('IfStmt', 'ForStmt', 'WhileStmt', 'SwitchStmt') for parent in parents):
            self.emit('4.4.4', 'verify every path zeroes this structure before any field is used.', node, review=True)

    def functions_and_records(self, node, ancestors):
        kind = node.get('kind')
        children = node.get('inner', [])
        if kind in ('FunctionDecl', 'CXXMethodDecl'):
            body = next((child for child in children if child.get('kind') == 'CompoundStmt'), None)
            if body is not None:
                parameters = school_definition_parameters(self.text, node)
                if parameters and parameters[1] == parameters[0] + 1:
                    self.emit('4.5.2', 'write (void) for a definition with no parameters; resolve incompatible calls first.', node)
                if parameters:
                    start = node.get('loc', {}).get('offset')
                    finish = body.get('range', {}).get('begin', {}).get('offset')
                    if start is not None and finish is not None:
                        line_start = self.data.rfind(b'\n', 0, start) + 1
                        header = self.data[line_start:finish].decode('utf-8')
                        base = len(header) - len(header.lstrip(' '))
                        if base + len(' '.join(header.split())) + 2 > 70:
                            brace_line = self.data[self.data.rfind(b'\n', 0, finish) + 1:finish]
                            correct = not brace_line.strip()
                            for parameter in (child for child in children if child.get('kind') == 'ParmVarDecl'):
                                location = parameter.get('range', {}).get('begin', {}).get('offset')
                                if location is None:
                                    correct = False
                                    continue
                                prefix = self.data[self.data.rfind(b'\n', 0, location) + 1:location]
                                correct = correct and prefix == b' ' * (base + 8)
                            if not correct:
                                self.emit('4.5.3', 'put each parameter on its own line at +8 spaces and the opening brace on its own line.', node)
                returns = [n for n in school_nodes(body) if n.get('kind') == 'ReturnStmt']
                if not returns:
                    self.emit('4.5.1', 'add an explicit return, including in void functions.', node)
                if node.get('name') == 'main':
                    if not school_guaranteed_return(body):
                        self.emit('5.7', 'show that every reachable main exit executes an explicit return.',
                                  node, review=True)
                    for ret in returns:
                        value = school_integer(next(iter(ret.get('inner', [])), None), self.constants)
                        if value is None:
                            self.emit('5.7', 'prove this main return value belongs to [0, 128).', ret, review=True)
                        elif not 0 <= value < 128:
                            self.emit('5.7', 'main must return a value in [0, 128).', ret)
        for index, body in enumerate(school_control_bodies(node)):
            chained_else = kind == 'IfStmt' and node.get('hasElse') and index == 1 and body.get('kind') == 'IfStmt'
            if body.get('kind') != 'CompoundStmt' and not chained_else:
                self.emit('4.6.8', 'put this control body inside braces, including an empty body.', body)
        if kind in ('RecordDecl', 'CXXRecordDecl') and node.get('tagUsed') in ('struct', 'union'):
            field_lines = set()
            for field in children:
                if field.get('kind') == 'FieldDecl' and self.local(field):
                    line = self.data[:self.offset(field)].count(b'\n')
                    if line in field_lines:
                        self.emit('4.1', 'declare every structure field on its own line.', field)
                    field_lines.add(line)
        if kind == 'DeclStmt':
            declarations = [n for n in children if n.get('kind') == 'VarDecl']
            if len(declarations) > 1:
                complex_init = any(n.get('init') and not school_simple_initializer(n)
                                   for n in declarations)
                if complex_init:
                    self.emit('4.4.5', 'put each nonconstant initialized variable in its own declaration.', node)
            record_starts = {n.get('range', {}).get('begin', {}).get('offset') for n in children
                             if n.get('kind') in ('RecordDecl', 'CXXRecordDecl')}
            if any(n.get('kind') == 'VarDecl' and n.get('range', {}).get('begin', {}).get('offset')
                   in record_starts for n in children):
                self.emit('4.1', 'separate the record definition from object declarations.', node)
        if kind == 'VarDecl':
            begin = node.get('range', {}).get('begin', {}).get('offset')
            for record in self.tree.get('inner', []):
                if record.get('kind') in ('RecordDecl', 'CXXRecordDecl') and record.get('completeDefinition'):
                    if begin == record.get('range', {}).get('begin', {}).get('offset'):
                        self.emit('4.1', 'separate the record definition from object declarations.', node)
                        break
        if kind == 'InitListExpr':
            typ = node.get('type', {}).get('qualType', '')
            for child in children:
                if child.get('kind') == 'InitListExpr' and self.local(child):
                    if not self.excerpt(child).lstrip().startswith('{'):
                        self.emit('4.4.1', 'write explicit braces around each nested initializer.', child)
            if '[' in typ or typ.startswith(('struct ', 'union ')):
                self.emit('4.4.1', 'confirm the grouping reflects the structure of the initialized data.', node,
                          review=True)
        if kind == 'IndirectGotoStmt':
            self.emit('4.6.11', 'resolve every computed goto target and prove forward cleanup-only control flow.', node, review=True)
        if kind == 'GotoStmt':
            target = self.labels.get(node.get('targetLabelDeclId'))
            if target is not None and target <= self.offset(node):
                self.emit('4.6.11', 'backward goto is prohibited; use a loop.', node)
            else:
                self.emit('4.6.11', 'justify a forward goto for cleanup or exiting nested loops.', node, review=True)
        if kind == 'CXXTryStmt':
            catches = [n for n in children if n.get('kind') == 'CXXCatchStmt']
            for catch in catches:
                parameter = next((n for n in catch.get('inner', []) if n.get('kind') == 'VarDecl'), None)
                if parameter:
                    typ = parameter.get('type', {}).get('qualType', '')
                    builtin = re.fullmatch(r'(?:const )?(?:int|char|double|float|long|short|bool)(?:[ &*]+)?', typ)
                    if not builtin and not ('const ' in typ and '&' in typ):
                        self.emit('4.6.12', 'catch user-defined exception objects by const reference.', parameter)
            previous = []
            for catch in catches:
                parameter = next((n for n in catch.get('inner', []) if n.get('kind') == 'VarDecl'), None)
                if parameter is None:
                    previous.append('*')
                    continue
                typ = parameter.get('type', {}).get('desugaredQualType',
                        parameter.get('type', {}).get('qualType', ''))
                name = re.sub(r'\bconst\b|[&* ]', '', typ)
                bases, pending = set(), list(self.record_bases.get(name, []))
                while pending:
                    base = pending.pop()
                    if base not in bases:
                        bases.add(base)
                        pending.extend(self.record_bases.get(base, []))
                if '*' in previous or name in previous or bases.intersection(previous):
                    self.emit('4.6.12', 'put this specialized catch before handlers for its base types/catch-all.', catch)
                previous.append(name)
            if len(catches) > 1:
                self.emit('4.6.12', 'verify catch order from specialized to general exception types.', node, review=True)

    def expressions(self, node, ancestors):
        kind = node.get('kind')
        inner = node.get('inner', [])
        if kind in ('IntegerLiteral', 'FloatingLiteral'):
            spelling = node.get('range', {}).get('begin', {}).get('spellingLoc', {})
            if spelling.get('file') == '<scratch space>':
                self.emit('4.5.1', 'verify location-sensitive macro values after layout changes (for example __LINE__).',
                          node, review=True)
                return
            generated_in_header = bool(spelling.get('includedFrom'))
            constant_context = generated_in_header or any(n.get('kind') == 'EnumConstantDecl' or
                n.get('kind') == 'VarDecl' and 'const' in n.get('type', {}).get('qualType', '') and
                '*' not in n.get('type', {}).get('qualType', '') for n in ancestors)
            if not constant_context and str(node.get('value')) not in ('0', '1'):
                stderr_descriptor = False
                for parent in reversed(ancestors):
                    if parent.get('kind') == 'CallExpr':
                        name = self.callee(parent)
                        args = parent.get('inner', [])[1:]
                        descriptor_index = {'write': 0, 'dprintf': 0, 'dup2': 1}.get(name)
                        if descriptor_index is not None and len(args) > descriptor_index:
                            stderr_descriptor = (school_unwrap(args[descriptor_index]) is node and
                                                 node.get('value') == '2')
                        break
                if not stderr_descriptor:
                    self.emit('5.1', 'replace literal {} with a named constant.'.format(node.get('value')), node)
        if kind == 'UnaryOperator' and node.get('opcode') == '-' and inner and school_integer(inner[0], self.constants) == 1:
            if not any(parent.get('kind') == 'EnumConstantDecl' for parent in ancestors):
                self.emit('5.1', 'confirm -1 is an error sentinel; otherwise use a named constant.', node, review=True)
        if kind == 'EnumConstantDecl':
            self.emit('5.2', 'verify this enum name describes its purpose rather than spelling a number.',
                      node, review=True)
        if kind == 'UnaryOperator' and node.get('opcode') == '*' and inner:
            base = school_unwrap(inner[0])
            if base.get('kind') == 'BinaryOperator' and base.get('opcode') == '+':
                self.emit('4.7.8', 'replace *(pointer + index) with pointer[index].', node)
        if kind == 'MemberExpr' and not node.get('isArrow') and inner:
            base = school_unwrap(inner[0])
            if base.get('kind') == 'UnaryOperator' and base.get('opcode') == '*':
                self.emit('4.7.8', 'replace (*pointer).member with pointer->member.', node)
        if kind == 'ParenExpr' and inner:
            child = school_unwrap(inner[0])
            parent = next((p for p in reversed(ancestors) if p.get('kind') != 'ImplicitCastExpr'), {})
            if parent.get('kind') != 'UnaryExprOrTypeTraitExpr':
                simple = child.get('kind') in ('DeclRefExpr', 'IntegerLiteral', 'FloatingLiteral',
                    'ArraySubscriptExpr', 'MemberExpr', 'CallExpr', 'ParenExpr')
                control = parent.get('kind') in ('IfStmt', 'WhileStmt', 'DoStmt', 'SwitchStmt')
                assignment = child.get('kind') == 'BinaryOperator' and child.get('opcode') in ('=', '+=', '-=')
                precedence = {',': 1, '=': 2, '||': 4, '&&': 5, '|': 6, '^': 7, '&': 8,
                              '==': 9, '!=': 9, '<': 10, '<=': 10, '>': 10, '>=': 10,
                              '<<': 11, '>>': 11, '+': 12, '-': 12, '*': 13, '/': 13, '%': 13}
                child_precedence = precedence.get(child.get('opcode'))
                parent_precedence = precedence.get(parent.get('opcode'))
                redundant_binary = (child_precedence is not None and parent_precedence is not None
                                    and child_precedence > parent_precedence)
                root_expression = parent.get('kind') == 'ReturnStmt' and not any(
                    ancestor.get('kind') == 'DecltypeType' for ancestor in ancestors)
                if (simple and parent.get('kind') != 'DecltypeType' or control and not assignment or
                        redundant_binary or root_expression):
                    self.emit('4.7.9', 'remove redundant parentheses around this expression.', node)
                elif assignment or child.get('kind') == 'CXXOperatorCallExpr':
                    self.emit('4.7.9', 'confirm this grouping is needed for an intentional assignment or overloaded operator.',
                              node, review=True)
        if kind == 'UnaryExprOrTypeTraitExpr' and node.get('name') == 'sizeof' and node.get('argType'):
            allocated = any(p.get('kind') == 'CallExpr' and self.callee(p) in SCHOOL_ALLOCATORS
                            for p in ancestors)
            self.emit('5.10', 'use sizeof(object) or sizeof(*pointer) when an object expression is available.',
                      node, review=not allocated)
        if kind == 'CStyleCastExpr' and not self.cpp:
            if any(n.get('kind') == 'CallExpr' and self.callee(n) in SCHOOL_ALLOCATORS
                   for n in school_nodes(node)):
                self.emit('5.18', 'remove the explicit cast of the allocation result.', node)

    def string_literal(self, node):
        node = school_unwrap(node)
        if node.get('kind') != 'StringLiteral':
            return None
        spelling = node.get('value', '')
        spelling = re.sub(r'^(?:u8|[uUL])(?=")', '', spelling)
        try:
            value = school_python_ast.literal_eval(spelling)
        except (ValueError, SyntaxError):
            return None
        return value.split('\0', 1)[0] if isinstance(value, str) else None

    def output_details(self, node):
        name = self.callee(node)
        args = node.get('inner', [])[1:]
        if name not in SCHOOL_OUTPUT_CALLS:
            return None
        if name in ('printf', 'vprintf', 'puts', 'putchar'):
            stream, index = 'stdout', 0
        elif name == 'perror':
            return 'stderr', True, False, None
        elif name in ('fprintf', 'vfprintf', 'dprintf'):
            stream, index = self.excerpt(args[0]) if args else '', 1
            if name == 'dprintf' and args:
                descriptor = school_integer(args[0], self.constants)
                stream = {1: 'stdout', 2: 'stderr'}.get(descriptor, stream)
        elif name in ('fputs', 'fputc', 'putc'):
            stream, index = self.excerpt(args[1]) if len(args) > 1 else '', 0
        else:
            stream, index = self.excerpt(args[0]) if args else '', 1
        if 'stderr' in stream:
            stream = 'stderr'
        elif 'stdout' in stream:
            stream = 'stdout'
        character = name in ('putchar', 'putc', 'fputc')
        value = self.string_literal(args[index]) if len(args) > index else None
        if name == 'puts':
            return stream, True, False, value
        if character:
            number = school_integer(args[index], self.constants) if len(args) > index else None
            return stream, True if number == 10 else None, True, None
        if value is None or name in ('vprintf', 'vfprintf', 'write'):
            return stream, None, False, value
        if not value:
            return stream, True, False, value
        if value.endswith('\n'):
            return stream, True, False, value
        if name in ('printf', 'fprintf', 'dprintf') and re.search(r'%(?:[-+ #0]*\d*(?:\.\d+)?[hljztL]*)?[sc]$', value):
            return stream, None, False, value
        return stream, False, False, value

    def output_completion(self, node, ancestors, details):
        stream, newline, character, _ = details
        if newline or character or newline is None:
            return newline
        if not ancestors or ancestors[-1].get('kind') != 'CompoundStmt':
            return None
        statements = ancestors[-1].get('inner', [])
        if node not in statements:
            return None
        following = statements[statements.index(node) + 1:]
        for statement in following:
            if statement.get('kind') == 'ReturnStmt':
                function = next((p for p in reversed(ancestors)
                                 if p.get('kind') == 'FunctionDecl'), {})
                return False if function.get('name') == 'main' else None
            if statement.get('kind') != 'CallExpr':
                return None
            other = self.output_details(statement)
            if other is None or other[0] != stream:
                return None
            if other[1]:
                return True
            if other[1] is None:
                return None
        return None

    def allocation_owner(self, node, ancestors):
        for parent in reversed(ancestors):
            if parent.get('kind') == 'VarDecl':
                return parent
            if parent.get('kind') == 'BinaryOperator' and parent.get('opcode') == '=':
                lhs = school_unwrap(parent.get('inner', [{}])[0])
                return self.symbols.get(lhs.get('referencedDecl', {}).get('id'), {})
        return {}

    def small_buffer(self, node, ancestors, owner):
        if not owner or '*' not in owner.get('type', {}).get('qualType', ''):
            return
        name = self.callee(node)
        args = node.get('inner', [])[1:]
        base_type = owner.get('type', {}).get('qualType', '').replace('const ', '').replace('*', '').strip()
        if base_type not in ('char', 'signed char', 'unsigned char'):
            self.emit('5.15', 'verify fixed local buffers at most 64 KiB use stack storage when their lifetime permits.',
                      node, review=True)
            return
        if name == 'calloc' and len(args) > 1:
            count = school_integer(args[0], self.constants)
            element = school_unwrap(args[1])
            bytes_known = element.get('kind') == 'UnaryExprOrTypeTraitExpr' and element.get('name') == 'sizeof'
        else:
            count, bytes_known = None, False
        if count is None or not bytes_known or not 0 < count <= 65536:
            self.emit('5.15', 'verify this allocation is variable-sized, larger than 64 KiB, or needs escaping lifetime.',
                      node, review=True)
            return
        function = next((p for p in ancestors if p.get('kind') == 'FunctionDecl'), {})
        identifier = owner.get('id')
        escaping = False
        safe_calls = {'free', 'memset', 'memcpy', 'memmove', 'strlen', 'strcmp', 'printf', 'fprintf', 'scanf', 'fscanf'}
        for use in school_nodes(function):
            references = [n for n in school_nodes(use) if n.get('kind') == 'DeclRefExpr'
                          and n.get('referencedDecl', {}).get('id') == identifier]
            if references and use.get('kind') == 'ReturnStmt':
                escaping = True
            if references and use.get('kind') == 'CallExpr' and use is not node and self.callee(use) not in safe_calls:
                escaping = True
        self.emit('5.15', 'replace this fixed small local char buffer with a stack array.',
                  node, review=escaping)

    def calls(self, node, ancestors):
        if node.get('kind') != 'CallExpr':
            return
        name = self.callee(node)
        args = node.get('inner', [])[1:]
        if name in SCHOOL_UNSAFE_CALLS:
            self.emit('5.8', 'replace unsafe {} with a bounded checked operation.'.format(name), node)
        if not name:
            self.emit('5.8', 'verify this indirect call cannot reach a prohibited unsafe function.', node, review=True)
        if name in ('scanf', 'fscanf', 'sscanf'):
            index = 0 if name == 'scanf' else 1
            fmt = school_unwrap(args[index]) if len(args) > index else {}
            if fmt.get('kind') != 'StringLiteral':
                self.emit('5.8', 'verify every string input conversion has a positive maximum width.', node, review=True)
            else:
                value = fmt.get('value', '').replace('%%', '')
                if re.search(r'%(?:\d+\$)?\*?0*(?:hh|ll|[hljztL])?s', value):
                    self.emit('5.8', 'add a positive width to every scanf %s conversion.', node)
        if name in SCHOOL_OUTPUT_CALLS:
            helper = next((p for p in reversed(ancestors)
                           if p.get('kind') in ('FunctionDecl', 'CXXMethodDecl')), {})
            if helper.get('name') != 'main':
                self.emit('5.13', 'confirm this helper is an output operation, not a general-purpose utility.',
                          node, review=helper.get('name') != 'getline')
            details = self.output_details(node)
            stream = details[0]
            if name != 'perror':
                self.emit('5.4', 'confirm results go to stdout and diagnostics go to stderr.', node, review=True)
            completion = self.output_completion(node, ancestors, details)
            if completion is not True:
                rules = ('5.5',) if stream == 'stderr' else ('5.6',) if stream == 'stdout' else ('5.5', '5.6')
                for rule in rules:
                    self.emit(rule, 'terminate complete messages/results with newline, or justify split/character-stream output.',
                              node, review=completion is None)
        if name == 'malloc':
            owner = self.allocation_owner(node, ancestors)
            owner_type = owner.get('type', {}).get('desugaredQualType', owner.get('type', {}).get('qualType', ''))
            record_name = re.sub(r'\b(?:struct|const)\b|[ *]', '', owner_type)
            record = next((item for item in school_nodes(self.tree)
                           if item.get('kind') in ('RecordDecl', 'CXXRecordDecl') and
                           item.get('name') == record_name and item.get('completeDefinition')), {})
            linked = any(field.get('kind') == 'FieldDecl' and '*' in field.get('type', {}).get('qualType', '') and
                         re.search(r'\b' + re.escape(record_name) + r'\b', field.get('type', {}).get('qualType', ''))
                         for field in record.get('inner', []))
            self.emit('5.9', 'use calloc for list/tree nodes; malloc is only allowed for a justified realloc-based array.',
                      node, review=not linked)
        if name in SCHOOL_ALLOCATORS:
            size_index = 1 if name in ('calloc', 'realloc') else 0
            size = school_unwrap(args[size_index]) if len(args) > size_index else {}
            size_nodes = list(school_nodes(size))
            has_sizeof = any(n.get('kind') == 'UnaryExprOrTypeTraitExpr' and n.get('name') == 'sizeof'
                             for n in size_nodes)
            product = size.get('kind') == 'BinaryOperator' and size.get('opcode') == '*'
            if not has_sizeof or name != 'calloc' and not product:
                self.emit('5.11', 'calculate bytes as count * sizeof(element), including char arrays.', node)
            else:
                self.emit('5.11', 'verify the count and sizeof expression describe the same allocated element type.',
                          node, review=True)
            if name in ('malloc', 'calloc'):
                owner = self.allocation_owner(node, ancestors)
                self.small_buffer(node, ancestors, owner)

    def source_rules(self):
        for number, line in enumerate(self.text.split('\n'), 1):
            if any(ord(c) < 32 and c != '\r' or ord(c) == 127 for c in line):
                self.emit('1.2' if '\t' in line else '1.1',
                          'replace control characters/tabs with spaces or escaped literal text.', line=number)
            if len(line.rstrip('\r')) > 100:
                self.emit('2.2', 'split the literal/comment to at most 100 characters.', line=number)
        for match in SCHOOL_LEXER.finditer(self.text):
            comment = match.group('comment')
            if comment and re.search(r'\bclang-format\s+off\b', comment):
                self.emit('2.1', 'remove clang-format off to validate school layout; use --clang for custom formatting.',
                          line=self.text[:match.start()].count('\n') + 1)
            if comment and 'school-reviewed' not in comment and re.search(
                    r'(?:\b(?:if|for|while|printf|return)\b.*[;{}]|\w+\s*=[^=].*;)', comment):
                self.emit('5.12', 'remove commented-out debugging code or explain why this is documentation.',
                          line=self.text[:match.start()].count('\n') + 1, review=True)
        for number, line in enumerate(self.code.splitlines(), 1):
            macro = re.match(r'\s*#\s*define\s+\w+\s+(.+)', line)
            integer_macro = macro and re.search(r'\b(?:0[xX][\da-fA-F]+|\d+)[uUlL]*\b', macro[1]) and not re.search(r'\d\.\d|\d[eEpP][+-]?\d', macro[1])
            if integer_macro:
                self.emit('5.2', 'replace integer #define with enum.', line=number)
            if re.match(r'\s*#\s*define\s+\w+\(', line):
                self.emit('4.5.1', 'review function-like macros separately; prefer a typed function.',
                          line=number, review=True)
        SchoolProjectAudit(self).run()

    def run(self):
        self.source_rules()

        def visit(node, ancestors=()):
            if self.local(node):
                self.declarations(node, ancestors)
                self.functions_and_records(node, ancestors)
                self.expressions(node, ancestors)
                self.calls(node, ancestors)
            for child in node.get('inner', []):
                visit(child, (*ancestors, node))
        visit(self.tree)
        return list(dict.fromkeys(self.findings))


def school_constant_expression(node):
    node = school_unwrap(node)
    kind = node.get('kind')
    if kind in ('IntegerLiteral', 'FloatingLiteral', 'CharacterLiteral', 'StringLiteral',
                'CXXBoolLiteralExpr', 'GNUNullExpr', 'CXXNullPtrLiteralExpr'):
        return True
    if kind == 'DeclRefExpr':
        return node.get('referencedDecl', {}).get('kind') == 'EnumConstantDecl'
    if kind == 'UnaryExprOrTypeTraitExpr':
        return not any(n.get('kind') == 'DeclRefExpr' and n.get('referencedDecl', {}).get('kind') != 'EnumConstantDecl'
                       for n in school_nodes(node))
    if kind in ('UnaryOperator', 'BinaryOperator', 'CStyleCastExpr', 'InitListExpr'):
        if node.get('opcode') in ('=', '+=', '-=', '++', '--', ','):
            return False
        return all(school_constant_expression(child) for child in node.get('inner', []))
    return False


def school_simple_initializer(node):
    children = node.get('inner', [])
    return not children or school_constant_expression(children[-1])


def school_guaranteed_return(node):
    kind, inner = node.get('kind'), node.get('inner', [])
    if kind in ('ReturnStmt', 'CXXThrowExpr'):
        return True
    if kind == 'CompoundStmt':
        return bool(inner) and school_guaranteed_return(inner[-1])
    if kind == 'IfStmt' and node.get('hasElse') and len(inner) >= 3:
        return school_guaranteed_return(inner[-1]) and school_guaranteed_return(inner[-2])
    return False


def school_parameter_layout(source, text, tree):
    """Apply PDF 4.5.3 after clang-format, using AST parameter ranges."""
    data = text.encode('utf-8')
    edits = []
    for function in school_nodes(tree):
        if function.get('kind') not in ('FunctionDecl', 'CXXMethodDecl'):
            continue
        body = next((n for n in function.get('inner', []) if n.get('kind') == 'CompoundStmt'), None)
        location = function.get('loc', {})
        if body is None or 'offset' not in location or 'includedFrom' in location:
            continue
        start = location['offset']
        end = body.get('range', {}).get('begin', {}).get('offset')
        if end is None:
            continue
        header = data[start:end].decode('utf-8')
        line_start = data.rfind(b'\n', 0, start) + 1
        prefix = data[line_start:start].decode('utf-8')
        indent = prefix[:len(prefix) - len(prefix.lstrip(' '))]
        logical = ' '.join((prefix + header).split())
        if len(indent) + len(logical) + 2 <= 70:
            continue
        params = [n for n in function.get('inner', []) if n.get('kind') == 'ParmVarDecl']
        name = function.get('name', '')
        parts = []
        for param in params:
            span = param.get('range', {})
            begin, finish = span.get('begin', {}), span.get('end', {})
            if 'offset' not in begin or 'offset' not in finish:
                break
            part = data[begin['offset']:finish['offset'] + finish.get('tokLen', 1)].decode('utf-8')
            # Preserve whitespace inside default string literals and comments.
            if '\n' in part or '\r' in part:
                break  # Keep layout intact; report unsupported parameter wrapping below.
            parts.append(part.strip())
        else:
            if function.get('variadic'):
                parts.append('...')
            if not parts:
                continue
            # Locate the matching closing parenthesis without touching attributes/body.
            parameters = school_definition_parameters(text, function)
            if not parameters:
                continue
            opening = school_tokens(text)[parameters[0]][1] - len(data[:start].decode('utf-8'))
            depth, closing = 0, None
            masked = school_mask(header)
            for index in range(opening, len(masked)):
                if masked[index] == '(':
                    depth += 1
                elif masked[index] == ')':
                    depth -= 1
                    if depth == 0:
                        closing = index
                        break
            if closing is None:
                continue
            suffix = header[closing + 1:].strip()
            replacement = (header[:opening] + '(\n' + ',\n'.join(
                indent + ' ' * 8 + part for part in parts) + ')'
                + (' ' + suffix if suffix else '') + '\n' + indent)
            edits.append((start, end, replacement.encode('utf-8')))
    for start, end, replacement in sorted(edits, reverse=True):
        data = data[:start] + replacement + data[end:]
    return data.decode('utf-8')


def school_label_layout(text, tree):
    data = text.encode('utf-8')
    edits = []

    def visit(node, compounds=()):
        if node.get('kind') == 'CompoundStmt':
            compounds = (*compounds, node)
        if node.get('kind') == 'LabelStmt' and node.get('inner') and compounds:
            child = node['inner'][0]
            start = node.get('range', {}).get('begin', {})
            following = child.get('range', {}).get('begin', {})
            if 'offset' in start and 'offset' in following and 'includedFrom' not in start:
                label_start, child_start = start['offset'], following['offset']
                if data[label_start:child_start].count(b'\n') == 0:
                    body_start = compounds[-1].get('range', {}).get('begin', {}).get('offset', 0)
                    line_start = data.rfind(b'\n', 0, body_start) + 1
                    prefix = data[line_start:body_start].decode('utf-8')
                    base = len(prefix) - len(prefix.lstrip(' '))
                    edits.append((child_start, b'\n' + b' ' * (base + 4)))
        for child in node.get('inner', []):
            visit(child, compounds)
    visit(tree)
    for position, insertion in sorted(set(edits), reverse=True):
        data = data[:position] + insertion + data[position:]
    return data.decode('utf-8')


def school_apply_layout(source, text, clang):
    tree, issues = school_parse(source, text, clang)
    if issues:
        return text, tree, issues
    candidate = school_parameter_layout(source, text, tree)
    if candidate != text:
        tree, issues = school_parse(source, candidate, clang)
        if issues:
            return candidate, tree, issues
    labeled = school_label_layout(candidate, tree)
    if labeled != candidate:
        tree, issues = school_parse(source, labeled, clang)
    return labeled, tree, issues


SCHOOL_ANALYZER_CAPABILITIES = {}


def school_analyzer_checkers(clang):
    """Resolve the same stream analysis under stable and older alpha names."""
    if clang in SCHOOL_ANALYZER_CAPABILITIES:
        return SCHOOL_ANALYZER_CAPABILITIES[clang]
    result = school_tool([clang, '-cc1', '-analyzer-checker-help'], capture_output=True, text=True)
    if result.returncode:
        raise CheckSetupError('school: cannot query Clang analyzer checkers: ' + result.stderr)
    available = set(re.findall(r'^\s+([A-Za-z_][\w.]+)\s', result.stdout, re.M))
    stream = 'unix.Stream'
    if stream not in available:
        alpha = school_tool([clang, '-cc1', '-analyzer-checker-help-alpha'], capture_output=True, text=True)
        if alpha.returncode:
            raise CheckSetupError('school: cannot query Clang stream analysis: ' + alpha.stderr)
        available.update(re.findall(r'^\s+([A-Za-z_][\w.]+)\s', alpha.stdout, re.M))
        stream = 'alpha.unix.Stream'
    required = ('unix.Malloc', stream, 'core.NullDereference', 'core.StackAddressEscape',
                'cplusplus.NewDelete', 'cplusplus.NewDeleteLeaks')
    missing = set(required) - available
    if missing:
        raise CheckSetupError('school: install a Clang analyzer providing: ' + ', '.join(sorted(missing)))
    SCHOOL_ANALYZER_CAPABILITIES[clang] = required
    return required


def school_resource_analysis(source, candidate_path, input_path, clang, include_args=()):
    language = 'c' if source.suffix in ('.c', '.h') else 'c++'
    standard = '-std=gnu99' if language == 'c' else '-std=gnu++17'
    checkers = school_analyzer_checkers(clang)
    with tempfile.TemporaryDirectory(prefix='school-analysis-') as directory:
        result = school_tool(
            [clang, '--analyze', '-x', language, standard,
             '-iquote', str(source.parent), *include_args,
             '-Xanalyzer', '-analyzer-checker=' + ','.join(checkers),
             '-Xanalyzer', '-analyzer-output=text',
             str(input_path), '-o', str(Path(directory) / 'analysis.plist')],
            text=True, capture_output=True)
    if result.returncode:
        raise CheckSetupError(str(source) + ': school analyzer failed:\n' + result.stderr)
    resource_warning = re.search(r'warning:.*\[(?:(?:alpha\.)?unix\.(?:Malloc|Stream)|core\.(?:NullDereference|StackAddressEscape)|cplusplus\.NewDelete(?:Leaks)?)\]', result.stderr)
    if resource_warning is None:
        return []
    diagnostic = result.stderr.replace(str(candidate_path), str(source))
    return [str(source) + ': school 5.17 error: fix the resource/control-flow diagnostic:\n' + diagnostic]
