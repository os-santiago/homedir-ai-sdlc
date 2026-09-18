"""Real browser positive/negative controls; no external site or model access."""

import os
import json
import subprocess
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'platform/scripts'))
from reputation_layout_probe import browser_boundary, probe_rendered_page
from container_boundary import runtime_environment
from container_receipts import reconcile_container
from test_worker_reputation_candidate import CandidateFixture, ROW
from reputation_candidate_probe import probe_candidate
from reputation_layout_probe import probe_qute_rows
from durable_run_state import StateError
from durable_run_state import digest
from scoped_proposal_runner import generate_proposal
from receipt_candidate import materialize_receipt
from reputation_candidate_probe import CSS_PATH, SCOPE

IMAGE = os.environ.get('SDLC_BROWSER_TEST_IMAGE')
HTML = '''<!doctype html><html><body><main>
<section><h2>Puntaje</h2><ol class="hub-list"><li class="hub-list-item">
<span>1</span><div class="hub-avatar">M</div>
<div class="hub-member"><a class="hub-member-link" title="Member">Member</a></div>
<span class="hub-score">30 pts</span></li></ol></section>
<section><h2>Crecimiento</h2><ol class="hub-list"><li class="hub-list-item">
<span>1</span><div class="hub-avatar">M</div>
<div class="hub-member"><span title="Member">Member</span></div>
<span class="hub-score">+26</span></li></ol></section>
</main></body></html>'''
CSS = '''body { margin:16px; font:16px Arial; }
.hub-list { padding:0; list-style:none; }
.hub-list-item { display:grid; grid-template-columns:auto auto minmax(0,1fr) auto; gap:8px; }
.hub-member { display:grid; min-width:0; }
.hub-member > * { min-width:0; max-width:100%; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.hub-score { white-space:nowrap; }
@media(max-width:600px) { .hub-avatar {display:none} .hub-list-item {grid-template-columns:auto minmax(0,1fr) auto;} }
'''


@unittest.skipUnless(IMAGE, 'set SDLC_BROWSER_TEST_IMAGE to the reviewed immutable validator image')
class CandidateQuteIntegrationTest(CandidateFixture):
    def test_scoped_provider_fixture_reaches_real_qute_and_browser(self):
        self.identity['requirement_hash'] = digest(b'fixture layout requirement')
        content = json.dumps({'edits': [{'path': CSS_PATH, 'old': 'body{}', 'new': CSS, 'count': 1}]})
        with self.open() as run:
            result = generate_proposal(run, 'fixture layout requirement', {CSS_PATH: 'body{}'}, {},
                                       lambda *_: {'outcome': 'proposal', 'content': content}, seconds=1)
            self.assertEqual(result['observation'], 'proposal')
            report = materialize_receipt(run, self.root / 'scratch', SCOPE)
            evidence = probe_candidate(run, report, IMAGE)
            self.assertTrue(evidence['result']['passed'], evidence)
            self.assertEqual(run.data['version'], 4)
            self.assertIsNone(run.data['checkpoint'])

    def test_receipt_to_candidate_to_qute_to_browser_retains_untrusted_state(self):
        with self.open() as run:
            report = self.candidate(run, CSS.encode())
            evidence = probe_candidate(run, report, IMAGE)
            self.assertTrue(evidence['result']['passed'], evidence)
            self.assertEqual(evidence['row_templates'], 5)
            self.assertEqual(evidence['snapshot_sha256'], report['snapshot_sha256'])
            self.assertEqual(run.data['status'], 'untrusted')
            self.assertIsNone(run.data['checkpoint'])

    def test_qute_fallback_tooltip_and_invalid_expression_are_rejected(self):
        missing = ROW.replace('<span title="{entry.displayName}">', '<span>')
        self.assertFalse(probe_qute_rows(IMAGE, [missing], CSS)['passed'])
        with self.assertRaises(StateError):
            probe_qute_rows(IMAGE, [ROW.replace('entry.displayName', 'missing.value')], CSS)
        with self.assertRaises(StateError):
            probe_qute_rows(IMAGE, [ROW.replace('entry.displayName', 'entry.displayName.getClass()')], CSS)


@unittest.skipUnless(IMAGE, 'set SDLC_BROWSER_TEST_IMAGE to the reviewed immutable validator image')
class ReputationLayoutIntegrationTest(unittest.TestCase):
    def test_outer_process_still_has_no_capabilities_or_chroot_authority(self):
        name, argv = browser_boundary(IMAGE)
        script = '''const fs = require('node:fs');
const cp = require('node:child_process');
const binary = ['/usr/sbin/chroot', '/usr/bin/chroot'].find(p => fs.existsSync(p));
if (!binary) process.exit(2);
const result = cp.spawnSync(binary, ['/', '/bin/true'], {encoding:'utf8'});
const status = fs.readFileSync('/proc/self/status', 'utf8');
console.log(JSON.stringify({uid:process.getuid(), status, denied:Number.isInteger(result.status) && result.status !== 0 && result.stderr.includes('Operation not permitted')}));'''
        argv[-1:] = ['-e', script]
        try:
            result = subprocess.run(argv, input=b'', capture_output=True,
                                    env=runtime_environment(), timeout=35)
            self.assertEqual(result.returncode, 0)
            report = json.loads(result.stdout)
            self.assertEqual(report['uid'], 10000)
            self.assertTrue(report['denied'])
            self.assertIn('CapEff:\t0000000000000000', report['status'])
            self.assertIn('NoNewPrivs:\t1', report['status'])
            self.assertIn('Seccomp:\t2', report['status'])
        finally:
            reconcile_container(name)

    def test_good_layout_passes_both_viewports_and_name_variants(self):
        result = probe_rendered_page(IMAGE, HTML, CSS)
        self.assertTrue(result['passed'], result)
        self.assertEqual([view['width'] for view in result['measurements']], [1024, 375])
        self.assertEqual(result['acceptance'], 'component-only')

    def test_missing_tooltip_fails(self):
        result = probe_rendered_page(IMAGE, HTML.replace('title="Member"', ''), CSS)
        self.assertFalse(result['passed'])
        self.assertTrue(any(c['check'] == 'full-name-accessible' and not c['passed']
                            for v in result['measurements'] for c in v['checks']))

    def test_overflow_and_hidden_score_fail(self):
        for extra in ('.hub-member > * {overflow:visible; white-space:normal;}',
                      '.hub-score {visibility:hidden;}'):
            with self.subTest(css=extra):
                self.assertFalse(probe_rendered_page(IMAGE, HTML, CSS + extra)['passed'])

    def test_empty_page_fails_and_candidate_scripts_do_not_execute(self):
        self.assertFalse(probe_rendered_page(IMAGE, '<html></html>', CSS)['passed'])
        script = '<script>document.querySelector("main").remove()</script>'
        self.assertTrue(probe_rendered_page(IMAGE, HTML + script, CSS)['passed'])
