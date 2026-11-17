"""Real terminal flows, including strict-build interruption and temporary notes."""
import json
import os
from pathlib import Path
import pty
import select
import shutil
import subprocess
import time
import unittest
import test_school_format as fixtures


@unittest.skipUnless(os.name == 'posix' and shutil.which('clang') and shutil.which('clang-format'), 'needs PTY and formatters')
class FormatTerminalTest(unittest.TestCase):
    def setUp(self):
        self.case = fixtures.SchoolFormatTest('runTest')
        self.case.setUp()
        self.addCleanup(self.case.doCleanups)
        self.source = self.case.source
        self.master, slave = pty.openpty()
        self.addCleanup(os.close, self.master)
        self.slave = slave
        self.process = None
        self.received = b''

    def start(self, args):
        self.process = subprocess.Popen([str(fixtures.RELEASE / 'cp-run.zsh'), *map(str, args)],
            stdin=self.slave, stdout=self.slave, stderr=self.slave,
            cwd=self.case.root, env=self.case.env, start_new_session=True)
        os.close(self.slave)
        self.addCleanup(self.stop)

    def stop(self):
        if self.process and self.process.poll() is None:
            self.process.kill()
            self.process.wait(timeout=10)

    def until(self, marker):
        deadline = time.monotonic() + 20
        while marker not in self.received:
            if time.monotonic() > deadline:
                self.fail('terminal timeout: ' + self.received.decode(errors='replace'))
            ready, _, _ = select.select([self.master], [], [], .1)
            if ready:
                try:
                    part = os.read(self.master, 65536)
                except OSError:
                    part = b''
                if not part:
                    self.fail('terminal ended: ' + self.received.decode(errors='replace'))
                self.received += part
        self.received = self.received[self.received.index(marker) + len(marker):]

    def test_strict_errors_open_full_formatter_then_interrupt_original_build(self):
        target = self.case.root / 'old.out'
        target.write_bytes(b'old binary')
        report = self.case.root / 'report.json'
        self.source.write_text('int state;\nint main(){int BadName=0;return BadName;}\n')
        self.start(['compile', self.source, '-o', target, '--strict-format=school', '--report', report])
        self.until(b'error> ')
        early = json.loads(report.read_text())
        self.assertTrue(all(item['severity'] == 'error' for item in early['findings']))
        self.source.write_text(self.source.read_text().replace('BadName', 'value'))
        os.write(self.master, b'a\n')
        self.until(b'review> ')
        self.assertTrue(any(item['phase'] == 'review' for item in json.loads(report.read_text())['initial']))
        os.write(self.master, b'd all\n')
        self.assertEqual(self.process.wait(timeout=20), 1)
        self.assertEqual(target.read_bytes(), b'old binary')
        repeated = subprocess.run([str(fixtures.RELEASE / 'cp-run.zsh'), 'compile', str(self.source),
                                  '-o', str(target), '--strict-format=school'],
                                 cwd=self.case.root, env=self.case.env, capture_output=True, text=True)
        self.assertEqual(repeated.returncode, 0, repeated.stderr)
        self.assertNotEqual(target.read_bytes(), b'old binary')

    def test_gnu_helper_enters_style_review_and_batch_justification_completes(self):
        self.source = self.case.root / 'main.cpp'
        self.source.write_text('#include <algorithm>\n'
                               'int main(void) { int BadName = std::__lg(8); return BadName != 3; }\n')
        report = self.case.root / 'review.json'
        self.start(['format', '--school', self.source, '--review', '--report', report])
        self.until(b'error> ')
        initial = json.loads(report.read_text())['findings']
        self.assertTrue(initial)
        self.assertTrue(all(item['rule'] not in ('frontend', 'GCC', 'backend') for item in initial), initial)
        os.write(self.master, b'j all required by assignment\n')
        self.assertEqual(self.process.wait(timeout=20), 0)
        self.assertIn('school-error-justified', self.source.read_text())
        self.assertEqual(json.loads(report.read_text())['state'], 'complete')

    def test_real_annotation_and_empty_batch_justification(self):
        self.source.write_text('int state;\nint main(void){return 0;}\n')
        self.start(['format', '--school', self.source, '--annotate'])
        self.until(b'review> ')
        self.assertIn('/* school-warning 5.14:', self.source.read_text())
        os.write(self.master, b'j all\n')
        self.assertEqual(self.process.wait(timeout=20), 0)
        text = self.source.read_text()
        self.assertIn('/* school-justified 5.14 */', text)
        self.assertNotIn('/* school-warning ', text)
        checked = self.case.invoke('--school', self.source, '--check')
        self.assertEqual(checked.returncode, 0, checked.stderr)
