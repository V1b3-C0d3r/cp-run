"""Read-only include ownership, header and Makefile auditing for school rules."""


def school_includes(text):
    visible = SCHOOL_LEXER.sub(
        lambda match: ''.join('\n' if c == '\n' else ' ' for c in match[0])
        if match.group('comment') else match[0], text)
    return list(re.finditer(r'^[^\S\r\n]*#[^\S\r\n]*include[^\S\r\n]*([<"])([^>"\n]+)[>"]', visible, re.M))


def school_declaration_key(node):
    kind = node.get('kind')
    if kind not in ('FunctionDecl', 'VarDecl', 'EnumConstantDecl', 'TypedefDecl',
                    'RecordDecl', 'CXXRecordDecl', 'EnumDecl'):
        return None
    name = node.get('name')
    if not name:
        return None
    signature = node.get('type', {}).get('qualType', '') if kind in ('FunctionDecl', 'VarDecl') else ''
    return kind, name, signature


class SchoolProjectAudit:
    def __init__(self, policy):
        self.policy = policy
        self.clang = shutil.which('clang')
        self.headers = {}
        self.direct = set()
        self.parents = {}
        self.macro_include = False

    def includes(self, owner, text):
        result = []
        for directive in school_includes(text):
            opener, name = directive[1], directive[2]
            line = text[:directive.start()].count('\n') + 1
            local = (owner.source.parent / name).resolve()
            if opener == '<':
                if name not in SCHOOL_STANDARD_HEADERS and local.is_file():
                    owner.emit('5.3', 'use quotes for the project header ' + name, line=line)
                continue
            if local.is_file():
                result.append(local)
            elif name in SCHOOL_STANDARD_HEADERS:
                owner.emit('5.3', 'use #include <{}> for this standard header.'.format(name), line=line)
            else:
                owner.emit('5.3', 'identify the owner of this installed header and verify the include delimiters.',
                           line=line, review=True)
        literal_lines = {text[:item.start()].count('\n') for item in school_includes(text)}
        for number, line in enumerate(school_mask(text).splitlines()):
            if re.match(r'\s*#\s*include\b', line) and number not in literal_lines:
                owner.emit('6.4', 'verify direct ownership for this macro-generated include.',
                           line=number + 1, review=True)
                if owner is self.policy:
                    self.macro_include = True
        return result

    def guard(self, policy):
        lines = [line.strip() for line in policy.code.splitlines() if line.strip()]
        pragma = any(re.fullmatch(r'#\s*pragma\s+once', line) for line in lines)
        guarded = False
        if len(lines) >= 3:
            first = re.fullmatch(r'#\s*ifndef\s+([A-Za-z_]\w*)', lines[0])
            if first and re.fullmatch(r'#\s*define\s+' + first[1], lines[1]):
                depth = 0
                guarded = True
                for index, line in enumerate(lines):
                    if re.match(r'#\s*(?:if|ifdef|ifndef)\b', line):
                        depth += 1
                    elif re.match(r'#\s*endif\b', line):
                        depth -= 1
                    if depth < 0 or depth == 0 and index != len(lines) - 1:
                        guarded = False
                guarded = guarded and depth == 0
        if not (pragma or guarded):
            policy.emit('6.2', 'protect the entire header with matching include guards or #pragma once.')
        for node in policy.functions:
            policy.emit('6.1', 'move C function bodies from the header to the implementation module.',
                        node, review=policy.cpp)

    def header(self, path):
        if path in self.headers:
            return
        if len(self.headers) >= 64:
            self.policy.emit('6.4', 'include graph exceeds 64 project headers; verify a smaller complete module context.',
                             review=True)
            return
        text = self.policy.text if path == self.policy.source else path.read_text(encoding='utf-8')
        tree, issues = school_parse(path, text, self.clang, cpp=self.policy.cpp)
        if issues:
            self.policy.findings.extend(issues)
            return
        context = self.policy if path == self.policy.source else SchoolPolicy(path, text, tree, cpp=self.policy.cpp)
        self.headers[path] = context
        self.guard(context)
        dependencies = self.includes(context, text)
        self.parents[path] = dependencies
        for dependency in dependencies:
            self.header(dependency)
        self.minimal_includes(context)
        if context is not self.policy:
            self.policy.findings.extend(context.findings)

    def own_nodes(self, context):
        return [node for node in school_nodes(context.tree) if context.local(node)]

    def public_symbols(self, context):
        return {school_declaration_key(node) for node in self.own_nodes(context)
                if school_declaration_key(node) is not None}

    def ownership(self):
        owners = {}
        for path, header in self.headers.items():
            for key in self.public_symbols(header):
                owners.setdefault(key, set()).add(path)
        for node in self.own_nodes(self.policy):
            if node.get('kind') != 'DeclRefExpr':
                continue
            reference = node.get('referencedDecl', {})
            declaration = self.policy.symbols.get(reference.get('id'), {})
            if self.policy.local(declaration):
                continue
            key = school_declaration_key(reference)
            candidates = owners.get(key, set())
            if len(candidates) == 1:
                owner = next(iter(candidates))
                if owner not in self.direct and owner != self.policy.source:
                    self.policy.emit('6.4', 'directly include "{}"; this entity currently arrives transitively.'.format(owner.name),
                                     node, review=self.macro_include)
            elif len(candidates) > 1:
                self.policy.emit('6.4', 'resolve the owning declaration header for ' + reference.get('name', ''),
                                 node, review=True)
        if any(self.public_symbols(context) for context in self.headers.values()):
            self.policy.emit('6.4', 'confirm all other project consumers include their owning headers directly.',
                             review=True)

    def minimal_includes(self, context):
        directives = school_includes(context.text)
        if not directives:
            return
        # Keep guards, but do not make a deletion claim through other preprocessor branches.
        conditionals = re.findall(r'^\s*#\s*(if|ifdef|ifndef|elif|else)\b', context.code, re.M)
        ordinary_guard_only = len(conditionals) <= 1 and (
            not conditionals or re.match(r'\s*#\s*ifndef\b', context.code))
        own = self.public_symbols(context)
        primitive = {'void', 'char', 'signed', 'unsigned', 'short', 'int', 'long',
                     'float', 'double', 'const', 'volatile', 'restrict', '_Bool'}
        simple_interface = all(
            node.get('kind') in ('FunctionDecl', 'ParmVarDecl') and
            set(re.findall(r'[A-Za-z_]\w*', node.get('type', {}).get('qualType', ''))) <= primitive
            for node in self.own_nodes(context)
            if node.get('kind', '').endswith('Decl') and not node.get('isImplicit'))
        for directive in directives:
            without = context.text[:directive.start()] + ''.join(
                '\n' if c == '\n' else ' ' for c in directive[0]) + context.text[directive.end():]
            tree, issues = school_parse(context.source, without, self.clang, cpp=context.cpp)
            if issues:
                continue  # The header demonstrably needs entities from this include.
            other = SchoolPolicy(context.source, without, tree, cpp=context.cpp)
            equal = self.public_symbols(other) == own
            if equal and simple_interface and ordinary_guard_only:
                context.emit('6.5', 'remove implementation-only include "{}" from this primitive declaration interface.'.format(directive[2]),
                             line=context.text[:directive.start()].count('\n') + 1)
            else:
                context.emit('6.5', 'justify include "{}" for the entities declared by this header.'.format(directive[2]),
                             line=context.text[:directive.start()].count('\n') + 1, review=True)

    def module(self):
        policy = self.policy
        if policy.source.suffix != '.c':
            return
        header = policy.source.with_suffix('.h')
        if not header.is_file():
            if not policy.has_main:
                policy.emit('6.1', 'supply a sibling .h with this module\'s types, constants and prototypes.')
        else:
            if header.resolve() not in self.direct:
                policy.emit('6.3', 'directly include your own module header "{}".'.format(header.name))
            context = self.headers.get(header.resolve())
            if context and not policy.has_main:
                declared = self.public_symbols(context)
                for function in policy.functions:
                    if function.get('storageClass') != 'static' and school_declaration_key(function) not in declared:
                        policy.emit('6.1', 'declare this public function in ' + header.name, function)
        if not policy.has_main or self.direct:
            self.makefile()

    def makefile(self):
        policy = self.policy
        candidates = [policy.source.parent / 'Makefile', policy.source.parent / 'makefile']
        makefile = next((path for path in candidates if path.is_file()), None)
        if makefile is None:
            policy.emit('6.6', 'supply Makefile with all and clean targets.')
            return
        targets, variables = set(), {}
        unresolved = False
        for raw in makefile.read_text().splitlines():
            if not raw or raw[0].isspace() or raw.lstrip().startswith('#'):
                continue
            line = raw.split('#', 1)[0]
            assignment = re.fullmatch(r'([A-Za-z_]\w*)\s*(?::=|=)\s*([A-Za-z0-9_ .-]*)', line)
            if assignment:
                variables[assignment[1]] = assignment[2]
                continue
            if re.match(r'(?:-?include|ifn?def|ifn?eq)\b', line):
                unresolved = True
            target = re.match(r'([^:=]+):(?!=)', line)
            if target:
                value = target[1]
                for name, replacement in variables.items():
                    value = value.replace('$(' + name + ')', replacement).replace('${' + name + '}', replacement)
                if '$' in value:
                    unresolved = True
                else:
                    targets.update(value.split())
        if not {'all', 'clean'} <= targets and not unresolved:
            policy.emit('6.6', 'define both all and clean targets in ' + str(makefile))
        else:
            policy.emit('6.6', 'verify all builds every module and clean removes generated objects/executables only.',
                        review=True)

    def run(self):
        if not self.clang:
            raise CheckSetupError('school project audit requires clang')
        if self.policy.source.suffix in ('.h', '.hpp'):
            self.header(self.policy.source)
            self.direct = set(self.parents.get(self.policy.source, []))
        else:
            self.direct = set(self.includes(self.policy, self.policy.text))
            for path in self.direct:
                self.header(path)
        self.ownership()
        self.module()
