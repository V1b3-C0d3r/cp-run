"""Promoted warnings may avoid a second build; actual/unknown errors may not."""
import json
import shutil
import subprocess
import unittest
from unittest import mock
import test_school_format as fixtures

engine = fixtures.engine


class StructuredGccTest(unittest.TestCase):
    def test_select_supported_gnu_formats(self):
        for banner, expected in (('gcc (GCC) 11.3.0', 'json'), ('g++ (GCC) 15.2.0', 'json'),
                                 ('g++-16 (Homebrew GCC 16.2.0) 16.2.0', 'sarif-stderr')):
            self.assertEqual(engine.school_gcc_diagnostic_option(banner), '-fdiagnostics-format=' + expected)
        self.assertIsNone(engine.school_gcc_diagnostic_option('gcc (GCC) 8.1.0'))
        self.assertIsNone(engine.school_gcc_diagnostic_option('unknown compiler'))

    def test_json_warning_identity_and_human_locations(self):
        record = [dict(kind='error', option='-Werror=unused-variable', message='unused value',
                       locations=[dict(caret=dict(file='/code/main.c', line=2, column=7))], children=[])]
        only_warnings, text = engine.school_gcc_diagnostics(json.dumps(record))
        self.assertTrue(only_warnings)
        self.assertIn('/code/main.c:2:7: error: unused value [-Werror=unused-variable]', text)

    def test_forged_warning_text_does_not_disguise_a_real_error(self):
        for record in (
            [dict(kind='error', message='#error pretend [-Werror=unused-variable]', locations=[])],
            dict(version='2.1.0', runs=[dict(results=[dict(level='error', ruleId='error',
                 message=dict(text='#error pretend [-Werror=unused-variable]'))])]),
        ):
            self.assertFalse(engine.school_gcc_diagnostics(json.dumps(record))[0])

    def test_nested_error_and_mixed_errors_stay_conservative(self):
        record = [dict(kind='error', option='-Werror=unused-variable', message='unused',
                       children=[dict(kind='error', message='actual error')])]
        self.assertFalse(engine.school_gcc_diagnostics(json.dumps(record))[0])

    def test_sarif_warning_and_percent_encoded_filename(self):
        record = dict(version='2.1.0', runs=[dict(invocations=[dict(executionSuccessful=False)],
            results=[dict(level='error', ruleId='-Werror=unused-variable', message=dict(text='unused'),
                locations=[dict(physicalLocation=dict(artifactLocation=dict(uri='file:///code/a%20b.c'),
                    region=dict(startLine=3, startColumn=5)))])])])
        only_warnings, text = engine.school_gcc_diagnostics(json.dumps(record))
        self.assertTrue(only_warnings)
        self.assertIn('/code/a b.c:3:5: error: unused', text)

    def test_malformed_or_incomplete_tool_output_is_not_trusted(self):
        records = ('not json', '{}', '[null]', '[] trailing', '{"version":"other"}',
                   json.dumps(dict(version='2.1.0', runs=[dict(invocations=[
                       dict(toolExecutionNotifications=[dict(level='error')])])])))
        for text in records:
            self.assertIsNone(engine.school_gcc_diagnostics(text), text)

    def test_early_termination_options_do_not_claim_a_complete_warning_pass(self):
        for argument in ('-Wfatal-errors', '-fmax-errors=1'):
            record = dict(version='2.1.0', runs=[dict(invocations=[dict(arguments=[argument])],
                results=[dict(level='error', ruleId='-Werror=unused-variable', message=dict(text='unused'))])])
            self.assertIsNone(engine.school_gcc_diagnostics(json.dumps(record)))

    def test_unknown_structured_format_retries_with_native_output(self):
        source = subprocess.CompletedProcess([], 1, '', 'unsupported diagnostic format')
        native = subprocess.CompletedProcess([], 1, '', 'native error')
        with mock.patch.object(engine, 'school_tool', side_effect=[source, native]) as tool:
            checked, warning_only = engine.school_gcc_check(['gcc', 'main.c'], ['-O2', '-Wall', '-Werror'],
                                                          'main.o', 'main.d', 'gcc (GCC) 16.2.0')
        self.assertEqual(checked.stderr, 'native error')
        self.assertFalse(warning_only)
        self.assertEqual(tool.call_count, 2)
        self.assertNotIn('-fdiagnostics-format=sarif-stderr', tool.call_args.args[0])


@unittest.skipUnless(shutil.which('clang') and shutil.which('clang-format'), 'needs school tools')
class RealGccDiagnosticsTest(unittest.TestCase):
    def setUp(self):
        self.case = fixtures.SchoolFormatTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)

    def test_only_promoted_warnings_do_not_compile_twice(self):
        source = self.case.source
        source.write_text('int main(void) { int unused; return 0; }\n')
        calls = []
        real = engine.school_tool
        def capture(argv, **options):
            calls.append(argv)
            return real(argv, **options)
        with mock.patch.object(engine, 'school_tool', side_effect=capture), \
             mock.patch.object(engine, 'school_syntax_gate', wraps=engine.school_syntax_gate) as gate:
            result = engine.school_analyze(dict(protected=[str(source)], prettier='format', format_cache=False))
        self.assertTrue(any(item.rule == 'GCC' and 'unused' in item.message for item in result.errors))
        self.assertEqual(sum('-c' in args for args in calls), 1)
        self.assertEqual(gate.call_count, 0)

    def test_actual_syntax_error_never_publishes_layout(self):
        source = self.case.source
        original = '#error pretend [-Werror=unused-variable]\nint main(){return 0;}\n'
        source.write_text(original)
        with self.assertRaisesRegex(engine.CheckSetupError, 'syntax prevents safe publication'):
            engine.format_collect(dict(protected=[str(source)], format_mode='school', prettier='format', format_cache=False))
        self.assertEqual(source.read_text(), original)
