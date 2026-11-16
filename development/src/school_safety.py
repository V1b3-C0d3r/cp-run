"""Validate automatic school edits without executing the submitted program."""
import bisect as school_bisect


def school_tokens(text):
    """Return spellings and character offsets, preserving literal contents."""
    result = []
    position = 0

    def plain(start, end):
        pattern = (r"(?:\d|\.\d)(?:[\w.']|(?<=[eEpP])[+-])*|[^\W\d]\w*|"
                   r"%:%:|>>=|<<=|\.\.\.|<=>|->\*|\.\*|::|\+\+|--|<<|>>|<=|>=|==|!=|"
                   r"&&|\|\||\*=|/=|%=|\+=|-=|&=|\^=|\|=|->|##|<:|:>|<%|%>|%:|\S")
        for token in re.finditer(pattern, text[start:end]):
            offset = start + token.start()
            if token[0] == '\\' and text[offset + 1:offset + 2] in ('\r', '\n'):
                continue
            result.append((token[0], offset))

    for literal in SCHOOL_LEXER.finditer(text):
        plain(position, literal.start())
        if not literal.group('comment'):
            spelling = re.sub(r'\\(?:\r\n|\r|\n)', '', literal[0])
            result.append((spelling, literal.start()))
        position = literal.end()
    plain(position, len(text))
    return result


def school_definitions(tree):
    for node in school_nodes(tree):
        if node.get('kind') in ('FunctionDecl', 'CXXMethodDecl', 'CXXConversionDecl'):
            location = node.get('loc', {})
            if ('offset' in location and 'includedFrom' not in location and
                    any(child.get('kind') == 'CompoundStmt' for child in node.get('inner', []))):
                yield node


def school_definition_parameters(text, node, tokens=None):
    tokens = school_tokens(text) if tokens is None else tokens
    location = node.get('loc', {})
    if 'offset' not in location or 'includedFrom' in location:
        return None
    offset = len(text.encode('utf-8')[:location['offset']].decode('utf-8'))
    starts = [position for _, position in tokens]
    index = school_bisect.bisect_left(starts, offset)
    name = [value for value, _ in school_tokens(node.get('name', ''))]
    if [value for value, _ in tokens[index:index + len(name)]] != name:
        return None
    index += len(name)
    if index >= len(tokens) or tokens[index][0] != '(':
        return None
    opening, depth = index, 0
    for closing in range(opening, len(tokens)):
        value = tokens[closing][0]
        if value == '(':
            depth += 1
        elif value == ')':
            depth -= 1
            if depth == 0:
                return opening, closing
    return None


def school_directive_spans(text):
    masked = school_mask(text)
    original_lines = text.splitlines(keepends=True)
    masked_lines = masked.splitlines(keepends=True)
    result = []
    offset, beginning = 0, None
    for original, visible in zip(original_lines, masked_lines):
        if beginning is None and visible.lstrip(' \t').startswith('#'):
            beginning = offset
        offset += len(original)
        if beginning is not None and not original.rstrip('\r\n').endswith('\\'):
            result.append((beginning, offset))
            beginning = None
    if beginning is not None:
        result.append((beginning, len(text)))
    return result


def school_control_bodies(node):
    children = node.get('inner', [])
    kind = node.get('kind')
    if kind == 'IfStmt':
        return children[-2:] if node.get('hasElse') else children[-1:]
    if kind in ('WhileStmt', 'ForStmt', 'CXXForRangeStmt'):
        return children[-1:]
    if kind == 'DoStmt':
        return children[:1]
    return []


def school_empty_body_positions(text, tree):
    positions = set()
    data = text.encode('utf-8')
    for node in school_nodes(tree):
        for body in school_control_bodies(node):
            location = body.get('range', {}).get('begin', {})
            if body.get('kind') == 'NullStmt' and 'offset' in location and 'includedFrom' not in location:
                position = location['offset']
                if data[position:position + 1] == b';':
                    positions.add(len(data[:position].decode('utf-8')))
    return positions


def school_spelling_signature(text, skip_void=(), skip_empty=()):
    directives = school_directive_spans(text)
    result = []
    for spelling, offset in school_tokens(text):
        if offset in skip_void and spelling == 'void':
            continue
        if offset in skip_empty and spelling == ';':
            continue
        if spelling in ('{', '}') and not any(start <= offset < end for start, end in directives):
            continue
        if re.fullmatch(r"[^\w\s\"']+", spelling):
            result.extend(spelling)
        else:
            result.append(spelling)
    return result


def school_inserted_void_positions(original, original_tree, candidate, candidate_tree):
    original_tokens, candidate_tokens = school_tokens(original), school_tokens(candidate)
    old_definitions = list(school_definitions(original_tree))
    new_definitions = list(school_definitions(candidate_tree))
    if len(old_definitions) != len(new_definitions):
        return set(), set()
    positions, names = set(), set()
    for old, new in zip(old_definitions, new_definitions):
        old_parameters = school_definition_parameters(original, old, original_tokens)
        new_parameters = school_definition_parameters(candidate, new, candidate_tokens)
        if old.get('name') != new.get('name') or not old_parameters or not new_parameters:
            continue
        old_start, old_end = old_parameters
        new_start, new_end = new_parameters
        if old_end == old_start + 1 and new_end == new_start + 2:
            spelling, position = candidate_tokens[new_start + 1]
            if spelling == 'void':
                positions.add(position)
                names.add(old.get('name'))
    return positions, names


def school_ast_signature(text, tree, void_names=()):
    data = text.encode('utf-8')

    def local(node):
        location = school_location(node)
        return ('offset' in location and 'includedFrom' not in location and
                location.get('file', '<stdin>') == '<stdin>' and
                0 <= location['offset'] < len(data) and not node.get('isImplicit'))

    declarations, labels = {}, {}
    for node in school_nodes(tree):
        if local(node) and node.get('kind', '').endswith('Decl') and 'id' in node:
            declarations.setdefault(node['id'], len(declarations))
        if local(node) and node.get('kind') == 'LabelStmt':
            labels.setdefault(node.get('declId'), len(labels))

    properties = ('name', 'opcode', 'value', 'isPostfix', 'isArrow', 'castKind',
                  'storageClass', 'tagUsed', 'variadic', 'hasElse', 'init', 'valueCategory')
    wrappers = {'ImplicitCastExpr', 'ParenExpr', 'ConstantExpr', 'ExprWithCleanups',
                'MaterializeTemporaryExpr'}
    controls = {'IfStmt', 'ForStmt', 'WhileStmt', 'DoStmt', 'CXXForRangeStmt'}

    def signature(node, parent=''):
        kind = node.get('kind')
        if kind in wrappers and len(node.get('inner', [])) == 1:
            return signature(node['inner'][0], parent)
        children = tuple(value for child in node.get('inner', [])
                         if (value := signature(child, kind)) is not None)
        if not local(node):
            return ('source-context', children) if children else None
        if kind == 'CompoundStmt' and parent in controls:
            if len(children) == 1:
                return children[0]
            if not children:
                return ('NullStmt', (), ())
        values = [(key, str(node[key])) for key in properties if key in node]
        typ = node.get('type', {}).get('qualType')
        reference = node.get('referencedDecl', {})
        name = node.get('name') or reference.get('name')
        if typ:
            if name in void_names and (kind in ('FunctionDecl', 'CXXMethodDecl', 'CXXConversionDecl')
                                       or reference.get('kind') == 'FunctionDecl'):
                typ = typ.replace('()', '(void)', 1)
            values.append(('type', typ))
        if reference:
            target = declarations.get(reference.get('id'))
            values.append(('reference', target if target is not None else
                           (reference.get('kind'), reference.get('name'),
                            reference.get('type', {}).get('qualType'))))
        if kind == 'GotoStmt':
            values.append(('target', labels.get(node.get('targetLabelDeclId'))))
        # Formatting naturally updates __LINE__ values. Preserve its invocation
        # spelling and require an explicit policy review of location-sensitive code.
        begin = node.get('range', {}).get('begin', {})
        spelling = begin.get('spellingLoc', {})
        expansion = begin.get('expansionLoc', {})
        if kind == 'IntegerLiteral' and spelling.get('file') == '<scratch space>' and 'offset' in expansion:
            line = expansion.get('presumedLine', data[:expansion['offset']].count(b'\n') + 1)
            if str(node.get('value')) == str(line):
                values = [(key, '<source-line>' if key == 'value' else value) for key, value in values]
        return kind, tuple(values), children
    return signature(tree)


def school_verify_layout(source, original, original_tree, candidate, candidate_tree):
    positions, names = school_inserted_void_positions(original, original_tree, candidate, candidate_tree)
    before = school_spelling_signature(original, skip_empty=school_empty_body_positions(original, original_tree))
    after = school_spelling_signature(candidate, positions, school_empty_body_positions(candidate, candidate_tree))
    if before != after:
        raise CheckSetupError(str(source) + ': school: formatter changed non-layout tokens; rewrite the affected macro/literal explicitly, then retry.')
    if school_ast_signature(original, original_tree, names) != school_ast_signature(candidate, candidate_tree, names):
        raise CheckSetupError(str(source) + ': school: formatting changed the parsed program; rewrite the affected construct explicitly, then retry.')


def school_compact_diagnostics(findings):
    """Keep automatic errors intact; show a concise file/rule review list."""
    output, reviews = [], {}
    pattern = re.compile(r'^(.*):(\d+):(\d+): school ([0-9.]+) review required: (.*)$', re.S)
    for finding in findings:
        match = pattern.match(finding)
        if not match:
            output.append(finding)
            continue
        key = (match[1], match[4])
        reviews.setdefault(key, []).append(finding)
    for items in reviews.values():
        output.extend(items[:2])
        if len(items) > 2:
            output.append('  ... {} further locations under the same whole-file review obligation'.format(len(items) - 2))
    return output
