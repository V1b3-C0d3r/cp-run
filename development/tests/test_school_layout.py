"""Byte-level school layout contracts, followed by a real Clang reparse."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from _paths import load_engine

engine = load_engine('school_layout_contracts')

LAYOUT_CASES = [
    ('1.2', 'int main(void) {\n\treturn 0;\n}\n', '    return 0;'),
    ('2.1', 'int main(void){int value=0;if(value){value++;}return value;}',
     '    if (value) {\n        value++;\n    }'),
    ('4.1', 'struct Node{int first;int second;};int main(void){return 0;}',
     'struct Node {\n    int first;\n    int second;\n};'),
    ('4.2', 'enum Colours{RED,GREEN};int main(void){return RED;}',
     'enum Colours {\n    RED,\n    GREEN\n};'),
    ('4.3', 'int main(void){int* first=0;int** second=0;return first==0&&second==0;}',
     'int **second = 0;'),
    ('4.4.2', 'int main(void){int\nvalue\n=\n0;return value;}', '    int value = 0;'),
    ('4.4.3', 'int main(void){char message[] =\n"short";return message[0];}',
     'char message[] = "short";'),
    ('4.5.1', 'static inline char*copy_str(const char*text){return 0;}',
     'static inline char *\ncopy_str(const char *text) {'),
    ('4.5.2', 'int main(){return 0;}', 'main(void) {'),
    ('4.6.1', 'int main(void){int value=0;if(value){value++;}return value;}',
     'if (value) {\n        value++;'),
    ('4.6.2', 'int main(void){int value=0;if(value){value++;}else{value--;}return value;}',
     '} else {\n        value--;'),
    ('4.6.3', 'int main(void){int value=0;if(value){value++;}else if(!value){value--;}else{value=0;}return value;}',
     '} else if (!value) {'),
    ('4.6.4', 'int main(void){int value=0;while(value){value--;}return value;}',
     'while (value) {\n        value--;'),
    ('4.6.5', 'int main(void){int value=0;do{value++;}while(value);return value;}',
     '} while (value);'),
    ('4.6.6', 'int main(void){int value=0;for(int index=0;index<1;++index){value++;}return value;}',
     'for (int index = 0; index < 1; ++index) {'),
    ('4.6.7', 'int main(void){int value=0;switch(value){case 0:++value;break;default:break;}return value;}',
     '    switch (value) {\n    case 0:\n        ++value;'),
    ('4.6.8', 'int main(void){int value=0;if(value)++value;while(value)--value;for(;;)break;do ++value;while(value);return value;}',
     'for (;;) {\n        break;\n    }'),
    ('4.6.9', 'int main(void){int value=0;value++;value--;return value;}',
     '    value++;\n    value--;'),
    ('4.6.10', 'int main(void){if(1){goto done;done:;}return 0;}',
     '\ndone:\n        ;'),
    ('4.7.1', 'int main(void){int first=0,second=1;return first+second;}',
     'return first + second;'),
    ('4.7.2', 'struct Node{int value;};int main(void){struct Node node={0};struct Node*ptr=&node;return ptr -> value;}',
     'return ptr->value;'),
    ('4.7.3', 'int main(void){int first=0,second=1;return first+second;}',
     'int first = 0, second = 1;'),
    ('4.7.4', 'int main(void){int value=0;int*ptr=&value;return * ptr ++;}',
     'return *ptr++;'),
    ('4.7.5', 'int value(void);int main (void){return value ( );}', 'return value();'),
    ('4.7.6', 'int main(void){int first=0,second=1;return ( first + second );}',
     'return (first + second);'),
    ('4.7.7', 'int main(void){char text[1]={0};unsigned char*other=(unsigned char*)text;return other[0];}',
     '(unsigned char *) text'),
]


@unittest.skipUnless(shutil.which('clang-format') and shutil.which('clang'), 'needs school layout tools')
class SchoolLayoutTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='school-layout-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.clang = shutil.which('clang')
        self.formatter = shutil.which('clang-format')

    def layout(self, text, filename='main.c'):
        source = self.root / filename
        source.write_text(text)
        candidate, issues = engine.school_prepare(source, text, self.clang)
        self.assertEqual(issues, [])
        formatted = engine.school_tool([self.formatter, '--style=' + json.dumps(engine.SCHOOL_STYLE),
            '--assume-filename=' + str(source)], input=candidate, text=True, capture_output=True)
        self.assertEqual(formatted.returncode, 0, formatted.stderr)
        candidate, tree, issues = engine.school_apply_layout(source, formatted.stdout, self.clang)
        self.assertEqual(issues, [])
        return candidate

    def test_layout_rule_fixtures_are_idempotent_and_reparse(self):
        for rule, source, expected in LAYOUT_CASES:
            with self.subTest(rule=rule):
                result = self.layout(source)
                self.assertIn(expected, result)
                self.assertNotIn('\t', result)
                self.assertEqual(self.layout(result), result)

    def test_T2_2_unicode_width_boundary_and_controls(self):
        for width in (100, 101):
            code = '// ' + 'я' * (width - 3) + '\nint main(void) { return 0; }\n'
            source = self.root / 'main.c'
            tree, issues = engine.school_parse(source, code, self.clang)
            self.assertEqual(issues, [])
            findings = engine.SchoolPolicy(source, code, tree).run()
            self.assertEqual(any('school 2.2 error' in finding for finding in findings), width > 100)

    def test_T2_3_continuation_uses_eight_extra_spaces(self):
        code = ('int very_long_argument_number_one; int very_long_argument_number_two; '
                'int very_long_argument_number_three; int very_long_argument_number_four; '
                'int main(void) { if (very_long_argument_number_one && very_long_argument_number_two && '
                'very_long_argument_number_three && very_long_argument_number_four) { return 1; } return 0; }')
        result = self.layout(code)
        self.assertIn('\n            very_long_argument_number_', result)
        self.assertEqual(self.layout(result), result)

    def test_T4_5_3_seventy_character_threshold_and_parameter_ranges(self):
        for code in (
            'int combine_values(int first_parameter, int second_parameter, int third_parameter) { return first_parameter; }',
            'int combine_values(int (*operation)(int, int), int first_parameter, int second_parameter) { return first_parameter; }',
            'int combine_values(const char *very_long_format_string, const char *very_long_prefix, ...) { return 0; }',
        ):
            with self.subTest(source=code):
                result = self.layout(code)
                self.assertIn('combine_values(\n        ', result)
                self.assertIn(')\n{', result)
                self.assertEqual(self.layout(result), result)
        short = self.layout('int sum(int first, int second) { return first + second; }')
        self.assertIn('sum(int first, int second) {', short)

    def test_T4_6_12_try_catch_layout(self):
        result = self.layout('int main(){try{throw 0;}catch(int value){return value;}}', 'main.cpp')
        self.assertIn('} catch (int value) {', result)
        self.assertEqual(self.layout(result, 'main.cpp'), result)
