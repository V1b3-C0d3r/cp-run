# CLI reference

[Quick start](../README.md) · [Testing and sample files](TESTING.md) · [Runnable examples](../examples/README.md)

**FILE and positional operands come before options.** Put the operation (`test`, `run`, etc.) first. Values accept either `--option=value` or `--option value`; program arguments belong after the runtime boundary.

## Commands and argument boundaries

```text
cp-run [FILE] [OPTIONS] [-- BACKEND_ARGS [-- PROGRAM_ARGS]]
cp-run compile|debug[=PROFILE] [FILE] [OPTIONS] [-- BACKEND_ARGS]
cp-run debug[=PROFILE] run [FILE] [OPTIONS] [-- BACKEND_ARGS [-- PROGRAM_ARGS]]
cp-run run [TARGET] [OPTIONS] [-- PROGRAM_ARGS]
cp-run test[=auto|mult] [run] [CASE...] [FILE [IN [ANS [REPORT]]]] [OPTIONS]
cp-run stress [run] [MAIN [BRUTE [GEN]]] [OPTIONS]
cp-run companion [FILE] [OPTIONS]
cp-run --pack=in|ans [DIR [BUNDLE]] [OPTIONS]
cp-run --unpack=in|ans [BUNDLE [DIR]] [OPTIONS]
```

**`debug` never runs by default.** Like `compile`, it prepares the program and prints its absolute target path. Add `run` explicitly: `cp-run debug run main.cpp` or `cp-run debug=extra run main.cpp`. Runtime options such as `-t`, `-m` and stream redirection require that explicit run.

**Extension aliases:** `--compile`, `--debug[=PROFILE]` and `--run` select the corresponding command. Put them first or after FILE, before an argument boundary. `cp-run --compile main.cpp` and `cp-run main.cpp --compile` both compile without running. `cp-run main.cpp --debug` builds without running; **`cp-run --debug --run main.cpp`** builds and runs. The two flags also work after FILE and in either order. Standalone `--run` runs an existing target: `cp-run ./main.out --run -- --verbose`. Other conflicting commands are errors. After `--`, aliases remain literal backend/program arguments. To request the compiler's debug information alone, use `-g` (or pass GNU `--debug` in the backend tail).

The ordinary command, `debug run` and source test/stress accept two boundaries: the first starts backend arguments, the second starts program arguments. Binary/interpreted `run` variants have one program boundary. Build-only `compile` and `debug` have one backend tail.

```sh
cp-run main.cpp -- -I include -- --input data.txt
cp-run main.py -- -X dev -- --input data.txt
cp-run run ./main.out -- --input data.txt
cp-run debug run main.cpp -- -DTRACE -- --input data.txt
cp-run test main.cpp -- -DTESTING -- --verbose
```

Unknown options before a boundary go to the backend. After the runtime boundary, everything is program data. Managed numeric `-std` shorthand is translated only before the backend boundary; `-- -std=20` remains literally `-std=20` for the compiler to accept/reject. Use `--show-command` to inspect the actual escaped build/launch argv on stderr. Display quoting is never executed. Before the backend boundary, legacy GNU aliases (`--ansi`, `--no-warnings`, `--optimize`) have their equivalent Clang spelling when Clang is selected; the raw tail is never translated.

## Source discovery and language defaults

An explicit FILE always selects its language: `.c` is C, `.py` is Python, and `.cpp`, `.cc`, `.cxx`, `.C` are C++. Paths may contain spaces when quoted. Source discovery is local, not recursive.

With FILE omitted:

1. Look for the preferred language (factory **C++**, editable in defaults or with `--language=c++|c|python|auto`).
2. Use its sole source; with several, use its saved fallback (`main.cpp`, `main.c` or `main.py`). If several remain without that fallback, ask for FILE.
3. If the preferred language is absent, use a sole supported source, or a unique saved fallback across languages. Otherwise report ambiguity. `auto` starts at this step.

Stress discovers conventional `brute` and `gen`, preferring the main language. Explicit roles may mix languages. Native roles can use separate saved C/C++ compiler families; `--compiler` explicitly selects the family for every native role. `CC` and `CXX` select the driver executable and must match that family.

In **`--set-defaults` → Languages & tools → Language/compiler defaults**, choose the preferred language, C compiler, C++ compiler and Python interpreter. Native `inherit` uses the Build menu's compiler. Python's factory interpreter is **`pypy3`**; a missing requested interpreter is an error, with no silent switch to CPython.

FILE `-` recalls the workspace's last source or launched target; `./-` is literal. `tr` means `test run -`; `sr BRUTE GEN` means `stress run - BRUTE GEN`. Failed compilation does not replace source history. Python target history retains interpreter options; newly supplied `--interpreter-arg` options are appended before the source, and a newly explicit interpreter rebuilds the launch from current defaults.

## Languages and profiles

| Option | Contract |
| --- | --- |
| `--language=NAME` | Preferred omitted-source language: `c++` (factory), `c`, `python` or `auto`. Explicit FILE wins. |
| `--compiler=NAME` | GCC/gcc/g++ or clang/clang++; any option position. C uses a C driver; C++ a C++ driver. `CC`/`CXX` override discovery and must match the requested family. |
| `--interpreter-arg=ARG` | Repeatable explicit Python option, including exact failure replay options; also accepts a separate operand. |
| `--interpreter=NAME_OR_PATH` | Python executable, default **`pypy3`**; use `python3` or an executable path for CPython. Does not select cp-run's internal service Python. |
| `-std=VALUE`, `-std VALUE` | Numeric shorthand or native C/C++ dialect. Default: newest advertised ISO mode, which may be a draft. Invalid managed choices fail before compiling. |
| `--profile=NAME` | Saved diagnostic or plain-flags profile. `debug=NAME` accepts diagnostic profiles only. |
| `--no-w` | Removes baseline native warnings. Incompatible with diagnostic profiles; explicit/common profile warning flags remain. |
| `--show-command` | Show escaped build/run commands on stderr. Otherwise compiler/program diagnostics are unwrapped. |

`compile` and build-only `debug` print an absolute native artifact path. For Python they validate syntax without running/importing the program and print the original source path; no `.out`/portable `.pyc` is created. `debug run` explicitly executes the prepared program. `run` accepts readable `.py` even without executable permission. Python does not support explicit native `-o`, `-std` or macro action. `--profile` selects flags without changing the operation: ordinary `cp-run main.cpp --profile=debug` still builds and runs.

**Built-in diagnostic components:**

| Component | `debug` | `extra` |
| --- | --- | --- |
| Native code | Address/undefined/float-cast sanitizers, `-O2 -g2`, frame pointers, no sanitizer recovery | `-Og -g2`, additional bounds checks and stricter warnings, no sibling-call optimization |
| libstdc++ | `_GLIBCXX_ASSERTIONS` | `_GLIBCXX_DEBUG` and `_GLIBCXX_DEBUG_PEDANTIC` |
| libc++ | FAST hardening, verified in selected headers | DEBUG hardening, verified in selected headers |
| CPython | `-X dev -W default` | `-X dev -W error` |
| PyPy | `-X track-resources -W default` | `-X track-resources -W error` |

Native `debug` combines sanitizers, frame pointers and assertions for actual libstdc++/libc++ headers. `extra` strengthens warnings, bounds/library checks and debug information. C omits C++ library flags. Diagnostic profiles reject known weakening options in both managed and backend arguments; unsupported required diagnostics fail clearly. For example, `debug -- -O0` is allowed, but `debug -- -O3`, disabling sanitizers, response files and warning suppression are rejected.

For example, `cp-run debug run main.py --interpreter=python3 --show-command` launches `python3 -X dev -W default main.py` (paths are resolved in actual output). Without `run`, it only validates syntax and prints the source path. `debug=extra run` replaces the warning action with `error`.

Python `debug`/`extra` use implementation-specific runtime diagnostics, not native sanitizers or an automatic debugger. Assertion-removing optimization and conflicting warning filters are rejected, including `PYTHONOPTIMIZE`. The requested interpreter reports its implementation/version; CPython development diagnostics require 3.7+. Ordinary Python execution has no extra version-probe process. Native `-O` is unrelated to Python's `-O`/`-OO` assertion removal.

Plain `pragma`, `pragma-fast`, `pragma-native` are native driver flag sets, not source injections. All add `-Wunknown-pragmas`; fast variants enable fast-math, and native adds capability-checked host tuning. Fast-math changes NaN/infinity/rounding behavior. Native artifacts are not guaranteed portable to other CPUs. Explicit native overrides retain compiler precedence.

## Files and routing

| Option | Meaning |
| --- | --- |
| `--wsp-dir=DIR` | Workspace path, absolute or relative to invocation; default `./`. Cannot be bare/empty. |
| `--wsp-name=NAME` | Alone: search ancestors. With explicit directory: verify its basename. No default name. |
| `--dest-dir=DIR` | Workspace-relative artifact destination. Default `./`; `test=mult` and Companion default `tests`. |
| `--save-relpath[=0|1]` | Preserve source-parent subtree under destination; bare = 1. |
| `-o PATH`, `-oPATH`, `--output=PATH` | Exact native artifact path; bypass artifact workspace/destination lookup. |
| `--find=NAME` | With omitted run target, check destination and optional invocation subtree. NAME and NAME.out are equivalent; two matches are an error. |
| `--test-dir=DIR` | Separate mult/Companion data directory; otherwise destination is used. |
| `--save-test-relpath[=0|1]` | Append source-parent subtree to test root, independently of artifact routing. |
| `--in-tmp`, `--ans-tmp` | Numbered templates; defaults `./{n}.in`, `./{n}.ans`. |

Settings precedence, per field: **explicit CLI > selected profile override > operation/submode override > global fallback > factory value**. An absent map entry inherits; `0` explicitly disables a saved boolean. Submodes inherit `test`. These settings are editable under `--set-defaults` → Action/profile routing.

Relative-path binary lookup is exactly `workspace/destination/relative-path/NAME[.out]`. Relative source/data paths are physically checked for containment. Do not use `..` in workspace-relative destinations/templates. Exact output bypass does not exempt independently used test-data paths from checks.

## Workspace-rooted file preferences

Prefix a saved filename with **`{wsp-dir}/`** to resolve it from the selected workspace, including when running from a nested directory. For example, in **`--set-defaults` → Files**:

| Setting | Example |
| --- | --- |
| Fallback source | `{wsp-dir}/src/main.cpp` |
| Input | `{wsp-dir}/data/input.txt` |
| Answer | `{wsp-dir}/data/ans.txt` |
| Redirected output | `{wsp-dir}/data/output.txt` |
| Test/stress report | `{wsp-dir}/logs/test_out` |

C/Python fallback sources, the stress reference and generator accept the same prefix in their menus. Parent directories for ordinary I/O and report files must already exist. Discovery still prefers a sole local source before consulting the configured fallback.

Without the prefix, relative file paths keep their usual meaning: **relative to the invocation directory**. The token must be at the start, followed by `/` and a path; `..` and symlinks escaping the workspace are rejected. It is literal data, never shell expansion. Settings export/import preserves it.

The same prefix works in explicit source, `-o`, redirection and checking file operands; quote it in shell commands:

```sh
cp-run test '{wsp-dir}/src/main.cpp' '{wsp-dir}/data/input.txt' \
  '{wsp-dir}/data/ans.txt' --wsp-dir=/projects/contest --cout
```

Numbered patterns also accept it: **`{wsp-dir}/samples/{stem}/{n}.in`** starts at the workspace instead of the usual test-data destination/subtree. Input and answer patterns may use different roots. Mult, pack/unpack and Companion share this interpretation. [Concrete template example](TESTING.md#workspace-rooted-test-files).

## File I/O

`--file-io` is a full alias of `-f`:

```sh
cp-run main.cpp -f                    # Factory action: -DFILEO
cp-run main.py -f=auto data.in data.out
cp-run main.py -f in data.in          # Redirect stdin only
cp-run main.py --file-io=out data.out  # Redirect stdout only
```

Bare action and macro name are editable. Auto defaults to input.txt/output.txt. Optional file operands stop at an option or argument boundary; FILE precedes them or is discovered. File input uses console redirection, not source editing. Missing input is an execution/open failure. Test/stress reject `-f` because they own I/O. Redirected output cannot overwrite another protected role.

## Measurements and limits

`-t`/`--time`, `-m`/`--memory`; short `f/t/m` combine as `-ftm`.

| Option | Default / behavior |
| --- | --- |
| `--warm-up[=0|1]` | Saved default 1; bare 1. Hidden initial launch. |
| `--average[=N]` | Saved default 1; bare uses saved value; 0 means one. Up to 100000. |
| `--time-unit=s|ms` | ms. |
| `--memory-unit=B|KB|KiB|MB|MiB` | KiB; larger-unit equivalent is added when appropriate. |
| `--TLE=MS`, `--MLE=MiB` | Positive integers or `inf`. Ordinary execution, `debug run` and `run` are unlimited; test/stress use 1500 ms / 256 MiB per process. |

Repetition needs `-t` or `-m`. Build once, warm once when selected, measure N launches. Report median elapsed time and maximum peak RSS; expose first measured stdout once. Every measured output is checked. A hidden failed repeat has separate evidence and cannot replace the first stdout or disappear in a median. For redirected input, the first measured stdout is shown and input is replayed from the file or a bounded spool.

With **terminal input and several launches (`--average>1` or an enabled warm-up)**, cp-run first runs the program visibly and records stdin through a pipe. This preparation run is excluded from statistics so typing does not affect the median. A program needing no input finishes without waiting for EOF. Then the recorded input feeds the optional hidden warm-up and N hidden measured runs. Thus this path performs one extra visible launch. Only that visible stdout is shown; successful hidden stdout/stderr is discarded. A failed visible, replayed warm-up or measured run stops the job with its status; failed hidden stderr is replayed in full. Limits still apply to each execution. A single terminal measurement without warm-up remains direct. Test/stress protocols retain their existing behavior.

Measurements exclude compilation/preparation/checking. Python includes interpreter startup/imports. PyPy JIT state does not persist across fresh processes. Native OS peak RSS is measured in bytes internally; it is not virtual address-space size or a promise of online-judge equivalence.

A nominal violation produces TLE/MLE. The program is killed at the saved multiplier (factory x2), or finishes before then with the same violated verdict. Auto/mult tests each have independent limits. Whole-file test is one process; `--test-iters=N` scales only its time budget for a declared internal count. RSS remains one process peak. See [testing](TESTING.md).

## Test, bundle and integration controls

| Option | Meaning |
| --- | --- |
| `--test-iters=N` | Auto/mult selected-case ceiling; stress iteration count; whole-test aggregate time factor. |
| `--seed=N` | Stress unsigned 64-bit seed, default 4; value mandatory. |
| `--cin` / `--cout` | Framed console input+answer / protocol stdout. |
| `--report-tests=all|failed` | All bodies by default; failed-only retains every verdict/metric row and final groups. |
| `--stop-on-failure` | Stress quick-stop behavior; default continues finite independent iterations. |
| `--sep=TEXT` | Internal delimiter; visible default `\n\x1e\n`. |
| `--bundle-format=legacy|counted` | Auto mode: uncounted legacy split or count-first pack output. |
| `--text` | Pack/unpack a manual file using the saved manual separator. |
| `--text-sep=TEXT` | Pack/unpack single manual-file conversion, default marker `\n###\n`. |
| `--source=FILE` | Pack/unpack stem/subtree anchor without compiling. |
| `--overwrite` | Permit replacing the planned imported/unpacked files. |
| `--port=N`, `--wait=N` | Companion listener port / seconds; defaults 27122 / 120. |
| `--minimize[=sequence|cases|lines]` | Opt-in stress WA reduction; bare chooses sequence. |
| `--validator=PROGRAM` | Additional stdin validator; exit 0 means valid. Required for cases/lines. |

Value options accept `=` or a separate operand, including `-f auto`. Required values cannot be absent/empty; dash-leading wrapper values use `=VALUE`. Optional booleans consume only 0/1. Native warning options are forwarded separately from wrapper `--no-w`.

## Preferences

`--set-defaults` edits pending changes with preview, undo/reset, explicit save/cancel. Groups cover build, files, warnings, profiles, limits, measurements, language tools, test layouts and operation/profile routing. Flags toggle: same removes, a changed value replaces, new adds. Use `add FLAGS`/`remove FLAGS` for explicit edits.

`--export-settings=FILE` / `--import-settings=FILE` transfer validated data-only JSON. Schema 1 imports are accepted with legacy values retained and new defaults filled in; exports use schema 2. No auto-loaded config or shell evaluation. Installed-script updates should export/import personal settings.

## Formatting

**`--make-prettier` edits formatting with an external formatter.** It does not optimize code, insert pragmas or fix algorithmic errors. A requested missing formatter stops the operation with an installation hint.

| Command | Edits source? | Compiles/runs? |
| --- | --- | --- |
| `cp-run main.cpp --make-prettier=only` | Yes | No |
| `cp-run main.py --make-prettier=check` | No; nonzero exit if changes are needed | No |
| `cp-run main.cpp --make-prettier` | Yes | Yes, after successful formatting |
| `cp-run --make-prettier` | Yes, discovered source | No |
| `cp-run --make-prettier=before` | Yes, discovered source | Yes |
| `cp-run test main.cpp --make-prettier` | Yes | Compile and check tests |

Install only the needed tool:

- **C/C++:** [clang-format](https://clang.llvm.org/docs/ClangFormat.html); e.g. `sudo apt install clang-format` on Debian/Ubuntu. cp-run uses `.clang-format` when present, otherwise LLVM style, and forces include sorting off.
- **Python:** [Ruff installation](https://docs.astral.sh/ruff/installation/), then `ruff format` is used. Project Ruff settings apply. To use [Black](https://black.readthedocs.io/en/stable/getting_started.html#installation), select `black` in **`--set-defaults` → Languages & tools → Interpreter/source/standard/tools → Python formatter**.

For example, `print( 1+2 )` becomes `print(1 + 2)` with Ruff's default style:

```sh
cp-run main.py --make-prettier=only
cp-run main.py --make-prettier=check    # Exit 0 when no changes are needed
```

Only selected physical source files are formatted, once each; stress includes MAIN, BRUTE and GEN. No recursive project sweep occurs. All formatter executables are resolved before the first edit. A formatter failure stops the build; edits already made by an earlier formatter remain. Binary-only `run` operations cannot format.

Formatter output goes to stderr, leaving stdout for program output or the compiled path. **Formatting is separate from linting**: `ruff check`, import sorting and `clang-tidy` are not invoked. Formatting follows external-tool style rules; review source changes as usual.

## Diagnostics and exit status

`--doctor` lists required/optional tools without installing them. `--help` needs no compiler; `--version` shows script and selected compiler versions; an explicit interpreter selects its version instead. Compilation diagnostics stay on console. Test runtime stderr is captured fully in its protocol; the visible ordinary run keeps direct stderr; successful hidden runs stay silent and failed hidden stderr is replayed.

Exit 0 means success; wrapper usage errors use 2, WA 3, unfinished comparison 4, TLE 124, MLE 125, interruption 130/143. Native compiler/runtime errors retain meaningful nonzero statuses. Do not infer verdicts from exit number alone; a program's own exit 3 is RE, not WA.
