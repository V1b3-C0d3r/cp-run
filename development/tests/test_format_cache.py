"""Cached findings remain valid only for identical code/tools/dependencies."""
import json
from pathlib import Path
import shutil
import shlex
import unittest
import tempfile
from unittest import mock
import test_school_format as fixtures

engine = fixtures.engine


@unittest.skipUnless(shutil.which('clang') and shutil.which('clang-format'), 'needs school tools')
class FormatCacheTest(unittest.TestCase):
    def setUp(self):
        self.case = fixtures.SchoolFormatTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)
        self.source = self.case.source
        self.source.write_text('int\nmain(void) {\n    return 0;\n}\n')
        self.cache = self.case.root / 'cache'
        self.environ = mock.patch.dict(engine.os.environ, XDG_CACHE_HOME=str(self.cache))
        self.environ.start()
        self.addCleanup(self.environ.stop)
        self.config = dict(format_mode='school', protected=[str(self.source)], prettier='format')

    def collect_calls(self, **changes):
        calls = []
        original = engine.school_tool
        def capture(argv, **kwargs):
            calls.append(argv)
            return original(argv, **kwargs)
        with mock.patch.object(engine, 'school_tool', side_effect=capture):
            result = engine.format_collect(dict(self.config, **changes))
        return result, calls

    def test_parser_failure_is_cached_as_an_error_with_dependency_invalidation(self):
        header = self.case.root / 'values.h'
        header.write_text('#pragma once\nenum { STATUS = 0 };\n')
        self.source.write_text('#include "values.h"\nint\nmain(void) {\n    return STATUS;\n}\n')
        def failed_parse(*args, **options):
            return None, engine.SchoolParseIssues(['unsupported frontend construct'], [str(header)])
        with mock.patch.object(engine, 'school_parse', side_effect=failed_parse) as parse:
            first, _ = self.collect_calls()
            self.assertTrue(any(item.rule == 'frontend' for item in first.errors))
            repeated, calls = self.collect_calls()
            self.assertEqual(parse.call_count, 1)
            self.assertFalse(any('-c' in argv for argv in calls), calls)
            self.assertTrue(any(item.rule == 'frontend' for item in repeated.errors))
            header.write_text('#pragma once\nenum { STATUS = 128 };\n')
            self.collect_calls()
            self.assertEqual(parse.call_count, 2)

    def test_prepared_cpp_lookup_reuses_graph_and_still_tracks_header_changes(self):
        self.source = self.source.with_suffix('.cpp')
        self.config['protected'] = [str(self.source)]
        header = self.source.parent / 'values.hpp'
        header.write_text('#pragma once\nenum { STATUS = 0 };\n')
        self.source.write_text('#include "values.hpp"\nint\nmain(void) {\n    return STATUS;\n}\n')
        with mock.patch.object(engine, 'format_include_candidates', wraps=engine.format_include_candidates) as lookup:
            self.collect_calls()
        self.assertTrue(any(call.kwargs.get('owners') is not None for call in lookup.call_args_list))
        _, warm = self.collect_calls()
        self.assertFalse(any('-ast-dump=json' in args for args in warm))
        header.write_text('#pragma once\nenum { STATUS = 128 };\n')
        result, fresh = self.collect_calls()
        self.assertTrue(any('-ast-dump=json' in args for args in fresh))
        self.assertTrue(any(item.rule == '5.7' for item in result.errors), result.findings)

    def test_body_file_presence_uses_full_graph_after_prepared_includes(self):
        self.source = self.source.with_suffix('.cpp')
        self.config['protected'] = [str(self.source)]
        (self.source.parent / 'values.hpp').write_text('#pragma once\n')
        self.source.write_text('#include "values.hpp"\n#if __has_include("feature.hpp")\n'
                               '#define STATUS 37\n#else\n#define STATUS 0\n#endif\n'
                               'int\nmain(void) {\n    return STATUS;\n}\n')
        with mock.patch.object(engine, 'format_include_candidates', wraps=engine.format_include_candidates) as lookup:
            self.collect_calls()
        self.assertTrue(all(call.kwargs.get('owners') is None for call in lookup.call_args_list))
        _, warm = self.collect_calls()
        self.assertFalse(any('-ast-dump=json' in args for args in warm))
        (self.source.parent / 'feature.hpp').write_text('// feature is available\n')
        _, fresh = self.collect_calls()
        self.assertTrue(any('-ast-dump=json' in args for args in fresh))

    def test_unchanged_second_pass_does_not_repeat_frontend_or_compile(self):
        first, initial = self.collect_calls()
        second, repeated = self.collect_calls()
        self.assertFalse(first.errors)
        self.assertFalse(second.errors)
        self.assertTrue(any('-ast-dump=json' in args for args in initial))
        self.assertFalse(any('-ast-dump=json' in args or '-c' in args for args in repeated), repeated)

    def test_source_change_and_explicit_no_cache_force_fresh_checks(self):
        self.collect_calls()
        self.source.write_text(self.source.read_text().replace('return 0;', 'return 37;'))
        result, calls = self.collect_calls()
        self.assertTrue(any(item.rule == '5.1' for item in result.errors))
        self.assertTrue(any('-ast-dump=json' in args for args in calls))
        _, calls = self.collect_calls(format_cache=False)
        self.assertTrue(any('-ast-dump=json' in args for args in calls))

    def test_external_angle_header_shadow_invalidates_cached_result(self):
        with tempfile.TemporaryDirectory(prefix='cp-external-includes-') as temporary:
            external = Path(temporary)
            first, fallback = external / 'first', external / 'fallback'
            first.mkdir()
            fallback.mkdir()
            (first / 'values.h').write_text('#pragma once\n#include <status.h>\n')
            (fallback / 'status.h').write_text('#pragma once\nenum { STATUS = 0 };\n')
            self.source.write_text('#include <values.h>\nint\nmain(void) {\n    return STATUS;\n}\n')
            with mock.patch.dict(engine.os.environ, CPATH=str(first) + engine.os.pathsep + str(fallback)):
                self.collect_calls()
                _, warm = self.collect_calls()
                self.assertFalse(any('-ast-dump=json' in argv for argv in warm))
                (first / 'status.h').write_text('#pragma once\nenum { STATUS = 128 };\n')
                result, fresh = self.collect_calls()
            self.assertTrue(any('-ast-dump=json' in argv for argv in fresh))
            self.assertTrue(any(item.rule == '5.7' for item in result.errors), result.findings)

    def test_new_earlier_search_root_header_invalidates_literal_and_macro_results(self):
        for form in ('#include <remote.h>\n', '#define HEADER "remote.h"\n#include HEADER\n'):
            with self.subTest(form=form), tempfile.TemporaryDirectory(prefix='cp-shadow-roots-') as directory:
                first, fallback = Path(directory) / 'first', Path(directory) / 'fallback'
                first.mkdir()
                fallback.mkdir()
                (fallback / 'remote.h').write_text('enum { STATUS = 0 };\n')
                self.source.write_text(form + 'int\nmain(void) {\n    return STATUS;\n}\n')
                with mock.patch.dict(engine.os.environ, CPATH=str(first) + engine.os.pathsep + str(fallback)):
                    self.collect_calls()
                    _, warm = self.collect_calls()
                    self.assertFalse(any('-c' in args for args in warm))
                    (first / 'remote.h').write_text('enum { STATUS = 128 };\n')
                    result, fresh = self.collect_calls()
                self.assertTrue(any('-c' in args for args in fresh))
                self.assertTrue(any(item.rule == '5.7' for item in result.errors), result.findings)

    def test_header_edit_after_analysis_cannot_bless_stale_findings(self):
        header = self.case.root / 'remote.h'
        header.write_text('enum { STATUS = 0 };\n')
        self.source.write_text('#include "remote.h"\nint\nmain(void) {\n    return STATUS;\n}\n')
        result = engine.school_analyze(self.config)
        header.write_text('enum { STATUS = 128 };\n')
        for source, candidate, findings, dependencies, tools in result.cache_jobs:
            engine.format_cache_store(source, candidate, findings, dependencies, tools, self.config)
        self.assertFalse(list(self.cache.rglob('school-*.json')))

    def test_unusable_extra_dependency_disables_optional_cache(self):
        with mock.patch.object(engine, 'format_include_candidates', return_value={'bad\0name.h'}):
            result, _ = self.collect_calls()
        self.assertFalse(result.errors, result.findings)
        self.assertFalse(list(self.cache.rglob('school-*.json')))

    def test_dependency_superset_covers_comments_and_spliced_directives(self):
        text = '#/**/include/**/"first.h"\n#inc\\\nlude "second.h"\n'
        candidates = engine.format_include_candidates(self.source, text, [])
        self.assertIn(str(self.source.parent / 'first.h'), candidates)
        self.assertIn(str(self.source.parent / 'second.h'), candidates)

    def test_header_change_invalidates_result(self):
        header = self.case.root / 'values.h'
        header.write_text('#pragma once\nenum { STATUS = 0 };\n')
        self.source.write_text('#include "values.h"\nint\nmain(void) {\n    return STATUS;\n}\n')
        self.collect_calls()
        _, warm = self.collect_calls()
        self.assertFalse(any('-ast-dump=json' in args for args in warm), warm)
        header.write_text('#pragma once\nenum { STATUS = 128 };\n')
        result, fresh = self.collect_calls()
        self.assertTrue(any('-ast-dump=json' in args for args in fresh))
        self.assertTrue(any(item.rule == '5.7' for item in result.errors), result.findings)

    def test_tool_identity_and_engine_revision_invalidate_result(self):
        self.collect_calls()
        with mock.patch.object(engine, 'SCHOOL_ENGINE_ID', 'different-policy'):
            _, calls = self.collect_calls()
        self.assertTrue(any('-ast-dump=json' in args for args in calls))
        wrapper = self.case.root / 'formatter'
        wrapper.write_text('#!/bin/sh\nexec ' + shlex.quote(shutil.which('clang-format')) + ' "$@"\n')
        wrapper.chmod(0o755)
        self.collect_calls(native_formatter=str(wrapper))
        _, warm = self.collect_calls(native_formatter=str(wrapper))
        self.assertFalse(any('-ast-dump=json' in args for args in warm))
        wrapper.write_text(wrapper.read_text() + '# upgraded\n')
        _, fresh = self.collect_calls(native_formatter=str(wrapper))
        self.assertTrue(any('-ast-dump=json' in args for args in fresh))

    def test_compiled_artifact_does_not_invalidate_source_checks(self):
        self.collect_calls()
        (self.case.root / 'program.out').write_bytes(b'compiled program')
        _, calls = self.collect_calls()
        self.assertFalse(any('-ast-dump=json' in args for args in calls), calls)

    def test_new_makefile_invalidates_prior_missing_file_finding(self):
        self.source.write_text('int\ncalculate(void) {\n    return 0;\n}\n')
        (self.case.root / 'main.h').write_text('#pragma once\nint calculate(void);\n')
        self.source.write_text('#include "main.h"\n' + self.source.read_text())
        result, _ = self.collect_calls()
        self.assertTrue(any(item.rule == '6.6' for item in result.errors))
        (self.case.root / 'Makefile').write_text('all:\nclean:\n')
        result, calls = self.collect_calls()
        self.assertFalse(any(item.rule == '6.6' for item in result.errors), result.findings)
        self.assertTrue(any('-ast-dump=json' in args for args in calls))

    def test_corrupt_cache_is_recomputed_and_report_decisions_are_not_cached(self):
        self.collect_calls()
        path = next(self.cache.rglob('school-*.json'))
        path.write_text('not JSON')
        result, calls = self.collect_calls()
        self.assertFalse(result.errors)
        self.assertTrue(any('-ast-dump=json' in args for args in calls))
        record = json.loads(path.read_text())
        self.assertNotIn('decision', str(record['findings']))

    def test_include_environment_change_forces_fresh_checks(self):
        self.collect_calls()
        with mock.patch.dict(engine.os.environ, CPATH=str(self.case.root / 'new-includes')):
            _, calls = self.collect_calls()
        self.assertTrue(any('-ast-dump=json' in args for args in calls))

    def test_report_cannot_overwrite_a_related_header(self):
        header = self.case.root / 'module.h'
        header.write_text('#pragma once\nint calculate(void);\n')
        self.source.write_text('#include "module.h"\nint main(void) { return 0; }\n')
        before = header.read_bytes()
        with self.assertRaises(engine.CheckUsageError):
            self.collect_calls(review_report=str(header), overwrite=True)
        self.assertEqual(header.read_bytes(), before)

    def test_make_dependency_escaping(self):
        actual = engine.format_dependency_paths('unit: /tmp/a\\ b.h /tmp/money$$.h ' + chr(92) + chr(10) + ' /tmp/hash\\#.h\n')
        self.assertEqual(actual, ['/tmp/a b.h', '/tmp/money$.h', '/tmp/hash#.h'])
