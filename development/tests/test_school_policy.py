"""Rule-level positive, negative and review-exception contracts from the PDF."""
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from _paths import load_engine

engine = load_engine('cp_school_rule_contracts')


@unittest.skipUnless(shutil.which('clang'), 'needs the Clang AST frontend')
class SchoolPolicyTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='school-rules-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.clang = shutil.which('clang')

    def check(self, text, filename='main.c', headers=None, reviewed=()):
        for name, content in (headers or {}).items():
            (self.root / name).write_text(content)
        comments = ''.join('// school-reviewed {}: This fixture explicitly verifies this semantic obligation.\n'.format(rule)
                           for rule in reviewed)
        source = self.root / filename
        source.write_text(comments + text)
        tree, errors = engine.school_parse(source, comments + text, self.clang)
        self.assertEqual(errors, [], errors)
        policy = engine.SchoolPolicy(source, comments + text, tree)
        return policy.run()

    def has_rule(self, findings, rule, category=None):
        return any('school {} '.format(rule) in finding and
                   (category is None or category in finding) for finding in findings)

    def test_naming_rules_and_review_cannot_hide_mechanical_error(self):
        cases = [
            ('3.1', 'int fn(void) { return 0; }', 'error'),
            ('3.2', 'int main(void) { int vychislenie = 0; return vychislenie; }', 'error'),
            ('3.3', 'enum { red = 0 }; int main(void) { return red; }', 'error'),
            ('3.4', 'int main(void) { int BadName = 0; return BadName; }', 'error'),
            ('3.5', 'int main(void) { int value = 0; int *p_count = &value; return *p_count; }', 'warning'),
            ('3.6', 'struct node { int value; }; int main(void) { return 0; }', 'error'),
            ('3.7', 'int main(void) { int l = 0; return l; }', 'error'),
        ]
        for rule, code, category in cases:
            with self.subTest(rule=rule):
                self.assertTrue(self.has_rule(self.check(code), rule, category))
                if category == 'warning':
                    self.assertFalse(self.has_rule(self.check(code, reviewed=(rule,)), rule))
                else:
                    findings = self.check(code, reviewed=(rule,))
                    self.assertTrue(self.has_rule(findings, rule, 'error'))

    def test_teacher_exception_only_applies_to_functions(self):
        code = 'int Calc(void) { return 0; } int main(void) { return Calc(); }'
        self.assertTrue(self.has_rule(self.check(code), '3.4', 'warning'))
        self.assertFalse(self.has_rule(self.check(code, reviewed=('3.4',)), '3.4'))
        code = 'int main(void) { int Value = 0; return Value; }'
        self.assertTrue(self.has_rule(self.check(code, reviewed=('3.4',)), '3.4', 'error'))

    def test_record_and_initializer_rules(self):
        cases = [
            ('4.1', 'struct Node { int value; } object; int main(void) { return 0; }'),
            ('4.4.1', 'int main(void) { int matrix[2][2] = {0, 1, 1, 0}; return matrix[0][0]; }'),
            ('4.4.4', 'struct Node { int value; }; int main(void) { struct Node node = {0}; return node.value; }'),
            ('4.4.5', 'int main(void) { int base = 0; int first = base + 1, second = 0; return first + second; }'),
        ]
        for rule, code in cases:
            with self.subTest(rule=rule):
                self.assertTrue(self.has_rule(self.check(code), rule, 'error'))
        code = 'int main(void) { int matrix[2][2] = {{0, 1}, {1, 0}}; return matrix[0][0]; }'
        self.assertFalse(self.has_rule(self.check(code, reviewed=('4.4.1',)), '4.4.1'))

    def test_const_expression_and_memset_positive(self):
        code = 'int main(void) { int first = 1 + 1, second = 0; return first + second; }'
        self.assertFalse(self.has_rule(self.check(code), '4.4.5'))
        code = '#include <string.h>\nstruct Node { int value; };\nint main(void) { struct Node node; memset(&node, 0, sizeof(node)); node.value = 1; return 0; }'
        self.assertFalse(self.has_rule(self.check(code), '4.4.4'))

    def test_return_and_main_exit_paths(self):
        self.assertTrue(self.has_rule(self.check('void run(void) {}'), '4.5.1', 'error'))
        code = 'int main(void) { return -1; }'
        self.assertTrue(self.has_rule(self.check(code), '5.7', 'error'))
        code = 'int main(void) { int value = 0; if (value) { return 0; } else { return 1; } }'
        self.assertFalse(self.has_rule(self.check(code), '5.7'))
        code = 'enum { TOO_LARGE = 128 }; int main(void) { return TOO_LARGE; }'
        self.assertTrue(self.has_rule(self.check(code), '5.7', 'error'))
        code = 'enum { LAST_VALID = 127 }; int main(void) { return LAST_VALID; }'
        self.assertFalse(self.has_rule(self.check(code), '5.7'))

    def test_goto_target_direction(self):
        backward = 'int main(void) { again: if (0) { goto again; } return 0; }'
        forward = 'int main(void) { goto done; done: return 0; }'
        self.assertTrue(self.has_rule(self.check(backward), '4.6.11', 'error'))
        self.assertTrue(self.has_rule(self.check(forward), '4.6.11', 'warning'))
        self.assertFalse(self.has_rule(self.check(forward, reviewed=('4.6.11',)), '4.6.11'))

    def test_pointer_notation_and_parentheses(self):
        cases = [
            ('4.7.8', 'int main(void) { int data[1] = {0}; int *ptr = data; return *(ptr + 0); }'),
            ('4.7.8', 'struct Node { int value; }; int main(void) { struct Node *ptr = 0; return (*ptr).value; }'),
            ('4.7.9', 'int main(void) { int value = 0; if ((value > 0) && (!(value))) { return 1; } return 0; }'),
        ]
        for rule, code in cases:
            with self.subTest(rule=rule, code=code):
                self.assertTrue(self.has_rule(self.check(code), rule, 'error'))
        self.assertFalse(self.has_rule(self.check(
            'int main(void) { int first = 1, second = 0; return first - (second - first); }'), '4.7.9'))
        self.assertFalse(self.has_rule(self.check(
            'int main(void) { int value = 0; return sizeof(value); }'), '4.7.9'))

    def test_literal_contexts(self):
        self.assertTrue(self.has_rule(self.check('int main(void) { return 3; }'), '5.1', 'error'))
        self.assertFalse(self.has_rule(self.check(
            '#include <unistd.h>\nint main(void) { write(2, "", 0); return 0; }'), '5.1'))
        self.assertFalse(self.has_rule(self.check(
            'enum { STATUS = 2 }; int main(void) { return STATUS; }'), '5.1'))
        self.assertTrue(self.has_rule(self.check(
            '#define STATUS 3\nint main(void) { return STATUS; }'), '5.2', 'error'))
        self.assertFalse(self.has_rule(self.check(
            'int main(void) { const char *text = ""; return text[0]; }'), '5.2'))

    def test_scanf_format_and_unsafe_aliases(self):
        for fmt in ('%s', '%0s', '%*s'):
            code = '#include <stdio.h>\nint main(void) { char value[1]; scanf("' + fmt + '", value); return 0; }'
            self.assertTrue(self.has_rule(self.check(code), '5.8', 'error'), fmt)
        for fmt in ('%1s', '%%s'):
            code = '#include <stdio.h>\nint main(void) { char value[1]; scanf("' + fmt + '", value); return 0; }'
            self.assertFalse(self.has_rule(self.check(code), '5.8'), fmt)
        code = '#include <string.h>\nint main(void) { char *(*copy)(char *, const char *) = strcpy; char data[1]; copy(data, ""); return 0; }'
        self.assertTrue(self.has_rule(self.check(code), '5.8', 'error'))
        code = 'void run(void (*operation)(void)) { operation(); return; }'
        self.assertFalse(self.has_rule(self.check(code), '5.8'))

    def test_output_review_and_known_newlines(self):
        code = '#include <stdio.h>\nint main(void) { printf("value"); return 0; }'
        findings = self.check(code)
        self.assertFalse(self.has_rule(findings, '5.4'))
        self.assertTrue(self.has_rule(findings, '5.6', 'error'))
        code = '#include <stdio.h>\nint main(void) { printf("value\\n"); return 0; }'
        self.assertFalse(self.has_rule(self.check(code), '5.6'))
        code = '#include <stdio.h>\nint main(void) { fprintf(stderr, "error"); return 0; }'
        self.assertTrue(self.has_rule(self.check(code), '5.5', 'error'))
        code = '#include <stdio.h>\nint main(void) { printf("value"); printf("\\n"); return 0; }'
        self.assertFalse(self.has_rule(self.check(code), '5.6'))

    def test_allocations_and_resources(self):
        code = '#include <stdlib.h>\nint main(void) { char *buffer = calloc(1, sizeof(char)); free(buffer); return 0; }'
        findings = self.check(code)
        self.assertTrue(self.has_rule(findings, '5.10', 'error'))
        self.assertTrue(self.has_rule(findings, '5.15', 'error'))
        code = '#include <stdlib.h>\nint main(void) { char *buffer = 0; buffer = realloc(buffer, 1); free(buffer); return 0; }'
        self.assertTrue(self.has_rule(self.check(code), '5.11', 'error'))
        code = '#include <stdlib.h>\nint main(void) { char *buffer = (char *)calloc(1, sizeof(*buffer)); free(buffer); return 0; }'
        self.assertTrue(self.has_rule(self.check(code), '5.18', 'error'))
        code = '#include <stdlib.h>\nint main(void) { int value = 0; value++; char *buffer = 0; free(buffer); return value; }'
        self.assertTrue(self.has_rule(self.check(code), '5.17', 'error'))
        code = '#include <stdlib.h>\nint main(void) { char *buffer = 0; free(buffer); return 0; }'
        self.assertFalse(self.has_rule(self.check(code), '5.17'))

    def test_vla_multidimensional_and_parameter_exception(self):
        for array in ('values[size]', 'values[size][4]'):
            code = 'int run(int size) { int ' + array + '; return 0; }'
            self.assertTrue(self.has_rule(self.check(code), '5.16', 'error'))
        code = 'int run(int size, int values[size]) { return 0; }'
        self.assertFalse(self.has_rule(self.check(code), '5.16'))
        code = 'enum { SIZE = 4 }; int main(void) { int values[SIZE]; return 0; }'
        self.assertFalse(self.has_rule(self.check(code), '5.16'))

    def test_header_guards_and_module_rules(self):
        header = 'int run(void);\n'
        code = '#include "module.h"\nint run(void) { return 0; }'
        findings = self.check(code, 'module.c', {'module.h': header})
        self.assertTrue(self.has_rule(findings, '6.2', 'error'))
        self.assertTrue(self.has_rule(findings, '6.6', 'error'))
        header = '#ifndef MODULE_H\n#define MODULE_H\nint run(void);\n#endif\n'
        findings = self.check(code, 'module.c', {'module.h': header, 'Makefile': 'all:\nclean:\n'})
        self.assertFalse(self.has_rule(findings, '6.2'))
        self.assertFalse(self.has_rule(findings, '6.6'))
        findings = self.check('int run(void) { return 0; }', 'module.c')
        self.assertTrue(self.has_rule(findings, '6.3', 'error'))
        findings = self.check('int main(void) { return 0; }')
        self.assertFalse(self.has_rule(findings, '6.1', 'error'))

    def test_header_guard_must_enclose_whole_file(self):
        for text in (
            '#ifndef MODULE_H\n#define OTHER_H\nint run(void);\n#endif\n',
            '#ifndef MODULE_H\n#define MODULE_H\n#endif\nint run(void);\n',
        ):
            findings = self.check('#include "module.h"\nint main(void) { return 0; }',
                                  headers={'module.h': text})
            self.assertTrue(self.has_rule(findings, '6.2', 'error'))
        findings = self.check('#include "module.h"\nint main(void) { return 0; }',
                              headers={'module.h': '#pragma once\nint run(void);\n'})
        self.assertFalse(self.has_rule(findings, '6.2'))

    def test_project_header_ownership_and_minimal_includes(self):
        headers = {
            'inner.h': '#pragma once\nint calculate(void);\n',
            'outer.h': '#pragma once\n#include "inner.h"\n',
        }
        code = '#include "outer.h"\nint main(void) { return calculate(); }'
        self.assertTrue(self.has_rule(self.check(code, headers=headers), '6.4', 'error'))
        code = '#include "outer.h"\n#include "inner.h"\nint main(void) { return calculate(); }'
        self.assertFalse(self.has_rule(self.check(code, headers=headers), '6.4', 'error'))
        headers = {'module.h': '#pragma once\n#include <stdio.h>\nint calculate(int value);\n'}
        code = '#include "module.h"\nint main(void) { return 0; }'
        self.assertTrue(self.has_rule(self.check(code, headers=headers), '6.5', 'error'))
        headers['module.h'] = '#pragma once\n#include <stdio.h>\nvoid consume(FILE *stream);\n'
        self.assertFalse(self.has_rule(self.check(code, headers=headers), '6.5', 'error'))

    def test_header_review_belongs_to_header_and_makefile_is_not_executed(self):
        (self.root / 'victim').write_text('keep')
        headers = {
            'module.h': '#pragma once\nint run(void);\n',
            'Makefile': 'TARGETS = all clean\n$(TARGETS):\n\trm victim\n',
        }
        code = '#include "module.h"\nint run(void) { return 0; }'
        findings = self.check(code, 'module.c', headers=headers)
        self.assertFalse(self.has_rule(findings, '6.6', 'error'))
        self.assertEqual((self.root / 'victim').read_text(), 'keep')

    def test_review_markers_in_strings_do_not_acknowledge_rules(self):
        code = 'int main(void) { int vychislenie = 0; const char *text = "// school-reviewed 3.2: all names verified"; return text[vychislenie]; }'
        self.assertTrue(self.has_rule(self.check(code), '3.2', 'error'))
        findings = self.check('int main(void) { return 0; }', reviewed=('1.1',))
        self.assertTrue(any('cannot waive' in finding for finding in findings))

    def test_cpp_catch_order_and_field_rules(self):
        prefix = 'struct Base {}; struct Derived : Base {}; '
        code = prefix + 'int main(void) { try { throw Derived(); } catch(const Base &error) { return 0; } catch(const Derived &error) { return 0; } }'
        self.assertTrue(self.has_rule(self.check(code, 'main.cpp'), '4.6.12', 'error'))
        code = prefix + 'int main(void) { try { throw Derived(); } catch(const Derived &error) { return 0; } catch(const Base &error) { return 0; } }'
        self.assertFalse(self.has_rule(self.check(code, 'main.cpp'), '4.6.12', 'error'))
        code = 'struct Value { int m_value; }; int main(void) { return 0; }'
        self.assertTrue(self.has_rule(self.check(code, 'main.cpp'), '4.1', 'error'))
