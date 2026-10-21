"""Counted argv bridge between native parsing and the embedded services."""


def _bridge_config(values):
    """Decode lengths instead of guessing delimiters inside user arguments."""
    values = iter(values)
    pairs = int(next(values))
    config = {next(values): next(values) for _ in range(pairs)}
    runtime_count = int(next(values))
    config['runtime_args'] = [next(values) for _ in range(runtime_count)]
    protected_count = int(next(values))
    config['protected'] = [next(values) for _ in range(protected_count)]
    for key in ('auto', 'cin', 'cout', 'show_time', 'show_memory', 'show_command', 'warmup'):
        config[key] = config.get(key, '0') == '1'
    config['cases'] = [int(value) for value in config.get('cases', '').split(',') if value]
    for key in ('num_test', 'seed'):
        if config.get(key, '') == '':
            config.pop(key, None)
    return config


def _bridge_main():
    if sys.version_info < (3, 9):
        print('cp-run: this feature requires Python 3.9+', file=sys.stderr)
        return 127
    action = sys.argv[1]
    if action == 'settings':
        return edit_settings(sys.argv[2])
    if action in ('import', 'export'):
        return transfer_preferences(action, sys.argv[2], sys.argv[3])
    config = _bridge_config(sys.argv[2:])
    if action == 'preflight':
        preflight_check(config)
        return 0
    if action == 'test':
        return execute_test(config)
    if action == 'stress':
        return execute_stress(config)
    if action == 'supervise':
        return supervise(config)
    raise CheckUsageError('unknown internal operation: ' + action)


try:
    _bridge_status = _bridge_main()
except CheckUsageError as _bridge_error:
    print('cp-run: ' + str(_bridge_error), file=sys.stderr)
    _bridge_status = 2
except (CheckSetupError, OSError) as _bridge_error:
    print('cp-run: ' + str(_bridge_error), file=sys.stderr)
    _bridge_status = 1
except ValueError as _bridge_error:
    print('cp-run: ' + str(_bridge_error), file=sys.stderr)
    _bridge_status = 2
except KeyboardInterrupt:
    _bridge_status = 130
raise SystemExit(_bridge_status)
