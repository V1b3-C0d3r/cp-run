"""Execute selected sample cases using shared process/comparison services."""

def _runner(config):
    return Runner(timeout_ms=str(config.get("timeout_ms", "inf")),
                  memory_mib=str(config.get("memory_mib", "inf")),
                  show_time=bool(config.get("show_time")),
                  show_memory=bool(config.get("show_memory")), show_command=False,
                  time_factor=config.get('time_factor', '2'), memory_factor=config.get('memory_factor', '2'),
                  time_unit=config.get('time_unit', 'ms'), memory_unit=config.get('memory_unit', 'KiB'))


def _show_run(config, argv, incoming, outgoing):
    if config.get("show_command"):
        print("{} < {} > {}".format(shlex.join([str(x) for x in argv]),
                                    shlex.quote(str(incoming)), shlex.quote(str(outgoing))),
              file=sys.stderr, flush=True)


def _run_files(runner, config, argv, incoming, outgoing, label):
    _show_run(config, argv, incoming, outgoing)
    with open(incoming, "rb") as stdin, open(outgoing, "wb") as stdout:
        return runner.run([str(x) for x in argv], stdin=stdin, stdout=stdout, label=label)


def _publish_actual(source, destination):
    """Replace the latest stress stdout only after its complete copy succeeds."""
    target = Path(destination)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".cp-run-output-", delete=False) as output:
            temporary = Path(output.name)
            with open(source, "rb") as incoming:
                shutil.copyfileobj(incoming, output)
        os.replace(temporary, target)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def _aggregate(verdicts):
    for verdict, status in verdicts:
        if verdict == "INTERRUPTED":
            return status
    if any(verdict == "INCOMPLETE" for verdict, _ in verdicts):
        return 4
    for name, status in (("TLE", 124), ("MLE", 125)):
        if any(verdict == name for verdict, _ in verdicts):
            return status
    for verdict, status in verdicts:
        if verdict not in ("OK", "WA"):
            return status or 1
    return 3 if any(verdict == "WA" for verdict, _ in verdicts) else 0


def execute_test(config):
    """Run selected cases with one supervisor and continue candidate failures."""
    plan = _load_plan(config)
    if not config.get("executable"):
        raise CheckUsageError("test execution needs an executable")
    runner = _runner(config)
    argv = [config["executable"], *config.get("runtime_args", [])]
    verdicts, executed = [], 0
    with check_lock(), tempfile.TemporaryDirectory(prefix=".cp-run-test-", dir=".") as temporary:
        directory = Path(temporary)
        report = Protocol(config)
        combined = directory / "combined.stdout"
        try:
            if plan.zero_notice:
                print("cp-run: tests use 1-based indices; using 1 instead of 0", file=sys.stderr)
            report.emit("cp-run test: selected {} of {} cases".format(len(plan.selected), len(plan.inputs)))
            with open(combined, "wb") as all_output:
                for position, number in enumerate(plan.selected):
                    incoming, answer, actual = (directory / name for name in ("input.txt", "ans.txt", "actual.txt"))
                    plan.inputs[number - 1].copy_to(incoming); plan.answers[number - 1].copy_to(answer)
                    result, comparison = run_candidate(runner, config, argv, incoming, actual, answer, 'test {}'.format(number))
                    executed += 1
                    if position and config.get("auto"):
                        all_output.write(plan.separator)
                    with open(actual, "rb") as stream:
                        shutil.copyfileobj(stream, all_output)
                    if result.verdict == "INTERRUPTED":
                        verdict = "INTERRUPTED"
                    else:
                        comparison = comparison or compare_case(actual, answer, config)
                        verdict = result.verdict if result.status else ("OK" if comparison.equal else "WA")
                        if comparison.incomplete:
                            verdict = "INCOMPLETE"
                    status = 4 if verdict == "INCOMPLETE" else (3 if verdict == "WA" else result.status)
                    verdicts.append((verdict, status))
                    report.emit("Test {}: {}{}".format(number, verdict,
                                " (status {})".format(result.status) if result.status else ""))
                    if verdict != "OK" and comparison is not None:
                        _failure_details(report, incoming, actual, answer, comparison, plan.line_limit)
                    if verdict == "INTERRUPTED":
                        report.emit("Execution interrupted; partial stdout retained in real-out.txt")
                    if verdict == "INCOMPLETE":
                        report.emit("INCOMPLETE: unchecked output remains; no PASS verdict")
                    if result.verdict == "INTERRUPTED":
                        break
            status = _aggregate(verdicts)
            summary = "{}: {} selected cases executed; {} failed".format(
                "PASS" if status == 0 else "INCOMPLETE" if status == 4 else "FAIL",
                executed,
                sum(verdict != "OK" for verdict, _ in verdicts))
            report.emit(summary)
            if not config.get("cout"):
                print("cp-run: " + summary + "; report: " + str(config.get("report", "test_out")), file=sys.stderr)
            os.replace(combined, config["actual"])
            report.finish()
            return status
        except BaseException:
            report.abort()
            raise


