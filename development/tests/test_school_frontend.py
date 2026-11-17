"""GNU compatibility and small ASTs without losing header semantics."""
import shutil
import unittest
from unittest import mock
import test_school_format as fixtures

engine = fixtures.engine


@unittest.skipUnless(shutil.which('clang') and shutil.which('clang-format'), 'needs school tools')
class SchoolFrontendTest(unittest.TestCase):
    def setUp(self):
        self.case = fixtures.SchoolFormatTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)
        self.source = self.case.root / 'main.cpp'
        self.clang = shutil.which('clang')
        self.clear_preambles()
        self.addCleanup(self.clear_preambles)

    def clear_preambles(self):
        for entry in engine.SCHOOL_PREAMBLES.values():
            entry['temporary'].cleanup()
        engine.SCHOOL_PREAMBLES.clear()

    def parse(self, code, **patches):
        calls = []
        real = engine.school_tool
        def capture(argv, **options):
            result = real(argv, **options)
            calls.append((argv, result))
            return result
        with mock.patch.object(engine, 'school_tool', side_effect=capture):
            tree, errors = engine.school_parse(self.source, code, self.clang)
        self.assertEqual(errors, [], errors)
        self.assertIsNotNone(tree)
        return tree, calls

    def test_gnu_lg_and_bits_use_gnu_headers_with_a_small_ast(self):
        code = '#include <bits/stdc++.h>\nint main() { return std::__lg(8) != 3; }\n'
        tree, calls = self.parse(code)
        dumps = [(argv, result) for argv, result in calls if '-ast-dump=json' in argv]
        self.assertTrue(dumps)
        self.assertTrue(all('-include-pch' in argv for argv, _ in dumps), dumps)
        # The original bug serialized hundreds of MB of library implementations.
        self.assertLess(sum(len(result.stdout) for _, result in dumps), 2_000_000)
        self.assertIn('main', [node.get('name') for node in tree['inner']])
        context = engine.school_cpp_context()
        if context:
            self.assertIn('-nostdinc++', context)
            self.assertIn('-isystem', context)
        _, edited = self.parse(code.replace('__lg(8)', '__lg(16)'))
        self.assertFalse(any('c++-header' in argv for argv, _ in edited))
        self.assertTrue(all('-include-pch' in argv for argv, _ in edited if '-ast-dump=json' in argv))

    def test_imported_explicit_and_implicit_enum_values_still_check_main(self):
        header = self.case.root / 'values.hpp'
        header.write_text('#pragma once\nnamespace limits { enum Status { LOW = 127, HIGH }; }\n')
        for expression, expected_error in (('limits::LOW', False), ('limits::HIGH', True)):
            code = '#include "values.hpp"\nint main() { return ' + expression + '; }\n'
            tree, calls = self.parse(code)
            findings = engine.SchoolPolicy(self.source, code, tree).run()
            self.assertEqual(any(item.rule == '5.7' and item.severity == 'error' for item in findings),
                             expected_error, findings)
            self.assertTrue(all('-include-pch' in argv for argv, _ in calls if '-ast-dump=json' in argv))

    def test_anonymous_enum_metadata_does_not_degrade_to_unprovable_warning(self):
        (self.case.root / 'values.hpp').write_text('#pragma once\nenum { STATUS = 128 };\n')
        code = '#include "values.hpp"\nint main() { return STATUS; }\n'
        tree, _ = self.parse(code)
        findings = engine.SchoolPolicy(self.source, code, tree).run()
        self.assertTrue(any(item.rule == '5.7' and item.severity == 'error' for item in findings), findings)

    def test_imported_exception_ancestry_still_rejects_hidden_catch(self):
        (self.case.root / 'errors.hpp').write_text(
            '#pragma once\nnamespace errors { struct Base {}; struct Derived : Base {}; }\n')
        code = ('#include "errors.hpp"\nint main() { try { throw errors::Derived(); } '
                'catch (const errors::Base &) { return 0; } '
                'catch (const errors::Derived &) { return 0; } }\n')
        tree, calls = self.parse(code)
        findings = engine.SchoolPolicy(self.source, code, tree).run()
        self.assertTrue(any(item.rule == '4.6.12' and item.severity == 'error' and
                            'specialized catch' in item.message for item in findings), findings)
        self.assertTrue(all('-include-pch' in argv for argv, _ in calls if '-ast-dump=json' in argv))

    def test_inaccessible_enum_probe_falls_back_to_full_checked_ast(self):
        (self.case.root / 'values.hpp').write_text(
            '#pragma once\nclass Limits { enum { STATUS = 128 }; public: '
            'static int status(); };\n')
        # The source member may use a private enum; the global metadata probe
        # cannot. This must take the full path rather than omit its value.
        code = ('#include "values.hpp"\nint Limits::status() { return STATUS; }\n'
                'int main() { return Limits::status(); }\n')
        tree, calls = self.parse(code)
        self.assertIn(128, engine.SchoolPolicy(self.source, code, tree).constants.values())
        dumps = [argv for argv, _ in calls if '-ast-dump=json' in argv]
        self.assertTrue(any('-include-pch' in argv for argv in dumps))
        self.assertTrue(any('-include-pch' not in argv for argv in dumps))

    def test_prefix_handles_comments_conditional_includes_and_utf8_offsets(self):
        (self.case.root / 'empty.hpp').write_text('#pragma once\n')
        code = ('// комментарий\n#if 1\n#include "empty.hpp"\n#endif\n'
                'int main() { int BadName = 0; return BadName; }\n')
        tree, _ = self.parse(code)
        bad = next(node for node in engine.school_nodes(tree) if node.get('name') == 'BadName')
        self.assertEqual(engine.school_location(bad)['offset'], code.encode().index(b'BadName'))
        self.assertEqual(engine.school_preamble_prefix(code), code[:code.index('int main')])
        self.assertEqual(engine.school_preamble_prefix('#line 30\n' + code), '')
        self.assertEqual(engine.school_preamble_prefix('#if 1\n#include "empty.hpp"\nint value;\n#endif\n'), '')

    def test_header_edit_invalidates_preamble_and_enum_value(self):
        header = self.case.root / 'values.hpp'
        header.write_text('#pragma once\nenum { STATUS = 0 };\n')
        code = '#include "values.hpp"\nint main() { return STATUS; }\n'
        self.parse(code)
        header.write_text('#pragma once\nenum { STATUS = 128 };\n')
        tree, calls = self.parse(code)
        self.assertTrue(any('c++-header' in argv for argv, _ in calls))
        self.assertIn(128, tree['school_external_values'].values())

    def test_source_macro_edits_reuse_headers_but_are_parsed_again(self):
        (self.case.root / 'empty.hpp').write_text('#pragma once\n')
        code = '#include "empty.hpp"\n#define VALUE(x) ((int)x)\nint main() { return VALUE(0); }\n'
        self.parse(code)
        _, calls = self.parse(code.replace('((int)x)', '((int) x)'))
        self.assertFalse(any('c++-header' in argv for argv, _ in calls))
        self.assertTrue(any('-ast-dump=json' in argv for argv, _ in calls))

    def test_new_quoted_header_shadow_invalidates_preamble(self):
        import tempfile
        from pathlib import Path
        with tempfile.TemporaryDirectory(prefix='cp-external-headers-') as temporary:
            external = Path(temporary)
            (external / 'values.hpp').write_text('#pragma once\n#include "config.hpp"\n')
            (self.case.root / 'config.hpp').write_text('#pragma once\nenum { STATUS = 0 };\n')
            code = '#include <values.hpp>\nint main() { return STATUS; }\n'
            with mock.patch.dict(engine.os.environ, CPATH=str(external)):
                self.parse(code)
                (external / 'config.hpp').write_text('#pragma once\nenum { STATUS = 128 };\n')
                tree, calls = self.parse(code)
            self.assertTrue(any('c++-header' in argv for argv, _ in calls))
            self.assertIn(128, tree['school_external_values'].values())

    def test_header_changed_during_ast_query_aborts_instead_of_using_stale_pch(self):
        header = self.case.root / 'values.hpp'
        header.write_text('#pragma once\nenum { STATUS = 0 };\n')
        code = '#include "values.hpp"\nint main() { return STATUS; }\n'
        self.parse(code)
        actual = engine.school_tool
        def change(argv, **options):
            result = actual(argv, **options)
            if '-ast-dump=json' in argv:
                header.write_text('#pragma once\nenum { STATUS = 128 };\n')
            return result
        with mock.patch.object(engine, 'school_tool', side_effect=change):
            with self.assertRaisesRegex(engine.CheckSetupError, 'dependency changed'):
                engine.school_parse(self.source, code, self.clang)

    def test_fixed_array_indexing_skips_pointer_analysis_but_pointers_do_not(self):
        for code, expected in (
            ('int main() { int values[2] = {}; return values[0]; }', False),
            ('int read_value(int *values) { return values[0]; }', True),
            ('int main() { int *value = 0; return *value; }', True),
            ('int main() { int *value = new int(0); return *value; }', True),
        ):
            with self.subTest(code=code):
                tree, _ = self.parse(code)
                self.assertEqual(engine.school_needs_resource_analysis(self.source, code, tree), expected)
