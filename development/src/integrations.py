"""Optional formatting and feature-oriented dependency diagnostics."""


def execute_format(config):
    sources = config.get("protected", [])
    if not sources:
        raise CheckUsageError("formatting needs a source file")
    jobs = []
    seen = set()
    for source in sources:
        source = str(Path(source).resolve())
        if source in seen:
            continue
        seen.add(source)
        if not Path(source).is_file():
            raise CheckSetupError("source not found: " + source)
        python_source = source.endswith(".py")
        tool = (
            config.get("python_formatter", "ruff")
            if python_source
            else config.get("native_formatter", "clang-format")
        )
        executable = shutil.which(tool)
        if not executable:
            raise CheckSetupError(
                "optional formatter not found: " + tool + "; see README installation"
            )
        check = config.get("prettier") == "check"
        if python_source:
            argv = [
                executable,
                *([] if Path(tool).name.startswith("black") else ["format"]),
                *(["--check"] if check else []),
                source,
            ]
        else:
            argv = [
                executable,
                "--style=file",
                "--fallback-style=LLVM",
                "--sort-includes=false",
                *(["--dry-run", "--Werror"] if check else ["-i"]),
                source,
            ]
        jobs.append(argv)
    # Resolve every dependency before the first edit; no recursive directory sweep.
    for argv in jobs:
        result = subprocess.run(argv, stdout=sys.stderr)
        if result.returncode:
            return result.returncode
    return 0


def execute_doctor(config):
    required = ("zsh", "python3")
    optional = (
        "gcc",
        "g++",
        "clang",
        "clang++",
        config.get("interpreter", "python3"),
        "pypy3",
        config.get("native_formatter", "clang-format"),
        config.get("python_formatter", "ruff"),
        "clang-tidy",
    )
    missing = False
    print("cp-run dependency check (optional tools are needed only for their features)")
    for name in dict.fromkeys((*required, *optional)):
        executable = shutil.which(name)
        version = ""
        if executable:
            try:
                probe = subprocess.run(
                    [executable, "--version"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    timeout=5,
                    text=True,
                )
                version = next(iter(probe.stdout.splitlines()), "version unavailable")
                if name == "zsh":
                    match = re.search(r"zsh ([0-9]+)\.([0-9]+)", version)
                    if not match or tuple(map(int, match.groups())) < (5, 9):
                        missing = True
                        version += " [requires 5.9+]"
            except (OSError, subprocess.TimeoutExpired):
                version = "version probe failed"
        print(
            "  {}: {}{}{}".format(
                name,
                executable or "not installed",
                " [required]" if name in required else " [optional]",
                " — " + version if version else "",
            )
        )
        if name in required and not executable:
            missing = True
    return int(missing)
