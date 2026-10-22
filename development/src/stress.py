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
    for filename in ("in.txt", "ans.txt", "out.txt"):
        source = directory / filename
        if source.exists():
            target = destination / filename
            shutil.copyfile(source, target)
            files[filename] = _file_digest(target)
    failed_repeat = config.get('_failed_output')
    if failed_repeat and Path(failed_repeat).exists():
        shutil.copyfile(failed_repeat, destination / 'failed-repeat.txt')
    for index, (_, path) in enumerate(config.get('_stderr_paths', [])):
        if Path(path).exists(): shutil.copyfile(path, destination / ('stderr-{}.txt'.format(index)))
    report.copy_to(destination / "test_out")
    destination = destination.resolve()
    if verdict in ("GENERATOR_ERROR", "ORACLE_ERROR") or "candidate" not in results:
        replay = [str(config.get("script", "cp-run")), "stress", "run", str(config["executable"]),
                  str(config["brute"]), str(config["generator"]), "--seed=" + str(seed), "--test-iters=1",
                  "--TLE=" + str(config.get("timeout_ms", "inf")),
                  "--MLE=" + str(config.get("memory_mib", "inf")), "--", *config.get("runtime_args", [])]
    else:
        replay = [str(config.get("script", "cp-run")), "test", "run", str(config["executable"]),
                  str(destination / "in.txt"), str(destination / "ans.txt"), str(destination / "replay-report.txt"),
                  "--TLE=" + str(config.get("timeout_ms", "inf")),
                  "--MLE=" + str(config.get("memory_mib", "inf")), "--", *config.get("runtime_args", [])]
    # A saved candidate failure replays against the saved answer, so only its
    # exact interpreter options are needed; no source/profile is regenerated.
    chosen = config.get('main_argv', [])
    if config.get('executable', '').endswith('.py') and chosen:
        boundary = replay.index('--')
        replay[boundary:boundary] = ['--interpreter=' + chosen[0], *['--interpreter-arg=' + arg for arg in chosen[1:-1]]]
    if config.get('show_time') or config.get('show_memory'):
        boundary = replay.index('--')
        replay[boundary:boundary] = [flag for enabled, flag in (
            (config.get('show_time'), '-t'), (config.get('show_memory'), '-m')) if enabled] + [
            '--average=' + str(config.get('average', 1)), '--warm-up=' + str(int(bool(config.get('warmup'))))]
    manifest = {"format": "cp-run-failure", "schema": 2, "cwd": str(Path.cwd()), "seed": seed, "iteration": iteration, "verdict": verdict,
                "commands": {"main": [*config.get("main_argv", [config["executable"]]), *config.get("runtime_args", [])],
                             "brute": config.get("brute_argv", [config["brute"]]), "generator": [*config.get("generator_argv", [config["generator"]]), str(seed)]},
                "limits": {"timeout_ms": config.get("timeout_ms", "inf"), "memory_mib": config.get("memory_mib", "inf")},
                "measurement": {key: config.get(key) for key in ('warmup', 'average', 'time_factor', 'memory_factor')},
                "results": results, "sha256": files, "replay_argv": replay,
                "tools": {role: config.get("tool_" + role) for role in ("main", "brute", "generator")}}
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
    """Continue independent seeds, preserving role failures and bounded evidence."""
    plan = _prepare_check(config)
    for key in ('executable', 'brute', 'generator'):
        if not config.get(key): raise CheckUsageError('stress needs ' + key)
    runner = _runner(config)
    count = positive_setting(config.get('num_test') or config.get('iterations', 1000), 'stress iterations')
    start = int(config.get('seed', 4))
    main_argv = [*config.get('main_argv', [config['executable']]), *config.get('runtime_args', [])]
    verdicts, groups, saved = [], {}, 0
    maximum = positive_setting(config.get('max_failures', 10), 'failure bundle limit')
    with check_lock(), tempfile.TemporaryDirectory(prefix='.cp-run-stress-', dir='.') as temporary:
        directory, report = Path(temporary), Protocol(config)
        incoming, answer, actual = (directory / name for name in ('in.txt', 'ans.txt', 'out.txt'))
        seed, iteration, results = start, 0, {}
        current_bundle = None
        try:
            report.emit('cp-run stress: start seed {}; maximum {} iterations'.format(start, count))
            for iteration in range(1, count + 1):
                seed = (start + iteration - 1) % 2**64
                results, verdict, comparison = {}, None, None
                current_bundle = None
                for target in (incoming, answer, actual): target.write_bytes(b'')
                role_stderr = []
                # A failing generator/oracle leaves this seed unresolved. Its
                # role error cannot be misreported as a candidate wrong answer.
                for role, argv, source, target in (
                    ('generator', [*config.get('generator_argv', [config['generator']]), str(seed)], os.devnull, incoming),
                    ('reference', config.get('brute_argv', [config['brute']]), incoming, answer)):
                    error_path = directory / (role + '.stderr')
                    with open(error_path, 'wb') as stderr:
                        result = _run_files(runner, config, argv, source, target, role, stderr)
                    role_stderr.append((role, str(error_path)))
                    results[role] = {'status': result.status, 'elapsed_ns': result.elapsed_ns, 'peak_bytes': result.peak_bytes}
                    if result.status:
                        verdict = 'INTERRUPTED' if result.verdict == 'INTERRUPTED' else ('GENERATOR_ERROR' if role == 'generator' else 'ORACLE_ERROR')
                        config['_stderr_paths'] = role_stderr
                        case_protocol(report, config, iteration, incoming, actual, answer, result, None, seed)
                        report.emit('ROLE FAILURE: ' + verdict)
                        break
                if verdict is None:
                    actual.unlink(missing_ok=True)
                    result, comparison = run_candidate(runner, config, main_argv, incoming, actual, answer, 'candidate {}'.format(iteration))
                    config['_stderr_paths'] = role_stderr + config.get('_stderr_paths', [])
                    results['candidate'] = {'status': result.status, 'elapsed_ns': result.elapsed_ns, 'peak_bytes': result.peak_bytes}
                    _publish_actual(actual, config['actual'])
                    verdict = case_protocol(report, config, iteration, incoming, actual, answer, result, comparison, seed)
                    report.emit('Iteration {}: {} (seed {})'.format(iteration, verdict, seed))
                verdicts.append((verdict, result.status))
                groups.setdefault(verdict, []).append(iteration)
                if verdict in ('TLE', 'MLE'):
                    for violation in config.get('_resource_violations', []):
                        if violation != verdict: groups.setdefault(violation, []).append(iteration)
                if verdict != 'AC' and saved < maximum:
                    bundle = _bundle(config, report, directory, seed, iteration, verdict, results)
                    current_bundle = bundle
                    saved += 1
                    if config.get('minimize') and verdict == 'WA':
                        minimize_failure(config, directory, bundle)
                if verdict == 'INTERRUPTED' or (verdict != 'AC' and config.get('stop_on_failure')): break
            status = _aggregate(verdicts)
            final_protocol(report, groups, any(v in ('INCOMPLETE', 'GENERATOR_ERROR', 'ORACLE_ERROR', 'INTERRUPTED') for v, _ in verdicts))
            summary = 'No difference in {} generated cases'.format(iteration) if not status else 'Stress checked {} cases; failures retained'.format(iteration)
            report.emit(summary)
            if not config.get('cout'): print('cp-run: ' + summary + '; report: ' + str(config.get('report', 'test_out')), file=sys.stderr)
            report.finish()
            return status
        except KeyboardInterrupt:
            report.emit('INTERRUPTED at iteration {} (seed {})'.format(iteration, seed))
            if incoming.exists() and current_bundle is None: _bundle(config, report, directory, seed, iteration, 'INTERRUPTED', results)
            report.finish(); return 130
        except BaseException:
            report.abort(); raise
