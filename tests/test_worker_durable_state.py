"""Fault-injection tests using local repositories, no models or external publishers."""

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "platform/scripts/durable_run_state.py"
spec = importlib.util.spec_from_file_location("durable_run_state", MODULE)
state = importlib.util.module_from_spec(spec)
spec.loader.exec_module(state)


class DurableStateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.git("init", "-b", "main")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "user.name", "Fixture")
        (self.repo / "tracked.txt").write_text("before\n")
        self.git("add", ".")
        self.git("commit", "-m", "fixture")
        self.identity = dict(requirement_hash=state.digest(b"requirement"), base_sha=self.git("rev-parse", "HEAD"),
                             policy_version="1", plan_version="1")
        self.now = 1000

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args], stderr=subprocess.DEVNULL).decode().strip()

    def open(self, **kwargs):
        return state.RunState(self.root / "state", "run-1", self.repo, self.identity,
                              edit_seconds=10, validation_seconds=5, max_attempts=2,
                              clock=lambda: self.now, **kwargs)

    def edit(self):
        (self.repo / "tracked.txt").write_text("after\n")
        (self.repo / "new.txt").write_text("new content\n")

    def validate(self, run):
        run.begin("validation", 3, "step-1")
        run.finish("success", 1)

    def test_success_is_untrusted_until_independent_validation(self):
        with self.open() as run:
            run.begin("edit", 4, "step-1")
            self.edit()
            run.finish("success", 2)
            self.assertEqual(run.data["status"], "untrusted")
            with self.assertRaises(state.StateError):
                run.checkpoint()
            self.validate(run)
            checkpoint = run.checkpoint()
            self.assertEqual(checkpoint["untracked"][0]["path"], "new.txt")
            self.assertEqual(run.data["remaining"], {"edit": 8, "validation": 4})
            self.assertTrue(all(not a["trusted"] for a in run.data["artifacts"]))

    def test_failure_timeout_and_cancel_preserve_work(self):
        for outcome in ("failure", "timeout", "cancelled"):
            with self.subTest(outcome=outcome):
                # Each case uses its own identity and ledger directory.
                with state.RunState(self.root / outcome, "run", self.repo, self.identity) as run:
                    run.begin("edit", 2, "step")
                    self.edit()
                    run.finish(outcome, 2)
                    artifact = run._artifact(run.data["artifacts"][-1])
                    self.assertTrue(artifact["patch"])
                    self.assertTrue(artifact["untracked"])
                    self.assertEqual(run.data["status"], "untrusted")

    def test_restart_after_crash_keeps_full_reservation_and_recovers_partial(self):
        with self.open() as run:
            run.begin("edit", 6, "step-1")
            self.edit()
            # Simulate process death: no finish call and no refund.
        with self.open() as run:
            self.assertEqual(run.data["remaining"]["edit"], 4)
            with self.assertRaises(state.StateError):
                run.begin("edit", 1, "step-1")
            run.recover_interrupted()
            self.assertTrue(run._artifact(run.data["artifacts"][-1])["untracked"])
            self.assertEqual(run.data["status"], "untrusted")
            with self.assertRaises(state.StateError):
                run.begin("edit", 5, "step-1")
            run.begin("edit", 4, "step-1")
            run.finish("timeout", 4)
            with self.assertRaises(state.StateError):
                run.begin("edit", 1, "step-1")
            self.validate(run)  # Edit exhaustion does not consume validation reserve.

    def test_attempt_limit_persists_even_when_execution_is_fast(self):
        for _ in range(2):
            with self.open() as run:
                run.begin("edit", 1, "step")
                run.finish("failure", 0)
        with self.open() as run:
            with self.assertRaises(state.StateError):
                run.begin("edit", 1, "step")

    def test_abrupt_process_exit_preserves_manifest_and_releases_lock(self):
        script = '''import importlib.util, json, os, pathlib, sys
spec = importlib.util.spec_from_file_location("ledger", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with module.RunState(sys.argv[2], "run-1", sys.argv[3], json.loads(sys.argv[4]),
                     edit_seconds=10, validation_seconds=5, max_attempts=2) as run:
    run.begin("edit", 6, "step")
    pathlib.Path(sys.argv[3], "new.txt").write_text("partial")
    os._exit(23)
'''
        result = subprocess.run([sys.executable, "-c", script, str(MODULE), str(self.root / "state"),
                                 str(self.repo), json.dumps(self.identity)], timeout=10)
        self.assertEqual(result.returncode, 23)
        with self.open() as run:
            run.recover_interrupted()
            self.assertEqual(run.data["remaining"]["edit"], 4)
            self.assertEqual(run._artifact(run.data["artifacts"][-1])["untracked"][0]["path"], "new.txt")

    def test_methods_require_lock_and_state_cannot_live_in_checkout(self):
        run = self.open()
        with self.assertRaises(state.StateError):
            run.begin("edit", 1, "step")
        with self.assertRaises(state.StateError):
            state.RunState(self.repo / "state", "run", self.repo, self.identity)

    def test_validation_mutating_candidate_never_creates_checkpoint(self):
        with self.open() as run:
            run.begin("validation", 2, "step")
            self.edit()
            run.finish("success", 1)
            self.assertIsNone(run.data["checkpoint"])

    def test_stale_requirement_and_changed_base_are_rejected(self):
        with self.open() as run:
            self.validate(run)
        self.identity["requirement_hash"] = "changed"
        with self.assertRaises(state.StateError):
            with self.open():
                pass
        self.identity["requirement_hash"] = state.digest(b"requirement")
        self.git("commit", "--allow-empty", "-m", "new base")
        with self.open() as run:
            with self.assertRaises(state.StateError):
                run.checkpoint()

    def test_manifest_and_artifact_corruption_fail_closed(self):
        with self.open() as run:
            self.validate(run)
            artifact = run.path / run.data["artifacts"][-1]["name"]
        old = artifact.read_bytes()
        artifact.write_bytes(b"corrupt")
        with self.assertRaises(state.StateError):
            with self.open():
                pass
        artifact.write_bytes(old)
        manifest = self.root / "state/run-1/manifest.json"
        envelope = json.loads(manifest.read_text())
        envelope["data"]["remaining"]["edit"] = 9999
        manifest.write_text(json.dumps(envelope))
        with self.assertRaises(state.StateError):
            with self.open():
                pass

    def test_single_writer_lock_and_release(self):
        with self.open():
            with self.assertRaises(BlockingIOError):
                with self.open():
                    pass
        with self.open() as run:
            self.assertEqual(run.data["status"], "ready")

    def test_symlink_and_size_failure_preserve_source(self):
        outside = self.root / "secret"
        outside.write_text("private")
        (self.repo / "link").symlink_to(outside)
        with self.open() as run:
            with self.assertRaises(state.StateError):
                run.begin("edit", 1, "step")
            self.assertEqual(outside.read_text(), "private")
            (self.repo / "link").unlink()
            self.edit()
            run.MAX_ARTIFACT_BYTES = 1
            with self.assertRaises(state.StateError):
                run.begin("edit", 1, "step")
            self.assertTrue((self.repo / "new.txt").exists())

    def test_capacity_wait_is_bounded_persistent_and_separate(self):
        with self.open() as run:
            run.wait(60)
        with self.open() as run:
            with self.assertRaises(state.StateError):
                run.release_wait()
            self.now += 60
            run.release_wait()
            run.wait(180)
            self.now += 180
            run.release_wait()
            with self.assertRaises(state.StateError):
                run.wait(1)
            self.assertEqual(run.data["remaining"], {"edit": 10, "validation": 5})

    def test_wait_expiration_does_not_restart_execution(self):
        with self.open() as run:
            run.wait(60)
        self.now += 86401
        with self.open() as run:
            with self.assertRaises(state.StateError):
                run.release_wait()
            with self.assertRaises(state.StateError):
                run.begin("edit", 1, "step")

    def test_publication_crash_requires_reconcile_not_duplicate_creation(self):
        external_prs = []
        with self.open() as run:
            self.edit()
            self.validate(run)
            key = run.publication_intent("codex/fixture")
            external_prs.append(123)  # Fake publisher succeeded; acknowledgement lost.
        with self.open() as run:
            with self.assertRaises(state.StateError):
                run.publication_intent("codex/fixture")
            run.reconcile_publication(key, "codex/fixture", external_prs[0])
            run.reconcile_publication(key, "codex/fixture", external_prs[0])
            self.assertEqual(run.data["status"], "published")
            self.assertEqual(len(external_prs), 1)
            with self.assertRaises(state.StateError):
                run.reconcile_publication(key, "codex/fixture", 456)

    def test_changed_candidate_cannot_publish_validated_checkpoint(self):
        with self.open() as run:
            self.validate(run)
            self.edit()
            with self.assertRaises(state.StateError):
                run.publication_intent("codex/fixture")


if __name__ == "__main__":
    unittest.main()
