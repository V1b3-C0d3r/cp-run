"""Private, bounded compiler preambles; each reader owns its artifact lifetime."""
SCHOOL_PREAMBLE_CACHE_VERSION = 5
SCHOOL_PREAMBLE_CACHE_ENTRIES = 8
SCHOOL_PREAMBLE_CACHE_BYTES = 256 * 1024 * 1024


def school_preamble_cache_key(source, prefix, compiler, arguments):
    record = dict(version=SCHOOL_PREAMBLE_CACHE_VERSION, directory=str(source.parent),
                  prefix=prefix, compiler=format_file_identity(compiler), arguments=arguments,
                  cwd=str(Path.cwd()),
                  environment={name: os.environ.get(name) for name in SCHOOL_FRONTEND_ENVIRONMENT})
    return hashlib.sha256(json.dumps(record, sort_keys=True).encode()).hexdigest()


def school_preamble_cache_root(source):
    record = format_cache_location(source, {})
    if record is None:
        return None
    root = record.parent / 'preambles'
    try:
        root.mkdir(mode=0o700, exist_ok=True)
        info = root.stat()
        if root.is_symlink() or info.st_uid != os.getuid() or info.st_mode & 0o022:
            return None
    except OSError:
        return None
    return root


def school_preamble_blob_name(key, value):
    return (isinstance(value, str) and Path(value).name == value and
            re.fullmatch(r'pch-' + re.escape(key) + r'-[\w-]+\.pch', value) is not None)


def school_preamble_blob_info(value):
    info = Path(value).stat()
    if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o022
            or Path(value).is_symlink()):
        raise ValueError('untrusted preamble artifact')
    # Reader hardlinks change ctime/link count, but never artifact bytes.
    return [info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns]


def school_preamble_link(original, destination):
    try:
        os.link(original, destination)
    except OSError:
        shutil.copyfile(original, destination)


def school_preamble_cache_load(source, prefix, key):
    root = school_preamble_cache_root(source)
    if root is None:
        return None
    temporary = None
    try:
        index = root / (key + '.json')
        if index.is_symlink() or index.stat().st_size > 4 * 1024 * 1024:
            return None
        record = json.loads(index.read_text())
        if (record.get('version') != SCHOOL_PREAMBLE_CACHE_VERSION or record.get('key') != key
                or record.get('clock_independent') is not True
                or not school_preamble_blob_name(key, record.get('blob'))
                or not isinstance(record.get('dependencies'), dict)
                or not isinstance(record.get('inputs'), list)
                or not isinstance(record.get('prefix'), str) or not record['prefix']
                or not prefix.startswith(record['prefix'])
                or not isinstance(record.get('lookup_roots'), list)
                or any(not isinstance(value, list) or len(value) != 2
                       or not isinstance(value[0], str) or not Path(value[0]).is_absolute()
                       or type(value[1]) is not bool for value in record['lookup_roots'])
                or any(value not in record['dependencies'] for value in record['inputs'])):
            return None
        dependencies = record['dependencies']
        if any(not Path(value).is_absolute() or format_file_identity(value) != identity
               for value, identity in dependencies.items()):
            return None
        blob = root / record['blob']
        if school_preamble_blob_info(blob) != record.get('artifact'):
            return None
        temporary = tempfile.TemporaryDirectory(prefix='cp-format-preamble-')
        target = Path(temporary.name) / 'prefix.pch'
        school_preamble_link(blob, target)
        # An evicted blob can disappear before linking; an active reader's
        # private link/copy remains valid throughout compiler execution.
        if school_preamble_blob_info(blob) != record['artifact'] or target.stat().st_size != record['artifact'][2]:
            temporary.cleanup()
            return None
        os.utime(index, None)
        return dict(temporary=temporary, pch=str(target), prefix=record['prefix'],
                    dependencies=record['inputs'], identities=dependencies, cache_key=key,
                    lookup_roots=[tuple(value) for value in record['lookup_roots']], lookup_complete=True)
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        if temporary is not None:
            temporary.cleanup()
        return None


def school_preamble_cache_prune(root):
    """Called under the publisher lock; loaded readers already own their link."""
    records = sorted(root.glob('*.json'), key=lambda value: value.stat().st_mtime_ns, reverse=True)
    retained, total = set(), 0
    for index in records:
        if not re.fullmatch(r'[0-9a-f]{64}\.json', index.name):
            continue
        try:
            record = json.loads(index.read_text())
            blob = root / record['blob']
            if not school_preamble_blob_name(index.stem, blob.name):
                raise ValueError('invalid preamble blob')
            size = blob.stat().st_size
            if len(retained) >= SCHOOL_PREAMBLE_CACHE_ENTRIES or total + size > SCHOOL_PREAMBLE_CACHE_BYTES:
                index.unlink()
            else:
                retained.add(blob.name)
                total += size
        except (OSError, ValueError, KeyError, TypeError):
            index.unlink(missing_ok=True)
    for blob in root.glob('pch-*.pch'):
        if re.fullmatch(r'pch-[0-9a-f]{64}-[\w-]+\.pch', blob.name) and blob.name not in retained:
            blob.unlink(missing_ok=True)


def school_preamble_cache_store(source, key, entry):
    root = school_preamble_cache_root(source)
    if root is None or Path(entry['pch']).stat().st_size > SCHOOL_PREAMBLE_CACHE_BYTES:
        return
    descriptor, blob, temporary = None, None, None
    try:
        # No waiting behind another process: a preparation cache is optional.
        descriptor = os.open(root / '.lock', os.O_RDWR | os.O_CREAT | getattr(os, 'O_NOFOLLOW', 0), 0o600)
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o022:
            return
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        old = root / (key + '.json')
        handle, name = tempfile.mkstemp(prefix='pch-' + key + '-', suffix='.pch', dir=root)
        os.close(handle)
        blob = Path(name)
        blob.unlink()
        school_preamble_link(entry['pch'], blob)
        os.chmod(blob, 0o600)
        record = dict(version=SCHOOL_PREAMBLE_CACHE_VERSION, key=key, clock_independent=True, blob=blob.name,
                      artifact=school_preamble_blob_info(blob), dependencies=entry['identities'],
                      inputs=entry['dependencies'], prefix=entry['prefix'], lookup_roots=entry['lookup_roots'])
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', prefix='.index-', dir=root, delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(record, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, old)
        temporary, blob = None, None
        school_preamble_cache_prune(root)
    except (OSError, ValueError, TypeError):
        pass  # Full parsing is still mandatory if preparation cannot be reused.
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
        if blob is not None:
            blob.unlink(missing_ok=True)
        if descriptor is not None:
            os.close(descriptor)
