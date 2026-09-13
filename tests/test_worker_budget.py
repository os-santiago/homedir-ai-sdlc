"""Exercise initial implementation routing with a simulated agent/service."""

from pathlib import Path
import subprocess
import unittest


SOURCE = (Path(__file__).resolve().parents[1] / "platform/scripts/homedir-sdlc-worker.sh").read_text()


def function(name):
    start = SOURCE.index(name + "() {")
    return SOURCE[start:SOURCE.index("\n}\n", start) + 3]


class WorkerBudgetTest(unittest.TestCase):
    def run_case(self, service, budget=3):
        script = "\n".join([
            "set -euo pipefail",
            "log() { :; }",
            "classify_issue_complexity() { echo simple; }",
            f"get_timeout_for_complexity() {{ echo {budget}; }}",
            function("remaining_implementation_seconds"),
            function("run_initial_implementation"),
            "call_implementation_service() { " + service + "; }",
            'run_scc_checked() { echo "fallback:$(remaining_implementation_seconds)"; }',
            'if run_initial_implementation 61 body prompt; then exit 0; else exit $?; fi',
        ])
        return subprocess.run(["bash", "-c", script], capture_output=True, text=True, timeout=10)

    def test_success_does_not_fallback(self):
        result = self.run_case("echo generated; return 0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "generated")

    def test_submitted_failure_never_falls_back(self):
        for code in (1, 124, 7):
            with self.subTest(code=code):
                result = self.run_case(f"return {code}")
                self.assertEqual(result.returncode, code, result.stderr)
                self.assertNotIn("fallback", result.stdout)

    def test_unavailable_service_uses_remaining_budget(self):
        result = self.run_case("sleep 1.1; return 69", budget=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        remaining = int(result.stdout.strip().split(":")[1])
        self.assertGreater(remaining, 0)
        self.assertLess(remaining, 5)

    def test_expired_budget_prevents_fallback(self):
        result = self.run_case("sleep 1.1; return 69", budget=1)
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertNotIn("fallback", result.stdout)


if __name__ == "__main__":
    unittest.main()
