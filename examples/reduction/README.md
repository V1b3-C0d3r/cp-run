# Smaller counterexample

From this directory:

```sh
cp-run stress --minimize=sequence --validator=validate.py --stop-on-failure
```

Expected exit: 3 (WA). `main.py` is deliberately wrong when the sequence contains 7; `brute.py` computes the correct sum. The seeded generator supplies six values. The validator requires a nonempty counted sequence with values 0..10.

The original input stays in `stress-failure/input.txt`. The reduced input should be `1` followed by `7`; `reduced-ans.txt` is `7`, `reduced-out.txt` is `8`. See `reduction.json` for attempts and confirmation. Replay the reduced case:

```sh
cp-run test main.py stress-failure/reduced-input.txt stress-failure/reduced-ans.txt
```

This returns WA again. The example declares a sequence grammar; it does not infer an arbitrary problem's input structure.
