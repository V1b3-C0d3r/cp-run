"""Public 1.0 CLI regressions with a recording compiler and real processes.

The recording compiler fixture originated in the frozen 2.0 tests. These tests invoke only
the new public syntax; recording argv verifies forwarding independently of
whether a particular host compiler accepts an experimental option.
"""

import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time
import tempfile
import unittest


from _paths import RELEASE

SCRIPT = RELEASE / "cp-run.zsh"
BASE_WARNINGS = (
    "-Wall", "-Wextra", "-Wshadow", "-Wconversion",
    "-Wduplicated-cond", "-Wlogical-op",
)

CLANG_BASE_WARNINGS = (
    "-Wall", "-Wextra", "-Wshadow", "-Wconversion",
    "-Wlogical-op-parentheses", "-Wtautological-compare",
)

FAKE_COMPILER = r'''import json, os, pathlib, sys, time
args = sys.argv[1:]
with open(os.environ["FAKE_COMPILER_LOG"], "a") as log:
    log.write(json.dumps(args) + "\n")
if args == ["--version"]:
    family = os.environ.get("FAKE_COMPILER_FAMILY", "GCC")
    banner = "clang version 21.0.0 (integration fixture)" if family == "clang" else "g++ (GNU GCC integration fixture) 1.2.3"
    print(os.environ.get("FAKE_COMPILER_BANNER", banner))
    sys.exit(int(os.environ.get("FAKE_VERSION_STATUS", "0")))
if args == ["-dumpmachine"]:
    print(os.environ.get("FAKE_TARGET", "aarch64-apple-darwin25"))
    sys.stderr.write(os.environ.get("FAKE_TARGET_STDERR", ""))
    sys.exit(int(os.environ.get("FAKE_TARGET_STATUS", "0")))
if "-S" in args and "-Werror" in args and "/dev/null" in args:
    # Capability probes must never create, truncate or chmod the real null device.
    sys.stdout.write(os.environ.get("FAKE_NATIVE_STDOUT", ""))
    sys.stderr.write(os.environ.get("FAKE_NATIVE_STDERR", ""))
    sys.exit(1 if os.environ.get("FAKE_NATIVE_UNSUPPORTED") else 0)
standards = os.environ.get("FAKE_STANDARDS", "c++98 c++03 c++11 c++14 c++17 c++20 c++23 c++2b c++2c c++26 gnu++23 gnu++2b").replace(",", " ").split()
if args == ["--help=c++"]:
    print("\n".join("  -std=" + standard + "  Select C++ language mode" for standard in standards))
    sys.exit(0)
if any(arg.startswith("-std=__cp_run_") for arg in args):
    sys.stderr.write("error: invalid value for -std; valid values are: " + " ".join(standards) + "\n")
    sys.exit(1)
if "-dM" in args and "-E" in args:
    print("#define __GNUC__ 16")
    print("#define __GNUC_MINOR__ 2")
    library = os.environ.get("FAKE_STDLIB", "libc++" if os.environ.get("FAKE_COMPILER_FAMILY") == "clang" else "libstdc++")
    for arg in args:
        if arg.startswith("-stdlib="): library = arg.partition("=")[2]
    if os.environ.get("FAKE_COMPILER_FAMILY") == "clang":
        print("#define __clang__ 1")
        print("#define __clang_major__ 21")
    if not os.environ.get("FAKE_NO_STDLIB"):
        if library == "libstdc++":
            print("#define __GLIBCXX__ 20261001")
            print("#define _GLIBCXX_RELEASE 16")
        elif library == "libc++" and not os.environ.get("FAKE_NO_LIBCPP"):
            print("#define _LIBCPP_VERSION " + os.environ.get("FAKE_LIBCPP_VERSION", "220106"))
            if os.environ.get("FAKE_MISSING_MODE") != "FAST":
                print("#define _LIBCPP_HARDENING_MODE_FAST 2")
            if os.environ.get("FAKE_MISSING_MODE") != "DEBUG":
                print("#define _LIBCPP_HARDENING_MODE_DEBUG 8")
    sys.stderr.write(os.environ.get("FAKE_PROBE_STDERR", ""))
    sys.exit(int(os.environ.get("FAKE_PROBE_STATUS", "0")))
if os.environ.get("FAKE_COMPILE_SLEEP"): time.sleep(float(os.environ["FAKE_COMPILE_SLEEP"]))
sys.stdout.write(os.environ.get("FAKE_GCC_STDOUT", ""))
sys.stderr.write(os.environ.get("FAKE_GCC_STDERR", ""))
if os.environ.get("FAKE_REPORT_TTY"):
    sys.stderr.write("compiler stderr tty=" + str(sys.stderr.isatty()) + "\n")
sys.stdout.flush()
sys.stderr.flush()
if os.environ.get("FAKE_COMPILER_READY"):
    pathlib.Path(os.environ["FAKE_COMPILER_READY"]).write_text("ready\n")
    while not pathlib.Path(os.environ["FAKE_COMPILER_RELEASE"]).exists():
        time.sleep(0.01)
status = int(os.environ.get("FAKE_GCC_STATUS", "0"))
if status:
    sys.exit(status)
output = None
index = 0
while index < len(args):
    arg = args[index]
    if arg in ("-o", "--output"):
        index += 1
        output = args[index]
    elif arg.startswith("--output="):
        output = arg.split("=", 1)[1]
    elif arg.startswith("-o") and len(arg) > 2:
        output = arg[2:]
    index += 1
if output and not os.environ.get("FAKE_NO_OUTPUT"):
    output = pathlib.Path(output)
    if os.environ.get("FAKE_OBJECT"):
        output.write_bytes(b"object fixture\n")
    else:
        output.write_text("#!" + sys.executable + "\n" +
            "import os, pathlib, sys, time\n"
            "counter = os.environ.get('FAKE_PROGRAM_COUNTER')\n"
            "run_number = (int(pathlib.Path(counter).read_text()) + 1 if counter and pathlib.Path(counter).exists() else 1)\n"
            "if counter: pathlib.Path(counter).write_text(str(run_number))\n"
            "if run_number == 1:\n"
            "    sys.stdout.write(os.environ.get('FAKE_FIRST_STDOUT', '')); sys.stdout.flush()\n"
            "    sys.stderr.write(os.environ.get('FAKE_FIRST_STDERR', '')); sys.stderr.flush()\n"
            "    if os.environ.get('FAKE_FIRST_SLEEP'): time.sleep(float(os.environ['FAKE_FIRST_SLEEP']))\n"
            "    if os.environ.get('FAKE_FIRST_MEMORY'): allocation = bytearray(int(os.environ['FAKE_FIRST_MEMORY']) * 1024 * 1024)\n"
            "    if os.environ.get('FAKE_FIRST_STATUS'): sys.exit(int(os.environ['FAKE_FIRST_STATUS']))\n"
            "if os.environ.get('FAKE_PROGRAM_LOG'): pathlib.Path(os.environ['FAKE_PROGRAM_LOG']).write_text(os.getcwd() + '\\n')\n"
            "if os.environ.get('FAKE_PROGRAM_PID'): pathlib.Path(os.environ['FAKE_PROGRAM_PID']).write_text(str(os.getpid()))\n"
            "sys.stdout.write(os.environ.get('FAKE_PROGRAM_STDOUT', ''))\n"
            "sys.stderr.write(os.environ.get('FAKE_PROGRAM_STDERR', ''))\n"
            "if os.environ.get('FAKE_REPORT_TTY'): sys.stderr.write('program stderr tty=' + str(sys.stderr.isatty()) + '\\n')\n"
            "sys.stdout.flush(); sys.stderr.flush()\n"
            "if os.environ.get('FAKE_PROGRAM_STDIN'): sys.stdout.write(sys.stdin.readline())\n"
            "if os.environ.get('FAKE_PROGRAM_ARGS'): pathlib.Path(os.environ['FAKE_PROGRAM_ARGS']).write_text(__import__('json').dumps(sys.argv[1:]))\n"
            "if os.environ.get('FAKE_PROGRAM_MEMORY'): allocation = bytearray(int(os.environ['FAKE_PROGRAM_MEMORY']) * 1024 * 1024)\n"
            "if os.environ.get('FAKE_PROGRAM_SLEEP'): time.sleep(float(os.environ['FAKE_PROGRAM_SLEEP']))\n"
            "if os.environ.get('FAKE_PROGRAM_WAIT'): time.sleep(30)\n"
            "sys.exit(int(os.environ.get('FAKE_PROGRAM_STATUS', '0')))\n")
        output.chmod(0o755)
    if os.environ.get("FAKE_SIDECAR"):
        bundle = pathlib.Path(str(output) + ".dSYM")
        bundle.mkdir()
        (bundle / "symbols").write_text(os.environ["FAKE_SIDECAR"])
        pathlib.Path(str(output) + ".map").write_text("link map\n")
'''


class CliTest(unittest.TestCase):
    # The recording fixture is vendored so release archives are standalone.
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cp-run-tests-")
        self.root = Path(self.temp.name).resolve()
        self.ws = self.root / "Main"
        self.cwd = self.ws / "task with spaces"
        self.cwd.mkdir(parents=True)
        self.source = self.cwd / "main file.cpp"
        self.source.write_text("int main() {}\n")
        self.compiler = self.root / "compiler with spaces"
        self.compiler.write_text("#!" + sys.executable + "\n" + FAKE_COMPILER)
        self.compiler.chmod(0o755)
        self.log = self.root / "compiler.jsonl"
        self.program_log = self.root / "program.cwd"

    def tearDown(self):
        self.temp.cleanup()

    def environment(self, overrides=None):
        """Use the same isolated compiler environment for sync and live checks."""
        command_env = dict(os.environ)
        command_env.update(CXX=str(self.compiler), FAKE_COMPILER_LOG=str(self.log))
        if overrides:
            for name, value in overrides.items():
                if value is None:
                    command_env.pop(name, None)
                else:
                    command_env[name] = value
        return command_env

    def calls(self, include_probes=False):
        if not self.log.exists():
            return []
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        if include_probes:
            return calls
        return [args for args in calls
                if args not in (["--version"], ["--help=c++"], ["-dumpmachine"])
                and not any(arg.startswith("-std=__cp_run_") for arg in args)
                and not ("-dM" in args and "-E" in args)
                and not ("-S" in args and "-Werror" in args and "/dev/null" in args)]

    def output_arg(self, args):
        result = None
        for index, arg in enumerate(args):
            if arg in ("-o", "--output"):
                result = args[index + 1]
            elif arg.startswith("--output="):
                result = arg.partition("=")[2]
            elif arg.startswith("-o") and len(arg) > 2:
                result = arg[2:]
        self.assertIsNotNone(result, args)
        return Path(result) if Path(result).is_absolute() else self.cwd / result

    def invoke(self, *args, cwd=None, env=None, input=None, script=SCRIPT):
        return subprocess.run([str(script), *map(str, args)], cwd=cwd or self.cwd,
                              env=self.environment(env), input=input, text=True,
                              capture_output=True, timeout=20)

    def build(self, *flags, env=None, source=None):
        result = self.invoke("compile", source or self.source.name, *flags, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result, self.calls()[-1]

    def rejected(self, *args, status=2, env=None):
        before = self.calls()
        result = self.invoke(*args, env=env)
        self.assertEqual(result.returncode, status, result.stderr)
        self.assertIn("cp-run:", result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertEqual(self.calls(), before, "invalid wrapper request must not compile")
        return result

    def binary(self, name="runner.out", body='printf "%s\\n" "$@"\n'):
        target = self.cwd / name
        target.write_text("#!/bin/sh\n" + body)
        target.chmod(0o755)
        return target

    def data(self, incoming="hello\n", expected="hello\n"):
        (self.cwd / "input.txt").write_text(incoming)
        (self.cwd / "ans.txt").write_text(expected)

    def test_shell_syntax(self):
        result = subprocess.run(["zsh", "-n", str(SCRIPT)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_required_wrapper_values_reject_missing_empty_and_next_option(self):
        options = ('--compiler', '--profile', '--dest-dir', '--wsp-name', '--find',
                   '--TLE', '--MLE', '--sep', '--test-iters', '--seed', '--wsp-dir')
        for option in options:
            for suffix in ((), ('--show-command',), ('--',)):
                with self.subTest(option=option, suffix=suffix):
                    result = self.rejected('compile', self.source.name, option, *suffix)
                    self.assertIn('missing value for ' + option, result.stderr)
            result = self.rejected('compile', self.source.name, option + '=')
            self.assertIn('empty value for ' + option, result.stderr)
        self.assertEqual(self.calls(include_probes=True), [])

    def test_required_long_values_accept_equal_and_separate_forms(self):
        for joined in (True, False):
            flags = []
            for option, value in (('--compiler', 'GCC'), ('--profile', 'debug'),
                                  ('--wsp-dir', '..'), ('--wsp-name', 'Main'), ('--dest-dir', 'bin'),
                                  ('--TLE', '1000'), ('--MLE', '256')):
                flags.extend([option + '=' + value] if joined else [option, value])
            result, args = self.build(*flags)
            self.assertEqual(Path(result.stdout.strip()), self.ws / 'bin/main file.out')
            self.assertIn('-fsanitize=address,undefined', args)

    def test_workspace_dir_requires_an_explicit_nonempty_value_even_with_exact_output(self):
        for spelling in (('--wsp-dir',), ('--wsp-dir=',), ('--wsp-dir', '--show-command')):
            self.rejected('compile', self.source.name, '-o', 'exact.bin', *spelling)


    def test_dash_prefixed_long_values_use_equals_without_becoming_options(self):
        result, _ = self.build('--dest-dir=-build')
        self.assertEqual(Path(result.stdout.strip()), self.cwd / '-build/main file.out')
        result, _ = self.build('-o', '-native.out')
        self.assertEqual(Path(result.stdout.strip()), self.cwd / '-native.out')

    def test_renamed_and_misspelled_options_have_actionable_migration_errors(self):
        replacements = {'--cph-ng': '--save-relpath', '--save-relpth': '--save-relpath',
                        '--workspace-name': '--wsp-name', '--workspace-dir': '--wsp-dir',
                        '--destination-dir': '--dest-dir', '--timeout': '--TLE',
                        '--memory-limit': '--MLE', '--num-test': '--test-iters'}
        for old, new in replacements.items():
            for spelling in (old, old + '=value'):
                with self.subTest(spelling=spelling):
                    result = self.rejected('compile', self.source.name, spelling)
                    self.assertIn('use ' + new, result.stderr)

    def test_boolean_wrapper_options_reject_attached_values(self):
        for option in ('--save-relpath', '--no-w', '--time', '--memory', '--show-command',
                       '--cin', '--cout', '--help', '--version', '--set-defaults'):
            result = self.rejected('compile', self.source.name, option + '=yes')
            self.assertIn('accepts 0 or 1' if option == '--save-relpath' else 'does not take a value', result.stderr)

    def test_wrapper_spellings_are_literal_inside_both_argument_tails(self):
        words = ['--wsp-dir=', '--dest-dir=elsewhere', '--save-relpath', '--TLE=1',
                 '--MLE=1', '--test-iters=1', '--seed', '--workspace-dir=old', '--timeout=old']
        _, args = self.build('--', *words)
        offset = args.index(words[0])
        self.assertEqual(args[offset:offset + len(words)], words)
        binary = self.binary()
        result = self.invoke('run', binary, '--', *words)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), words)

    def test_compile_default_flags_and_absolute_artifact(self):
        result, args = self.build()
        final = self.cwd / "main file.out"
        self.assertEqual(result.stdout, str(final) + "\n")
        self.assertEqual(result.stderr, "")
        self.assertTrue(final.is_file())
        self.assertIn("-std=c++26", args)
        self.assertIn("-O2", args)
        for warning in BASE_WARNINGS:
            self.assertEqual(args.count(warning), 1)
        self.assertEqual(self.output_arg(args).name, final.name)
        self.assertFalse(self.output_arg(args).exists(), "staging artifact must have been installed")

    def test_default_run_preserves_streams_cwd_and_status(self):
        result = self.invoke(self.source.name, env={
            "FAKE_PROGRAM_STDOUT": "native output\n", "FAKE_PROGRAM_STDERR": "native error\n",
            "FAKE_PROGRAM_STATUS": "7", "FAKE_PROGRAM_LOG": str(self.program_log)})
        self.assertEqual((result.returncode, result.stdout, result.stderr),
                         (7, "native output\n", "native error\n"))
        self.assertEqual(self.program_log.read_text().strip(), str(self.cwd))

    def test_omitted_source_and_main_fallback(self):
        result = self.invoke("compile")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1][0], str(self.source))
        main = self.cwd / "main.cpp"
        main.write_text("int main(){}\n")
        result = self.invoke("compile")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1][0], str(main))

    def test_source_selection_missing_and_ambiguous(self):
        other = self.cwd / "other.cpp"
        other.write_text("int main(){}")
        self.rejected("compile")
        other.unlink(); self.source.unlink()
        self.rejected("compile")
        self.assertEqual(self.calls(include_probes=True), [])

    def test_cpp_directories_do_not_count_as_sources(self):
        (self.cwd / "fake.cpp").mkdir()
        result = self.invoke("compile")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1][0], str(self.source))

    def test_unknown_compiler_option_preserves_native_diagnostic(self):
        result = self.invoke(self.source.name, "--unknown-compiler-option", env={
            "FAKE_GCC_STATUS": "9", "FAKE_GCC_STDERR": "compiler: unknown option\n"})
        self.assertEqual((result.returncode, result.stderr), (9, "compiler: unknown option\n"))
        self.assertIn("--unknown-compiler-option", self.calls()[-1])

    def test_no_w_only_removes_generated_warnings(self):
        _, args = self.build("--no-w", "-Wconversion")
        self.assertEqual(args.count("-Wconversion"), 1)
        for flag in BASE_WARNINGS:
            if flag != "-Wconversion":
                self.assertNotIn(flag, args)

    def test_plain_optimization_and_debug_levels_keep_native_order(self):
        _, args = self.build("-O0", "-O3", "-g0", "-g3")
        levels = [arg for arg in args if arg.startswith(("-O", "-g"))]
        self.assertEqual(levels, ["-O2", "-O0", "-O3", "-g0", "-g3"])

    def test_known_compiler_operands_are_not_wrapper_options(self):
        _, args = self.build("-I", "--no-w", "-include", "-f")
        self.assertEqual(args[args.index("-I") + 1], "--no-w")
        self.assertEqual(args[args.index("-include") + 1], "-f")
        self.assertIn("-Wall", args)
        self.assertNotIn("-DFILEO", args)

    def test_second_boundary_passes_literal_runtime_arguments(self):
        recorded = self.root / "runtime.json"
        values = ["--input", "a b", "", "--no-w", "--", "$HOME", "$(touch missing)"]
        result = self.invoke(self.source.name, "--", "-I", "with space", "--", *values,
                             env={"FAKE_PROGRAM_ARGS": str(recorded)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(recorded.read_text()), values)
        args = self.calls()[-1]
        self.assertEqual(args[args.index("-I") + 1], "with space")
        self.assertNotIn("--input", args)

    def test_empty_compiler_tail_still_allows_runtime_arguments(self):
        recorded = self.root / "args.json"
        result = self.invoke(self.source.name, "--", "--", "-arg", "", env={"FAKE_PROGRAM_ARGS": str(recorded)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(recorded.read_text()), ["-arg", ""])

    def test_compile_and_debug_have_only_one_compiler_tail(self):
        for action in ("compile", "debug"):
            result = self.invoke(action, self.source.name, "--", "--", "--profile=opaque")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("--", self.calls()[-1])
            self.assertIn("--profile=opaque", self.calls()[-1])

    def test_raw_tail_does_not_expand_standard_or_wrapper_options(self):
        _, args = self.build("--", "-std=20", "--compiler=clang", "--no-w")
        self.assertIn("-std=20", args)
        self.assertNotIn("-std=c++20", args)
        self.assertNotIn("-std=c++26", args)
        self.assertIn("--compiler=clang", args)
        self.assertIn("--no-w", args)

    def test_standard_operand_does_not_suppress_auto_selection(self):
        _, args = self.build("--", "-I", "-std=c++20")
        self.assertIn("-std=c++26", args)
        self.assertEqual(args[args.index("-I") + 1], "-std=c++20")

    def test_newest_standard_is_queried_per_compiler(self):
        for listing, expected in (("c++17 c++2b c++23", "c++23"),
                                  ("c++20 c++2c", "c++2c"),
                                  ("c++98 c++11", "c++11")):
            _, args = self.build(env={"FAKE_STANDARDS": listing})
            self.assertIn("-std=" + expected, args)

    def test_explicit_standard_is_checked_against_discovery(self):
        self.build("-std=20")
        self.assertIn(["--help=c++"], self.calls(include_probes=True))

    def test_profile_adapts_to_actual_library_not_driver(self):
        for compiler, library, macro in (("GCC", "libc++", "-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST"),
                                         ("clang++", "libstdc++", "-D_GLIBCXX_ASSERTIONS")):
            family = "clang" if compiler == "clang++" else "GCC"
            _, args = self.build("--profile=debug", "--compiler=" + compiler,
                                 env={"FAKE_COMPILER_FAMILY": family, "FAKE_STDLIB": library})
            self.assertIn(macro, args)

    def test_extra_profile_driver_adaptations(self):
        for family, sanitizer in (("GCC", "-fsanitize=float-cast-overflow,bounds-strict"),
                                   ("clang", "-fsanitize=float-cast-overflow,bounds")):
            _, args = self.build("--profile=extra", "--compiler=" + family,
                                 env={"FAKE_COMPILER_FAMILY": family})
            self.assertIn(sanitizer, args)
            self.assertIn("-fno-optimize-sibling-calls", args)

    def test_library_probe_failure_is_not_silently_ignored(self):
        result = self.invoke("debug", self.source.name, env={"FAKE_PROBE_STATUS": "1", "FAKE_PROBE_STDERR": "bad library\n"})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])
        self.assertIn("bad library", result.stderr)

    def test_matching_profile_repetition_is_harmless(self):
        result = self.invoke("debug", self.source.name, "--profile=debug")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_different_profile_selections_conflict(self):
        self.rejected("debug", self.source.name, "--profile=extra")

    def test_managed_no_w_keeps_profile_checks(self):
        _, args = self.build("--profile=extra", "--no-w")
        self.assertFalse(any(arg.startswith("-W") for arg in args))
        self.assertIn("-fsanitize=address,undefined", args)

    def test_profile_compiler_operand_does_not_weaken_level(self):
        _, args = self.build("--profile=extra", "--", "-I", "-O3")
        self.assertEqual(args[args.index("-I") + 1], "-O3")
        self.assertIn("-Og", args)

    def test_separate_native_standard_tail_is_probed_and_suppresses_auto(self):
        _, args = self.build("--profile=debug", "--", "--std", "c++20")
        self.assertEqual(args[args.index("--std") + 1], "c++20")
        all_calls = self.calls(include_probes=True)
        self.assertNotIn(["--help=c++"], all_calls)
        probe = next(call for call in all_calls if "-dM" in call)
        self.assertEqual(probe[probe.index("--std") + 1], "c++20")

    def test_separate_standard_operand_is_not_a_debug_flag(self):
        _, args = self.build("--profile=debug", "--", "--std", "-O3")
        self.assertEqual(args[args.index("--std") + 1], "-O3")

    def test_default_workspace_and_destination_are_current_directory(self):
        result, _ = self.build()
        self.assertEqual(result.stdout.strip(), str(self.cwd / "main file.out"))

    def test_name_alone_searches_nearest_ancestor(self):
        result, _ = self.build("--wsp-name=Main")
        self.assertEqual(result.stdout.strip(), str(self.ws / "main file.out"))

    def test_explicit_workspace_name_checks_without_searching(self):
        result, _ = self.build("--wsp-dir=..", "--wsp-name=Main", "--dest-dir=bin")
        self.assertEqual(result.stdout.strip(), str(self.ws / "bin/main file.out"))
        self.rejected("compile", self.source.name, "--wsp-dir=.", "--wsp-name=Main")

    def test_save_relpath_uses_source_tree(self):
        source = self.ws / "other" / "nested" / "solution.cpp"
        source.parent.mkdir(parents=True); source.write_text("int main(){}")
        result, _ = self.build("--wsp-dir=..", "--dest-dir=build", "--save-relpath", source=source)
        self.assertEqual(result.stdout.strip(), str(self.ws / "build/other/nested/solution.out"))

    def test_save_relpath_default_destination_and_explicit_override_both_orders(self):
        result, _ = self.build('--wsp-dir=..', '--save-relpath')
        self.assertEqual(Path(result.stdout.strip()), self.cwd / 'main file.out')
        for flags in (('--save-relpath', '--dest-dir=build'), ('--dest-dir=build', '--save-relpath'),
                      ('--save-relpath', '--dest-dir=.'), ('--dest-dir=.', '--save-relpath')):
            with self.subTest(flags=flags):
                result, _ = self.build('--wsp-dir=..', *flags)
                dest = 'build' if '--dest-dir=build' in flags else '.'
                self.assertEqual(Path(result.stdout.strip()), self.ws / dest / self.cwd.name / 'main file.out')

    def test_save_relpath_rejects_source_outside_workspace(self):
        source = self.root / "outside.cpp"; source.write_text("int main(){}")
        self.rejected("compile", source, "--save-relpath", status=1)

    def test_destination_symlink_cannot_escape_workspace(self):
        outside = self.root / "outside"; outside.mkdir()
        (self.cwd / "escape").symlink_to(outside, target_is_directory=True)
        self.rejected("compile", self.source.name, "--dest-dir=escape", status=1)

    def test_output_wins_over_unused_routes_both_orders(self):
        invalid = ["--wsp-dir=/not/here", "--wsp-name=missing", "--dest-dir=../outside", "--save-relpath"]
        for options in ([*invalid, "-o", "chosen.bin"], ["-o", "chosen.bin", *invalid]):
            result, _ = self.build(*options)
            self.assertEqual(result.stdout.strip(), str(self.cwd / "chosen.bin"))

    def test_output_last_value_wins_and_has_no_forced_extension(self):
        result, _ = self.build("-o", "first", "-osecond")
        self.assertEqual(result.stdout.strip(), str(self.cwd / "second"))
        self.assertFalse((self.cwd / "first").exists())

    def test_output_parent_creation(self):
        target = self.root / "new" / "nested" / "program"
        result, _ = self.build("-o", target)
        self.assertEqual(result.stdout.strip(), str(target))
        self.assertTrue(target.is_file())

    def test_source_and_source_hardlink_are_protected(self):
        alias = self.cwd / "source-link"
        os.link(self.source, alias)
        for path in (self.source, alias):
            self.rejected("compile", self.source.name, "-o", path)
        self.assertEqual(self.source.read_text(), "int main() {}\n")

    def test_failure_preserves_old_binary_and_does_not_execute_it(self):
        final = self.binary("main file.out", 'echo stale\n')
        before = final.read_bytes()
        result = self.invoke(self.source.name, env={"FAKE_GCC_STATUS": "9", "FAKE_GCC_STDERR": "compile failed\n"})
        self.assertEqual(result.returncode, 9)
        self.assertEqual(result.stderr, "compile failed\n")
        self.assertEqual(result.stdout, "")
        self.assertEqual(final.read_bytes(), before)
        self.assertEqual(list(self.cwd.glob(".cp-run-build.*")), [])

    def test_build_preserves_debug_bundles_and_compiler_sidecars(self):
        result, _ = self.build("-g", env={"FAKE_SIDECAR": "first symbols"})
        artifact = Path(result.stdout.strip())
        self.assertEqual(Path(str(artifact) + ".dSYM/symbols").read_text(), "first symbols")
        self.assertEqual(Path(str(artifact) + ".map").read_text(), "link map\n")
        self.build("-g", env={"FAKE_SIDECAR": "replacement symbols"})
        self.assertEqual(Path(str(artifact) + ".dSYM/symbols").read_text(), "replacement symbols")
        self.assertEqual(list(self.cwd.glob(".cp-run-build.*")), [])

    def test_ordinary_exec_cleans_build_staging_before_replacing_shell(self):
        result = self.invoke(self.source.name)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(list(self.cwd.glob(".cp-run-build.*")), [])

    def test_compiler_sidecar_cannot_overwrite_redirected_input(self):
        incoming = self.cwd / 'main file.out.map'
        incoming.write_text('keep my input\n')
        result = self.invoke(self.source.name, '-f=auto', incoming.name, 'output.txt',
                             env={'FAKE_SIDECAR': 'symbols'})
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(incoming.read_text(), 'keep my input\n')
        self.assertFalse((self.cwd / 'output.txt').exists())

    def test_compiler_sidecar_cannot_overwrite_expected_answer(self):
        (self.cwd / 'input.txt').write_text('data\n')
        answer = self.cwd / 'main file.out.map'
        answer.write_text('keep my answer\n')
        result = self.invoke('test', self.source.name, 'input.txt', answer.name,
                             env={'FAKE_SIDECAR': 'symbols'})
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(answer.read_text(), 'keep my answer\n')
        self.assertFalse((self.cwd / 'real-out.txt').exists())

    def test_success_without_new_artifact_never_runs_stale_binary(self):
        self.binary("main file.out", 'echo stale\n')
        result = self.invoke(self.source.name, env={"FAKE_NO_OUTPUT": "1"})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertIn("fresh", result.stderr)

    def test_compile_reserves_stdout_for_path(self):
        result, _ = self.build(env={"FAKE_GCC_STDOUT": "compiler notes\n", "FAKE_GCC_STDERR": "warning\n"})
        self.assertEqual(result.stdout, str(self.cwd / "main file.out") + "\n")
        self.assertCountEqual(result.stderr.splitlines(), ["compiler notes", "warning"])

    def test_show_command_is_opt_in_and_does_not_add_failure_banner(self):
        result = self.invoke(self.source.name, "--show-command", env={"FAKE_GCC_STATUS": "8", "FAKE_GCC_STDERR": "native\n"})
        self.assertEqual(result.returncode, 8)
        self.assertIn("-std=c++26", result.stderr)
        self.assertTrue(result.stderr.endswith("native\n"))
        self.assertNotIn("cp-run: error", result.stderr)

    def test_help_without_source_or_compiler(self):
        self.source.unlink()
        result = self.invoke("--help", env={"CXX": "/missing"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("test[=auto|mult]", result.stdout)
        self.assertEqual(self.calls(include_probes=True), [])

    def test_version_has_wrapper_and_compiler_information(self):
        result = self.invoke("--version")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("cp-run 1.1", result.stdout)
        self.assertIn("GNU GCC integration fixture", result.stdout)

    def test_missing_compiler_is_status_127(self):
        self.rejected("compile", self.source.name, env={"CXX": "/does/not/exist"}, status=127)

    def test_compiler_can_follow_wrapper_and_native_options(self):
        _, args = self.build("--no-w", "-O0", "--compiler=clang++", env={"FAKE_COMPILER_FAMILY": "clang"})
        self.assertIn("-O0", args)
        self.assertNotIn("-Wall", args)

    def test_direct_binary_skips_toolchain_and_unused_routes(self):
        self.source.unlink(); binary = self.binary(body='echo direct\n')
        result = self.invoke("run", binary, "--wsp-dir=/missing", "--dest-dir=../unused", env={"CXX": "/missing"})
        self.assertEqual((result.returncode, result.stdout), (0, "direct\n"))
        self.assertEqual(self.calls(include_probes=True), [])

    def test_binary_tail_is_literal_and_has_one_boundary(self):
        self.binary()
        result = self.invoke("run", "runner.out", "--", "--", "--compiler=clang", "a b", "")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "--\n--compiler=clang\na b\n\n")

    def test_find_ambiguous_binary_requires_explicit_path(self):
        self.binary("task"); self.binary("task.out")
        result = self.rejected("run", "--find=task")
        self.assertIn("ambiguous", result.stderr)
        self.assertEqual(self.invoke("run", "./task").returncode, 0)

    def test_find_with_explicit_file_does_not_check_unused_name(self):
        binary = self.binary(body='echo explicit\n')
        result = self.invoke("run", binary, "--find=invalid/path")
        self.assertEqual((result.returncode, result.stdout), (0, "explicit\n"))

    def test_find_save_relpath_uses_invocation_subtree_and_own_default_destination(self):
        self.binary(body='echo located\n')
        result = self.invoke("run", "--find=runner", "--wsp-dir=..", "--save-relpath")
        self.assertEqual((result.returncode, result.stdout), (0, "located\n"))

    def test_find_save_relpath_honors_explicit_destination(self):
        self.binary(body='echo located\n')
        for flags in (('--save-relpath', '--dest-dir=.'), ('--dest-dir=.', '--save-relpath')):
            result = self.invoke('run', '--find=runner', '--wsp-dir=..', *flags)
            self.assertEqual((result.returncode, result.stdout), (0, 'located\n'), result.stderr)

    def test_file_macro_does_not_redirect_streams(self):
        result = self.invoke(self.source.name, "-f", env={"FAKE_PROGRAM_STDOUT": "console\n"})
        self.assertEqual((result.returncode, result.stdout), (0, "console\n"))
        self.assertIn("-DFILEO", self.calls()[-1])
        self.assertFalse((self.cwd / "output.txt").exists())

    def test_auto_file_io_redirects_without_macro(self):
        self.data()
        for flags in (("-f=auto",), ("-f", "auto")):
            result = self.invoke(self.source.name, *flags, env={"FAKE_PROGRAM_STDIN": "1"})
            self.assertEqual((result.returncode, result.stdout), (0, ""))
            self.assertEqual((self.cwd / "output.txt").read_text(), "hello\n")
            self.assertNotIn("-DFILEO", self.calls()[-1])

    def test_separate_auto_mode_preserves_subsequent_compiler_options(self):
        self.data()
        result = self.invoke(self.source.name, '-f', 'auto', '-DUSER=7', '--', '-pthread',
                             env={'FAKE_PROGRAM_STDIN': '1'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / 'output.txt').read_text(), 'hello\n')
        self.assertIn('-DUSER=7', self.calls()[-1])
        self.assertIn('-pthread', self.calls()[-1])
        self.assertNotIn('-DFILEO', self.calls()[-1])

    def test_auto_file_io_paths_with_spaces_and_dash_prefix_remain_literal(self):
        (self.cwd / '-input data').write_text('literal\n')
        result = self.invoke(self.source.name, '-f', 'auto', './-input data', 'result file',
                             env={'FAKE_PROGRAM_STDIN': '1'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / 'result file').read_text(), 'literal\n')

    def test_auto_file_io_accepts_explicit_paths_in_both_value_forms(self):
        (self.cwd / "data.in").write_text("custom\n")
        for flags in (("-f=auto", "data.in", "data.out"), ("-f", "auto", "data.in", "data.out")):
            result = self.invoke(self.source.name, *flags, env={"FAKE_PROGRAM_STDIN": "1"})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((self.cwd / "data.out").read_text(), "custom\n")

    def test_auto_file_io_combines_with_short_measurement_clusters(self):
        self.data()
        for flags in (('-ftm=auto',), ('-ftm', 'auto'), ('-mtf=auto',), ('-mtf', 'auto')):
            result = self.invoke(self.source.name, *flags, env={'FAKE_PROGRAM_STDIN': '1'})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((self.cwd / 'output.txt').read_text(), 'hello\n')
            self.assertEqual(result.stderr.count('cp-run: time:'), 1)
            self.assertEqual(result.stderr.count('cp-run: peak RSS:'), 1)
            self.assertNotIn('-DFILEO', self.calls()[-1])

    def test_missing_auto_input_is_native_runtime_error_and_does_not_truncate_output(self):
        target = self.cwd / "output.txt"; target.write_text("previous\n")
        result = self.invoke(self.source.name, "-f=auto")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("cp-run:", result.stderr)
        self.assertIn("input.txt", result.stderr)
        self.assertEqual(target.read_text(), "previous\n")
        self.assertEqual(len(self.calls()), 1)

    def test_test_default_files_and_report(self):
        self.data()
        # File routing is independent of cold interpreter startup on CI.
        result = self.invoke("test", '--TLE=inf', env={"FAKE_PROGRAM_STDIN": "1"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.cwd / "real-out.txt").read_text(), "hello\n")
        self.assertIn("PASS", (self.cwd / "test_out").read_text())
        self.assertEqual(len(self.calls()), 1)

    def test_test_auto_default_empty_line_separator_compiles_once(self):
        self.data("first\n\x1e\nsecond\n", "first\n\x1e\nsecond\n")
        result = self.invoke("test=auto", '--TLE=inf', env={"FAKE_PROGRAM_STDIN": "1"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls()), 1)
        self.assertIn("2", (self.cwd / "test_out").read_text())

    def test_test_count_mismatch_has_one_error_no_probe_or_output_changes(self):
        self.data("one\n\x1e\ntwo\n", "one\n")
        previous = self.cwd / "real-out.txt"; previous.write_text("previous\n")
        result = self.invoke("test=auto", "--show-command")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertEqual(len(result.stderr.splitlines()), 1, result.stderr)
        self.assertEqual(previous.read_text(), "previous\n")
        self.assertFalse((self.cwd / "test_out").exists())
        self.assertEqual(self.calls(include_probes=True), [])

    def test_test_binary_uses_no_compiler_and_preserves_stderr(self):
        self.data(); self.binary(body='echo "native" >&2\ncat\n')
        result = self.invoke("test", "run", "runner.out", env={"CXX": "/missing"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("native\n", result.stderr)
        self.assertIn("native", (self.cwd / "test_out").read_text())
        self.assertEqual(self.calls(include_probes=True), [])

    def test_test_console_report_keeps_real_output(self):
        self.data(); self.binary(body='cat\n')
        result = self.invoke("test", "run", "runner.out", "--cout")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS", result.stdout)
        self.assertEqual((self.cwd / "real-out.txt").read_text(), "hello\n")
        self.assertFalse((self.cwd / "test_out").exists())

    def test_test_console_input_is_framed(self):
        self.binary(body='cat\n')
        result = self.invoke("test", "run", "runner.out", "--cin", "--cout", input="hello\n:::answer:::\nhello\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS", result.stdout)

    def test_test_wrong_answer_report_independently_numbers_lines(self):
        self.data("input\n", "first\ninserted\nlast\n")
        self.binary(body="printf 'first\\nlast\\n'\n")
        result = self.invoke("test", "run", "runner.out")
        self.assertEqual(result.returncode, 3, result.stderr)
        protocol = (self.cwd / "test_out").read_text()
        self.assertIn("WA", protocol)
        self.assertIn("inserted", protocol)
        self.assertIn("2", protocol)

    def test_stress_sources_compile_three_roles_once(self):
        # These two tests count builds, not runtime limits. A freshly created
        # Python fixture can start slowly on cold or loaded macOS workers.
        (self.cwd / "brute.cpp").write_text("int main(){}")
        (self.cwd / "gen.cpp").write_text("int main(){}")
        result = self.invoke("stress", self.source.name, "brute.cpp", "gen.cpp", "--test-iters=2", "--seed=9", '--TLE=inf',
                             env={"FAKE_PROGRAM_STDOUT": "same\n"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls()), 3)
        self.assertTrue((self.cwd / "test_out").exists())

    def test_stress_identical_source_configuration_is_built_once(self):
        (self.cwd / "gen.cpp").write_text("int main(){}")
        result = self.invoke("stress", self.source.name, self.source.name, "gen.cpp", "--test-iters=1", '--TLE=inf',
                             env={"FAKE_PROGRAM_STDOUT": "same\n"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls()), 2)
        self.assertEqual(self.calls(include_probes=True).count(["--help=c++"]), 1)

    def test_stress_binary_roles_are_explicit_even_when_defaults_exist(self):
        self.binary("candidate", "cat\n")
        self.binary("brute.cpp", "cat\n")
        self.binary("gen.cpp", "echo input\n")
        self.rejected("stress", "run", "candidate", "--test-iters=1")

    def test_stress_seed_defaults_to_four_and_advances_reproducibly(self):
        self.binary('candidate', 'cat\n')
        self.binary('brute', 'cat\n')
        self.binary('gen', 'echo "$1"\n')
        for _ in range(2):
            result = self.invoke('stress', 'run', 'candidate', 'brute', 'gen', '--test-iters=2')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((self.cwd / 'real-out.txt').read_text(), '5\n')
            self.assertIn('start seed 4', (self.cwd / 'test_out').read_text())

    def test_stress_seed_zero_and_repeated_values_use_the_last_value(self):
        self.binary('candidate', 'cat\n'); self.binary('brute', 'cat\n'); self.binary('gen', 'echo "$1"\n')
        for values, expected in ((('--seed=9', '--seed', '0'), '0\n'),
                                 (('--seed', '9', '--seed=0'), '0\n'),
                                 (('--seed=' + str(2**64 - 1),), str(2**64 - 1) + '\n'),
                                 (('--seed=0004',), '4\n')):
            result = self.invoke('stress', 'run', 'candidate', 'brute', 'gen', '--test-iters=1', *values)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((self.cwd / 'real-out.txt').read_text(), expected)

    def test_separate_checking_and_binary_lookup_operands_match_attached_values(self):
        self.binary(body='cat\n')
        self.data('one\n###\ntwo\n', 'one\n###\ntwo\n')
        for flags in (('--find=runner', r'--sep=\n###\n', '--test-iters=1'),
                      ('--find', 'runner', '--sep', r'\n###\n', '--test-iters', '1')):
            result = self.invoke('test=auto', 'run', *flags)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((self.cwd / 'real-out.txt').read_text(), 'one')

    def test_invalid_stress_seeds_fail_before_any_compiler_probe(self):
        for value in ('-1', str(2**64), '1.5', 'inf', '９', '9' * 5000):
            result = self.rejected('stress', self.source.name, '--seed=' + value)
            self.assertIn('unsigned 64-bit', result.stderr)
        self.assertEqual(self.calls(include_probes=True), [])

    def test_stress_binary_failure_preserves_replay_bundle(self):
        self.binary("candidate", 'echo bad\n')
        self.binary("brute", 'cat\n')
        self.binary("gen", 'echo "$1"\n')
        result = self.invoke("stress", "run", "candidate", "brute", "gen", "--test-iters=2", "--seed=7", "--stop-on-failure")
        self.assertEqual(result.returncode, 3, result.stderr)
        bundles = list(self.cwd.glob("stress-failure*"))
        self.assertEqual(len(bundles), 1)
        self.assertEqual((bundles[0] / "input.txt").read_text(), "7\n")
        self.assertEqual((bundles[0] / "ans.txt").read_text(), "7\n")
        self.assertEqual((bundles[0] / "real-out.txt").read_text(), "bad\n")
        self.assertEqual(self.calls(include_probes=True), [])

    def test_integrated_timer_excludes_compilation_and_setup(self):
        start = time.monotonic()
        result = self.invoke(self.source.name, "-t", env={
            "FAKE_COMPILE_SLEEP": "2.5", "FAKE_PROGRAM_SLEEP": ".04"})
        outer = time.monotonic() - start
        self.assertEqual(result.returncode, 0, result.stderr)
        shown = float(re.search(r"time: (\d+\.\d{3}) ms", result.stderr)[1])
        self.assertGreaterEqual(shown, 35)
        # Newly written executables can incur substantial cold-launch time
        # on macOS. Do not equate startup with the program's 40ms sleep; prove
        # instead that the known 2.5s compile interval stays outside the timer.
        self.assertGreater(outer * 1000 - shown, 2400)

    def test_measured_binary_keeps_program_stderr(self):
        self.binary(body='echo native >&2\nsleep .03\n')
        result = self.invoke("run", "runner.out", "-tm")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stderr.startswith("native\n"))
        self.assertRegex(result.stderr, r"time: \d+\.\d{3} ms")
        self.assertIn("peak RSS:", result.stderr)

    def test_warmup_time_flag_runs_twice_but_builds_once(self):
        counter = self.root / 'starts'
        result = self.invoke(self.source.name, '-t', env={'FAKE_PROGRAM_COUNTER': str(counter),
                             'FAKE_PROGRAM_STDOUT': 'visible\n', 'FAKE_PROGRAM_STDERR': 'native\n'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '2')
        self.assertEqual(len(self.calls()), 1)
        self.assertEqual(result.stdout, 'visible\n')
        self.assertEqual(result.stderr.count('native\n'), 1)
        self.assertEqual(result.stderr.count('cp-run: time:'), 1)

    def test_warmup_memory_only_reports_only_the_second_peak(self):
        counter = self.root / 'starts'
        result = self.invoke(self.source.name, '-m', env={'FAKE_PROGRAM_COUNTER': str(counter),
                             'FAKE_FIRST_MEMORY': '96'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '2')
        peak = int(re.search(r'peak RSS: (\d+) KiB', result.stderr)[1])
        self.assertLess(peak, 96 * 1024, 'warm-up RSS must not leak into the second run')
        self.assertEqual(result.stderr.count('peak RSS:'), 1)
        self.assertNotIn('cp-run: time:', result.stderr)

    def test_warmup_first_time_and_failure_are_discarded(self):
        counter = self.root / 'starts'
        result = self.invoke(self.source.name, '-tm', env={
            'FAKE_PROGRAM_COUNTER': str(counter), 'FAKE_FIRST_SLEEP': '.3',
            'FAKE_FIRST_STDOUT': 'hidden output\n', 'FAKE_FIRST_STDERR': 'hidden error\n',
            'FAKE_FIRST_STATUS': '7', 'FAKE_PROGRAM_SLEEP': '.03', 'FAKE_PROGRAM_STDOUT': 'measured\n'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '2')
        self.assertEqual(result.stdout, 'measured\n')
        self.assertNotIn('hidden', result.stderr)
        shown = float(re.search(r'time: (\d+\.\d{3}) ms', result.stderr)[1])
        self.assertGreaterEqual(shown, 25)
        self.assertLess(shown, 250, 'the first 300ms sleep must stay outside the second timer')

    def test_warmup_does_not_consume_piped_runtime_input(self):
        counter = self.root / 'starts'
        result = self.invoke(self.source.name, '-t', input='one input\n', env={
            'FAKE_PROGRAM_COUNTER': str(counter), 'FAKE_PROGRAM_STDIN': '1'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '2')
        self.assertEqual(result.stdout, 'one input\n')

    def test_warmup_auto_file_io_reopens_input_without_output_pollution(self):
        self.data(incoming='same input\n')
        counter = self.root / 'starts'
        result = self.invoke(self.source.name, '-f=auto', '-tm', env={
            'FAKE_PROGRAM_COUNTER': str(counter), 'FAKE_PROGRAM_STDIN': '1',
            'FAKE_FIRST_STDOUT': 'hidden\n', 'FAKE_FIRST_STDERR': 'hidden\n'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '2')
        self.assertEqual(result.stdout, '')
        self.assertEqual((self.cwd / 'output.txt').read_text(), 'same input\n')
        self.assertNotIn('hidden', result.stderr)

    def test_warmup_preserves_runtime_arguments_and_shows_only_measured_command(self):
        counter, arguments = self.root / 'starts', self.root / 'argv.json'
        result = self.invoke(self.source.name, '-t', '--show-command', '--', '--', 'a b', '', '--', env={
            'FAKE_PROGRAM_COUNTER': str(counter), 'FAKE_PROGRAM_ARGS': str(arguments)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '2')
        self.assertEqual(json.loads(arguments.read_text()), ['a b', '', '--'])
        self.assertEqual(result.stderr.count('cp-run: time:'), 1)
        self.assertEqual(len(result.stderr.splitlines()), 3, 'compile, visible run, measurement only')

    def test_warmup_second_exit_status_is_preserved(self):
        counter = self.root / 'starts'
        result = self.invoke(self.source.name, '-t', env={
            'FAKE_PROGRAM_COUNTER': str(counter), 'FAKE_FIRST_STATUS': '7', 'FAKE_PROGRAM_STATUS': '9'})
        self.assertEqual(result.returncode, 9, result.stderr)
        self.assertEqual(counter.read_text(), '2')

    def test_warmup_is_not_enabled_by_a_timeout_alone(self):
        counter = self.root / 'starts'
        result = self.invoke(self.source.name, '--TLE=5000', env={'FAKE_PROGRAM_COUNTER': str(counter)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '1')

    def test_warmup_is_not_enabled_without_measurement_flags(self):
        counter = self.root / 'starts'
        result = self.invoke(self.source.name, env={'FAKE_PROGRAM_COUNTER': str(counter)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '1')

    def test_warmup_supports_combined_file_time_memory_short_flags(self):
        counter = self.root / 'starts'
        result = self.invoke(self.source.name, '-ftm', env={'FAKE_PROGRAM_COUNTER': str(counter)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '2')
        self.assertIn('-DFILEO', self.calls()[-1])

    def test_warmup_preserves_terminal_input_for_the_measured_run(self):
        counter = self.root / 'starts'
        master, slave = os.openpty()
        process = None
        try:
            process = subprocess.Popen([str(SCRIPT), self.source.name, '-t'], cwd=self.cwd,
                env=self.environment({'FAKE_PROGRAM_COUNTER': str(counter), 'FAKE_PROGRAM_STDIN': '1'}),
                stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            os.close(slave); slave = -1
            os.write(master, b'terminal input\n')
            stdout, stderr = process.communicate(timeout=20)
            self.assertEqual(process.returncode, 0, stderr)
            self.assertEqual(counter.read_text(), '2')
            self.assertEqual(stdout, 'terminal input\n')
        finally:
            os.close(master)
            if slave != -1: os.close(slave)
            if process is not None and process.poll() is None:
                process.kill(); process.communicate()

    def test_warmup_cancellation_does_not_start_the_second_process(self):
        counter = self.root / 'starts'
        process = subprocess.Popen([str(SCRIPT), self.source.name, '-tm'], cwd=self.cwd,
            env=self.environment({'FAKE_PROGRAM_COUNTER': str(counter), 'FAKE_FIRST_SLEEP': '8'}),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
        try:
            deadline = time.monotonic() + 10
            while not counter.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(.01)
            self.assertTrue(counter.exists(), 'warm-up must have started')
            os.killpg(process.pid, signal.SIGTERM)
            stdout, stderr = process.communicate(timeout=5)
            self.assertIn(process.returncode, (143, -signal.SIGTERM), stderr)
            self.assertEqual(counter.read_text(), '1')
            self.assertEqual(stdout, '')
            self.assertNotIn('cp-run: time:', stderr)
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL); process.communicate()

    def test_warmup_applies_to_explicit_debug_and_binary_run(self):
        counter = self.root / 'starts'
        result = self.invoke('debug', self.source.name, '-tm', env={'FAKE_PROGRAM_COUNTER': str(counter)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '2')
        result = self.invoke('run', str(self.cwd / 'main file.out'), '-tm', env={'FAKE_PROGRAM_COUNTER': str(counter)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '4')

    def test_warmup_applies_to_candidate_not_stress_helpers(self):
        self.data(incoming='same\n', expected='same\n')
        counter = self.root / 'starts'
        result = self.invoke('test', self.source.name, '-tm', '--TLE=inf', env={
            'FAKE_PROGRAM_COUNTER': str(counter), 'FAKE_PROGRAM_STDOUT': 'same\n'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '2')
        (self.cwd / 'brute.cpp').write_text('int main(){}')
        (self.cwd / 'gen.cpp').write_text('int main(){}')
        counter.unlink()
        result = self.invoke('stress', self.source.name, 'brute.cpp', 'gen.cpp', '-tm', '--test-iters=1', '--TLE=inf', env={
            'FAKE_PROGRAM_COUNTER': str(counter), 'FAKE_PROGRAM_STDOUT': 'same\n'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(counter.read_text(), '4', 'candidate warms once; each helper runs once')

    def test_measured_auto_command_display_includes_redirections(self):
        self.data()
        result = self.invoke(self.source.name, "-f=auto", "-t", "--show-command",
                             env={"FAKE_PROGRAM_STDIN": "1"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(result.stderr, r"< (?:\S*/)?input\.txt > (?:\S*/)?output\.txt")
        self.assertEqual((self.cwd / "output.txt").read_text(), "hello\n")

    def test_integrated_timeout_uses_runtime_not_compilation(self):
        result = self.invoke(self.source.name, "--TLE=2000", env={
            "FAKE_COMPILE_SLEEP": "2.5", "FAKE_PROGRAM_SLEEP": ".03"})
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_settings_cancel_does_not_rewrite_script(self):
        copied = self.root / "configured.zsh"; shutil.copy2(SCRIPT, copied)
        previous = copied.read_bytes()
        result = self.invoke("--set-defaults", input="1\n3\n-O0\ncancel\n", script=copied)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(copied.read_bytes(), previous)


def _add_matrix(name, rows, operation):
    """Each row is its own test, preserving useful unittest failure names."""
    for label, value in rows:
        def check(self, value=value):
            operation(self, value)
        check.__name__ = "test_" + name + "_" + label
        setattr(CliTest, check.__name__, check)


def _standard(self, value):
    spelling, expected = value
    flags = spelling if isinstance(spelling, tuple) else (spelling,)
    _, args = self.build(*flags)
    self.assertIn(expected, args)


_add_matrix("standard", [
    ("numeric20", ("-std=20", "-std=c++20")),
    ("numeric26", ("-std=26", "-std=c++26")),
    ("native_iso", ("-std=c++23", "-std=c++23")),
    ("native_gnu", ("-std=gnu++23", "-std=gnu++23")),
    ("draft_alias", ("-std=c++2c", "-std=c++2c")),
    ("gnu_draft", ("-std=gnu++2b", "-std=gnu++2b")),
    ("long_alias", ("--std=20", "-std=c++20")),
    ("separate_numeric", (("-std", "20"), "-std=c++20")),
    ("separate_native", (("-std", "gnu++23"), "-std=gnu++23")),
], _standard)


def _compiler_alias(self, alias):
    clang = alias.lower().startswith("clang")
    _, args = self.build("--compiler=" + alias, env={"FAKE_COMPILER_FAMILY": "clang" if clang else "GCC"})
    warnings = CLANG_BASE_WARNINGS if clang else BASE_WARNINGS
    for flag in warnings:
        self.assertIn(flag, args)


_add_matrix("compiler_alias", [(str(index), value) for index, value in enumerate(
    ("GCC", "gcc", "g++", "GcC", "clang", "clang++", "ClAnG++"))], _compiler_alias)


def _invalid_usage(self, args):
    self.rejected(*args)


_add_matrix("invalid", [
    ("compiler", ("compile", "--compiler=unknown")),
    ("empty_compiler", ("compile", "--compiler=")),
    ("empty_name", ("compile", "--wsp-name=")),
    ("empty_destination", ("compile", "--dest-dir=")),
    ("negative_time", ("compile", "--TLE=-1")),
    ("zero_time", ("compile", "--TLE=0")),
    ("float_time", ("compile", "--TLE=1.5")),
    ("zero_memory", ("compile", "--MLE=0")),
    ("float_memory", ("compile", "--MLE=1.5")),
    ("compile_time", ("compile", "-t")),
    ("compile_memory", ("compile", "-m")),
    ("compile_auto_io", ("compile", "-f=auto")),
    ("manual_test", ("test=manual",)),
    ("test_f", ("test", "-f")),
    ("test_f_cluster", ("test", "-ftm")),
    ("stress_f", ("stress", "-f=auto")),
    ("cin_normal", ("--cin",)),
    ("cin_stress", ("stress", "--cin")),
    ("cout_normal", ("--cout",)),
    ("sep_normal_test", ("test", "--sep=\\n###\\n")),
    ("seed_normal", ("--seed=1",)),
    ("find_compile", ("compile", "--find=main")),
    ("run_missing_file", ("run",)),
    ("f_empty", ("-f=",)),
    ("f_duplicate", ("-f", "-f=auto")),
    ("f_removed_mode", ("-f=manual",)),
    ("f_unknown_mode", ("-f=unknown",)),
    ("f_path_shorthand", ("-f=data.in",)),
    ("f_separate_unknown", ("-f", "data.in")),
    ("cluster_without_f_value", ("-tm=auto",)),
], _invalid_usage)


_add_matrix("removed_option", [(str(index), (option,)) for index, option in enumerate(
    ("--no-run", "--debug-flags", "--extra-debug-flags", "--mode=extra",
     "--test", "--run=main.out", "--run-file=main", "--run-args"))], _invalid_usage)


def _guard_reject(self, option):
    self.rejected("debug", self.source.name, "--", option)


_add_matrix("debug_guard", [(str(index), option) for index, option in enumerate((
    "-O3", "-Ofast", "-g0", "-g1", "-w", "--no-warnings", "-Wno-everything",
    "-fno-sanitize=address", "-fsanitize-recover=all", "-fomit-frame-pointer",
    "-ffast-math", "-ffinite-math-only", "@hidden.rsp", "-U_GLIBCXX_ASSERTIONS",
    "-D_GLIBCXX_ASSERTIONS=0", "-fsanitize-ignorelist=hidden.txt", "-Xclang",
))], _guard_reject)


def _guard_allow(self, flags):
    result, args = self.build("--profile=debug", "--", *flags)
    self.assertEqual(result.returncode, 0, result.stderr)
    self.assertIn("-fsanitize=address,undefined", args)
    for flag in flags:
        self.assertIn(flag, args)


_add_matrix("debug_allowed", [
    ("O0", ("-O0",)), ("Og", ("-Og",)), ("O1", ("-O1",)),
    ("O2", ("-O2",)), ("g3", ("-g3",)),
    ("sanitizer_add", ("-fsanitize=leak",)),
    ("fatal_sanitizers", ("-fno-sanitize-recover=all",)),
], _guard_allow)


def _find(self, value):
    actual, requested = value
    self.binary(actual, "echo found\n")
    result = self.invoke("run", "--find=" + requested)
    self.assertEqual((result.returncode, result.stdout), (0, "found\n"), result.stderr)


_add_matrix("find", [
    ("bare_to_out", ("task.out", "task")),
    ("out_to_bare", ("task", "task.out")),
    ("exact_bare", ("task", "task")),
    ("exact_out", ("task.out", "task.out")),
    ("exe_unchanged", ("task.exe", "task.exe")),
    ("exe_plus_out", ("task.exe.out", "task.exe")),
], _find)


if __name__ == "__main__":
    unittest.main()
