"""Bounded, validity-aware delta reduction of reproducible wrong answers.

The declared grammar owns count repair. A validator may add problem-specific
constraints; an oracle's successful exit alone is not an input-validity proof.
"""


class ReductionBudget(Exception):
    pass


class ReductionInterrupted(KeyboardInterrupt):
    def __init__(self, best, attempts):
        self.best, self.attempts = best, attempts


class SequenceGrammar:
    """N followed by exactly N integer tokens; no inferred graph/tree grammar."""

    def decode(self, payload):
        words = payload.split()
        if not words or len(words[0]) > 12 or not words[0].isdigit():
            raise CheckUsageError("sequence needs an initial N")
        count = int(words[0])
        if count != len(words) - 1 or count > 100000:
            raise CheckUsageError("sequence needs exactly N values (at most 100000)")
        if any(not re.fullmatch(rb"-?[0-9]{1,64}", word) for word in words[1:]):
            raise CheckUsageError("sequence values must be integers of at most 64 digits")
        return [int(word) for word in words[1:]]

    def encode(self, items):
        return (str(len(items)) + "\n" + " ".join(map(str, items)) + "\n").encode("ascii")


class CaseLineGrammar:
    """T followed by T independent, single-line testcase records."""

    def decode(self, payload):
        rows = payload.splitlines(keepends=True)
        if not rows or not rows[0].strip().isdigit():
            raise CheckUsageError("cases need an initial T")
        if int(rows[0]) != len(rows) - 1 or len(rows) > 100001:
            raise CheckUsageError("cases need exactly T single-line records")
        return rows[1:]

    def encode(self, items):
        return str(len(items)).encode() + b"\n" + b"".join(items)


class LineGrammar:
    def decode(self, payload):
        rows = payload.splitlines(keepends=True)
        if len(rows) > 100000:
            raise CheckUsageError("reduction exceeds 100000 records")
        return rows

    def encode(self, items):
        return b"".join(items)


def reduce_items(payload, grammar, predicate, attempts=200, seconds=30):
    """Complement deletion, then integer simplification; no global-minimum claim."""
    deadline = time.monotonic() + seconds
    items = grammar.decode(payload)
    best, count, cache = payload, 0, {}

    def accepts(proposal):
        nonlocal count, best
        if count >= attempts or time.monotonic() >= deadline:
            raise ReductionBudget
        digest = hashlib.sha256(proposal).digest()
        if digest not in cache:
            count += 1
            cache[digest] = predicate(proposal, deadline)
        if cache[digest]:
            best = proposal
        return cache[digest]

    reason = "no smaller confirmed input"
    try:
        # Canonicalizing a grammar is itself a proposal, never assumed safe.
        initial = grammar.encode(items)
        if not accepts(initial):
            return payload, count, "failure was not reproducible under the declared grammar"
        granularity = 2
        while items:
            width = (len(items) + granularity - 1) // granularity
            changed = False
            for offset in range(0, len(items), width):
                candidate = items[:offset] + items[offset + width :]
                if accepts(grammar.encode(candidate)):
                    items = candidate
                    granularity = max(2, granularity - 1)
                    changed = True
                    break
            if changed:
                continue
            if granularity >= len(items):
                break
            granularity = min(len(items), granularity * 2)
        if isinstance(grammar, SequenceGrammar):
            for index in range(len(items)):
                old = items[index]
                for value in dict.fromkeys((0, 1 if old > 0 else -1, old // 2)):
                    if abs(value) >= abs(old):
                        continue
                    candidate = list(items)
                    candidate[index] = value
                    if accepts(grammar.encode(candidate)):
                        items = candidate
                        old = value
        reason = "completed available reduction steps"
    except ReductionBudget:
        reason = "reduction budget exhausted; best confirmed input retained"
    except KeyboardInterrupt:
        raise ReductionInterrupted(best, count) from None
    return best, count, reason


def minimize_failure(config, directory, bundle):
    """Save reduced files beside untouched original evidence, never over it."""
    original = Path(directory) / "in.txt"
    if original.stat().st_size > 4 * 1024 * 1024:
        print("cp-run: reduction skipped: input exceeds 4 MiB", file=sys.stderr)
        return
    mode = config.get("minimize", "sequence")
    validator = config.get("validator")
    if mode in ("lines", "cases") and not validator:
        raise CheckUsageError("lines/cases reduction requires --validator=PROGRAM")
    grammar = {"sequence": SequenceGrammar, "cases": CaseLineGrammar, "lines": LineGrammar}[mode]()
    main = [*config.get("main_argv", [config["executable"]]), *config.get("runtime_args", [])]
    oracle = config.get("brute_argv", [config["brute"]])
    payload = original.read_bytes()
    with tempfile.TemporaryDirectory(prefix=".cp-run-reduce-", dir=".") as temporary:
        root = Path(temporary)
        incoming, answer, actual, error = [
            root / name for name in ("input", "answer", "actual", "stderr")
        ]

        def predicate(proposal, deadline):
            incoming.write_bytes(proposal)
            # Two confirmations reject simple stateful/flaky failures. Every
            # launch is bounded by both its original allowance and job deadline.
            for _ in range(2):
                remaining = int((deadline - time.monotonic()) * 1000)
                if remaining < 1:
                    raise ReductionBudget
                native = str(config.get("timeout_ms", "inf"))
                budget = remaining if native == "inf" else min(remaining, int(native))
                runner = Runner(
                    timeout_ms=str(budget),
                    memory_mib=str(config.get("memory_mib", "inf")),
                    time_factor="1",
                    memory_factor="1",
                )
                if validator:
                    command = [str(validator)]
                    if str(validator).endswith(".py"):
                        command.insert(0, config.get("validator_interpreter", sys.executable))
                    with (
                        open(incoming, "rb") as stdin,
                        open(os.devnull, "wb") as sink,
                        open(error, "wb") as stderr,
                    ):
                        checked = runner.run(
                            command, stdin=stdin, stdout=sink, stderr=stderr, report=False
                        )
                        if checked.verdict == "INTERRUPTED":
                            raise KeyboardInterrupt
                        if checked.status:
                            return False
                for command, target in ((oracle, answer), (main, actual)):
                    remaining = int((deadline - time.monotonic()) * 1000)
                    if remaining < 1:
                        raise ReductionBudget
                    runner.timeout_ns = min(runner.timeout_ns, remaining * 1000000)
                    runner.kill_time_ns = runner.timeout_ns
                    with open(error, "wb") as stderr:
                        outcome = _run_files(
                            runner, {}, command, incoming, target, "reduction", stderr
                        )
                    if outcome.verdict == "INTERRUPTED":
                        raise KeyboardInterrupt
                    if outcome.status:
                        return False
                difference = compare_case(actual, answer, config)
                if difference.equal or difference.incomplete:
                    return False
            return True

        best, attempts = payload, 0
        try:
            best, attempts, reason = reduce_items(
                payload,
                grammar,
                predicate,
                positive_setting(config.get("minimize_attempts", 200), "reduction attempts"),
                positive_setting(config.get("minimize_seconds", 30), "reduction seconds"),
            )
            # Recheck using the original repetition/limits; changed verdicts
            # never publish an alleged reduction.
            incoming.write_bytes(best)
            with open(error, "wb") as stderr:
                reference = _run_files(
                    _runner(config), {}, oracle, incoming, answer, "reference", stderr
                )
            if reference.verdict == "INTERRUPTED":
                raise KeyboardInterrupt
            trial = dict(config, operation="test")
            result, comparison = run_candidate(
                _runner(trial), trial, main, incoming, actual, answer, "reduced"
            )
            if result.verdict == "INTERRUPTED":
                raise KeyboardInterrupt
            confirmed = (
                not reference.status
                and result.verdict == "WA"
                and comparison
                and not comparison.equal
                and not comparison.incomplete
            )
            if confirmed:
                shutil.copyfile(incoming, Path(bundle) / "reduced-input.txt")
                shutil.copyfile(answer, Path(bundle) / "reduced-ans.txt")
                shutil.copyfile(actual, Path(bundle) / "reduced-out.txt")
            note = {
                "strategy": mode,
                "attempts": attempts,
                "reason": reason,
                "confirmed": bool(confirmed),
                "original_bytes": len(payload),
                "reduced_bytes": len(best),
            }
            (Path(bundle) / "reduction.json").write_text(json.dumps(note, indent=2) + "\n")
            print(
                "cp-run: reduction: {} -> {} bytes; {}{}".format(
                    len(payload),
                    len(best),
                    reason,
                    "" if confirmed else "; not confirmed, original retained",
                ),
                file=sys.stderr,
            )
        except KeyboardInterrupt as stop:
            partial = stop.best if isinstance(stop, ReductionInterrupted) else best
            (Path(bundle) / "partial-reduced-input.txt").write_bytes(partial)
            (Path(bundle) / "reduction.json").write_text(
                json.dumps(
                    {
                        "confirmed": False,
                        "interrupted": True,
                        "original_bytes": len(payload),
                        "partial_bytes": len(partial),
                    }
                )
                + "\n"
            )
            raise
        except (CheckUsageError, CheckSetupError, ReductionBudget) as error:
            print("cp-run: reduction skipped: " + str(error), file=sys.stderr)
