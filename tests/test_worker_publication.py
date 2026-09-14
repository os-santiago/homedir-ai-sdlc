"""Exercise publication arguments and policy filtering without GitHub mutation."""
import json
import os
from pathlib import Path
import subprocess
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / 'platform/scripts/homedir-sdlc-worker.sh').read_text()


def function(name):
    start = SOURCE.index(name + '() {')
    return SOURCE[start:SOURCE.index('\n}\n', start) + 3]


class PublicationTest(unittest.TestCase):
    def test_creation_arguments(self):
        script = '\n'.join([
            'set -eu', 'REPO=fixture/repo',
            function('create_implementation_pr'),
            'publication_risk_label() { echo pr:risk-medium; }',
            'gh() { printf "%s\\0" "$@"; }',
            'create_implementation_pr 67 "A title" fix/fixture "Validation pending"',
        ])
        result = subprocess.run(['bash', '-c', script], capture_output=True, text=True, check=True)
        args = result.stdout.split('\0')[:-1]
        self.assertEqual(args[:2], ['pr', 'create'])
        self.assertEqual(args.count('--label'), 1)
        self.assertEqual(args[args.index('--label') + 1], 'pr:risk-medium')
        body = args[args.index('--body') + 1]
        self.assertIn('Closes #67', body)
        self.assertIn('Validation pending', body)
        self.assertNotIn('pr:acceptance-ok', args)

    def test_risk_selection(self):
        for files, expected in [
            ('docs/guide.md', 'pr:risk-low'),
            ('src/page.css\nsrc/page.html', 'pr:risk-medium'),
            ('.github/workflows/ci.yml', 'pr:risk-high'),
            ('src/Authentication.java\ndocs/guide.md', 'pr:risk-critical'),
            ('', None),
        ]:
            with self.subTest(files=files):
                script = '\n'.join(['set -eu', 'WORKDIR=fixture', function('publication_risk_label'),
                                    'git() { printf "%s" "$FILES"; }', 'publication_risk_label'])
                result = subprocess.run(['bash', '-c', script], env=dict(os.environ, FILES=files), capture_output=True, text=True)
                if expected:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.strip(), expected)
                else:
                    self.assertNotEqual(result.returncode, 0)

    def test_policy_requires_one_real_decision(self):
        valid = json.dumps({'policy': 'test', 'decision': 'test'})
        for value in ['null', 'null\nnull', '', '{}', 'invalid', valid, valid + '\n' + valid]:
            with self.subTest(value=value):
                result = subprocess.run(['bash', '-c', function('valid_policy_decision') + '\nvalid_policy_decision'],
                                        input=value, text=True, capture_output=True)
                self.assertEqual(result.returncode == 0, value == valid)

    def test_worker_owned_commits_are_signed(self):
        commands = [line for line in SOURCE.splitlines() if 'git -C "${WORKDIR}" commit ' in line]
        self.assertEqual(len(commands), 2)
        for command in commands:
            self.assertIn('commit -s ', command)


if __name__ == '__main__':
    unittest.main()
