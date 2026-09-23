"""Approved targets cannot be retargeted, cascaded or partially applied by a model."""

import base64
import json
from pathlib import Path

from test_worker_container_receipts import LedgerFixture
from container_receipts import ProtocolError
from durable_run_state import digest
from receipt_candidate import materialize_receipt
from scoped_proposal_runner import generate_proposal
from targeted_proposal import target_spans, apply_targets, target_messages
from reputation_edit_plan import reputation_targets
from reputation_candidate_probe import CSS_PATH, TEMPLATE_PATH


def target(name='first', old='unchanged', count=1):
    return {'id':name, 'path':'baseline', 'old':old, 'count':count, 'intent':'Update the approved text.'}


def response(*items):
    return json.dumps({'replacements':[{'id':name, 'text':text} for name, text in items]})


class TargetedTest(LedgerFixture):
    def test_all_occurrences_use_original_offsets_without_cascading(self):
        files = {'baseline':'A B A'}
        targets = [target('a', 'A', 2), target('b', 'B')]
        entries = apply_targets(response(('a','B'),('b','C')), files, targets)
        self.assertEqual(base64.b64decode(entries[0]['content']), b'B C B')
        self.assertEqual(files['baseline'], 'A B A')

    def test_missing_unknown_duplicate_and_extra_fields_are_rejected_atomically(self):
        files, targets = {'baseline':'A B'}, [target('a','A'), target('b','B')]
        for value in (response(('a','new')), response(('a','new'),('outside','other')),
                      response(('a','new'),('a','other')),
                      '{"replacements":[{"id":"a","text":"new","path":"outside"},{"id":"b","text":"other"}]}',
                      '{"replacements":[],"replacements":[]}', 'null', 'not json'):
            with self.subTest(value=value), self.assertRaises(ProtocolError):
                apply_targets(value, files, targets)
        self.assertEqual(files, {'baseline':'A B'})

    def test_overlapping_stale_and_unsafe_plans_are_rejected(self):
        for targets in ([target('a','unchanged'), target('b','changed')],
                        [target('a','missing')], [target('a','unchanged',2)],
                        [dict(target(), path='../outside')], [target(), target()]):
            with self.subTest(targets=targets), self.assertRaises(ProtocolError):
                target_spans({'baseline':'unchanged'}, targets)

    def test_noop_oversize_and_non_text_replacements_are_rejected(self):
        for value in (response(('first','unchanged')), response(('first','x'*140000)),
                      response(('first',None))):
            with self.subTest(length=len(value)), self.assertRaises(ProtocolError):
                apply_targets(value, {'baseline':'unchanged'}, [target()])

    def test_prompt_is_literal_and_model_does_not_own_paths_or_counts(self):
        original = '<span title="Name">\nName</span>'
        messages = target_messages('requirement', {'baseline':original}, [target(old=original)])
        self.assertIn(original, messages[1]['content'])
        self.assertIn('"id":"target-id","text":"complete new text"', messages[0]['content'])

    def test_valid_response_is_recorded_and_materialized_without_checkpoint(self):
        self.identity['requirement_hash'] = digest(b'requirement')
        with self.open() as run:
            result = generate_proposal(run, 'requirement', {'baseline':'unchanged'}, {},
                lambda *_: {'outcome':'proposal', 'content':response(('first','updated'))},
                seconds=1, targets=[target()])
            evidence = run._artifact(result['receipt'])['evidence']
            self.assertEqual(evidence['context_format'], 'approved-targets-v1')
            self.assertEqual(len(evidence['target_plan_sha256']), 64)
            report = materialize_receipt(run, self.root/'scratch', ['baseline'])
            self.assertEqual((Path(report['candidate'])/'baseline').read_text(), 'updated')
            self.assertIsNone(run.data['checkpoint'])

    def test_previous_proposal_is_untrusted_literal_text_separate_from_validator(self):
        previous = response(('first', '<span title="Full name">Name</span>'))
        messages = target_messages('requirement', {'baseline':'unchanged'}, [target()],
                                   {'previous_proposal':previous, 'passed':False})
        prompt = messages[1]['content']
        self.assertIn('PREVIOUS UNTRUSTED PROPOSAL\n' + previous, prompt)
        trusted = prompt.split('TRUSTED VALIDATOR FEEDBACK\n')[1]
        self.assertEqual(json.loads(trusted), {'passed':False})
        for feedback in ([], 'text', {'previous_proposal':{}}):
            with self.subTest(feedback=feedback), self.assertRaises(ProtocolError):
                target_messages('requirement', {'baseline':'unchanged'}, [target()], feedback)

    def test_bad_plan_spends_nothing_but_invalid_response_charges_attempt(self):
        self.identity['requirement_hash'] = digest(b'requirement')
        with self.open() as run:
            with self.assertRaises(ProtocolError):
                generate_proposal(run,'requirement',{'baseline':'unchanged'}, {},
                                 lambda *_: self.fail('provider called'), seconds=1, targets=[target(old='stale')])
            self.assertEqual(run.data['attempts'],0)
            result = generate_proposal(run,'requirement',{'baseline':'unchanged'}, {},
                                      lambda *_:{'outcome':'proposal','content':response()}, seconds=1, targets=[target()])
            self.assertEqual(result['observation'],'rejected')
            self.assertEqual(run.data['attempts'],1)
            self.assertIn('every approved target',result['rejection'])

    def test_caller_plan_mutation_cannot_retarget_an_inflight_proposal(self):
        self.identity['requirement_hash'] = digest(b'requirement')
        targets = [target()]
        def provider(*_):
            targets[0]['old'] = 'changed-after-admission'
            return {'outcome':'proposal','content':response(('first','updated'))}
        with self.open() as run:
            result = generate_proposal(run,'requirement',{'baseline':'unchanged'}, {},
                                      provider,seconds=1,targets=targets)
            self.assertEqual(result['observation'],'proposal')
            evidence = run._artifact(result['receipt'])['evidence']
            self.assertEqual(evidence['target_plan'][0]['old'],'unchanged')

    def test_pilot_plan_covers_every_name_variant_and_avoids_unrelated_css(self):
        blocks = ['.hub-list-item', '.hub-member', '.hub-member-link', '.hub-handle', '  .hub-list-item']
        css = '.other-link,\n.hub-member-link {\n  color:white;\n}\n\n' + '\n\n'.join(
            selector + ' {\n  color:black;\n' + ('  ' if selector.startswith('  ') else '') + '}' for selector in blocks)
        def row(prefix):
            return ('<li class="hub-list-item"><div class="hub-member">'
                    '<a href="{' + prefix + '.profilePath}" class="hub-member-link">{' + prefix + '.displayName}</a>'
                    '<span>{' + prefix + '.displayName}</span></div></li>')
        files = {CSS_PATH:css, TEMPLATE_PATH:row('standing.leader') + row('entry')*4}
        targets = reputation_targets(files)
        self.assertEqual(len(targets),9)
        self.assertEqual({t['id']:t['count'] for t in targets if t['path']==TEMPLATE_PATH},
                         {'leader-link':1,'leader-fallback':1,'entry-link':4,'entry-fallback':4})
        self.assertNotIn('color:white', next(t['old'] for t in targets if t['id']=='name-overflow'))
        with self.assertRaises(ProtocolError):
            reputation_targets(dict(files, **{TEMPLATE_PATH:files[TEMPLATE_PATH].replace('<span>{entry.displayName}</span>','<span>other</span>',1)}))
