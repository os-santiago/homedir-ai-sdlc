"""Offline browser observation of rendered HTML; does not authorize publication."""

import json
import re
import subprocess
import uuid

from container_boundary import runtime_environment
from container_receipts import reconcile_container
from durable_run_state import StateError, digest, encoded


def browser_boundary(image_id):
    if not isinstance(image_id, str) or not re.fullmatch(r'sha256:[0-9a-f]{64}', image_id):
        raise StateError('preloaded reviewed validator image required')
    name = 'sdlc-boundary-' + uuid.uuid4().hex
    argv = ['podman', '--remote=false', 'run', '--interactive', '--name', name,
            '--label', 'io.os-santiago.sdlc=boundary-qualification',
            '--pull=never', '--network=none', '--pid=private', '--ipc=private', '--uts=private',
            '--cgroupns=private', '--cgroups=enabled', '--user=10000:10000',
            '--cap-drop=ALL', '--security-opt=no-new-privileges',
            '--read-only', '--read-only-tmpfs=false', '--unsetenv-all',
            '--env=PATH=/usr/local/bin:/usr/bin:/bin', '--env=HOME=/home/runner',
            '--env=LANG=C.UTF-8', '--env=PLAYWRIGHT_BROWSERS_PATH=/ms-playwright',
            '--memory=512m', '--memory-swap=512m', '--cpus=1', '--pids-limit=128',
            '--ulimit=nofile=1024:1024', '--ulimit=fsize=8388608:8388608',
            '--tmpfs=/tmp:rw,noexec,nosuid,nodev,size=128m,mode=1777',
            '--tmpfs=/home/runner:rw,noexec,nosuid,nodev,size=16m,mode=1777',
            '--shm-size=128m', '--log-driver=none', '--timeout=30',
            '--entrypoint=node', image_id, '/opt/validator/check.cjs']
    return name, argv


def probe_rendered_page(image_id, html, css):
    """Only trusted orchestration invokes this with an already rendered page.

    No candidate code, mounts, credentials, network or arbitrary test argv.
    HTML/CSS are data; page scripts are disabled. The outer non-privileged
    container is the process boundary; Chromium's user-namespace sandbox is
    unavailable on the current WSL Podman profile and is disabled explicitly.
    This component probe cannot prove Qute compilation or deployed revision.
    """
    if not isinstance(html, str) or not isinstance(css, str):
        raise StateError('HTML and CSS strings required')
    payload = encoded({'html': html, 'css': css})
    if len(payload) > 1024 * 1024:
        raise StateError('browser input limit exceeded')
    name, argv = browser_boundary(image_id)
    process = None
    try:
        process = subprocess.Popen(argv, env=runtime_environment(), stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        output, _ = process.communicate(payload, timeout=35)
        if len(output) > 128 * 1024:
            raise StateError('browser report limit exceeded')
        result = json.loads(output)
        if (process.returncode not in (0, 1) or result.get('schema') != 1 or
                result.get('validator') != 'reputation-hub-layout-v1' or
                result.get('input_sha256') != digest(payload) or
                type(result.get('passed')) is not bool or
                result['passed'] != (process.returncode == 0)):
            raise StateError('browser did not return valid observation evidence')
        return dict(result, image_id=image_id, acceptance='component-only')
    except (subprocess.TimeoutExpired, ValueError) as exc:
        raise StateError('browser probe failed or exceeded its deadline') from exc
    finally:
        # Remove the owned container even on parser, transport or deadline errors.
        try:
            reconcile_container(name)
        finally:
            if process is not None:
                if process.poll() is None:
                    process.kill()
                process.communicate(timeout=3)
