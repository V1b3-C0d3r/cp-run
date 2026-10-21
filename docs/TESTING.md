# Test a solution

Start with one input file and one expected answer. Independent cases and stress testing are optional. Ready-to-run examples live in [Examples](../examples/README.md).

## One input, one answer

Save this as `main.cpp`:

```cpp
#include <iostream>
int main() {
    long long a, b;
    while (std::cin >> a >> b) std::cout << a + b << '\n';
}
```

Create `input.txt`:

```text
2 3
```

Create `ans.txt`:

```text
5
```

Run:

```sh
cp-run test main.cpp
```

| File | Who writes it? | Contents in this example |
| --- | --- | --- |
| `main.cpp` | You | Program to compile |
| `input.txt` | You | `2 3` followed by a newline; sent to program stdin |
| `ans.txt` | You | `5` followed by a newline; expected stdout |
| `main.out` | Compiler | Generated executable |
| `real-out.txt` | cp-run | Actual stdout: `5` followed by a newline |
| `test_out` | cp-run | Human-readable protocol below |

```text
cp-run test: selected 1 of 1 cases
Test 1: OK
PASS: 1 selected cases executed; 0 failed
```

You may omit `main.cpp` using the usual source-discovery rule. `test` treats the complete input as one run; a count or multiple cases inside it belong to your C++ program.

### Change files or reuse a binary

```sh
cp-run test main.cpp sample.in correct.ans report.txt
cp-run test "" sample.in correct.ans           # Discover source; keep other named slots
cp-run compile main.cpp
cp-run test run ./main.out input.txt ans.txt
cp-run test run "" input.txt ans.txt --find=main
cp-run test main.cpp --cout                   # Protocol to stdout
```

The four positional slots are **FILE IN ANS REPORT**. Missing or `""` slots use defaults. In `test run`, FILE is an existing binary; `--find` fills an omitted FILE. `--cout` moves the protocol to stdout, but `real-out.txt` is still written. Data paths start at the invocation directory; their parent directories must exist. `-f` is unavailable because the harness already controls stdin/stdout.

### Read a failure

Change `ans.txt` to `6` and run the test again. The report contains:

```text
Test 1: WA
input:
    input:1 | "2 3"
real-out.txt:
  ! real-out.txt:1 | "5"
ans:
  ! ans:1 | "6"
```

`!` marks a differing line. `real-out.txt:1` and `ans:1` are independent line numbers; inserted/deleted lines are shown as `<missing line>`. Display quotes and escapes make control characters visible; they are not added to the raw files. See [a ready-made failing answer](../examples/testing/wrong.ans).

Comparison preserves spaces, tabs and blank lines; it treats LF/CRLF line endings alike and accepts a final line without its newline. The comparison budget defaults to **10000 aligned rows per case/iteration**; successful earlier cases do not consume the next allowance. Reaching it with unchecked output produces **INCOMPLETE** (exit 4), never PASS. Factory caps also bound each row to 1 MiB, total compared bytes per case (both streams) to 64 MiB and diagnostic payload to 256 KiB with at most 10000 rows per section. Oversized comparison data is INCOMPLETE; shortening the displayed diff never changes a completed verdict. All caps are editable in settings. These protect checker memory, not the disk space produced by an unlimited child.

## Independent cases: `test=auto`

Use the same program. Put this in `input.txt`:

```text
2 3

7 8
```

Put this in `ans.txt`:

```text
5

15
```

```sh
cp-run test=auto main.cpp
cp-run test=auto run ./main.out              # Same bundle, existing binary
```

The blank line is the default separator: **`\n\n` means two newline bytes**. Both files split into two corresponding blocks. A new process receives each input block; no case count is inserted. Input/answer block counts must match, even when you select only some cases. A mismatch stops before compilation or output creation.

No separator means one case; an empty file is one empty case. One separator at the end closes the previous case without creating an extra one. Leading/interior empty blocks remain cases. Separators consume their bytes, including boundary newlines; payload whitespace is otherwise unchanged. Bundle separators use LF exactly, so save these files with LF line endings.

`real-out.txt` preserves stdout from selected runs and inserts the separator between them. Programs may already print a final newline; the combined file preserves that too. Each case is compared separately, so joining cannot mix case answers.

### Select cases

```sh
cp-run test=auto 2 main.cpp                 # Only case 2
cp-run test=auto 2 1 main.cpp                # Case 2, then case 1
cp-run test=auto 2 1 main.cpp --test-iters=1 # Only the first selected case: 2
```

Numbers are **1-based original case IDs**, typed immediately after `test=auto` (or after its `run` modifier). Duplicates are removed in requested order. `0` becomes `1` with a notice; negative/out-of-range IDs fail. `--test-iters=N` limits how many selected cases run; it does not choose case N. Numbered selection requires `test=auto`.

### Keep blank lines inside a case

Use [custom.in](../examples/testing/custom.in) and [custom.ans](../examples/testing/custom.ans):

```text
2 3

7 8
###
10 20

-5 8
```

Each case contains two pairs, including an internal blank line. The first sums `2 3` and `7 8`; the second sums `10 20` and `-5 8`. Expected answer:

```text
5
15
###
30
3
```

```sh
cp-run test=auto main.cpp custom.in custom.ans --sep='\n###\n'
```

In `--sep='\n###\n'`, `=` attaches the value; shell quotes keep it literal and are removed by the shell; each `\n` becomes one newline; the three `#` characters are literal. The separator is therefore a line containing exactly `###`, including the newline before and after it. The internal blank lines stay in the cases.

A separator starts/ends with newline and otherwise permits ASCII letters, digits, spaces and `#=_.:+-`. Only visible `\n` is decoded. Quotes, `$`, `@`, other escapes and shell operators are not separator content. Save another default separator in Checking & limits.

## Read input and answer from the console

```sh
cp-run test main.cpp --cin --cout <<'EOF'
2 3
:::answer:::
5
EOF
```

The shell's `<<'EOF'` sends the block literally; its closing `EOF` is not data. The line **`:::answer:::`** separates program input from expected output, then EOF finishes both. Exactly one marker line is required. `--cin` selects stdin; `--cout` selects the report destination. Neither changes `real-out.txt`.

For interactive entry, run `cp-run test --cin`, enter the same lines and finish with Ctrl-D. For a saved frame, use `cp-run test --cin < console.txt`. In `test=auto`, separate cases on both sides of the marker using the selected separator; [console-auto.txt](../examples/testing/console-auto.txt) shows two cases.

For a program that needs a literal `:::answer:::` input/answer line, write **`\:::answer:::`** instead. That leading backslash is removed. No other payload escapes are decoded.

Try [console-literal.txt](../examples/testing/console-literal.txt) with an echoing binary:

```sh
cp-run test run /bin/cat --cin < console-literal.txt
```

## Compiler and runtime arguments

```sh
cp-run test main.cpp -- -DTESTING -- --verbose
cp-run test main.cpp -- -- --verbose
cp-run test run ./main.out -- --verbose
cp-run test main.cpp --profile=extra --TLE=1000 --MLE=256
```

For source tests, the first `--` starts compiler arguments and the second starts program arguments. Adjacent `-- --` means no extra compiler flags. For binary tests, the first `--` starts program arguments. The sum example ignores arguments; [runtime examples](../examples/README.md#runtime-and-profiles) show a program that reads them.

Factory test/stress budgets are 1500 ms and 256 MiB per execution; `--TLE=inf --MLE=inf` disables them. `-t --average=3` optionally warms and checks three measured candidate runs per case, with median time and maximum RSS. No program stdout is duplicated: the harness still stores one result; a failing repeat replaces it for useful diagnostics. Reference and generator run once per stress iteration. Each independent case has its own [resource budgets](CLI.md#measurements-limits-and-streams). Wrong answers and candidate runtime/limit failures do not skip remaining cases. Cancellation/infrastructure errors stop the job. Aggregate failures prioritize TLE, MLE, the first runtime failure, then WA; an actual comparison cutoff produces INCOMPLETE. A child's exit status `3` is a runtime failure, not automatically WA.

## Stress testing

Provide three programs: **MAIN** is your candidate; **BRUTE** is a trusted implementation of the same task; **GEN** generates one input. [The complete stress example](../examples/README.md#stress) includes a correct candidate, an intentionally buggy candidate, a reference and a deterministic generator.

```sh
cp-run stress main.cpp brute.cpp gen.cpp
cp-run stress buggy.cpp brute.cpp gen.cpp --seed=4 --test-iters=20
```

Each source is compiled once. For every iteration, GEN receives the decimal seed as `argv[1]`; its stdout becomes the identical stdin for BRUTE and MAIN. BRUTE's stdout is the expected answer. The default starting seed is **4** and the ceiling is **1000 iterations**, both editable in Stress settings. `--seed=N` requires a value in `0…18446744073709551615`; iteration i uses `(seed + i - 1) modulo 2^64`. GEN must actually use that argument for deterministic generation.

For example, GEN may output `4 2` for seed `4`; BRUTE should output `6`. A candidate that outputs `7` produces the first counterexample. The job stops and saves:

| Saved file | Contents |
| --- | --- |
| `stress-failure/input.txt` | Generated input, such as `4 2` |
| `stress-failure/ans.txt` | BRUTE stdout, such as `6` |
| `stress-failure/real-out.txt` | MAIN stdout, such as `7` |
| `stress-failure/test_out` | Verdict and numbered differences |
| `stress-failure/manifest.json` | Seed, iteration, exact argv, limits/statuses, hashes and replay argv |

Existing bundles get a free suffix instead of being overwritten. A replay command is printed on stderr; it uses the saved input rather than requiring generation to repeat. For the example binaries:

```sh
cp-run test run ./buggy.out stress-failure/input.txt stress-failure/ans.txt replay-report.txt
cp-run stress run ./main.out ./brute.out ./gen.out --test-iters=20
cp-run stress main.cpp brute.cpp gen.cpp -- -O2 -- --verbose
```

Binary stress requires all three executables; `--find` can fill only omitted MAIN: `cp-run stress run "" ./brute.out ./gen.out --find=main`. Shared compiler-tail flags apply to all builds; runtime-tail arguments and a selected profile apply to MAIN only. Every role has an independent runtime budget. Generator/reference failures are labeled separately. `--cin` and `-f` are unavailable.

The regular `real-out.txt` contains the latest candidate output; `test_out` is the protocol unless `--cout` prints it. Failure bundles are retained even with `--cout`. “No difference in N generated cases” means exactly that tested sample, not a proof of correctness.

`test` indexes input/answer byte ranges and validates counts before running. Console input is spooled once (factory 256 MiB cap), not consumed again during execution; bundles are limited to 100000 cases. Source, input, answer, executable and output paths cannot collide; concurrent test/stress writers in the same directory are rejected. Cancelled jobs clean scratch files while preserving available counterexamples and captured stdout.
