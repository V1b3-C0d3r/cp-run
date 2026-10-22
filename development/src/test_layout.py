"""Restricted numbered templates and a shared, contained test-data writer."""

import re


WORKSPACE_PATH_PREFIX = "{wsp-dir}"


def workspace_path_suffix(value):
    """Validate the literal root prefix without needing a workspace at save time."""
    if WORKSPACE_PATH_PREFIX not in value:
        return None
    prefix = WORKSPACE_PATH_PREFIX + "/"
    if value == WORKSPACE_PATH_PREFIX:
        return ""
    if not value.startswith(prefix):
        raise CheckUsageError("use {wsp-dir}/PATH at the beginning of a path")
    relative = value[len(prefix):]
    if not relative or WORKSPACE_PATH_PREFIX in relative or Path(relative).is_absolute() or ".." in Path(relative).parts:
        raise CheckUsageError("workspace path must stay inside its workspace")
    return relative


def case_location(config, root, pattern):
    """An explicit workspace anchor replaces the usual destination/subtree root."""
    relative = workspace_path_suffix(pattern)
    if relative is None:
        return Path(root), pattern
    return Path(config.get("workspace", ".")).resolve(), relative


def case_template(pattern, stem, number=None):
    """Only literal text, one {n}, and source-stem aliases are supported."""
    relative = workspace_path_suffix(pattern)
    if relative is not None:
        pattern = relative
    for alias in ("{filename-noExt}", "{file-name-no-ext}", "{filename-no-ext}"):
        pattern = pattern.replace(alias, "{stem}")
    if pattern.count("{n}") != 1:
        raise CheckUsageError("test template must contain exactly one {n}")
    rest = pattern.replace("{n}", "").replace("{stem}", "")
    if "{" in rest or "}" in rest:
        raise CheckUsageError("unknown template placeholder; use {wsp-dir}, {n} and {stem}")
    if not stem or "/" in stem or stem in (".", ".."):
        raise CheckUsageError("invalid source stem for test template")
    value = pattern.replace("{stem}", stem)
    if number is not None:
        value = value.replace("{n}", str(number))
    if "\x00" in value or Path(value).is_absolute() or ".." in Path(value).parts:
        raise CheckUsageError("test template must stay inside its test directory")
    return value


def layout_root(config):
    """Artifact and data relative paths are independent, each appended once."""
    workspace = Path(config.get("workspace", ".")).resolve()
    relative = config.get("test_dir") or config.get("destination", ".")
    anchored = workspace_path_suffix(relative)
    if anchored is not None:
        relative = anchored or "."
    if Path(relative).is_absolute() or ".." in Path(relative).parts:
        raise CheckUsageError("test directory must be workspace-relative without ..")
    root = workspace / relative
    if config.get("save_test_relpath"):
        anchor = Path(config.get("source_anchor") or config.get("executable") or ".").absolute()
        parent = (
            Path(config["anchor_dir"])
            if config.get("anchor_dir")
            else anchor.parent
            if anchor.is_file() or anchor.suffix
            else anchor
        )
        try:
            subtree = parent.resolve().relative_to(workspace)
        except ValueError:
            raise CheckUsageError("test source must be inside the workspace") from None
        root = root / subtree
    try:
        root.resolve().relative_to(workspace)
    except ValueError:
        raise CheckUsageError("test directory escapes workspace") from None
    return root


def contained_target(root, relative):
    """Reject symlink parents before writes, including links back inside root."""
    root = Path(root).absolute()
    if root.is_symlink():
        raise CheckUsageError("test root must not be a symbolic link")
    root = root.resolve()
    relative = Path(relative)
    if relative.is_absolute() or ".." in relative.parts:
        raise CheckUsageError("test path escapes its root")
    candidate = root / relative
    for item in (candidate, *candidate.parents):
        if item == root:
            break
        if item.is_symlink():
            raise CheckUsageError("test path contains a symbolic link: " + str(item))
    try:
        candidate.resolve().relative_to(root.resolve())
    except ValueError:
        raise CheckUsageError("test path escapes its root") from None
    return candidate


def discover_cases(root, pattern, stem):
    """Discover sparse numerical IDs; never stop at the first missing file."""
    root = Path(root)
    template = case_template(pattern, stem)
    expression = re.compile(
        "^" + re.escape(Path(template).as_posix()).replace(r"\{n\}", r"([0-9]+)") + "$"
    )
    prefix = template.split("{n}", 1)[0]
    base = root / (Path(prefix) if prefix.endswith("/") else Path(prefix).parent)
    if not base.is_dir():
        raise CheckSetupError("test directory not found: " + str(base))
    result = {}
    candidates = base.rglob("*") if "/" in template[len(prefix) :] else base.iterdir()
    for path in candidates:
        match = expression.fullmatch(path.relative_to(root).as_posix())
        if not match:
            continue
        digits = match[1]
        if len(digits) > 12 or int(digits) < 1:
            raise CheckUsageError("test IDs must be positive integers")
        number = int(digits)
        if number in result:
            raise CheckUsageError("duplicate numerical test ID: " + digits)
        if len(result) >= 100000:
            raise CheckSetupError("test directory exceeds 100000 cases")
        target = contained_target(root, path.relative_to(root))
        if not target.is_file():
            raise CheckSetupError("test is not a regular file: " + str(target))
        result[number] = target
    return result


def mult_cases(config):
    root = layout_root(config)
    stem = Path(config.get("source_anchor") or config.get("executable", "main.cpp")).stem
    input_root, input_pattern = case_location(config, root, config.get("in_template", "./{n}.in"))
    answer_root, answer_pattern = case_location(config, root, config.get("ans_template", "./{n}.ans"))
    left = discover_cases(input_root, input_pattern, stem)
    right = discover_cases(answer_root, answer_pattern, stem)
    if not left or set(left) != set(right):
        raise CheckUsageError(
            "mult test ID mismatch: missing answers {}; missing inputs {}".format(
                sorted(set(left) - set(right)), sorted(set(right) - set(left))
            )
        )
    ids = sorted(left)
    return ids, [index_cases(left[n])[0] for n in ids], [index_cases(right[n])[0] for n in ids]


def write_test_files(root, entries, overwrite=False, protected=()):
    """Preflight the set, stage sibling files, and roll back handled failures.

    Each replacement is atomic. A set in an existing directory is deliberately
    not advertised as crash-atomic. The directory lock coordinates our writers.
    """
    root = Path(root).absolute()
    if root.is_symlink():
        raise CheckUsageError("test root must not be a symbolic link")
    root = root.resolve()
    planned, names, identities = [], set(), set()
    for relative, content in entries:
        target = contained_target(root, relative)
        identity = (target.stat().st_dev, target.stat().st_ino) if target.exists() else None
        if (
            target in names
            or (identity is not None and identity in identities)
            or any(_same_path(target, p) for p in protected)
        ):
            raise CheckUsageError("test output aliases another protected role: " + str(target))
        names.add(target)
        if identity is not None:
            identities.add(identity)
        if target.exists():
            if not target.is_file():
                raise CheckUsageError("test output is not a regular file: " + str(target))
            if target.stat().st_size == len(content) and target.read_bytes() == content:
                continue
            if not overwrite:
                raise CheckUsageError("test file exists; use --overwrite: " + str(target))
        planned.append((target, content))
    root.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(root, os.O_RDONLY)
    staged, previous, installed = [], {}, []
    try:
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise CheckSetupError("another import is writing this test directory") from None
        for target, content in planned:
            # Recheck after the lock; another process may have committed meanwhile.
            contained_target(root, target.relative_to(root))
            if (
                target.exists()
                and not overwrite
                and (target.stat().st_size != len(content) or target.read_bytes() != content)
            ):
                raise CheckUsageError("test file appeared during import: " + str(target))
            target.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(
                dir=target.parent, prefix=".cp-run-import-", delete=False
            ) as stream:
                staged.append((Path(stream.name), target))
                stream.write(content)
                stream.flush()
                os.fsync(stream.fileno())
            if target.exists():
                with tempfile.NamedTemporaryFile(
                    dir=target.parent, prefix=".cp-run-backup-", delete=False
                ) as backup:
                    previous[target] = Path(backup.name)
                shutil.copy2(target, previous[target])
                os.chmod(staged[-1][0], stat.S_IMODE(target.stat().st_mode))
        for source, target in staged:
            installed.append(
                target
            )  # Register before replace: interruption between bytecodes is recoverable.
            os.replace(source, target)
    except BaseException:
        for target in reversed(installed):
            if target in previous:
                os.replace(previous[target], target)
            else:
                target.unlink(missing_ok=True)
        raise
    finally:
        for source, _ in staged:
            source.unlink(missing_ok=True)
        for backup in previous.values():
            backup.unlink(missing_ok=True)
        os.close(descriptor)
