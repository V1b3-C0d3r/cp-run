"""Requested numeric exceptions, precise name evidence and fast-path correctness."""
import shutil
import unittest
from unittest import mock
import test_school_policy as cases

engine = cases.engine


@unittest.skipUnless(shutil.which('clang'), 'needs Clang')
class School151PolicyTest(unittest.TestCase):
    def setUp(self):
        self.case = cases.SchoolPolicyTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)

    def test_two_and_minus_one_never_require_enum_conversion(self):
        for declaration, value in (('const int STATUS = 2;', 'STATUS'),
                                   ('const int STATUS = -1;', 'STATUS'),
                                   ('#define STATUS 2\n', 'STATUS'),
                                   ('#define STATUS (-1)\n', 'STATUS')):
            findings = self.case.check(declaration + '\nint main(void) { return ' + value + ' != 0; }')
            self.assertFalse(any(item.rule in ('5.1', '5.2') for item in findings), findings)
        findings = self.case.check('int main(void) { int value = -1; return value < 2; }')
        self.assertFalse(self.case.has_rule(findings, '5.1'), findings)

    def test_requested_forbidden_identifiers(self):
        for code, rule in (('enum { I = 0 }; int main(void) { return I; }', '3.7'),
                           ('int main(void) { int l = 0; return l; }', '3.7'),
                           ('int f(void) { return 0; } int main(void) { return f(); }', '3.1')):
            self.assertTrue(self.case.has_rule(self.case.check(code), rule, 'error'), code)

    def test_enum_N_is_allowed_in_c_and_cpp(self):
        for extension in ('main.c', 'main.cpp'):
            findings = self.case.check('enum { N = 16 }; int main(void) { return N != 0; }', extension)
            self.assertFalse(any(item.rule in ('3.1', '3.3', '3.7') for item in findings), findings)

    def test_ambiguous_constants_are_rejected_in_each_declaration_form(self):
        for name in ('I', 'O'):
            for declaration in ('enum { NAME = 2 };', 'const int NAME = 2;', '#define NAME 2\n'):
                code = declaration.replace('NAME', name) + '\nint main(void) { return ' + name + ' != 0; }'
                findings = self.case.check(code)
                self.assertTrue(self.case.has_rule(findings, '3.7', 'error'), code)

    def test_this_field_access_alone_needs_no_resource_analysis(self):
        source = self.case.root / 'main.cpp'
        for code, expected in (
            ('struct Value { int count = 0; int get() { return this->count; } };', False),
            ('struct Value { int count = 0; int get() { return count; } };', False),
            ('struct Value { int count; }; int get(Value *value) { return value->count; }', True),
            ('struct Value { int *data; int get() { return data[0]; } };', True),
            ('struct Value { void reset() { delete this; } };', True),
            ('struct Value { int count = 0; auto closure() { return [this] { return count; }; } };', True),
            ('struct Value { int count = 0; ~Value() {} int stop() { this->~Value(); return count; } };', True),
            ('#include <vector>\\nstruct Value { std::vector<int> data; int get() { return data[0]; } };', True),
        ):
            tree, errors = engine.school_parse(source, code, self.case.clang)
            self.assertFalse(errors, errors)
            self.assertEqual(engine.school_needs_resource_analysis(source, code, tree), expected, code)

    def test_transliteration_is_whole_word_and_conservative(self):
        for name in ('vychislenie', 'kolichestvo', 'massiv_razmer'):
            code = 'int ' + name + '(void) { return 0; }'
            self.assertTrue(self.case.has_rule(self.case.check(code), '3.2', 'error'), name)
        for name in ('massive_count', 'polynomial_value', 'calculate_root', 'format_value', 'data'):
            code = 'int ' + name + '(void) { return 0; }'
            self.assertFalse(self.case.has_rule(self.case.check(code), '3.2'), name)

    def test_generic_semantic_obligations_produce_no_warnings(self):
        code = ('int main(void) { int count = 0; int *borrowed = &count; '
                'if (count) { return *borrowed; } return 0; }')
        self.assertFalse(any(item.severity == 'warning' for item in self.case.check(code)))

    def test_resource_analysis_is_not_skipped_for_real_resources(self):
        for code in ('#include <stdlib.h>\nint main(void) { char *data = calloc(1, sizeof(*data)); free(data); return 0; }',
                     'int main(void) { int *value = 0; return *value; }'):
            source = self.case.root / 'main.c'
            tree, errors = engine.school_parse(source, code, self.case.clang)
            self.assertEqual(errors, [])
            self.assertTrue(engine.school_needs_resource_analysis(source, code, tree), code)
        plain = 'int main(void) { int value = 0; return value; }'
        tree, _ = engine.school_parse(self.case.root / 'main.c', plain, self.case.clang)
        self.assertFalse(engine.school_needs_resource_analysis(self.case.root / 'main.c', plain, tree))

    def test_header_implementations_are_not_traversed_as_user_code(self):
        source = self.case.root / 'main.c'
        text = '#include <stdio.h>\nint main(void) { return 0; }'
        tree, errors = engine.school_parse(source, text, self.case.clang)
        self.assertEqual(errors, [])
        functions = [item['name'] for item in tree['inner'] if item.get('kind') == 'FunctionDecl']
        self.assertEqual(functions, ['main'])
