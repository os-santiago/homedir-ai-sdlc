"""Bounded parser and durable receipt tests without a runtime or external services."""

import base64
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "platform/scripts"))
from container_receipts import ProtocolError, ReceiptStream, capture_container, reconcile_container
from durable_run_state import RunState, StateError, digest


def frame(path="allowed.txt", content=b"proposal"):
    return json.dumps({"path": path, "content": base64.b64encode(content).decode(), "mode": 420}).encode() + b"\n"


class ReceiptParserTest(unittest.TestCase):
    def setUp(self):
        self.saved = []
        self.stream = ReceiptStream(["allowed.txt"], lambda entries, number: self.saved.append((entries, number)))

    def test_split_frames_and_replacements_persist_before_end(self):
        raw = frame()
        self.stream.feed(raw[:9])
        self.assertEqual(self.saved, [])
        self.stream.feed(raw[9:] + frame(content=b"updated"))
        self.assertEqual(len(self.saved), 2)
        self.assertEqual(base64.b64decode(self.saved[-1][0][0]["content"]), b"updated")
        self.stream.feed(b'{"path":"allowed.txt","delete":true}\n')
        self.assertEqual(self.saved[-1][0][0]["delete"], True)

    def test_invalid_frames_cannot_claim_success_or_escape_scope(self):
        for raw in (frame("../outside"), frame("/absolute"), frame(".git/config"), frame("other.txt"),
                    b'{"path":"allowed.txt","delete":true,"success":true}\n',
                    b'{"path":"allowed.txt","path":"allowed.txt","delete":true}\n',
                    b'{"path":"allowed.txt","content":"!!!","mode":420}\n',
                    b'{"path":"allowed.txt","content":"","mode":true}\n', b'null\n'):
            with self.subTest(raw=raw[:60]), self.assertRaises(ProtocolError):
                ReceiptStream(["allowed.txt"], lambda *_: self.fail("invalid frame persisted")).feed(raw)

    def test_partial_tail_and_malformed_frame_retain_accepted_prefix(self):
        self.stream.feed(frame() + b'{"path":')
        with self.assertRaises(ProtocolError):
            self.stream.end()
        self.assertEqual(len(self.saved), 1)

    def test_file_frame_stream_and_count_limits(self):
        for raw in (frame(content=b"x" * (ReceiptStream.MAX_FILE + 1)),
                    b"x" * (ReceiptStream.MAX_FRAME + 1), b"x" * (ReceiptStream.MAX_WIRE + 1)):
            with self.subTest(size=len(raw)), self.assertRaises(ProtocolError):
                ReceiptStream(["allowed.txt"], lambda *_: None).feed(raw)
        self.stream.feed(frame() * 32)
        with self.assertRaises(ProtocolError):
            self.stream.feed(frame())
        self.assertEqual(len(self.saved), 32)

    def test_decoded_total_limit(self):
        stream = ReceiptStream([f"f{i}" for i in range(5)], lambda *_: None)
        for i in range(4):
            stream.feed(frame(f"f{i}", b"x" * ReceiptStream.MAX_FILE))
        with self.assertRaises(ProtocolError):
            stream.feed(frame("f4", b"x"))


class LedgerFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        def git(*args):
            return subprocess.check_output(["git", "-C", str(self.repo), *args], stderr=subprocess.DEVNULL).decode().strip()
        git("init", "-b", "main")
        git("config", "user.name", "Fixture")
        git("config", "user.email", "fixture@example.invalid")
        (self.repo / "baseline").write_text("unchanged")
        git("add", ".")
        git("commit", "-m", "fixture")
        self.identity = dict(requirement_hash=digest(b"requirement"), base_sha=git("rev-parse", "HEAD"), policy_version="1", plan_version="1")

    def open(self):
        return RunState(self.root / "state", "run", self.repo, self.identity, edit_seconds=30)


class ReceiptLedgerTest(LedgerFixture):
    def test_cleanup_failure_retains_reservation_and_blocks_generic_recovery(self):
        fixture = self.root / "fixture.py"
        fixture.write_text("print('fixture')")
        real_popen = subprocess.Popen
        def launch(argv, *args, **kwargs):
            if argv[0] == "podman":
                raise OSError("fixture launch failed")
            return real_popen(argv, *args, **kwargs)
        with self.open() as run:
            with patch("container_receipts.subprocess.Popen", side_effect=launch), \
                 patch("container_receipts.reconcile_container", side_effect=StateError("runtime unavailable")):
                with self.assertRaises(StateError):
                    capture_container(run, "sha256:" + "a" * 64, fixture, ["allowed.txt"], seconds=3)
        with self.open() as run:
            self.assertIsNotNone(run.data["external_container"])
            self.assertEqual(run.data["remaining"]["edit"], 27)
            with self.assertRaises(StateError):
                run.recover_interrupted()

    def test_reconciliation_refuses_unowned_container(self):
        name = "sdlc-boundary-" + "a" * 32
        inspected = json.dumps([{"Name": name, "Config": {"Labels": {"io.os-santiago.sdlc": "other"}}}])
        replies = [subprocess.CompletedProcess([], 0, "", ""), subprocess.CompletedProcess([], 0, inspected, "")]
        with patch("container_receipts.subprocess.run", side_effect=replies) as mocked:
            with self.assertRaises(StateError):
                reconcile_container(name)
            self.assertEqual(mocked.call_count, 2)

    def test_existing_checkpoint_is_preserved_and_schema_never_downgrades(self):
        from durable_step_runner import restore_checkpoint
        with self.open() as run:
            run.begin("validation", 1, "prior-step")
            run.finish("success", 0)
            prior = dict(run.data["checkpoint"])
            run.begin("edit", 3, "step")
            run.start_container_capture("sdlc-boundary-" + "a" * 32, "sha256:" + "a" * 64)
            ReceiptStream(["allowed.txt"], run.container_progress).feed(frame())
            run.finish_container_capture("failed")
            self.assertEqual(run.data["checkpoint"], prior)
            restore_checkpoint(run, self.root / "scratch")
            self.assertEqual(run.data["version"], 3)
            self.assertEqual(run.data["remaining"]["edit"], 27)

    def test_receipts_survive_reopen_without_validating_or_applying(self):
        with self.open() as run:
            run.begin("edit", 3, "step")
            run.start_container_capture("sdlc-boundary-" + "a" * 32, "sha256:" + "a" * 64)
            ReceiptStream(["allowed.txt"], run.container_progress).feed(frame())
        with self.open() as run:
            self.assertEqual(run.data["version"], 3)
            self.assertEqual(run.data["remaining"]["edit"], 27)
            with self.assertRaises(StateError):
                run.recover_interrupted()
            with self.assertRaises(StateError):
                run.finish("success", 0)
            receipt = run._artifact(run.data["last_container_receipt"])
            self.assertEqual(receipt["identity"], run.identity)
            self.assertEqual(receipt["step"], "step")
            run.finish_container_capture("interrupted")  # Fake trusted reconciler.
            self.assertEqual(run.data["status"], "untrusted")
            self.assertIsNone(run.data["checkpoint"])
            with self.assertRaises(StateError):
                run.publication_intent("codex/fixture")
        self.assertFalse((self.repo / "allowed.txt").exists())

    def test_corrupted_receipt_fails_closed(self):
        with self.open() as run:
            run.begin("edit", 3, "step")
            run.start_container_capture("sdlc-boundary-" + "b" * 32, "sha256:" + "a" * 64)
            ReceiptStream(["allowed.txt"], run.container_progress).feed(frame())
            path = run.path / run.data["last_container_receipt"]["name"]
        path.write_text("corrupted")
        with self.assertRaises(StateError):
            with self.open():
                pass
