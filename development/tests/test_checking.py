"""Checker/stress contracts with real child programs and bounded comparisons."""

from contextlib import redirect_stderr, redirect_stdout
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest import mock


from _paths import ROOT, load_engine
ENGINE = load_engine('cp_run_checking_test_engine')


class CheckingTest(unittest.TestCase):
    def setUp(self):
        self.original = Path.cwd()
        self.temporary = tempfile.TemporaryDirectory()
        os.chdir(self.temporary.name)
        self.directory = Path.cwd()
        self.binary = self.program("solver.out", "import sys\nsys.stdout.buffer.write(sys.stdin.buffer.read())\n")
        Path("input.txt").write_bytes(b"hello\n")
        Path("ans.txt").write_bytes(b"hello\n")
        self.config = {"operation": "test", "executable": str(self.binary)}

    def tearDown(self):
        os.chdir(self.original)
        self.temporary.cleanup()

    def program(self, name, code):
        path = Path(name).absolute()
        path.write_text("#!" + sys.executable + "\n" + code)
        path.chmod(0o755)
        return path

    def execute(self, config=None, stress=False):
        stdout, stderr = io.StringIO(), io.StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            status = (ENGINE.execute_stress if stress else ENGINE.execute_test)(dict(config or self.config))
        return status, stdout.getvalue(), stderr.getvalue()

    def auto(self, incoming=b"a\n\nb\n\nc\n", answer=None, **extra):
        Path("input.txt").write_bytes(incoming)
        Path("ans.txt").write_bytes(incoming if answer is None else answer)
        self.config.update(auto=True, **extra)
        return self.config

    def stress(self, main=None, **extra):
        generator = self.program("generator.out", "import sys\nprint(sys.argv[1])\n")
        reference = self.program("reference.out", "import sys\nsys.stdout.buffer.write(sys.stdin.buffer.read())\n")
        return {"operation": "stress", "executable": str(main or self.binary),
                "brute": str(reference), "generator": str(generator),
                "seed": "17", "iterations": 3, **extra}

    def test_default_normal_test_is_useful_without_configuration(self):
        status, stdout, stderr = self.execute()
        self.assertEqual(status, 0)
        self.assertEqual(stdout, "")
        self.assertIn("PASS", stderr)
        self.assertEqual(Path("real-out.txt").read_bytes(), b"hello\n")
        self.assertIn("Test 1: OK", Path("test_out").read_text())
        self.assertFalse(any(p.name.startswith(".cp-run-") for p in Path.cwd().iterdir()))

    def test_wrong_answer_reports_full_three_sections_and_line_numbers(self):
        Path("ans.txt").write_text("expected\n")
        status, _, _ = self.execute()
        report = Path("test_out").read_text()
        self.assertEqual(status, 3)
        self.assertIn('input:1 | "hello"', report)
        self.assertIn('! real-out.txt:1 | "hello"', report)
        self.assertIn('! ans:1 | "expected"', report)

    def test_inserted_answer_line_retains_both_files_numbers(self):
        Path("input.txt").write_text("first\nlast\n")
        Path("ans.txt").write_text("first\ninserted\nlast\n")
        self.assertEqual(self.execute()[0], 3)
        report = Path("test_out").read_text()
        self.assertIn('ans:2 | "inserted"', report)
        self.assertIn('real-out.txt:2 | "last"', report)
        self.assertIn('real-out.txt:— | <missing line>; ans:2', report)

    def test_deleted_answer_line_marks_missing_answer(self):
        Path("input.txt").write_text("first\ninserted\nlast\n")
        Path("ans.txt").write_text("first\nlast\n")
        self.assertEqual(self.execute()[0], 3)
        self.assertIn('ans:— | <missing line>; real-out.txt:2', Path("test_out").read_text())

    def test_comparison_normalizes_crlf_and_optional_last_newline(self):
        Path("input.txt").write_bytes(b"hello\r\n")
        Path("ans.txt").write_bytes(b"hello")
        self.assertEqual(self.execute()[0], 0)

    def test_spaces_and_extra_blank_rows_are_significant(self):
        for output in (b"hello \n", b"hello\n\n"):
            Path("input.txt").write_bytes(output)
            self.assertEqual(self.execute()[0], 3)

    def test_report_control_bytes_are_quoted(self):
        Path("input.txt").write_bytes(b"\x1b[31m\xff\n")
        self.assertEqual(self.execute()[0], 3)
        report = Path("test_out").read_text()
        self.assertNotIn("\x1b", report)
        self.assertIn("\\u001b", report)
        self.assertIn("\\\\xff", report)

    def test_auto_default_is_two_lf_and_runs_each_case(self):
        self.auto()
        self.assertEqual(self.execute()[0], 0)
        report = Path("test_out").read_text()
        self.assertIn("Test 1: OK", report)
        self.assertIn("Test 2: OK", report)
        self.assertIn("Test 3: OK", report)

    def test_auto_custom_separator_is_literal(self):
        self.auto(b"a\n###\nb", sep=r"\n###\n")
        self.assertEqual(self.execute()[0], 0)
        self.assertIn("selected 2 of 2", Path("test_out").read_text())

    def test_opaque_normal_test_does_not_split_blank_lines(self):
        Path("input.txt").write_text("2\n\nvalue\n")
        Path("ans.txt").write_text("2\n\nvalue\n")
        self.assertEqual(self.execute()[0], 0)
        self.assertIn("selected 1 of 1", Path("test_out").read_text())

    def test_mismatched_counts_do_not_touch_prior_artifacts_or_print(self):
        self.auto(b"a\n\nb", b"a\n")
        Path("real-out.txt").write_text("old output")
        Path("test_out").write_text("old report")
        output, error = io.StringIO(), io.StringIO()
        with redirect_stdout(output), redirect_stderr(error), self.assertRaisesRegex(ENGINE.CheckUsageError, "count mismatch"):
            ENGINE.preflight_check(self.config)
        self.assertEqual(output.getvalue() + error.getvalue(), "")
        self.assertEqual(Path("real-out.txt").read_text(), "old output")
        self.assertEqual(Path("test_out").read_text(), "old report")

    def test_selections_cannot_hide_bad_bundle(self):
        self.auto(b"a\n\nb", b"a", cases=[1])
        with self.assertRaisesRegex(ENGINE.CheckUsageError, "count mismatch"):
            ENGINE.preflight_check(self.config)

    def test_selection_preserves_ids_order_and_deduplicates(self):
        self.auto(cases=[3, 1, 3])
        self.assertEqual(self.execute()[0], 0)
        report = Path("test_out").read_text()
        self.assertLess(report.index("Test 3:"), report.index("Test 1:"))
        self.assertEqual(report.count("Test 3:"), 1)
        self.assertNotIn("Test 2:", report)

    def test_zero_maps_to_one_with_one_notice(self):
        self.auto(cases=[0, 1, 0])
        status, _, stderr = self.execute()
        self.assertEqual(status, 0)
        self.assertEqual(stderr.count("1-based"), 1)
        self.assertEqual(Path("test_out").read_text().count("Test 1:"), 1)

    def test_invalid_selection_and_normal_selection_are_errors(self):
        for ids in ([-1], [4]):
            self.auto(cases=ids)
            with self.assertRaises(ENGINE.CheckUsageError):
                ENGINE.preflight_check(self.config)
        self.config.update(auto=False, cases=[1])
        with self.assertRaisesRegex(ENGINE.CheckUsageError, "test=auto"):
            ENGINE.preflight_check(self.config)

    def test_num_test_caps_after_selection(self):
        self.auto(cases=[3, 2, 1], num_test=2)
        self.assertEqual(self.execute()[0], 0)
        report = Path("test_out").read_text()
        self.assertIn("selected 2 of 3", report)
        self.assertNotIn("Test 1:", report)

    def test_invalid_positive_settings(self):
        for key in ("line_limit", "num_test"):
            for value in (0, -1, "garbage"):
                with self.assertRaises(ENGINE.CheckUsageError):
                    ENGINE.preflight_check({**self.config, key: value})

    def test_was_do_not_stop_other_selected_cases(self):
        self.auto(b"a\n\nb\n\nc", b"a\n\nwrong\n\nc")
        self.assertEqual(self.execute()[0], 3)
        self.assertIn("Test 3: OK", Path("test_out").read_text())

    def test_runtime_failure_continues_other_selected_cases(self):
        self.binary = self.program("solver.out", "import sys\np=sys.stdin.buffer.read()\nsys.stdout.buffer.write(p)\nsys.exit(7 if p==b'b' else 0)\n")
        self.auto()
        self.assertEqual(self.execute()[0], 7)
        report = Path("test_out").read_text()
        self.assertIn("Test 2: RTE (status 7)", report)
        self.assertIn("Test 3: OK", report)

    def interrupted_runner(self, phase=1):
        class InterruptedRunner:
            def __init__(self, **kwargs):
                self.calls = 0

            def display(self, *args): pass

            def run(self, argv, stdin=None, stdout=None, label=None, **kwargs):
                self.calls += 1
                stdout.write(b"partial\n")
                return ENGINE.Result(130 if self.calls == phase else 0, 1, 1,
                                     "INTERRUPTED" if self.calls == phase else "OK")
        return InterruptedRunner

    def test_cancellation_skips_comparison_preserves_partial_output_and_stops(self):
        self.auto(line_limit=1)
        with mock.patch.object(ENGINE, "Runner", self.interrupted_runner()), mock.patch.object(ENGINE, "compare_streams") as compare:
            self.assertEqual(self.execute()[0], 130)
            compare.assert_not_called()
        report = Path("test_out").read_text()
        self.assertIn("Test 1: INTERRUPTED", report)
        self.assertNotIn("Test 2:", report)
        self.assertNotIn("INCOMPLETE", report)
        self.assertEqual(Path("real-out.txt").read_bytes(), b"partial\n")

    def test_child_exit_three_is_rte_not_wa(self):
        self.program("solver.out", "raise SystemExit(3)\n")
        self.assertEqual(self.execute()[0], 3)
        report = Path("test_out").read_text()
        self.assertIn("RTE (status 3)", report)
        self.assertNotIn("Test 1: WA", report)

    def test_comparison_budget_returns_incomplete_not_pass(self):
        Path("input.txt").write_text("a\nb\nc\n")
        Path("ans.txt").write_text("a\nb\nc\n")
        self.config["line_limit"] = 2
        self.assertEqual(self.execute()[0], 4)
        self.assertIn("INCOMPLETE", Path("test_out").read_text())
        self.assertEqual(Path("real-out.txt").read_text(), "a\nb\nc\n")

    def test_exact_end_at_budget_is_pass(self):
        self.config["line_limit"] = 1
        self.assertEqual(self.execute()[0], 0)

    def test_budget_resets_for_selected_cases(self):
        self.auto(line_limit=2)
        self.assertEqual(self.execute()[0], 0)
        self.assertIn("Test 3: OK", Path("test_out").read_text())

    def test_stdout_report_keeps_actual_file_and_no_report_file(self):
        self.config["cout"] = True
        status, stdout, stderr = self.execute()
        self.assertEqual(status, 0)
        self.assertIn("Test 1: OK", stdout)
        self.assertEqual(stderr, "")
        self.assertTrue(Path("real-out.txt").exists())
        self.assertFalse(Path("test_out").exists())

    def test_console_framing_and_literal_escape(self):
        source = io.BytesIO(b"line\n\\:::answer:::\n:::answer:::\nline\n\\:::answer:::\n")
        incoming, answer = ENGINE.console_payloads(source)
        self.assertEqual(incoming, b"line\n:::answer:::\n")
        self.assertEqual(answer, incoming)

    def test_console_missing_or_extra_marker_is_error(self):
        for payload in (b"none", b":::answer:::\n:::answer:::\n"):
            with self.assertRaises(ENGINE.CheckUsageError):
                ENGINE.console_payloads(io.BytesIO(payload))

    def test_console_preflight_cache_avoids_reading_stdin_twice(self):
        self.config.update(cin=True, console_cache=str(Path("console-cache.json").absolute()))
        original = sys.stdin
        try:
            sys.stdin = io.TextIOWrapper(io.BytesIO(b"hello\n:::answer:::\nhello\n"))
            ENGINE.preflight_check(self.config)
            sys.stdin = io.StringIO("this must not be read")
            self.assertEqual(self.execute()[0], 0)
        finally:
            sys.stdin = original

    def test_console_cache_keeps_a_deliberate_final_empty_auto_case(self):
        self.config.update(cin=True, auto=True, console_cache=str(Path("console-cache.json").absolute()))
        original = sys.stdin
        try:
            sys.stdin = io.TextIOWrapper(io.BytesIO(b"hello\n\n\n\n:::answer:::\nhello\n\n\n\n"))
            first = ENGINE.preflight_check(self.config)
            second = ENGINE.preflight_check(self.config)
            self.assertEqual([case.length for case in first.inputs], [5, 0])
            self.assertEqual(second.inputs, first.inputs)
            self.assertEqual(self.execute()[0], 0)
        finally:
            sys.stdin = original

    def test_collision_roles_reject_before_truncation(self):
        for report in ("input.txt", "ans.txt", "real-out.txt", str(self.binary)):
            with self.assertRaises(ENGINE.CheckUsageError):
                ENGINE.preflight_check({**self.config, "report": report})
        self.assertEqual(Path("input.txt").read_text(), "hello\n")

    def test_hardlink_output_alias_is_rejected(self):
        os.link("ans.txt", "real-out.txt")
        with self.assertRaises(ENGINE.CheckUsageError):
            ENGINE.preflight_check(self.config)

    def test_report_symlink_is_rejected(self):
        Path("test_out").symlink_to("unrelated.txt")
        with self.assertRaises(ENGINE.CheckUsageError):
            ENGINE.preflight_check(self.config)

    def test_missing_input_or_report_parent_is_setup_error(self):
        with self.assertRaises(ENGINE.CheckSetupError):
            ENGINE.preflight_check({**self.config, "input": "missing.txt"})
        with self.assertRaises(ENGINE.CheckSetupError):
            ENGINE.preflight_check({**self.config, "report": "missing/report.txt"})

    def test_same_directory_concurrent_writer_is_rejected_without_sidecar(self):
        with ENGINE.check_lock():
            with self.assertRaisesRegex(ENGINE.CheckSetupError, "another test/stress"):
                self.execute()
        self.assertFalse(Path("real-out.txt").exists())

    def test_stress_success_records_finite_claim_and_latest_actual(self):
        status, _, stderr = self.execute(self.stress(), stress=True)
        self.assertEqual(status, 0)
        self.assertIn("No difference in 3 generated cases", stderr)
        self.assertEqual(Path("real-out.txt").read_text(), "19\n")
        self.assertFalse(Path("stress-failure").exists())

    def test_stress_mismatch_saves_input_seed_outputs_and_replay(self):
        wrong = self.program("wrong.out", "print('wrong')\n")
        status, _, stderr = self.execute(self.stress(main=wrong), stress=True)
        self.assertEqual(status, 3)
        bundle = Path("stress-failure")
        self.assertEqual((bundle / "input.txt").read_text(), "17\n")
        self.assertEqual((bundle / "ans.txt").read_text(), "17\n")
        self.assertEqual((bundle / "real-out.txt").read_text(), "wrong\n")
        manifest = json.loads((bundle / "manifest.json").read_text())
        self.assertEqual(manifest["seed"], 17)
        self.assertEqual(manifest["iteration"], 1)
        self.assertEqual(manifest["replay_argv"][1:3], ["test", "run"])
        self.assertEqual(len(manifest["executables"]["main"]["sha256"]), 64)
        self.assertIn("replay:", stderr)
        self.assertIn('--TLE=inf', manifest['replay_argv'])
        self.assertIn('--MLE=inf', manifest['replay_argv'])

    def test_stress_default_seed_is_four_for_direct_engine_callers(self):
        config = self.stress(iterations=2)
        del config['seed']
        status, _, stderr = self.execute(config, stress=True)
        self.assertEqual(status, 0, stderr)
        self.assertIn('start seed 4', Path('test_out').read_text())
        self.assertEqual(Path('real-out.txt').read_text(), '5\n')

    def test_oversized_seed_and_iteration_values_are_usage_errors(self):
        for extra in ({'seed': '9' * 5000}, {'num_test': '9' * 5000}):
            with self.subTest(key=next(iter(extra))):
                with self.assertRaises(ENGINE.CheckUsageError):
                    ENGINE.preflight_check(self.stress(**extra))

    def test_stress_runtime_tail_applies_to_candidate_only(self):
        candidate = self.program("candidate.out", "import sys\nassert sys.argv[1:]==['a b','--flag']\nsys.stdout.buffer.write(sys.stdin.buffer.read())\n")
        self.assertEqual(self.execute(self.stress(main=candidate, runtime_args=["a b", "--flag"], num_test=1), stress=True)[0], 0)

    def test_stress_budget_resets_each_iteration(self):
        status, _, stderr = self.execute(self.stress(line_limit=1), stress=True)
        self.assertEqual(status, 0)
        self.assertIn("No difference in 3", stderr)

    def test_stress_cancellation_is_not_misreported_as_role_failure_or_incomplete(self):
        for phase in (1, 2, 3):
            with self.subTest(phase=phase), mock.patch.object(ENGINE, "Runner", self.interrupted_runner(phase)), mock.patch.object(ENGINE, "compare_streams") as compare:
                self.assertEqual(self.execute(self.stress(line_limit=1), stress=True)[0], 130)
                compare.assert_not_called()
            report = Path("test_out").read_text()
            self.assertIn("INTERRUPTED", report)
            self.assertNotIn("GENERATOR_ERROR", report)
            self.assertNotIn("ORACLE_ERROR", report)
            self.assertNotIn("INCOMPLETE", report)

    def test_stress_preserves_multiple_failures_and_console_protocol(self):
        wrong = self.program("wrong.out", "print('wrong')\n")
        self.execute(self.stress(main=wrong), stress=True)
        status, stdout, _ = self.execute(self.stress(main=wrong, cout=True), stress=True)
        self.assertEqual(status, 3)
        self.assertIn("Iteration 1: WA", stdout)
        self.assertTrue(Path("stress-failure-1/test_out").is_file())

    def test_stress_generator_and_oracle_failure_are_distinct(self):
        fail = self.program("fail.out", "raise SystemExit(7)\n")
        config = self.stress(generator=str(fail))
        self.assertEqual(self.execute(config, stress=True)[0], 7)
        self.assertIn("GENERATOR_ERROR", Path("test_out").read_text())
        config = self.stress(brute=str(fail))
        self.assertEqual(self.execute(config, stress=True)[0], 7)
        self.assertIn("ORACLE_ERROR", Path("test_out").read_text())

    def test_stress_unsigned_seed_wraparound(self):
        self.assertEqual(self.execute(self.stress(seed=str(2**64-1), iterations=2), stress=True)[0], 0)
        self.assertEqual(Path("real-out.txt").read_text(), "0\n")

    def test_stress_num_test_overrides_iteration_default(self):
        self.assertEqual(self.execute(self.stress(num_test=1), stress=True)[0], 0)
        self.assertIn("No difference in 1 generated cases", Path("test_out").read_text())

    def test_stress_console_input_and_invalid_seed_are_errors(self):
        for extra in ({"cin": True}, {"seed": -1}, {"seed": str(2**64)}):
            with self.assertRaises(ENGINE.CheckUsageError):
                ENGINE.preflight_check(self.stress(**extra))


class PureCheckingTest(unittest.TestCase):
    def test_cancellation_supersedes_prior_limit_or_answer_failures(self):
        self.assertEqual(ENGINE._aggregate([("TLE", 124), ("INTERRUPTED", 130)]), 130)
        self.assertEqual(ENGINE._aggregate([("WA", 3), ("INTERRUPTED", 143)]), 143)

    def test_separator_empty_trailing_and_leading_blocks(self):
        sep = b"\n\n"
        for payload, expected in ((b"", [b""]), (b"a", [b"a"]),
                                  (b"a\n\n", [b"a"]),
                                  (b"a\n\n\n\n", [b"a", b""]),
                                  (b"\n\na", [b"", b"a"])):
            self.assertEqual(ENGINE.split_cases(payload, sep), expected)

    def test_separator_validation_has_no_general_escape_interpreter(self):
        self.assertEqual(ENGINE.decode_separator(r"\n\n"), b"\n\n")
        self.assertEqual(ENGINE.decode_separator("\n-- A1 --\n"), b"\n-- A1 --\n")
        for value in ("", "###", r"\n$HOME\n", r"\n\x0a\n", "\n@\n", "\n;\n", "\n'\n", "\n\r\n", "\né\n"):
            with self.assertRaises(ENGINE.CheckUsageError):
                ENGINE.decode_separator(value)

    def test_bounded_comparator_does_not_scan_whole_files(self):
        class CountingFile(io.BytesIO):
            def __next__(self):
                self.count += 1
                return super().__next__()
        a, b = CountingFile(b"x\n" * 100000), CountingFile(b"x\n" * 100000)
        a.count = b.count = 0
        result = ENGINE.compare_streams(a, b, 10)
        self.assertTrue(result.incomplete)
        self.assertEqual(result.used, 10)
        self.assertLess(a.count + b.count, 100)


if __name__ == "__main__":
    unittest.main()
