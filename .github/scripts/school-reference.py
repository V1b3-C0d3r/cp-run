#!/usr/bin/env python3
"""Run the reference GNU compiler in its official image; never run candidates."""
import os
from pathlib import Path
import subprocess
import sys

compiler = Path(sys.argv[0]).name
if compiler not in ('gcc', 'g++'):
    raise SystemExit('Install this wrapper as gcc and g++ before using it')
workspace = os.environ['GITHUB_WORKSPACE']
command = ['docker', 'run', '--rm',
           '--volume', '/tmp:/tmp',
           '--volume', workspace + ':' + workspace,
           '--workdir', os.getcwd(),
           'gcc:11.3', compiler, *sys.argv[1:]]
raise SystemExit(subprocess.run(command).returncode)
