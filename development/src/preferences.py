"""Validated data-only preferences transfer; no runtime config lookup."""


def validate_preferences(values):
    """Validate a complete or older-schema settings record without a compiler."""
    if not isinstance(values, dict) or set(values) - set(FACTORY_SETTINGS):
        raise ValueError('unknown settings keys or invalid settings object')
    data = copy.deepcopy(FACTORY_SETTINGS)
    data.update(copy.deepcopy(values))
    for key, factory in FACTORY_SETTINGS.items():
        value = data[key]
        if type(value) is not type(factory):
            raise ValueError('invalid type for ' + key)
        strings = list(value.values()) if isinstance(value, dict) else value if isinstance(value, list) else [value]
        if isinstance(value, dict) and any(not isinstance(k, str) for k in value):
            raise ValueError('invalid profile key in ' + key)
        if any(not isinstance(v, str) or any(c in v for c in '\x00\r\n') for v in strings):
            raise ValueError('invalid text in ' + key + '; use visible \\n escapes')
    data['DEFAULT_COMPILER'] = _settings_compiler(data['DEFAULT_COMPILER'])
    _settings_standard(data['DEFAULT_STANDARD'])
    _settings_choice('c++', 'c', 'python', 'auto')(data['DEFAULT_LANGUAGE'])
    if set(data['LANGUAGE_COMPILERS']) - {'c', 'c++'}:
        raise ValueError('compiler overrides support c and c++ only; use DEFAULT_INTERPRETER for Python')
    data['LANGUAGE_COMPILERS'] = {key: _settings_compiler(value) for key, value in data['LANGUAGE_COMPILERS'].items()}
    if data['C_STANDARD'] != 'auto' and not re.fullmatch(r'(?:[0-9]+|(?:gnu|c)[0-9][A-Za-z0-9]*|iso9899:[0-9]+)', data['C_STANDARD']): raise ValueError('invalid C standard')
    for key in ('DEFAULT_INPUT_TEMPLATE', 'DEFAULT_ANSWER_TEMPLATE'): case_template(data[key], 'main', 1)
    _settings_filename(data['DEFAULT_SOURCE'])
    for key in ('DEFAULT_BRUTE', 'DEFAULT_GENERATOR'):
        _settings_filename(data[key])
    for key in ('DEFAULT_TIMEOUT', 'DEFAULT_MEMORY_LIMIT', 'CHECK_TIMEOUT', 'CHECK_MEMORY_LIMIT'):
        data[key] = _settings_positive(data[key], True)
    for key in ('DEFAULT_LINE_LIMIT', 'DEFAULT_ITERATIONS', 'MAX_LINE_BYTES', 'MAX_CHECK_BYTES',
                'MAX_REPORT_BYTES', 'MAX_REPORT_LINES', 'MAX_SPOOL_BYTES'):
        data[key] = _settings_positive(data[key])
    _settings_seed(data['DEFAULT_SEED'])
    _settings_separator(data['DEFAULT_SEPARATOR'])
    _settings_macro(data['DEFAULT_MACRO'])
    _settings_choice('macro', 'auto', 'in', 'out')(data['DEFAULT_F_MODE'])
    _settings_choice('0', '1')(data['DEFAULT_WARMUP'])
    for key in ('TIME_KILL_FACTOR', 'MEMORY_KILL_FACTOR'):
        _factor(data[key])
    data['DEFAULT_AVERAGE'] = str(repetition_count(data['DEFAULT_AVERAGE']))
    _settings_choice('s', 'ms')(data['DEFAULT_TIME_UNIT'])
    _settings_choice('B', 'KB', 'KiB', 'MB', 'MiB')(data['DEFAULT_MEMORY_UNIT'])
    for key in ('DEFAULT_DESTINATION', 'DEFAULT_RELPATH_DESTINATION'):
        if not data[key]: raise ValueError('empty destination')
        _settings_destination(data[key])
    for key in ('DEFAULT_WORKSPACE', 'DEFAULT_INPUT', 'DEFAULT_OUTPUT', 'DEFAULT_ANSWER', 'DEFAULT_REPORT'):
        if not data[key]: raise ValueError('empty setting: ' + key)
    # Optional map entries inherit; an explicit zero remains a real override.
    actions = {'ordinary', 'compile', 'debug', 'run', 'test', 'test-auto', 'test-mult', 'stress', 'companion'}
    for key in ('ACTION_DEST_DIR', 'ACTION_SAVE_RELPATH', 'ACTION_SAVE_TEST_RELPATH'):
        if set(data[key]) - actions: raise ValueError('unknown action in ' + key)
    for key in ('MODE_DEST_DIR', 'MODE_SAVE_RELPATH', 'MODE_SAVE_TEST_RELPATH'):
        data[key] = {name: value for name, value in data[key].items() if value != ''}
    for key in ('ACTION_DEST_DIR', 'MODE_DEST_DIR'):
        for value in data[key].values():
            if not value: raise ValueError('empty destination override')
            _settings_destination(value)
    for key in ('ACTION_SAVE_RELPATH', 'ACTION_SAVE_TEST_RELPATH', 'MODE_SAVE_RELPATH', 'MODE_SAVE_TEST_RELPATH'):
        for value in data[key].values(): _settings_choice('0', '1')(value)
    for key in ('DEFAULT_TEST_DIR',):
        if data[key]: _settings_destination(data[key])
    for key in ('C_SOURCE', 'PYTHON_SOURCE'): _settings_filename(data[key])
    _settings_separator(data['MANUAL_SEPARATOR'])
    _settings_choice('all', 'failed')(data['DEFAULT_REPORT_TESTS'])
    for key in ('COMPANION_PORT', 'COMPANION_WAIT', 'MINIMIZE_ATTEMPTS', 'MINIMIZE_SECONDS', 'MAX_FAILURES'):
        _settings_positive(data[key])
    if int(data['COMPANION_PORT']) > 65535: raise ValueError('port must be 1..65535')
    if not data['DEFAULT_INTERPRETER']: raise ValueError('empty interpreter')
    flag_units(data['PYTHON_FLAGS'], python=True)
    names = data['MODE_NAMES']
    for key in PROFILE_KEYS:
        if key not in values: data[key] = {name: value for name, value in data[key].items() if name in names}
    if len(set(names)) != len(names): raise ValueError('duplicate profile name')
    reserved = {'companion', 'compile', 'run', 'test', 'stress', 'tr', 'sr', 'none', 'plain'}
    for name in names:
        if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,31}', name) or name in reserved:
            raise ValueError('invalid profile name: ' + name)
        if data['MODE_KIND'].get(name) not in ('debug', 'flags'):
            raise ValueError('invalid profile kind: ' + name)
        if data['MODE_CPU'].get(name, 'default') not in ('default', 'native'):
            raise ValueError('invalid profile CPU policy: ' + name)
    for key in PROFILE_KEYS:
        if set(data[key]) - set(names): raise ValueError('unknown profile in ' + key)
    # Validate the shell-word grammar while preserving the original spelling.
    for key in ('DEFAULT_FLAGS', 'WARNINGS_GCC', 'WARNINGS_CLANG'):
        flag_units(data[key])
    for key in SETTINGS_GROUPS.values():
        for text in data[key].values(): shlex.split(text)
    return data


def export_preferences(path, data, script_path):
    """Write an atomic portable export; never overwrite the installed script."""
    destination = Path(path)
    if destination.resolve() == Path(script_path).resolve():
        raise ValueError('settings export must not overwrite the script')
    data = validate_preferences(data)
    record = {'format': 'cp-run-settings', 'schema': 2, 'settings': data}
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=destination.parent,
                                         prefix='.cp-run-settings-', delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(record, stream, indent=2, ensure_ascii=True)
            stream.write('\n'); stream.flush(); os.fsync(stream.fileno())
        os.replace(temporary, destination)
    finally:
        if temporary is not None: temporary.unlink(missing_ok=True)


def load_preferences(path):
    """Reject oversized/ambiguous JSON before it can alter native preferences."""
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result: raise ValueError('duplicate settings key: ' + key)
            result[key] = value
        return result
    with open(path, 'rb') as stream: raw = stream.read(4 * 1024 * 1024 + 1)
    if len(raw) > 4 * 1024 * 1024: raise ValueError('settings export exceeds 4 MiB')
    try:
        record = json.loads(raw, object_pairs_hook=unique)
    except RecursionError:
        raise ValueError('settings export is too deeply nested') from None
    if (not isinstance(record, dict) or set(record) != {'format', 'schema', 'settings'}
            or record['format'] != 'cp-run-settings' or type(record['schema']) is not int
            or record['schema'] not in (1, 2)):
        raise ValueError('unsupported settings export format/schema')
    return validate_preferences(record['settings'])


def transfer_preferences(action, script, path):
    filename = Path(script).resolve()
    original = filename.read_text()
    if action == 'export':
        export_preferences(path, read_settings(original), script)
    else:
        save_settings(filename, original, load_preferences(path))
    print('cp-run: settings {}: {}'.format('exported' if action == 'export' else 'imported', path), file=sys.stderr)
    return 0


def remember_launch(config):
    """Commit only the main candidate after spawn; repeats do not rewrite history."""
    path = config.get('history_binary')
    if not path or config.get('_remembered'): return
    config['_remembered'] = True
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=Path(path).parent, prefix='.launch-', delete=False) as stream:
            temporary = Path(stream.name)
            fields = [config['executable']]
            if config['executable'].endswith('.py'):
                fields.extend(['CP_RUN_ARGV_V1', *config.get('main_argv', [config['executable']])])
            stream.write(b''.join(os.fsencode(value) + b'\0' for value in fields))
        os.replace(temporary, path)
    except OSError as error:
        print('cp-run: warning: launch history not saved: ' + str(error), file=sys.stderr)
    finally:
        if temporary is not None:
            try: temporary.unlink(missing_ok=True)
            except OSError: pass  # History failure must not abort a spawned program.
