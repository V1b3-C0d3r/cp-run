"""Optional foreground Competitive Companion receiver; no external server."""


def companion_samples(payload):
    """Validate protocol data without trusting remote names, paths or limits."""

    def unique(pairs):
        record = {}
        for key, value in pairs:
            if key in record:
                raise CheckUsageError("duplicate Companion JSON key: " + key)
            record[key] = value
        return record

    try:
        data = json.loads(payload, object_pairs_hook=unique)
    except (ValueError, UnicodeError, RecursionError) as error:
        raise CheckUsageError("invalid Companion JSON: " + str(error)) from None
    if not isinstance(data, dict):
        raise CheckUsageError("Companion request must be an object")
    batch = data.get("batch", {})
    if (
        not isinstance(batch, dict)
        or type(batch.get("size", 1)) is not int
        or batch.get("size", 1) != 1
    ):
        raise CheckUsageError("this listener accepts one problem; import a single problem page")
    tests = data.get("tests")
    if not isinstance(tests, list) or not 1 <= len(tests) <= 100000:
        raise CheckUsageError("Companion request needs 1..100000 samples")
    result = []
    for number, test in enumerate(tests, 1):
        if not isinstance(test, dict) or not all(
            isinstance(test.get(k), str) for k in ("input", "output")
        ):
            raise CheckUsageError("sample {} needs string input/output".format(number))
        try:
            result.append((test["input"].encode("utf-8"), test["output"].encode("utf-8")))
        except UnicodeError:
            raise CheckUsageError("sample contains invalid Unicode") from None
    return result


def import_companion(config, payload):
    samples = companion_samples(payload)
    root = layout_root(config)
    entries = [(test_filename(stream, number), content)
               for number, sample in enumerate(samples, 1)
               for stream, content in zip(("in", "ans"), sample)]
    # A shorter import must not silently leave tests from another problem.
    if root.is_dir():
        for stream in ("in", "ans"):
            if set(discover_cases(root, stream)) - set(range(1, len(samples) + 1)):
                raise CheckUsageError("existing extra samples would remain; choose a clean test folder")
    write_test_files(root, entries, bool(config.get("overwrite")), config.get("protected", []))
    return len(samples), root


def companion_server(address, handler):
    """Bind numeric loopback without HTTPServer's slow reverse-DNS lookup."""
    from http.server import HTTPServer
    from socketserver import TCPServer

    class LocalServer(HTTPServer):
        def server_bind(self):
            TCPServer.server_bind(self)
            self.server_name = "localhost"
            self.server_port = self.server_address[1]

    return LocalServer(address, handler)


def execute_companion(config):
    # HTTP imports are optional; ordinary measurements never pay their startup cost.
    from http.server import BaseHTTPRequestHandler

    port = positive_setting(config.get("port", 27122), "--port")
    if port > 65535:
        raise CheckUsageError("--port must be 1..65535")
    wait = positive_setting(config.get("wait", 120), "--wait")
    maximum = min(
        4 * 1024 * 1024, positive_setting(config.get("max_spool", 268435456), "request limit")
    )
    accepted = []

    class Handler(BaseHTTPRequestHandler):
        timeout = 3  # Includes reading headers, before do_POST is entered.

        def log_message(self, *args):
            pass

        def do_POST(self):
            try:
                self.connection.settimeout(3)
                if self.path != "/":
                    raise CheckUsageError("Companion endpoint is POST /")
                origin = self.headers.get("Origin", "")
                if origin and not origin.startswith(("chrome-extension://", "moz-extension://")):
                    raise CheckUsageError("browser page origins are not accepted")
                if self.headers.get_content_type() != "application/json":
                    raise CheckUsageError("Content-Type must be application/json")
                length = self.headers.get("Content-Length", "")
                if (
                    not length.isascii()
                    or not length.isdecimal()
                    or len(length) > 10
                    or not 0 < int(length) <= maximum
                ):
                    raise CheckUsageError("invalid or oversized Content-Length")
                payload = self.rfile.read(int(length))
                if len(payload) != int(length):
                    raise CheckUsageError("truncated Companion request")
                count, root = import_companion(config, payload)
                accepted.append(count)
                message = "Saved {} samples in {}".format(count, root)
                self.send_response(200)
                print("cp-run: " + message, file=sys.stderr, flush=True)
            except (ValueError, OSError) as error:
                message = str(error)
                self.send_response(400)
                print("cp-run: Companion: " + message, file=sys.stderr, flush=True)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            body = (message + "\n").encode("utf-8")
            self.send_header("Content-Length", str(len(body)))
            try:
                self.end_headers()
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass  # Receipt already committed.

    deadline = time.monotonic() + wait
    with companion_server(("127.0.0.1", port), Handler) as server:
        print(
            "cp-run: Companion listening on http://localhost:{}/; import one problem".format(
                server.server_port
            ),
            file=sys.stderr,
            flush=True,
        )
        while not accepted and time.monotonic() < deadline:
            server.timeout = min(0.25, max(0, deadline - time.monotonic()))
            server.handle_request()
    if not accepted:
        raise CheckSetupError("Companion wait expired without a successful import")
    return 0
