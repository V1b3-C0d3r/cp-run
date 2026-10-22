# Runnable examples

Use an installed `cp-run`, or replace it with the absolute path to the built script. Run each block from the indicated directory. Failed examples deliberately return nonzero.

## C / Python

In `languages/`:

```sh
printf '2 3\n' | cp-run main.c --compiler=clang
```

Expected stdout: 5. In `mult/`:

```sh
cp-run test=mult --cout
cp-run test=mult 2 main.py --cout
cp-run test=mult main.py -tm --average=3 --warm-up=0 --cout
cp-run pack input.bundle ans.bundle
cp-run unpack input.bundle ans.bundle --test-f=restored
cp-run test=mult main.py --test-f=restored --cout
cp-run test=auto main.py input.bundle ans.bundle --bundle-format=counted --cout
```

Two fixed pairs in `tests/` (`in1.txt`/`ans1.txt` and `in2.txt`/`ans2.txt`) expect 5 and 15. Each invocation gets an independent verdict and resource statistics. The packed run must also return AC.

## Existing whole-file and auto tests

In `testing/`, `sum.cpp` sums each input pair until EOF. `in.txt`/`ans.txt` expect the two lines 5 and 15; `wrong.ans` deliberately differs.

```sh
cp-run test sum.cpp --cout
cp-run test sum.cpp in.txt wrong.ans --cout
cp-run test=auto sum.cpp auto.in auto.ans --sep='\n\n'
cp-run test=auto 2 sum.cpp auto.in auto.ans --sep='\n\n' --cout
cp-run test=auto sum.cpp custom.in custom.ans --sep='\n###\n'
cp-run test sum.cpp --cin --cout < console.txt
cp-run test=auto sum.cpp --cin --cout --sep='\n\n' < console-auto.txt
```

`auto.in`/`auto.ans` use the old blank-line delimiter explicitly. `custom.in` has blank lines inside cases, so it uses the visible ### marker. `:::answer:::` separates console input/answer; `console-literal.txt` demonstrates escaping that marker with a backslash.

## Stress and reduction

In `stress/`:

```sh
cp-run stress --test-iters=3
cp-run stress buggy.cpp brute.cpp gen.cpp --test-iters=3 --stop-on-failure
```

The second command returns WA and preserves the failure bundle. In `reduction/`, follow the [counterexample example](reduction/README.md) for an intentionally faulty Python solution and validity-aware minimization.

## Companion without a browser

From `mult/`, start:

```sh
cp-run companion main.py --test-f=received
```

In another terminal, from `companion/`:

```sh
curl --fail -H 'Content-Type: application/json' --data-binary @sample.json http://localhost:27122/
```

Then, back in `mult/`:

```sh
cp-run test=mult main.py --test-f=received --cout
```

Expected: two AC samples. A real browser uses Competitive Companion with Custom port 27122 and the same receiver. No source file or remote execution settings are created from the request.

## File I/O and native diagnostics

In `file-io/`, with the factory macro action:

```sh
cp-run main.cpp -f
```

Expected answer: 42 in `out.txt`; the source uses FILEO to open its files. Now run **`cp-run configure` → Files → Bare -f action → auto**, then save. The same flag now redirects streams instead:

```sh
cp-run main.cpp -f in.txt result.txt
cp-run main.cpp -f --cout                # Input file, console stdout: 42
printf '40 2\n' | cp-run main.cpp -f --cin # Console stdin, out.txt: 42
cp-run main.cpp --file-io                # Full alias of -f
cp-run test main.cpp
```

`-f` accepts no `=VALUE`; the action is saved configuration. Console switches require auto, and combining both with `-f` is an error. Tests own I/O and reject `-f`.

In `optimization/`:

```sh
cp-run main.cpp --profile=pragma
cp-run main.cpp --profile=pragma-fast
cp-run main.cpp --profile=pragma-native
```

These are integer workloads. `nan.cpp` separately demonstrates why fast-math is unsuitable for code relying on NaN behavior; it is not promised clean under fast-math plus `-Werror`.

In `runtime/`:

```sh
cp-run main.cpp -tm -- -- --echo='hello world' --sleep=60 --memory=16
cp-run compile main.cpp -o program.out
cp-run debug main.cpp                 # Build only; print the target path
cp-run debug run checks.cpp           # Deliberate undefined behavior; nonzero exit
cp-run run ./program.out -tm --average=3 --warm-up=0 -- --echo=once --sleep=60
cp-run run - -- --echo=history
```

Only the first measured stdout is shown, even with repeated measurements. Runtime arguments after the program boundary are not wrapper options.
