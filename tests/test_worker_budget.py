"""Exercise the real worker CLI route against isolated fixture repositories."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / "platform/scripts/homedir-sdlc-worker.sh").read_text()


def function(name):
    start = SOURCE.index(name + "() {")
    return SOURCE[start:SOURCE.index("\n}\n", start) + 3]


class WorktreeImplementationTest(unittest.TestCase):
    def run_case(self, agent, validation="test -f change.txt", budget=5, cap=5):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            repo = root / "repo"
            repo.mkdir()
            def git(*args):
                return subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, text=True).stdout.strip()
            git("init", "-b", "main")
            git("config", "user.name", "Fixture")
            git("config", "user.email", "fixture@example.invalid")
            (repo / "AGENTS.md").write_text("Read the fixture instructions before editing.\n")
            git("add", ".")
            git("commit", "-m", "initial")
            base = git("rev-parse", "HEAD")
            git("switch", "-c", "fix/fixture")
            binary = root / "agent"
            binary.write_text('#!/bin/bash\nset -eu\nprintf "%s\\n" "$*" > "$PROMPT_CAPTURE"\n' + agent + "\n")
            binary.chmod(0o700)
            env = dict(os.environ, WORKDIR=str(repo), SCC_BIN=str(binary), LOGFILE=str(root / "log"), PROMPT_CAPTURE=str(root / "prompt"))
            script = "\n".join([
                "set -euo pipefail",
                f"SCC_TIMEOUT_SECONDS={cap}; SCC_PROFILE=fixture; SCC_CLEAR_HISTORY=true",
                "log() { printf '%s\\n' \"$*\"; }",
                "classify_issue_complexity() { echo simple; }",
                f"get_timeout_for_complexity() {{ echo {budget}; }}",
                f"get_validation_command_for_changes() {{ echo '{validation}'; }}",
                "call_implementation_service() { echo forbidden-http-route; return 99; }",
                *[function(name) for name in ("remaining_implementation_seconds", "run_scc_handle_exit_code", "run_scc_prompt", "run_scc_checked", "run_initial_implementation")],
                'if run_initial_implementation 63 body prompt; then exit 0; else exit $?; fi',
            ])
            result = subprocess.run(["bash", "-c", script], env=env, text=True, capture_output=True, timeout=12)
            prompt = (root / "prompt").read_text()
            self.assertIn(base, prompt)
            self.assertIn("AGENTS.md", prompt)
            self.assertNotIn("forbidden-http-route", result.stdout)
            return result

    def test_real_file_change_and_validation(self):
        result = self.run_case("cat AGENTS.md >/dev/null; echo fixed > change.txt")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("changed_files=change.txt", result.stdout)
        self.assertIn("Scoped validation passed", result.stdout)

    def test_agent_committed_changes_are_also_validated(self):
        result = self.run_case("echo fixed > change.txt; git add change.txt; git commit -m fix")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Scoped validation passed", result.stdout)

    def test_prose_without_diff_is_rejected(self):
        result = self.run_case("echo 'Implementation complete'")
        self.assertEqual(result.returncode, 1)
        self.assertIn("no repository diff", result.stdout)

    def test_wrong_base_is_rejected(self):
        result = self.run_case("git commit --amend --allow-empty -m rewritten; echo fixed > change.txt")
        self.assertEqual(result.returncode, 1)
        self.assertIn("base history", result.stdout)

    def test_branch_switch_is_rejected(self):
        result = self.run_case("git switch -c unexpected; echo fixed > change.txt")
        self.assertEqual(result.returncode, 1)

    def test_failed_validation_is_rejected(self):
        result = self.run_case("echo fixed > change.txt", validation="false")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Scoped validation failed", result.stdout)

    def test_timeout_is_preserved(self):
        result = self.run_case("sleep 3", budget=1)
        self.assertEqual(result.returncode, 124, result.stderr)

    def test_validation_cannot_outlive_shared_deadline(self):
        result = self.run_case("echo fixed > change.txt", validation="sleep 5", budget=1)
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertIn("Scoped validation exhausted", result.stdout)

    def test_agent_time_is_deducted_from_validation_budget(self):
        result = self.run_case("sleep 1; echo fixed > change.txt", validation="sleep 2", budget=2)
        self.assertEqual(result.returncode, 124, result.stderr)

    def test_configured_cap_limits_complexity_budget(self):
        result = self.run_case("sleep 3", budget=5, cap=1)
        self.assertEqual(result.returncode, 124, result.stderr)


if __name__ == "__main__":
    unittest.main()
