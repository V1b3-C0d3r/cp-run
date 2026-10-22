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

**`in.txt`** — bytes sent to the program's stdin:

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

This is **one test**, even if input contains blank lines or an internal testcase count. Program output is kept in `out.txt`; the protocol goes to `test_out`, or stdout with `--cout`. Console mode never prints a separate raw copy of `out.txt`: its output appears only as numbered report lines.

```text
TEST 1
input:
    input:1 | "2 3"
out.txt:
    out.txt:1 | "5"
ans:
    ans:1 | "5"
Test 1: AC
  TIME: ...    MEMORY: ...
FINAL VERDICT: AC
```

**Reading the report:** `input:1` means input line 1; `out.txt:1` means the first actual output line; `ans:1` means answer line 1. The `|` separates the line number from quoted content; the quotes are report notation, not bytes added to the files. `AC` means the output matches. Actual time and memory replace `...`.

Each section has its own line numbering. `!` marks differing output/answer lines. An inserted/deleted line has an explicit missing counterpart; empty files and a missing final newline are labeled. Comparisons preserve spaces and blank rows, normalize CRLF, and tolerate one optional final newline. Input is displayed, not compared to the answer.

```sh
cp-run test main.py samples.in correct.ans report.txt
cp-run test "" samples.in correct.ans       # Discover FILE; retain positional slots
cp-run test run ./solution.out --cout
cp-run test main.cpp -- -DTESTING -- --verbose
```

`FILE`, `IN`, `ANS`, `REPORT` are positional slots. Use `""` to leave one at its default. The first `--` starts backend options; the second starts program arguments. For `test run`, one `--` starts program arguments.

Change the result filename with **`--out=FILE`** (or `--out FILE`), independently of REPORT:

```sh
cp-run test main.py --out=results.txt --cout
cp-run test main.py --wsp-dir=/projects/contest --out='{wsp-dir}/results/actual.txt'
```

The first command keeps raw stdout in `results.txt` and prints the protocol, with lines such as `results.txt:1`. The second stores it at `/projects/contest/results/actual.txt`; create `results/` first. Under **`cp-run configure` → Files → Program output**, save this filename or workspace-prefixed path for all checks and ordinary `-f=auto/out` redirection. Factory files are **`in.txt`, `out.txt`, `ans.txt`, `test_out`**. Imported preferences retain their saved filenames.

## Separate files: `test=mult`

Keep the same `main.py`. One task folder contains fixed filenames:

```text
tests/
  in1.txt     contents: 2 3 + newline
  ans1.txt    contents: 5 + newline
  in2.txt     contents: 7 8 + newline
  ans2.txt    contents: 15 + newline
```

`in` marks program input, `ans` marks expected stdout, and the matching number identifies a test. `.txt` is part of the required filename. These names are not configurable.

```sh
cp-run test=mult main.py --cout
cp-run test=mult 2 1 main.py --cout          # Test 2, then test 1
cp-run test=mult main.py --test-iters=1      # Only first selected test
cp-run test=mult main.py --test-f=samples --cout
```

The factory folder is **`{wsp-dir}/tests`**. In the last command, `samples` is relative to the current directory. Set a permanent folder under **`cp-run configure` → Test files & integrations → Test folder**; `--test-f` overrides it for one invocation. Both `--test-f=samples` and `--test-f samples` work.

For a specific task inside a shared workspace:

```sh
cp-run test=mult src/A.cpp --wsp-dir=/projects/contest \
  --test-f='{wsp-dir}/tasks/A/tests' --cout
```

This reads **`/projects/contest/tasks/A/tests/in1.txt`** and **`ans1.txt`** in the same folder. `{wsp-dir}` is the only path placeholder; it expands to `/projects/contest`. Nothing is inferred from `A.cpp`. `--dest-dir` and `--save-relpath` route binaries independently and do not change test data.

IDs are positive integers and sorted numerically unless selected explicitly. Gaps are accepted: tests 1 and 3 do not require test 2. `in1.txt` plus `in01.txt` is ambiguous and rejected. A missing input/answer pair fails before compilation. Subdirectories are not searched.

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

Here `\n` is a newline escape decoded by cp-run; `###` is literal text. The separator's surrounding newlines belong to the delimiter. Test 1 input is exactly `2 3`, not `2 3` plus a trailing newline. Choose mult files when exact boundary whitespace matters. The default uncounted auto format has **no header count** and ignores one terminal delimiter. Do not pass a packed file without `--bundle-format=counted`.

Auto and mult run each test independently, compare it independently, and apply TLE/MLE independently. A mismatch, crash or resource failure does not prevent the next test.

## Pack and unpack

**Pack collects one task's numbered tests into two files. Unpack restores those files into a chosen folder.** Use mult when you prefer to edit separate files; bundle them for storage or `test=auto`.

Starting with the two tests above:

```sh
cp-run pack samples.in samples.ans
```

This reads `tests/in1.txt`, `in2.txt` into `samples.in`, and `tests/ans1.txt`, `ans2.txt` into `samples.ans`. No source file or compiler is used.

```sh
cp-run unpack samples.in samples.ans --test-f=restored
```

The result is:

```text
restored/
  in1.txt     exact original bytes from tests/in1.txt
  ans1.txt    exact original bytes from tests/ans1.txt
  in2.txt     exact original bytes from tests/in2.txt
  ans2.txt    exact original bytes from tests/ans2.txt
```

Check either representation:

```sh
cp-run test=mult main.py --test-f=restored --cout
cp-run test=auto main.py samples.in samples.ans --bundle-format=counted --cout
```

### Filenames and defaults

| Command | Files used |
| --- | --- |
| `cp-run pack` | Write saved Input and Answer filenames; factory `in.txt`, `ans.txt`. |
| `cp-run unpack` | Read those same saved filenames. |
| `cp-run pack custom.in` | Write `custom.in` and the saved Answer filename. |
| `cp-run unpack custom.in custom.ans` | Read these two files. |
| `cp-run pack=in inputs.bundle` | Pack only input files; do not read/write answers. |
| `cp-run unpack=ans answers.bundle` | Unpack only answer files. |
| `cp-run pack=ans` | Pack only answers into the saved Answer filename. |

The first positional filename is IN, the second is ANS. With `=ans`, the single filename is ANS instead. Stream selectors require `=`: `pack in` treats `in` as a filename, not a selector. Files may use a quoted `{wsp-dir}/PATH` prefix. The folder always comes from `--test-f` or its saved default, never a positional DIR, source name or binary destination.

Packing both streams requires matching case IDs. Sparse IDs are collected in numeric order and become records 1..N; the renumbering is printed. Unpacking both requires equal record counts. Existing identical files are accepted; changed files require `--overwrite`. Stale extra numbered tests are refused even with overwrite: choose a clean folder instead. Validation errors leave both streams intact. Handled write failures are rolled back; a multi-file update is not guaranteed crash-atomic.

### What is inside a bundle?

There is one pack/unpack format: a **decimal record count**, one newline, then records joined by a delimiter. The count belongs to the container, not to program stdin. Payload bytes are never trimmed or given extra newlines. This preserves blank lines, empty tests, CRLF and missing final newlines.

The default delimiter is LF, ASCII Record Separator (byte **0x1E**), LF, written **`\n\x1e\n`** in settings. Pack inserts it; do not type the invisible character manually. For a readable example, choose `--sep='\n###\n'` in **both** directions:

```sh
cp-run pack samples.in samples.ans --sep='\n###\n'
cp-run unpack samples.in samples.ans --test-f=copy --sep='\n###\n'
```

For records containing exactly `2 3` and `7 8` without final newlines, `samples.in` is:

```text
2
2 3
###
7 8
```

The first `2` says there are two records. `###` and its surrounding newlines form the delimiter and are not sent to the program. In a real text file, a final newline after `7 8` belongs to the second record; pack preserves whether it exists. The file extension does not determine its format.

Allowed separator characters are ASCII letters, digits, spaces, `#=_.:+-`, newline escapes and the reserved RS escape. Separators must begin/end with a newline. Under the default codec, RS cannot occur inside a record. Custom-marker collisions, including overlapping record boundaries, fail before writes; choose another delimiter. The bundle stores neither the chosen delimiter nor sparse original IDs, so use the same `--sep` when unpacking/checking.

`test=auto` defaults to **uncounted** input for hand-written files; `--bundle-format=counted` tells it to read pack output. This option selects only the auto reader, not a different pack format. The old `--source`, template options and `--text` conversion modes are removed.

## Console input

```sh
cp-run test main.py --cin --cout <<'EOF'
2 3
:::answer:::
5
EOF
```

`:::answer:::` on its own line separates input from answer. Prefix it with a backslash (`\:::answer:::`) to include that literal marker line in a payload. `--cin` is for whole-file/auto tests, not mult or stress. `--cout` redirects only the protocol; raw program stdout still goes to `out.txt`. In auto/mult, that file joins each selected test's first measured stdout with the internal separator, in execution order (no count header). Use the report to read per-test output.

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
5. Run `cp-run test=mult main.py --cout`. Samples are `tests/in1.txt`, `tests/ans1.txt`, and so on.

Port and wait seconds: `--port=27122 --wait=120`. The task folder is shared with mult; use the same `--test-f=DIR` when importing and checking. For example, `cp-run companion --test-f=samples`, then `cp-run test=mult main.py --test-f=samples --cout`. No automatic source-name subfolder is created. Imports preserve the received strings, including blank lines and empty answers. Remote file paths/limits are not applied. A site's internal testcase count is program input and remains untouched.

The listener binds loopback only, accepts bounded JSON, and performs no compilation/formatting inside requests. It accepts one problem; a contest batch is rejected before writes. Repeated identical samples are idempotent. Changed files need `--overwrite`; stale extra samples require a clean destination to avoid accidentally mixing problems. Requests and imports never overwrite sources or binaries. On WSL, verify browser localhost forwarding for your setup.
