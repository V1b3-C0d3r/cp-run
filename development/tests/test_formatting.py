"""Formatting is a terminal source action, with no compiler or program launch."""

import json
from pathlib import Path
import shutil
import sys
import unittest

from _paths import load_engine
import test_cli as fixtures

engine = load_engine('cp_run_formatting_tests')


class FormattingTest(unittest.TestCase):
    setUp_fixture = fixtures.CliTest.setUp
    tearDown = fixtures.CliTest.tearDown
    calls = fixtures.CliTest.calls

    def setUp(self):
        self.setUp_fixture()
        self.script = self.root / 'configured.zsh'
        shutil.copy2(fixtures.SCRIPT, self.script)
        self.tool = self.root / 'formatter'
        self.format_log = self.root / 'formatted.jsonl'
        self.tool.write_text('#!' + sys.executable + '\n' +
            'import json,os,pathlib,sys\n'
            'with open(os.environ["FORMAT_LOG"],"a") as f: f.write(json.dumps(sys.argv[1:])+"\\n")\n'
            'print("formatter stdout")\nprint("formatter stderr",file=sys.stderr)\n'
            'if os.environ.get("FORMAT_STATUS"): sys.exit(int(os.environ["FORMAT_STATUS"]))\n'
            'if "--check" in sys.argv or "--dry-run" in sys.argv: sys.exit(1)\n'
            'p=pathlib.Path(sys.argv[-1]); p.write_text(p.read_text()+"\\n"+("#" if p.suffix==".py" else "//")+" formatted\\n")\n')
        self.tool.chmod(0o755)
        self.save(NATIVE_FORMATTER=str(self.tool), PYTHON_FORMATTER=str(self.tool))

    def save(self, **values):
        source = self.script.read_text(); data = engine.read_settings(source); data.update(values)
        engine.save_settings(self.script, source, data)

    def environment(self, overrides=None):
        result = fixtures.CliTest.environment(self, overrides)
        result['FORMAT_LOG'] = str(self.format_log)
        return result

    def invoke(self, *args, **options):
        return fixtures.CliTest.invoke(self, *args, script=self.script, **options)

    def formatted(self):
        return [json.loads(row) for row in self.format_log.read_text().splitlines()] if self.format_log.exists() else []

    def test_bare_flag_never_compiles_runs_or_queries_a_compiler(self):
        for prefix in ((), ('compile',), ('debug',), ('debug', 'run'), ('test',)):
            with self.subTest(prefix=prefix):
                result = self.invoke(*prefix, self.source, '--make-prettier', env={'CXX': '/missing/compiler'})
                self.assertEqual((result.returncode, result.stdout), (0, ''), result.stderr)
                self.assertIn('formatter stdout', result.stderr)
                self.assertIn('formatter stderr', result.stderr)
        self.assertEqual(self.calls(include_probes=True), [])
        self.assertFalse((self.cwd / 'main file.out').exists())
        self.assertFalse((self.cwd / 'out.txt').exists())
        self.assertFalse((self.cwd / 'test_out').exists())

    def test_discovery_and_python_file_only_format_without_running(self):
        self.assertEqual(self.invoke('--make-prettier').returncode, 0)
        source = self.cwd / 'main.py'; source.write_text('raise RuntimeError("must not run")\n')
        result = self.invoke(source, '--make-prettier', env={'CP_RUN_DO_NOT_RUN': '1'})
        self.assertEqual((result.returncode, result.stdout), (0, ''), result.stderr)
        self.assertIn('# formatted', source.read_text())
        self.assertEqual(self.formatted()[-1][0], 'format')
        self.assertEqual(self.calls(include_probes=True), [])

    def test_check_requires_attached_value_and_keeps_source_unchanged(self):
        original = self.source.read_bytes()
        for options in (('--make-prettier=check',),):
            result = self.invoke(self.source, *options)
            self.assertEqual((result.returncode, result.stdout), (1, ''), result.stderr)
            self.assertEqual(self.source.read_bytes(), original)
            self.assertIn('--dry-run', self.formatted()[-1])
        self.assertEqual(self.calls(include_probes=True), [])

    def test_removed_modes_and_runtime_build_options_are_rejected(self):
        for options in (('--make-prettier=only',), ('--make-prettier=before',),
                        ('--make-prettier=',), ('--make-prettier', 'only'), ('--make-prettier', 'check'),
                        ('--make-prettier', '-t'), ('--make-prettier', '-f'),
                        ('--make-prettier', '-o', 'ignored.out'),
                        ('--make-prettier', '--out=ignored.txt'),
                        ('--make-prettier', '--', '-O2')):
            with self.subTest(options=options):
                result = self.invoke(self.source, *options)
                self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse(self.format_log.exists())
        self.assertEqual(self.calls(include_probes=True), [])

    def test_stress_formats_every_unique_source_and_never_executes_roles(self):
        generator = self.cwd / 'gen.py'; generator.write_text('raise RuntimeError("must not run")\n')
        result = self.invoke('stress', self.source, self.source, generator, '--make-prettier')
        self.assertEqual((result.returncode, result.stdout), (0, ''), result.stderr)
        self.assertEqual([Path(args[-1]) for args in self.formatted()], [self.source, generator])
        self.assertEqual(self.calls(include_probes=True), [])
        self.assertFalse((self.cwd / 'test_out').exists())

    def test_missing_later_formatter_is_detected_before_the_first_edit(self):
        generator = self.cwd / 'gen.py'; generator.write_text('print(1)\n')
        self.save(PYTHON_FORMATTER='/missing/formatter')
        original = self.source.read_bytes()
        result = self.invoke('stress', self.source, self.source, generator, '--make-prettier')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('optional formatter not found', result.stderr)
        self.assertEqual(self.source.read_bytes(), original)
        self.assertFalse(self.format_log.exists())

    def test_formatter_failure_status_is_preserved_without_building(self):
        result = self.invoke(self.source, '--make-prettier', env={'FORMAT_STATUS': '7'})
        self.assertEqual((result.returncode, result.stdout), (7, ''), result.stderr)
        self.assertEqual(self.calls(include_probes=True), [])

    def test_workspace_prefix_and_source_history_are_supported(self):
        source = self.ws / 'root.cpp'; source.write_text('int main(){}\n')
        result = self.invoke('{wsp-dir}/root.cpp', '--wsp-dir=..', '--make-prettier', '--dest-dir=../unused')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(Path(self.formatted()[-1][-1]), source)
        prepared = self.invoke('compile', self.source)
        self.assertEqual(prepared.returncode, 0, prepared.stderr)
        before = self.calls(include_probes=True)
        result = self.invoke('-', '--make-prettier')
        self.assertEqual((result.returncode, result.stdout), (0, ''), result.stderr)
        self.assertEqual(Path(self.formatted()[-1][-1]), self.source)
        self.assertEqual(self.calls(include_probes=True), before)


if __name__ == '__main__':
    unittest.main()
