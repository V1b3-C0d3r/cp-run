"""1.1 storage, protocol, Companion and reduction acceptance regressions."""

from contextlib import redirect_stderr, redirect_stdout
import copy
import io
import json
import os
from pathlib import Path
import select
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from _paths import RELEASE, load_engine
import test_languages as language_fixtures

engine = load_engine("cp_run_v11_tests")


class StorageTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cp-run-v11-")
        self.cwd = Path(self.temp.name).resolve()
        self.old = Path.cwd()
        os.chdir(self.cwd)

    def tearDown(self):
        os.chdir(self.old)
        self.temp.cleanup()

    def test_counted_roundtrip_preserves_empty_lf_crlf_and_no_final_lf(self):
        sep = b"\n\x1e\n"
        for records in (
            [],
            [b""],
            [b"\n"],
            [b"A\n", b"\nB"],
            [b"", b""],
            [b"A\r\n\r\n", b"B", b""],
        ):
            Path("bundle").write_bytes(engine.encode_bundle(records, sep))
            actual = [engine.slice_bytes(c) for c in engine.counted_cases("bundle", sep)]
            self.assertEqual(actual, records)

    def test_counted_format_does_not_infer_program_case_count(self):
        Path("bundle").write_bytes(b"1\n2\n3 4\n5 6\n")
        cases = engine.counted_cases("bundle", b"\n\x1e\n")
        self.assertEqual(engine.slice_bytes(cases[0]), b"2\n3 4\n5 6\n")

    def test_separator_collisions_and_overlap_are_rejected(self):
        for records, sep in (
            ([b"x\x1ey"], b"\n\x1e\n"),
            ([b"A\n", b"B"], b"\n\n"),
            ([b"\n#", b"x"], b"\n#\n"),
        ):
            with self.assertRaises(engine.CheckUsageError):
                engine.encode_bundle(records, sep)

    def test_sparse_ids_and_pairing(self):
        Path("tests").mkdir()
        for n in (1, 3):
            Path("tests/{}.in".format(n)).write_text(str(n))
            Path("tests/{}.ans".format(n)).write_text(str(n))
        ids, left, right = engine.mult_cases(
            {"test_dir": "tests", "source_anchor": str(self.cwd / "main.cpp")}
        )
        self.assertEqual(ids, [1, 3])
        self.assertEqual(engine.slice_bytes(left[1]), b"3")
        Path("tests/3.ans").unlink()
        with self.assertRaisesRegex(engine.CheckUsageError, "missing answers"):
            engine.mult_cases({"test_dir": "tests"})

    def test_duplicate_numerical_id_and_template_escape(self):
        Path("tests").mkdir()
        for name in ("1.in", "01.in"):
            Path("tests", name).touch()
        with self.assertRaisesRegex(engine.CheckUsageError, "duplicate"):
            engine.discover_cases("tests", "{n}.in", "main")
        for pattern in ("../{n}.in", "/tmp/{n}", "{n}/{unknown}", "{n}{n}"):
            with self.assertRaises(engine.CheckUsageError):
                engine.case_template(pattern, "main", 1)

    def test_template_stem_literal_characters_and_subtree(self):
        root = self.cwd / "tests"
        engine.write_test_files(root, [("a [x]/3.in", b"3")])
        self.assertEqual(list(engine.discover_cases(root, "{stem}/{n}.in", "a [x]")), [3])
        config = {
            "workspace": str(self.cwd),
            "test_dir": "tests",
            "source_anchor": str(self.cwd / "src/main.cpp"),
            "save_test_relpath": True,
        }
        self.assertEqual(engine.layout_root(config), self.cwd / "tests/src")

    def test_writer_preflights_entire_set_and_refuses_links(self):
        root = self.cwd / "tests"
        root.mkdir()
        (root / "exists").write_bytes(b"old")
        with self.assertRaises(engine.CheckUsageError):
            engine.write_test_files(root, [("new", b"x"), ("exists", b"y")])
        self.assertFalse((root / "new").exists())
        (root / "link").symlink_to(self.cwd, target_is_directory=True)
        with self.assertRaises(engine.CheckUsageError):
            engine.write_test_files(root, [("link/escape", b"x")])
        self.assertFalse((self.cwd / "escape").exists())

    def test_companion_preserves_samples_and_ignores_remote_paths(self):
        payload = json.dumps(
            {
                "tests": [{"input": "2\n1 2\n\n", "output": ""}],
                "name": "../../escape",
                "input": {"type": "file", "fileName": "/tmp/bad"},
                "batch": {"id": "a", "size": 1},
                "testType": "multiNumber",
            }
        ).encode()
        config = {"test_dir": "tests", "source_anchor": str(self.cwd / "main.cpp")}
        count, root = engine.import_companion(config, payload)
        self.assertEqual(count, 1)
        self.assertEqual((root / "1.in").read_bytes(), b"2\n1 2\n\n")
        self.assertEqual((root / "1.ans").read_bytes(), b"")
        engine.import_companion(config, payload)  # Idempotent repeated delivery.

    def test_companion_binding_never_queries_reverse_dns(self):
        from http.server import BaseHTTPRequestHandler

        with mock.patch("socket.getfqdn", side_effect=AssertionError("reverse DNS is not needed")):
            with engine.companion_server(("127.0.0.1", 0), BaseHTTPRequestHandler) as server:
                self.assertEqual(server.server_name, "localhost")
                self.assertGreater(server.server_port, 0)

    def test_import_rollback_restores_prior_files_after_interrupted_replace(self):
        root = self.cwd / "tests"
        root.mkdir()
        (root / "1.in").write_bytes(b"old")
        original = os.replace
        calls = [0]

        def interrupt(source, target):
            calls[0] += 1
            if calls[0] == 1:
                original(source, target)
                raise KeyboardInterrupt
            return original(source, target)

        with (
            mock.patch.object(engine.os, "replace", side_effect=interrupt),
            self.assertRaises(KeyboardInterrupt),
        ):
            engine.write_test_files(root, [("1.in", b"new"), ("1.ans", b"answer")], overwrite=True)
        self.assertEqual((root / "1.in").read_bytes(), b"old")
        self.assertFalse((root / "1.ans").exists())
        self.assertEqual(sorted(path.name for path in root.iterdir()), ["1.in"])

    def test_companion_rejects_batch_duplicate_keys_and_bad_samples(self):
        for payload in (
            b'{"tests":[],"tests":[]}',
            b'{"tests":[{"input":"x","output":3}]}',
            b'{"tests":[{"input":"x","output":"y"}],"batch":{"size":2}}',
        ):
            with self.assertRaises(engine.CheckUsageError):
                engine.companion_samples(payload)
        self.assertFalse(Path("tests").exists())

    def test_reducer_repairs_count_and_preserves_failure_predicate(self):
        grammar = engine.SequenceGrammar()

        def fails(payload, deadline):
            return 7 in grammar.decode(payload)

        result, attempts, _ = engine.reduce_items(b"6\n1 2 7 3 4 5\n", grammar, fails, 100, 5)
        self.assertEqual(grammar.decode(result), [7])
        self.assertLessEqual(attempts, 100)

    def test_reducer_does_not_accept_invalid_or_changed_failure(self):
        grammar = engine.SequenceGrammar()
        original = b"3\n2 9 4\n"

        def fails(payload, deadline):
            values = grammar.decode(payload)
            return len(values) >= 2 and 9 in values  # Declared extra validity constraint.

        result, _, _ = engine.reduce_items(original, grammar, fails, 30, 5)
        values = grammar.decode(result)
        self.assertGreaterEqual(len(values), 2)
        self.assertIn(9, values)
        unchanged, _, reason = engine.reduce_items(original, grammar, lambda *args: False)
        self.assertEqual(unchanged, original)
        self.assertIn("not reproducible", reason)

    def test_reducer_interruption_exposes_best_valid_partial(self):
        grammar = engine.SequenceGrammar()
        calls = [0]

        def interrupted(payload, deadline):
            calls[0] += 1
            if calls[0] == 3:
                raise KeyboardInterrupt
            return True

        with self.assertRaises(engine.ReductionInterrupted) as stopped:
            engine.reduce_items(b"4\n1 2 3 4\n", grammar, interrupted)
        self.assertLess(len(grammar.decode(stopped.exception.best)), 4)

    def test_schema_one_migration_retains_old_values_and_deleted_profiles(self):
        data = {
            "DEFAULT_SEPARATOR": r"\n\n",
            "DEFAULT_DESTINATION": "old-bin",
            "MODE_NAMES": [],
            "MODE_KIND": {},
            "MODE_CPU": {},
        }
        for key in engine.SETTINGS_GROUPS.values():
            if key not in ("MODE_CPYTHON", "MODE_PYPY"):
                data[key] = {}
        migrated = engine.validate_preferences(data)
        self.assertEqual(migrated["DEFAULT_DESTINATION"], "old-bin")
        self.assertEqual(migrated["DEFAULT_SEPARATOR"], r"\n\n")
        self.assertEqual(migrated["MODE_CPYTHON"], {})

    def test_simultaneous_resource_failures_have_deterministic_priority(self):
        result = engine.Result(124, 2000000000, 300 * engine.MIB, "TLE")
        self.assertEqual(
            engine.public_verdict(result, config={"timeout_ms": "1000", "memory_mib": "256"}), "MLE"
        )

    def test_reduction_budget_is_bounded(self):
        result, attempts, reason = engine.reduce_items(
            b"4\n1 2 3 4\n", engine.SequenceGrammar(), lambda *args: True, attempts=1
        )
        self.assertEqual(attempts, 1)
        self.assertIn("budget", reason)


class AdvancedCliTest(unittest.TestCase):
    setUp = language_fixtures.LanguagesTest.setUp
    tearDown = language_fixtures.LanguagesTest.tearDown
    invoke = language_fixtures.LanguagesTest.invoke
    source = language_fixtures.LanguagesTest.source

    def data(self, value="hello\n"):
        (self.cwd / "in.txt").write_text(value)
        (self.cwd / "ans.txt").write_text(value)

    def test_whole_file_is_one_test_with_numbered_sections_and_metrics(self):
        self.source(content="import sys\nsys.stdout.write(sys.stdin.read())\n")
        self.data("2\n\nhello\n")
        result = self.invoke("test", "--cout")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("TEST 1\n"), 1)
        for value in (
            "input:1",
            "out.txt:1",
            "ans:1",
            "Test 1: AC",
            "TIME:",
            "MEMORY:",
            "FINAL VERDICT: AC",
        ):
            self.assertIn(value, result.stdout)

    def test_mult_selection_continues_re_and_records_full_stderr(self):
        self.source(
            content='import sys\ns=sys.stdin.read()\nprint(s,end="")\nif s=="bad":\n sys.stderr.write("failure\\n"*20);sys.exit(7)\n'
        )
        (self.cwd / "tests").mkdir()
        for n, text in ((1, "bad"), (3, "good")):
            (self.cwd / "tests/{}.in".format(n)).write_text(text)
            (self.cwd / "tests/{}.ans".format(n)).write_text(text)
        result = self.invoke("test=mult", "--cout")
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertIn("Test 1: RE", result.stdout)
        self.assertIn("Test 3: AC", result.stdout)
        self.assertEqual(result.stdout.count("failure"), 20)
        self.assertNotIn("failure", result.stderr)

    def test_bundle_manual_conversion_cli_roundtrip(self):
        self.source()
        manual = self.cwd / "manual.txt"
        manual.write_bytes(b"2\nA\n\n###\n\nB")
        result = self.invoke("--pack", "in", "manual.txt", "data.bundle", "--text-sep", r"\n###\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b"\n\x1e\n", (self.cwd / "data.bundle").read_bytes())
        result = self.invoke("--unpack=in", "data.bundle", "copy.txt", "--text-sep=" + r"\n###\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / "copy.txt").read_bytes(), manual.read_bytes())

    def test_ce_has_report_and_never_runs_source(self):
        self.source(content="def invalid(:\n")
        self.data()
        result = self.invoke("test", "--cout")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FINAL VERDICT: CE", result.stdout)
        self.assertIn("NOT RUN: 1", result.stdout)
        self.assertIn("SyntaxError", result.stderr)

    def test_failed_repeat_does_not_replace_first_stdout(self):
        self.source(
            content='from pathlib import Path\nimport sys\np=Path("count");n=int(p.read_text())+1 if p.exists() else 1;p.write_text(str(n));print("hello" if n==1 else "wrong")\n'
        )
        self.data()
        result = self.invoke("test", "-tm", "--warm-up=0", "--average=2", "--cout")
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertEqual((self.cwd / "out.txt").read_text(), "hello\n")
        self.assertIn("FAILED REPEAT 2", result.stdout)
        self.assertIn("Test 1: WA", result.stdout)

    def test_auto_and_mult_limits_are_independent(self):
        self.source(
            content='import sys,time\ns=sys.stdin.read()\nif s=="slow": time.sleep(1)\nprint(s,end="")\n'
        )
        self.data("slow\n\x1e\nfast")
        result = self.invoke("test=auto", "--TLE=600", "--cout")
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertIn("Test 1: TLE", result.stdout)
        self.assertIn("Test 2: AC", result.stdout)

    def test_companion_real_http_invalid_then_valid_request(self):
        self.source()
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        process = subprocess.Popen(
            [self.script, "companion", "--port", str(port), "--wait=10"],
            cwd=self.cwd,
            env=self.env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        try:
            ready, _, _ = select.select([process.stderr], [], [], 10)
            self.assertTrue(ready, "receiver did not announce readiness")
            self.assertIn("listening", process.stderr.readline())
            url = "http://127.0.0.1:{}/".format(port)
            with self.assertRaises(HTTPError):
                urlopen(
                    Request(url, b'{"tests":[]}', {"Content-Type": "application/json"}), timeout=5
                )
            payload = json.dumps({"tests": [{"input": "1\n", "output": "1\n"}]}).encode()
            with urlopen(
                Request(url, payload, {"Content-Type": "application/json"}), timeout=5
            ) as response:
                self.assertEqual(response.status, 200)
            stdout, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, stderr)
            self.assertEqual((self.cwd / "tests/1.in").read_bytes(), b"1\n")
            self.assertEqual((self.cwd / "tests/1.ans").read_bytes(), b"1\n")
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()

    def test_stress_continues_candidate_failures_by_default(self):
        self.source(content='print("wrong")\n')
        self.source("brute.py", 'import sys\nprint(sys.stdin.read(),end="")\n')
        self.source("gen.py", "import sys\nprint(sys.argv[1])\n")
        result = self.invoke("stress", "--test-iters=3")
        self.assertEqual(result.returncode, 3, result.stderr)
        report = (self.cwd / "test_out").read_text()
        self.assertIn("Iteration 3: WA", report)
        self.assertIn("WA: 1, 2, 3", report)

    def test_mult_memory_limit_does_not_poison_next_case(self):
        self.source(
            content='import sys,time\ns=sys.stdin.read()\nif s=="mem":\n a=bytearray(256*1024*1024)\n for i in range(0,len(a),4096): a[i]=1\n time.sleep(.3)\nprint(s,end="")\n'
        )
        (self.cwd / "tests").mkdir()
        for n, text in ((1, "mem"), (2, "fast")):
            (self.cwd / "tests/{}.in".format(n)).write_text(text)
            (self.cwd / "tests/{}.ans".format(n)).write_text(text)
        result = self.invoke("test=mult", "--MLE=96", "--TLE=5000", "--cout")
        self.assertEqual(result.returncode, 125, result.stderr)
        self.assertIn("Test 1: MLE", result.stdout)
        self.assertIn("Test 2: AC", result.stdout)

    def test_end_to_end_sequence_counterexample_reduction(self):
        self.source(
            content="import sys\na=list(map(int,sys.stdin.read().split()))[1:]\nprint(sum(a)+(1 if 7 in a else 0))\n"
        )
        self.source(
            "brute.py", "import sys\na=list(map(int,sys.stdin.read().split()))[1:]\nprint(sum(a))\n"
        )
        self.source("gen.py", 'print("6\\n1 2 7 3 4 5")\n')
        result = self.invoke("stress", "--test-iters=1", "--minimize=sequence")
        self.assertEqual(result.returncode, 3, result.stderr)
        bundle = self.cwd / "stress-failure"
        self.assertEqual((bundle / "in.txt").read_bytes(), b"6\n1 2 7 3 4 5\n")
        self.assertEqual(
            engine.SequenceGrammar().decode((bundle / "reduced-input.txt").read_bytes()), [7]
        )
        self.assertTrue(json.loads((bundle / "reduction.json").read_text())["confirmed"])

    def test_out_only_may_use_the_unused_default_input_filename(self):
        self.source(content='print("written")\n')
        result = self.invoke("main.py", "-f=out", "in.txt")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / "in.txt").read_text(), "written\n")

    @unittest.skipUnless(shutil.which("ruff"), "optional Ruff formatter")
    def test_real_python_format_only_check_and_reserved_stdout(self):
        source = self.source(content="value=1\nprint(value)\n")
        checked = self.invoke(source, "--make-prettier=check")
        self.assertEqual(checked.returncode, 1, checked.stderr)
        formatted = self.invoke("--make-prettier")
        self.assertEqual((formatted.returncode, formatted.stdout), (0, ""), formatted.stderr)
        self.assertIn("value = 1", source.read_text())
        self.assertFalse((self.cwd / "main.out").exists())
        self.assertEqual(self.invoke(source, "--make-prettier=check").returncode, 0)

    @unittest.skipUnless(shutil.which("clang-format"), "optional native formatter")
    def test_real_native_format_does_not_query_a_compiler(self):
        source = self.source("main.c", "int main(void){return 0;}\n")
        self.env["CC"] = "/missing/compiler"
        result = self.invoke(source, "--make-prettier")
        self.assertEqual((result.returncode, result.stdout), (0, ""), result.stderr)
        self.assertIn("return 0;", source.read_text())
        self.assertNotEqual(source.read_text(), "int main(void){return 0;}\n")

    def test_pack_uses_mult_defaults_without_a_source_file(self):
        (self.cwd / "tests").mkdir()
        (self.cwd / "tests/1.in").write_bytes(b"2 3\n")
        packed = self.invoke("--pack", "in")
        self.assertEqual(packed.returncode, 0, packed.stderr)
        self.assertEqual((self.cwd / "in.bundle").read_bytes(), b"1\n2 3\n")

    def test_interpreter_argument_replay_retains_diagnostic_options(self):
        self.source(content='print("wrong")\n')
        self.source("brute.py", 'print("correct")\n')
        self.source("gen.py", 'print("input")\n')
        result = self.invoke(
            "stress", "--test-iters=1", "--interpreter-arg=-X", "--interpreter-arg=dev"
        )
        self.assertEqual(result.returncode, 3, result.stderr)
        manifest = json.loads((self.cwd / "stress-failure/manifest.json").read_text())
        replay = manifest["replay_argv"]
        self.assertIn("--interpreter-arg=-X", replay)
        self.assertIn("--interpreter-arg=dev", replay)
        repeated = subprocess.run(
            replay, cwd=self.cwd, env=self.env, text=True, capture_output=True, timeout=20
        )
        self.assertEqual(repeated.returncode, 3, repeated.stderr)
