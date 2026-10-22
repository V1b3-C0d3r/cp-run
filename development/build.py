#!/usr/bin/env python3
"""Build the single installable script in a workspace or source release."""
from pathlib import Path
import os
import subprocess
import tempfile
import importlib.util
import re

ROOT = Path(__file__).resolve().parent
VERSION = re.search(r'\bVERSION=([0-9.]+)', (ROOT / 'src/bootstrap.zsh').read_text())[1]
RELEASE = ROOT.parent.parent / 'Versions' / VERSION if ROOT.parent.name == 'Work' else ROOT.parent

# Ordering is explicit: source modules share one namespace in the installed
# file, so deployment adds neither runtime imports nor companion files.
ZSH_MODULES = ('bootstrap.zsh', 'options.zsh', 'paths.zsh', 'languages.zsh', 'toolchain.zsh',
               'profiles.zsh', 'artifacts.zsh', 'history.zsh', 'dispatch.zsh', 'launcher.zsh')
PYTHON_MODULES = ('memory.py', 'runtime.py', 'measurements.py', 'cases.py', 'test_layout.py', 'bundles.py', 'comparison.py', 'reporting.py',
                  'checking.py', 'stress.py', 'minimization.py', 'companion.py', 'integrations.py', 'settings_schema.py', 'settings.py',
                  'preferences.py', 'bridge.py')


def build():
    shell = '\n'.join('# Source: ' + name + '\n' + (ROOT / 'src' / name).read_text()
                      for name in ZSH_MODULES)
    # The shebang must remain byte zero; all later boundaries stay visible.
    shell = shell.replace('# Source: bootstrap.zsh\n', '', 1)
    support = '\n\n'.join('# Source: ' + name + '\n' + (ROOT / 'src' / name).read_text()
                           for name in PYTHON_MODULES)
    support = re.sub(r'# @SOURCE_IMPORT_BEGIN@\n.*?# @SOURCE_IMPORT_END@\n', '', support, flags=re.S)
    spec = importlib.util.spec_from_file_location('cp_run_schema', ROOT / 'src/settings_schema.py')
    schema = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(schema)
    shell = shell.replace('# @NATIVE_SETTINGS@', schema.settings_text(schema.FACTORY_SETTINGS))
    # A quoted heredoc embeds data without evaluating shell metacharacters.
    if '\nCP_RUN_PYTHON\n' in support or shell.count('# @EMBEDDED_PYTHON@') != 1:
        raise ValueError('invalid embedded Python marker or delimiter')
    assembled = shell.replace('# @EMBEDDED_PYTHON@', support.rstrip())
    target = RELEASE / 'cp-run.zsh'
    # Build beside the target: atomic replacement never truncates a live script.
    descriptor, temporary = tempfile.mkstemp(prefix='.cp-run-build-', dir=RELEASE)
    try:
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(assembled)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o755)
        subprocess.run(['zsh', '-n', temporary], check=True)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return target


if __name__ == '__main__':
    print(build())
