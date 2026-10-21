"""Bounded binary comparisons and readable diagnostics."""

class ComparisonLimit(ValueError):
    """An unfinished comparison is never an equality or wrong-answer verdict."""


def _line_values(stream, max_line=1048576, counter=None, max_bytes=67108864):
    """Read one row at a time; a conventional final LF adds no phantom row."""
    number = 0
    while True:
        line = stream.readline(max_line + 1)
        if not line: return
        number += 1
        if len(line) > max_line: raise ComparisonLimit('row exceeds {} bytes'.format(max_line))
        if counter is not None:
            counter[0] += len(line)
            if counter[0] > max_bytes: raise ComparisonLimit('checked data exceeds {} bytes'.format(max_bytes))
        if line.endswith(b"\n"):
            line = line[:-1]
            if line.endswith(b"\r"):
                line = line[:-1]
        yield number, line


@dataclass
class Comparison:
    equal: bool
    incomplete: bool
    used: int
    actual_different: set
    answer_different: set
    missing_rows: list
    reason: str = ''


def compare_streams(actual, answer, budget, max_line=1048576, max_bytes=67108864):
    """Linear bounded-lookahead alignment; never run a quadratic whole-file diff."""
    left, right = deque(), deque()
    counter = [0]
    sources = (iter(_line_values(actual, max_line, counter, max_bytes)),
               iter(_line_values(answer, max_line, counter, max_bytes)))
    exhausted = [False, False]
    changed_left, changed_right, missing = set(), set(), []
    used = 0

    def fill(index, queue):
        while len(queue) < 16 and not exhausted[index]:
            try:
                queue.append(next(sources[index]))
            except StopIteration:
                exhausted[index] = True

    while True:
        try:
            fill(0, left); fill(1, right)
        except ComparisonLimit as error:
            return Comparison(False, True, used, changed_left, changed_right, missing, str(error))
        if not left and not right:
            return Comparison(not (changed_left or changed_right or missing), False,
                              used, changed_left, changed_right, missing)
        if used >= budget:
            return Comparison(False, True, used, changed_left, changed_right, missing)
        used += 1
        if left and right and left[0][1] == right[0][1]:
            left.popleft(); right.popleft(); continue
        # A nearby matching anchor distinguishes insertion/deletion without
        # losing either file's independent original line numbers.
        skip_left = next((i for i, row in enumerate(left) if i and right and row[1] == right[0][1]), None)
        skip_right = next((i for i, row in enumerate(right) if i and left and row[1] == left[0][1]), None)
        if left and (not right or (skip_left is not None and (skip_right is None or skip_left <= skip_right))):
            number, _ = left.popleft(); changed_left.add(number); missing.append((number, None))
        elif right and (not left or skip_right is not None):
            number, _ = right.popleft(); changed_right.add(number); missing.append((None, number))
        else:
            number, _ = left.popleft(); changed_left.add(number)
            number, _ = right.popleft(); changed_right.add(number)


def _quoted(value):
    # ASCII JSON escapes keep ANSI, bidi and invalid UTF-8 bytes inert in files
    # and terminals. Visible escaped Unicode is preferable to spoofed reports.
    return json.dumps(value.decode("utf-8", errors="backslashreplace"), ensure_ascii=True)


def _section(report, title, path, different=None, display_limit=10000):
    report.emit(title + ":")
    found = False
    with open(path, "rb") as stream:
        try:
            rows = _line_values(stream, report.max_line)
            for number, line in rows:
                found = True
                if number > display_limit:
                    report.detail('  ... display truncated; raw data retained')
                    break
                mark = '!' if different and number in different else ' '
                # Clip before escaping: JSON encoding can expand every byte.
                allowance = max(0, report.detail_remaining // 6 - 100)
                clipped = line[:allowance]
                report.detail('  {} {}:{} | {}{}'.format(mark, title, number, _quoted(clipped),
                              ' ... [truncated]' if len(clipped) < len(line) else ''))
                if not report.detail_remaining: break
        except ComparisonLimit as error:
            report.detail('  ... ' + str(error) + '; raw data retained')
    if not found:
        report.emit("  <empty>")


def _failure_details(report, incoming, actual, answer, comparison, display_limit):
    report.detail_remaining = report.max_details
    display_limit = report.display_lines
    if comparison.reason: report.emit('INCOMPLETE: ' + comparison.reason)
    _section(report, "input", incoming, display_limit=display_limit)
    _section(report, "real-out.txt", actual, comparison.actual_different, display_limit)
    _section(report, "ans", answer, comparison.answer_different, display_limit)
    for left, right in comparison.missing_rows:
        if left is None:
            report.detail("  ! real-out.txt:— | <missing line>; ans:{}".format(right))
        if right is None:
            report.detail("  ! ans:— | <missing line>; real-out.txt:{}".format(left))


def compare_case(actual, answer, config):
    with open(actual, 'rb') as left, open(answer, 'rb') as right:
        return compare_streams(left, right, positive_setting(config.get('line_limit', 10000), 'line limit'),
                               positive_setting(config.get('max_line', 1048576), 'row byte limit'),
                               positive_setting(config.get('max_check', 67108864), 'checked byte limit'))


