#!/usr/bin/env python3
"""Measure a private source corpus without executing its programs."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import platform
import signal
import shutil
import statistics
import subprocess
import time


def run_case(script, source, environment, timeout):
    """Capture CLI latency/outcome; never execute a submitted program."""
    before = source.read_bytes()
    started = time.monotonic()
    try:
        process = subprocess.Popen([str(script), 'format', '--school', str(source)],
                                   cwd=source.parent, env=environment, text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        _, diagnostic = process.communicate(timeout=timeout)
        status = process.returncode
    except subprocess.TimeoutExpired:
        # The unreaped leader still owns this process group; stop its compilers
        # too, rather than leaving benchmark work running after a timeout.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.communicate()
        diagnostic, status = 'benchmark timeout', 124
    after = source.read_bytes()
    return dict(seconds=time.monotonic() - started, status=status,
                diagnostics=Counter(diagnostic_kind(diagnostic)),
                source_before=hashlib.sha256(before).hexdigest(),
                source_after=hashlib.sha256(after).hexdigest())


def diagnostic_kind(text):
    for line in text.splitlines():
        if ': school ' in line:
            yield line.split(': school ', 1)[1].split(':', 1)[0]
    if 'syntax prevents safe publication' in text:
        yield 'syntax failure'
    if 'formatter changed' in text or 'formatting changed' in text:
        yield 'safety failure'
    if 'benchmark timeout' in text:
        yield 'timeout'


def benchmark(arguments):
    corpus, script, work = arguments.corpus.resolve(), arguments.script.resolve(), arguments.work.resolve()
    if work.exists():
        raise ValueError('work directory already exists: ' + str(work))
    if work == corpus or corpus in work.parents:
        raise ValueError('work directory must be outside the corpus')
    work.mkdir(parents=True)
    pinned_script = work / 'cp-run'
    shutil.copy2(script, pinned_script)
    script = pinned_script
    target = work / 'sources'
    shutil.copytree(corpus, target, symlinks=True, ignore=shutil.ignore_patterns('.git', '.bin'))
    if arguments.sample:
        names = json.loads(arguments.sample.read_text())
    else:
        names = [str(path.relative_to(target)) for path in sorted(target.rglob('*'))
                 if path.suffix in ('.c', '.cc', '.cpp', '.cxx', '.C') and path.is_file() and not path.is_symlink()]
    if any(not (target / name).resolve().is_relative_to(target) for name in names):
        raise ValueError('sample escapes the copied source tree')
    report = dict(platform=platform.platform(), script_sha256=hashlib.sha256(script.read_bytes()).hexdigest(),
                  cases=[], phases={})
    environment = dict(os.environ, XDG_CACHE_HOME=str(work / 'cache'), XDG_STATE_HOME=str(work / 'state'))
    for index, name in enumerate(names, 1):
        source = target / name
        cold = run_case(script, source, environment, arguments.timeout)
        warm = run_case(script, source, environment, arguments.timeout)
        case = dict(file=name, cold=cold, warm=warm, idempotent=warm['source_before'] == warm['source_after'])
        if arguments.edited:
            text = source.read_text()
            position = text.rfind('return 0;')
            if position >= 0:
                source.write_text(text[:position] + 'return 1;' + text[position + len('return 0;'):])
                case['edit'] = 'return-value'
            else:
                source.write_text(text + '\n// benchmark body edit\n')
                case['edit'] = 'comment'
            case['edited'] = run_case(script, source, environment, arguments.timeout)
        report['cases'].append(case)
        arguments.output.write_text(json.dumps(report, indent=2) + '\n')
        print('{}/{} {} {:.3f}s cold / {:.3f}s warm'.format(
            index, len(names), name, cold['seconds'], warm['seconds']), flush=True)
    for phase in ('cold', 'warm', 'edited'):
        values = sorted(item[phase]['seconds'] for item in report['cases'] if phase in item)
        if values:
            report['phases'][phase] = dict(median=statistics.median(values),
                p90=values[min(len(values) - 1, int(len(values) * .9))], maximum=max(values))
    arguments.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report['phases'], indent=2), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('corpus', type=Path)
    parser.add_argument('--script', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--sample', type=Path)
    parser.add_argument('--edited', action='store_true')
    parser.add_argument('--timeout', type=float, default=45)
    benchmark(parser.parse_args())
