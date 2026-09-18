"""Materialize a recorded proposal for inspection; never validate or publish it."""

import base64
import os
from pathlib import Path
import stat
import subprocess
import tempfile

from container_receipts import ReceiptStream
from durable_run_state import StateError, atomic_write, digest, encoded, locked
from durable_step_runner import fixture_environment


@locked
def materialize_receipt(run, scratch_root, allowed_paths):
    """Trusted caller supplies exact scope from policy, never from model output.

    The first-step lane starts at the immutable base, not a previous proposal.
    Returned evidence means only that application succeeded, not acceptance.
    """
    if (run.data['active'] or run.data.get('external_container') or
            run.data['publication'] or run.data['status'] == 'waiting'):
        raise StateError('run must be quiescent')
    item = run.data.get('last_container_receipt')
    if not item:
        raise StateError('recorded receipt required')
    receipt = run._artifact(item)
    if (receipt.get('schema') != 1 or receipt.get('kind') != 'container-receipt' or
            receipt.get('identity') != run.identity or
            receipt.get('observation') == 'streaming'):
        raise StateError('completed receipt with matching identity required')
    entries = receipt.get('entries')
    if not isinstance(entries, list) or not entries:
        raise StateError('nonempty proposal required')
    parser = ReceiptStream(allowed_paths, lambda *_: None)
    seen = set()
    for entry in entries:
        parser.feed(encoded(entry) + b'\n')
        if entry['path'] in seen:
            raise StateError('duplicate final path')
        seen.add(entry['path'])
    parser.end()
    root = Path(scratch_root)
    if root.is_symlink():
        raise StateError('scratch cannot be a symlink')
    root = root.resolve()
    if any(root.is_relative_to(p) or p.is_relative_to(root) for p in (run.repo, run.root)):
        raise StateError('scratch must be separate from repository and state')
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    if root.stat().st_mode & 0o077:
        raise StateError('scratch must be private (0700)')
    target = Path(tempfile.mkdtemp(prefix='proposal-', dir=root))
    home = Path(tempfile.mkdtemp(prefix='git-home-', dir=root))
    environment = fixture_environment(home)

    def git(*args):
        result = subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', *args],
                                env=environment, capture_output=True, timeout=30)
        if result.returncode:
            raise StateError(f'candidate operation failed; retained at {target}')
        return result.stdout

    git('clone', '--no-hardlinks', '--no-checkout', '--', str(run.repo), str(target))
    git('-C', str(target), 'checkout', '--detach', run.identity['base_sha'])
    # Remove the source remote so inspection tooling cannot accidentally push.
    git('-C', str(target), 'remote', 'remove', 'origin')
    # Check every destination before applying any entry. Never follow symlinks,
    # replace directories, or traverse a submodule in the recorded base tree.
    for entry in entries:
        path = target / entry['path']
        cursor = target
        for part in Path(entry['path']).parts:
            cursor = cursor / part
            tree = git('-C', str(target), 'ls-tree', 'HEAD', '--', cursor.relative_to(target).as_posix())
            if tree.startswith((b'120000 ', b'160000 ')):
                raise StateError('proposal traverses a symlink or submodule')
            if cursor.is_symlink():
                raise StateError('proposal collides with a symlink')
            if cursor.exists() and cursor != path and not cursor.is_dir():
                raise StateError('proposal parent is not a directory')
        tracked = git('-C', str(target), 'ls-files', '--stage', '--', entry['path'])
        if tracked and not tracked.startswith((b'100644 ', b'100755 ')):
            raise StateError('proposal destination is not a regular tracked file')
        if path.exists() and not stat.S_ISREG(path.lstat().st_mode):
            raise StateError('proposal destination is not a regular file')
        if entry.get('delete') and not path.is_file():
            raise StateError('deletion requires an existing regular file')
    for entry in entries:
        path = target / entry['path']
        if entry.get('delete'):
            path.unlink()
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
            with os.fdopen(fd, 'wb') as stream:
                stream.write(base64.b64decode(entry['content'], validate=True))
                stream.flush()
                os.fsync(stream.fileno())
                os.fchmod(stream.fileno(), entry['mode'])
    snapshot = run._snapshot(target)
    if not snapshot['patch'] and not snapshot['untracked']:
        raise StateError('proposal has no change')
    snapshot_sha = digest(encoded(snapshot))
    report = {'schema': 1, 'kind': 'untrusted-candidate', 'identity': run.identity,
              'receipt_sha256': item['sha256'], 'snapshot_sha256': snapshot_sha,
              'candidate': str(target), 'allowed_paths': sorted(parser.allowed),
              'observation': receipt['observation'], 'acceptance': 'not-run'}
    atomic_write(target.parent / (target.name + '.evidence.json'), report)
    # No adoption, checkpoint, budget refund or publication transition here.
    return report
