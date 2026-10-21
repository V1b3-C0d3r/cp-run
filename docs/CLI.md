# CLI reference

## Commands and arguments

```text
cp-run [FILE] [OPTIONS] [-- COMPILER_ARGS [-- PROGRAM_ARGS]]
cp-run compile [FILE] [OPTIONS] [-- COMPILER_ARGS]
cp-run debug[=PROFILE] [FILE] [OPTIONS] [-- COMPILER_ARGS]
cp-run run [BINARY] [OPTIONS] [-- PROGRAM_ARGS]
cp-run test[=auto] [run] [CASE...] [FILE [IN [ANS [REPORT]]]] [OPTIONS] [TAILS]
cp-run stress [run] [MAIN [BRUTE [GEN]]] [OPTIONS] [TAILS]
cp-run tr [IN [ANS [REPORT]]] [OPTIONS] [-- PROGRAM_ARGS]
cp-run sr BRUTE GEN [OPTIONS] [-- PROGRAM_ARGS]
cp-run --help | --version | --set-defaults
cp-run --export-settings=FILE | --import-settings=FILE
```

`[ ]` means optional, uppercase words are values you supply, and `...` means repetition. These symbols are not typed.

| Command | Result |
| --- | --- |
| No command | Compile and run |
| `compile` | Compile only; stdout contains the absolute binary path |
| `debug`, `debug=` | Compile and run with the saved `debug` profile |
| `debug=NAME` | Compile and run a saved profile whose kind is `debug` |
| `run` | Run an existing executable; no compiler needed |
| `test`, `test=auto` | Check a whole input or independent cases; [examples](TESTING.md) |
| `stress` | Compare candidate, reference and generator; [examples](TESTING.md#stress-testing) |
| `test run`, `test=auto run`, `stress run` | Check existing binaries instead of compiling |
| `tr`, `sr` | `test run -`, `stress run -`; reuse the last primary binary |

Put file operands before options. Omitted source FILE means the only regular local `*.cpp`, otherwise the saved fallback `main.cpp`. An explicitly missing file is an error. Use `./run`, `./-name.cpp` or `./123.cpp` when a filename resembles a command, option or case number. Empty quoted test slots `""` keep that slot's default.

Value options accept **both** `--name=VALUE` and `--name VALUE`, including `--wsp-dir`. `-std=23` and `-std 23` work too. Required values are nonempty; `--warm-up` and `--average` also accept omitted numeric operands as described below; use `=` when a wrapper value starts with `-`. Quote paths containing spaces. Boolean options take no value. Scalar repetitions use the last value; booleans may repeat; different profiles conflict; `-f`/`--file-io` share one permitted occurrence.

## Options

| Option | Purpose / factory default |
| --- | --- |
| `--compiler=NAME` | `GCC`, `gcc`, `g++`, `clang` or `clang++`, case-insensitive; `GCC` |
| `-std=VALUE` | Number, native standard or alias; newest advertised ISO C++ mode |
| `--profile=NAME` | Apply a saved `debug` or `flags` profile to a source build |
| `--no-w` | Omit generated base/profile warnings; native `-w` is separate |
| `-f`, `--file-io` | Identical saved action; factory action adds `-DFILEO` |
| `-f=auto` | Redirect program stdin/stdout; also `-f auto` |
| `--wsp-dir=DIR` | Existing workspace path, relative to the current directory or absolute; `./` |
| `--wsp-name=NAME` | Find an ancestor by name, or verify an explicit workspace directory |
| `--dest-dir=DIR` | Workspace-relative binary directory; `./` |
| `--save-relpath` | Preserve the source-directory subtree; its own destination default is `./` |
| `-o PATH` | Exact output path; also `-oPATH`, `--output=PATH` or `--output PATH` |
| `--find=NAME` | Find an omitted binary FILE under workspace/destination |
| `-t`, `--time` | Elapsed program time in milliseconds |
| `-m`, `--memory` | Peak resident memory in KiB |
| `--warm-up[=0\|1]` | Hidden warm-up with `-t`/`-m`; saved default 1, bare means 1 |
| `--average[=N]` | Measured runs: median time / maximum RSS; saved default 1, bare uses saved N, 0 means 1 |
| `--time-unit=s\|ms` | Time display; `ms` |
| `--memory-unit=UNIT` | `B`, `KB`, `KiB`, `MB`, `MiB`; `KiB` |
| `--TLE=MS` | Positive integer ms or `inf`; test/stress 1500, other modes `inf` |
| `--MLE=MiB` | Positive integer MiB or `inf`; test/stress 256, other modes `inf` |
| `--show-command` | Show the actual quoted commands on stderr |
| `--cin` | Read test input and answer from framed stdin |
| `--cout` | Write the test/stress report to stdout |
| `--sep=TEXT` | Independent-case separator; `\n\n` |
| `--test-iters=N` | Positive maximum selected cases or stress iterations |
| `--seed=N` | Stress starting seed, unsigned 64-bit integer; `4` |
| `--set-defaults` | Open the standalone settings menu |
| `--export-settings=FILE`, `--import-settings=FILE` | Standalone preferences transfer, no compiler needed |
| `--help` | Show help without finding a compiler |
| `--version` | Show cp-run and the selected compiler versions |

Short flags combine: `-ftm` uses the saved file action and reports both metrics. For redirection, `-f auto -tm` is the clearest form. Native options such as `-fopenmp` remain compiler arguments.

### File I/O

```sh
cp-run main.cpp -f                         # Define FILEO; program controls its files
cp-run main.cpp -f auto                    # input.txt → stdin; stdout → output.txt
cp-run main.cpp -f=auto sample.in result.txt
cp-run main.cpp --file-io=auto sample.in result.txt
```

`--file-io` is a complete alias of `-f`, including bare, `=auto` and separate `auto` forms. `auto` accepts up to two adjacent filename operands, IN then OUT. Use `./` for a filename starting with `-`. The macro name, preferred action and filenames are editable in settings. Without `-f`, streams are inherited. [Working file-I/O examples](../examples/README.md#file-io) show both actions.

Defining the macro requires compilation; redirection requires execution. `-f` is unavailable in `test`/`stress`, which manage their own streams. Missing input is a runtime file-open error; input is opened before output, so that error does not truncate the output file.

## Compiler and program arguments

| Operation | First `--` | Second `--` |
| --- | --- | --- |
| Ordinary, source `test`/`stress` | Start compiler arguments | Start program arguments |
| `compile`, `debug` | Everything remaining goes to compiler | Literal compiler argument |
| Any binary-only command | Everything remaining goes to program | Literal program argument |

```sh
cp-run main.cpp -- -pthread -- --input data.txt
cp-run main.cpp -- -- --input data.txt       # Empty compiler tail
cp-run run ./main.out -- --input data.txt
```

Before `--`, known wrapper options are handled and other compiler options are forwarded. Common separate compiler operands are preserved; put unfamiliar option/operand pairs after `--`. Tails preserve order, spaces and empty arguments without shell evaluation. Numeric standard shorthand applies before `--`; use native `-std=c++23` inside a compiler tail.

The tracked output option is appended last. Therefore choose an output with managed `-o`; a compiler-tail `-o` remains literal but is superseded. Debug profiles also inspect compiler arguments for known weakening options. All other compiler errors remain the compiler's responsibility.

## Workspace and output paths

With no routing options, workspace and destination are `./`. `--wsp-name=Main` alone searches physical ancestors for the nearest directory named `Main`. With `--wsp-dir=DIR` as well, it checks that directory's basename instead; no search occurs. There is no default workspace name.

Normal output is `WORKSPACE/DESTINATION/SOURCE_BASENAME.out`, removing the source's last extension. `--save-relpath` inserts the source parent's workspace-relative subtree. An explicit `--dest-dir` overrides either saved destination in any option order.

From `Main/tasks/`, compiling `search/main.cpp`:

| Options | Result relative to `Main/` |
| --- | --- |
| `--wsp-dir=..` | `main.out` |
| `--wsp-dir=.. --save-relpath` | `tasks/search/main.out` |
| `--wsp-dir=.. --save-relpath --dest-dir=build` | `build/tasks/search/main.out` |
| `-o chosen.bin` | `tasks/chosen.bin` |

Destination paths must be relative, contain no `..` component and stay inside the workspace, including through symlinks. Missing output directories are created. Exact `-o` paths start at the invocation directory, add no extension and bypass unused workspace routing. Source/data overwrites, directory outputs and unsafe automatic-output symlinks are rejected.

An explicit binary path likewise bypasses routing. Without it, `run --find=main` searches one resolved destination directory for `main` or `main.out`. Only one final lowercase `.out` is optional: `main.exe` also matches `main.exe.out`, not `main`. Two executable matches are ambiguous. With `--save-relpath`, lookup uses the invocation-directory subtree. `--find` substitutes only MAIN in binary stress; BRUTE and GEN stay explicit.

## Last source and last binary

FILE `-` reuses the last successfully built primary source in a source command, or the last primary launch target in a binary command. `./-` is literal; `-` after `--` is an ordinary argument. `tr IN ANS REPORT` means `test run - IN ANS REPORT`; `sr BRUTE GEN` means `stress run - BRUTE GEN`.

Source and binary records are independent and scoped to the canonical workspace. A failed build does not replace them; compile-only updates the source, not the last-run binary. BRUTE/GEN and hidden repeats never replace MAIN. Missing/unreadable/nonexecutable history fails instead of selecting another file. When exact `-o`/binary paths bypass workspace resolution, history uses canonical cwd; use the same directory for the next `-` lookup, or the matching workspace for routed builds.

History lives under `${XDG_STATE_HOME:-$HOME/.local/state}/cp-run/history`, using private, atomic path records, never shell evaluation. A history-write failure warns without blocking an explicit run. Parallel launches use last committed updates. Observed runs commit after spawn; native execution records the validated target immediately before `exec`, so a subsequent OS exec failure can leave that attempted target as history. This preserves the fast path without a Python process solely for history.

## Compilers and diagnostic profiles

`-std=23` becomes `-std=c++23`. Managed numeric/native/draft values must appear in the selected compiler's advertised C++ dialect list; unsupported values fail before source compilation. Discovery is shared within a stress job. Native standards after `--` keep compiler validation and native syntax. An advertised mode does not promise a complete standard implementation.

`CXX` may name one executable of the selected family, without flags. GCC selection finds genuine GNU GCC rather than Apple's `g++` alias; Clang uses `clang++`. Compiler-specific warning/sanitizer spellings follow the driver; library checks follow the actual selected headers.

| Factory profile | Checks |
| --- | --- |
| `debug` | `-O2 -g2`, ASan/UBSan, float-cast overflow, fatal sanitizer errors, frame pointers, `LOCAL` |
| `extra` | `-Og -g2`, broader bounds/warnings, no sibling-call optimization, stronger library checks |

libstdc++ uses `_GLIBCXX_ASSERTIONS` in `debug`, `_GLIBCXX_DEBUG`/`_GLIBCXX_DEBUG_PEDANTIC` in `extra`. libc++ uses supported FAST/DEBUG hardening respectively. Missing requested hardening fails clearly. Base warnings are `-Wall -Wextra -Wshadow -Wconversion`, plus GCC's `-Wduplicated-cond -Wlogical-op` or Clang's `-Wlogical-op-parentheses -Wtautological-compare`.

A profile has kind `debug` (guarded) or `flags` (ordinary compiler precedence). `debug=NAME` accepts only the first kind; `--profile=NAME` accepts either. Debug profiles reject weaker explicit `-O`/`-g`, disabled sanitizers, recovery/exclusion lists, reserved-macro changes, blanket warning suppression and opaque response/internal forwarding. Stronger levels and additional checks are allowed. `--no-w` deliberately removes generated warnings without disabling runtime checks.

```sh
cp-run debug -- -O0                       # Allowed
cp-run debug=extra -- -O2                 # Error: weakens this profile
cp-run debug -- -fsanitize=leak           # Adds checks
cp-run debug -- -fno-sanitize=address     # Error: disables a check
```

Generated order is standard, common flags/warnings, optional file macro, profile groups, user arguments, effective guarded debug levels, final output. Use `--show-command` or profile preview to inspect exact flags. Sanitizers cannot detect every bug; libstdc++ debug containers may have different compatibility requirements.

Builds stage a fresh artifact before installing it, so an old binary is never run after a no-output build. Debug bundles and ordinary sidecars are retained. Compiler features embedding output locations, such as coverage or split DWARF, may retain the temporary staging path.

### Optimization profiles

Select these factory `flags` profiles with `--profile`.

| Profile | Generated optimization options |
| --- | --- |
| `pragma` | `-O3 -funroll-loops`; keep the compiler's target instruction set |
| `pragma-fast` | GCC: `-Ofast`; Clang: `-O3`. Both add `-ffast-math -funroll-loops -fno-stack-protector` |
| `pragma-native` | `pragma-fast`, plus supported native CPU selection |

```sh
cp-run main.cpp --profile=pragma
cp-run main.cpp --profile=pragma-fast --show-command
cp-run compile main.cpp --profile=pragma-native
cp-run main.cpp --profile=pragma -- -O2   # Ordinary user overrides remain allowed
```

Inspired by the [Codeforces pragma article](https://codeforces.com/blog/entry/129283), these profiles use compiler options rather than inserting pragmas. [GCC optimization pragmas](https://gcc.gnu.org/onlinedocs/gcc/Function-Specific-Option-Pragmas.html) affect subsequent functions; build options also affect preprocessing and linking. Clang needs its own supported options, so the two implementations are not identical pragma rewrites. Your source stays unchanged.

Native selection depends on the compiler's target/backend and actual support, not the standard-library brand. ARM/AArch64 tries `-mcpu=native`; x86 tries `-march=native`. A quiet code-generation probe must succeed; otherwise the profile keeps the existing target ISA. Explicit target/CPU/ISA options or opaque driver forwarding skip automatic native selection. `--show-command` shows the resulting choice.

Native output is intended for the compiling machine. A fixed AVX/SSE list is never enabled automatically: unsupported instructions do not simply disappear, and a [native binary may fail on another CPU](https://gcc.gnu.org/onlinedocs/gcc/x86-Options.html). Recompile on the destination machine or use `pragma`/`pragma-fast` with an appropriate explicit target.

Fast math permits reassociation and assumptions about NaN, infinity and signed zero; it can change numerical results. See [GCC optimization options](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html) and [Clang's fast-math contract](https://clang.llvm.org/docs/UsersManual.html#ffast-math). No profile guarantees faster execution on every input or judge. The [optimization examples](../examples/README.md#optimization-profiles) include deterministic checksums, floating-point differences and literal GCC pragma samples.

## Measurements, limits and streams

Time is monotonic elapsed wall time from process launch to termination, including OS launch/scheduling but excluding compilation, setup and report formatting. Memory is peak resident memory: kernel accounting covers short single-process peaks, while process-group sampling can miss brief peaks or count shared pages twice. `1 MiB = 1024 KiB = 1,048,576 bytes`.

With `-t`/`-m`, compilation happens once, followed by one optional hidden warm-up and N measured executions. `--warm-up`, `--warm-up=1` and `--warm-up 1` agree; `--warm-up=0` disables it. `--average=N` or `--average N` selects 0…100000 measured runs, with 0 treated as 1. Bare `--average` uses its saved count (factory 1); empty values fail. Explicit warm-up/average options require `-t` or `-m`.

Time is the median, rounded to integer nanoseconds for an even count; memory is the maximum peak. **Only the first measured run exposes stdout.** Warm-up and later repetitions discard stdout; auto redirection keeps that first measured output file. Measured stderr stays direct. Failures stop repetition and cannot disappear inside an average. With tests, every measured output is checked; a failing repeat is retained for diagnostics. Test/stress repeat only MAIN; each reference/generator executes once with independent limits.

Regular input is rewound for repeats; a pipe is captured once to a bounded private file before timing and must reach EOF before execution; interactive pipe protocols cannot be replayed. Repeated terminal input is rejected: redirect an input file. A single measured terminal run keeps its original stdin; its warm-up receives EOF. Auto-input warm-up opens the file independently. Warm-up's ordinary exit failure is ignored, but cancellation/limit/setup failures abort. Program-managed side effects can happen on every execution.

`--time-unit` chooses `s`/`ms`; `--memory-unit` chooses `B`, `KB`, `KiB`, `MB`, `MiB`. The selected unit stays primary; a larger supported prefix is appended when applicable: `1536.000 ms (1.536 s)`, `1536 KiB (1.500 MiB)`. KB/MB are decimal; KiB/MiB are binary. Display rounding never changes budgets or comparisons. Bare TLE/MLE values always mean ms/MiB, regardless of display units.

| Mode | Factory time / memory budget |
| --- | --- |
| Ordinary, debug, run | `inf` / `inf`; no observer unless requested |
| test, test run | 1500 ms / 256 MiB per execution |
| stress, stress run | 1500 ms / 256 MiB per role execution |

Explicit `--TLE`/`--MLE` override the corresponding mode default; `inf` disables it. Values are positive integers of up to 12 digits or `inf`. Finishing over the nominal budget produces TLE/MLE. A continuing process is killed at the saved time/memory factor, each factory x2 and independently editable as a finite decimal ≥1. The multiplier is not extra accepted runtime/memory. TLE takes precedence over MLE. Scheduling and RSS sampling can overshoot a kill threshold; this is a local runner, not a kernel allocation cap. Without measurements or finite limits, normal execution keeps its native path.

Compiler and visible program stderr pass directly through. Wrapper errors use `cp-run: ...`. Only `--show-command` prints commands; measurements/prompts/summaries use stderr. `compile` reserves stdout for the binary path; `--cout` reserves it for the report. Compile-only rejects measurements, redirection and runtime arguments; saved runtime budgets are irrelevant there. Binary-only commands reject compiler arguments, profiles, file macros and `-o`.

| Outcome | Exit status |
| --- | --- |
| Success | 0 |
| Setup/I/O/unsupported capability | 1 |
| Invalid wrapper usage/configuration | 2 |
| Wrong answer / incomplete comparison | 3 / 4 |
| TLE / MLE | 124 / 125 |
| Non-executable / missing tool | 126 / 127 |
| Compiler/program failure | Native status unless a limit verdict applies |

## Settings

Run `cp-run --set-defaults`, choose a category, edit and `save`; review the changes and confirm with `y`. No source or compiler is needed.

| Menu | Contents |
| --- | --- |
| Build | Compiler, auto/explicit standard, common flags |
| Files | Fallback source, workspace/destinations, input/answer/output/report, file action/macro |
| Warnings | Common and compiler-specific warning lists |
| Checking & limits | Ordinary/checking budgets, kill factors, separators and comparison/report/spool caps |
| Measurements | Warm-up, repeat count and display units |
| Profiles | Create, copy, edit, preview or delete profiles |
| Stress | Reference/generator sources, iteration ceiling, starting seed |

Enter keeps a value; `back` keeps pending edits; `undo` reverses the latest edit; `reset` restores the displayed menu's factory values. `save`, `cancel` and `help` work from nested menus. `show` in the main menu displays all settings. EOF/interruption cancels.

In a flags editor, entering `-O0 -g` toggles those flags: identical removes, another value replaces, new adds. Use `add FLAGS`, `remove FLAGS` or `clear` explicitly. Quotes preserve spaces; substitutions are never executed.

In Profiles, `new contest debug` copies the guarded base, `new careful extra` copies extra and `new release plain` creates a `flags` set. Type a name to edit; `flags`, `preview`, `advanced`, `kind`, `cpu` and `delete` expose its actions. `cpu` selects `default` (keep the compiler target) or `native` (probe local CPU selection); previews show this policy and copied profiles retain it. Use `delete NAME` from the list. Names begin with a letter, then letters/digits/`_`/`-`, at most 32 characters; `compile`, `run`, `test`, `stress`, `none` and `plain` are reserved. A `flags` set runs through `--profile=release`, not `debug=release`.

Use `export FILE` / `import FILE` in the main menu to transfer pending preferences. Import previews changes; `save` commits them. The standalone `--export-settings=FILE` and `--import-settings=FILE` commands need no source/compiler; explicit import applies immediately. JSON is data only and generated for you. Unknown schemas/keys, duplicate keys, invalid values and oversized exports are rejected before mutation. Import replaces preferences, filling absent new fields from factory defaults; it does not merge arbitrary profile fragments or include history. Export/import before/after upgrading to preserve preferences.

Saving safely replaces the physical installed script, retaining permissions/symlinks and checking for concurrent edits. The script and its directory must be writable. CLI values override saved preferences, which override factory defaults. The default operation remains compile-and-run.

## For contributors

From the extracted source archive:

```sh
python3 development/build.py
python3 -B -m unittest discover -s development/tests -v
python3 development/package.py
```

Source modules and regression tests are under `development/`; end users install only `cp-run.zsh`. CI is configured for Ubuntu 24.04 and macOS on ARM64 and x86-64. Check its results after uploading; local verification does not imply hosted CI has run.

The builder's explicit manifest joins cohesive zsh/Python sources in dependency order. Native settings come from one schema; a dedicated descriptor transports the embedded Python while stdin stays available. Only marked development imports are removed during assembly. Tests exercise the same ordered sources and the generated script; no runtime extraction or helper installation is required.
