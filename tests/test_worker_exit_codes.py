"""Exercise worker exit handling in Bash without external services."""

from pathlib import Path
import subprocess
import unittest


WORKER = Path(__file__).resolve().parents[1] / "platform/scripts/homedir-sdlc-worker.sh"
SOURCE = WORKER.read_text()


def function(name):
    start = SOURCE.index(name + "() {")
    end = SOURCE.index("\n}\n", start) + 3
    return SOURCE[start:end]


class WorkerExitCodesTest(unittest.TestCase):
    def test_remediation_preserves_agent_status(self):
        for code in (0, 124, 7):
            with self.subTest(code=code):
                script = "\n".join([
                    "set -euo pipefail",
                    "SCC_TIMEOUT_SECONDS=1800",
                    "log() { printf '%s\\n' \"$*\"; }",
                    f"run_scc_prompt() {{ return {code}; }}",
                    function("run_scc_handle_exit_code"),
                    function("run_scc_with_timeout_handling"),
                    'if run_scc_with_timeout_handling prompt; then exit 0; else exit $?; fi',
                ])
                result = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
                self.assertEqual(result.returncode, code, result.stderr)
                if code == 124:
                    self.assertIn("timed out", result.stdout)

    def test_initial_failure_preserves_timeout_classification(self):
        start = SOURCE.index("  if [[ $scc_rc -eq 0 ]]; then")
        end = SOURCE.index('\n  if [[ "$(git -C', start)
        block = SOURCE[start:end]
        for code, expected in ((0, "continued"), (124, "timed out after 900s"), (7, "non-zero (7)")):
            with self.subTest(code=code):
                script = "\n".join([
                    "set -euo pipefail",
                    "log() { :; }",
                    'mark_failed() { printf "%s\\n" "$2"; }',
                    "classify_issue_complexity() { echo simple; }",
                    "get_timeout_for_complexity() { echo 900; }",
                    "run_case() {",
                    f"local scc_rc={code} number=55 body=example LOGFILE=offline.log",
                    block,
                    "echo continued",
                    "}",
                    "run_case",
                ])
                result = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(expected, result.stdout)
                if code:
                    self.assertNotIn("continued", result.stdout)


if __name__ == "__main__":
    unittest.main()
