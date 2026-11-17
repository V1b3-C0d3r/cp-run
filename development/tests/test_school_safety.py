"""Real unreadable-code formatting and rejection of non-layout transformations."""
from pathlib import Path
import shutil
import subprocess
import sys
import copy
import unittest
import test_school_format as cli_cases
import test_school_layout as layout_cases

engine = cli_cases.engine


@unittest.skipUnless(shutil.which('clang') and shutil.which('clang-format'), 'needs school tools')
class SchoolAstSafetyTest(unittest.TestCase):
    def setUp(self):
        self.case = layout_cases.SchoolLayoutTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)
        self.source = self.case.root / 'main.c'

    def parsed(self, text, filename='main.c'):
        self.source = self.case.root / filename
        tree, issues = engine.school_parse(self.source, text, self.case.clang)
        self.assertEqual(issues, [], issues)
        return tree

    def test_lambda_coordinates_change_without_changing_closure_identity(self):
        original = ('template<class Fn> int apply(Fn fn){return fn();}'
                    'int main(){auto first=[](){return 0;};auto second=[](){return 1;};'
                    'return apply(first)+apply(second);}')
        before = self.parsed(original, 'main.cpp')
        candidate = engine.school_tool(
            [shutil.which('clang-format'), '--style=' + engine.json.dumps(engine.SCHOOL_STYLE)],
            input=original, capture_output=True, text=True).stdout
        after = self.parsed(candidate, 'main.cpp')
        engine.school_verify_layout(self.source, original, before, candidate, after)
        signature = engine.school_ast_signature(candidate, after)
        self.assertIn('<source-lambda-0>', repr(signature))
        self.assertIn('<source-lambda-1>', repr(signature))
        changed = copy.deepcopy(after)
        second = next(node for node in engine.school_nodes(changed)
                      if node.get('kind') == 'VarDecl' and node.get('name') == 'second')
        for node in engine.school_nodes(changed):
            reference = node.get('referencedDecl', {})
            if reference.get('kind') == 'VarDecl' and reference.get('name') == 'first':
                reference['id'] = second['id']
        self.assertNotEqual(signature, engine.school_ast_signature(candidate, changed))

    def test_ugly_dangling_else_and_literal_data_are_preserved(self):
        text = 'int main(){int first=0,second=1;char text[]="x;a+b{ else }";if(first)if(second)return text[0];else return 0;return 0;}'
        candidate = self.case.layout(text)
        engine.school_verify_layout(self.source, text, self.parsed(text), candidate, self.parsed(candidate))
        self.assertIn('"x;a+b{ else }"', candidate)
        self.assertEqual(self.case.layout(candidate), candidate)

    def test_changed_literal_is_rejected(self):
        before = 'int main(void) { return 0; }'
        after = 'int main(void) { return 1; }'
        with self.assertRaisesRegex(engine.CheckSetupError, 'non-layout tokens'):
            engine.school_verify_layout(self.source, before, self.parsed(before), after, self.parsed(after))

    def test_rebinding_else_is_rejected_even_when_nonbrace_tokens_match(self):
        before = 'int main(){int first=0,second=0;if(first)if(second)return 1;else return 0;return 0;}'
        after = 'int main(void){int first=0,second=0;if(first){if(second)return 1;}else return 0;return 0;}'
        with self.assertRaisesRegex(engine.CheckSetupError, 'parsed program'):
            engine.school_verify_layout(self.source, before, self.parsed(before), after, self.parsed(after))

    def test_exported_macro_body_is_preserved_even_when_unused(self):
        before = '#define TYPE void\nint main(void) { return 0; }'
        after = '#define TYPE int\nint main(void) { return 0; }'
        with self.assertRaisesRegex(engine.CheckSetupError, 'non-layout tokens'):
            engine.school_verify_layout(self.source, before, self.parsed(before), after, self.parsed(after))

    def test_cpp_raw_strings_and_digit_separators_are_not_code(self):
        text = ('const char *text=R"tag(raw "quote"\n// school-reviewed 3.2: fake marker inside data.\n)tag";'
                "int main(){int count=1'000;return text[0]=='x'&&count?1:0;}")
        candidate = self.case.layout(text, 'main.cpp')
        original_tree = self.parsed(text, 'main.cpp')
        tree = self.parsed(candidate, 'main.cpp')
        engine.school_verify_layout(self.source, text, original_tree, candidate, tree)
        policy = engine.SchoolPolicy(self.source, candidate, tree)
        self.assertNotIn('3.2', policy.reviews)
        self.assertIn("1'000", candidate)

    def test_empty_body_braces_preserve_control_flow(self):
        text = 'int main(void){int count=0;while(count);if(count);else count++;for(;count;);return 0;}'
        candidate = self.case.layout(text)
        engine.school_verify_layout(self.source, text, self.parsed(text), candidate, self.parsed(candidate))
        self.assertIn('while (count) {', candidate)

    def test_cpp_overload_does_not_block_empty_signature_formatting(self):
        text = 'int value(){return 0;} int value(int count){return count;} int main(){return value(0);}'
        candidate = self.case.layout(text, 'main.cpp')
        self.assertIn('value(void)', candidate)
        engine.school_verify_layout(self.source, text, self.parsed(text, 'main.cpp'),
                                    candidate, self.parsed(candidate, 'main.cpp'))

    def test_parameter_default_literal_keeps_internal_spaces(self):
        text = ('int combine_very_long_parameter_name(const char *first = "two  spaces", '
                'const char *second = "a"){return first[0] == second[0];} int main(){return 0;}')
        candidate = self.case.layout(text, 'main.cpp')
        self.assertIn('"two  spaces"', candidate)
        engine.school_verify_layout(self.source, text, self.parsed(text, 'main.cpp'),
                                    candidate, self.parsed(candidate, 'main.cpp'))

    def test_T4_5_3_exact_seventy_and_seventy_one_columns(self):
        for width in (70, 71):
            name = 'parameter_' + 'x' * (width - len('combine_values(int ) {') - len('parameter_'))
            text = 'int combine_values(int ' + name + ') { return ' + name + '; }'
            result = self.case.layout(text)
            self.assertEqual('combine_values(\n' in result, width == 71, result)
            self.assertEqual(self.case.layout(result), result)


class SchoolPracticalCliTest(unittest.TestCase):
    def setUp(self):
        self.case = cli_cases.SchoolFormatTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)

    def test_real_sort_lambda_can_be_formatted_and_checked(self):
        source = self.case.root / 'main.cpp'
        source.write_text('#include <algorithm>\nenum{LENGTH=3};'
                          'int main(){int values[LENGTH]={2,1,0};'
                          'std::sort(values,values+LENGTH,[](int lhs,int rhs){return lhs<rhs;});return 0;}')
        result = self.case.invoke('--school', source)
        self.assertEqual(result.returncode, 0, result.stderr)
        checked = self.case.invoke('--school', source, '--check')
        self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_real_ugly_code_is_beautified_without_unverifiable_reviews(self):
        text = '#include <stdio.h>\nint main(){int n=0;scanf("%d",&n);if(n)printf("%d\\n",n);return 0;}'
        self.case.source.write_text(text)
        result = self.case.invoke('--school', self.case.source)
        self.assertEqual(result.returncode, 0, result.stderr)
        actual = self.case.source.read_text()
        self.assertNotEqual(actual, text)
        self.assertIn('main(void)', actual)
        self.assertIn('    if (n) {', actual)
        self.assertNotIn('review required', result.stderr)
        self.assertIn('scanf("%d", &n);', actual)

    def test_syntax_error_never_overwrites_source(self):
        text = 'int main( { broken;'
        self.case.source.write_text(text)
        result = self.case.invoke('--school', self.case.source)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.case.source.read_text(), text)

    def test_valid_GNU_nested_function_gets_conservative_layout_and_explicit_error(self):
        text = 'int main(void){int nested(void){return 0;}return nested();}'
        self.case.source.write_text(text)
        result = self.case.invoke('--school', self.case.source)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertNotEqual(self.case.source.read_text(), text)
        self.assertIn('token layout only', result.stderr)

    def test_formatter_cannot_change_a_valid_program(self):
        formatter = self.case.root / 'bad-formatter'
        formatter.write_text('#!' + sys.executable + '\nprint("int main(void) { return 1; }")\n')
        formatter.chmod(0o755)
        script = self.case.root / 'configured'
        shutil.copy2(cli_cases.RELEASE / 'cp-run.zsh', script)
        original = script.read_text()
        data = engine.read_settings(original)
        data['NATIVE_FORMATTER'] = str(formatter)
        engine.save_settings(script, original, data)
        self.case.source.write_text('int main(void) { return 0; }')
        result = subprocess.run([str(script), 'format', '--school', str(self.case.source)],
                                cwd=self.case.root, env=self.case.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('non-layout tokens', result.stderr)
        self.assertEqual(self.case.source.read_text(), 'int main(void) { return 0; }')
