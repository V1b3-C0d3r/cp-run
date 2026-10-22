"""Count-first separator bundles, with byte-exact manual conversion checks."""


def counted_cases(filename, separator):
    with open(filename, "rb") as source:
        header = source.readline(16)
        if not header.endswith(b"\n") or not header[:-1].isdigit() or len(header) > 7:
            raise CheckUsageError("bundle needs a decimal case count on its first line")
        count = int(header[:-1])
        if count > 100000:
            raise CheckUsageError("bundle exceeds 100000 cases")
        offset = source.tell()
    if not count:
        if Path(filename).stat().st_size != offset:
            raise CheckUsageError("zero-case bundle contains data")
        return []
    cases = index_cases(filename, separator, start_offset=offset, keep_terminal=True)
    if len(cases) != count:
        raise CheckUsageError(
            "bundle count mismatch: header {}; found {}".format(count, len(cases))
        )
    return cases


def slice_bytes(case, maximum=268435456):
    if case.length > maximum:
        raise CheckSetupError("case exceeds conversion byte limit")
    with open(case.path, "rb") as source:
        source.seek(case.start)
        data = source.read(case.length)
    if len(data) != case.length:
        raise CheckSetupError("test data changed during conversion")
    return data


def encode_bundle(records, separator, maximum=268435456):
    """Verify framing before any write, including partial-marker overlaps."""
    total = sum(map(len, records)) + max(0, len(records) - 1) * len(separator)
    if total > maximum:
        raise CheckSetupError("bundle exceeds conversion byte limit")
    if separator == b"\n\x1e\n" and any(b"\x1e" in case for case in records):
        raise CheckUsageError("test contains reserved RS byte; choose another --sep")
    payload = separator.join(records)
    decoded = payload.split(separator) if records else []
    if decoded != records:
        raise CheckUsageError(
            "separator collides with test data or its boundary; choose another separator"
        )
    return str(len(records)).encode("ascii") + b"\n" + payload


def atomic_data_file(filename, payload, overwrite=False, protected=()):
    target = Path(filename).absolute()
    if target.is_symlink() or any(_same_path(target, p) for p in protected):
        raise CheckUsageError("bundle output aliases a protected file")
    write_test_files(target.parent, [(target.name, payload)], overwrite, protected)


def execute_bundle(config):
    """Both streams share the same codec; answers are never special-cased."""
    stream = config.get("bundle_stream")
    if stream not in ("in", "ans"):
        raise CheckUsageError("--pack/--unpack accepts in or ans")
    source, target = config.get("data_input"), config.get("data_output")
    default_file = (
        config.get("default_input", "in.txt")
        if stream == "in"
        else config.get("default_answer", "ans.txt")
    )
    bundle_file = str(Path(default_file).with_suffix(".bundle"))
    manual = bool(config.get("text_conversion"))

    def directory(explicit):
        if not explicit:
            return layout_root(config)
        root = Path(explicit).absolute()
        if config.get("save_test_relpath"):
            workspace = Path(config.get("workspace", ".")).resolve()
            parent = Path(config.get("source_anchor", "main.cpp")).absolute().parent.resolve()
            try:
                root = root / parent.relative_to(workspace)
            except ValueError:
                raise CheckUsageError("test source must be inside workspace") from None
        return root

    if config["operation"] == "pack":
        source = (source or default_file) if manual else directory(source)
        target = target or bundle_file
    else:
        source = source or bundle_file
        target = (target or default_file) if manual else directory(target)
    separator = decode_separator(config.get("sep", r"\n\x1e\n"))
    text_separator = decode_separator(config.get("text_sep", r"\n###\n"))
    manual = bool(config.get("text_conversion"))
    maximum = positive_setting(config.get("max_spool", 268435456), "conversion byte limit")
    overwrite = bool(config.get("overwrite"))
    protected = (
        [*config.get("protected", []), source]
        if Path(source).is_file()
        else config.get("protected", [])
    )
    if config["operation"] == "pack":
        if manual:
            cases = counted_cases(source, text_separator)
            if sum(case.length for case in cases) > maximum:
                raise CheckSetupError("bundle exceeds conversion byte limit")
            records = [slice_bytes(case, maximum) for case in cases]
        else:
            stem = Path(config.get("source_anchor", "main.cpp")).stem
            key = "in_template" if stream == "in" else "ans_template"
            pattern = config.get(key, "./{n}." + stream)
            source, pattern = case_location(config, source, pattern)
            found = discover_cases(source, pattern, stem)
            if not found:
                raise CheckUsageError("no matching tests to pack")
            ordered = sorted(found)
            records = []
            total = 0
            for number in ordered:
                case = index_cases(found[number])[0]
                total += case.length
                if total > maximum:
                    raise CheckSetupError("bundle exceeds conversion byte limit")
                records.append(slice_bytes(case, maximum))
            protected = [*protected, *found.values()]
            if ordered != list(range(1, len(ordered) + 1)):
                print(
                    "cp-run: packed IDs {} as 1..{}".format(ordered, len(ordered)), file=sys.stderr
                )
        payload = encode_bundle(records, separator, maximum)
        atomic_data_file(target, payload, overwrite, protected)
    else:
        cases = counted_cases(source, separator)
        if sum(case.length for case in cases) > maximum:
            raise CheckSetupError("bundle exceeds conversion byte limit")
        records = [slice_bytes(case, maximum) for case in cases]
        if manual:
            atomic_data_file(
                target, encode_bundle(records, text_separator, maximum), overwrite, protected
            )
        else:
            stem = Path(config.get("source_anchor", "main.cpp")).stem
            key = "in_template" if stream == "in" else "ans_template"
            pattern = config.get(key, "./{n}." + stream)
            target, pattern = case_location(config, target, pattern)
            entries = [
                (case_template(pattern, stem, i), record) for i, record in enumerate(records, 1)
            ]
            write_test_files(target, entries, overwrite, protected)
    print(
        "cp-run: {} {}: {} cases".format(config["operation"], stream, len(records)), file=sys.stderr
    )
    return 0
