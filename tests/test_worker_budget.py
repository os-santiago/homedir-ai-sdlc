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
    def run_case(self, agent, validation="test -f change.txt", budget=5, cap=5, help_command="exit 0"):
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
            binary.write_text('#!/bin/bash\nset -eu\ncase " $* " in *" --help "*) ' + help_command + ';; esac\nprintf "%s\\n" "$*" > "$PROMPT_CAPTURE"\n' + agent + "\n")
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
            if (root / "prompt").exists():
                prompt = (root / "prompt").read_text()
                self.assertIn(base, prompt)
                self.assertIn("AGENTS.md", prompt)
            else:
                self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("forbidden-http-route", result.stdout)
            return result

    def test_real_file_change_and_validation(self):
        result = self.run_case("cat AGENTS.md >/dev/null; echo fixed > change.txt")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("changed_files=change.txt", result.stdout)
        self.assertIn("Scoped validation passed", result.stdout)

    def test_unresponsive_help_is_bounded_without_launching_agent(self):
        result = self.run_case("echo unexpected-generation; echo fixed > change.txt", cap=1,
                               help_command="sleep 4; exit 0")
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertIn("capability discovery timed out", result.stdout)
        self.assertNotIn("unexpected-generation", result.stdout)

    def test_help_time_is_charged_to_generation_deadline(self):
        result = self.run_case("sleep 2; echo fixed > change.txt", cap=3,
                               help_command="sleep 2; exit 0")
        self.assertEqual(result.returncode, 124, result.stderr)

    def test_old_cli_without_help_still_executes(self):
        result = self.run_case("echo fixed > change.txt", help_command="exit 2")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_invalid_cap_refuses_execution(self):
        result = self.run_case("echo unexpected-generation", cap="invalid")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertNotIn("unexpected-generation", result.stdout)

    def test_timeout_environment_precedence(self):
        assignment = next(line for line in SOURCE.splitlines() if line.startswith('SCC_TIMEOUT_SECONDS='))
        for setup, expected in (("", "1800"), ("SCC_TIMEOUT_SECONDS=600", "600"),
                                ("SCC_TIMEOUT_SECONDS=600; HOMEDIR_SDLC_SCC_TIMEOUT_SECONDS=300", "300")):
            result = subprocess.run(["bash", "-c", 'unset SCC_TIMEOUT_SECONDS HOMEDIR_SDLC_SCC_TIMEOUT_SECONDS\n'
                                     + setup + '\n' + assignment + '\nprintf %s "$SCC_TIMEOUT_SECONDS"'],
                                    capture_output=True, text=True, check=True)
            self.assertEqual(result.stdout, expected)

    def test_remediation_generation_obeys_cap_without_initial_wrapper(self):
        with tempfile.TemporaryDirectory() as temp:
            binary = Path(temp) / "agent"
            binary.write_text('#!/bin/bash\ncase " $* " in *" --help "*) exit 0;; esac\nsleep 4\n')
            binary.chmod(0o700)
            env = dict(os.environ, WORKDIR=temp, SCC_BIN=str(binary), LOGFILE=str(Path(temp) / "log"))
            script = "\n".join([
                "set -euo pipefail",
                "SCC_TIMEOUT_SECONDS=1; SCC_PROFILE=fixture; SCC_CLEAR_HISTORY=true",
                "log() { :; }",
                "classify_issue_complexity() { echo complex; }",
                "get_timeout_for_complexity() { echo 100; }",
                function("remaining_implementation_seconds"), function("run_scc_prompt"),
                'run_scc_prompt prompt body',
            ])
            result = subprocess.run(["bash", "-c", script], env=env, capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 124, result.stderr)

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
