"""Final small public interface: configure, pack/unpack and value-free -f."""

from pathlib import Path
import unittest

from _paths import load_engine
import test_cli as fixtures

engine = load_engine('cp_run_final_commands')


class FinalCommandsTest(unittest.TestCase):
    setUp = fixtures.CliTest.setUp
    tearDown = fixtures.CliTest.tearDown
    environment = fixtures.CliTest.environment
    invoke = fixtures.CliTest.invoke
    calls = fixtures.CliTest.calls

    def test_configure_switches_saved_action_and_preserves_factory_macro(self):
        self.assertEqual(engine.FACTORY_SETTINGS['DEFAULT_F_MODE'], 'macro')
        installed = self.root / 'installed.zsh'
        installed.write_bytes(fixtures.SCRIPT.read_bytes()); installed.chmod(0o755)
        configured = self.invoke('configure', script=installed, input='2\n8\nauto\nsave\ny\n')
        self.assertEqual(configured.returncode, 0, configured.stderr)
        self.assertEqual(engine.read_settings(installed.read_text())['DEFAULT_F_MODE'], 'auto')
        (self.cwd / 'in.txt').write_text('redirected\n')
        result = self.invoke(self.source, '-f', script=installed, env={'FAKE_PROGRAM_STDIN': '1'})
        self.assertEqual((result.returncode, result.stdout), (0, ''), result.stderr)
        self.assertEqual((self.cwd / 'out.txt').read_text(), 'redirected\n')
        result = self.invoke('configure', script=installed, input='2\n8\nmacro\nsave\ny\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.invoke('compile', self.source, '-f', script=installed)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('-DFILEO', self.calls()[-1])

    def test_f_values_are_rejected_for_both_aliases_and_clusters(self):
        for word in ('-f=auto', '-f=manual', '-f=macro', '-f=', '--file-io=auto',
                     '--file-io=', '-ftm=auto', '-tm=1'):
            with self.subTest(word=word):
                result = self.invoke(self.source, word)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn('take no values', result.stderr)
        self.assertEqual(self.calls(include_probes=True), [])

    def test_configure_is_exclusive_and_old_actions_have_clear_migration_errors(self):
        for args in (('configure', self.source), ('configure', '--doctor'),
                     ('configure', '--make-prettier'), ('configure', '--version'),
                     ('configure', '--export-settings=unused'),
                     ('--set-default',), ('--set-defaults',), ('--set-defaults=x',),
                     ('--pack',), ('--unpack=in',), ('--text',)):
            with self.subTest(args=args):
                result = self.invoke(*args, input='cancel\n')
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertNotIn('Traceback', result.stderr)
        self.assertEqual(self.calls(include_probes=True), [])
        self.assertFalse((self.cwd / 'unused').exists())

    def test_operation_names_remain_literal_inside_backend_arguments(self):
        values = ['configure', 'pack', 'unpack', '--set-defaults', '-f=auto']
        result = self.invoke('compile', self.source, '--', *values)
        self.assertEqual(result.returncode, 0, result.stderr)
        args = self.calls()[-1]
        self.assertEqual(args[args.index('configure'):args.index('configure') + len(values)], values)
