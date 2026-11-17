"""Only source-local, severity-specific exceptions mute concrete findings."""
import shutil
import unittest
import test_school_policy as policy_cases
import test_school_format as cli_cases


@unittest.skipUnless(shutil.which('clang'), 'needs Clang')
class SchoolReviewPolicyTest(unittest.TestCase):
    def setUp(self):
        self.case = policy_cases.SchoolPolicyTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)

    def test_ordinary_names_and_unknown_meaning_need_no_review(self):
        findings = self.case.check('int calculate(void) { int count = 0; return count; }')
        self.assertFalse(any(item.severity == 'warning' for item in findings), findings)

    def test_known_name_violations_remain_errors_with_legacy_reviews(self):
        for name, rule in (('f', '3.1'), ('vychislenie_kornya', '3.2'), ('переменная', '3.2')):
            with self.subTest(name=name):
                code = 'int ' + name + '(void) { return 0; } int main(void) { return ' + name + '(); }'
                findings = self.case.check(code, reviewed=('3.1', '3.2', '3.4'))
                self.assertTrue(self.case.has_rule(findings, rule, 'error'))

    def test_invalid_legacy_markers_have_structured_errors(self):
        markers = ['// school-reviewed 99.1: This is an unknown rule.',
                   '// school-reviewed 3.2: checked',
                   '// school-reviewed 1.1: Controls cannot be approved by a legacy marker.',
                   '// school-reviewed 3.2 no colon']
        for marker in markers:
            findings = self.case.check(marker + '\nint main(void) { return 0; }')
            self.assertTrue(any(item.rule == 'review-comment' and item.severity == 'error'
                                for item in findings), findings)

    def test_literal_cannot_create_an_exception(self):
        code = ('int main(void) { const char *text = "/* school-error-justified 3.4 */";'
                ' int BadName = 0; return text[BadName]; }')
        self.assertTrue(self.case.has_rule(self.case.check(code), '3.4', 'error'))

    def test_warning_justification_does_not_mute_error(self):
        code = 'int main(void) {\n/* school-justified 3.4 */\nint BadName = 0; return BadName;\n}'
        self.assertTrue(self.case.has_rule(self.case.check(code), '3.4', 'error'))
        code = code.replace('school-justified', 'school-error-justified')
        self.assertFalse(self.case.has_rule(self.case.check(code), '3.4'))

    def test_source_cannot_justify_a_header_error(self):
        header = 'int calculate(void);\n'
        code = '/* school-error-justified 6.2 */\n#include "module.h"\nint main(void) { return 0; }'
        findings = self.case.check(code, headers={'module.h': header})
        errors = [item for item in findings if item.rule == '6.2' and item.severity == 'error']
        self.assertTrue(errors, findings)
        self.assertTrue(all('module.h' in item.source for item in errors))

    def test_unknown_project_obligations_do_not_emit_blanket_warnings(self):
        code = '#include "module.h"\nint main(void) { return 0; }'
        header = '#pragma once\n#include <stdio.h>\n#if defined(BUFSIZ)\nvoid consume(FILE *stream);\n#endif\n'
        findings = self.case.check(code, headers={'module.h': header})
        self.assertFalse(any(item.severity == 'warning' and item.rule.startswith('6.') for item in findings), findings)


@unittest.skipUnless(shutil.which('clang') and shutil.which('clang-format'), 'needs formatters')
class SchoolReviewCliTest(unittest.TestCase):
    def setUp(self):
        self.case = cli_cases.SchoolFormatTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)

    def test_plain_program_formats_without_name_assertions(self):
        self.case.source.write_text('int main(void){int count=0;if(count)return 1;return 0;}')
        result = self.case.invoke('--school', self.case.source)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('review', result.stderr)
        self.assertIn('if (count) {', self.case.source.read_text())
        checked = self.case.invoke('--school', self.case.source, '--check')
        self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_unsafe_call_and_real_leak_are_errors_without_explicit_exception(self):
        self.case.source.write_text('#include <string.h>\nint main(void) { char data[1]; strcpy(data, ""); return 0; }')
        result = self.case.invoke('--school', self.case.source)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('5.8 error', result.stderr)
        self.case.test_resource_analyzer_finds_leak_despite_author_review()
