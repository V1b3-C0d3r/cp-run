"""Interactive preferences editor; serialization lives in settings_schema.py."""

def flag_key(flag):
    """Recognize value families while leaving independent warnings separate."""
    if re.fullmatch(r'-O(?:\d+|g|s|z|fast)?', flag):
        return '-O'
    if re.fullmatch(r'-g(?:\d+)?|-ggdb(?:\d+)?', flag):
        return '-g'
    if flag.startswith(('-D', '-U')):
        return 'macro:' + flag[2:].split('=', 1)[0]
    key = flag.split('=', 1)[0]
    if key in ('--std', '-std'):
        return '-std'
    if key.startswith('-Wno-'):
        return '-W' + key[5:]
    if key.startswith('-fno-'):
        return '-f' + key[5:]
    return key


def flag_units(words, python=False):
    """Keep known option/operand pairs intact during toggle operations."""
    paired = {'-I', '-L', '-l', '-D', '-U', '-isystem', '-iquote', '-include',
              '-imacros', '-isysroot', '--sysroot', '-target', '--target',
              '-arch', '-B', '-X', '-W', '--jit', '-Xlinker', '-Xclang', '-Xpreprocessor', '-mllvm'}
    if python:
        # -B and -I are standalone Python switches, but native driver options
        # with operands. Share the editor without sharing the wrong grammar.
        paired = {'-X', '-W', '--jit', '--check-hash-based-pycs'}
    units, index = [], 0
    while index < len(words):
        word = words[index]
        if not word.startswith('-') or word == '-':
            raise ValueError('expected a compiler flag, got {!r}'.format(word))
        unit = [word]
        if word in paired:
            index += 1
            if index == len(words):
                raise ValueError('missing operand for ' + word)
            unit.append(words[index])
        units.append(unit)
        index += 1
    return units


def _settings_unit_key(unit, python=False):
    if python and len(unit) == 1:
        return flag_key(unit[0])
    if unit[0] in ('-X', '-W', '--jit'):
        return unit[0] + ':' + unit[1].split('=', 1)[0]
    if unit[0] in ('-D', '-U'):
        return flag_key(unit[0] + unit[1])
    # Multiple include/link paths are independent, rather than replacing every
    # previous -I when a user adds a second directory.
    repeatable = ('-I', '-L', '-l', '-isystem', '-iquote', '-include', '-imacros', '-B')
    if unit[0] in repeatable:
        return unit[0] + ':' + unit[1]
    for prefix in ('-I', '-L', '-l', '-B'):
        if unit[0].startswith(prefix) and len(unit[0]) > len(prefix):
            return prefix + ':' + unit[0][len(prefix):]
    return flag_key(unit[0])


def _settings_change_flags(current, command, python=False):
    """Return a new list; a malformed edit cannot partially change settings."""
    action = 'toggle'
    for prefix in ('add ', 'remove '):
        if command.startswith(prefix):
            action, command = prefix.strip(), command[len(prefix):]
            break
    units = flag_units(current, python)
    for unit in flag_units(shlex.split(command), python):
        key = _settings_unit_key(unit, python)
        matches = [item for item in units if _settings_unit_key(item, python) == key]
        units = [item for item in units if _settings_unit_key(item, python) != key]
        if action != 'remove' and (action == 'add' or matches != [unit]):
            units.append(unit)
    return [word for unit in units for word in unit]


class _SettingsSave(Exception):
    pass


class _SettingsCancel(Exception):
    pass


class SettingsEditor:
    """One session owns pending data, undo history and the current reset scope."""

    def __init__(self, data):
        self.data = copy.deepcopy(data)
        self.history = []
        self.reset_action = lambda: self.replace(copy.deepcopy(FACTORY_SETTINGS))

    def replace(self, updated):
        if updated != self.data:
            self.history.append(copy.deepcopy(self.data))
            self.data.clear()
            self.data.update(updated)

    def set(self, key, value):
        updated = copy.deepcopy(self.data)
        updated[key] = value
        self.replace(updated)

    @contextmanager
    def scope(self, keys, profile=None):
        previous = self.reset_action

        def reset():
            updated = copy.deepcopy(self.data)
            for key in keys:
                if profile is None:
                    updated[key] = copy.deepcopy(FACTORY_SETTINGS[key])
                else:
                    fallback = PROFILE_DEFAULTS.get(key, '')
                    updated[key][profile] = FACTORY_SETTINGS[key].get(profile, fallback)
            self.replace(updated)

        self.reset_action = reset
        try:
            yield
        finally:
            self.reset_action = previous

    def ask(self, prompt):
        answer = input(prompt).strip()
        if any(c in answer for c in '\r\n\x00'):
            raise ValueError('enter one line; use visible \\n for a newline')
        if answer == 'save':
            raise _SettingsSave
        if answer in ('cancel', 'quit'):
            raise _SettingsCancel
        if answer == 'undo':
            if self.history:
                previous = self.history.pop()
                self.data.clear()
                self.data.update(previous)
                print('Undid the last edit.')
            else:
                print('Nothing to undo.')
            return None
        if answer == 'reset':
            self.reset_action()
            print('Restored factory values for this menu; not saved yet.')
            return None
        if answer == 'help':
            print('Choose a number or name. Enter keeps a value. back keeps pending edits.\n'
                  'undo reverses one edit; reset restores this menu; save reviews/writes; cancel discards.\n'
                  'Flags toggle: identical removes, another value replaces, new adds.\n'
                  'Use add FLAGS or remove FLAGS for an explicit operation. Quotes are data, never executed.')
            return None
        return answer


def _settings_scalar(editor, key, label, validator=None):
    value = editor.ask('{} [{}; Enter keeps it]: '.format(label, editor.data[key]))
    if value is None or value == '':
        return
    if validator is not None:
        value = validator(value)
    editor.set(key, value)


def _settings_compiler(value):
    aliases = {'gcc': 'GCC', 'g++': 'GCC', 'clang': 'clang++', 'clang++': 'clang++'}
    if value.lower() not in aliases:
        raise ValueError('choose GCC, gcc, g++, clang or clang++')
    return aliases[value.lower()]


def _settings_standard(value):
    if value != 'auto' and not re.fullmatch(r'(?:\d+|(?:gnu|c)\+\+[A-Za-z0-9]+)', value):
        raise ValueError('use auto, a number such as 23, or a native C++ standard name')
    return value


def _settings_positive(value, allow_inf=False):
    if allow_inf and value == 'inf':
        return value
    if not re.fullmatch(r'[0-9]{1,12}', value) or int(value) == 0:
        raise ValueError('use a positive integer of at most 12 digits' + (' or inf' if allow_inf else ''))
    return str(int(value))


def _settings_choice(*choices):
    def validate(value):
        if value not in choices:
            raise ValueError('choose ' + ' or '.join(choices))
        return value
    return validate


def _settings_filename(value):
    _settings_file_path(value)
    if not value.endswith(('.cpp', '.cc', '.cxx', '.C', '.c', '.py')):
        raise ValueError('use a C/C++/Python source path')
    return value


def _settings_file_path(value):
    """Saved file paths are literal; only a leading workspace token is special."""
    relative = workspace_path_suffix(value)
    if not value or relative == "":
        raise ValueError('use a filename, optionally prefixed with {wsp-dir}/')
    return value


def _settings_destination(value):
    """Match routing's lexical rules; physical containment is checked at use."""
    relative = workspace_path_suffix(value)
    if relative is not None:
        value_for_check = relative or '.'
    else:
        value_for_check = value
    if Path(value_for_check).is_absolute() or '..' in Path(value_for_check).parts:
        raise ValueError('use a workspace-relative path without .. components')
    return value


def _settings_macro(value):
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', value):
        raise ValueError('use a C++ macro identifier, without -D or a value')
    return value


def _settings_seed(value):
    """Accept the generator's complete unsigned 64-bit range, including zero."""
    if not re.fullmatch(r'[0-9]{1,20}', value) or int(value) >= 2**64:
        raise ValueError('use an unsigned 64-bit integer (0 to 18446744073709551615)')
    return str(int(value))


def _settings_flags(editor, key, profile=None):
    with editor.scope([key], profile):
        _settings_flags_menu(editor, key, profile)


def _settings_flags_menu(editor, key, profile=None):
    while True:
        value = editor.data[key].get(profile, '') if profile else editor.data[key]
        current = shlex.split(value) if profile else value
        print('Flags: ' + (shlex.join(current) or '(none)'))
        command = editor.ask('flags> [flags / add / remove / clear / back]: ')
        if command is None:
            continue
        if command in ('', 'back'):
            return
        changed = [] if command == 'clear' else _settings_change_flags(
            current, command, python=key in ('PYTHON_FLAGS', 'MODE_CPYTHON', 'MODE_PYPY'))
        if profile:
            updated = dict(editor.data[key])
            updated[profile] = shlex.join(changed)
            editor.set(key, updated)
        else:
            editor.set(key, changed)


def _settings_fields(editor, title, fields):
    """A shared scalar menu keeps file/limit/stress behavior consistent."""
    with editor.scope([field[0] for field in fields]):
        while True:
            print('\n' + title)
            for i, (key, label, _) in enumerate(fields, 1):
                print('  {}. {}: {}'.format(i, label, editor.data[key]))
            choice = editor.ask('Choose a number, back, help, save or cancel: ')
            if choice is None:
                continue
            if choice in ('', 'back'):
                return
            if choice.isdecimal() and 1 <= int(choice) <= len(fields):
                key, label, validator = fields[int(choice) - 1]
                _settings_scalar(editor, key, label, validator)
            else:
                print('Choose a displayed number.')


def _settings_build(editor):
    with editor.scope(['DEFAULT_COMPILER', 'DEFAULT_STANDARD', 'DEFAULT_FLAGS']):
        while True:
            print('\nBuild\n  1. Compiler: {}\n  2. Standard: {}\n  3. Common flags: {}'.format(
                editor.data['DEFAULT_COMPILER'], editor.data['DEFAULT_STANDARD'],
                shlex.join(editor.data['DEFAULT_FLAGS']) or '(none)'))
            choice = editor.ask('build> [1–3 / back]: ')
            if choice is None:
                continue
            if choice in ('', 'back'):
                return
            if choice == '1':
                _settings_scalar(editor, 'DEFAULT_COMPILER', 'Compiler [GCC / clang++]', _settings_compiler)
            elif choice == '2':
                _settings_scalar(editor, 'DEFAULT_STANDARD', 'Standard [auto / 23 / c++26]', _settings_standard)
            elif choice == '3':
                _settings_flags(editor, 'DEFAULT_FLAGS')
            else:
                print('Choose 1, 2 or 3.')


def _settings_warnings(editor):
    with editor.scope(['WARNINGS_GCC', 'WARNINGS_CLANG']):
        while True:
            common = [flag for flag in editor.data['WARNINGS_GCC'] if flag in editor.data['WARNINGS_CLANG']]
            print('\nWarnings\n  1. Common: {}\n  2. GCC: {}\n  3. Clang: {}'.format(
                shlex.join(common) or '(none)', shlex.join(editor.data['WARNINGS_GCC']),
                shlex.join(editor.data['WARNINGS_CLANG'])))
            choice = editor.ask('warnings> [1–3 / back]: ')
            if choice is None:
                continue
            if choice in ('', 'back'):
                return
            if choice in ('2', '3'):
                _settings_flags(editor, 'WARNINGS_GCC' if choice == '2' else 'WARNINGS_CLANG')
            elif choice == '1':
                command = editor.ask('Common flags [flags / clear / back]: ')
                if command is None or command in ('', 'back'):
                    continue
                changed = [] if command == 'clear' else _settings_change_flags(common, command)
                updated = copy.deepcopy(editor.data)
                for key in ('WARNINGS_GCC', 'WARNINGS_CLANG'):
                    extras = [flag for flag in updated[key] if flag not in common]
                    updated[key] = changed + [flag for flag in extras if flag not in changed]
                editor.replace(updated)
            else:
                print('Choose 1, 2 or 3.')


def _settings_profile(editor, name):
    with editor.scope(PROFILE_KEYS, name):
        _settings_profile_menu(editor, name)


def _settings_profile_preview(editor, name):
    """Expand platform groups on request; the everyday menu stays compact."""
    print('Configured combinations; compiler/library support is checked at build time:')
    print('CPU: {}; native selection is resolved at build time.'.format(
        editor.data['MODE_CPU'].get(name, 'default')))
    if not any(editor.data[key].get(name, '') for key in ('MODE_LIBSTDCXX', 'MODE_LIBCPP')):
        print('No standard-library-specific flags in this profile.')
    for family in ('gcc', 'clang'):
        base = editor.data['WARNINGS_GCC' if family == 'gcc' else 'WARNINGS_CLANG']
        for library in ('libstdc++', 'libc++'):
            groups = ('common', family, library, 'warnings-' + family)
            words = list(editor.data['DEFAULT_FLAGS']) + list(base)
            for group in groups:
                words.extend(shlex.split(editor.data[SETTINGS_GROUPS[group]].get(name, '')))
            print('  {} + {}: {}'.format(family, library, shlex.join(words) or '(none)'))


def _settings_profile_menu(editor, name):
    while name in editor.data['MODE_NAMES']:
        print('\nProfile {} ({})'.format(name, editor.data['MODE_KIND'][name]))
        print('  Native common: ' + (editor.data['MODE_FLAGS'].get(name, '') or '(none)'))
        print('  CPU: ' + editor.data['MODE_CPU'].get(name, 'default'))
        print('  Compiler/library adaptations are retained; Python groups are under advanced.')
        choice = editor.ask('profile> [flags / preview / advanced / kind / cpu / delete / back]: ')
        if choice is None:
            continue
        if choice in ('', 'back'):
            return
        if choice == 'flags':
            _settings_flags(editor, 'MODE_FLAGS', name)
        elif choice == 'preview':
            _settings_profile_preview(editor, name)
        elif choice == 'advanced':
            groups = list(SETTINGS_GROUPS)
            for i, group in enumerate(groups, 1):
                print('  {}. {}: {}'.format(i, group, editor.data[SETTINGS_GROUPS[group]].get(name, '') or '(none)'))
            group = editor.ask('Group number/name, or back: ')
            if group is None:
                continue
            if group.isdecimal() and 1 <= int(group) <= len(groups):
                group = groups[int(group) - 1]
            if group in SETTINGS_GROUPS:
                _settings_flags(editor, SETTINGS_GROUPS[group], name)
            elif group not in ('', 'back'):
                print('Choose a displayed group.')
        elif choice == 'kind':
            kind = editor.ask('debug (guard checks) or flags (native precedence): ')
            if kind not in (None, ''):
                kind = _settings_choice('debug', 'flags')(kind)
                changed = dict(editor.data['MODE_KIND'])
                changed[name] = kind
                editor.set('MODE_KIND', changed)
        elif choice == 'cpu':
            cpu = editor.ask('default (compiler target) or native (local CPU): ')
            if cpu not in (None, ''):
                cpu = _settings_choice('default', 'native')(cpu)
                changed = dict(editor.data['MODE_CPU'])
                changed[name] = cpu
                editor.set('MODE_CPU', changed)
        elif choice == 'delete':
            _settings_delete_profile(editor, name)
            return
        else:
            print('Use flags for common edits, cpu for targeting, preview to inspect, or advanced for adaptations.')


def _settings_delete_profile(editor, name):
    if name not in editor.data['MODE_NAMES']:
        raise ValueError('profile not found: ' + name)
    updated = copy.deepcopy(editor.data)
    updated['MODE_NAMES'].remove(name)
    for key in PROFILE_KEYS:
        updated[key].pop(name, None)
    editor.replace(updated)
    print('Deleted ' + name + '; undo restores it until you save.')


def _settings_profiles(editor):
    keys = ['MODE_NAMES', *PROFILE_KEYS]
    with editor.scope(keys):
        while True:
            print('\nProfiles: ' + (', '.join(editor.data['MODE_NAMES']) or '(none)'))
            command = editor.ask('profiles> [NAME / new / delete NAME / back]: ')
            if command is None:
                continue
            if command in ('', 'back'):
                return
            words = shlex.split(command)
            if words[0] == 'delete' and len(words) == 2:
                _settings_delete_profile(editor, words[1])
            elif words[0] == 'new' and len(words) <= 3:
                name = words[1] if len(words) >= 2 else editor.ask('New profile name: ')
                if name is None:
                    continue
                reserved = {'compile', 'run', 'test', 'stress', 'tr', 'sr', 'none', 'plain'}
                if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,31}', name) or name in reserved:
                    raise ValueError('start with a letter; use up to 32 letters/digits/_/-; avoid command names')
                if name in editor.data['MODE_NAMES']:
                    raise ValueError('that profile already exists')
                template = words[2] if len(words) == 3 else editor.ask('Template [saved profile name / plain]: ')
                if template is None:
                    continue
                if template != 'plain' and template not in editor.data['MODE_NAMES']:
                    raise ValueError('choose an existing profile or plain')
                updated = copy.deepcopy(editor.data)
                updated['MODE_NAMES'].append(name)
                for key in PROFILE_KEYS:
                    fallback = PROFILE_DEFAULTS.get(key, '')
                    updated[key][name] = updated[key].get(template, fallback) if template != 'plain' else fallback
                editor.replace(updated)
                _settings_profile(editor, name)
            elif len(words) == 1 and words[0] in editor.data['MODE_NAMES']:
                _settings_profile(editor, words[0])
            else:
                print('Example: new contest debug; or type extra to edit the existing profile.')


def save_settings(filename, original, data):
    """Validate a sibling replacement and retain the complete old file on failure."""
    data = validate_preferences(data)
    filename = Path(filename).resolve()
    if filename.read_text() != original:
        raise ValueError('script changed while editing; reopen --set-defaults')
    region = re.search(r'^# CP_RUN_SETTINGS_BEGIN\n.*?^# CP_RUN_SETTINGS_END$', original, re.M | re.S)
    if region is None:
        raise ValueError('embedded settings block is missing')
    updated = original[:region.start()] + settings_text(data) + original[region.end():]
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=filename.parent,
                                         prefix='.' + filename.name + '.', delete=False) as stream:
            temporary = Path(stream.name)
            os.fchmod(stream.fileno(), stat.S_IMODE(filename.stat().st_mode))
            stream.write(updated)
            stream.flush()
            os.fsync(stream.fileno())
        checked = subprocess.run(['/bin/zsh', '-n', str(temporary)], capture_output=True, text=True)
        if checked.returncode:
            raise ValueError('settings not saved: zsh syntax check failed')
        if filename.read_text() != original:
            raise ValueError('script changed while editing; reopen --set-defaults')
        os.replace(temporary, filename)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def _settings_finish(filename, original, initial, editor):
    changed = [(key, initial.get(key), value) for key, value in editor.data.items()
               if initial.get(key) != value]
    if not changed:
        print('No changes; nothing written.')
        return 0
    print('\nReview pending changes:')
    for key, before, after in changed:
        print('  {}: {} -> {}'.format(key, repr(before), repr(after)))
    print('Preferred omitted-source language: ' + editor.data['DEFAULT_LANGUAGE'])
    # Preview each actual backend instead of showing a misleading C++ command
    # when Python or C is the user's preferred language.
    for language, standard_key in (('c++', 'DEFAULT_STANDARD'), ('c', 'C_STANDARD')):
        compiler = editor.data['LANGUAGE_COMPILERS'].get(language, editor.data['DEFAULT_COMPILER'])
        warnings = editor.data['WARNINGS_GCC' if compiler == 'GCC' else 'WARNINGS_CLANG']
        standard = editor.data[standard_key]
        if standard.isdecimal(): standard = language + standard
        dialect = '[newest supported ISO ' + language + ']' if standard == 'auto' else '-std=' + standard
        print('Result ({}): --compiler={} {} {}'.format(language, compiler, dialect,
              shlex.join(editor.data['DEFAULT_FLAGS'] + warnings)))
    print('Result (python): ' + shlex.join([editor.data['DEFAULT_INTERPRETER'], *editor.data['PYTHON_FLAGS']]))
    answer = input('Write these changes to this script? [y/N]: ').strip().lower()
    if answer not in ('y', 'yes'):
        print('Cancelled; nothing saved.')
        return 0
    save_settings(filename, original, editor.data)
    print('Saved in {}. No configuration file was created.'.format(filename))
    return 0


def edit_settings(script_path):
    """Enter a pipe-testable menu; EOF/cancellation never writes preferences."""
    filename = Path(script_path).resolve()
    original = filename.read_text()
    initial = read_settings(original)
    editor = SettingsEditor(initial)
    files = [
        ('DEFAULT_SOURCE', 'Fallback source', _settings_filename),
        ('DEFAULT_WORKSPACE', 'Workspace path', None),
        ('DEFAULT_DESTINATION', 'Workspace-relative destination', _settings_destination),
        ('DEFAULT_INPUT', 'Input file ({wsp-dir}/PATH supported)', _settings_file_path), ('DEFAULT_ANSWER', 'Answer file ({wsp-dir}/PATH supported)', _settings_file_path),
        ('DEFAULT_OUTPUT', 'Redirected program output', _settings_file_path),
        ('DEFAULT_REPORT', 'Test/stress report', _settings_file_path),
        ('DEFAULT_F_MODE', 'Bare -f action', _settings_choice('macro', 'auto', 'in', 'out')),
        ('DEFAULT_MACRO', '-f macro identifier', _settings_macro),
        ('DEFAULT_RELPATH_DESTINATION', 'Destination with --save-relpath', _settings_destination),
    ]
    checks = [
        ('DEFAULT_TIMEOUT', 'Time budget in ms', lambda v: _settings_positive(v, True)),
        ('DEFAULT_MEMORY_LIMIT', 'Memory budget in MiB', lambda v: _settings_positive(v, True)),
        ('DEFAULT_SEPARATOR', r'Auto-test separator (visible \n)', lambda v: (_settings_separator(v), v)[1]),
        ('DEFAULT_LINE_LIMIT', 'Comparison row budget', _settings_positive),
        ('CHECK_TIMEOUT', 'Test/stress time budget in ms', lambda v: _settings_positive(v, True)),
        ('CHECK_MEMORY_LIMIT', 'Test/stress memory budget in MiB', lambda v: _settings_positive(v, True)),
        ('TIME_KILL_FACTOR', 'Time kill multiplier (>= 1)', lambda v: (_factor(v), v)[1]),
        ('MEMORY_KILL_FACTOR', 'Memory kill multiplier (>= 1)', lambda v: (_factor(v), v)[1]),
        ('MAX_LINE_BYTES', 'Maximum compared row bytes', _settings_positive),
        ('MAX_CHECK_BYTES', 'Checked bytes per case (both streams)', _settings_positive),
        ('MAX_REPORT_BYTES', 'Diagnostic bytes per failed case', _settings_positive),
        ('MAX_REPORT_LINES', 'Diagnostic rows per section', _settings_positive),
        ('MAX_SPOOL_BYTES', 'Maximum captured pipe/console bytes', _settings_positive),
    ]
    stress = [
        ('DEFAULT_BRUTE', 'Reference source', _settings_filename),
        ('DEFAULT_GENERATOR', 'Generator source', _settings_filename),
        ('DEFAULT_ITERATIONS', 'Stress iteration ceiling', _settings_positive),
        ('DEFAULT_SEED', 'Starting seed (unsigned 64-bit)', _settings_seed),
    ]
    measurements = [
        ('DEFAULT_WARMUP', 'Warm-up with -t/-m (0 or 1)', _settings_choice('0', '1')),
        ('DEFAULT_AVERAGE', 'Measured runs (0 means 1)', lambda v: str(repetition_count(v))),
        ('DEFAULT_TIME_UNIT', 'Displayed time unit', _settings_choice('s', 'ms')),
        ('DEFAULT_MEMORY_UNIT', 'Displayed memory unit', _settings_choice('B', 'KB', 'KiB', 'MB', 'MiB')),
    ]
    try:
        while True:
            print('\ncp-run 1.1 defaults — changes stay pending until save')
            print('  1. Build: {} / {} / {}'.format(editor.data['DEFAULT_COMPILER'],
                editor.data['DEFAULT_STANDARD'], shlex.join(editor.data['DEFAULT_FLAGS']) or '(no flags)'))
            print('  2. Files: {} / {} / {}'.format(editor.data['DEFAULT_SOURCE'],
                editor.data['DEFAULT_INPUT'], editor.data['DEFAULT_ANSWER']))
            print('  3. Warnings\n  4. Checking & limits: {} ms / {} MiB'.format(
                editor.data['DEFAULT_TIMEOUT'], editor.data['DEFAULT_MEMORY_LIMIT']))
            print('  5. Profiles: {}\n  6. Stress: up to {} cases, seed {}'.format(
                ', '.join(editor.data['MODE_NAMES']) or '(none)', editor.data['DEFAULT_ITERATIONS'],
                editor.data['DEFAULT_SEED']))
            try:
                print('  7. Measurements\n  8. Languages & tools\n  9. Test files & integrations\n  10. Action/profile routing\n  export FILE / import FILE: portable preferences (data only)')
                choice = editor.ask('defaults> [1–10 / export FILE / import FILE / show / undo / reset / help / save / cancel]: ')
                if choice is None:
                    continue
                if choice == '1':
                    _settings_build(editor)
                elif choice == '2':
                    _settings_fields(editor, 'Files (real-out.txt is fixed)', files)
                elif choice == '3':
                    _settings_warnings(editor)
                elif choice == '4':
                    _settings_fields(editor, 'Checking & limits', checks)
                elif choice == '5':
                    _settings_profiles(editor)
                elif choice == '6':
                    _settings_fields(editor, 'Stress defaults', stress)
                elif choice == '7':
                    _settings_fields(editor, 'Measurements', measurements)
                elif choice == '8':
                    _settings_languages(editor)
                elif choice == '9':
                    _settings_fields(editor, 'Test files & integrations', [
                        ('DEFAULT_INPUT_TEMPLATE', 'Input template', lambda v: (case_template(v, 'main', 1), v)[1]),
                        ('DEFAULT_ANSWER_TEMPLATE', 'Answer template', lambda v: (case_template(v, 'main', 1), v)[1]),
                        ('DEFAULT_TEST_DIR', 'Data directory (inherit uses destination)', lambda v: '' if v == 'inherit' else _settings_destination(v)),
                        ('MANUAL_SEPARATOR', 'Manual separator', lambda v: (_settings_separator(v), v)[1]),
                        ('DEFAULT_REPORT_TESTS', 'Show test bodies', _settings_choice('all', 'failed')),
                        ('COMPANION_PORT', 'Companion port', _settings_positive),
                        ('COMPANION_WAIT', 'Companion wait seconds', _settings_positive),
                        ('MINIMIZE_ATTEMPTS', 'Reduction attempt ceiling', _settings_positive),
                        ('MINIMIZE_SECONDS', 'Reduction time seconds', _settings_positive),
                        ('MAX_FAILURES', 'Saved stress failures', _settings_positive),
                    ])
                elif choice == '10':
                    _settings_routing(editor)
                elif choice.startswith('export '):
                    export_preferences(choice[7:].strip(), editor.data, filename)
                    print('Exported pending preferences.')
                elif choice.startswith('import '):
                    updated = load_preferences(choice[7:].strip())
                    for key, value in updated.items():
                        if editor.data.get(key) != value: print('{}: {} -> {}'.format(key, repr(editor.data.get(key)), repr(value)))
                    editor.replace(updated)
                    print('Imported into pending edits; save to apply.')
                elif choice == 'show':
                    for key, value in editor.data.items():
                        print('{}: {}'.format(key, repr(value)))
                else:
                    print('Choose a displayed number; help explains editing.')
            except ValueError as error:
                print('Not changed: ' + str(error))
    except _SettingsSave:
        try:
            return _settings_finish(filename, original, initial, editor)
        except (EOFError, KeyboardInterrupt):
            print('\nCancelled; nothing saved.')
            return 0
    except (_SettingsCancel, EOFError, KeyboardInterrupt):
        print('\nCancelled; nothing saved.')
        return 0


def _settings_languages(editor):
    with editor.scope(['DEFAULT_LANGUAGE', 'LANGUAGE_COMPILERS', 'DEFAULT_INTERPRETER', 'C_SOURCE', 'PYTHON_SOURCE', 'C_STANDARD', 'NATIVE_FORMATTER', 'PYTHON_FORMATTER', 'PYTHON_FLAGS']):
        _settings_languages_menu(editor)


def _settings_languages_menu(editor):
    """Language options stay separate from native optimization/warning lists."""
    while True:
        print('\nLanguages & tools: 1. Interpreter/source/standard/tools  2. Python flags  3. Language/compiler defaults  back')
        choice = editor.ask('languages> ')
        if choice in ('', 'back'): return
        if choice == '1':
            _settings_fields(editor, 'Language settings', [
                ('DEFAULT_INTERPRETER', 'Python interpreter (python3, pypy3 or path)', None),
                ('C_SOURCE', 'C fallback source', _settings_filename),
                ('PYTHON_SOURCE', 'Python fallback source', _settings_filename),
                ('C_STANDARD', 'C standard (auto or native spelling)', None),
                ('NATIVE_FORMATTER', 'C/C++ formatter executable', None),
                ('PYTHON_FORMATTER', 'Python formatter (ruff or black)', None),
            ])
        elif choice == '2': _settings_flags(editor, 'PYTHON_FLAGS')
        elif choice == '3': _settings_language_defaults(editor)


def _settings_language_defaults(editor):
    """Edit language preferences with ordinary names; no map syntax required."""
    while True:
        print('\nLanguage defaults\n  1. Preferred source language: ' + editor.data['DEFAULT_LANGUAGE'])
        for number, language in ((2, 'c'), (3, 'c++')):
            print('  {}. {} compiler: {}'.format(number, language, editor.data['LANGUAGE_COMPILERS'].get(language, 'inherit (' + editor.data['DEFAULT_COMPILER'] + ')')))
        print('  4. Python interpreter: ' + editor.data['DEFAULT_INTERPRETER'])
        choice = editor.ask('language defaults> ')
        if choice in ('', 'back'): return
        if choice == '1':
            _settings_scalar(editor, 'DEFAULT_LANGUAGE', 'Language [c++ / c / python / auto]', _settings_choice('c++', 'c', 'python', 'auto'))
        elif choice in ('2', '3'):
            language = 'c' if choice == '2' else 'c++'
            value = editor.ask(language + ' compiler [GCC / clang / inherit; Enter keeps it]: ')
            if value:
                updated = dict(editor.data['LANGUAGE_COMPILERS'])
                if value == 'inherit': updated.pop(language, None)
                else: updated[language] = _settings_compiler(value)
                editor.set('LANGUAGE_COMPILERS', updated)
        elif choice == '4':
            _settings_scalar(editor, 'DEFAULT_INTERPRETER', 'Interpreter [pypy3 / python3 / absolute path]')


def _settings_routing(editor):
    with editor.scope(['ACTION_DEST_DIR', 'ACTION_SAVE_RELPATH', 'ACTION_SAVE_TEST_RELPATH', 'MODE_DEST_DIR', 'MODE_SAVE_RELPATH', 'MODE_SAVE_TEST_RELPATH']):
        _settings_routing_menu(editor)


def _settings_routing_menu(editor):
    """A small command menu edits optional overrides without JSON syntax."""
    actions = ('ordinary', 'compile', 'debug', 'run', 'test', 'test-auto', 'test-mult', 'stress', 'companion')
    while True:
        print('\nActions: ' + ', '.join(actions))
        print('Or enter profile NAME. Values inherit unless explicitly set.')
        selection = editor.ask('routing> [ACTION / profile NAME / back]: ')
        if selection in ('', 'back'): return
        if selection is None: continue
        profile = selection.startswith('profile ')
        name = selection[8:].strip() if profile else selection
        if name not in (editor.data['MODE_NAMES'] if profile else actions):
            print('Choose an action or a saved profile.'); continue
        prefix = 'MODE_' if profile else 'ACTION_'
        fields = {'dest-dir': prefix + 'DEST_DIR', 'save-relpath': prefix + 'SAVE_RELPATH',
                  'save-test-relpath': prefix + 'SAVE_TEST_RELPATH'}
        while True:
            for label, key in fields.items(): print('  {}: {}'.format(label, editor.data[key].get(name, '(inherit)')))
            command = editor.ask('routing {}> [FIELD VALUE / inherit FIELD / back]: '.format(name))
            if command in ('', 'back'): break
            if command is None: continue
            words = shlex.split(command)
            if len(words) != 2: print('Example: dest-dir build/debug; or inherit dest-dir'); continue
            inherit = words[0] == 'inherit'
            field = words[1] if inherit else words[0]
            if field not in fields: print('Use dest-dir, save-relpath or save-test-relpath.'); continue
            key = fields[field]
            value = '' if inherit else words[1]
            if not inherit:
                if field == 'dest-dir': _settings_destination(value)
                else: _settings_choice('0', '1')(value)
            mapping = dict(editor.data[key])
            if inherit: mapping.pop(name, None)
            else: mapping[name] = value
            editor.set(key, mapping)
