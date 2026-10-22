"""Workspace-rooted preferences and fixed test folders across all file consumers."""

import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from _paths import RELEASE, load_engine
import test_settings

engine = load_engine('cp_run_workspace_paths')


class WorkspacePathsTest(unittest.TestCase):
    setUp = test_settings.SettingsTest.setUp
    tearDown = test_settings.SettingsTest.tearDown
    invoke = test_settings.SettingsTest.invoke
    configure = test_settings.SettingsTest.configure
    data = test_settings.SettingsTest.data
    build = test_settings.SettingsTest.build

    def save(self, **values):
        original = self.script.read_text()
        data = engine.read_settings(original)
        data.update(values)
        engine.save_settings(self.script, original, data)

    def nested(self):
        workspace = self.cwd
        self.cwd = workspace / 'nested dir'
        self.cwd.mkdir()
        return workspace

    def test_source_and_single_test_files_from_workspace_defaults(self):
        workspace = self.cwd
        (workspace / 'data').mkdir()
        (workspace / 'reports').mkdir()
        (workspace / 'data/in.txt').write_text('root input\n')
        (workspace / 'data/answer.txt').write_text('root input\n')
        self.save(DEFAULT_WORKSPACE='..', DEFAULT_SOURCE='{wsp-dir}/main.cpp',
                  DEFAULT_INPUT='{wsp-dir}/data/in.txt', DEFAULT_ANSWER='{wsp-dir}/data/answer.txt',
                  DEFAULT_OUTPUT='{wsp-dir}/data/chosen.txt',
                  DEFAULT_REPORT='{wsp-dir}/reports/test.txt')
        self.nested()
        result = self.invoke('test')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('FINAL VERDICT: AC', (workspace / 'reports/test.txt').read_text())
        self.assertEqual((workspace / 'data/chosen.txt').read_text(), 'root input\n')
        self.assertFalse((self.cwd / 'out.txt').exists())
        self.assertFalse((self.cwd / 'test_out').exists())

    def test_redirection_and_explicit_cli_paths(self):
        workspace = self.cwd
        (workspace / 'data').mkdir()
        (workspace / 'data/in.txt').write_text('copied\n')
        self.save(DEFAULT_WORKSPACE='..', DEFAULT_SOURCE='{wsp-dir}/main.cpp', DEFAULT_F_MODE='auto',
                  DEFAULT_INPUT='{wsp-dir}/data/in.txt', DEFAULT_OUTPUT='{wsp-dir}/data/out.txt')
        self.nested()
        result = self.invoke('-f')
        self.assertEqual((result.returncode, result.stdout), (0, ''), result.stderr)
        self.assertEqual((workspace / 'data/out.txt').read_text(), 'copied\n')
        result = self.invoke('{wsp-dir}/main.cpp', '-f', '{wsp-dir}/data/in.txt',
                             '{wsp-dir}/data/explicit.txt', '-o', '{wsp-dir}/program.out')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((workspace / 'data/explicit.txt').read_text(), 'copied\n')
        self.assertTrue((workspace / 'program.out').is_file())

    def test_exact_output_bypasses_invalid_destination_but_resolves_input_workspace(self):
        self.save(DEFAULT_F_MODE='auto')
        (self.cwd / 'in.txt').write_text('safe\n')
        result = self.invoke(self.source, '-o', 'explicit.out', '--dest-dir=../unused',
                             '-f', '{wsp-dir}/in.txt', '--cout')
        self.assertEqual((result.returncode, result.stdout), (0, 'safe\n'), result.stderr)

    def test_workspace_name_search_and_quoted_root_paths(self):
        workspace = self.nested()
        result = self.invoke('compile', '{wsp-dir}/main.cpp', '--wsp-name', workspace.name,
                             '-o', '{wsp-dir}/named output.out')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((workspace / 'named output.out').is_file())

    def test_rooted_mult_and_default_bundle_files_through_cli(self):
        workspace = self.cwd
        (workspace / 'data').mkdir()
        (workspace / 'cases/main').mkdir(parents=True)
        (workspace / 'cases/main/in1.txt').write_text('case one\n')
        (workspace / 'cases/main/ans1.txt').write_text('case one\n')
        self.save(DEFAULT_WORKSPACE='..', DEFAULT_SOURCE='{wsp-dir}/main.cpp',
                  DEFAULT_INPUT='{wsp-dir}/data/in.txt',
                  DEFAULT_TEST_FOLDER='{wsp-dir}/cases/main')
        self.nested()
        result = self.invoke('test=mult', '--cout')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Test 1: AC', result.stdout)
        result = self.invoke('pack=in')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((workspace / 'data/in.txt').read_bytes(), b'1\ncase one\n')

    def test_unused_anchored_defaults_do_not_force_workspace_lookup(self):
        self.save(DEFAULT_SOURCE='{wsp-dir}/missing.cpp', DEFAULT_INPUT='{wsp-dir}/missing.in',
                  DEFAULT_ANSWER='{wsp-dir}/missing.ans', DEFAULT_WORKSPACE='/missing/workspace')
        result = self.invoke('compile', self.source, '-o', 'direct.out')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_cpp_c_python_fallbacks_and_stress_roles_are_saved_as_paths(self):
        for key, value in [('DEFAULT_SOURCE', '{wsp-dir}/src/main.cpp'),
                           ('C_SOURCE', '{wsp-dir}/src/main.c'),
                           ('PYTHON_SOURCE', '{wsp-dir}/src/main.py'),
                           ('DEFAULT_BRUTE', '{wsp-dir}/src/brute.py'),
                           ('DEFAULT_GENERATOR', '{wsp-dir}/src/gen.py')]:
            self.save(**{key: value})
            self.assertEqual(self.data()[key], value)
        for language, name in [('c++', 'main.cpp'), ('c', 'main.c'), ('python', 'main.py')]:
            workspace = self.cwd
            (workspace / 'src').mkdir(exist_ok=True)
            path = workspace / 'src' / name
            path.write_text('print("Python")\n' if language == 'python' else 'int main(){}\n')
            self.save(DEFAULT_WORKSPACE='..', DEFAULT_LANGUAGE=language, DEFAULT_INTERPRETER=sys.executable)
            self.nested()
            result = self.invoke('compile')
            self.assertEqual(result.returncode, 0, result.stderr)
            if language == 'python': self.assertEqual(result.stdout, str(path.resolve()) + '\n')
            self.cwd = workspace
            shutil.rmtree(workspace / 'nested dir')

    def test_mixed_language_stress_uses_rooted_reference_and_generator_defaults(self):
        workspace = self.cwd
        (workspace / 'programs').mkdir()
        for name in ('main.py', 'brute.py'):
            (workspace / 'programs' / name).write_text('import sys; print(sys.stdin.read(), end="")\n')
        (workspace / 'programs/gen.py').write_text('import sys; print(sys.argv[1])\n')
        self.save(DEFAULT_WORKSPACE='..', DEFAULT_LANGUAGE='python',
                  PYTHON_SOURCE='{wsp-dir}/programs/main.py', DEFAULT_BRUTE='{wsp-dir}/programs/brute.py',
                  DEFAULT_GENERATOR='{wsp-dir}/programs/gen.py', DEFAULT_INTERPRETER=sys.executable,
                  DEFAULT_REPORT='{wsp-dir}/report.txt', DEFAULT_OUTPUT='{wsp-dir}/stress-result.txt')
        self.nested()
        result = self.invoke('stress', '--test-iters=1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('FINAL VERDICT: AC', (workspace / 'report.txt').read_text())
        self.assertEqual((workspace / 'stress-result.txt').read_text(), '4\n')
        self.assertFalse((self.cwd / 'out.txt').exists())

    def test_menu_and_export_roundtrip_accept_workspace_paths(self):
        result = self.configure('2\n1\n{wsp-dir}/src/main.cpp\n4\n{wsp-dir}/data/in.txt\n'
                                '5\n{wsp-dir}/data/ans.txt\n6\n{wsp-dir}/data/out.txt\n'
                                '7\n{wsp-dir}/logs/report.txt\nback\nsave\ny\n')
        self.assertEqual(self.data()['DEFAULT_SOURCE'], '{wsp-dir}/src/main.cpp')
        export = self.cwd / 'export.json'
        self.assertEqual(self.invoke('--export-settings', export).returncode, 0)
        original = self.data()
        self.assertEqual(self.invoke('--import-settings', export).returncode, 0)
        self.assertEqual(self.data(), original)

    def test_anchored_symlink_and_parent_escape_are_rejected(self):
        outside = self.cwd.parent
        (self.cwd / 'link').symlink_to(outside, target_is_directory=True)
        for filename in ('{wsp-dir}/../escape.out', '{wsp-dir}/link/escape.out',
                         'prefix{wsp-dir}/x', '{wsp-dir}//absolute.out'):
            result = self.invoke('compile', self.source, '-o', filename)
            self.assertEqual(result.returncode, 2, (filename, result.stderr))
        for key in ('DEFAULT_SOURCE', 'DEFAULT_INPUT', 'DEFAULT_OUTPUT', 'DEFAULT_ANSWER', 'DEFAULT_REPORT'):
            values = copy.deepcopy(engine.FACTORY_SETTINGS)
            values[key] = '{wsp-dir}/../outside.cpp'
            with self.assertRaises(engine.CheckUsageError): engine.validate_preferences(values)


class WorkspaceTestFolderTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cp-run-test-folder-')
        self.root = Path(self.temporary.name).resolve()
        self.config = {'workspace': str(self.root), 'test_folder': '{wsp-dir}/samples',
                       'destination': 'unused', 'source_anchor': str(self.root / 'src/sum.cpp')}

    def tearDown(self):
        self.temporary.cleanup()

    def payload(self):
        return json.dumps({'tests': [{'input': '2 3\n', 'output': '5\n'},
                                     {'input': '7 8\n', 'output': '15\n'}]}).encode()

    def test_companion_and_mult_share_fixed_folder(self):
        count, root = engine.import_companion(self.config, self.payload())
        self.assertEqual((count, root), (2, self.root / 'samples'))
        self.assertEqual((root / 'in1.txt').read_bytes(), b'2 3\n')
        ids, inputs, answers = engine.mult_cases(self.config)
        self.assertEqual(ids, [1, 2])
        self.assertEqual(engine.slice_bytes(answers[1]), b'15\n')
        self.assertFalse((self.root / 'unused').exists())

    def test_explicit_workspace_root_is_a_valid_folder(self):
        config = dict(self.config, test_folder='{wsp-dir}')
        engine.import_companion(config, self.payload())
        self.assertEqual(engine.mult_cases(config)[0], [1, 2])
        self.assertTrue((self.root / 'in1.txt').is_file())

    def test_pack_and_unpack_share_fixed_folder(self):
        engine.import_companion(self.config, self.payload())
        bundle = self.root / 'input.bundle'
        config = dict(self.config, operation='pack', bundle_stream='in', default_input=str(bundle))
        engine.execute_bundle(config)
        records = engine.counted_cases(bundle, b'\n\x1e\n')
        self.assertEqual([engine.slice_bytes(c) for c in records], [b'2 3\n', b'7 8\n'])
        config.update(operation='unpack', test_folder='{wsp-dir}/restored')
        engine.execute_bundle(config)
        self.assertEqual((self.root / 'restored/in2.txt').read_bytes(), b'7 8\n')

    def test_folder_anchor_is_strict_and_retains_write_protection(self):
        for folder in ('{wsp-dir}/../cases', 'x/{wsp-dir}/cases', '{wsp-dir}//tmp'):
            with self.assertRaises(engine.CheckUsageError):
                engine.import_companion(dict(self.config, test_folder=folder), self.payload())
        (self.root / 'samples').symlink_to(self.root.parent, target_is_directory=True)
        with self.assertRaises(engine.CheckUsageError):
            engine.import_companion(self.config, self.payload())


if __name__ == '__main__':
    unittest.main()
