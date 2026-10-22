"""Fixed task-folder contract: CLI defaults, paired transactions and migration."""

from pathlib import Path
import os
import unittest
from unittest import mock

from _paths import load_engine
import test_languages as fixtures

engine = load_engine('cp_run_test_folder_tests')


class TestFolderCliTest(unittest.TestCase):
    setUp = fixtures.LanguagesTest.setUp
    tearDown = fixtures.LanguagesTest.tearDown
    invoke = fixtures.LanguagesTest.invoke

    def folder(self, name='tests', records=((b'2 3\n', b'5\n'), (b'7 8\n\n', b'15'))):
        root = self.cwd / name
        root.mkdir()
        for number, (input_data, answer) in enumerate(records, 1):
            (root / ('in%d.txt' % number)).write_bytes(input_data)
            (root / ('ans%d.txt' % number)).write_bytes(answer)
        return root

    def bundles(self, left=(b'2 3\n',), right=(b'5\n',)):
        for name, records in (('in.txt', left), ('ans.txt', right)):
            (self.cwd / name).write_bytes(engine.encode_bundle(list(records), b'\n\x1e\n'))

    def test_bare_pack_and_unpack_use_saved_file_defaults(self):
        root = self.folder()
        packed = self.invoke('pack')
        self.assertEqual((packed.returncode, packed.stdout), (0, ''), packed.stderr)
        restored = self.invoke('unpack', '--test-f', 'restored')
        self.assertEqual(restored.returncode, 0, restored.stderr)
        self.assertEqual({p.name: p.read_bytes() for p in root.iterdir()},
                         {p.name: p.read_bytes() for p in (self.cwd / 'restored').iterdir()})

    def test_one_operand_replaces_input_only_and_two_replace_both(self):
        self.folder()
        for files in (('custom.in',), ('other.in', 'other.ans')):
            with self.subTest(files=files):
                result = self.invoke('pack', *files, '--overwrite')
                self.assertEqual(result.returncode, 0, result.stderr)
                target = 'copy-' + str(len(files))
                result = self.invoke('unpack', *files, '--test-f=' + target)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((self.cwd / target / 'ans2.txt').read_bytes(), b'15')

    def test_single_stream_selector_uses_its_saved_default(self):
        root = self.folder()
        (root / 'in1.txt').unlink(); (root / 'in2.txt').unlink()
        result = self.invoke('pack=ans')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.cwd / 'in.txt').exists())
        result = self.invoke('unpack=ans', '--test-f=answers')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sorted(p.name for p in (self.cwd / 'answers').iterdir()), ['ans1.txt', 'ans2.txt'])

    def test_saved_bundle_filenames_support_workspace_paths(self):
        self.folder('samples')
        source = Path(self.script).read_text()
        values = engine.read_settings(source)
        values.update(DEFAULT_TEST_FOLDER='{wsp-dir}/samples', DEFAULT_WORKSPACE='..',
                      DEFAULT_INPUT='{wsp-dir}/bundles/inputs', DEFAULT_ANSWER='{wsp-dir}/bundles/answers')
        engine.save_settings(Path(self.script), source, values)
        workspace = self.cwd
        self.cwd = workspace / 'nested'; self.cwd.mkdir()
        result = self.invoke('pack')
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.invoke('unpack', '--test-f={wsp-dir}/copy')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((workspace / 'copy/in2.txt').read_bytes(), b'7 8\n\n')
        self.assertEqual((workspace / 'copy/ans1.txt').read_bytes(), b'5\n')

    def test_required_folder_and_removed_templates_fail_before_writes(self):
        self.bundles()
        for flags in (('--test-f',), ('--test-f=',), ('--source=x.cpp',),
                      ('--in-tmp=x{n}',), ('--ans-tmp=x{n}',), ('--test-dir=old',),
                      ('--save-test-relpath',), ('--text',), ('--text-sep=x',)):
            with self.subTest(flags=flags):
                result = self.invoke('unpack', *flags)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertFalse((self.cwd / 'tests').exists())

    def test_unmatched_pack_ids_do_not_write_either_bundle(self):
        root = self.folder()
        (root / 'ans2.txt').unlink()
        result = self.invoke('pack')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse((self.cwd / 'in.txt').exists())
        self.assertFalse((self.cwd / 'ans.txt').exists())

    def test_bad_second_bundle_does_not_write_first_stream(self):
        self.bundles(right=(b'5', b'6'))
        result = self.invoke('unpack')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse((self.cwd / 'tests').exists())
        (self.cwd / 'ans.txt').write_bytes(b'bad header\n')
        result = self.invoke('unpack')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse((self.cwd / 'tests').exists())

    def test_pack_second_target_conflict_leaves_first_intact(self):
        self.folder()
        (self.cwd / 'ans.txt').write_bytes(b'keep')
        result = self.invoke('pack')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse((self.cwd / 'in.txt').exists())
        self.assertEqual((self.cwd / 'ans.txt').read_bytes(), b'keep')

    def test_unpack_existing_second_stream_conflict_is_transactional(self):
        self.bundles()
        root = self.cwd / 'tests'; root.mkdir()
        (root / 'ans1.txt').write_bytes(b'keep')
        result = self.invoke('unpack')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse((root / 'in1.txt').exists())
        self.assertEqual((root / 'ans1.txt').read_bytes(), b'keep')
        result = self.invoke('unpack', '--overwrite')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((root / 'ans1.txt').read_bytes(), b'5\n')

    def test_unpack_rejects_stale_cases_even_with_overwrite(self):
        self.bundles()
        root = self.folder()
        result = self.invoke('unpack', '--overwrite')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn('extra tests', result.stderr)
        self.assertEqual((root / 'in2.txt').read_bytes(), b'7 8\n\n')

    def test_two_bundle_targets_cannot_alias_each_other_or_cases(self):
        root = self.folder()
        for files in (('same', 'same'), ('tests/in1.txt', 'answers')):
            result = self.invoke('pack', *files, '--overwrite')
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertEqual((root / 'in1.txt').read_bytes(), b'2 3\n')

    def test_saved_workspace_folder_is_independent_from_artifacts(self):
        self.folder('samples')
        source = Path(self.script).read_text()
        values = engine.read_settings(source)
        values.update(DEFAULT_TEST_FOLDER='{wsp-dir}/samples', DEFAULT_WORKSPACE='..')
        engine.save_settings(Path(self.script), source, values)
        self.cwd = self.cwd / 'nested'; self.cwd.mkdir()
        result = self.invoke('pack', '--dest-dir=../unused')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / 'in.txt').read_bytes().split(b'\n', 1)[0], b'2')
        result = self.invoke('unpack', '--test-f={wsp-dir}/restored')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.cwd.parent / 'restored/in2.txt').is_file())

    def test_literal_workspace_root_is_a_valid_folder(self):
        self.bundles()
        result = self.invoke('unpack', '--test-f={wsp-dir}')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.cwd / 'in1.txt').is_file())

    def test_symlinks_and_hardlinks_never_overwrite_source_cases(self):
        root = self.folder()
        (self.cwd / 'linked').symlink_to(root / 'in1.txt')
        os.link(root / 'in1.txt', self.cwd / 'hardlink')
        for target in ('linked', 'hardlink'):
            result = self.invoke('pack=in', target, '--overwrite')
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertEqual((root / 'in1.txt').read_bytes(), b'2 3\n')

    def test_invalid_selector_and_extra_bundle_operands_are_rejected(self):
        for args in (('pack=',), ('pack=both',), ('unpack=bad',), ('pack=in', 'a', 'b'),
                     ('pack', 'a', 'b', 'c')):
            result = self.invoke(*args)
            self.assertEqual(result.returncode, 2, result.stderr)


class FolderPreferencesTest(unittest.TestCase):
    def test_counted_reader_refuses_fifo_without_opening_it(self):
        import tempfile
        with tempfile.TemporaryDirectory() as directory:
            fifo = Path(directory) / 'pipe'
            os.mkfifo(fifo)
            with mock.patch('builtins.open', side_effect=AssertionError('must not open FIFO')):
                with self.assertRaises(engine.CheckSetupError):
                    engine.counted_cases(fifo, b'\n\x1e\n')

    def test_old_settings_migrate_folder_and_discard_filename_templates(self):
        values = engine.validate_preferences({'DEFAULT_TEST_DIR': 'samples',
            'DEFAULT_INPUT_TEMPLATE': '{stem}/{n}.in', 'DEFAULT_ANSWER_TEMPLATE': '{n}.ans',
            'ACTION_SAVE_TEST_RELPATH': {'test-mult': '1'}, 'MODE_SAVE_TEST_RELPATH': {},
            'MANUAL_SEPARATOR': r'\n###\n'})
        self.assertEqual(values['DEFAULT_TEST_FOLDER'], '{wsp-dir}/samples')
        self.assertNotIn('DEFAULT_INPUT_TEMPLATE', values)
        self.assertNotIn('ACTION_SAVE_TEST_RELPATH', values)

    def test_invalid_legacy_folder_is_a_usage_error(self):
        for value in (1, [], {}):
            with self.assertRaisesRegex(ValueError, 'legacy test folder'):
                engine.validate_preferences({'DEFAULT_TEST_DIR': value})

    def test_folder_accepts_paths_but_no_per_case_placeholders(self):
        for folder in ('{wsp-dir}', '{wsp-dir}/tasks/A', 'tests/A', '/tmp/tests'):
            self.assertEqual(engine.validate_preferences({'DEFAULT_TEST_FOLDER': folder})['DEFAULT_TEST_FOLDER'], folder)
        for folder in ('', '{wsp-dir}/../escape', '{stem}/{n}', 'x/{wsp-dir}/tests'):
            with self.assertRaises((ValueError, engine.CheckUsageError)):
                engine.validate_preferences({'DEFAULT_TEST_FOLDER': folder})
