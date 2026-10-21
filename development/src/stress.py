"""Reproducible generator/reference/candidate checks and failure bundles."""

def _file_digest(path):
    """Failure payloads can be huge even when the bounded comparison stopped."""
    digest = hashlib.sha256()
    with open(path, 'rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''): digest.update(chunk)
    return digest.hexdigest()


def _bundle(config, report, directory, seed, iteration, verdict, results):
    """Keep exact bytes and argv; replay does not depend on generator determinism."""
    base = Path("stress-failure")
    for suffix in range(1000000):
        destination = base if suffix == 0 else Path(str(base) + "-" + str(suffix))
        try:
            destination.mkdir()
            break
        except FileExistsError:
            continue
    else:
        raise CheckSetupError("cannot choose a free stress failure directory")
    files = {}
    for filename in ("input.txt", "ans.txt", "real-out.txt"):
        source = directory / filename
        if source.exists():
            target = destination / filename
            shutil.copyfile(source, target)
            files[filename] = _file_digest(target)
    report.copy_to(destination / "test_out")
    destination = destination.resolve()
    if verdict in ("GENERATOR_ERROR", "ORACLE_ERROR") or "candidate" not in results:
        replay = [str(config.get("script", "cp-run")), "stress", "run", str(config["executable"]),
                  str(config["brute"]), str(config["generator"]), "--seed=" + str(seed), "--test-iters=1",
                  "--TLE=" + str(config.get("timeout_ms", "inf")),
                  "--MLE=" + str(config.get("memory_mib", "inf")), "--", *config.get("runtime_args", [])]
    else:
        replay = [str(config.get("script", "cp-run")), "test", "run", str(config["executable"]),
                  str(destination / "input.txt"), str(destination / "ans.txt"), str(destination / "replay-report.txt"),
                  "--TLE=" + str(config.get("timeout_ms", "inf")),
                  "--MLE=" + str(config.get("memory_mib", "inf")), "--", *config.get("runtime_args", [])]
    if config.get('show_time') or config.get('show_memory'):
        boundary = replay.index('--')
        replay[boundary:boundary] = [flag for enabled, flag in (
            (config.get('show_time'), '-t'), (config.get('show_memory'), '-m')) if enabled] + [
            '--average=' + str(config.get('average', 1)), '--warm-up=' + str(int(bool(config.get('warmup'))))]
    manifest = {"seed": seed, "iteration": iteration, "verdict": verdict,
                "commands": {"main": [config["executable"], *config.get("runtime_args", [])],
                             "brute": [config["brute"]], "generator": [config["generator"], str(seed)]},
                "limits": {"timeout_ms": config.get("timeout_ms", "inf"), "memory_mib": config.get("memory_mib", "inf")},
                "measurement": {key: config.get(key) for key in ('warmup', 'average', 'time_factor', 'memory_factor')},
                "results": results, "sha256": files, "replay_argv": replay,
                "compiler": config.get("compiler_info")}
    manifest["executables"] = {}
    for role, key in (("main", "executable"), ("brute", "brute"), ("generator", "generator")):
        path = Path(config[key])
        identity = {"path": str(path.resolve())}
        try:
            identity["sha256"] = _file_digest(path)
        except OSError as error:
            # A program can remove/change its own executable. Keep the useful
            # counterexample even when optional binary identity is unavailable.
            identity["hash_error"] = str(error)
        manifest["executables"][role] = identity
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("cp-run: saved failure: " + str(destination), file=sys.stderr)
    print("cp-run: replay: " + shlex.join(replay), file=sys.stderr)
    return destination


def execute_stress(config):
    """Generate once, feed identical bytes to both programs, stop on first failure."""
    plan = _prepare_check(config)
    for key in ("executable", "brute", "generator"):
        if not config.get(key):
            raise CheckUsageError("stress execution needs " + key)
    runner = _runner(config)
    count = positive_setting(config.get("num_test") or config.get("iterations", 1000), "stress iterations")
    # The CLI supplies its saved value; direct callers share the factory seed.
    start = int(config["seed"]) if config.get("seed") is not None else 4
    main_argv = [config["executable"], *config.get("runtime_args", [])]
    with check_lock(), tempfile.TemporaryDirectory(prefix=".cp-run-stress-", dir=".") as temporary:
        directory, report = Path(temporary), Protocol(config)
        incoming, answer, actual = (directory / name for name in ("input.txt", "ans.txt", "real-out.txt"))
        seed, iteration, results = start, 0, {}
        try:
            report.emit("cp-run stress: start seed {}; maximum {} iterations".format(start, count))
            if not config.get("cout"):
                print("cp-run: stress start seed {}".format(start), file=sys.stderr)
            status = 0
            for iteration in range(1, count + 1):
                seed = (start + iteration - 1) % 2**64
                results = {}
                # Failed generator/reference phases must not borrow payloads
                # from a previous successful iteration in their saved bundle.
                answer.unlink(missing_ok=True)
                actual.unlink(missing_ok=True)
                with open(incoming, "wb") as stream, open(os.devnull, "rb") as no_input:
                    command = [config["generator"], str(seed)]
                    if config.get("show_command"):
                        print(shlex.join(command) + " > " + shlex.quote(str(incoming)), file=sys.stderr)
                    generated = runner.run(command, stdin=no_input, stdout=stream, label="generator {}".format(iteration))
                results["generator"] = {"status": generated.status, "elapsed_ns": generated.elapsed_ns, "peak_bytes": generated.peak_bytes}
                if generated.status:
                    verdict = "INTERRUPTED" if generated.verdict == "INTERRUPTED" else "GENERATOR_ERROR"
                    status = generated.status
                    report.emit("Iteration {}: {} (status {}; seed {})".format(iteration, verdict, status, seed))
                    _bundle(config, report, directory, seed, iteration, verdict, results); break
                reference = _run_files(runner, config, [config["brute"]], incoming, answer, "reference {}".format(iteration))
                results["reference"] = {"status": reference.status, "elapsed_ns": reference.elapsed_ns, "peak_bytes": reference.peak_bytes}
                if reference.status:
                    verdict = "INTERRUPTED" if reference.verdict == "INTERRUPTED" else "ORACLE_ERROR"
                    status = reference.status
                    report.emit("Iteration {}: {} (status {}; seed {})".format(iteration, verdict, status, seed))
                    _bundle(config, report, directory, seed, iteration, verdict, results); break
                result, comparison = run_candidate(runner, config, main_argv, incoming, actual, answer, 'candidate {}'.format(iteration))
                results["candidate"] = {"status": result.status, "elapsed_ns": result.elapsed_ns, "peak_bytes": result.peak_bytes}
                _publish_actual(actual, config["actual"])
                if result.verdict == "INTERRUPTED":
                    verdict, status = "INTERRUPTED", result.status
                    report.emit("Iteration {}: INTERRUPTED (seed {}); partial stdout retained".format(iteration, seed))
                    _bundle(config, report, directory, seed, iteration, verdict, results)
                    break
                comparison = comparison or compare_case(actual, answer, config)
                verdict = result.verdict if result.status else ("OK" if comparison.equal else "WA")
                if comparison.incomplete:
                    verdict = "INCOMPLETE"
                status = 4 if verdict == "INCOMPLETE" else 3 if verdict == "WA" else result.status
                report.emit("Iteration {}: {} (seed {})".format(iteration, verdict, seed))
                if status:
                    _failure_details(report, incoming, actual, answer, comparison, plan.line_limit)
                    _bundle(config, report, directory, seed, iteration, verdict, results)
                    break
            summary = ("No difference in {} generated cases".format(iteration) if status == 0
                       else "INCOMPLETE" if status == 4 else "Stress stopped at iteration {}".format(iteration))
            report.emit(summary)
            if not config.get("cout"):
                print("cp-run: " + summary + "; report: " + str(config.get("report", "test_out")), file=sys.stderr)
            report.finish()
            return status
        except KeyboardInterrupt:
            report.emit("INTERRUPTED at iteration {} (seed {})".format(iteration, seed))
            if incoming.exists():
                _bundle(config, report, directory, seed, iteration, "INTERRUPTED", results)
            report.finish()
            return 130
        except BaseException:
            report.abort()
            raise
