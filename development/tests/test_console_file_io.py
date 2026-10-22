"""Auto file redirection can put exactly one stream back on the console."""

from pathlib import Path
import unittest

from _paths import load_engine
import test_languages as fixtures

engine = load_engine('cp_run_console_file_io')


class ConsoleFileIOTest(unittest.TestCase):
    setUp_fixture = fixtures.LanguagesTest.setUp
    tearDown = fixtures.LanguagesTest.tearDown
    invoke = fixtures.LanguagesTest.invoke
    source = fixtures.LanguagesTest.source

    def setUp(self):
        self.setUp_fixture()
        fixtures.LanguagesTest.set_file_io_mode(self)

    def echo(self):
        return self.source(content='import sys\nsys.stdout.write(sys.stdin.read())\n')

    def test_cout_reads_file_and_does_not_create_output_file(self):
        source = self.echo()
        (self.cwd / 'in.txt').write_text('file input\n')
        result = self.invoke(source, '-f', '--cout', input='unused console\n')
        self.assertEqual((result.returncode, result.stdout), (0, 'file input\n'), result.stderr)
        self.assertFalse((self.cwd / 'out.txt').exists())

    def test_cin_reads_console_without_opening_missing_input(self):
        source = self.echo()
        result = self.invoke(source, '--cin', '--file-io', input='console input\n')
        self.assertEqual((result.returncode, result.stdout), (0, ''), result.stderr)
        self.assertEqual((self.cwd / 'out.txt').read_text(), 'console input\n')
        self.assertFalse((self.cwd / 'in.txt').exists())

    def test_both_overrides_fail_before_execution_in_either_order(self):
        source = self.source(content='from pathlib import Path; Path("executed").touch()\n')
        for args in (('-f', '--cin', '--cout'), ('--cout', '--cin', '-f')):
            result = self.invoke(source, *args)
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertIn('cannot combine', result.stderr)
            self.assertFalse((self.cwd / 'executed').exists())
            self.assertFalse((self.cwd / 'out.txt').exists())

    def test_explicit_files_keep_slots_and_unused_input_is_not_resolved(self):
        result = self.invoke(self.echo(), '-f', '{wsp-dir}/missing', 'chosen.txt', '--cin',
                             '--wsp-dir=/missing/workspace', input='text')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / 'chosen.txt').read_text(), 'text')

    def test_saved_auto_action_supports_bare_f_and_console_override(self):
        source = Path(self.script).read_text(); values = engine.read_settings(source)
        values['DEFAULT_F_MODE'] = 'auto'
        engine.save_settings(Path(self.script), source, values)
        (self.cwd / 'in.txt').write_text('saved\n')
        result = self.invoke(self.echo(), '--cout', '-f')
        self.assertEqual((result.returncode, result.stdout), (0, 'saved\n'), result.stderr)

    def test_repeats_with_cin_keep_one_output_and_replay_console_input(self):
        source = self.source(content='from pathlib import Path\nimport sys\n'
            'p=Path("count");p.write_text(str(int(p.read_text())+1 if p.exists() else 1))\n'
            'sys.stdout.write(sys.stdin.read())\n')
        result = self.invoke(source, '-f', '--cin', '-tm', '--warm-up=0', '--average=2', input='once\n')
        self.assertEqual((result.returncode, result.stdout), (0, ''), result.stderr)
        self.assertEqual((self.cwd / 'out.txt').read_text(), 'once\n')
        self.assertEqual((self.cwd / 'count').read_text(), '2')

    def test_existing_binary_and_failed_runtime_keep_status_and_stderr(self):
        binary = self.cwd / 'program.out'
        binary.write_text('#!/bin/sh\ncat\nprintf "failure\\n" >&2\nexit 7\n');binary.chmod(0o755)
        (self.cwd / 'in.txt').write_text('visible\n')
        result = self.invoke('run', binary, '-f', '--cout')
        self.assertEqual((result.returncode, result.stdout, result.stderr), (7, 'visible\n', 'failure\n'))

    def test_macro_mode_rejects_either_console_override(self):
        script = Path(self.script)
        script.write_text(script.read_text().replace('typeset -g DEFAULT_F_MODE=auto',
                                                   'typeset -g DEFAULT_F_MODE=macro'))
        for flag in ('--cin', '--cout'):
            result = self.invoke(self.echo(), '-f', flag)
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertFalse((self.cwd / 'out.txt').exists())

    def test_console_overrides_require_auto_and_execution(self):
        source = self.echo()
        for args in (('--cin',), ('-f=in', '--cout'), ('-f=out', '--cin')):
            result = self.invoke(source, *args)
            self.assertEqual(result.returncode, 2, result.stderr)
        result = self.invoke('compile', source, '-f', '--cin')
        self.assertEqual(result.returncode, 2, result.stderr)
