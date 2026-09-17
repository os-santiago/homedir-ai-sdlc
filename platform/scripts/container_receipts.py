"""Bounded untrusted proposals from the offline container boundary; never applies files."""

import base64
import json
import os
import re
import selectors
import subprocess
import time

from container_boundary import qualification_boundary, runtime_environment
from durable_run_state import StateError


class ProtocolError(ValueError):
    pass


def relative_path(value):
    if not isinstance(value, str) or len(value) > 240:
        raise ProtocolError("invalid path")
    parts = value.split("/")
    if any(not re.fullmatch(r"[A-Za-z0-9_.-]+", p) or p in {".", "..", ".git", ".ssh"} for p in parts):
        raise ProtocolError("unsafe path")
    return value


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ProtocolError("duplicate JSON key")
        result[key] = value
    return result


class ReceiptStream:
    MAX_FRAME = 360 * 1024
    MAX_WIRE = 2 * 1024 * 1024
    MAX_FILE = 256 * 1024
    MAX_TOTAL = 1024 * 1024

    def __init__(self, allowed_paths, persist):
        self.allowed = {relative_path(path) for path in allowed_paths}
        if not 1 <= len(self.allowed) <= 16:
            raise ProtocolError("one to sixteen exact allowed paths required")
        self.persist = persist
        self.buffer = b""
        self.wire = 0
        self.frames = 0
        self.entries = {}
        self.sizes = {}

    def feed(self, chunk):
        self.wire += len(chunk)
        if self.wire > self.MAX_WIRE:
            raise ProtocolError("stream limit exceeded")
        self.buffer += chunk
        while b"\n" in self.buffer:
            line, self.buffer = self.buffer.split(b"\n", 1)
            self._frame(line)
        if len(self.buffer) > self.MAX_FRAME:
            raise ProtocolError("frame limit exceeded")

    def _frame(self, line):
        if len(line) > self.MAX_FRAME or self.frames >= 32:
            raise ProtocolError("frame limit exceeded")
        try:
            entry = json.loads(line.decode("utf-8"), object_pairs_hook=unique_object)
            path = relative_path(entry["path"])
            if path not in self.allowed:
                raise ProtocolError("path outside approved scope")
            if set(entry) == {"path", "delete"} and entry["delete"] is True:
                size = 0
            elif set(entry) == {"path", "content", "mode"} and type(entry["mode"]) is int and entry["mode"] in (0o644, 0o755):
                raw = base64.b64decode(entry["content"], validate=True)
                if base64.b64encode(raw).decode() != entry["content"]:
                    raise ProtocolError("noncanonical base64")
                size = len(raw)
            else:
                raise ProtocolError("invalid file proposal")
            if size > self.MAX_FILE or sum(self.sizes.values()) - self.sizes.get(path, 0) + size > self.MAX_TOTAL:
                raise ProtocolError("decoded size limit exceeded")
        except (KeyError, TypeError, ValueError, UnicodeError, RecursionError) as exc:
            raise ProtocolError("invalid proposal frame") from exc
        entries = dict(self.entries, **{path: entry})
        # Persist before acknowledging a frame or consuming subsequent proposals.
        self.persist([entries[key] for key in sorted(entries)], self.frames + 1)
        self.entries = entries
        self.sizes[path] = size
        self.frames += 1

    def end(self):
        if self.buffer:
            raise ProtocolError("incomplete final frame")


def reconcile_container(name):
    """Remove only the recorded, correctly labelled qualification container."""
    if not re.fullmatch(r"sdlc-boundary-[0-9a-f]{32}", name):
        raise StateError("invalid container identity")
    def podman(*args):
        return subprocess.run(["podman", "--remote=false", *args], env=runtime_environment(),
                              capture_output=True, text=True, timeout=20)
    exists = podman("container", "exists", name)
    if exists.returncode == 1:
        return
    if exists.returncode != 0:
        raise StateError("container existence unknown")
    inspected = podman("inspect", name)
    if inspected.returncode:
        raise StateError("container identity unknown")
    info = json.loads(inspected.stdout)[0]
    if info["Name"].lstrip("/") != name or info["Config"]["Labels"].get("io.os-santiago.sdlc") != "boundary-qualification":
        raise StateError("refusing to remove an unowned container")
    if podman("rm", "--force", "--time", "0", name).returncode != 0:
        raise StateError("container removal failed")
    if podman("container", "exists", name).returncode != 1:
        raise StateError("container removal not confirmed")


def recover_container_capture(run):
    container = run.data.get("external_container")
    if not container:
        raise StateError("no container capture to reconcile")
    reconcile_container(container["name"])
    run.finish_container_capture("interrupted")


def capture_container(run, image_id, fixture, allowed_paths, seconds=10, step_id="edit", cancelled=lambda: False):
    """Offline reviewed fixtures only; source checkout and ledger are never mounted."""
    boundary = qualification_boundary(image_id, fixture, seconds)
    stream = ReceiptStream(allowed_paths, run.container_progress)
    run.begin("edit", seconds, step_id)
    run.start_container_capture(boundary.name, image_id)
    process = None
    observation = "failed"
    try:
        process = subprocess.Popen(boundary.argv, env=runtime_environment(), stdin=subprocess.DEVNULL,
                                   stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        deadline = time.monotonic() + seconds + 5
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            while True:
                if cancelled():
                    observation = "cancelled"
                    break
                if time.monotonic() >= deadline:
                    observation = "timeout"
                    break
                if not selector.select(timeout=0.05):
                    continue
                chunk = os.read(process.stdout.fileno(), 65536)
                if not chunk:
                    code = process.wait(timeout=2)
                    stream.end()
                    observation = "exited" if code == 0 else "failed"
                    break
                stream.feed(chunk)
    except ProtocolError:
        observation = "invalid"
    except (KeyboardInterrupt, SystemExit):
        observation = "cancelled"
        raise
    finally:
        # Any engine/reconciliation error leaves intent + reservation unresolved.
        if process is not None:
            process.stdout.close()
        try:
            reconcile_container(boundary.name)
        finally:
            if process is not None:
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
        run.finish_container_capture(observation)
    return run._artifact(run.data["last_container_receipt"])
