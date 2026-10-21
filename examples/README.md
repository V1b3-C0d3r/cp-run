# Runnable examples

Use a fresh cp-run 1.0 copy, or the factory defaults. Run each section's commands from its named subdirectory. Generated binaries and reports are disposable; the sample inputs and answers are source files.

## Testing

In `testing/`, [sum.cpp](testing/sum.cpp) prints the sum of each input pair. [input.txt](testing/input.txt) contains `2 3` and `7 8`; [ans.txt](testing/ans.txt) expects `5` and `15` on separate lines.

```sh
cp-run test sum.cpp
cp-run test "" input.txt ans.txt                  # Empty FILE slot: discover sum.cpp
cp-run test sum.cpp "" wrong.ans                 # Expected WA, exit 3; answer line 2 is deliberately wrong
```

A passing normal run writes `5\n15\n` to `real-out.txt` and a report to `test_out`. `wrong.ans` changes the expected second line to `16`, so its report shows actual `15` versus expected `16`.

[auto.in](testing/auto.in) and [auto.ans](testing/auto.ans) contain two independent cases, separated by one empty line:

```sh
cp-run test=auto sum.cpp auto.in auto.ans
cp-run test=auto 2 sum.cpp auto.in auto.ans --cout
cp-run test=auto 2 1 sum.cpp auto.in auto.ans --test-iters=1
cp-run test=auto sum.cpp auto.in ans.txt          # Expected usage error, exit 2: two inputs but one answer block
```

The `--test-iters=1` command selects cases 2 then 1 but checks only the first selected case: original case 2. `--cout` puts the report on the terminal; `real-out.txt` still stores program output.

[custom.in](testing/custom.in) has blank lines *inside* cases; [custom.ans](testing/custom.ans) expects two output lines per case. Here a line containing `###` separates cases:

```sh
cp-run test=auto sum.cpp custom.in custom.ans --sep='\n###\n'
```

Quotes keep the separator one shell argument. Each `\n` means one line-feed byte; the three `#` characters are literal data. The separator consumes its surrounding newlines. Each case is compared separately; `real-out.txt` combines raw program outputs with that separator.

[console.txt](testing/console.txt) places input before the exact line `:::answer:::` and the answer after it. [console-auto.txt](testing/console-auto.txt) uses the same marker with blank-line-separated cases:

```sh
cp-run test sum.cpp --cin < console.txt
cp-run test=auto sum.cpp --cin --cout < console-auto.txt
cp-run test run /bin/cat --cin < console-literal.txt
```

[console-literal.txt](testing/console-literal.txt) uses `\:::answer:::` on both sides of the marker. That leading backslash makes the marker ordinary payload; `/bin/cat` must echo the literal line `:::answer:::`.

To check an existing binary, compile once and add `run` immediately after `test`:

```sh
cp-run compile sum.cpp -o sum.out
cp-run test run ./sum.out
cp-run test=auto run 2 ./sum.out auto.in auto.ans
cp-run test run --find sum
cp-run run ./sum.out < input.txt
cp-run tr
```

To preserve the source's subtree beneath a chosen workspace destination:

```sh
cp-run compile sum.cpp --wsp-dir .. --save-relpath --dest-dir build
cp-run test run --find=sum --wsp-dir=.. --save-relpath --dest-dir=build
```

Here `..` is the examples directory. Compilation writes `build/testing/sum.out`; lookup recreates the same route. The `--name=VALUE` and `--name VALUE` option forms are equivalent.

## Stress

In `stress/`, `main.cpp` and `brute.cpp` both add two numbers. `gen.cpp` reads its seed from `argv[1]`; seed `4` produces `4 2`, whose answer is `6`.

```sh
cp-run stress main.cpp brute.cpp gen.cpp --test-iters=3
cp-run stress buggy.cpp brute.cpp gen.cpp --test-iters=3
```

The second command deliberately fails on the first case, exit `3`: `buggy.cpp` prints `7`. Inspect `stress-failure/input.txt`, `ans.txt`, `real-out.txt`, `test_out` and `manifest.json`. The manifest/report contains a replay command. The saved input also works directly:

```sh
cp-run test run ./buggy.out stress-failure/input.txt stress-failure/ans.txt replay.txt
```

This replay deliberately returns WA again. To skip compilation for all stress roles:

```sh
cp-run compile main.cpp -o main.out
cp-run compile brute.cpp -o brute.out
cp-run compile gen.cpp -o gen.out
cp-run stress run ./main.out ./brute.out ./gen.out --test-iters=3 --seed=4
cp-run run ./main.out < ../testing/input.txt
cp-run sr ./brute.out ./gen.out --test-iters=3
```

## File I/O

In `file-io/`, `input.txt` contains `20 22`; the expected answer in `ans.txt` is `42`.

```sh
cp-run main.cpp -f
cp-run main.cpp -f auto
cp-run main.cpp -f=auto input.txt result.txt
cp-run main.cpp --file-io=auto input.txt result.txt
cp-run test main.cpp
```

With factory settings, the first command defines `FILEO`: `main.cpp` opens `input.txt`/`output.txt` itself. The next three commands redirect standard streams; no macro is added. They write `42` to `output.txt` or `result.txt`. The test command checks against `ans.txt` and uses neither `-f` nor the program's file-opening branch. Bare `-f` can be configured to use automatic redirection instead.

## Runtime and profiles

In `runtime/`, `main.cpp` accepts `--echo=TEXT`, `--sleep=MS` and `--memory=MiB`. The demonstration accepts at most 120 ms of sleep and 64 MiB of storage.

```sh
cp-run main.cpp -tm -- -- --echo='hello world' --sleep=60 --memory=16
cp-run compile main.cpp -o program.out
cp-run run ./program.out -tm -- --echo='existing binary' --sleep=60
cp-run run ./program.out -tm --average=3 --warm-up=0 --time-unit=s --memory-unit=MiB -- --echo=once --sleep=60
cp-run run - -- --echo=history
cp-run compile - -o recalled.out
cp-run --export-settings=cp-run-settings.json
cp-run --import-settings=cp-run-settings.json
cp-run run ./program.out --TLE=20 -- --sleep=120
cp-run run ./program.out --MLE=8 -- --memory=32 --sleep=120
```

The first `--` ends wrapper options; the second starts program arguments in an ordinary build-and-run command. Binary `run` needs just one boundary. The final two commands deliberately return TLE (`124`) and MLE (`125`). Reported time includes OS launch/scheduling, so it need not equal the sleep duration. `-tm` performs one hidden warm-up by default in all executable modes. The three-repeat example disables warm-up and prints `once` exactly once; its report is median time / maximum RSS. History recalls source and binary independently. The export/import commands preserve defaults without asking you to edit JSON.

`checks.cpp` deliberately overflows a signed integer. Both diagnostic profiles should stop it with a sanitizer error:

```sh
cp-run debug checks.cpp
cp-run debug=extra checks.cpp
```

To create a plain compiler-flag set, open `cp-run --set-defaults` and enter these lines:

```text
5
new fast-example plain
flags
-O3 -DNDEBUG
save
y
```

Then use it through `--profile`:

```sh
cp-run main.cpp --profile=fast-example -- -- --echo=profile
cp-run debug=fast-example main.cpp
```

The first command prints `profile`. The second deliberately fails with usage status `2`: `debug=NAME` accepts only profiles marked `debug`; plain `flags` sets use `--profile`. Saving edits the installed script, so use a disposable copy while exploring this example.

## Optimization profiles

In `optimization/`, `main.cpp` processes integer arrays and always prints `checksum=4128010`. Try the same workload with three plain flag profiles:

```sh
cp-run main.cpp --profile=pragma
cp-run main.cpp --profile=pragma-fast
cp-run main.cpp --profile=pragma-native --show-command
```

`pragma` uses `-O3` and loop unrolling without relaxing floating-point rules. `pragma-fast` adds aggressive floating-point optimization and removes the stack protector. Both keep the compiler's default CPU target. `pragma-native` additionally requests supported tuning for the machine doing compilation; it falls back when unavailable or when an explicit target is supplied. Inspect the actual command rather than assuming SSE/AVX exists on ARM. None guarantees a speedup; a native binary is intended for its build machine.

To see the floating-point tradeoff, pass an actual NaN at runtime:

```sh
cp-run main.cpp --profile=pragma -- -- nan
cp-run main.cpp --profile=pragma-fast -- -- nan
```

Both print the same integer checksum. The first prints `isnan=1`; aggressive fast math can print `isnan=0` because it assumes non-finite values do not occur. Choose the ordinary profile when that assumption is invalid.

[gcc-pragmas.hpp](optimization/gcc-pragmas.hpp) shows the corresponding literal GCC optimization pragmas. Its compiler guard avoids unknown-pragmas warnings on Clang; the profiles supply Clang's working driver options. These commands include the header before the source without editing it:

```sh
cp-run main.cpp --profile=pragma -- -Werror -include gcc-pragmas.hpp
cp-run main.cpp --profile=pragma-fast -- -Werror -include gcc-pragmas.hpp -DCP_RUN_FAST_PRAGMAS
```

The header has no fixed instruction-set list. The adaptive native profile uses compiler options for that part. All three profiles have kind `flags`, so select them with `--profile`, not `debug=...`.
