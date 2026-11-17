"""Boundary and exception tests supplementing the per-paragraph matrix."""
import shutil
import unittest
import test_school_policy as policy_cases
import test_school_layout as layout_cases

engine = policy_cases.engine


@unittest.skipUnless(shutil.which('clang'), 'needs Clang')
class SchoolPolicyEdgeTest(unittest.TestCase):
    def setUp(self):
        self.case = policy_cases.SchoolPolicyTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)

    def test_T4_4_4_zero_before_first_field_assignment(self):
        prefix = '#include <string.h>\nstruct Item { int value; };\n'
        bad = prefix + 'int main(void) { struct Item item; item.value = 1; return item.value; }'
        good = prefix + 'int main(void) { struct Item item; memset(&item, 0, sizeof(item)); item.value = 1; return item.value; }'
        self.assertTrue(self.case.has_rule(self.case.check(bad), '4.4.4', 'error'))
        self.assertFalse(self.case.has_rule(self.case.check(good), '4.4.4'))

    def test_T4_5_2_empty_definitions_are_not_silently_approved(self):
        self.assertTrue(self.case.has_rule(self.case.check('int main() { return 0; }'), '4.5.2', 'error'))
        self.assertFalse(self.case.has_rule(self.case.check('int main(void) { return 0; }'), '4.5.2'))

    def test_T4_6_8_unbraced_and_empty_control_bodies(self):
        for text in ('if (value) value++;', 'while (value);', 'do value++; while (value);'):
            code = 'int main(void) { int value = 0; ' + text + ' return 0; }'
            self.assertTrue(self.case.has_rule(self.case.check(code), '4.6.8', 'error'), text)
        self.assertFalse(self.case.has_rule(self.case.check('int main(void) { if (1) {} return 0; }'), '4.6.8'))

    def test_T3_4_cpp_operator_is_a_language_construct(self):
        code = 'struct Value { int operator+(const Value &) const { return 0; } }; int main(void) { return 0; }'
        findings = self.case.check(code, 'main.cpp', reviewed=('3.2', '3.5'))
        self.assertFalse(self.case.has_rule(findings, '3.4'), findings)

    def test_T5_1_minus_one_needs_no_rationale(self):
        code = 'int error_code(void) { return -1; } int main(void) { return 0; }'
        self.assertFalse(self.case.has_rule(self.case.check(code), '5.1'))
        self.assertFalse(self.case.has_rule(self.case.check(code, reviewed=('5.1',)), '5.1'))

    def test_T5_2_parenthesized_integer_macro(self):
        code = '#define LIMIT (2 * 3)\nint main(void) { return LIMIT; }'
        self.assertTrue(self.case.has_rule(self.case.check(code), '5.2', 'error'))

    def test_T5_9_malloc_of_linked_node_is_not_reviewable(self):
        code = ('#include <stdlib.h>\nstruct Node { struct Node *next; };\n'
                'int main(void) { struct Node *node = malloc(1 * sizeof(*node)); free(node); return 0; }')
        self.assertTrue(self.case.has_rule(self.case.check(code, reviewed=('5.9',)), '5.9', 'error'))

    def test_T5_16_pointer_to_vla_is_not_a_local_array(self):
        code = 'int run(int size) { int (*data)[size] = 0; return data == 0; }'
        self.assertFalse(self.case.has_rule(self.case.check(code), '5.16'))
        bad = 'int run(int size) { int *data[size]; return 0; }'
        self.assertTrue(self.case.has_rule(self.case.check(bad), '5.16', 'error'))

    def test_T5_17_borrowed_pointer_can_be_declared_at_first_use(self):
        code = 'int main(void) { int value = 0; value++; int *borrowed = &value; return *borrowed; }'
        findings = self.case.check(code)
        self.assertFalse(self.case.has_rule(findings, '5.17', 'error'), findings)

    def test_T5_17_descriptor_acquired_after_declaration(self):
        code = '#include <fcntl.h>\n#include <unistd.h>\nint main(void) { int value = 0; value++; int fd; fd = open("", 0); close(fd); return value; }'
        self.assertTrue(self.case.has_rule(self.case.check(code), '5.17', 'error'))

    def test_T4_7_9_return_grouping_is_redundant_but_decltype_grouping_is_not(self):
        code = 'int main(void) { int value = 0; return (value + 1); }'
        self.assertTrue(self.case.has_rule(self.case.check(code), '4.7.9', 'error'))
        cpp = 'int main(void) { int value = 0; decltype((value)) alias = value; return alias; }'
        self.assertFalse(self.case.has_rule(self.case.check(cpp, 'main.cpp'), '4.7.9', 'error'))

    def test_source_line_sensitive_expansion_needs_review(self):
        code = 'int main(void) { return __LINE__ != 0; }'
        findings = self.case.check(code)
        self.assertFalse(self.case.has_rule(findings, '5.1', 'error'), findings)
        self.assertTrue(self.case.has_rule(findings, '4.5.1', 'warning'), findings)
