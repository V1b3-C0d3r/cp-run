"""Locate sources and the public script in workspace and release layouts."""
from pathlib import Path
import sys
import types
import os
import tempfile
import atexit
import re

# Every integration test gets generated history outside the user's real state.
_state = tempfile.TemporaryDirectory(prefix='cp-run-test-state-')
os.environ['XDG_STATE_HOME'] = _state.name
atexit.register(_state.cleanup)

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from build import RELEASE


def load_engine(name):
    """Exercise the exact module ordering used by the one-file builder."""
    sys.path.insert(0, str(ROOT))
    from build import PYTHON_MODULES
    module = types.ModuleType(name)
    sys.modules[name] = module
    for filename in PYTHON_MODULES:
        if filename != 'bridge.py':
            source = (ROOT / 'src' / filename).read_text()
            source = re.sub(r'# @SOURCE_IMPORT_BEGIN@\n.*?# @SOURCE_IMPORT_END@\n', '', source, flags=re.S)
            exec(compile(source, filename, 'exec'), module.__dict__)
    return module
