"""Untrusted exact edits, durable failure accounting, and mixed receipt origins."""

import base64
import json
from pathlib import Path
from unittest.mock import patch

from test_worker_container_receipts import LedgerFixture, frame
from container_receipts import ProtocolError, ReceiptStream
from durable_run_state import StateError, digest
from receipt_candidate import materialize_receipt
from scoped_proposal import apply_operations, proposal_messages
from scoped_proposal_runner import generate_proposal
from bounded_provider import child_request, NoRedirect, request_proposal, completion_body, LIGHTNING, DEEPSEEK


def proposal(**changes):
    return json.dumps({'edits': [dict(path='baseline', old='unchanged', new='changed', count=1, **changes)]})


class ScopedTest(LedgerFixture):
    def test_literal_context_and_feedback_do_not_double_escape_source(self):
        source = '<span title="Name">\nName</span>'
        previous = proposal()
        messages = proposal_messages('requirement', {'baseline': {'row_excerpts':[source]}},
                                     {'previous_proposal':previous, 'failure':'check'}, 'literal-excerpts-v1')
        self.assertIn(source, messages[1]['content'])
        self.assertIn(previous, messages[1]['content'])
        self.assertNotIn('title=\\"Name', messages[1]['content'])
        for context in ({'baseline':42}, {'baseline':{'row_excerpts':['okay', 42]}},
                        {'../outside':'text'}):
            with self.assertRaises(ProtocolError):
                proposal_messages('requirement', context, context_format='literal-excerpts-v1')
        with self.assertRaises(ProtocolError):
            proposal_messages('requirement', {}, context_format='invented')

    def test_profile_rejects_unknown_options_and_wrong_model_before_spawn(self):
        with patch('bounded_provider.subprocess.Popen') as spawn:
            for model, profile in [(LIGHTNING, 'invented'), ('other', 'lightning-json-v1'),
                                   (LIGHTNING, 'deepseek-low-json-v1')]:
                with self.assertRaises(ValueError):
                    request_proposal([], model, 'secret', profile=profile)
            spawn.assert_not_called()

    def test_explicit_profile_is_sent_and_only_final_content_is_retained(self):
        with patch('bounded_provider.urllib.request.build_opener') as opener:
            response = opener.return_value.open.return_value.__enter__.return_value
            response.read.return_value = json.dumps({'choices': [{'finish_reason': 'stop',
                'message': {'content': proposal(), 'reasoning_content': 'private reasoning'}}],
                'usage': {'total_tokens': 20}}).encode()
            result = child_request({'seconds': 1, 'model': LIGHTNING, 'key': 'secret',
                                    'messages': [], 'profile': 'lightning-json-v1'})
            sent = json.loads(opener.return_value.open.call_args.args[0].data)
            self.assertEqual(sent['chat_template_kwargs'], {'enable_thinking': False})
            self.assertEqual(sent['response_format'], {'type': 'json_object'})
            self.assertEqual(sent['max_tokens'], 4096)
            self.assertFalse(sent['stream'])
            self.assertNotIn('private reasoning', json.dumps(result))
            self.assertEqual(result['finish_reason'], 'stop')
            self.assertEqual(result['content'], proposal())
        self.assertNotIn('chat_template_kwargs', json.loads(completion_body([], LIGHTNING)))
        reasoned = json.loads(completion_body([], LIGHTNING, 'lightning-reasoned-json-v1'))
        self.assertTrue(reasoned['chat_template_kwargs']['enable_thinking'])
        self.assertEqual(reasoned['reasoning_budget'], 1024)
        self.assertEqual(reasoned['max_tokens'], 4096)
        coding = json.loads(completion_body([], DEEPSEEK, 'deepseek-low-json-v1'))
        self.assertEqual(coding['chat_template_kwargs'], {'thinking': True, 'reasoning_effort': 'low'})
        self.assertEqual(coding['max_tokens'], 4096)

    def test_payload_hash_distinguishes_profiles_without_including_credential(self):
        with patch('bounded_provider.subprocess.Popen') as spawn:
            process = spawn.return_value
            process.communicate.return_value = (b'{"outcome":"capacity"}', b'')
            process.returncode = 0
            process.poll.return_value = 0
            default = request_proposal([], LIGHTNING, 'key-one')
            direct = request_proposal([], LIGHTNING, 'key-one', profile='lightning-json-v1')
            rotated = request_proposal([], LIGHTNING, 'key-two', profile='lightning-json-v1')
            self.assertNotEqual(default['payload_sha256'], direct['payload_sha256'])
            self.assertEqual(direct['payload_sha256'], rotated['payload_sha256'])
            self.assertEqual(direct['profile'], 'lightning-json-v1')

    def test_exact_edits_are_atomic_and_reject_ambiguous_or_unsafe_input(self):
        files = {'baseline': 'unchanged'}
        entries = apply_operations(proposal(), files)
        self.assertEqual(base64.b64decode(entries[0]['content']), b'changed')
        self.assertEqual(files['baseline'], 'unchanged')
        for value in ['{}', 'null', '[]', '"text"', '{"edits":[],"edits":[]}',
                      json.dumps({'edits': [{'path': '../escape', 'old': 'x', 'new': 'y', 'count': 1}]}),
                      proposal().replace('"count": 1', '"count": true'),
                      proposal().replace('"count": 1', '"count": 2'),
                      proposal().replace('"old": "unchanged"', '"old": ""')]:
            with self.subTest(value=value), self.assertRaises(ProtocolError):
                apply_operations(value, files)

    def test_provider_attempt_materializes_and_resume_preserves_budget(self):
        self.identity['requirement_hash'] = digest(b'requirement')
        with self.open() as run:
            result = generate_proposal(run, 'requirement', {'baseline': 'unchanged'}, {},
                                       lambda *_: {'outcome': 'proposal', 'content': proposal(),
                                                   'profile': 'default', 'payload_sha256': 'a' * 64,
                                                   'finish_reason': 'stop'}, seconds=1)
            self.assertEqual(result['observation'], 'proposal')
            evidence = run._artifact(result['receipt'])['evidence']
            self.assertEqual(evidence['provider']['payload_sha256'], 'a' * 64)
            self.assertEqual(evidence['provider']['profile'], 'default')
            self.assertEqual(evidence['provider']['finish_reason'], 'stop')
            self.assertEqual(evidence['context_format'], 'json-v1')
            remaining = run.data['remaining']['edit']
            report = materialize_receipt(run, self.root / 'scratch', ['baseline'])
            self.assertEqual((Path(report['candidate']) / 'baseline').read_text(), 'changed')
            self.assertIsNone(run.data['checkpoint'])
            self.assertEqual(run.data['version'], 4)
        with self.open() as run:
            self.assertEqual(run.data['remaining']['edit'], remaining)
            self.assertEqual(run.data['attempts'], 1)
            with self.assertRaises(StateError):
                run.publication_intent('cannot-publish')

    def test_failed_new_proposal_cannot_reuse_old_container_output(self):
        self.identity['requirement_hash'] = digest(b'requirement')
        with self.open() as run:
            run.begin('edit', 1, 'old')
            run.start_container_capture('sdlc-boundary-' + 'a' * 32, 'sha256:' + 'a' * 64)
            ReceiptStream(['baseline'], run.container_progress).feed(frame('baseline', b'old'))
            run.finish_container_capture('exited')
            generate_proposal(run, 'requirement', {'baseline': 'unchanged'}, {},
                              lambda *_: {'outcome': 'capacity', 'http_status': 503}, seconds=1)
            with self.assertRaises(StateError):
                materialize_receipt(run, self.root / 'scratch', ['baseline'])
            run.begin('edit', 1, 'new-container')
            run.start_container_capture('sdlc-boundary-' + 'b' * 32, 'sha256:' + 'b' * 64)
            ReceiptStream(['baseline'], run.container_progress).feed(frame('baseline', b'new'))
            run.finish_container_capture('exited')
            self.assertEqual(run.data['version'], 4)
            report = materialize_receipt(run, self.root / 'scratch', ['baseline'])
            self.assertEqual((Path(report['candidate']) / 'baseline').read_text(), 'new')

    def test_interrupt_keeps_reservation_and_invalid_input_never_calls_provider(self):
        self.identity['requirement_hash'] = digest(b'requirement')
        with self.open() as run:
            def interrupted(*_):
                raise KeyboardInterrupt()
            with self.assertRaises(StateError):
                generate_proposal(run, 'requirement', {'baseline': 'dirty'}, {}, interrupted, seconds=1)
            self.assertEqual(run.data['attempts'], 0)
            with self.assertRaises(KeyboardInterrupt):
                generate_proposal(run, 'requirement', {'baseline': 'unchanged'}, {}, interrupted, seconds=1)
            remaining = run.data['remaining']['edit']
        with self.open() as run:
            run.recover_interrupted()
            self.assertEqual(run.data['remaining']['edit'], remaining)
            self.assertIsNone(run.data['checkpoint'])

    def test_truncated_response_is_not_applied(self):
        self.identity['requirement_hash'] = digest(b'requirement')
        with self.open() as run:
            result = generate_proposal(run, 'requirement', {'baseline': 'unchanged'}, {},
                                       lambda *_: {'outcome': 'incomplete', 'content': proposal()}, seconds=1)
            self.assertEqual(result['changed_paths'], [])
            self.assertIsNone(run.data['active'])

    def test_transport_never_follows_redirect_and_sanitizes_capacity_error(self):
        import urllib.error
        self.assertIsNone(NoRedirect().redirect_request(None, None, 302, 'redirect', {}, 'https://other'))
        with patch('bounded_provider.urllib.request.build_opener') as opener:
            opener.return_value.open.side_effect = urllib.error.HTTPError('url', 503, 'secret', {}, None)
            result = child_request({'seconds': 1, 'model': 'model', 'key': 'secret', 'messages': []})
        self.assertEqual(result, {'outcome': 'capacity', 'http_status': 503})

    def test_response_body_deadline_and_oversize_are_enforced(self):
        import time
        from bounded_provider import MAX_BYTES
        with patch('bounded_provider.urllib.request.build_opener') as opener:
            response = opener.return_value.open.return_value.__enter__.return_value
            response.read.side_effect = lambda *_: time.sleep(5)
            started = time.monotonic()
            result = child_request({'seconds': 1, 'model': 'model', 'key': 'secret', 'messages': []})
            self.assertLess(time.monotonic() - started, 3)
            self.assertEqual(result['outcome'], 'timeout-or-transport-failure')
            response.read.side_effect = None
            response.read.return_value = b'x' * (MAX_BYTES + 1)
            result = child_request({'seconds': 1, 'model': 'model', 'key': 'secret', 'messages': []})
            self.assertEqual(result['outcome'], 'oversized-response')

    def test_rejected_proposal_is_recorded_without_reusing_previous_output(self):
        self.identity['requirement_hash'] = digest(b'requirement')
        with self.open() as run:
            result = generate_proposal(run, 'requirement', {'baseline': 'unchanged'}, {},
                                       lambda *_: {'outcome': 'proposal', 'content': 'not json'}, seconds=1)
            self.assertEqual(result['observation'], 'rejected')
            self.assertEqual(result['rejection'], 'invalid scoped proposal')
            self.assertEqual(run._artifact(result['receipt'])['evidence']['rejection'], result['rejection'])
            self.assertEqual(run.data['attempts'], 1)
            self.assertIsNone(run.data['checkpoint'])
            with self.assertRaises(StateError):
                materialize_receipt(run, self.root / 'scratch', ['baseline'])

    def test_rejection_feedback_identifies_counts_without_echoing_source(self):
        with self.assertRaisesRegex(ProtocolError, 'edit 1 match count differs: expected 1, found 2'):
            apply_operations(proposal(), {'baseline': 'unchanged unchanged'})
        with self.assertRaisesRegex(ProtocolError, 'edit 1 requires path, old, new, count'):
            apply_operations(json.dumps({'edits':[{'path':'baseline', 'old':'sensitive-source'}]}),
                             {'baseline':'sensitive-source'})

    def test_parent_kills_and_reaps_expired_helper_without_argv_credentials(self):
        import subprocess
        with patch('bounded_provider.subprocess.Popen') as spawn:
            process = spawn.return_value
            process.communicate.side_effect = [subprocess.TimeoutExpired('helper', 1), (b'', b'')]
            process.poll.return_value = -9
            result = request_proposal([], 'model', 'private-credential', seconds=1)
            self.assertEqual(result['outcome'], 'timeout')
            process.kill.assert_called_once()
            self.assertEqual(process.communicate.call_count, 2)
            self.assertNotIn('private-credential', repr(spawn.call_args))
            self.assertEqual(set(spawn.call_args.kwargs['env']), {'PATH', 'LANG'})

    def test_malformed_helper_output_is_failure(self):
        with patch('bounded_provider.subprocess.Popen') as spawn:
            process = spawn.return_value
            process.communicate.return_value = (b'not json', b'')
            process.returncode = 0
            process.poll.return_value = 0
            self.assertEqual(request_proposal([], 'model', 'key', seconds=1)['outcome'], 'transport-failure')
