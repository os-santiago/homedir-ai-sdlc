"""Offline durable ledger for trusted orchestration; not a sandbox or worker route."""

import base64
import fcntl
from functools import wraps
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import subprocess
import tempfile
import time


class StateError(RuntimeError):
    """State cannot safely advance; preserve evidence and reconcile."""


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def locked(method):
    @wraps(method)
    def call(self, *args, **kwargs):
        if self.lock is None:
            raise StateError("writer lock required")
        return method(self, *args, **kwargs)
    return call


def atomic_write(path, value):
    data = encoded(value)
    fd, name = tempfile.mkstemp(prefix=".pending-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(name):
            os.unlink(name)


class RunState:
    """Use one private state root for the repository and hold this context throughout work.

    Callers must stop all candidate processes before capture/recovery. They own
    trusted validation and external reconciliation; this class executes neither.
    """

    MAX_ARTIFACT_BYTES = 16 * 1024 * 1024

    def __init__(self, root, run_id, repo, identity, edit_seconds=1800,
                 validation_seconds=600, max_attempts=6, clock=time.time):
        if not re.fullmatch(r"[a-zA-Z0-9_-]{1,80}", run_id):
            raise StateError("invalid run id")
        if set(identity) != {"requirement_hash", "base_sha", "policy_version", "plan_version"}:
            raise StateError("incomplete identity")
        if any(not isinstance(v, str) or not v for v in identity.values()):
            raise StateError("invalid identity")
        if any(type(v) is not int or v <= 0 for v in (edit_seconds, validation_seconds, max_attempts)):
            raise StateError("invalid limits")
        self.root = Path(root).resolve()
        self.repo = Path(repo).resolve()
        if self.root.is_relative_to(self.repo):
            raise StateError("state must be outside the candidate checkout")
        self.path = self.root / run_id
        self.identity = dict(identity, repository=str(self.repo), run_id=run_id)
        self.limits = {"edit": edit_seconds, "validation": validation_seconds, "attempts": max_attempts}
        self.clock = clock
        self.lock = None

    def __enter__(self):
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)
        if self.root.stat().st_mode & 0o077:
            raise StateError("state root must be private (0700)")
        fd = os.open(self.root / ".lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        self.lock = os.fdopen(fd, "r+")
        try:
            fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            if self.path.is_symlink():
                raise StateError("run directory cannot be a symlink")
            self.path.mkdir(exist_ok=True, mode=0o700)
            if self.path.stat().st_mode & 0o077:
                raise StateError("run directory must be private (0700)")
            manifest = self.path / "manifest.json"
            if manifest.is_symlink():
                raise StateError("manifest cannot be a symlink")
            if manifest.exists():
                try:
                    envelope = json.loads(manifest.read_bytes())
                    self.data = envelope["data"]
                    if digest(encoded(self.data)) != envelope["sha256"]:
                        raise ValueError("checksum")
                    if self.data["version"] not in (1, 2, 3) or self.data["identity"] != self.identity:
                        raise StateError("stale or incompatible run identity")
                    if self.data["limits"] != self.limits:
                        raise StateError("run limits cannot change on resume")
                    for item in self.data["artifacts"]:
                        self._artifact(item)
                    if self.data["version"] >= 2 and "candidate_repo" in self.data:
                        if not isinstance(self.data["candidate_repo"], str) or not self.data["candidate_repo"]:
                            raise StateError("invalid adopted candidate")
                        self.repo = Path(self.data["candidate_repo"]).resolve()
                    elif "candidate_repo" in self.data:
                        raise StateError("adopted candidate requires schema version 2")
                    elif self.data["version"] == 2:
                        raise StateError("missing adopted candidate")
                except (ValueError, KeyError, TypeError, OSError) as exc:
                    raise StateError("corrupt run state or artifact") from exc
            else:
                if any(self.path.iterdir()):
                    raise StateError("missing manifest in nonempty run directory")
                self.data = {"version": 1, "identity": self.identity, "limits": self.limits,
                             "remaining": {"edit": self.limits["edit"], "validation": self.limits["validation"]},
                             "attempts": 0, "active": None, "status": "ready", "artifacts": [],
                             "checkpoint": None, "events": [], "wait_count": 0,
                             "wait_until": None, "wait_started": None, "publication": None}
                self._save()
            return self
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def __exit__(self, *_):
        if self.lock is not None:
            self.lock.close()
            self.lock = None

    def _save(self):
        if self.lock is None:
            raise StateError("writer lock required")
        atomic_write(self.path / "manifest.json", {"data": self.data, "sha256": digest(encoded(self.data))})

    def _event(self, kind, **fields):
        self.data["events"].append(dict(kind=kind, timestamp=self.clock(), **fields))

    def _git(self, *args, repo=None):
        with tempfile.TemporaryFile() as output:
            result = subprocess.run(["git", "-C", str(repo or self.repo), *args], stdout=output,
                                    stderr=subprocess.DEVNULL, timeout=30)
            if result.returncode:
                raise StateError("repository capture failed")
            output.seek(0)
            data = output.read(self.MAX_ARTIFACT_BYTES + 1)
            if len(data) > self.MAX_ARTIFACT_BYTES:
                raise StateError("oversized repository output; source work retained")
            return data

    def _snapshot(self, repo=None):
        repo = Path(repo or self.repo).resolve()
        if self._git("rev-parse", "HEAD", repo=repo).decode().strip() != self.identity["base_sha"]:
            raise StateError("base changed; preserve checkout for manual reconciliation")
        patch = self._git("diff", "--binary", "--no-ext-diff", "--no-textconv", self.identity["base_sha"], "--", repo=repo)
        files = []
        size = len(patch)
        for raw in self._git("ls-files", "--others", "--exclude-standard", "-z", repo=repo).split(b"\0"):
            if not raw:
                continue
            name = os.fsdecode(raw)
            path = repo / name
            if not path.resolve().is_relative_to(repo):
                raise StateError("untracked path escapes repository")
            cursor = path
            while cursor != repo:
                if cursor.is_symlink():
                    raise StateError("untracked symlinks require manual preservation")
                cursor = cursor.parent
            fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
            with os.fdopen(fd, "rb") as stream:
                info = os.fstat(stream.fileno())
                if not stat.S_ISREG(info.st_mode) or size + info.st_size > self.MAX_ARTIFACT_BYTES:
                    raise StateError("unsupported or oversized untracked artifact")
                blob = stream.read(self.MAX_ARTIFACT_BYTES - size + 1)
                size += len(blob)
                files.append({"path": name, "mode": stat.S_IMODE(info.st_mode),
                              "content": base64.b64encode(blob).decode()})
        if size > self.MAX_ARTIFACT_BYTES:
            raise StateError("oversized artifact; source work retained")
        return {"base_sha": self.identity["base_sha"], "patch": base64.b64encode(patch).decode(), "untracked": files}

    def _capture(self):
        snapshot = self._snapshot()
        sha = digest(encoded(snapshot))
        name = f"artifact-{sha}.json"
        atomic_write(self.path / name, snapshot)
        item = {"name": name, "sha256": sha, "trusted": False}
        self.data["artifacts"].append(item)
        return item

    def _artifact(self, item):
        if not re.fullmatch(r"[0-9a-f]{64}", item["sha256"]) or item["name"] != f"artifact-{item['sha256']}.json":
            raise StateError("invalid artifact reference")
        path = self.path / item["name"]
        if path.is_symlink():
            raise StateError("artifact cannot be a symlink")
        raw = path.read_bytes()
        if digest(raw) != item["sha256"]:
            raise StateError("artifact checksum mismatch")
        return json.loads(raw)

    @locked
    def begin(self, phase, seconds, step_id):
        if phase not in ("edit", "validation") or type(seconds) is not int or seconds <= 0:
            raise StateError("invalid reservation")
        if not re.fullmatch(r"[a-zA-Z0-9_-]{1,80}", step_id):
            raise StateError("invalid step id")
        if self.data["active"] or self.data["publication"]:
            raise StateError("active or published run requires reconciliation")
        if self.data["status"] == "waiting":
            raise StateError("release bounded wait before executing")
        if phase == "edit" and self.data["attempts"] >= self.limits["attempts"]:
            raise StateError("attempt budget exhausted")
        if seconds > self.data["remaining"][phase]:
            raise StateError("phase budget exhausted")
        baseline = self._capture()
        self.data["remaining"][phase] -= seconds
        if phase == "edit":
            self.data["attempts"] += 1
        self.data["active"] = {"phase": phase, "seconds": seconds, "step": step_id,
                               "attempt": self.data["attempts"], "started": self.clock(),
                               "input_sha256": baseline["sha256"]}
        self.data["status"] = "running"
        self._event("reserved", phase=phase, seconds=seconds, step=step_id)
        self._save()

    @locked
    def finish(self, outcome, elapsed):
        if self.data.get("external_container"):
            raise StateError("container lifecycle must be reconciled before completion")
        active = self.data["active"]
        if active is None or outcome not in ("success", "failure", "timeout", "cancelled"):
            raise StateError("invalid completion")
        if type(elapsed) not in (int, float) or not math.isfinite(elapsed) or elapsed < 0 or elapsed > active["seconds"]:
            raise StateError("invalid elapsed duration")
        item = self._capture()
        phase = active["phase"]
        self.data["remaining"][phase] += active["seconds"] - elapsed
        self.data["active"] = None
        self.data["status"] = "untrusted"
        # Validation must not mutate the exact candidate it claims to validate.
        if phase == "validation" and outcome == "success" and item["sha256"] == active["input_sha256"]:
            self.data["checkpoint"] = dict(item, step=active["step"])
            self.data["status"] = "validated"
        self._event("finished", phase=phase, outcome=outcome, elapsed=elapsed, step=active["step"])
        self._save()

    @locked
    def recover_interrupted(self):
        if self.data.get("external_container"):
            raise StateError("container lifecycle must be reconciled before recovery")
        if self.data["active"] is None:
            raise StateError("no interrupted reservation")
        active = self.data["active"]
        self._capture()
        # Unknown elapsed work is charged at its full reserved duration.
        self.data["active"] = None
        self.data["status"] = "untrusted"
        self._event("interrupted", phase=active["phase"], charged_seconds=active["seconds"], step=active["step"])
        self._save()

    @locked
    def checkpoint(self):
        item = self.data["checkpoint"]
        if item is None:
            raise StateError("no validated checkpoint")
        if self._git("rev-parse", "HEAD").decode().strip() != self.identity["base_sha"]:
            raise StateError("stale base")
        return self._artifact(item)

    @locked
    def adopt_checkpoint(self, repo):
        """Adopt an independently restored candidate without resetting the run ledger."""
        if self.data["active"] or self.data["publication"] or self.data["status"] == "waiting":
            raise StateError("run must be quiescent before checkpoint adoption")
        candidate = Path(repo).resolve()
        if candidate == self.repo or self.root.is_relative_to(candidate) or candidate.is_relative_to(self.root):
            raise StateError("checkpoint candidate must be separate from source and state")
        if encoded(self._snapshot(candidate)) != encoded(self.checkpoint()):
            raise StateError("restored candidate differs from validated checkpoint")
        self.data["candidate_repo"] = str(candidate)
        self.data["version"] = max(2, self.data["version"])
        self.data["status"] = "validated"
        self._event("checkpoint_adopted", artifact=self.data["checkpoint"]["sha256"])
        self._save()
        self.repo = candidate

    @locked
    def start_container_capture(self, name, image_id):
        active = self.data["active"]
        if not active or active["phase"] != "edit" or self.data.get("external_container"):
            raise StateError("unused edit reservation required")
        if not re.fullmatch(r"sdlc-boundary-[0-9a-f]{32}", name) or not re.fullmatch(r"sha256:[0-9a-f]{64}", image_id):
            raise StateError("invalid container identity")
        self.data["version"] = 3
        self.data["external_container"] = {"name": name, "image_id": image_id, "frames": 0, "receipt": None}
        self._event("container_intent", name=name)
        self._save()

    def _store_container_receipt(self, entries, frames, observation):
        container = self.data["external_container"]
        payload = {"schema": 1, "kind": "container-receipt", "identity": self.identity,
                   "step": self.data["active"]["step"], "attempt": self.data["active"]["attempt"],
                   "container": container["name"], "image_id": container["image_id"],
                   "frames": frames, "observation": observation, "entries": entries}
        raw = encoded(payload)
        if len(raw) > 2 * 1024 * 1024:
            raise StateError("receipt size limit exceeded")
        sha = digest(raw)
        item = {"name": f"artifact-{sha}.json", "sha256": sha, "trusted": False}
        atomic_write(self.path / item["name"], payload)
        self.data["artifacts"].append(item)
        container["receipt"] = item
        container["frames"] = frames
        self.data["last_container_receipt"] = item

    @locked
    def container_progress(self, entries, frames):
        container = self.data.get("external_container")
        if not container or type(frames) is not int or frames != container["frames"] + 1 or frames > 32:
            raise StateError("invalid container progress sequence")
        self._store_container_receipt(entries, frames, "streaming")
        self._save()

    @locked
    def finish_container_capture(self, observation):
        """Trusted observer calls only after verifying container removal."""
        container = self.data.get("external_container")
        if not container or observation not in {"exited", "failed", "timeout", "invalid", "cancelled", "interrupted"}:
            raise StateError("invalid container completion")
        entries = self._artifact(container["receipt"])["entries"] if container["receipt"] else []
        self._store_container_receipt(entries, container["frames"], observation)
        self._event("container_capture_finished", observation=observation,
                    charged_seconds=self.data["active"]["seconds"], name=container["name"])
        # No refund for container startup/cleanup or ambiguous elapsed execution.
        self.data["active"] = None
        self.data["external_container"] = None
        self.data["status"] = "untrusted"
        self._save()

    @locked
    def wait(self, seconds):
        if self.data["active"] or self.data["publication"] or self.data["status"] == "waiting":
            raise StateError("cannot enter wait")
        if type(seconds) is not int or seconds <= 0 or seconds > 180 or self.data["wait_count"] >= 2:
            raise StateError("wait budget exhausted")
        now = self.clock()
        self.data["wait_started"] = now if self.data["wait_started"] is None else self.data["wait_started"]
        if now - self.data["wait_started"] >= 86400:
            raise StateError("wait lifetime expired")
        self.data["wait_until"] = now + seconds
        self.data["wait_count"] += 1
        self.data["status"] = "waiting"
        self._event("waiting", seconds=seconds)
        self._save()

    @locked
    def release_wait(self):
        now = self.clock()
        if self.data["status"] != "waiting" or now < self.data["wait_until"]:
            raise StateError("wait not ready")
        if now - self.data["wait_started"] >= 86400:
            raise StateError("wait lifetime expired")
        self.data["wait_until"] = None
        self.data["status"] = "untrusted"
        self._event("wait_released")
        self._save()

    @locked
    def publication_intent(self, branch):
        if self.data["publication"] is not None:
            raise StateError("publication uncertain or complete; reconcile, never create again")
        if self.data["active"] or self.data["status"] != "validated":
            raise StateError("validated candidate required")
        candidate = self.checkpoint()
        if encoded(self._snapshot()) != encoded(candidate):
            raise StateError("candidate changed after validation")
        if not branch or not isinstance(branch, str):
            raise StateError("branch required")
        key = digest(encoded(self.identity))
        self.data["publication"] = {"key": key, "branch": branch, "artifact": self.data["checkpoint"]["sha256"], "pr": None}
        self.data["status"] = "publication_pending"
        self._event("publication_intent")
        self._save()
        return key

    @locked
    def reconcile_publication(self, key, branch, pr):
        current = self.data["publication"]
        if not current or current["key"] != key or current["branch"] != branch or type(pr) is not int or pr <= 0:
            raise StateError("publication identity mismatch")
        if current["pr"] is not None and current["pr"] != pr:
            raise StateError("conflicting publication")
        current["pr"] = pr
        self.data["status"] = "published"
        self._event("publication_reconciled", pr=pr)
        self._save()
