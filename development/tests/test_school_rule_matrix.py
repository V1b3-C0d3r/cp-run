"""One independently reported, behavioral test for each numbered PDF paragraph."""
import shutil
import unittest
import test_school_policy as policy_cases
import test_school_layout as layout_cases

engine = policy_cases.engine
LAYOUT = {rule: (source, expected) for rule, source, expected in layout_cases.LAYOUT_CASES}
ERRORS = {
    '3.1': ('int fn(void) { return 0; }', 'int calculate(void) { return 0; }'),
    '3.2': ('int vychislenie(void) { return 0; }', 'int calculation(void) { return 0; }'),
    '1.1': ('// forbidden control: \x7f\nint main(void) { return 0; }',
            '// ordinary comment\nint main(void) { return 0; }'),
    '3.3': ('enum { red = 0 }; int main(void) { return red; }',
            'enum { RED = 0 }; int main(void) { return RED; }'),
    '3.4': ('int main(void) { int BadName = 0; return BadName; }',
            'int main(void) { int value = 0; return value; }'),
    '3.6': ('struct node { int value; }; int main(void) { return 0; }',
            'struct Node { int value; }; int main(void) { return 0; }'),
    '3.7': ('int main(void) { int l = 0; return l; }',
            'int main(void) { int index = 0; return index; }'),
    '4.4.1': ('int main(void) { int matrix[2][2] = {0, 1, 1, 0}; return matrix[0][0]; }',
              'int main(void) { int matrix[2][2] = {{0, 1}, {1, 0}}; return matrix[0][0]; }'),
    '4.4.4': ('struct Node { int value; }; int main(void) { struct Node node = {0}; return node.value; }',
              '#include <string.h>\nstruct Node { int value; }; int main(void) { struct Node node; memset(&node, 0, sizeof(node)); return node.value; }'),
    '4.4.5': ('int main(void) { int base = 0; int first = base + 1, second = 0; return first + second; }',
              'int main(void) { int first = 1 + 1, second = 0; return first + second; }'),
    '4.5.1': ('void run(void) {}', 'void run(void) { return; }'),
    '4.7.8': ('int main(void) { int data[1] = {0}; return *(data + 0); }',
              'int main(void) { int data[1] = {0}; return data[0]; }'),
    '4.7.9': ('int main(void) { int value = 0; if ((value > 0) && (!(value))) { return 1; } return 0; }',
              'int main(void) { int value = 0; if (value > 0 && !value) { return 1; } return 0; }'),
    '5.1': ('int main(void) { return 3; }',
            'enum { STATUS = 2 }; int main(void) { return STATUS; }'),
    '5.2': ('#define STATUS 3\nint main(void) { return STATUS; }',
            'enum { STATUS = 2 }; int main(void) { return STATUS; }'),
    '5.3': ('#include "stdio.h"\nint main(void) { return 0; }',
            '#include <stdio.h>\nint main(void) { return 0; }'),
    '5.5': ('#include <stdio.h>\nint main(void) { fprintf(stderr, "error"); return 0; }',
            '#include <stdio.h>\nint main(void) { fprintf(stderr, "error\\n"); return 0; }'),
    '5.6': ('#include <stdio.h>\nint main(void) { printf("result"); return 0; }',
            '#include <stdio.h>\nint main(void) { printf("result\\n"); return 0; }'),
    '5.7': ('enum { STATUS = 128 }; int main(void) { return STATUS; }',
            'enum { STATUS = 127 }; int main(void) { return STATUS; }'),
    '5.8': ('#include <string.h>\nint main(void) { char data[1]; strcpy(data, ""); return 0; }',
            '#include <string.h>\nint main(void) { char data[1]; memcpy(data, "", sizeof(data)); return 0; }'),
    '5.10': ('#include <stdlib.h>\nint main(void) { char *data = calloc(1, sizeof(char)); free(data); return 0; }',
             '#include <stdlib.h>\nint main(void) { char *data = calloc(1, sizeof(*data)); free(data); return 0; }'),
    '5.11': ('#include <stdlib.h>\nint main(void) { char *data = 0; data = realloc(data, 1); free(data); return 0; }',
             '#include <stdlib.h>\nint main(void) { char *data = 0; data = realloc(data, 1 * sizeof(*data)); free(data); return 0; }'),
    '5.15': ('#include <stdlib.h>\nint main(void) { char *data = calloc(1, sizeof(*data)); free(data); return 0; }',
             'int main(void) { char data[1] = {0}; return data[0]; }'),
    '5.16': ('int run(int size) { int data[size][4]; return 0; }',
             'enum { SIZE = 4 }; int run(void) { int data[SIZE][SIZE]; return 0; }'),
    '5.17': ('#include <stdlib.h>\nint main(void) { int value = 0; value++; char *data = 0; free(data); return value; }',
             '#include <stdlib.h>\nint main(void) { char *data = 0; free(data); return 0; }'),
    '5.18': ('#include <stdlib.h>\nint main(void) { char *data = (char *)calloc(1, sizeof(*data)); free(data); return 0; }',
             '#include <stdlib.h>\nint main(void) { char *data = calloc(1, sizeof(*data)); free(data); return 0; }'),
}
REVIEWS = {


    '3.5': 'int main(void) { int count = 0; int *p_count = &count; return *p_count; }',
    '4.6.11': 'int main(void) { goto done; done: return 0; }',

    '5.9': '#include <stdlib.h>\nchar *create_buffer(void) { char *data = malloc(1 * sizeof(*data)); return data; } int main(void) { return 0; }',
    '5.12': '// printf("debug");\nint main(void) { return 0; }',

    '5.14': 'int total; int main(void) { return total; }',
}


@unittest.skipUnless(shutil.which('clang') and shutil.which('clang-format'), 'needs school frontend tools')
class SchoolRuleMatrixTest(unittest.TestCase):
    def setUp(self):
        self.policy_case = policy_cases.SchoolPolicyTest('runTest')
        self.policy_case.setUp()
        self.addCleanup(self.policy_case.doCleanups)
        self.layout_case = layout_cases.SchoolLayoutTest('runTest')
        self.layout_case.setUp()
        self.addCleanup(self.layout_case.doCleanups)

    def assert_rule(self, rule):
        exercised = False
        if rule in LAYOUT:
            source, expected = LAYOUT[rule]
            candidate = self.layout_case.layout(source)
            self.assertIn(expected, candidate)
            self.assertNotEqual(candidate, source)
            self.assertEqual(self.layout_case.layout(candidate), candidate)
            exercised = True
        if rule in ERRORS:
            bad, good = ERRORS[rule]
            reviewed = (rule,) if rule in engine.SCHOOL_REVIEW_RULES else ()
            bad_findings = self.policy_case.check(bad, reviewed=reviewed)
            self.assertTrue(self.policy_case.has_rule(bad_findings, rule, 'error'), bad_findings)
            good_findings = self.policy_case.check(good, reviewed=reviewed)
            self.assertFalse(self.policy_case.has_rule(good_findings, rule), good_findings)
            exercised = True
        if rule in REVIEWS:
            code = REVIEWS[rule]
            findings = self.policy_case.check(code)
            self.assertTrue(self.policy_case.has_rule(findings, rule, 'warning'), findings)
            reviewed = self.policy_case.check(code, reviewed=(rule,))
            self.assertFalse(self.policy_case.has_rule(reviewed, rule), reviewed)
            exercised = True
        if rule in CUSTOM:
            getattr(self, CUSTOM[rule])()
            exercised = True
        self.assertTrue(exercised, 'Rule has no behavioral contract: ' + rule)

    def manual_output_intent(self):
        findings = self.policy_case.check('#include <stdio.h>\nint main(void) { puts("result"); return 0; }')
        self.assertFalse(self.policy_case.has_rule(findings, '5.4'), findings)

    def helper_output(self):
        ordinary = '#include <stdio.h>\nvoid print_result(void) { puts("result"); return; }'
        self.assertFalse(self.policy_case.has_rule(self.policy_case.check(ordinary), '5.13'))
        prohibited = 'int puts(const char *);\nvoid getline(void) { puts("result"); return; }'
        self.assertTrue(self.policy_case.has_rule(self.policy_case.check(prohibited), '5.13', 'error'))

    def width(self):
        self.layout_case.test_T2_2_unicode_width_boundary_and_controls()

    def continuation(self):
        self.layout_case.test_T2_3_continuation_uses_eight_extra_spaces()

    def parameters(self):
        self.layout_case.test_T4_5_3_seventy_character_threshold_and_parameter_ranges()

    def catches(self):
        self.layout_case.test_T4_6_12_try_catch_layout()
        self.policy_case.test_cpp_catch_order_and_field_rules()

    def module_pair(self):
        bad = self.policy_case.check('int run(void) { return 0; }', 'module.c')
        self.assertTrue(self.policy_case.has_rule(bad, '6.1', 'error'), bad)
        good = self.policy_case.check('#include "module.h"\nint run(void) { return 0; }', 'module.c',
            headers={'module.h': '#pragma once\nint run(void);\n', 'Makefile': 'all:\nclean:\n'})
        self.assertFalse(self.policy_case.has_rule(good, '6.1'), good)

    def guard(self):
        self.policy_case.test_header_guard_must_enclose_whole_file()

    def own_header(self):
        headers = {'module.h': '#pragma once\nint run(void);\n', 'Makefile': 'all:\nclean:\n'}
        bad = self.policy_case.check('int run(void) { return 0; }', 'module.c', headers=headers)
        self.assertTrue(self.policy_case.has_rule(bad, '6.3', 'error'), bad)
        good = self.policy_case.check('#include "module.h"\nint run(void) { return 0; }', 'module.c', headers=headers)
        self.assertFalse(self.policy_case.has_rule(good, '6.3'), good)

    def owner(self):
        self.policy_case.test_project_header_ownership_and_minimal_includes()

    def minimal(self):
        self.policy_case.test_project_header_ownership_and_minimal_includes()

    def makefile(self):
        headers = {'module.h': '#pragma once\nint run(void);\n', 'Makefile': 'all:\n'}
        code = '#include "module.h"\nint run(void) { return 0; }'
        bad = self.policy_case.check(code, 'module.c', headers=headers)
        self.assertTrue(self.policy_case.has_rule(bad, '6.6', 'error'), bad)
        headers['Makefile'] = 'all:\nclean:\n'
        good = self.policy_case.check(code, 'module.c', headers=headers, reviewed=('6.6',))
        self.assertFalse(self.policy_case.has_rule(good, '6.6'), good)
        self.policy_case.test_header_review_belongs_to_header_and_makefile_is_not_executed()


CUSTOM = {
    '5.4': 'manual_output_intent', '5.13': 'helper_output',
    '2.2': 'width', '2.3': 'continuation', '4.5.3': 'parameters', '4.6.12': 'catches',
    '6.1': 'module_pair', '6.2': 'guard', '6.3': 'own_header',
    '6.4': 'owner', '6.5': 'minimal', '6.6': 'makefile',
}


def make_rule_test(rule):
    def test(self):
        self.assert_rule(rule)
    test.__doc__ = 'Positive, negative and exception contract for PDF rule ' + rule
    return test


for _rule in engine.SCHOOL_RULES:
    setattr(SchoolRuleMatrixTest, 'test_T' + _rule.replace('.', '_'), make_rule_test(_rule))


class SchoolCoverageInventoryTest(unittest.TestCase):
    def test_every_rule_has_an_executed_contract(self):
        implemented = set(LAYOUT) | set(ERRORS) | set(REVIEWS) | set(CUSTOM)
        self.assertEqual(implemented, set(engine.SCHOOL_RULES))
        cases = unittest.defaultTestLoader.getTestCaseNames(SchoolRuleMatrixTest)
        self.assertEqual(set(cases), {'test_T' + rule.replace('.', '_') for rule in engine.SCHOOL_RULES})
