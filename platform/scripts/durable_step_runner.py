"""Offline Linux supervisor for trusted commands; no production execution route."""

import base64
import json
import os
from pathlib import Path, PurePosixPath
import signal
import subprocess
import sys
import tempfile
import time

from durable_run_state import StateError, atomic_write, encoded


def fixture_environment(home):
    # Deliberately do not inherit host credentials, Git config or language hooks.
    return {"PATH": "/usr/bin:/bin", "HOME": str(home), "LANG": "C.UTF-8",
            "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_TERMINAL_PROMPT": "0", "GIT_LFS_SKIP_SMUDGE": "1"}


def stop_group(process):
    """Terminate descendants even if their direct parent already exited."""
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    time.sleep(0.1)
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait(timeout=2)
    deadline = time.monotonic() + 2
    while True:
        live = False
        for entry in Path("/proc").iterdir():
            if not entry.name.isdigit():
                continue
            try:
                fields = (entry / "stat").read_text().rsplit(")", 1)[1].split()
            except FileNotFoundError:
                continue
            if fields[2] == str(process.pid) and fields[0] not in ("Z", "X"):
                live = True
                break
        if not live:
            return
        if time.monotonic() >= deadline:
            raise StateError("process group did not quiesce")
        time.sleep(0.02)


def guard(spec_path, result_path, lock_fd):
    """Retain the inherited writer lock and deadline if the caller crashes."""
    spec = json.loads(Path(spec_path).read_text())
    cancelled = False

    def cancel(_signum, _frame):
        nonlocal cancelled
        cancelled = True

    signal.signal(signal.SIGTERM, cancel)
    signal.signal(signal.SIGINT, cancel)
    started = time.monotonic()
    process = None
    outcome, returncode = "failure", None
    try:
        if started >= spec["deadline"]:
            outcome = "timeout"
        elif cancelled:
            outcome = "cancelled"
        else:
            process = subprocess.Popen(spec["argv"], cwd=spec["repo"],
                                       env=fixture_environment(spec["home"]),
                                       stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                       stderr=subprocess.DEVNULL, start_new_session=True,
                                       pass_fds=(lock_fd,))
            while True:
                if cancelled:
                    outcome = "cancelled"
                    break
                if time.monotonic() >= spec["deadline"]:
                    outcome = "timeout"
                    break
                returncode = process.poll()
                if returncode is not None:
                    outcome = "success" if returncode == 0 else "failure"
                    break
                time.sleep(0.02)
    except OSError:
        outcome = "failure"
    finally:
        if process is not None:
            stop_group(process)
        atomic_write(Path(result_path), {"outcome": outcome, "returncode": returncode,
                                         "elapsed": time.monotonic() - started})


def execute_step(run, phase, seconds, step_id, argv, cancelled=lambda: False):
    """Run an operator-authored fixture argv; not issue/model-supplied shell text."""
    if not isinstance(argv, list) or not argv or any(not isinstance(arg, str) or "\0" in arg for arg in argv):
        raise StateError("trusted argv required")
    run.begin(phase, seconds, step_id)
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix="supervisor-", dir=run.path) as directory:
        private = Path(directory)
        home = private / "home"
        home.mkdir(mode=0o700)
        spec, result = private / "spec.json", private / "result.json"
        atomic_write(spec, {"argv": argv, "repo": str(run.repo), "home": str(home), "deadline": started + seconds})
        watchdog = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--guard",
                                     str(spec), str(result), str(run.lock.fileno())],
                                    env=fixture_environment(home), stdin=subprocess.DEVNULL,
                                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                    start_new_session=True, pass_fds=(run.lock.fileno(),))
        cancellation_sent = False
        try:
            while watchdog.poll() is None:
                if not cancellation_sent and cancelled():
                    watchdog.send_signal(signal.SIGTERM)
                    cancellation_sent = True
                if time.monotonic() > started + seconds + 5:
                    raise StateError("watchdog exceeded cleanup allowance; reconcile before recovery")
                time.sleep(0.02)
        except BaseException:
            watchdog.send_signal(signal.SIGTERM)
            watchdog.wait(timeout=5)
            # A caller cancellation still preserves evidence when cleanup succeeds.
            if result.exists() and watchdog.returncode == 0:
                run.finish("cancelled", min(seconds, time.monotonic() - started))
            raise
        if watchdog.returncode != 0 or not result.exists():
            raise StateError(f"watchdog failed (exit {watchdog.returncode}); reservation retained for reconciliation")
        report = json.loads(result.read_text())
        run.finish(report["outcome"], min(seconds, time.monotonic() - started))
        return report


def restore_checkpoint(run, scratch_root):
    """Create a fresh candidate, verify exact content, then retain the same budget ledger."""
    if run.data["active"] or run.data["publication"] or run.data["status"] == "waiting":
        raise StateError("run must be quiescent before restoration")
    snapshot = run.checkpoint()
    root = Path(scratch_root).resolve()
    if root.is_relative_to(run.repo) or root.is_relative_to(run.root):
        raise StateError("scratch root must be outside source and state")
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    if root.stat().st_mode & 0o077:
        raise StateError("scratch root must be private (0700)")
    patch = base64.b64decode(snapshot["patch"], validate=True)
    untracked = []
    for item in snapshot["untracked"]:
        path = PurePosixPath(item["path"])
        if (path.is_absolute() or not path.parts or ".." in path.parts
                or any(part.lower() == ".git" for part in path.parts) or "\\" in item["path"]):
            raise StateError("unsafe artifact path")
        mode = item["mode"]
        if type(mode) is not int or mode < 0 or mode > 0o777:
            raise StateError("unsupported artifact mode")
        untracked.append((path, mode, base64.b64decode(item["content"], validate=True)))
    target = Path(tempfile.mkdtemp(prefix="checkpoint-", dir=root))
    home = Path(tempfile.mkdtemp(prefix="git-home-", dir=root))
    environment = fixture_environment(home)

    def git(*args, data=None):
        result = subprocess.run(["git", "-c", "core.hooksPath=/dev/null", *args], input=data,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                env=environment, timeout=30)
        if result.returncode:
            raise StateError(f"checkpoint restoration failed; retained candidate: {target}")

    git("clone", "--no-hardlinks", "--no-checkout", "--", str(run.repo), str(target))
    git("-C", str(target), "checkout", "--detach", snapshot["base_sha"])
    if patch:
        git("-C", str(target), "apply", "--check", "--binary", "-", data=patch)
        git("-C", str(target), "apply", "--binary", "-", data=patch)
    for relative, mode, content in untracked:
        path = target.joinpath(*relative.parts)
        parent = target
        for part in relative.parts[:-1]:
            parent = parent / part
            if parent.is_symlink():
                raise StateError("artifact collides with symlink; candidate retained")
            parent.mkdir(exist_ok=True)
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, "wb") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), mode)
    if encoded(run._snapshot(target)) != encoded(snapshot):
        raise StateError("restored candidate differs; source and candidate retained")
    run.adopt_checkpoint(target)
    return target


if __name__ == "__main__":
    if len(sys.argv) != 5 or sys.argv[1] != "--guard":
        raise SystemExit("Internal offline watchdog; use the trusted Python API")
    guard(sys.argv[2], sys.argv[3], int(sys.argv[4]))
