"""Real public settings sessions on isolated copies of the single script."""

import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


from _paths import ROOT, RELEASE, load_engine
settings = load_engine('cp_run_settings_tests')

# A deliberately small recorder isolates preference behavior from a host's
# compiler installation. Real GCC/Clang checks live in the CLI suite.
COMPILER = r'''import json, os, pathlib, sys
args = sys.argv[1:]
if args == ['--version']:
    print('g++ (GNU GCC settings fixture) 16.2.0'); raise SystemExit(0)
if args == ['--help=c++']:
    print('  -std=c++20  C++20\n  -std=c++26  C++26'); raise SystemExit(0)
if '-dM' in args:
    print('#define __GLIBCXX__ 20261001\n#define _GLIBCXX_RELEASE 16'); raise SystemExit(0)
with open(os.environ['SETTINGS_COMPILER_LOG'], 'a') as stream:
    stream.write(json.dumps(args) + '\n')
output = pathlib.Path(args[args.index('-o') + 1])
output.write_text('#!/bin/sh\ncat\n'); output.chmod(0o755)
'''


class SettingsTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cp-run-settings-')
        self.cwd = Path(self.temporary.name)
        self.script = self.cwd / 'one script.zsh'
        shutil.copy2(RELEASE / 'cp-run.zsh', self.script)
        self.source = self.cwd / 'main.cpp'
        self.source.write_text('int main() {}\n')
        self.compiler = self.cwd / 'compiler fixture'
        self.compiler.write_text('#!' + sys.executable + '\n' + COMPILER)
        self.compiler.chmod(0o755)
        self.log = self.cwd / 'compiler.jsonl'
        self.env = dict(os.environ, CXX=str(self.compiler), SETTINGS_COMPILER_LOG=str(self.log))

    def tearDown(self):
        self.temporary.cleanup()

    def invoke(self, *args, commands=None, script=None):
        return subprocess.run([str(script or self.script), *map(str, args)], cwd=self.cwd,
                              env=self.env, input=commands, capture_output=True,
                              text=True, timeout=15)

    def configure(self, commands):
        result = self.invoke('--set-defaults', commands=commands)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('Traceback', result.stderr)
        return result

    def data(self):
        return settings.read_settings(self.script.read_text())

    def build(self, *args):
        result = self.invoke('compile', *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(self.log.read_text().splitlines()[-1])

    def binary(self, name='runner.out', body='cat\n'):
        path = self.cwd / name
        path.write_text('#!/bin/sh\n' + body)
        path.chmod(0o755)
        return path

    def test_factory_defaults_match_native_block_exactly(self):
        native = settings.read_settings((RELEASE / 'cp-run.zsh').read_text())
        self.assertEqual(native, settings.FACTORY_SETTINGS)
        self.assertEqual(settings.read_settings(settings.settings_text(native)), native)

    def test_menu_cancel_eof_and_declined_save_leave_copy_identical(self):
        original = self.script.read_bytes()
        for commands in ('1\n3\n-O0\ncancel\n', '1\n1\nclang\n',
                         '1\n3\n-O0\nsave\nn\n'):
            self.configure(commands)
            self.assertEqual(self.script.read_bytes(), original)

    def test_saved_standard_and_flags_reach_public_compilation(self):
        result = self.configure('1\n2\n20\n3\n-O0 -g\nsave\ny\n')
        self.assertIn('Review pending changes', result.stdout)
        self.assertIn('-std=c++20', result.stdout)
        argv = self.build()
        self.assertIn('-std=c++20', argv)
        self.assertIn('-O0', argv)
        self.assertIn('-g', argv)
        self.assertNotIn('-O2', argv)

    def test_latest_edit_undo_and_scoped_reset(self):
        original = self.script.read_bytes()
        self.configure('1\n3\n-O0\nundo\nsave\n')
        self.assertEqual(self.script.read_bytes(), original)
        self.configure('1\n2\n20\n3\n-O0\nreset\nsave\ny\n')
        self.assertEqual(self.data()['DEFAULT_STANDARD'], '20')
        self.assertEqual(self.data()['DEFAULT_FLAGS'], ['-O2'])

    def test_save_through_symlink_preserves_link_and_executable_mode(self):
        alias = self.cwd / 'alias'
        alias.symlink_to(self.script)
        result = self.invoke('--set-defaults', commands='1\n2\n23\nsave\ny\n', script=alias)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(alias.is_symlink())
        self.assertEqual(self.data()['DEFAULT_STANDARD'], '23')
        self.assertEqual(self.script.stat().st_mode & 0o777, 0o755)
        self.assertFalse(any(path.name.startswith('.one script.zsh.') for path in self.cwd.iterdir()))

    def test_concurrent_edit_is_rejected_without_overwriting_it(self):
        original = self.script.read_text()
        changed = copy.deepcopy(self.data())
        changed['DEFAULT_SOURCE'] = 'solve.cpp'
        external = original + '\n# concurrent edit\n'
        self.script.write_text(external)
        with self.assertRaisesRegex(ValueError, 'changed while editing'):
            settings.save_settings(self.script, original, changed)
        self.assertEqual(self.script.read_text(), external)

    def test_flag_edits_are_literal_and_keep_repeatable_include_paths(self):
        marker = self.cwd / 'must not exist'
        literal = '-DMSG="$(touch ' + str(marker) + ')"'
        self.configure('1\n3\n-I one -I two\n' + literal + '\nsave\ny\n')
        argv = self.build()
        self.assertIn('-DMSG=$(touch ' + str(marker) + ')', argv)
        self.assertIn('one', argv)
        self.assertIn('two', argv)
        self.assertFalse(marker.exists())

    def test_global_file_defaults_and_auto_mode_are_used_by_bare_f(self):
        self.configure('2\n4\ndata.in\n5\ndata.ans\n6\ndata.out\n8\nauto\nsave\ny\n')
        (self.cwd / 'data.in').write_text('configured input\n')
        result = self.invoke('-f')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / 'data.out').read_text(), 'configured input\n')
        self.assertNotIn('-DFILEO', json.loads(self.log.read_text().splitlines()[-1]))
        self.binary()
        (self.cwd / 'data.ans').write_text('configured input\n')
        result = self.invoke('test', 'run', './runner.out')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_file_macro_is_configurable_without_enabling_redirection(self):
        self.configure('2\n9\nMY_FILEIO\nsave\ny\n')
        self.assertIn('-DMY_FILEIO', self.build('-f'))
        self.assertFalse((self.cwd / 'output.txt').exists())

    def test_saved_bare_f_action_can_return_from_auto_to_macro(self):
        self.configure('2\n8\nauto\nsave\ny\n')
        self.configure('2\n8\nmacro\nsave\ny\n')
        self.assertIn('-DFILEO', self.build('-f'))
        self.assertFalse((self.cwd / 'output.txt').exists())

    def test_global_separator_and_comparison_budget_apply_to_checks(self):
        self.configure('4\n3\n\\n###\\n\n4\n1\nsave\ny\n')
        self.binary()
        (self.cwd / 'input.txt').write_text('one\n###\ntwo\n')
        (self.cwd / 'ans.txt').write_text('one\n###\ntwo\n')
        result = self.invoke('test=auto', 'run', './runner.out')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('PASS', (self.cwd / 'test_out').read_text())
        self.assertEqual(self.data()['DEFAULT_SEPARATOR'], r'\n###\n')

    def test_default_timeout_applies_to_existing_binary(self):
        self.configure('4\n1\n30\nsave\ny\n')
        self.binary(body='sleep 2\n')
        result = self.invoke('run', './runner.out')
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertIn('30 ms', result.stderr)

    def test_stress_seed_can_be_saved_overridden_and_reset(self):
        self.configure('6\n4\n0\nsave\ny\n')
        self.assertEqual(self.data()['DEFAULT_SEED'], '0')
        self.binary('candidate', 'cat\n'); self.binary('brute', 'cat\n'); self.binary('gen', 'echo "$1"\n')
        for flags, expected in (((), '0\n'), (('--seed=8',), '8\n')):
            result = self.invoke('stress', 'run', 'candidate', 'brute', 'gen', '--test-iters=1', *flags)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((self.cwd / 'real-out.txt').read_text(), expected)
        self.configure('6\nreset\nsave\ny\n')
        self.assertEqual(self.data()['DEFAULT_SEED'], '4')

    def test_seed_editor_validates_unsigned_64_bit_range_without_partial_save(self):
        self.configure('6\n4\n18446744073709551615\nsave\ny\n')
        self.assertEqual(self.data()['DEFAULT_SEED'], str(2**64 - 1))
        original = self.script.read_bytes()
        for value in ('-1', str(2**64), '1.5', 'inf', '9' * 5000):
            result = self.configure('6\n4\n' + value + '\ncancel\n')
            self.assertIn('Not changed', result.stdout)
            self.assertEqual(self.script.read_bytes(), original)

    def test_saved_destinations_apply_to_their_routes_and_explicit_dest_wins(self):
        self.configure('2\n3\nflat\n10\ntree\nsave\ny\n')
        for flags, destination in (((), 'flat'), (('--save-relpath',), 'tree'),
                                   (('--save-relpath', '--dest-dir=chosen'), 'chosen')):
            result = self.invoke('compile', *flags)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(Path(result.stdout.strip()), (self.cwd / destination / 'main.out').resolve())

    def test_both_destination_editors_reject_invalid_relative_paths(self):
        original = self.script.read_bytes()
        for field in ('3', '10'):
            for path in ('/absolute', '../outside', 'a/../b'):
                result = self.configure('2\n' + field + '\n' + path + '\ncancel\n')
                self.assertIn('Not changed', result.stdout)
                self.assertEqual(self.script.read_bytes(), original)

    def test_create_guarded_profile_copy_and_remove_it(self):
        self.configure('5\nnew contest debug\nflags\n-O0\nsave\ny\n')
        argv = self.build('--profile=contest')
        self.assertIn('-O0', argv)
        self.assertIn('-D_GLIBCXX_ASSERTIONS', argv)
        result = self.invoke('debug=contest', '--', '-O3')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.configure('5\ndelete contest\nsave\ny\n')
        self.assertNotIn('contest', self.data()['MODE_NAMES'])
        self.assertEqual(self.invoke('debug=contest').returncode, 2)

    def test_flags_profile_is_available_only_through_profile_option(self):
        self.configure('5\nnew release plain\nflags\n-O3\nsave\ny\n')
        self.assertEqual(self.data()['MODE_KIND']['release'], 'flags')
        argv = self.build('--profile=release')
        self.assertIn('-O3', argv)
        previous = self.log.read_bytes()
        result = self.invoke('debug=release')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn('--profile', result.stderr)
        self.assertEqual(self.log.read_bytes(), previous)

    def test_debug_command_checks_kind_even_for_the_default_profile_name(self):
        self.configure('5\ndebug\nkind\nflags\nsave\ny\n')
        self.assertEqual(self.data()['MODE_KIND']['debug'], 'flags')
        for command in ('debug', 'debug=debug', 'debug='):
            result = self.invoke(command)
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertIn('--profile', result.stderr)
        argv = self.build('--profile=debug', '--', '-O3')
        self.assertIn('-O3', argv)

    def test_pragma_profiles_are_flags_with_explicit_cpu_policy(self):
        data = self.data()
        for name in ('pragma', 'pragma-fast', 'pragma-native'):
            self.assertEqual(data['MODE_KIND'][name], 'flags')
            self.assertEqual(data['MODE_CPU'][name], 'native' if name == 'pragma-native' else 'default')
            for key in ('MODE_LIBSTDCXX', 'MODE_LIBCPP', 'MODE_WARNINGS_GCC', 'MODE_WARNINGS_CLANG'):
                self.assertFalse(data[key].get(name, ''))
            result = self.invoke('debug=' + name)
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertIn('--profile', result.stderr)
        self.assertFalse(self.log.exists(), 'debug= must reject plain profiles before compiler discovery')

    def test_copy_edit_reset_and_delete_profile_preserve_cpu_metadata(self):
        self.configure('5\nnew local-fast pragma-native\nsave\ny\n')
        copied = self.data()
        for key in settings.PROFILE_KEYS:
            self.assertEqual(copied[key].get('local-fast', ''), copied[key].get('pragma-native', ''))
        self.configure('5\nlocal-fast\ncpu\ndefault\nsave\ny\n')
        changed = self.data()
        self.assertEqual(changed['MODE_CPU']['local-fast'], 'default')
        self.assertEqual(changed['MODE_CPU']['pragma-native'], 'native')
        self.assertEqual(changed['MODE_FLAGS']['local-fast'], copied['MODE_FLAGS']['local-fast'])
        self.configure('5\npragma-native\ncpu\ndefault\nkind\ndebug\nreset\nsave\n')
        self.assertEqual(self.data(), changed, 'scoped reset restores native factory metadata without touching the copy')
        self.configure('5\ndelete local-fast\nsave\ny\n')
        deleted = self.data()
        self.assertNotIn('local-fast', deleted['MODE_NAMES'])
        for key in settings.PROFILE_KEYS:
            self.assertNotIn('local-fast', deleted[key])

    def test_plain_profile_cpu_default_preview_and_invalid_edit(self):
        result = self.configure('5\nnew baseline plain\npreview\ncpu\nunsupported\n5\nbaseline\ncpu\n\nsave\ny\n')
        self.assertEqual(self.data()['MODE_CPU']['baseline'], 'default')
        self.assertEqual(self.data()['MODE_KIND']['baseline'], 'flags')
        self.assertIn('No standard-library-specific flags', result.stdout)
        self.assertIn('native selection is resolved at build time', result.stdout)
        self.assertIn('Not changed: choose default or native', result.stdout)

    def test_custom_profile_reset_clears_native_policy_and_full_reset_restores_builtins(self):
        self.configure('5\nnew custom pragma-native\nreset\nsave\ny\n')
        custom = self.data()
        self.assertEqual(custom['MODE_CPU']['custom'], 'default')
        self.assertEqual(custom['MODE_KIND']['custom'], 'flags')
        for key in settings.SETTINGS_GROUPS.values():
            self.assertEqual(custom[key]['custom'], '')
        self.configure('5\ndelete pragma-native\nreset\nsave\ny\n')
        self.assertEqual(self.data(), settings.FACTORY_SETTINGS)

    def test_common_warning_edits_preserve_driver_specific_extras(self):
        self.configure('3\n1\nclear\nsave\ny\n')
        data = self.data()
        self.assertNotIn('-Wall', data['WARNINGS_GCC'])
        self.assertNotIn('-Wall', data['WARNINGS_CLANG'])
        self.assertIn('-Wduplicated-cond', data['WARNINGS_GCC'])
        self.assertIn('-Wlogical-op-parentheses', data['WARNINGS_CLANG'])

    def test_invalid_separator_is_not_saved_and_invalid_macro_is_rejected(self):
        original = self.script.read_bytes()
        result = self.configure('4\n3\n\\n$\\n\ncancel\n')
        self.assertIn('Not changed', result.stdout)
        self.assertEqual(self.script.read_bytes(), original)
        result = self.configure('2\n9\nBAD-MACRO\ncancel\n')
        self.assertIn('Not changed', result.stdout)
        self.assertEqual(self.script.read_bytes(), original)

    def test_operation_and_profile_routing_menu_with_explicit_override(self):
        self.configure('10\ncompile\ndest-dir mode-bin\nback\nprofile pragma\ndest-dir profile-bin\nsave-relpath 1\nback\nback\nsave\ny\n')
        data = self.data()
        self.assertEqual(data['ACTION_DEST_DIR']['compile'], 'mode-bin')
        self.assertEqual(data['MODE_DEST_DIR']['pragma'], 'profile-bin')
        first = self.invoke('compile', self.source, '--profile=pragma')
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(Path(first.stdout.strip()), (self.cwd / 'profile-bin/main.out').resolve())
        second = self.invoke('compile', self.source, '--dest-dir=explicit', '--profile=pragma', '--save-relpath=0')
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(Path(second.stdout.strip()), (self.cwd / 'explicit/main.out').resolve())

    def test_language_and_test_layout_menus(self):
        self.configure('8\n1\n1\n' + sys.executable + '\nback\nback\n9\n1\n{stem}/{n}.in\n2\n{stem}/{n}.ans\nback\nsave\ny\n')
        self.assertEqual(self.data()['DEFAULT_INTERPRETER'], sys.executable)
        self.assertEqual(self.data()['DEFAULT_INPUT_TEMPLATE'], '{stem}/{n}.in')
        self.assertEqual(self.data()['DEFAULT_ANSWER_TEMPLATE'], '{stem}/{n}.ans')



if __name__ == '__main__':
    unittest.main()
