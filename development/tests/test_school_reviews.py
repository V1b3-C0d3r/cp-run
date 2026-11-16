"""Review obligations are explicit, file-scoped and never waive proven violations."""
import shutil
import unittest
import test_school_format as cli_cases
import test_school_policy as policy_cases


@unittest.skipUnless(shutil.which('clang'), 'needs Clang')
class SchoolReviewPolicyTest(unittest.TestCase):
    def setUp(self):
        self.case = policy_cases.SchoolPolicyTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)

    def test_missing_and_specific_review(self):
        code = 'int main(void) { int count = 0; return count; }'
        findings = self.case.check(code)
        self.assertTrue(self.case.has_rule(findings, '3.2', 'review required'))
        reviewed = self.case.check(code, reviewed=('3.2', '3.5', '5.7'))
        self.assertFalse(reviewed, reviewed)

    def test_known_english_violations_cannot_be_reviewed_away(self):
        for name in ('f', 'vychislenie_kornya', 'переменная'):
            with self.subTest(name=name):
                code = 'int ' + name + '(void) { return 0; } int main(void) { return ' + name + '(); }'
                findings = self.case.check(code, reviewed=('3.1', '3.2', '3.4'))
                self.assertTrue(self.case.has_rule(findings, '3.2', 'error'))

    def test_invalid_markers_fail_even_without_review_obligations(self):
        markers = [
            '// school-reviewed 99.1: This number is not a known rule.',
            '// school-reviewed 3.2: checked',
            '// school-reviewed 1.1: Controls cannot be approved by the author.',
            '// school-reviewed 3.2 no colon or reason',
        ]
        for marker in markers:
            with self.subTest(marker=marker):
                findings = self.case.check(marker + '\nint main(void) { return 0; }')
                self.assertTrue(any('school-review error:' in item for item in findings), findings)

    def test_block_comment_review_and_literal_spoof(self):
        code = ('/*\n * school-reviewed 3.2: count denotes the number of items.\n'
                ' * school-reviewed 3.5: count contains no Hungarian type marker.\n'
                ' */\nint main(void) { int count = 0; if (count) { return 1; } return 0; }')
        findings = self.case.check(code)
        self.assertFalse(self.case.has_rule(findings, '3.2'))
        self.assertFalse(self.case.has_rule(findings, '3.5'))
        self.case.test_review_markers_in_strings_do_not_acknowledge_rules()

    def test_source_cannot_review_a_header_requirement(self):
        header = '#pragma once\n#include <stdio.h>\n#if defined(BUFSIZ)\nvoid consume(FILE *stream);\n#endif\n'
        source = '#include "module.h"\nint main(void) { return 0; }'
        findings = self.case.check(source, headers={'module.h': header}, reviewed=('6.5',))
        pending = [item for item in findings if 'school 6.5 review required:' in item]
        self.assertTrue(pending, findings)
        self.assertTrue(all('module.h:' in item for item in pending))
        reviewed_header = '// school-reviewed 6.5: FILE in this public interface requires stdio under the guard.\n' + header
        findings = self.case.check(source, headers={'module.h': reviewed_header})
        self.assertFalse(self.case.has_rule(findings, '6.5', 'review required'), findings)


@unittest.skipUnless(shutil.which('clang-format') and shutil.which('clang'), 'needs school tools')
class SchoolReviewCliTest(unittest.TestCase):
    def setUp(self):
        self.case = cli_cases.SchoolFormatTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)

    def test_pending_review_allows_layout_but_blocks_success_until_resolved(self):
        source = self.case.source
        code = 'int main(void){int count=0;if(count)return 1;return 0;}'
        source.write_text(code)
        result = self.case.invoke('--school', source)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('review required', result.stderr)
        self.assertNotEqual(source.read_text(), code)
        comments = ('// school-reviewed 3.2: count is the English count of items.\n'
                    '// school-reviewed 3.5: count has no type-encoding prefix or suffix.\n')
        source.write_text(comments + code)
        result = self.case.invoke('--school', source)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('if (count) {', source.read_text())
        checked = self.case.invoke('--school', source, '--check')
        self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_unsafe_call_and_real_leak_stay_errors(self):
        source = self.case.source
        code = ('// school-reviewed 5.8: This assertion cannot authorize strcpy.\n'
                '#include <string.h>\nint main(void) { char data[1]; strcpy(data, ""); return 0; }')
        source.write_text(code)
        result = self.case.invoke('--school', source)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('5.8 error:', result.stderr)
        self.assertNotEqual(source.read_text(), code)
        self.case.test_resource_analyzer_finds_leak_despite_author_review()
