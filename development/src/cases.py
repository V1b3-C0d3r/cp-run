"""Answer checking and reproducible stress tests, embedded in cp-run.zsh.

This module shares Runner with runtime.py. It never compiles, evaluates shell
text or captures stderr. The shell prepares executable paths before execution.
"""

import base64
from collections import deque
from contextlib import contextmanager
from dataclasses import dataclass
import fcntl
import hashlib
import io
import json
import os
from pathlib import Path
import shlex
import shutil
import sys
import tempfile


class CheckUsageError(ValueError):
    """A malformed request; the CLI adapter prints one diagnostic/status 2."""


class CheckSetupError(OSError):
    """Files or infrastructure failed independently of the tested solution."""


def decode_separator(value):
    """Accept literal LF or visible \\n; deliberately decode no other escapes."""
    text = str(value).replace(r"\n", "\n").replace(r"\x1e", "\x1e")
    allowed = "\n\x1e #=_.:+-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    if not text or text[0] != "\n" or text[-1] != "\n" or any(c not in allowed for c in text):
        raise CheckUsageError("--sep must start/end with LF and contain only LF, ASCII letters, digits, spaces or #=_.:+-")
    return text.encode("ascii")


def split_cases(payload, separator):
    """Drop one terminal terminator, preserving deliberate empty test blocks."""
    blocks = payload.split(separator)
    if payload.endswith(separator):
        blocks.pop()
    return blocks or [b""]


def positive_setting(value, label):
    text = str(value)
    if not text.isascii() or not text.isdecimal() or len(text) > 12 or int(text) <= 0:
        raise CheckUsageError(label + " must be a positive integer (up to 12 digits)")
    return int(text)


def _frame_console(stream, outputs, maximum=268435456):
    """Copy framed console bytes in bounded chunks, including very long rows."""
    if getattr(stream, 'isatty', lambda: False)():
        print('Input, then :::answer::: on its own line, then answer and EOF:', file=sys.stderr)
    source = stream.buffer if hasattr(stream, 'buffer') else stream
    side, total, at_start = 0, 0, True
    while True:
        line = source.readline(65536)
        if not line: break
        if isinstance(line, str): line = line.encode()
        total += len(line)
        if total > maximum: raise CheckSetupError('console input exceeds spool byte limit')
        body = line[:-1] if line.endswith(b'\n') else line
        if body.endswith(b'\r'): body = body[:-1]
        if at_start and body == b':::answer:::':
            if side: raise CheckUsageError('--cin requires exactly one :::answer::: marker line')
            side = 1
        else:
            if at_start and body == b'\\:::answer:::': line = line[1:]
            outputs[side].write(line)
        at_start = line.endswith(b'\n')
    if not side: raise CheckUsageError('--cin requires an :::answer::: marker line')


def console_payloads(stream):
    """Small in-memory convenience API; the CLI spools directly to files."""
    outputs = (io.BytesIO(), io.BytesIO())
    _frame_console(stream, outputs)
    return tuple(output.getvalue() for output in outputs)


@dataclass(frozen=True)
class CaseSlice:
    """A byte range in a regular file, copied without loading the whole case."""
    path: str
    start: int
    length: int

    def copy_to(self, destination):
        with open(self.path, 'rb') as source, open(destination, 'wb') as output:
            source.seek(self.start)
            remaining = self.length
            while remaining:
                block = source.read(min(65536, remaining))
                if not block: raise CheckSetupError('test data changed or was truncated: ' + self.path)
                output.write(block); remaining -= len(block)


def index_cases(path, separator=None, start_offset=0, keep_terminal=False):
    """Index nonoverlapping delimiters across chunks; drop one terminal delimiter."""
    path = str(Path(path).resolve())
    if not Path(path).is_file(): raise CheckSetupError('test file not found or not regular: ' + path)
    if separator is None: return [CaseSlice(path, 0, Path(path).stat().st_size)]
    ranges, pending, base, start = [], b'', start_offset, start_offset
    with open(path, 'rb') as stream:
        stream.seek(start_offset)
        while True:
            block = stream.read(65536)
            if not block: break
            pending += block
            while True:
                found = pending.find(separator)
                if found < 0: break
                end = base + found
                ranges.append(CaseSlice(path, start, end - start))
                if len(ranges) > 100000: raise CheckSetupError('test bundle exceeds 100000 cases')
                consumed = found + len(separator)
                start = base + consumed
                pending = pending[consumed:]; base += consumed
            keep = min(len(pending), len(separator) - 1)
            discard = len(pending) - keep
            pending = pending[discard:]; base += discard
    size = base + len(pending)
    if keep_terminal or start < size or not ranges: ranges.append(CaseSlice(path, start, size - start))
    return ranges


def _console_paths(config):
    """Persist only filenames, never base64 copies of the complete test bundle."""
    cache = config.get('console_cache')
    if not cache: raise CheckUsageError('--cin requires a private console cache')
    cache = Path(cache)
    incoming, answer = str(cache) + '.input', str(cache) + '.answer'
    if not cache.exists():
        with open(incoming, 'xb') as left, open(answer, 'xb') as right:
            _frame_console(sys.stdin, (left, right), positive_setting(config.get('max_spool', 268435456), 'spool limit'))
        with cache.open('x') as record: json.dump({'input': incoming, 'answer': answer}, record)
    return json.loads(cache.read_text())


def _same_path(left, right):
    a, b = Path(left), Path(right)
    if a.resolve() == b.resolve():
        return True
    try:
        return a.exists() and b.exists() and os.path.samefile(a, b)
    except OSError:
        return False


def _validate_paths(config):
    """Protect every readable role before creating any report/output artifact."""
    operation = config.get("operation", "test")
    protected = [str(p) for p in config.get("protected", []) if p]
    protected.extend(str(config[key]) for key in ("executable", "brute", "generator") if config.get(key))
    reads = []
    if operation == "test" and not config.get("cin"):
        reads = config.get("case_reads") if config.get("mult") else [config.get("input", "input.txt"), config.get("answer", "ans.txt")]
        reads = reads or []
        if len(reads) == 2 and _same_path(*reads):
            raise CheckUsageError("test input and answer must be different files")
        for path in reads:
            if not Path(path).is_file():
                raise CheckSetupError("test file not found or not regular: " + str(path))
            if any(_same_path(path, other) for other in protected):
                raise CheckUsageError("test data must not alias a source or executable: " + str(path))
    actual = Path("real-out.txt").absolute()
    # The fixed name is intentional; config cannot quietly change this role.
    config["actual"] = str(actual)
    writes = [str(actual)]
    if not config.get("cout"):
        writes.append(str(config.get("report", "test_out")))
    for index, path in enumerate(writes):
        candidate = Path(path)
        if candidate.is_symlink() or candidate.is_dir():
            raise CheckUsageError("test output must be a regular path, not a symlink/directory: " + path)
        if not candidate.parent.is_dir():
            raise CheckSetupError("test output directory does not exist: " + str(candidate.parent))
        if any(_same_path(path, other) for other in protected + reads + writes[:index]):
            raise CheckUsageError("test output would overwrite another role: " + path)


@dataclass
class CheckPlan:
    inputs: list
    answers: list
    selected: list
    separator: bytes
    line_limit: int
    zero_notice: bool = False
    ids: list = None


def _prepare_check(config):
    operation = config.get("operation", "test")
    separator = decode_separator(config.get("sep", r"\n\n"))
    line_limit = positive_setting(config.get("line_limit", 10000), "NUM_LINE_LIMIT")
    maximum = config.get("num_test")
    if maximum is not None:
        maximum = positive_setting(maximum, "--test-iters")
    if operation == "stress":
        if config.get("cin"):
            raise CheckUsageError("--cin is not supported by stress; use test --cin")
        positive_setting(config.get("iterations", 1000), "stress iterations")
        seed = config.get("seed")
        if seed is not None and (not str(seed).isascii() or not str(seed).isdecimal()
                                 or len(str(seed)) > 20 or not 0 <= int(seed) < 2**64):
            raise CheckUsageError("--seed must be an unsigned 64-bit integer")
        _validate_paths(config)
        return CheckPlan([], [], [], separator, line_limit)
    # Discover and validate the complete suite before selection or compilation.
    ids = None
    if config.get('mult'):
        if config.get('cin'): raise CheckUsageError('--cin is unavailable with mult files')
        ids, inputs, answers = mult_cases(config)
        config['case_reads'] = [case.path for case in (*inputs, *answers)]
    else:
        paths = _console_paths(config) if config.get('cin') else {
            'input': config.get('input', 'input.txt'), 'answer': config.get('answer', 'ans.txt')}
        auto = bool(config.get('auto'))
        reader = counted_cases if auto and config.get('bundle_format') == 'counted' else index_cases
        inputs = reader(paths['input'], separator if auto else None)
        answers = reader(paths['answer'], separator if auto else None)
    if len(inputs) != len(answers):
        raise CheckUsageError('test count mismatch: input has {} cases; answer has {}'.format(len(inputs), len(answers)))
    if not inputs: raise CheckUsageError('test suite is empty')
    ids = ids or list(range(1, len(inputs) + 1))
    available = set(ids)
    requested = config.get('cases', [])
    independent = config.get('auto') or config.get('mult')
    if requested and not independent: raise CheckUsageError('case numbers require test=auto or test=mult')
    selected, zero = [], False
    for value in requested:
        try: number = int(value)
        except (ValueError, TypeError): raise CheckUsageError('test case numbers must be integers') from None
        if number == 0: number, zero = 1, True
        if number not in available: raise CheckUsageError('test number {} is not available'.format(number))
        if number not in selected: selected.append(number)
    selected = selected or ids
    if maximum is not None and independent: selected = selected[:maximum]
    _validate_paths(config)
    return CheckPlan(inputs, answers, selected, separator, line_limit, zero, ids)


def preflight_check(config):
    """Count/validate cases before compilation; console is spooled only once."""
    return _prepare_check(config)


def _load_plan(config):
    return _prepare_check(config)


@contextmanager
def check_lock():
    """Lock the directory inode: no stale PID file or persistent config sidecar."""
    descriptor = os.open(".", os.O_RDONLY)
    try:
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise CheckSetupError("another test/stress run is writing results in this directory") from None
        yield
    finally:
        os.close(descriptor)

