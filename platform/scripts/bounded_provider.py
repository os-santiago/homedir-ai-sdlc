"""One bounded non-streaming NVIDIA request; no agent tools or arbitrary endpoint."""

import hashlib
import json
from pathlib import Path
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request

ENDPOINT = 'https://integrate.api.nvidia.com/v1/chat/completions'
MAX_BYTES = 512 * 1024
LIGHTNING = 'nvidia/nemotron-3.5-lightning-30b-a3b'
DEEPSEEK = 'deepseek-ai/deepseek-v4-flash-0731'


def completion_body(messages, model, profile='default'):
    """Reviewed profiles only; model output cannot inject provider options."""
    if profile not in {'default', 'lightning-json-v1', 'lightning-reasoned-json-v1', 'deepseek-low-json-v1'}:
        raise ValueError('unknown inference profile')
    body = {'model': model, 'messages': messages, 'stream': False,
            'temperature': 0.2, 'max_tokens': 4096}
    if profile.startswith('lightning-'):
        if model != LIGHTNING:
            raise ValueError('inference profile does not match model')
        body.update(chat_template_kwargs={'enable_thinking': False},
                    response_format={'type': 'json_object'})
        if profile == 'lightning-reasoned-json-v1':
            body['chat_template_kwargs']['enable_thinking'] = True
            body['reasoning_budget'] = 1024
    elif profile == 'deepseek-low-json-v1':
        if model != DEEPSEEK:
            raise ValueError('inference profile does not match model')
        body.update(chat_template_kwargs={'thinking': True, 'reasoning_effort': 'low'},
                    response_format={'type': 'json_object'})
    return json.dumps(body, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *_args, **_kwargs):
        return None


def request_proposal(messages, model, api_key, seconds=120, profile='default'):
    """Secret travels only over stdin to a trusted child and in the HTTPS header."""
    if type(seconds) is not int or not 1 <= seconds <= 120:
        raise ValueError('deadline must be 1..120 seconds')
    if not isinstance(model, str) or not model or not isinstance(api_key, str) or not api_key:
        raise ValueError('operator model and credential required')
    body = completion_body(messages, model, profile)
    payload = json.dumps({'messages': messages, 'model': model, 'key': api_key,
                          'seconds': seconds, 'profile': profile}).encode()
    if len(payload) > 160 * 1024:
        raise ValueError('request input limit exceeded')
    started = time.monotonic()
    process = subprocess.Popen([sys.executable, '-I', str(Path(__file__).resolve()), '--request'],
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                               env={'PATH': '/usr/bin:/bin', 'LANG': 'C.UTF-8'})
    try:
        output, _ = process.communicate(payload, timeout=seconds + 2)
        if process.returncode or len(output) > MAX_BYTES:
            result = {'outcome': 'transport-failure'}
        else:
            try:
                result = json.loads(output)
                if not isinstance(result, dict) or not isinstance(result.get('outcome'), str):
                    result = {'outcome': 'transport-failure'}
            except (ValueError, TypeError):
                result = {'outcome': 'transport-failure'}
    except subprocess.TimeoutExpired:
        process.kill()
        process.communicate(timeout=2)
        result = {'outcome': 'timeout'}
    finally:
        if process.poll() is None:
            process.kill()
            process.communicate(timeout=2)
    return dict(result, model=model, profile=profile, payload_sha256=hashlib.sha256(body).hexdigest(),
                elapsed_seconds=round(time.monotonic() - started, 3))


def child_request(data):
    # An independent alarm also stops the request if the orchestrator is killed.
    def expired(*_):
        raise TimeoutError('request deadline')
    signal.signal(signal.SIGALRM, expired)
    signal.alarm(data['seconds'])
    body = completion_body(data['messages'], data['model'], data.get('profile', 'default'))
    request = urllib.request.Request(ENDPOINT, data=body, method='POST',
                                     headers={'Authorization': 'Bearer ' + data['key'], 'Content-Type': 'application/json'})
    # Ignore proxy environment/config and refuse bearer-token redirects.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    try:
        with opener.open(request, timeout=data['seconds']) as response:
            raw = response.read(MAX_BYTES + 1)
        if len(raw) > MAX_BYTES:
            return {'outcome': 'oversized-response'}
        parsed = json.loads(raw)
        choice = parsed['choices'][0]
        content = choice['message']['content']
        if not isinstance(content, str) or len(content.encode()) > 128 * 1024:
            return {'outcome': 'invalid-response'}
        usage = {k: v for k, v in (parsed.get('usage') or {}).items()
                 if k in {'prompt_tokens', 'completion_tokens', 'total_tokens'} and type(v) is int and v >= 0}
        return {'outcome': 'proposal' if choice.get('finish_reason') == 'stop' else 'incomplete',
                'content': content, 'usage': usage,
                'finish_reason': choice.get('finish_reason') if choice.get('finish_reason') in
                                 {'stop', 'length', 'tool_calls', 'content_filter'} else 'unknown'}
    except urllib.error.HTTPError as exc:
        exc.close()
        return {'outcome': 'capacity' if exc.code in {429, 503} else 'provider-error', 'http_status': exc.code}
    except (TimeoutError, urllib.error.URLError):
        return {'outcome': 'timeout-or-transport-failure'}
    except (ValueError, KeyError, TypeError, IndexError, AttributeError):
        return {'outcome': 'invalid-response'}
    finally:
        signal.alarm(0)


if __name__ == '__main__':
    if sys.argv[1:] != ['--request']:
        raise SystemExit('Internal request helper; use the trusted API')
    data = json.loads(sys.stdin.buffer.read(160 * 1024 + 1))
    print(json.dumps(child_request(data)))
