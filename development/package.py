#!/usr/bin/env python3
"""Publish only maintained sources, the script, documentation and examples."""
from pathlib import Path
import hashlib
import os
import re
import tempfile
import zipfile

from build import ROOT, RELEASE, build


EXAMPLE_FILES = (
    'README.md',
    'companion/sample.json',
    'file-io/ans.txt',
    'file-io/in.txt',
    'file-io/main.cpp',
    'languages/main.c',
    'mult/main.py',
    'mult/tests/1.ans',
    'mult/tests/1.in',
    'mult/tests/2.ans',
    'mult/tests/2.in',
    'optimization/gcc-pragmas.hpp',
    'optimization/main.cpp',
    'optimization/nan.cpp',
    'reduction/README.md',
    'reduction/brute.py',
    'reduction/gen.py',
    'reduction/main.py',
    'reduction/validate.py',
    'runtime/checks.cpp',
    'runtime/main.cpp',
    'stress/brute.cpp',
    'stress/buggy.cpp',
    'stress/gen.cpp',
    'stress/main.cpp',
    'testing/ans.txt',
    'testing/auto.ans',
    'testing/auto.in',
    'testing/console-auto.txt',
    'testing/console-literal.txt',
    'testing/console.txt',
    'testing/custom.ans',
    'testing/custom.in',
    'testing/in.txt',
    'testing/sum.cpp',
    'testing/wrong.ans',
)


def release_files():
    """Map the organized workspace and a GitHub checkout to one archive layout."""
    workspace = ROOT.parent.name == 'Work'
    docs = RELEASE / ('Documentation' if workspace else 'docs')
    files = {
        RELEASE / 'cp-run.zsh': 'cp-run.zsh',
        (docs if workspace else RELEASE) / 'README.md': 'README.md',
        (docs if workspace else RELEASE) / 'LICENSE': 'LICENSE',
        docs / 'CLI.md': 'docs/CLI.md', docs / 'TESTING.md': 'docs/TESTING.md',
    }
    for path in docs.glob('*.md'):
        if path.name != 'README.md': files[path] = 'docs/' + path.name
    if (ROOT / 'JOURNAL.md').exists(): files[ROOT / 'JOURNAL.md'] = 'development/JOURNAL.md'
    for name in ('build.py', 'package.py'):
        files[ROOT / name] = 'development/' + name
    for name in ('src', 'tests'):
        for path in (ROOT / name).rglob('*'):
            if path.is_file() and path.suffix in ('.py', '.zsh') and '__pycache__' not in path.parts:
                files[path] = 'development/' + path.relative_to(ROOT).as_posix()
    examples = RELEASE / ('Examples' if workspace else 'examples')
    for relative in EXAMPLE_FILES:
        files[examples / relative] = 'examples/' + relative
    for name in ('.gitignore', '.gitattributes'):
        files[(ROOT if workspace else RELEASE) / name] = name
    files[ROOT / 'ci.yml' if workspace else RELEASE / '.github/workflows/ci.yml'] = '.github/workflows/ci.yml'
    return files


def archive_bytes(source, name, files):
    """Rebase local Markdown links when documents move to the GitHub layout."""
    if source.suffix != '.md':
        return source.read_bytes()
    destinations = {path.resolve(): target for path, target in files.items()}

    def link(match):
        value = match[1]
        if value.startswith('#') or re.match(r'[a-z]+:', value):
            return match[0]
        path, marker, anchor = value.partition('#')
        target = destinations.get((source.parent / path).resolve())
        if target is None:
            raise ValueError('unmapped documentation link: {}: {}'.format(source, value))
        relative = os.path.relpath(target, str(Path(name).parent))
        return '](' + relative + (marker + anchor if marker else '') + ')'

    return re.sub(r'\]\(([^)\n]+)\)', link, source.read_text()).encode()


def package():
    script = build()
    version = re.search(r'\bVERSION=([0-9.]+)', script.read_text())[1]
    name = 'cp-run-' + version
    target = RELEASE / (name + '.zip')
    files = release_files()
    descriptor, temporary = tempfile.mkstemp(prefix='.cp-run-package-', dir=RELEASE)
    os.close(descriptor)
    try:
        with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            for source, relative in sorted(files.items(), key=lambda item: item[1]):
                info = zipfile.ZipInfo(name + '/' + relative, date_time=(1980, 1, 1, 0, 0, 0))
                info.create_system = 3
                info.external_attr = (source.stat().st_mode & 0xffff) << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, archive_bytes(source, relative, files))
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return target, hashlib.sha256(target.read_bytes()).hexdigest(), len(files)


if __name__ == '__main__':
    archive, digest, count = package()
    print('{}: {} files\nSHA256 {}'.format(archive, count, digest))
