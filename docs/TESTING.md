# Testing, imports and counterexamples

[Quick start](../README.md) · [CLI options](CLI.md) · [Runnable examples](../examples/README.md)

**Start with ordinary `test`.** Use `test=mult` for separate sample files; use `test=auto` only when you want several tests inside a bundle. Every independent test is a separate program launch. Python examples use the saved interpreter (factory **PyPy 3**); add `--interpreter=python3` to use CPython.

## One complete input: `test`

Create `main.py`:

```python
import sys
numbers = list(map(int, sys.stdin.read().split()))
print(sum(numbers))
```

Save these two files beside `main.py` (each ends with a newline):

**`input.txt`** — bytes sent to the program's stdin:

```text
2 3
```

**`ans.txt`** — the stdout you expect:

```text
5
```

```sh
cp-run test --cout
```

This is **one test**, even if input contains blank lines or an internal testcase count. Program output is kept in `real-out.txt`; the protocol goes to `test_out`, or stdout with `--cout`.

```text
TEST 1
input:
    input:1 | "2 3"
real-out.txt:
    real-out.txt:1 | "5"
ans:
    ans:1 | "5"
Test 1: AC
  TIME: ...    MEMORY: ...
FINAL VERDICT: AC
```

**Reading the report:** `input:1` means input line 1; `real-out.txt:1` means the first actual output line; `ans:1` means answer line 1. The `|` separates the line number from quoted content; the quotes are report notation, not bytes added to the files. `AC` means the output matches. Actual time and memory replace `...`.

Each section has its own line numbering. `!` marks differing output/answer lines. An inserted/deleted line has an explicit missing counterpart; empty files and a missing final newline are labeled. Comparisons preserve spaces and blank rows, normalize CRLF, and tolerate one optional final newline. Input is displayed, not compared to the answer.

```sh
cp-run test main.py samples.in correct.ans report.txt
cp-run test "" samples.in correct.ans       # Discover FILE; retain positional slots
cp-run test run ./solution.out --cout
cp-run test main.cpp -- -DTESTING -- --verbose
```

`FILE`, `IN`, `ANS`, `REPORT` are positional slots. Use `""` to leave one at its default. The first `--` starts backend options; the second starts program arguments. For `test run`, one `--` starts program arguments.

## Separate files: `test=mult`

Keep the same main.py and create:

```text
tests/
  1.in     contains: 2 3 + newline
  1.ans    contains: 5 + newline
  2.in     contains: 7 8 + newline
  2.ans    contains: 15 + newline
```

```sh
cp-run test=mult main.py --cout
cp-run test=mult 2 1 main.py --cout         # Test 2, then test 1
cp-run test=mult main.py --test-iters=1     # Only first selected test
```

The directory defaults to `tests`; set `--dest-dir=DIR` or a separate `--test-dir=DIR`. IDs are positive integers, sorted numerically unless selected explicitly. Gaps are accepted: 1 and 3 do not require 2. `1.in` plus `01.in` is ambiguous and rejected. Missing inputs/answers fail before compilation/execution.

Templates are literal paths with **`{n}` = test ID** and **`{stem}` = source basename without extension**:

```sh
cp-run test=mult sum.cpp --dest-dir=tests \
  --in-tmp='{stem}/{n}.in' --ans-tmp='{stem}/{n}.ans'
```

This reads `tests/sum/1.in` and `tests/sum/1.ans`. Quotes protect braces/spaces from shell interpretation; they are not part of the path. `{filename-noExt}`, `{file-name-no-ext}`, `{filename-no-ext}` are accepted stem aliases. No other expressions/placeholders are evaluated.

`--save-relpath` routes binaries under their workspace-relative source directory. `--save-test-relpath` does the same independently for data. For workspace `/project`, source `/project/tasks/A/main.cpp`, and data root `tests`, the latter reads `/project/tests/tasks/A/1.in`. `run --find` uses the corresponding invocation-relative artifact subtree.

## Separated blocks: `test=auto`

The internal delimiter is LF, ASCII **Record Separator** (byte 0x1E), LF. It is written `\n\x1e\n` in settings; pack/unpack insert it automatically. Do not manually type an invisible RS character.

For a hand-written bundle, use a visible marker and an explicit separator. Example `samples.in`:

```text
2 3
###
7 8
```

Corresponding `samples.ans`:

```text
5
###
15
```

```sh
cp-run test=auto main.py samples.in samples.ans --sep='\n###\n' --cout
cp-run test=auto 2 main.py samples.in samples.ans --sep='\n###\n'
```

Here `\n` is a newline escape decoded by cp-run; `###` is literal text. The separator's surrounding newlines belong to the delimiter. Test 1 input is exactly `2 3`, not `2 3` plus a trailing newline. Choose mult files when exact boundary whitespace matters. Legacy auto input has **no header count**, and drops one terminal delimiter as in 1.0.

Auto and mult run each test independently, compare it independently, and apply TLE/MLE independently. A mismatch, crash or resource failure does not prevent the next test.

## Pack/unpack without losing blank lines

A counted bundle starts with the decimal record count and LF. Remaining records are joined with the internal delimiter; payloads are never trimmed or given an extra final newline. The count disambiguates empty final records. Under the RS codec, RS is reserved in payloads; ambiguous custom markers are rejected before writing.

```sh
cp-run --pack=in tests inputs.bundle --source=main.py
cp-run --pack ans tests answers.bundle --source main.py
cp-run test=auto main.py inputs.bundle answers.bundle --bundle-format=counted
cp-run --unpack=in inputs.bundle restored --source=main.py
cp-run --unpack=ans answers.bundle restored --source=main.py
```

The templates also apply to packing/unpacking. Files 1 and 3 are packed in numerical order as container records 1 and 2; the mapping is printed. A plain counted container does not retain sparse filename IDs. Existing conflicting files are refused; use `--overwrite` for planned replacements. Missing DIR/BUNDLE uses routed test root and `input.bundle`/`ans.bundle` (derived from saved input/answer names).

For manual editing, use a separate configurable text marker. `manual.in`:

```text
2
2 3
###
7 8
```

The **first 2 is container metadata**, not part of the first program input. Convert in either direction:

```sh
cp-run --pack=in manual.in inputs.bundle --text-sep='\n###\n'
cp-run --unpack=in inputs.bundle editable.in --text-sep='\n###\n'
```

Use `--text` to select the saved manual marker, or an explicit `--text-sep` to override it. This selects a single manual file instead of a numbered directory. The marker is configurable in defaults. Conversion parses records, checks their count and lossless framing, then writes the other representation. It never globally replaces marker text inside payloads. If a marker collides with data or a partial boundary, choose another one; previous outputs remain intact on validation errors.

## Console input

```sh
cp-run test main.py --cin --cout <<'EOF'
2 3
:::answer:::
5
EOF
```

`:::answer:::` on its own line separates input from answer. Prefix it with a backslash (`\:::answer:::`) to include that literal marker line in a payload. `--cin` is for whole-file/auto tests, not mult or stress. `--cout` redirects only the protocol; raw program stdout still goes to `real-out.txt`. In auto/mult, that file joins each selected test's first measured stdout with the internal separator, in execution order (no count header). Use the report to read per-test output.

## Verdicts and resource statistics

Each full block shows input/output/answer, then verdict, elapsed time and peak RSS. `--report-tests=failed` hides AC payload bodies while retaining all verdict/metric rows. Compiler warnings/errors always remain live on console; runtime stderr is included completely in the checking report, with terminal controls escaped safely.

Public verdicts:

| Verdict | Meaning |
| --- | --- |
| **AC** | Accepted: execution succeeded and the complete output matches. |
| **WA** | Wrong answer: execution succeeded, but output differs. |
| **TLE** | Time limit exceeded by this execution. |
| **MLE** | Memory limit exceeded by this execution. |
| **RE** | Runtime error: nonzero exit or signal, with diagnostics in the report. |
| **CE** | Compilation/preparation error; affected tests do not run. |
 The final summary lists every affected test ID. Its deterministic headline uses CE > MLE > TLE > RE > WA > AC. A compiler failure marks tests NOT RUN; partial crash output cannot turn RE/TLE/MLE into WA. Checker limits, broken generator/oracle and cancellation are separately identified as unfinished/infrastructure states, never AC.

```sh
cp-run test=mult main.py -tm --average=3 --warm-up=1 --cout
cp-run test=mult main.py --TLE=1500 --MLE=256
```

Every independent test gets its own warm-up and measured series. Only the first measured stdout is canonical; time is the median, RSS the maximum, and a later failed repeat is reported separately, with raw evidence retained in `test-repeat-failure*` (or the stress bundle). On failure, the offending run's duration is shown. Generator/reference run once per stress iteration. Limits apply independently to every launch, not to the median or the sum of tests.

Ordinary test remains one process/measurement/verdict. If it internally processes 10 cases, `--test-iters=10` multiplies the whole-process time allowance by 10; it does not identify internal boundaries or multiply memory. Process cutoff is the saved multiplier (default x2), but exceeding the nominal allowance already means TLE/MLE. Reported durations include Python startup/imports; compilation and diff work are excluded.

Comparison defaults: 10000 aligned rows, 1 MiB per row, 64 MiB total checked bytes per case. Diagnostic payload display has separate limits. An unfinished comparison is INCOMPLETE, not AC/WA. Full raw first stdout remains available; report truncation is explicit. Checking limits do not constitute a disk quota on arbitrary user-program output.

## Stress and smaller counterexamples

```sh
cp-run stress main.cpp brute.py gen.py --seed=4 --test-iters=100
cp-run stress run ./main.out ./brute.out ./gen.out --test-iters=100
cp-run stress --stop-on-failure
```

GEN receives the seed as its first program argument; seeds increment modulo 2^64. BRUTE and MAIN receive identical generated stdin. Default source names are main/brute/gen with discovered supported extensions. Runtime arguments after the second boundary apply to MAIN.

Candidate failures do not stop later requested iterations by default. `--stop-on-failure` enables quick-stop. Failure bundles (`stress-failure`, `stress-failure-1`, ...) preserve input, answer, output, seed, role commands/tool metadata and a replay command in manifest.json. The saved bundle count is bounded in defaults; all failures remain in the summary. A generator/oracle failure is reported by role, not called candidate WA.

```sh
cp-run stress --minimize=sequence --stop-on-failure
cp-run stress --minimize=sequence --validator=validate.py --stop-on-failure
```

Sequence grammar: first token N, then exactly N integer tokens. Example `6\n1 2 7 3 4 5\n`. The reducer removes groups, repairs N and simplifies values, accepting only confirmed valid wrong answers. A validator reads proposed stdin and exits 0 for valid input; use it for bounds/sortedness/other problem constraints. `cases` means T followed by T single-line independent records; `lines` means declared independent lines. Both require a validator.

The original bundle is immutable. Confirmed results are saved as reduced-input.txt, reduced-ans.txt, reduced-out.txt and reduction.json. Search is bounded by attempts/time, uses no warm-up, checks failures twice and confirms again with original repetition settings. Large or unreproducible inputs are retained without a false reduction claim. Graph/tree structure is not inferred; no globally smallest-input guarantee.

The strategy follows [delta debugging](https://www.cs.purdue.edu/homes/xyzhang/fall07/Papers/delta-debugging.pdf); [hierarchical delta debugging](https://www.cs.ucdavis.edu/~su/publications/icse06-hdd.pdf) motivates keeping structured validity in grammar adapters. See the runnable [reduction example](../examples/reduction/README.md).

## Competitive Companion

1. Install [Competitive Companion](https://github.com/jmerle/competitive-companion#installation).
2. Extension settings → Custom ports: add **27122**.
3. Beside your source, run `cp-run companion main.py`.
4. Open one problem page and click the extension. The foreground receiver saves numbered samples and exits.
5. Run `cp-run test=mult main.py --cout`.

Port and wait seconds: `--port=27122 --wait=120`. Templates and data routing are shared with mult; use identical options for importing and checking. Imports preserve the received strings, including blank lines and empty answers. Remote file paths/limits are not applied. A site's internal testcase count is program input and remains untouched.

The listener binds loopback only, accepts bounded JSON, and performs no compilation/formatting inside requests. It accepts one problem; a contest batch is rejected before writes. Repeated identical samples are idempotent. Changed files need `--overwrite`; stale extra samples require a clean destination to avoid accidentally mixing problems. Requests and imports never overwrite sources or binaries. On WSL, verify browser localhost forwarding for your setup.
