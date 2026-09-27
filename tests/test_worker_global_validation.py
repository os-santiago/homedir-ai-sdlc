"""Run the publication validation gates without provider or GitHub access."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / "platform/scripts/homedir-sdlc-worker.sh").read_text()
START = SOURCE.index("run_global_validation() {")
FUNCTION = SOURCE[START:SOURCE.index("\n}\n", START) + 3]


class GlobalValidationTest(unittest.TestCase):
    def run_gate(self, command, budget="2", remediation=False):
        marker = '  validation_summary="Worker validation command not configured; GitHub checks are required before approval."'
        start = SOURCE.index(marker) if remediation else SOURCE.rindex(marker)
        block = SOURCE[start:SOURCE.index('\n  if ! git -C', start)]
        with tempfile.TemporaryDirectory() as directory:
            env = dict(os.environ, WORKDIR=directory, VALIDATION_COMMAND=command,
                       VALIDATION_TIMEOUT_SECONDS=budget)
            script = '\n'.join([
                'set -euo pipefail',
                'log() { :; }',
                'mark_failed() { printf "FAILED:%s:%s\\n" "$1" "$2"; }',
                FUNCTION, 'run_gate() {', 'local issue=111 number=111 validation_summary',
                block, 'echo PUBLICATION_ALLOWED', '}', 'run_gate',
            ])
            return subprocess.run(['bash', '-c', script], env=env, text=True,
                                  capture_output=True, timeout=15)

    def test_both_publication_paths_block_on_timeout(self):
        for remediation in (False, True):
            result = self.run_gate('sleep 5', budget='1', remediation=remediation)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('deadline exhausted', result.stdout)
            self.assertNotIn('PUBLICATION_ALLOWED', result.stdout)

    def test_both_paths_block_on_failure(self):
        for remediation in (False, True):
            result = self.run_gate('exit 7', remediation=remediation)
            self.assertIn('exit 7', result.stdout)
            self.assertNotIn('PUBLICATION_ALLOWED', result.stdout)

    def test_success_and_unconfigured_command_preserve_publication(self):
        for remediation in (False, True):
            for command in ('test -d "$PWD"', ''):
                result = self.run_gate(command, remediation=remediation)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('PUBLICATION_ALLOWED', result.stdout)
                self.assertNotIn('FAILED:', result.stdout)

    def test_invalid_budget_never_runs_command(self):
        for budget in ('0', '-1', 'invalid'):
            result = self.run_gate('echo SHOULD_NOT_RUN', budget=budget)
            self.assertIn('invalid timeout', result.stdout)
            self.assertNotIn('SHOULD_NOT_RUN', result.stdout)
            self.assertNotIn('PUBLICATION_ALLOWED', result.stdout)


if __name__ == '__main__':
    unittest.main()
