"""Closed Podman profile for qualification fixtures, not a production executor."""

from dataclasses import dataclass
import os
from pathlib import Path
import re
import uuid


@dataclass(frozen=True)
class Boundary:
    name: str
    argv: tuple[str, ...]


def runtime_environment():
    """Host runtime configuration only; no forwarding of caller credentials."""
    result = {"PATH": "/usr/sbin:/usr/bin:/sbin:/bin", "HOME": str(Path.home()), "LANG": "C.UTF-8"}
    if "XDG_RUNTIME_DIR" in os.environ:
        result["XDG_RUNTIME_DIR"] = os.environ["XDG_RUNTIME_DIR"]
    return result


def qualification_boundary(image_id, fixture, seconds=10):
    """Accept an operator-reviewed Python fixture and a preloaded immutable image.

    There is deliberately no extra-options, bind-directory, credentials, network
    or generated-command argument. Fixture images must provide /usr/local/bin/python3.
    """
    if not isinstance(image_id, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", image_id):
        raise ValueError("preloaded immutable image ID required")
    if type(seconds) is not int or not 1 <= seconds <= 60:
        raise ValueError("fixture deadline must be between 1 and 60 seconds")
    path = Path(fixture).absolute()
    if path.suffix != ".py" or any(part in {".git", ".ssh", ".config", ".aws", ".azure"} for part in path.parts):
        raise ValueError("reviewed Python fixture outside credential/metadata directories required")
    if any(char in str(path) for char in (":", "\n", "\r", "\0")):
        raise ValueError("unsupported mount path")
    if any(part.is_symlink() for part in (path, *path.parents)) or not path.is_file():
        raise ValueError("fixture must be a regular file without symlink traversal")
    if path.stat().st_size > 64 * 1024:
        raise ValueError("fixture exceeds qualification limit")
    name = "sdlc-boundary-" + uuid.uuid4().hex
    options = (
        "podman", "--remote=false", "run", "--name", name,
        "--label", "io.os-santiago.sdlc=boundary-qualification",
        "--pull=never", "--network=none", "--pid=private", "--ipc=private", "--uts=private",
        "--cgroupns=private", "--cgroups=enabled", "--user=10000:10000",
        "--cap-drop=ALL", "--security-opt=no-new-privileges",
        "--read-only", "--read-only-tmpfs=false", "--unsetenv-all",
        "--env=PATH=/usr/local/bin:/usr/bin:/bin", "--env=HOME=/home/runner", "--env=LANG=C.UTF-8",
        "--memory=128m", "--memory-swap=128m", "--cpus=0.5", "--pids-limit=16",
        "--ulimit=nofile=64:64", "--ulimit=fsize=8388608:8388608",
        "--tmpfs=/tmp:rw,noexec,nosuid,nodev,size=16m,mode=1777",
        "--tmpfs=/home/runner:rw,noexec,nosuid,nodev,size=8m,mode=1777",
        "--tmpfs=/workspace:rw,noexec,nosuid,nodev,size=32m,mode=1777",
        "--volume", f"{path}:/fixture.py:ro,Z", "--workdir=/workspace",
        "--log-driver=none", f"--timeout={seconds}",
        "--entrypoint=/usr/local/bin/python3", image_id, "/fixture.py",
    )
    return Boundary(name, options)
