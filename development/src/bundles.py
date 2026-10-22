"""Lossless counted bundles shared by pack, unpack and counted auto tests."""


def counted_cases(filename, separator):
    if not Path(filename).is_file():
        raise CheckSetupError("bundle is not a regular file: " + str(filename))
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


def execute_bundle(config):
    """Pack both streams by default; preflight all outputs before changing any."""
    operation = config["operation"]
    selected = config.get("bundle_stream", "both")
    if selected not in ("both", "in", "ans"):
        raise CheckUsageError("pack/unpack accepts =in, =ans, or no selector for both")
    streams = ("in", "ans") if selected == "both" else (selected,)
    paths = {"in": Path(config.get("default_input", "in.txt")).absolute(),
             "ans": Path(config.get("default_answer", "ans.txt")).absolute()}
    root = layout_root(config)
    separator = decode_separator(config.get("sep", r"\n\x1e\n"))
    maximum = positive_setting(config.get("max_spool", 268435456), "conversion byte limit")
    overwrite = bool(config.get("overwrite"))
    protected = list(config.get("protected", []))
    counts, entries = {}, []
    if operation == "pack":
        discovered = {stream: discover_cases(root, stream) for stream in streams}
        if selected == "both" and set(discovered["in"]) != set(discovered["ans"]):
            raise CheckUsageError("pack input/answer test IDs differ")
        for stream, found in discovered.items():
            if not found:
                raise CheckUsageError("no {} tests to pack in {}".format(stream, root))
            protected.extend(found.values())
            records, total = [], 0
            for number in sorted(found):
                case = index_cases(found[number])[0]
                total += case.length
                if total > maximum:
                    raise CheckSetupError("bundle exceeds conversion byte limit")
                records.append(slice_bytes(case, maximum))
            entries.append((paths[stream], encode_bundle(records, separator, maximum)))
            counts[stream] = len(records)
            if sorted(found) != list(range(1, len(found) + 1)):
                print("cp-run: packed IDs {} as 1..{}".format(sorted(found), len(found)), file=sys.stderr)
        # One preflight/rollback transaction covers both containers, even when
        # their parent directories differ. Common-root paths stay literal.
        common = Path(os.path.commonpath([str(path.parent) for path, _ in entries]))
        write_test_files(common, [(path.relative_to(common), data) for path, data in entries], overwrite, protected)
    else:
        protected.extend(paths[stream] for stream in streams)
        for stream in streams:
            cases = counted_cases(paths[stream], separator)
            if sum(case.length for case in cases) > maximum:
                raise CheckSetupError("bundle exceeds conversion byte limit")
            entries.extend((test_filename(stream, i), slice_bytes(case, maximum))
                           for i, case in enumerate(cases, 1))
            counts[stream] = len(cases)
        if selected == "both" and counts["in"] != counts["ans"]:
            raise CheckUsageError("unpack input/answer counts differ")
        # Reject stale numbered files instead of silently mixing problem sets.
        if root.is_dir():
            for stream in streams:
                if set(discover_cases(root, stream)) - set(range(1, counts[stream] + 1)):
                    raise CheckUsageError("existing extra tests would remain; choose a clean test folder")
        write_test_files(root, entries, overwrite, protected)
    for stream in streams:
        print("cp-run: {} {}: {} cases; folder {}; bundle {}".format(
            operation, stream, counts[stream], root, paths[stream]), file=sys.stderr)
    return 0
