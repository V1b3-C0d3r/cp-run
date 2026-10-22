# CLI reference

[Quick start](../README.md) · [Testing guide](TESTING.md) · [Runnable examples](../examples/README.md)

**Put the command first, then its files, then options.** `cp-run` without a command prepares and runs a discovered source. Paths containing spaces need quotes.

## Commands and argument boundaries

| Command | What it does |
| --- | --- |
| `cp-run [FILE]` | Compile C/C++, or select Python, then run. |
| `cp-run compile [FILE]` | Prepare only; print the absolute target path. |
| `cp-run debug [FILE]` | Prepare with the standard diagnostic profile; do not run. |
| `cp-run debug=extra [FILE]` | Prepare with the stricter diagnostic profile; do not run. |
| `cp-run debug[=NAME] run [FILE]` | Prepare with a diagnostic profile, then run. |
| `cp-run run [TARGET]` | Run an existing executable or Python source. |
| `cp-run test [FILE [IN [ANS [REPORT]]]]` | Check one complete input against one answer. |
| `cp-run test=mult [CASE...] [FILE]` | Check fixed numbered files in the task folder. |
| `cp-run test=auto [CASE...] [FILE [IN [ANS [REPORT]]]]` | Check independently separated records. |
| `cp-run stress [MAIN [BRUTE [GEN]]]` | Compare a candidate with a reference on generated inputs. |
| `cp-run configure` | Edit saved defaults, profiles and file-I/O behavior. |
| `cp-run companion [FILE]` | Receive one problem's samples into the task folder. FILE is optional and protected from replacement. |
| `cp-run pack[=in\|ans] [BUNDLE...]` | Collect numbered files into bundles; see [pack/unpack](#pack-and-unpack). |
| `cp-run unpack[=in\|ans] [BUNDLE...]` | Restore bundles into the numbered task folder. |

For checks on existing targets, insert `run`: `test run`, `test=mult run`, `test=auto run` or `stress run`. `tr` abbreviates `test run -`; `sr BRUTE GEN` abbreviates `stress run - BRUTE GEN`.

FILE is optional. An empty positional slot (`""`) retains its default, for example `cp-run test "" sample.in sample.ans`. Auto/mult case numbers go before FILE, are 1-based and may select several cases in order. A selector of 0 is treated as 1 with a message.

### Compiler/interpreter arguments versus program arguments

The separator `--` ends wrapper options. For source commands that execute, a **second** `--` starts program arguments:

```sh
cp-run main.cpp -- -I include -- --input data.txt
cp-run main.py -- -X dev -- --input data.txt
cp-run debug run main.cpp -- -DTRACE -- --verbose
cp-run test main.cpp -- -DTESTING -- --verbose
```

Build-only `compile`/`debug` have one backend tail. Existing-target `run` variants have one program tail:

```sh
cp-run compile main.cpp -- -O3
cp-run run ./main.out -- --input data.txt
cp-run test run ./main.out -- --verbose
```

Unknown options in the wrapper section are forwarded to the selected backend. Values of known compiler options remain literal arguments; runtime arguments are never interpreted by cp-run. Numeric `-std=23` is shorthand only in the wrapper section: `-- -std=23` reaches the compiler unchanged. Use `--show-command` to inspect the quoted argv on stderr; cp-run executes argument arrays, never that printed text.

**Extension aliases:** `--compile`, `--debug[=NAME]` and `--run` also select operations. They may precede FILE or follow it, before `--`. `--debug` alone builds only; `--debug --run` explicitly builds and runs, in either flag order. Other conflicting operations are errors.

## Source discovery and language defaults

Explicit FILE selects its language: `.c` is C; `.py` is Python; `.cpp`, `.cc`, `.cxx` and `.C` are C++. Discovery checks the current directory, without recursion:

1. Prefer the saved language (factory C++), or `--language=NAME`.
2. Use its sole source; with several sources, use its saved fallback (`main.cpp`, `main.c` or `main.py`). Otherwise request FILE.
3. If that language is absent, use the sole supported source or a unique saved fallback across languages. `--language=auto` starts here.

Stress discovers `brute` and `gen`, preferring the candidate's language. Explicit roles may mix languages. Under **`cp-run configure` → Languages & tools → Language/compiler defaults**, select the discovery preference, separate C/C++ compiler families and Python interpreter. An explicit `--compiler` applies to every native role.

**History:** FILE `-` recalls the workspace's last source or launched target. `./-` is a literal filename. Failed compilation does not replace source history. Python target history retains interpreter arguments; new `--interpreter-arg` values are appended before the source. An explicit new interpreter uses the current interpreter defaults.

## Languages and profiles

| Option | Meaning |
| --- | --- |
| `--language=NAME` | Discovery preference: `c++`, `c`, `python` or `auto`. Explicit FILE wins. |
| `--compiler=NAME` | `GCC`, `gcc`, `g++`, `clang` or `clang++`; any option position. `CC`/`CXX` may select a driver executable but must match the requested family. |
| `--interpreter=NAME_OR_PATH` | User Python executable; factory `pypy3`. Use `python3` for CPython. A missing requested interpreter is an error. |
| `--interpreter-arg=ARG` | Repeatable Python argument; use `=` for dash-leading values. |
| `-std=VALUE` | Existing numeric shorthand or native C/C++ dialect, including `c++26`. Default: newest ISO mode advertised by the compiler, possibly a draft. |
| `--profile=NAME` | Apply a saved diagnostic/flags profile without changing the command. |
| `--no-w` | Omit generated baseline native warnings; incompatible with diagnostic profiles. Explicit warning flags remain. |
| `--show-command` | Display build/run commands on stderr. |

Native `compile` and build-only `debug` print an absolute artifact path. Python preparation checks syntax without importing/running the program and prints its original source path; it creates no fake binary. `run` accepts readable Python sources without executable permission. Python rejects native `-o`, `-std` and macro actions.

### Built-in diagnostics

| Component | `debug` | `extra` |
| --- | --- | --- |
| Native code | `-O2 -g2`, address/undefined/float-cast sanitizers, frame pointers, no sanitizer recovery | `-Og -g2`, additional bounds checks and warnings, no sibling-call optimization |
| Actual libstdc++ | `_GLIBCXX_ASSERTIONS` | `_GLIBCXX_DEBUG`, `_GLIBCXX_DEBUG_PEDANTIC` |
| Actual libc++ | FAST hardening, checked against selected headers | DEBUG hardening, checked against selected headers |
| CPython | `-X dev -W default` | `-X dev -W error` |
| PyPy | `-X track-resources -W default` | `-X track-resources -W error` |

C omits C++ library checks. Unsupported required diagnostics fail clearly. `debug=NAME` accepts only profiles marked **debug**; flags profiles use `--profile=NAME`. Ordinary `cp-run main.cpp --profile=debug` still prepares and runs.

Diagnostic profiles reject known weakening options in both wrapper and backend sections. Native `debug -- -O0` is allowed; `debug -- -O3`, sanitizer disabling, warning suppression and response files are rejected. Stronger allowed `-O`/`-g` settings are retained. Custom profile contents are editable; they are not an unconditional safety guarantee against every arbitrary compiler option.

Python profiles enable interpreter diagnostics, not native sanitizers or a debugger. They reject assertion-removing optimization and conflicting warning filters, including `PYTHONOPTIMIZE`. CPython development diagnostics require 3.7+. Ordinary Python execution adds no version-probe process.

**Optimization profiles:** `pragma`, `pragma-fast` and `pragma-native` are native driver flag sets, not source injections. All include `-Wunknown-pragmas`. Fast variants enable fast-math, which changes NaN/infinity/rounding behavior; native adds capability-checked host tuning. Host-tuned artifacts may not run on another CPU. Explicit overrides use compiler precedence. Before the backend boundary, supported GNU aliases such as `--optimize` are translated for Clang; the raw backend tail stays unchanged.

## Files and routing

| Option | Meaning |
| --- | --- |
| `--wsp-dir=DIR` | Absolute or invocation-relative workspace; factory `./`. A value is required. |
| `--wsp-name=NAME` | Alone: search ancestor directory names. With explicit `--wsp-dir`: verify its basename. No default name. |
| `--dest-dir=DIR` | Workspace-relative **artifact** directory; factory `./`, with a separate `test=mult` default of `tests`. Does not choose the test-data folder. |
| `--save-relpath[=0\|1]` | Preserve source-parent subtree below artifact destination; bare means 1. |
| `-o PATH`, `-oPATH`, `--output=PATH` | Exact native artifact path; bypass unused artifact workspace/destination settings. |
| `--find=NAME` | With omitted run target: look under artifact destination and optional invocation subtree. NAME and NAME.out are equivalent; ambiguity is an error. |
| `--out=FILE` | Raw program stdout for checks or auto-mode `-f`; factory `out.txt`. Distinct from binary `-o`. |
| `--test-f=DIR` | One task's numbered sample folder; factory `{wsp-dir}/tests`. Used by mult, Companion, pack and unpack. |

Artifact settings resolve independently: **explicit CLI → profile override → operation/submode override → global fallback → factory**. Missing map entries inherit; explicit 0 disables a saved boolean. Edit them in **Action/profile routing**. `--find` with `--save-relpath` searches `workspace/destination/relative-path/NAME[.out]`.

**Test storage is simpler:** `--test-f` overrides **Test files & integrations → Test folder**. It never inherits binary routing or adds source subdirectories. Relative folders start at the invocation directory; absolute paths work. `{wsp-dir}/tasks/A/tests` starts at the workspace; `{wsp-dir}` alone selects its root. Filenames are always `inN.txt` and `ansN.txt`, starting at 1. They cannot be configured.

## Workspace-rooted file preferences

Use the literal prefix **`{wsp-dir}/`** in saved filenames or explicit file operands:

| Setting | Example |
| --- | --- |
| Fallback source | `{wsp-dir}/src/main.cpp` |
| Input / answer | `{wsp-dir}/data/in.txt` / `{wsp-dir}/data/ans.txt` |
| Raw program output | `{wsp-dir}/results/out.txt` |
| Test/stress report | `{wsp-dir}/results/test_out` |
| Numbered test folder | `{wsp-dir}/tasks/A/tests` |

Edit file roles in **`cp-run configure` → Files**, and the numbered folder in **Test files & integrations**. C/Python fallbacks and stress roles accept the same prefix. Without it, relative files start at the invocation directory. Ordinary input/output/report parent directories must exist; data imports and pack/unpack create their output directories.

The token is literal data: put it at the beginning and quote it in shell commands. Parent escapes and symlinks escaping an anchored workspace are rejected. No source-stem or per-test filename placeholders are supported.

```sh
cp-run test '{wsp-dir}/src/main.cpp' '{wsp-dir}/data/in.txt' \
  '{wsp-dir}/data/ans.txt' --wsp-dir=/projects/contest --cout
cp-run test=mult main.cpp --test-f='{wsp-dir}/tasks/A/tests' --cout
```

## File I/O

**`-f` takes no mode value.** `--file-io` is its full alias; both use the saved action. Without either flag, ordinary execution keeps console stdin/stdout.

Choose the action with **`cp-run configure` → Files → Bare -f action**:

| Saved action | What `-f` does |
| --- | --- |
| `macro` (factory) | Add `-DFILEO` when compiling C/C++; the program owns its I/O. Python and existing binaries cannot use this compilation action. |
| `auto` | Redirect stdin/stdout using saved Input/Program output files, factory `in.txt`/`out.txt`. Works with sources and existing targets. |

The macro identifier is editable in the same menu. No `-f=auto`, `-f=manual`, `-f=in` or other attached value is accepted. `auto`/`macro` are **settings**, not positional mode keywords. Save the choice once; later invocations need only `-f`.

With the factory macro setting:

```sh
cp-run main.cpp -f                    # Compile with -DFILEO, then run
cp-run compile main.c --file-io       # Compile with -DFILEO without running
```

**After choosing auto in configure:**

```sh
cp-run main.py -f                     # Read in.txt; write out.txt
cp-run main.py -f data.in data.out    # Override both filenames
cp-run run ./main.out --file-io       # Apply saved auto to an existing target
cp-run main.py -f --cout              # Read input file; stdout goes to console
cp-run main.py -f --cin                # Console stdin; save stdout to output file
cp-run main.py -f --cin --out=chosen.txt
```

Auto accepts optional IN and OUT filenames directly after `-f`; another option or `--` ends these operands. One filename replaces IN; two replace IN and OUT. FILE precedes wrapper options or is discovered. A word such as `auto` after `-f` is a literal filename in saved-auto mode, never a mode selector.

`--cin` and `--cout` may override **one** stream in auto. Both together with `-f` are an error. Either switch with macro is an error. Optional filenames keep their IN/OUT slots even when a side is overridden; that side's filename is unused. `--out=FILE` sets the output path without filling the unused input slot.

Input redirection uses file descriptors, not source changes. A missing input is an execution/open error. Output cannot overwrite another protected file role. Test/stress own I/O and reject `-f`; their existing `--cin`/`--cout` meanings are described in [testing](TESTING.md#console-input).

## Measurements and limits

| Option | Meaning |
| --- | --- |
| `-t`, `--time` | Show execution time; activate saved warm-up/repetition settings. |
| `-m`, `--memory` | Show peak RSS. Combine short flags as `-tm` or `-ftm`. |
| `--warm-up[=0\|1]` | Hidden warm-up; saved default 1, bare means 1. |
| `--average[=N]` | Median time and maximum RSS across N measurements; saved default 1. Bare uses saved N; 0 means 1. Maximum 100000. |
| `--time-unit=UNIT` | `s` or `ms` (factory). |
| `--memory-unit=UNIT` | `B`, `KB`, `KiB` (factory), `MB` or `MiB`; an equivalent larger unit is added when useful. |
| `--TLE=MS`, `--MLE=MiB` | Positive integers or `inf`. Factory ordinary/run limits: unlimited; test/stress: 1500 ms / 256 MiB per process. |

Warm-up/repetition controls require `-t` or `-m`; neither is available in build-only commands. Prepare once, optionally warm up, then measure. Only the first measured stdout is canonical. Test/stress verify repeated results and retain separate evidence for a failed repeat.

For ordinary repeated runs with **terminal stdin**, cp-run first runs visibly while recording input, then replays it to hidden warm-up/measurement launches. That visible capture is outside statistics; no-input programs need no EOF. Only its stdout is shown. A failed launch stops the series; failed hidden stderr is replayed completely. Redirected input is replayed from a file or bounded spool. A single terminal measurement without warm-up remains direct.

Measurements exclude compilation, history callbacks, checking and report rendering. Python includes interpreter startup/imports; JIT state does not survive fresh PyPy processes. Peak RSS is resident memory, not virtual address space or a promise of judge-equivalent accounting.

A nominal violation produces TLE/MLE, even if execution finishes before the kill threshold. Saved kill multipliers default to x2. Auto/mult cases have independent limits; whole-file `test` is one process. Its `--test-iters=N` multiplies only the whole-process time allowance for an internal test count, not RSS. [Verdicts and limits](TESTING.md#verdicts-and-resource-statistics).

## Pack and unpack

**The folder contains individual tests. The two bundle files contain their inputs and answers.** Pack reads the folder; unpack writes it. No source file or compiler is needed.

```sh
cp-run pack                               # tests/ → saved in.txt and ans.txt
cp-run pack samples.in samples.ans         # Override both bundle filenames
cp-run unpack samples.in samples.ans --test-f=restored
cp-run pack custom.in                      # Override IN only; ANS stays saved default
cp-run pack=in inputs.bundle               # Inputs only
cp-run unpack=ans answers.bundle --test-f=tests
```

Without a selector, process both streams: first operand is IN, second is ANS. Omitted operands use the saved **Input** and **Answer** filenames, including workspace prefixes. With `=in` or `=ans`, process only that stream and accept at most one filename, defaulting to that stream's saved filename. The command selector uses `=`; `pack in` means an input bundle literally named `in`, plus the default answer bundle.

Both streams must have matching case IDs/counts. Sparse folder IDs are packed in numeric order and renumbered 1..N; the mapping is printed. Bundles use one lossless, count-first format. `--sep` changes its delimiter, not filenames. Existing identical outputs are accepted; conflicting outputs need `--overwrite`. Unpack refuses stale extra cases even with overwrite; choose a clean folder. Validation failures leave both streams unchanged. Writes are individually atomic with rollback for handled failures, not crash-atomic across several files.

[Exact file contents and a complete round trip](TESTING.md#pack-and-unpack).

## Test and integration options

| Option | Meaning |
| --- | --- |
| `--test-iters=N` | Selected-case cap for auto/mult; iteration count for stress; internal count/time factor for whole-file test. |
| `--seed=N` | Required-valued unsigned 64-bit stress seed; factory 4. |
| `--cin` | Tests: framed console input/answer, whole-file/auto only. With ordinary `-f` in saved auto mode: console stdin instead of the input file. |
| `--cout` | Tests/stress: protocol stdout only, raw output remains saved. With ordinary `-f` in saved auto mode: stdout on console instead of the output file. |
| `--report-tests=POLICY` | `all` (factory) or `failed`; failed-only hides accepted payloads but keeps their verdicts/metrics. |
| `--stop-on-failure` | Stop stress at the first candidate failure; default continues requested iterations. |
| `--sep=TEXT` | Delimiter for auto/bundles; visible default `\n\x1e\n` (LF, RS byte, LF). |
| `--bundle-format=FORMAT` | `test=auto` only: `legacy` (uncounted, default) or `counted` (pack output). |
| `--overwrite` | Permit conflicting planned writes in Companion or pack/unpack; does not delete unrelated files. |
| `--port=N`, `--wait=N` | Companion listener port / wait seconds; factory 27122 / 120. |
| `--minimize[=STRATEGY]` | Stress WA reduction: `sequence` (bare default), `cases` or `lines`. |
| `--validator=PROGRAM` | Stdin validator, exit 0 means valid; required for cases/lines reduction. |

See the [testing guide](TESTING.md) for each file's contents, separators, report symbols and counterexamples.

## Preferences

`cp-run configure` edits settings embedded in the installed script. Choose a group, a field, then its value. Preview changes; use undo/reset, then explicitly save or cancel. Profile flag edits toggle matching flags: the same value removes, a changed value replaces, a new flag adds. `add FLAGS` / `remove FLAGS` make intent explicit.

Run `cp-run configure` on its own; extra options/files are rejected before tools run.

Groups cover build defaults, files, limits, warnings, profiles, stress, measurements, language tools, the fixed test folder/integrations and artifact routing. Do not edit JSON to use the menu.

```sh
cp-run --export-settings preferences.json
cp-run --import-settings preferences.json
```

Transfers are validated data-only JSON, without shell evaluation or automatic config loading. Current exports use schema 3; schema 1/2 imports retain supported settings and fill new defaults. Old explicit test directories become workspace-rooted folders; old per-case templates and test-subtree settings are discarded. Existing `1.in`/`1.ans` files are not renamed automatically: rename to `in1.txt`/`ans1.txt`. Export personal settings before replacing the installed script. Rebuilding from modules restores factory settings; export/import around a rebuild to retain personal choices.

## Formatting

There are exactly two forms:

```sh
cp-run main.cpp --make-prettier        # Format and stop
cp-run main.py --make-prettier=check   # Check style without editing; stop
```

Both operate only on selected source files and **never compile, run or compare answers**. Omitted FILE uses source discovery; stress selects MAIN, BRUTE and GEN once each. Binary-only modes cannot format. `--make-prettier check`, empty values and the former `only`/`before` values are not supported. This optional value intentionally requires `=check`.

C/C++ use [clang-format](https://clang.llvm.org/docs/ClangFormat.html), honoring `.clang-format` or otherwise LLVM style with include sorting disabled. Python uses [Ruff](https://docs.astral.sh/ruff/installation/) (`ruff format`), honoring project settings. [Black](https://black.readthedocs.io/en/stable/getting_started.html#installation) can be selected in **Languages & tools → Interpreter/source/standard/tools → Python formatter**.

All required formatters are located before editing starts. Missing tools produce an installation hint. A later formatter failure may leave earlier files formatted. Backend/runtime arguments, output options and execution/measurement controls are incompatible. Formatter diagnostics go to stderr; stdout stays empty. Check returns nonzero when changes are required. Formatting does not lint, fix algorithms, optimize code or inject pragmas.

## Information, values and errors

- `--help`: help without compiler discovery. `--version`: cp-run plus the selected compiler version; an explicit interpreter selects its version instead.
- `--doctor`: list required/optional tools without installing anything.
- Required option values accept `--option=VALUE` and `--option VALUE`, including `--test-f` and `-std`; empty/missing values fail. Dash-leading values use `=VALUE`.
- Optional booleans consume only 0/1. `-f` takes no mode value; choose its action in `cp-run configure`. Pack command selectors require `pack=in`/`pack=ans` (or `unpack=…`); formatter check requires `=check`.
- Compiler diagnostics remain live on stderr. Ordinary runtime stderr is direct; tests put runtime stderr in their protocols. Commands appear only with `--show-command`.

Exit codes: 0 success; 2 wrapper usage error; 3 WA; 4 unfinished comparison; 124 TLE; 125 MLE; 130/143 interruption. Compiler/runtime failures retain meaningful nonzero statuses. A program's own exit 3 means RE, not WA: read the verdict rather than inferring it from the number alone.
