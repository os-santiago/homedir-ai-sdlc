"""Real bounded output and crash-recovery probes using the unchanged container profile."""

import json
import os
import signal
import subprocess
import sys
import time
import unittest

from test_worker_container_receipts import LedgerFixture, frame
from container_receipts import capture_container, recover_container_capture
from durable_run_state import StateError

IMAGE = os.environ.get("SDLC_BOUNDARY_TEST_IMAGE")


@unittest.skipUnless(IMAGE, "set SDLC_BOUNDARY_TEST_IMAGE to a preloaded immutable image ID")
class ContainerReceiptIntegrationTest(LedgerFixture):
    def fixture(self, tail=""):
        path = self.root / "fixture.py"
        path.write_text(f"import sys, time\nsys.stdout.buffer.write({frame()!r}); sys.stdout.flush()\n" + tail)
        path.chmod(0o444)
        return path

    def test_success_remains_untrusted_and_does_not_touch_checkout(self):
        with self.open() as run:
            result = capture_container(run, IMAGE, self.fixture(), ["allowed.txt"], seconds=5)
            self.assertEqual(result["observation"], "exited")
            self.assertEqual(result["frames"], 1)
            self.assertEqual(run.data["status"], "untrusted")
            self.assertEqual(run.data["remaining"]["edit"], 25)
            self.assertIsNone(run.data["checkpoint"])
        self.assertFalse((self.repo / "allowed.txt").exists())

    def test_timeout_and_invalid_output_preserve_complete_prefix(self):
        for tail in ("time.sleep(30)\n", "print('invalid output', flush=True)\n"):
            with self.subTest(tail=tail), self.open() as run:
                result = capture_container(run, IMAGE, self.fixture(tail), ["allowed.txt"], seconds=2)
                self.assertNotEqual(result["observation"], "exited")
                self.assertEqual(result["frames"], 1)
                self.assertIsNone(run.data["external_container"])

    def test_output_flood_is_bounded(self):
        with self.open() as run:
            result = capture_container(run, IMAGE, self.fixture("sys.stdout.write('x' * 3000000); sys.stdout.flush(); time.sleep(30)\n"), ["allowed.txt"], seconds=3)
            self.assertEqual(result["observation"], "invalid")
            self.assertEqual(result["frames"], 1)

    def test_cancelled_capture_retains_prefix(self):
        with self.open() as run:
            result = capture_container(run, IMAGE, self.fixture("time.sleep(30)\n"), ["allowed.txt"], seconds=3,
                                       cancelled=lambda: run.data.get("last_container_receipt") is not None)
            self.assertEqual(result["observation"], "cancelled")
            self.assertEqual(result["frames"], 1)

    def test_collector_sigkill_preserves_durable_prefix_and_requires_reconcile(self):
        fixture = self.fixture("time.sleep(30)\n")
        script = '''import json, sys
from durable_run_state import RunState
from container_receipts import capture_container
with RunState(sys.argv[1], "run", sys.argv[2], json.loads(sys.argv[3]), edit_seconds=30) as run:
    capture_container(run, sys.argv[4], sys.argv[5], ["allowed.txt"], seconds=5)
'''
        env = dict(os.environ, PYTHONPATH=str(__import__("pathlib").Path(__file__).resolve().parents[1] / "platform/scripts"))
        caller = subprocess.Popen([sys.executable, "-c", script, str(self.root / "state"), str(self.repo), json.dumps(self.identity), IMAGE, str(fixture)], env=env)
        try:
            manifest = self.root / "state/run/manifest.json"
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                if manifest.exists() and json.loads(manifest.read_text())["data"].get("last_container_receipt"):
                    break
                time.sleep(0.05)
            else:
                self.fail("no durable prefix received")
            caller.send_signal(signal.SIGKILL)
            caller.wait(timeout=3)
            with self.open() as run:
                with self.assertRaises(StateError):
                    run.recover_interrupted()
                recover_container_capture(run)
                receipt = run._artifact(run.data["last_container_receipt"])
                self.assertEqual(receipt["observation"], "interrupted")
                self.assertEqual(receipt["frames"], 1)
                self.assertEqual(run.data["remaining"]["edit"], 25)
        finally:
            if caller.poll() is None:
                caller.kill()
                caller.wait()
            with self.open() as run:
                if run.data.get("external_container"):
                    recover_container_capture(run)


if __name__ == "__main__":
    unittest.main()
