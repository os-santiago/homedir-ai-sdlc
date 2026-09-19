"""Shadow data-only edit attempt; transport is supplied by the trusted operator."""

from container_receipts import ProtocolError, ReceiptStream
from durable_run_state import StateError, digest, encoded, locked
from scoped_proposal import apply_operations, proposal_messages


@locked
def generate_proposal(run, requirement, files, context, provider, seconds=120, feedback=None,
                      context_format='json-v1'):
    """Reserve first, then record one complete response without approving it.

    The provider must enforce its own deadline and return only after cleanup.
    Context and feedback come from trusted policy/validators, never model tools.
    Interrupted attempts retain their full reservation for explicit recovery.
    """
    if type(seconds) is not int or not 1 <= seconds <= 120:
        raise StateError('request deadline must be 1..120 seconds')
    ReceiptStream(files, lambda *_: None)
    if digest(requirement.encode()) != run.identity['requirement_hash']:
        raise StateError('requirement differs from run identity')
    for path, content in files.items():
        original = run._git('show', run.identity['base_sha'] + ':' + path)
        if original != content.encode():
            raise StateError('proposal input must match immutable base')
    messages = proposal_messages(requirement, context, feedback, context_format)
    run.begin('edit', seconds + 5, 'scoped-proposal')
    result = provider(messages, seconds)
    # Keep provider evidence bounded and free of transport credentials/errors.
    evidence = {'request_sha256': digest(encoded(messages)), 'context_format': context_format,
                'input_sha256': {path: digest(text.encode()) for path, text in files.items()},
                'provider': {key: result[key] for key in
                             ('outcome', 'model', 'profile', 'payload_sha256', 'finish_reason',
                              'elapsed_seconds', 'usage', 'http_status', 'content') if key in result}}
    entries, observation = [], 'failed'
    if result.get('outcome') == 'proposal':
        try:
            entries = apply_operations(result.get('content'), files)
            observation = 'proposal'
        except ProtocolError as exc:
            observation = 'rejected'
            evidence['rejection'] = str(exc)
    run.finish_file_proposal(entries, observation, evidence)
    return {'observation': observation, 'receipt': run.data['last_proposal'],
            'provider_outcome': result.get('outcome'), 'changed_paths': [e['path'] for e in entries],
            'rejection': evidence.get('rejection')}
