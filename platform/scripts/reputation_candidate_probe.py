"""Offline #1564 component evidence bound to an exact materialized candidate."""

import base64
from html.parser import HTMLParser
import os
from pathlib import Path
import stat
import xml.etree.ElementTree as ET

from container_receipts import ReceiptStream
from durable_run_state import StateError, atomic_write, digest, encoded, locked
from reputation_layout_probe import probe_qute_rows

CSS_PATH = 'quarkus-app/src/main/resources/META-INF/resources/css/reputation-hub.css'
TEMPLATE_PATH = 'quarkus-app/src/main/resources/templates/ReputationHubResource/hub.html'
SCOPE = {CSS_PATH, TEMPLATE_PATH}


class Rows(HTMLParser):
    """Extract original source slices; Qute, not this parser, evaluates expressions."""
    VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr'}

    def __init__(self, source):
        super().__init__(convert_charrefs=False)
        self.source, self.stack, self.rows, self.start = source, [], [], None
        self.lines = source.splitlines(keepends=True)
        self.feed(source)
        self.close()
        if self.start is not None or len(self.rows) != 5:
            raise StateError('pilot requires five complete source row templates')

    def source_index(self):
        line, column = self.getpos()
        return sum(map(len, self.lines[:line - 1])) + column

    def handle_starttag(self, tag, attrs):
        is_row = 'hub-list-item' in (dict(attrs).get('class') or '').split()
        if is_row:
            if self.start is not None or tag not in {'li', 'div'}:
                raise StateError('unsupported nested row structure')
            self.start = self.source_index()
            self.stack = []
        if self.start is not None and tag not in self.VOID:
            self.stack.append(tag)

    def handle_startendtag(self, tag, attrs):
        if tag not in self.VOID:
            self.handle_starttag(tag, attrs)
            self.handle_endtag(tag)

    def handle_endtag(self, tag):
        if self.start is None:
            return
        if not self.stack or self.stack.pop() != tag:
            raise StateError('unbalanced row markup')
        if not self.stack:
            end = self.source.find('>', self.source_index()) + 1
            if end <= self.source_index():
                raise StateError('incomplete row markup')
            self.rows.append(self.source[self.start:end])
            self.start = None


def read_regular(root, relative):
    path = root / relative
    if any(p.is_symlink() for p in (path, *path.parents)):
        raise StateError('candidate file cannot traverse symlinks')
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as source:
        info = os.fstat(source.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > 256 * 1024:
            raise StateError('regular bounded candidate file required')
        content = source.read(256 * 1024 + 1)
        if len(content) > 256 * 1024:
            raise StateError('candidate file grew beyond limit')
        return content, stat.S_IMODE(info.st_mode)


@locked
def probe_candidate(run, report, image_id):
    """Shadow observation only: no checkpoint, budget reset or publication transition."""
    if run.data['active'] or run.data.get('external_container') or run.data['publication'] or run.data['status'] == 'waiting':
        raise StateError('quiescent run required')
    receipt_ref = run.data.get('last_container_receipt')
    if (not receipt_ref or report.get('kind') != 'untrusted-candidate' or
            report.get('identity') != run.identity or report.get('receipt_sha256') != receipt_ref['sha256'] or
            not set(report.get('allowed_paths', [])).issubset(SCOPE)):
        raise StateError('matching pilot candidate required')
    receipt = run._artifact(receipt_ref)
    if receipt.get('identity') != run.identity:
        raise StateError('receipt identity mismatch')
    parser = ReceiptStream(SCOPE, lambda *_: None)
    for entry in receipt['entries']:
        parser.feed(encoded(entry) + b'\n')
    parser.end()
    if not set(parser.entries).issubset(report['allowed_paths']):
        raise StateError('receipt exceeds materialized scope')
    candidate = Path(report['candidate'])
    if any(p.is_symlink() for p in (candidate, *candidate.parents)):
        raise StateError('candidate path cannot traverse symlinks')
    candidate = candidate.resolve()
    if candidate == run.repo or candidate.is_relative_to(run.root):
        raise StateError('separate candidate required')
    snapshot = run._snapshot(candidate)
    snapshot_hash = digest(encoded(snapshot))
    if snapshot_hash != report.get('snapshot_sha256'):
        raise StateError('candidate changed since materialization')
    # Independently match proposed bytes/modes and reject unrelated candidate edits.
    changed = set(os.fsdecode(p) for p in run._git('diff', '--name-only', '-z', run.identity['base_sha'], '--', repo=candidate).split(b'\0') if p)
    changed.update(item['path'] for item in snapshot['untracked'])
    if not changed or not changed.issubset(parser.entries):
        raise StateError('candidate differs outside recorded proposal')
    for path, entry in parser.entries.items():
        if entry.get('delete'):
            raise StateError('pilot files cannot be deleted')
        content, mode = read_regular(candidate, path)
        if content != base64.b64decode(entry['content']) or mode != entry['mode']:
            raise StateError('candidate differs from recorded proposal')
    template, _ = read_regular(candidate, TEMPLATE_PATH)
    css, _ = read_regular(candidate, CSS_PATH)
    pom, _ = read_regular(candidate, 'quarkus-app/pom.xml')
    version = ET.fromstring(pom).find('{*}properties/{*}quarkus.platform.version')
    if version is None or version.text != '3.26.4':
        raise StateError('pilot renderer requires Quarkus 3.26.4')
    rows = Rows(template.decode('utf-8')).rows
    result = probe_qute_rows(image_id, rows, css.decode('utf-8'))
    if digest(encoded(run._snapshot(candidate))) != snapshot_hash:
        raise StateError('candidate changed during observation')
    evidence = {'schema': 1, 'kind': 'candidate-component-observation', 'identity': run.identity,
                'receipt_sha256': receipt_ref['sha256'], 'snapshot_sha256': snapshot_hash,
                'template_sha256': digest(template), 'css_sha256': digest(css),
                'renderer': 'qute-3.26.4-pilot-rows-v1', 'row_templates': len(rows), 'result': result,
                'acceptance': 'component-only'}
    name = 'observation-' + digest(encoded(evidence)) + '.json'
    atomic_write(run.path / name, evidence)
    return evidence
