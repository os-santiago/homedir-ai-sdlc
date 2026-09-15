"""Explicit opt-in probes against a real local Podman/cgroups-v2 runtime."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "platform/scripts"))
from container_boundary import qualification_boundary, runtime_environment

IMAGE = os.environ.get("SDLC_BOUNDARY_TEST_IMAGE")


@unittest.skipUnless(IMAGE, "set SDLC_BOUNDARY_TEST_IMAGE to a preloaded immutable image ID")
class BoundaryIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.environment = runtime_environment()
        result = subprocess.run(["podman", "--remote=false", "info", "--format", "{{.Host.CgroupsVersion}}"],
                                env=cls.environment, capture_output=True, text=True, timeout=20)
        if result.returncode != 0 or result.stdout.strip() != "v2":
            raise RuntimeError("a working local Podman cgroups-v2 runtime is required; no weakened fallback")

    def probe(self, script, seconds=10):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "fixture.py"
            fixture.write_text(script)
            fixture.chmod(0o444)
            boundary = qualification_boundary(IMAGE, fixture, seconds)
            def podman(*args):
                return subprocess.run(["podman", "--remote=false", *args], env=self.environment,
                                      capture_output=True, text=True, timeout=20)
            try:
                result = subprocess.run(boundary.argv, env=self.environment, capture_output=True,
                                        text=True, timeout=seconds + 15)
                inspected = podman("inspect", boundary.name)
                self.assertEqual(inspected.returncode, 0, result.stderr + inspected.stderr)
                state = json.loads(inspected.stdout)[0]["State"]
                self.assertFalse(state["Running"], "container must be stopped before accepting results")
                return result, state
            finally:
                removed = podman("rm", "--force", "--time", "0", boundary.name)
                self.assertEqual(removed.returncode, 0, removed.stderr)
                self.assertEqual(podman("container", "exists", boundary.name).returncode, 1)

    def test_identity_capabilities_mounts_and_effective_limits(self):
        result, _ = self.probe('''import json, os, resource
from pathlib import Path
status = dict(line.split(":", 1) for line in Path("/proc/self/status").read_text().splitlines() if ":" in line)
assert os.getuid() == 10000 and os.getgid() == 10000
assert int(status["CapEff"].strip(), 16) == 0
assert status["NoNewPrivs"].strip() == "1"
try:
    os.setuid(0)
except PermissionError:
    pass
else:
    raise AssertionError("privilege escalation succeeded")
assert Path("/sys/fs/cgroup/memory.max").read_text().strip() == "134217728"
assert Path("/sys/fs/cgroup/pids.max").read_text().strip() == "16"
quota, period = map(int, Path("/sys/fs/cgroup/cpu.max").read_text().split())
assert quota / period == 0.5
assert resource.getrlimit(resource.RLIMIT_NOFILE) == (64, 64)
assert resource.getrlimit(resource.RLIMIT_FSIZE) == (8388608, 8388608)
assert not any(key in os.environ for key in ("GH_TOKEN", "NVIDIA_API_KEY", "SC_API_KEY", "CONTAINER_HOST", "PYTHON_VERSION"))
for path in ("/root/.ssh", "/root/.config/gh", "/var/run/docker.sock", "/run/podman/podman.sock", "/var/lib/homedir-sdlc", "/workspace/.git"):
    assert not os.path.lexists(path), path
Path("/workspace/allowed").write_text("ok")
print("boundary-ok")
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("boundary-ok", result.stdout)

    def test_outside_and_fixture_writes_are_denied(self):
        result, _ = self.probe('''from pathlib import Path
for name in ("/outside", "/etc/passwd", "/fixture.py"):
    try:
        with open(name, "a") as stream:
            stream.write("forbidden")
    except OSError:
        pass
    else:
        raise AssertionError(name)
print("writes-denied")
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_network_and_unbounded_tmpfs_writes_are_denied(self):
        result, _ = self.probe('''import errno, socket
from pathlib import Path
assert sorted(path.name for path in Path("/sys/class/net").iterdir()) == ["lo"]
try:
    socket.create_connection(("198.51.100.1", 80), timeout=0.2)
except OSError:
    pass
else:
    raise AssertionError("network escaped")
try:
    for index in range(8):
        with open(f"/tmp/fill-{index}", "wb") as stream:
            for _ in range(4):
                stream.write(b"x" * 1048576)
except OSError as exc:
    assert exc.errno == errno.ENOSPC
else:
    raise AssertionError("tmpfs limit not enforced")
print("limits-enforced")
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_memory_exhaustion_is_confined_to_container(self):
        result, _ = self.probe('''import subprocess, sys
from pathlib import Path
def oom_kills():
    events = dict(line.split() for line in Path("/sys/fs/cgroup/memory.events").read_text().splitlines())
    return int(events["oom_kill"])
before = oom_kills()
child = subprocess.run([sys.executable, "-c", "data = bytearray(256 * 1024 * 1024)"], timeout=5)
assert child.returncode != 0, child.returncode
assert oom_kills() > before, "kernel did not record a cgroup OOM kill"
print("oom-confined")
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("oom-confined", result.stdout)

    def test_pid_limit_rejects_excess_children(self):
        result, _ = self.probe('''import errno, os, time
children = []
try:
    try:
        for _ in range(32):
            pid = os.fork()
            if pid == 0:
                time.sleep(2)
                os._exit(0)
            children.append(pid)
    except OSError as exc:
        assert exc.errno == errno.EAGAIN
        assert 0 < len(children) < 32
    else:
        raise AssertionError("PID limit not enforced")
finally:
    for pid in children:
        os.waitpid(pid, 0)
print("pid-limit-enforced")
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_runtime_timeout_stops_session_escaping_descendant(self):
        result, state = self.probe('''import os, time
child = os.fork()
if child == 0:
    os.setsid()
while True:
    time.sleep(1)
''', seconds=2)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(state["Running"])
        self.assertEqual(state["Pid"], 0)


if __name__ == "__main__":
    unittest.main()
