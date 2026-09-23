"""Reviewed #1564-specific plan; not automatic general-purpose issue planning."""

import re

from container_receipts import ProtocolError
from reputation_candidate_probe import CSS_PATH, TEMPLATE_PATH, SCOPE, Rows
from targeted_proposal import target_spans

PLAN_VERSION = 'reputation-approved-targets-v2'


def reputation_targets(files):
    if set(files) != SCOPE:
        raise ProtocolError('exact reputation pilot scope required')
    Rows(files[TEMPLATE_PATH])
    css = files[CSS_PATH]
    targets = []

    def block(identifier, selector, intent, indent=''):
        pattern = r'(?:^|\n\n)(' + re.escape(indent + selector) + r' \{\n[^{}]*?\n' + re.escape(indent) + r'\})'
        matches = list(re.finditer(pattern, css))
        if len(matches) != 1:
            raise ProtocolError('pilot CSS anchor is missing or ambiguous')
        targets.append({'id':identifier, 'path':CSS_PATH, 'old':matches[0][1], 'count':1, 'intent':intent})

    block('desktop-row', '.hub-list-item',
          'Change only grid-template-columns to auto auto minmax(0, 1fr) auto. Preserve this selector and every other declaration. Return only this rule, never additional selectors. Rank, avatar and score keep intrinsic widths; the member track must shrink.')
    block('mobile-row', '.hub-list-item',
          'Change only grid-template-columns to auto minmax(0, 1fr) auto. Preserve this selector. Return only this rule, never additional selectors. The avatar is hidden at this breakpoint.', '  ')
    block('member-box', '.hub-member',
          'Preserve display:grid, gap and min-width:0. Add max-width:100% and grid-template-columns:minmax(0, 1fr) to constrain the inner grid track. Return only this rule. Names remain visible; max-width:0 is forbidden.')
    block('name-overflow', '.hub-member-link',
          'Use the selector .hub-member-link, .hub-member-name. Preserve overflow:hidden, text-overflow:ellipsis, white-space:nowrap; add min-width:0 and max-width:100%. Return only this rule. Do not change display, color or decoration; fallback names must not receive link styling.')
    block('handle-overflow', '.hub-handle',
          'Preserve opacity and font-size. Add min-width:0, max-width:100%, overflow:hidden, text-overflow:ellipsis and white-space:nowrap. Return only this rule; keep handles visible within the member track.')
    for prefix, count in [('standing.leader', 1), ('entry', 4)]:
        kind = 'leader' if count == 1 else 'entry'
        name = '{' + prefix + '.displayName}'
        link = '<a href="{' + prefix + '.profilePath}" class="hub-member-link">' + name + '</a>'
        for suffix, original, intent in [
            ('link', link, 'Keep the link, URL, class and displayed Qute name. Add title with that same full Qute name.'),
            ('fallback', '<span>' + name + '</span>',
             'Keep the span and displayed Qute name. Add title with the same full Qute name and class="hub-member-name". Return only this span.')]:
            targets.append({'id':kind + '-' + suffix, 'path':TEMPLATE_PATH, 'old':original,
                            'count':count, 'intent':intent})
    target_spans(files, targets)
    return targets
