"""Interactive preferences embedded in the installed cp-run.zsh.

Only the marked native declaration block is rewritten. The editor parses data
with shlex; neither entered flags nor saved preferences are shell-evaluated.
"""

import copy
from contextlib import contextmanager
import os
from pathlib import Path
import re
import shlex
import stat
import subprocess
import tempfile


SETTINGS_BEGIN = '# CP_RUN_SETTINGS_BEGIN'
SETTINGS_END = '# CP_RUN_SETTINGS_END'
SETTINGS_GROUPS = {
    'common': 'MODE_FLAGS', 'gcc': 'MODE_GCC', 'clang': 'MODE_CLANG',
    'libstdc++': 'MODE_LIBSTDCXX', 'libc++': 'MODE_LIBCPP',
    'warnings-gcc': 'MODE_WARNINGS_GCC', 'warnings-clang': 'MODE_WARNINGS_CLANG',
    'cpython': 'MODE_CPYTHON', 'pypy': 'MODE_PYPY',
}
# Keep metadata in the same copy/reset/delete transaction as compiler flags.
PROFILE_KEYS = ('MODE_KIND', 'MODE_CPU', 'MODE_DEST_DIR', 'MODE_SAVE_RELPATH',
                'MODE_SAVE_TEST_RELPATH', *SETTINGS_GROUPS.values())
PROFILE_DEFAULTS = {'MODE_KIND': 'flags', 'MODE_CPU': 'default'}

# These defaults mirror the native block. A regression test checks equality so
# reset cannot quietly diverge from a freshly downloaded script.
FACTORY_SETTINGS = {
    'DEFAULT_COMPILER': 'GCC', 'DEFAULT_STANDARD': 'auto',
    'DEFAULT_LANGUAGE': 'c++', 'LANGUAGE_COMPILERS': {},
    'DEFAULT_SOURCE': 'main.cpp', 'DEFAULT_TIMEOUT': 'inf',
    'DEFAULT_MEMORY_LIMIT': 'inf', 'DEFAULT_INPUT': 'in.txt',
    'DEFAULT_OUTPUT': 'out.txt', 'DEFAULT_ANSWER': 'ans.txt',
    'DEFAULT_REPORT': 'test_out', 'DEFAULT_SEPARATOR': r'\n\x1e\n',
    'MANUAL_SEPARATOR': r'\n###\n', 'DEFAULT_INTERPRETER': 'pypy3',
    'C_STANDARD': 'auto', 'C_SOURCE': 'main.c', 'PYTHON_SOURCE': 'main.py',
    'PYTHON_FLAGS': [], 'MODE_CPYTHON': {'debug': '-X dev -W default', 'extra': '-X dev -W error'},
    'MODE_PYPY': {'debug': '-W default -X track-resources', 'extra': '-W error -X track-resources'},
    'ACTION_DEST_DIR': {'test-mult': 'tests'}, 'ACTION_SAVE_RELPATH': {},
    'ACTION_SAVE_TEST_RELPATH': {}, 'MODE_DEST_DIR': {},
    'MODE_SAVE_RELPATH': {}, 'MODE_SAVE_TEST_RELPATH': {},
    'DEFAULT_INPUT_TEMPLATE': './{n}.in', 'DEFAULT_ANSWER_TEMPLATE': './{n}.ans',
    'DEFAULT_TEST_DIR': '', 'NATIVE_FORMATTER': 'clang-format', 'PYTHON_FORMATTER': 'ruff', 'DEFAULT_REPORT_TESTS': 'all',
    'COMPANION_PORT': '27122', 'COMPANION_WAIT': '120',
    'MINIMIZE_ATTEMPTS': '200', 'MINIMIZE_SECONDS': '30', 'MAX_FAILURES': '10',
    'DEFAULT_LINE_LIMIT': '10000', 'DEFAULT_F_MODE': 'macro',
    'DEFAULT_MACRO': 'FILEO', 'DEFAULT_WORKSPACE': '.',
    'DEFAULT_DESTINATION': '.', 'DEFAULT_RELPATH_DESTINATION': '.',
    'DEFAULT_BRUTE': 'brute.cpp', 'DEFAULT_GENERATOR': 'gen.cpp',
    'DEFAULT_ITERATIONS': '1000', 'DEFAULT_SEED': '4',
    'CHECK_TIMEOUT': '1500', 'CHECK_MEMORY_LIMIT': '256',
    'TIME_KILL_FACTOR': '2', 'MEMORY_KILL_FACTOR': '2',
    'DEFAULT_WARMUP': '1', 'DEFAULT_AVERAGE': '1',
    'DEFAULT_TIME_UNIT': 'ms', 'DEFAULT_MEMORY_UNIT': 'KiB',
    'MAX_LINE_BYTES': '1048576', 'MAX_CHECK_BYTES': '67108864',
    'MAX_REPORT_BYTES': '262144', 'MAX_REPORT_LINES': '10000',
    'MAX_SPOOL_BYTES': '268435456',
    'DEFAULT_FLAGS': ['-O2'],
    'WARNINGS_GCC': ['-Wall', '-Wextra', '-Wshadow', '-Wconversion',
                     '-Wduplicated-cond', '-Wlogical-op'],
    'WARNINGS_CLANG': ['-Wall', '-Wextra', '-Wshadow', '-Wconversion',
                       '-Wlogical-op-parentheses', '-Wtautological-compare'],
    'MODE_NAMES': ['debug', 'extra', 'pragma', 'pragma-fast', 'pragma-native'],
    'MODE_KIND': {'debug': 'debug', 'extra': 'debug', 'pragma': 'flags',
                  'pragma-fast': 'flags', 'pragma-native': 'flags'},
    'MODE_CPU': {'debug': 'default', 'extra': 'default', 'pragma': 'default',
                 'pragma-fast': 'default', 'pragma-native': 'native'},
    'MODE_FLAGS': {
        'debug': '-O2 -g2 -fsanitize=address,undefined -fsanitize=float-cast-overflow -fno-sanitize-recover=all -fno-omit-frame-pointer -DLOCAL',
        'extra': '-Og -g2 -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -fno-optimize-sibling-calls -DLOCAL',
        'pragma': '-O3 -funroll-loops -Wunknown-pragmas',
        'pragma-fast': '-funroll-loops -fno-stack-protector -ffast-math -Wunknown-pragmas',
        'pragma-native': '-funroll-loops -fno-stack-protector -ffast-math -Wunknown-pragmas',
    },
    'MODE_GCC': {'debug': '', 'extra': '-fsanitize=float-cast-overflow,bounds-strict',
                 'pragma-fast': '-Ofast', 'pragma-native': '-Ofast'},
    'MODE_CLANG': {'debug': '', 'extra': '-fsanitize=float-cast-overflow,bounds',
                   'pragma-fast': '-O3', 'pragma-native': '-O3'},
    'MODE_LIBSTDCXX': {'debug': '-D_GLIBCXX_ASSERTIONS',
                      'extra': '-D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC'},
    'MODE_LIBCPP': {
        'debug': '-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST',
        'extra': '-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_DEBUG',
    },
    'MODE_WARNINGS_GCC': {
        'debug': '',
        'extra': '-Wsign-conversion -Wnull-dereference -Wvla -Wfloat-equal -Wswitch-enum -Wformat=2 -Wpedantic -Wduplicated-branches -Warray-bounds=2',
    },
    'MODE_WARNINGS_CLANG': {
        'debug': '',
        'extra': '-Wsign-conversion -Wnull-dereference -Wvla -Wfloat-equal -Wswitch-enum -Wformat=2 -Wpedantic -Wunreachable-code -Warray-bounds',
    },
}


def read_settings(source):
    """Read the small declaration grammar without sourcing an editable file."""
    region = re.search(r'^# CP_RUN_SETTINGS_BEGIN\n(.*?)^# CP_RUN_SETTINGS_END$',
                       source, re.M | re.S)
    if region is None:
        raise ValueError('embedded settings block is missing')
    data = {}
    for line in region.group(1).splitlines():
        if not line or line.startswith('#'):
            continue
        match = re.fullmatch(r'typeset -g(a|A)? ([A-Z_]+)=(.*)', line)
        if not match:
            raise ValueError('invalid embedded settings declaration')
        kind, key, value = match.groups()
        if key in data:
            raise ValueError('duplicate setting: ' + key)
        if kind:
            if not value.startswith('(') or not value.endswith(')'):
                raise ValueError('invalid settings array: ' + key)
            words = shlex.split(value[1:-1])
            if kind == 'A':
                if len(words) % 2 or len(set(words[::2])) != len(words[::2]):
                    raise ValueError('invalid settings map: ' + key)
                data[key] = dict(zip(words[::2], words[1::2]))
            else:
                data[key] = words
        else:
            words = shlex.split(value)
            if len(words) != 1:
                raise ValueError('invalid scalar setting: ' + key)
            data[key] = words[0]
    return data


def settings_text(data):
    """Serialize values as quoted native declarations, never executable input."""
    lines = [SETTINGS_BEGIN,
             '# Managed by --set-defaults; ordinary launches read these native values directly.']
    for key, value in data.items():
        if not re.fullmatch(r'[A-Z_]+', key):
            raise ValueError('invalid settings key')
        if isinstance(value, dict):
            words = [word for pair in value.items() for word in pair]
            lines.append('typeset -gA {}=({})'.format(key, shlex.join(words)))
        elif isinstance(value, list):
            lines.append('typeset -ga {}=({})'.format(key, shlex.join(value)))
        else:
            lines.append('typeset -g {}={}'.format(key, shlex.quote(str(value))))
    return '\n'.join(lines) + '\n' + SETTINGS_END


def _settings_separator(value):
    """Decode only visible \\n, then validate the deliberately literal format."""
    decoded = value.replace(r'\n', '\n').replace(r'\x1e', '\x1e')
    allowed = set('\n\x1e abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#=_.:+-')
    if not decoded or decoded[0] != '\n' or decoded[-1] != '\n' or any(c not in allowed for c in decoded):
        raise ValueError(r'separator must start/end with \n; use ASCII letters, digits, spaces or #=_.:+-')
    return decoded


