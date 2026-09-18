"""Candidate binding rejects stale, modified and out-of-scope evidence."""

from pathlib import Path
import subprocess
from unittest.mock import patch

from test_worker_container_receipts import LedgerFixture, frame
from container_receipts import ReceiptStream
from durable_run_state import StateError, digest, encoded
from receipt_candidate import materialize_receipt
from reputation_candidate_probe import CSS_PATH, TEMPLATE_PATH, SCOPE, Rows, probe_candidate

ROW = '''<li class="hub-list-item"><span>1</span><div class="hub-avatar">M</div><div class="hub-member">
{#if entry.profilePath}<a class="hub-member-link" title="{entry.displayName}">{entry.displayName}</a>
{#else}<span title="{entry.displayName}">{entry.displayName}</span>{/if}
</div><span class="hub-score">{i18n:reputation_hub_score(entry.score)}</span></li>'''


class CandidateFixture(LedgerFixture):
    def setUp(self):
        super().setUp()
        for name, text in ((CSS_PATH, 'body{}'), (TEMPLATE_PATH, ROW * 5),
                           ('quarkus-app/pom.xml', '<project><properties><quarkus.platform.version>3.26.4</quarkus.platform.version></properties></project>')):
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        subprocess.check_call(['git', '-C', str(self.repo), 'add', '.'], stdout=subprocess.DEVNULL)
        subprocess.check_call(['git', '-C', str(self.repo), 'commit', '-m', 'pilot'], stdout=subprocess.DEVNULL)
        self.identity['base_sha'] = subprocess.check_output(['git', '-C', str(self.repo), 'rev-parse', 'HEAD']).decode().strip()

    def candidate(self, run, css=b'body {margin: 0;}'):
        run.begin('edit', 3, 'pilot')
        run.start_container_capture('sdlc-boundary-' + 'a' * 32, 'sha256:' + 'a' * 64)
        ReceiptStream(SCOPE, run.container_progress).feed(frame(CSS_PATH, css))
        run.finish_container_capture('exited')
        return materialize_receipt(run, self.root / 'scratch', SCOPE)


class CandidateBindingTest(CandidateFixture):
    def test_evidence_binds_exact_files_without_advancing_ledger(self):
        with self.open() as run:
            report = self.candidate(run)
            before = encoded(run.data)
            with patch('reputation_candidate_probe.probe_qute_rows', return_value={'passed': False}) as browser:
                result = probe_candidate(run, report, 'sha256:' + 'a' * 64)
            self.assertEqual(browser.call_args.args[1], [ROW] * 5)
            self.assertEqual(result['snapshot_sha256'], report['snapshot_sha256'])
            self.assertEqual(result['acceptance'], 'component-only')
            self.assertEqual(encoded(run.data), before)
            self.assertEqual(len(list(run.path.glob('observation-*.json'))), 1)

    def test_changed_candidate_and_report_identity_fail_before_browser(self):
        with self.open() as run:
            report = self.candidate(run)
            with patch('reputation_candidate_probe.probe_qute_rows') as browser:
                with self.assertRaises(StateError):
                    probe_candidate(run, dict(report, identity={}), 'sha256:' + 'a' * 64)
                (Path(report['candidate']) / CSS_PATH).write_text('changed')
                with self.assertRaises(StateError):
                    probe_candidate(run, report, 'sha256:' + 'a' * 64)
                browser.assert_not_called()

    def test_forged_snapshot_cannot_hide_unrelated_changes(self):
        with self.open() as run:
            report = self.candidate(run)
            (Path(report['candidate']) / 'baseline').write_text('unapproved')
            report['snapshot_sha256'] = digest(encoded(run._snapshot(report['candidate'])))
            with self.assertRaises(StateError):
                probe_candidate(run, report, 'sha256:' + 'a' * 64)

    def test_mutation_during_browser_run_discards_evidence(self):
        with self.open() as run:
            report = self.candidate(run)
            def mutate(*_):
                (Path(report['candidate']) / CSS_PATH).write_text('changed')
                return {'passed': True}
            with patch('reputation_candidate_probe.probe_qute_rows', side_effect=mutate):
                with self.assertRaises(StateError):
                    probe_candidate(run, report, 'sha256:' + 'a' * 64)
            self.assertFalse(list(run.path.glob('observation-*.json')))

    def test_missing_unbalanced_or_extra_rows_are_not_silently_accepted(self):
        for source in ('', ROW * 4, ROW * 6, ROW * 4 + '<li class="hub-list-item"><div></li>'):
            with self.subTest(source=source[:30]), self.assertRaises(StateError):
                Rows(source)

    def test_incompatible_quarkus_base_is_not_observed(self):
        (self.repo / 'quarkus-app/pom.xml').write_text('<project><properties><quarkus.platform.version>3.27.0</quarkus.platform.version></properties></project>')
        subprocess.check_call(['git', '-C', str(self.repo), 'add', '.'], stdout=subprocess.DEVNULL)
        subprocess.check_call(['git', '-C', str(self.repo), 'commit', '-m', 'other version'], stdout=subprocess.DEVNULL)
        self.identity['base_sha'] = subprocess.check_output(['git', '-C', str(self.repo), 'rev-parse', 'HEAD']).decode().strip()
        with self.open() as run:
            report = self.candidate(run)
            with patch('reputation_candidate_probe.probe_qute_rows') as browser:
                with self.assertRaises(StateError):
                    probe_candidate(run, report, 'sha256:' + 'a' * 64)
                browser.assert_not_called()
