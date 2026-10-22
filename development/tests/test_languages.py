"""Real-language argv and phase regressions, independent of recording drivers."""

import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile
import unittest
from _paths import RELEASE


class LanguagesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cp-run-languages-")
        self.cwd = Path(self.temp.name)
        self.env = dict(os.environ, XDG_STATE_HOME=str(self.cwd / "state"))
        self.env.pop("CXX", None)
        self.env.pop("CC", None)
        self.script = str(self.cwd / 'fixture.zsh')
        factory = (RELEASE / 'cp-run.zsh').read_text()
        Path(self.script).write_text(factory.replace('typeset -g DEFAULT_INTERPRETER=pypy3',
                                                     'typeset -g DEFAULT_INTERPRETER=' + shlex.quote(sys.executable)))
        Path(self.script).chmod(0o755)

    def tearDown(self):
        self.temp.cleanup()

    def invoke(self, *args, **kwargs):
        return subprocess.run(
            [self.script, *map(str, args)],
            cwd=self.cwd,
            env=self.env,
            text=True,
            capture_output=True,
            timeout=20,
            **kwargs,
        )

    def set_file_io_mode(self):
        script = Path(self.script)
        script.write_text(script.read_text().replace('typeset -g DEFAULT_F_MODE=macro',
                                                   'typeset -g DEFAULT_F_MODE=auto'))

    def source(self, name="main.py", content='print("hello")\n'):
        path = self.cwd / name
        path.write_text(content)
        return path

    def test_pypy_is_factory_default(self):
        from _paths import load_engine
        settings = load_engine('language_defaults_probe')
        self.assertEqual(settings.FACTORY_SETTINGS['DEFAULT_INTERPRETER'], 'pypy3')
        if not shutil.which('pypy3'):
            self.skipTest('real PyPy default exercised where installed')
        source = self.source(content='import sys; print(sys.implementation.name)\n')
        result = subprocess.run([str(RELEASE / 'cp-run.zsh'), str(source)], cwd=self.cwd, env=self.env,
                                text=True, capture_output=True, timeout=20)
        self.assertEqual((result.returncode, result.stdout), (0, 'pypy\n'), result.stderr)

    def test_old_cpython_debug_is_rejected_before_source_execution(self):
        tool = self.cwd / 'old-python'
        tool.write_text('#!' + sys.executable + '\nprint("CPython\\n3.6")\n')
        tool.chmod(0o755)
        result = self.invoke('debug', self.source(), '--interpreter=' + str(tool))
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn('3.7+', result.stderr)

    @unittest.skipUnless(shutil.which('clang'), 'Clang required')
    def test_saved_c_compiler_and_explicit_family_override(self):
        from _paths import load_engine
        engine = load_engine('per_language_compiler_probe')
        script = Path(self.script)
        values = engine.read_settings(script.read_text())
        values['LANGUAGE_COMPILERS'] = {'c': 'clang++'}
        text = script.read_text()
        start = text.index(engine.SETTINGS_BEGIN)
        end = text.index(engine.SETTINGS_END) + len(engine.SETTINGS_END)
        script.write_text(text[:start] + engine.settings_text(values) + text[end:])
        source = self.source('main.c', 'int main(void) { return 0; }\n')
        result = self.invoke('compile', source, '--show-command')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('clang', result.stderr)
        # An explicitly incompatible CC must be diagnosed, not silently used
        # just because the saved C family differs from the global fallback.
        self.env['CC'] = shutil.which('clang')
        result = self.invoke('compile', source, '--compiler=GCC')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn('requested gcc', result.stderr)

    def test_language_preference_applies_only_to_omitted_file(self):
        self.source('main.cpp', 'int main() {}\n')
        self.source('main.py', 'print("chosen Python")\n')
        result = self.invoke('--language=python')
        self.assertEqual((result.returncode, result.stdout), (0, 'chosen Python\n'), result.stderr)
        result = self.invoke('main.py', '--language=c')
        self.assertEqual(result.stdout, 'chosen Python\n', result.stderr)
        self.assertEqual(self.invoke('--language=ruby').returncode, 2)

    def test_python_preserves_original_source_and_runtime_argv(self):
        path = self.source(
            "space name.py",
            "import sys\nfrom pathlib import Path\nprint(Path(__file__).name, sys.argv[1:])\n",
        )
        result = self.invoke(path, "--interpreter", sys.executable, "--", "--", "a b", "-")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "space name.py ['a b', '-']\n")
        self.assertFalse(list(self.cwd.glob("*.out")))

    def test_python_compile_validates_without_running(self):
        path = self.source(content='raise RuntimeError("must not run")\n')
        result = self.invoke("compile", path)
        self.assertEqual(
            (result.returncode, result.stdout), (0, str(path.resolve()) + "\n"), result.stderr
        )
        path.write_text("def broken(:\n")
        self.assertNotEqual(self.invoke("compile", path).returncode, 0)

    def test_python_run_and_history_without_execute_bit(self):
        path = self.source()
        self.assertEqual(self.invoke("run", path).stdout, "hello\n")
        self.assertEqual(self.invoke("run", "-").stdout, "hello\n")

    def test_python_debug_and_native_only_options(self):
        path = self.source(content="print(__debug__)\n")
        for command in ("debug", "debug=extra"):
            result = self.invoke(command, 'run', path)
            self.assertEqual((result.returncode, result.stdout), (0, "True\n"), result.stderr)
        for args in (("-std=23",), ("-f",), ("-o", "x"), ("--profile=pragma",)):
            self.assertEqual(self.invoke(path, *args).returncode, 2)
        self.assertEqual(self.invoke("debug", path, "--", "-O").returncode, 2)

    def test_python_in_out_redirects_are_independent(self):
        self.set_file_io_mode()
        path = self.source(content="import sys\nsys.stdout.write(sys.stdin.read())\n")
        (self.cwd / "in.txt").write_text("input\n")
        result = self.invoke(path, "-f", "--cout")
        self.assertEqual(result.stdout, "input\n")
        result = self.invoke(path, "--file-io", "--cin", "--out=chosen.txt", input="output\n")
        self.assertEqual((result.returncode, result.stdout), (0, ""), result.stderr)
        self.assertEqual((self.cwd / "chosen.txt").read_text(), "output\n")

    def test_python_stress_discovers_roles_and_keeps_seed_after_script(self):
        path = self.source(content="import sys\nprint(int(sys.stdin.read()) * 2)\n")
        self.source("brute.py", "import sys\nprint(int(sys.stdin.read()) * 2)\n")
        self.source("gen.py", "import sys\nprint(sys.argv[1])\n")
        result = self.invoke("stress", "--test-iters=2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("2 generated cases", (self.cwd / "test_out").read_text())

    def test_python_history_retains_diagnostic_interpreter_options(self):
        path = self.source(content="import sys\nprint(sys.flags.dev_mode)\n")
        first = self.invoke("debug", "run", path, "--interpreter", sys.executable)
        self.assertEqual(first.returncode, 0, first.stderr)
        recalled = self.invoke("run", "-")
        self.assertEqual(recalled.stdout, first.stdout, recalled.stderr)
        self.assertEqual(recalled.stdout, "True\n")

    def test_history_accepts_new_explicit_interpreter_arguments(self):
        source = self.source(content='import sys; print(sys.flags.dev_mode, bool(sys.flags.dont_write_bytecode))\n')
        first = self.invoke('debug', 'run', source)
        self.assertEqual((first.returncode, first.stdout), (0, 'True False\n'), first.stderr)
        recalled = self.invoke('run', '-', '--interpreter-arg=-B')
        self.assertEqual((recalled.returncode, recalled.stdout), (0, 'True True\n'), recalled.stderr)
        rejected = self.invoke('run', '-', '--interpreter-arg=-cprint(42)')
        self.assertEqual(rejected.returncode, 2, rejected.stderr)

    @unittest.skipUnless(shutil.which("pypy3"), "PyPy is optional; exercised on Linux CI")
    def test_pypy_profiles_and_checking(self):
        path = self.source(content='print("hello")\n')
        for args in ((path,), ("debug", "run", path), ("debug=extra", "run", path)):
            result = self.invoke(*args, "--interpreter=pypy3")
            self.assertEqual((result.returncode, result.stdout), (0, "hello\n"), result.stderr)
        (self.cwd / "in.txt").write_text("")
        (self.cwd / "ans.txt").write_text("hello\n")
        self.assertEqual(self.invoke("test", path, "--interpreter=pypy3").returncode, 0)

    def test_identical_python_roles_reuse_argv(self):
        self.source(content='import sys\nprint(sys.stdin.read(),end="")\n')
        self.source("gen.py", 'print("hello")\n')
        result = self.invoke("stress", "main.py", "main.py", "gen.py", "--test-iters=1")
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which("clang++"), "Clang required")
    def test_python_primary_tail_does_not_reach_native_reference(self):
        self.source(content="import sys\nprint(int(sys.stdin.read())*2)\n")
        self.source(
            "brute.cpp",
            '#include <iostream>\nint main(){int x;std::cin>>x;std::cout<<x*2<<"\\n";}\n',
        )
        self.source("gen.py", "import sys\nprint(sys.argv[1])\n")
        result = self.invoke(
            "stress",
            "main.py",
            "brute.cpp",
            "gen.py",
            "--compiler=clang",
            "--test-iters=1",
            "--",
            "-X",
            "dev",
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_debug_guards_python_clusters_and_preserves_option_operands(self):
        source = self.source(content="print(__debug__)\n")
        for args in (("-BO",), ("-vWignore",), ("-cprint(42)",), ("-W", "ignore"), ("-Wi",), ("-Wonce",)):
            result = self.invoke("debug", source, "--", *args)
            self.assertEqual(result.returncode, 2, result.stderr)
        accepted = self.invoke("debug", "run", source, "--", "-X", "-O")
        self.assertEqual((accepted.returncode, accepted.stdout), (0, "True\n"), accepted.stderr)
        accepted = self.invoke("debug", source, "--", "-W", "default")
        self.assertEqual(accepted.returncode, 0, accepted.stderr)
        rejected = self.invoke("debug=extra", source, "--", "-W", "default")
        self.assertEqual(rejected.returncode, 2, rejected.stderr)

    def test_native_debug_rejects_wrapper_warning_suppression_before_tool_lookup(self):
        source = self.source("main.cpp", "int main() {}\n")
        self.env["CXX"] = "/missing/compiler"
        for options in (("debug", source, "--no-w"), (source, "--profile=extra", "--no-w")):
            result = self.invoke(*options)
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertIn("--no-w", result.stderr)

    @unittest.skipUnless(shutil.which("clang"), "Clang required")
    def test_c_standard_and_debug_do_not_probe_cpp_library(self):
        path = self.source("main.c", '#include <stdio.h>\nint main(void) { puts("C"); }\n')
        result = self.invoke(path, "--compiler=clang", "-std", "17")
        self.assertEqual((result.returncode, result.stdout), (0, "C\n"), result.stderr)
        result = self.invoke("debug", "run", path, "--compiler=clang")
        self.assertEqual((result.returncode, result.stdout), (0, "C\n"), result.stderr)

    @unittest.skipUnless(shutil.which("clang++"), "Clang required")
    def test_mixed_cpp_candidate_python_reference_generator(self):
        self.source(
            "main.cpp",
            '#include <iostream>\nint main(){int x; std::cin>>x; std::cout<<x*2<<"\\n";}\n',
        )
        self.source("brute.py", "import sys\nprint(int(sys.stdin.read()) * 2)\n")
        self.source("gen.py", "import sys\nprint(sys.argv[1])\n")
        result = self.invoke(
            "stress", "main.cpp", "brute.py", "gen.py", "--compiler=clang", "--test-iters=2"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
