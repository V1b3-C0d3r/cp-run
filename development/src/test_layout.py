"""Fixed numbered test files and a shared, contained test-data writer."""

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


def layout_root(config):
    """Resolve the one task folder; artifact routing never changes test data."""
    folder = _settings_test_folder(config.get("test_folder", "{wsp-dir}/tests"))
    relative = workspace_path_suffix(folder)
    if relative is None:
        return Path(folder).absolute()
    workspace = Path(config.get("workspace", ".")).resolve()
    target = workspace / relative
    try:
        target.resolve().relative_to(workspace)
    except ValueError:
        raise CheckUsageError("test folder escapes workspace") from None
    return target


def test_filename(stream, number):
    """The public layout is fixed: in1.txt/ans1.txt, with positive case IDs."""
    return "{}{}.txt".format(stream, number)


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


def discover_cases(root, stream):
    """Read only this folder; gaps are allowed, ambiguous numeric IDs are not."""
    root = Path(root)
    if not root.is_dir():
        raise CheckSetupError("test folder not found: " + str(root))
    expression = re.compile(re.escape(stream) + r"([0-9]+)\.txt")
    result = {}
    for path in root.iterdir():
        match = expression.fullmatch(path.name)
        if not match:
            continue
        digits = match[1]
        if len(digits) > 12 or int(digits) < 1:
            raise CheckUsageError("test IDs must be positive integers")
        number = int(digits)
        if number in result:
            raise CheckUsageError("duplicate numerical test ID: " + digits)
        if len(result) >= 100000:
            raise CheckSetupError("test folder exceeds 100000 cases")
        target = contained_target(root, path.name)
        if not target.is_file():
            raise CheckSetupError("test is not a regular file: " + str(target))
        result[number] = target
    return result


def mult_cases(config):
    root = layout_root(config)
    left, right = discover_cases(root, "in"), discover_cases(root, "ans")
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
