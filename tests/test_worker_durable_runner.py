"""Offline process and restore integration tests. No provider or production calls."""

import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPTS = Path(__file__).resolve().parents[1] / "platform/scripts"
sys.path.insert(0, str(SCRIPTS))
from durable_run_state import RunState, StateError, digest, encoded, atomic_write
from durable_step_runner import execute_step, restore_checkpoint


class DurableRunnerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.git("init", "-b", "main")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "user.name", "Fixture")
        (self.repo / "tracked").write_text("before\n")
        self.git("add", ".")
        self.git("commit", "-m", "fixture")
        self.identity = dict(requirement_hash=digest(b"requirement"), base_sha=self.git("rev-parse", "HEAD"),
                             policy_version="1", plan_version="1")

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args], stderr=subprocess.DEVNULL).decode().strip()

    def open(self):
        return RunState(self.root / "state", "run", self.repo, self.identity,
                        edit_seconds=15, validation_seconds=10, max_attempts=4)

    def execute(self, run, code, phase="edit", seconds=2, **kwargs):
        return execute_step(run, phase, seconds, "step", [sys.executable, "-c", code], **kwargs)

    def validate(self, run):
        return self.execute(run, "from pathlib import Path; assert Path('tracked').read_text() == 'after\\n'", phase="validation")

    def edit_and_validate(self, run):
        self.execute(run, "from pathlib import Path; Path('tracked').write_text('after\\n'); Path('new').write_bytes(b'\\x00binary'); Path('new').chmod(0o700)")
        self.validate(run)
        self.assertEqual(run.data["status"], "validated")

    def test_success_and_validation_use_separate_budgets(self):
        with self.open() as run:
            self.edit_and_validate(run)
            self.assertEqual(run.data["attempts"], 1)
            self.assertLess(run.data["remaining"]["edit"], 15)
            self.assertLess(run.data["remaining"]["validation"], 10)

    def test_timeout_stops_background_descendant_before_capture(self):
        child = "from pathlib import Path; import time; time.sleep(2); Path('late').write_text('must not appear')"
        code = f"import subprocess, sys, time; from pathlib import Path; Path('partial').write_text('saved'); subprocess.Popen([sys.executable, '-c', {child!r}]); time.sleep(30)"
        with self.open() as run:
            started = time.monotonic()
            report = self.execute(run, code, seconds=1)
            self.assertEqual(report["outcome"], "timeout")
            self.assertLess(time.monotonic() - started, 4)
            self.assertEqual(run.data["status"], "untrusted")
            self.assertTrue((self.repo / "partial").exists())
            time.sleep(1.1)
            self.assertFalse((self.repo / "late").exists())

    def test_background_child_is_stopped_even_after_successful_parent_exit(self):
        child = "from pathlib import Path; import time; time.sleep(1); Path('late').write_text('bad')"
        with self.open() as run:
            report = self.execute(run, f"import subprocess, sys; subprocess.Popen([sys.executable, '-c', {child!r}])")
            self.assertEqual(report["outcome"], "success")
            time.sleep(1.1)
            self.assertFalse((self.repo / "late").exists())

    def test_cancellation_preserves_partial_and_removes_active_reservation(self):
        with self.open() as run:
            report = self.execute(run, "from pathlib import Path; import time; Path('partial').write_text('saved'); time.sleep(30)",
                                  cancelled=lambda: (self.repo / "partial").exists())
            self.assertEqual(report["outcome"], "cancelled")
            self.assertIsNone(run.data["active"])
            self.assertTrue(run.data["artifacts"])

    def test_cancellation_during_watchdog_startup_is_acknowledged(self):
        with self.open() as run:
            report = self.execute(run, "import time; time.sleep(30)", cancelled=lambda: True)
            self.assertEqual(report["outcome"], "cancelled")
            self.assertIsNone(run.data["active"])

    def test_nonzero_and_missing_command_remain_untrusted(self):
        with self.open() as run:
            report = self.execute(run, "from pathlib import Path; Path('partial').write_text('saved'); raise SystemExit(7)")
            self.assertEqual(report["returncode"], 7)
            self.assertEqual(run.data["status"], "untrusted")
            report = execute_step(run, "edit", 2, "step", ["/nonexistent-fixture-executor"])
            self.assertEqual(report["outcome"], "failure")

    def test_caller_exception_cancels_process_and_preserves_evidence(self):
        def interrupt():
            if (self.repo / "partial").exists():
                raise KeyboardInterrupt()
            return False
        with self.open() as run:
            with self.assertRaises(KeyboardInterrupt):
                self.execute(run, "from pathlib import Path; import time; Path('partial').write_text('saved'); time.sleep(30)", cancelled=interrupt)
            self.assertIsNone(run.data["active"])
            self.assertEqual(run.data["events"][-1]["outcome"], "cancelled")

    def test_host_credentials_and_python_hooks_are_not_inherited(self):
        from unittest.mock import patch
        with patch.dict(os.environ, {"GH_TOKEN": "fixture-secret", "NVIDIA_API_KEY": "fixture-secret", "PYTHONSTARTUP": "/bad"}):
            with self.open() as run:
                report = self.execute(run, "import os; assert not any(key in os.environ for key in ('GH_TOKEN', 'NVIDIA_API_KEY', 'PYTHONSTARTUP'))")
                self.assertEqual(report["outcome"], "success")
                self.assertNotIn("fixture-secret", (run.path / "manifest.json").read_text())

    def test_caller_sigkill_leaves_watchdog_lock_until_deadline(self):
        script = '''import json, sys
from durable_run_state import RunState
from durable_step_runner import execute_step
with RunState(sys.argv[1], "run", sys.argv[2], json.loads(sys.argv[3]), edit_seconds=15, validation_seconds=10, max_attempts=4) as run:
    execute_step(run, "edit", 2, "step", [sys.executable, "-c", "from pathlib import Path; import time; Path('started').write_text('yes'); time.sleep(30)"])
'''
        environment = dict(os.environ, PYTHONPATH=str(SCRIPTS))
        caller = subprocess.Popen([sys.executable, "-c", script, str(self.root / "state"), str(self.repo), json.dumps(self.identity)], env=environment)
        try:
            deadline = time.monotonic() + 5
            while not (self.repo / "started").exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue((self.repo / "started").exists())
            caller.send_signal(signal.SIGKILL)
            caller.wait(timeout=2)
            with self.assertRaises(BlockingIOError):
                with self.open():
                    pass
            while True:
                try:
                    with self.open() as run:
                        self.assertEqual(run.data["remaining"]["edit"], 13)
                        run.recover_interrupted()
                        self.assertEqual(run.data["status"], "untrusted")
                    break
                except BlockingIOError:
                    if time.monotonic() >= deadline:
                        self.fail("watchdog did not release lock after deadline")
                    time.sleep(0.05)
        finally:
            if caller.poll() is None:
                caller.kill()
                caller.wait()

    def test_restore_preserves_partial_source_and_lifetime_limits_on_reopen(self):
        with self.open() as run:
            self.edit_and_validate(run)
            self.execute(run, "from pathlib import Path; Path('partial').write_text('untrusted'); raise SystemExit(1)")
            remaining = dict(run.data["remaining"])
            attempts = run.data["attempts"]
            restored = restore_checkpoint(run, self.root / "scratch")
            self.assertEqual(run.data["version"], 2)
            self.assertTrue((self.repo / "partial").exists())
            self.assertFalse((restored / "partial").exists())
            self.assertEqual((restored / "new").read_bytes(), b"\x00binary")
            self.assertEqual((restored / "new").stat().st_mode & 0o777, 0o700)
        with self.open() as run:
            self.assertEqual(run.repo, restored)
            self.assertEqual(run.data["remaining"], remaining)
            self.assertEqual(run.data["attempts"], attempts)
            self.assertEqual(self.validate(run)["outcome"], "success")

    def test_restore_refuses_untrusted_candidate_and_stale_base(self):
        with self.open() as run:
            with self.assertRaises(StateError):
                restore_checkpoint(run, self.root / "scratch")
            self.edit_and_validate(run)
            self.git("commit", "--allow-empty", "-m", "changed base")
            with self.assertRaises(StateError):
                restore_checkpoint(run, self.root / "scratch")

    def test_restore_rejects_traversal_even_with_integrity_valid_artifact(self):
        with self.open() as run:
            self.edit_and_validate(run)
            artifact = run.checkpoint()
            artifact["untracked"][0]["path"] = "../escape"
            sha = digest(encoded(artifact))
            item = {"name": f"artifact-{sha}.json", "sha256": sha, "trusted": False}
            atomic_write(run.path / item["name"], artifact)
            run.data["checkpoint"] = item
            with self.assertRaises(StateError):
                restore_checkpoint(run, self.root / "scratch")
            self.assertFalse((self.root / "escape").exists())

    def test_restore_rejects_untracked_path_through_tracked_symlink(self):
        outside = self.root / "outside"
        outside.mkdir()
        (self.repo / "link").symlink_to(outside, target_is_directory=True)
        self.git("add", "link")
        self.git("commit", "-m", "tracked link")
        self.identity["base_sha"] = self.git("rev-parse", "HEAD")
        with self.open() as run:
            self.edit_and_validate(run)
            artifact = run.checkpoint()
            artifact["untracked"][0]["path"] = "link/escape"
            sha = digest(encoded(artifact))
            item = {"name": f"artifact-{sha}.json", "sha256": sha, "trusted": False}
            atomic_write(run.path / item["name"], artifact)
            run.data["checkpoint"] = item
            with self.assertRaises(StateError):
                restore_checkpoint(run, self.root / "scratch")
            self.assertFalse((outside / "escape").exists())


if __name__ == "__main__":
    unittest.main()
