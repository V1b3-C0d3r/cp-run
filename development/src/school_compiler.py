"""Structured GNU diagnostics preserve the syntax gate without duplicate builds."""
from urllib.parse import unquote as school_unquote, urlsplit as school_urlsplit


def school_gcc_diagnostic_option(banner):
    version = re.search(r'\b(\d+)\.\d+(?:\.\d+)?\b', banner)
    if version is None or int(version[1]) < 9:
        return None
    # GCC 16 removed its old JSON format; SARIF keeps the warning rule identity.
    return '-fdiagnostics-format=' + ('sarif-stderr' if int(version[1]) >= 16 else 'json')


def school_gcc_diagnostics(text):
    """Return (only promoted warnings, human text), or None for unknown output."""
    try:
        record = json.loads(text)
        messages = []
        if isinstance(record, list):
            def visit(item):
                kind, message = item['kind'], item['message']
                if kind not in ('error', 'fatal error', 'warning', 'note', 'sorry, unimplemented') or not isinstance(message, str):
                    raise ValueError('unsupported GNU diagnostic')
                locations = item.get('locations', [])
                caret = locations[0].get('caret', {}) if locations else {}
                messages.append((kind, item.get('option', ''), message, caret.get('file', ''),
                                 caret.get('line', 1), caret.get('display-column', caret.get('column', 1))))
                for child in item.get('children', []):
                    visit(child)
            for item in record:
                visit(item)
        elif isinstance(record, dict) and record.get('version') == '2.1.0' and isinstance(record.get('runs'), list):
            for run in record['runs']:
                # Tool crashes/incomplete results must retain the conservative gate.
                for invocation in run.get('invocations', []):
                    arguments = invocation.get('arguments', [])
                    if (invocation.get('toolExecutionNotifications') or '-Wfatal-errors' in arguments
                            or any(arg.startswith('-fmax-errors=') and arg != '-fmax-errors=0' for arg in arguments)):
                        return None
                for item in run.get('results', []):
                    kind, rule = item.get('level'), item.get('ruleId', '')
                    if kind not in ('error', 'warning', 'note'):
                        return None
                    location = next(iter(item.get('locations', [])), {}).get('physicalLocation', {})
                    uri = location.get('artifactLocation', {}).get('uri', '')
                    filename = school_unquote(school_urlsplit(uri).path) if uri.startswith('file:') else school_unquote(uri)
                    region = location.get('region', {})
                    message = item['message']['text']
                    if not isinstance(message, str):
                        return None
                    messages.append((kind, rule, message, filename, region.get('startLine', 1),
                                     region.get('startColumn', 1)))
                    for related in item.get('relatedLocations', []):
                        detail = related.get('message', {}).get('text', '')
                        if detail:
                            messages.append(('note', '', detail, '', 1, 1))
        else:
            return None
        errors = [item for item in messages if item[0] in ('error', 'fatal error', 'sorry, unimplemented')]
        only_warnings = bool(errors) and all(isinstance(item[1], str) and item[1].startswith('-Werror=') for item in errors)
        lines = []
        for kind, option, message, filename, line, column in messages:
            if not isinstance(filename, str) or type(line) is not int or type(column) is not int:
                return None
            prefix = '{}:{}:{}: '.format(filename, line, column) if filename else ''
            suffix = ' [' + option + ']' if isinstance(option, str) and option.startswith('-W') else ''
            lines.append(prefix + kind + ': ' + message + suffix)
        return only_warnings, '\n'.join(lines)
    except (ValueError, KeyError, TypeError, AttributeError, IndexError):
        return None


def school_gcc_check(argv, flags, output, dependency, banner):
    """Run every canonical flag; skip syntax-only only with positive warning evidence."""
    options = ['-c', '-MD', '-MF', str(dependency), '-MT', 'cp_source', '-o', str(output)]
    diagnostic = school_gcc_diagnostic_option(banner)
    checked = school_tool([*argv, *flags, *([diagnostic] if diagnostic else []), *options],
                          capture_output=True, text=True)
    structured = school_gcc_diagnostics(checked.stderr) if diagnostic else None
    if diagnostic and structured is None:
        # Older/custom compiler wrappers may not implement the advertised format.
        checked = school_tool([*argv, *flags, *options], capture_output=True, text=True)
    elif structured is not None:
        only_warnings, rendered = structured
        checked.stderr = rendered
        if checked.returncode == 1 and only_warnings:
            return checked, True
    return checked, False
