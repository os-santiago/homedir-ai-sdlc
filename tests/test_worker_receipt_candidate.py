"""Receipt-to-checkout integration against real Git repositories."""

import subprocess
from pathlib import Path

from test_worker_container_receipts import LedgerFixture, frame
from container_receipts import ProtocolError, ReceiptStream
from durable_run_state import StateError, encoded
from receipt_candidate import materialize_receipt


class CandidateTest(LedgerFixture):
    def capture(self, run, wire=None, paths=None, observation='exited'):
        run.begin('edit', 3, 'edit')
        run.start_container_capture('sdlc-boundary-' + 'a' * 32, 'sha256:' + 'a' * 64)
        ReceiptStream(paths or ['baseline'], run.container_progress).feed(wire or frame('baseline', b'changed'))
        run.finish_container_capture(observation)

    def test_materializes_without_modifying_source_state_or_budget(self):
        with self.open() as run:
            self.capture(run)
            before = encoded(run.data)
            report = materialize_receipt(run, self.root / 'scratch', ['baseline'])
            candidate = Path(report['candidate'])
            self.assertEqual((candidate / 'baseline').read_bytes(), b'changed')
            self.assertEqual((self.repo / 'baseline').read_text(), 'unchanged')
            self.assertEqual(before, encoded(run.data))
            self.assertEqual(report['acceptance'], 'not-run')
            self.assertEqual(subprocess.check_output(['git', '-C', str(candidate), 'remote']), b'')
            with self.assertRaises(StateError):
                run.publication_intent('should-not-publish')

    def test_partial_failed_receipt_is_explicitly_untrusted(self):
        with self.open() as run:
            self.capture(run, observation='timeout')
            report = materialize_receipt(run, self.root / 'scratch', ['baseline'])
            self.assertEqual(report['observation'], 'timeout')
            self.assertEqual(report['acceptance'], 'not-run')

    def test_scope_is_rechecked_before_application(self):
        with self.open() as run:
            self.capture(run)
            with self.assertRaises(ProtocolError):
                materialize_receipt(run, self.root / 'scratch', ['other'])
            self.assertFalse((self.root / 'scratch').exists())

    def test_deletion_and_binary_addition(self):
        wire = b'{"path":"baseline","delete":true}\n' + frame('new/file.bin', b'\x00\xff')
        with self.open() as run:
            self.capture(run, wire, ['baseline', 'new/file.bin'])
            report = materialize_receipt(run, self.root / 'scratch', ['baseline', 'new/file.bin'])
            candidate = Path(report['candidate'])
            self.assertFalse((candidate / 'baseline').exists())
            self.assertEqual((candidate / 'new/file.bin').read_bytes(), b'\x00\xff')

    def test_noop_and_dirty_source_do_not_contaminate_candidate(self):
        (self.repo / 'unrelated').write_text('private local work')
        (self.repo / 'baseline').write_text('local work')
        with self.open() as run:
            self.capture(run, frame('baseline', b'unchanged'))
            with self.assertRaises(StateError):
                materialize_receipt(run, self.root / 'scratch', ['baseline'])
            self.assertEqual((self.repo / 'baseline').read_text(), 'local work')

    def test_unresolved_capture_blocks_materialization(self):
        with self.open() as run:
            self.capture(run)
            run.begin('edit', 3, 'next')
            with self.assertRaises(StateError):
                materialize_receipt(run, self.root / 'scratch', ['baseline'])

    def test_symlink_and_submodule_ancestors_are_rejected(self):
        (self.repo / 'link').symlink_to(self.root, target_is_directory=True)
        subprocess.check_call(['git', '-C', str(self.repo), 'add', 'link'], stdout=subprocess.DEVNULL)
        subprocess.check_call(['git', '-C', str(self.repo), 'update-index', '--add', '--cacheinfo',
                               '160000,' + self.identity['base_sha'] + ',module'], stdout=subprocess.DEVNULL)
        subprocess.check_call(['git', '-C', str(self.repo), 'commit', '-m', 'special paths'], stdout=subprocess.DEVNULL)
        self.identity['base_sha'] = subprocess.check_output(['git', '-C', str(self.repo), 'rev-parse', 'HEAD']).decode().strip()
        with self.open() as run:
            for path in ['link/escape', 'module/escape']:
                self.capture(run, frame(path), [path])
                with self.assertRaises(StateError):
                    materialize_receipt(run, self.root / 'scratch', [path])
                self.assertFalse((self.root / 'escape').exists())

    def test_receipt_corruption_and_unsafe_scratch_are_rejected(self):
        with self.open() as run:
            self.capture(run)
            with self.assertRaises(StateError):
                materialize_receipt(run, self.repo / 'scratch', ['baseline'])
            artifact = run.path / run.data['last_container_receipt']['name']
            artifact.write_text('{}')
            with self.assertRaises(StateError):
                materialize_receipt(run, self.root / 'scratch', ['baseline'])

    def test_missing_deletion_and_directory_replacement_fail(self):
        with self.open() as run:
            self.capture(run, b'{"path":"absent","delete":true}\n', ['absent'])
            with self.assertRaises(StateError):
                materialize_receipt(run, self.root / 'scratch', ['absent'])
        (self.repo / 'directory').mkdir()
        (self.repo / 'directory/file').write_text('keep')
        subprocess.check_call(['git', '-C', str(self.repo), 'add', '.'], stdout=subprocess.DEVNULL)
        subprocess.check_call(['git', '-C', str(self.repo), 'commit', '-m', 'directory'], stdout=subprocess.DEVNULL)
        self.identity['base_sha'] = subprocess.check_output(['git', '-C', str(self.repo), 'rev-parse', 'HEAD']).decode().strip()
        from durable_run_state import RunState
        with RunState(self.root / 'state2', 'run', self.repo, self.identity) as run:
            self.capture(run, frame('directory'), ['directory'])
            with self.assertRaises(StateError):
                materialize_receipt(run, self.root / 'scratch', ['directory'])

    def test_changed_identity_is_not_applied(self):
        with self.open() as run:
            self.capture(run)
            run.identity = dict(run.identity, plan_version='different')
            with self.assertRaises(StateError):
                materialize_receipt(run, self.root / 'scratch', ['baseline'])
