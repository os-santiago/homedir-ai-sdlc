"""Real browser positive/negative controls; no external site or model access."""

import os
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'platform/scripts'))
from reputation_layout_probe import probe_rendered_page

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
class ReputationLayoutIntegrationTest(unittest.TestCase):
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
