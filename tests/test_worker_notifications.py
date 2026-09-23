"""Exercise real notification control flow without publishing GitHub comments."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / 'platform/scripts/homedir-sdlc-worker.sh').read_text()
START = SOURCE.index('comment_issue() {')
FUNCTION = SOURCE[START:SOURCE.index('\n}\n', START) + 3]


class NotificationsTest(unittest.TestCase):
    def run_case(self, commands):
        with tempfile.TemporaryDirectory() as directory:
            script = '\n'.join(['set -euo pipefail', 'REPO=fixture/repo', FUNCTION,
                                'log() { echo "$*"; }',
                                'gh() { echo attempt >> "$STATE_DIR/attempts"; return "$RESULT"; }',
                                commands, 'echo cycle-continued'])
            result = subprocess.run(['bash', '-c', script], env=dict(os.environ, STATE_DIR=directory),
                                    capture_output=True, text=True, timeout=10)
            attempts = (Path(directory) / 'attempts').read_text().splitlines()
            return result, len(attempts)

    def test_failure_is_nonfatal_and_retried(self):
        result, attempts = self.run_case('RESULT=1\ncomment_issue 69 message\nRESULT=0\ncomment_issue 69 message')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(attempts, 2)
        self.assertIn('notification failed', result.stdout)
        self.assertIn('cycle-continued', result.stdout)

    def test_successful_duplicate_is_skipped(self):
        result, attempts = self.run_case('RESULT=0\ncomment_issue 69 message\ncomment_issue 69 message')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(attempts, 1)

    def test_changed_message_and_other_issue_are_sent(self):
        result, attempts = self.run_case('RESULT=0\ncomment_issue 69 message\ncomment_issue 69 changed\ncomment_issue 70 changed')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(attempts, 3)


if __name__ == '__main__':
    unittest.main()
