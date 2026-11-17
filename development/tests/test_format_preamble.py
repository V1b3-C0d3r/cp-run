"""Persistent preparation must not reuse stale headers or lose active readers."""
import json
import os
from pathlib import Path
import shutil
import unittest
from unittest import mock
import test_school_format as fixtures

engine = fixtures.engine


@unittest.skipUnless(shutil.which('clang'), 'needs Clang')
class PreambleCacheTest(unittest.TestCase):
    def setUp(self):
        self.case = fixtures.SchoolFormatTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)
        self.source = self.case.root / 'main.cpp'
        self.header = self.case.root / 'values.hpp'
        self.header.write_text('#pragma once\nenum { STATUS = 0 };\n')
        self.cache = self.case.root / 'private-cache'
        patch = mock.patch.dict(engine.os.environ, XDG_CACHE_HOME=str(self.cache))
        patch.start()
        self.addCleanup(patch.stop)
        self.clear_memory()
        self.addCleanup(self.clear_memory)
        self.code = '#include "values.hpp"\nint main(void) { return STATUS; }\n'

    def clear_memory(self):
        for entry in engine.SCHOOL_PREAMBLES.values():
            entry['temporary'].cleanup()
        engine.SCHOOL_PREAMBLES.clear()

    def parse(self, code=None):
        code = self.code if code is None else code
        self.source.write_text(code)
        calls = []
        real = engine.school_tool
        def capture(argv, **options):
            calls.append(argv)
            return real(argv, **options)
        with mock.patch.object(engine, 'school_tool', side_effect=capture):
            tree, issues = engine.school_parse(self.source, code, shutil.which('clang'))
        self.assertFalse(issues, issues)
        self.assertIsNotNone(tree)
        return tree, calls

    def records(self):
        return list((self.cache / 'format-cache' / 'preambles').glob('*.json'))

    def test_new_session_reuses_headers_but_parses_edited_body(self):
        self.parse()
        self.assertTrue(self.records())
        self.clear_memory()
        tree, calls = self.parse(self.code.replace('return STATUS', 'return 1'))
        self.assertFalse(any('c++-header' in args for args in calls), calls)
        self.assertTrue(any('-ast-dump=json' in args for args in calls))
        self.assertTrue(any(node.get('kind') == 'IntegerLiteral' and node.get('value') == '1'
                            for node in engine.school_nodes(tree)))

    def test_atomic_editor_save_and_new_binary_do_not_discard_headers(self):
        self.parse()
        self.clear_memory()
        replacement = self.source.with_suffix('.new')
        replacement.write_text(self.code.replace('return STATUS', 'return 1'))
        os.replace(replacement, self.source)
        (self.source.parent / 'program.out').write_bytes(b'new executable')
        _, calls = self.parse(self.source.read_text())
        self.assertFalse(any('c++-header' in args for args in calls), calls)

    def test_file_presence_change_invalidates_prefix_without_including_file(self):
        code = ('#include "values.hpp"\n#if __has_include("feature.hpp")\n'
                '#define STATUS_VALUE 128\n#else\n#define STATUS_VALUE 0\n#endif\n'
                '#include "values.hpp"\nint main(void) { return STATUS_VALUE; }\n')
        self.parse(code)
        self.clear_memory()
        (self.source.parent / 'feature.hpp').write_text('// available now\n')
        tree, calls = self.parse(code)
        self.assertTrue(any('c++-header' in args for args in calls))
        self.assertTrue(any(node.get('kind') == 'IntegerLiteral' and node.get('value') == '128'
                            for node in engine.school_nodes(tree)))

    def test_builtin_presence_signature_does_not_disable_cache(self):
        self.header.write_text('#pragma once\n#ifndef __has_include\n#define __has_include(x) 0\n#endif\n'
                               '// __has_include(HEADER) is documented here.\nenum { STATUS = 0 };\n')
        self.parse()
        self.assertTrue(self.records())
        self.clear_memory()
        _, calls = self.parse()
        self.assertFalse(any('c++-header' in args for args in calls))

    def test_header_edit_invalidates_persistent_preparation(self):
        self.parse()
        self.clear_memory()
        self.header.write_text('#pragma once\nenum { STATUS = 128 };\n')
        tree, calls = self.parse()
        self.assertTrue(any('c++-header' in args for args in calls))
        self.assertIn(128, tree['school_external_values'].values())

    def test_new_earlier_search_root_header_invalidates_disk_preamble(self):
        import tempfile
        with tempfile.TemporaryDirectory(prefix='cp-shadow-pch-') as directory:
            first, fallback = Path(directory) / 'first', Path(directory) / 'fallback'
            first.mkdir()
            fallback.mkdir()
            (fallback / 'remote.hpp').write_text('enum { STATUS = 0 };\n')
            code = '#include <remote.hpp>\nint main(void) { return STATUS; }\n'
            with mock.patch.dict(engine.os.environ, CPATH=str(first) + os.pathsep + str(fallback)):
                self.parse(code)
                self.clear_memory()
                self.parse(code)
                self.clear_memory()
                (first / 'remote.hpp').write_text('enum { STATUS = 128 };\n')
                tree, calls = self.parse(code)
            self.assertTrue(any('c++-header' in args for args in calls))
            self.assertIn(128, tree['school_external_values'].values())

    def test_failed_first_header_reports_lines_without_dumping_a_partial_ast(self):
        (self.source.parent / 'bad.hpp').write_text('#error unsupported header\n')
        code = '#include "bad.hpp"\nint main(void) { return 0; }\n'
        real = engine.school_tool
        calls = []
        def capture(argv, **options):
            calls.append(argv)
            return real(argv, **options)
        with mock.patch.object(engine, 'school_tool', side_effect=capture):
            tree, issues = engine.school_parse(self.source, code, shutil.which('clang'))
        self.assertIsNone(tree)
        self.assertTrue(issues[0].split('school parser error:', 1)[1].startswith('\n'))
        self.assertFalse(any('-ast-dump=json' in args for args in calls))

    def test_bad_later_header_keeps_a_small_partial_preamble_and_revalidates_it(self):
        (self.source.parent / 'bad.hpp').write_text('#error unsupported header\n')
        code = '#include "values.hpp"\n#include "bad.hpp"\nint main(void) { return STATUS; }\n'
        real = engine.school_tool
        dumps = []
        def capture(argv, **options):
            result = real(argv, **options)
            if '-ast-dump=json' in argv:
                dumps.append((argv, len(result.stdout)))
            return result
        self.source.write_text(code)
        with mock.patch.object(engine, 'school_tool', side_effect=capture):
            tree, issues = engine.school_parse(self.source, code, shutil.which('clang'))
        self.assertIsNone(tree)
        self.assertIn('unsupported header', '\n'.join(issues))
        self.assertTrue(dumps)
        self.assertTrue(all('-include-pch' in args and size < 1_000_000 for args, size in dumps))
        entry = next(iter(engine.SCHOOL_PREAMBLES.values()))
        self.assertEqual(entry['prefix'], '#include "values.hpp"\n')
        self.clear_memory()
        (self.source.parent / 'bad.hpp').write_text('#pragma once\n')
        _, calls = self.parse(code)
        self.assertTrue(any('c++-header' in args for args in calls))
        self.assertEqual(next(iter(engine.SCHOOL_PREAMBLES.values()))['prefix'],
                         '#include "values.hpp"\n#include "bad.hpp"\n')

    def test_corrupt_blob_or_manifest_rebuilds_instead_of_skipping_checks(self):
        for damage in ('blob', 'index'):
            with self.subTest(damage=damage):
                self.parse()
                index = self.records()[0]
                record = json.loads(index.read_text())
                self.clear_memory()
                if damage == 'blob':
                    (index.parent / record['blob']).write_bytes(b'not a PCH')
                else:
                    index.write_text('[]')
                _, calls = self.parse()
                self.assertTrue(any('c++-header' in args for args in calls))

    def test_symlink_artifact_is_rejected_without_modifying_its_target(self):
        self.parse()
        index = self.records()[0]
        record = json.loads(index.read_text())
        blob = index.parent / record['blob']
        unrelated = self.case.root / 'unrelated.pch'
        contents = blob.read_bytes()
        unrelated.write_bytes(contents)
        self.clear_memory()
        blob.unlink()
        blob.symlink_to(unrelated)
        _, calls = self.parse()
        self.assertTrue(any('c++-header' in args for args in calls))
        self.assertEqual(unrelated.read_bytes(), contents)

    def test_eviction_keeps_an_active_readers_private_artifact(self):
        self.parse()
        self.clear_memory()
        self.parse()
        entry = next(iter(engine.SCHOOL_PREAMBLES.values()))
        root = self.records()[0].parent
        with mock.patch.object(engine, 'SCHOOL_PREAMBLE_CACHE_ENTRIES', 0):
            engine.school_preamble_cache_prune(root)
        self.assertFalse(self.records())
        self.assertTrue(Path(entry['pch']).is_file())
        _, calls = self.parse()
        self.assertFalse(any('c++-header' in args for args in calls))

    def test_busy_publisher_never_blocks_formatting(self):
        root = engine.school_preamble_cache_root(self.source)
        with open(root / '.lock', 'w') as lock:
            engine.fcntl.flock(lock, engine.fcntl.LOCK_EX | engine.fcntl.LOCK_NB)
            self.parse()
        self.assertFalse(self.records())

    def test_entry_count_and_bytes_are_bounded(self):
        with mock.patch.object(engine, 'SCHOOL_PREAMBLE_CACHE_ENTRIES', 2), \
             mock.patch.object(engine, 'SCHOOL_PREAMBLE_CACHE_BYTES', 16 * 1024 * 1024):
            for value in range(4):
                self.parse('#define SETTING ' + str(value) + '\n' + self.code)
        records = self.records()
        self.assertEqual(len(records), 2)
        root = records[0].parent
        self.assertLessEqual(sum(path.stat().st_size for path in root.glob('pch-*.pch')), 16 * 1024 * 1024)
        budget = max(path.stat().st_size for path in root.glob('pch-*.pch')) + 4096
        with mock.patch.object(engine, 'SCHOOL_PREAMBLE_CACHE_ENTRIES', 8), \
             mock.patch.object(engine, 'SCHOOL_PREAMBLE_CACHE_BYTES', budget):
            self.parse('#define SETTING 5\n' + self.code)
        self.assertEqual(len(self.records()), 1)
        self.assertLessEqual(sum(path.stat().st_size for path in root.glob('pch-*.pch')), budget)

    def test_group_writable_cache_is_not_trusted(self):
        self.parse()
        root = self.records()[0].parent
        root.chmod(0o777)
        self.clear_memory()
        _, calls = self.parse()
        self.assertTrue(any('c++-header' in args for args in calls))

    def test_clock_dependent_header_disables_precompiled_and_result_reuse(self):
        self.header.write_text('#pragma once\n#define NOW __TIME__\nenum { STATUS = 0 };\n')
        tree, _ = self.parse()
        self.assertIsNotNone(tree)
        self.assertFalse(self.records())
        self.assertFalse(engine.SCHOOL_PREAMBLES)
        engine.format_cache_store(self.source.resolve(), self.code, [], [str(self.header)], [], {})
        self.assertFalse(list((self.cache / 'format-cache').glob('school-*.json')))
