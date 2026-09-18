"""Fail-closed browser boundary and report handling without downloading a browser."""

from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'platform/scripts'))
from durable_run_state import StateError
from reputation_layout_probe import browser_boundary, probe_rendered_page


class BrowserBoundaryTest(unittest.TestCase):
    def test_closed_profile_has_no_mounts_or_credentials(self):
        name, argv = browser_boundary('sha256:' + 'a' * 64)
        self.assertTrue(name.startswith('sdlc-boundary-'))
        for option in ('--network=none', '--user=10000:10000', '--cap-drop=ALL',
                       '--read-only', '--unsetenv-all', '--timeout=30'):
            self.assertIn(option, argv)
        self.assertNotIn('--volume', argv)
        self.assertNotIn('--privileged', argv)
        self.assertFalse(any('host' in option for option in argv))

    def test_tags_and_oversized_inputs_fail_before_launch(self):
        with self.assertRaises(StateError):
            browser_boundary('image:latest')
        with patch('reputation_layout_probe.subprocess.Popen') as launch:
            with self.assertRaises(StateError):
                probe_rendered_page('sha256:' + 'a' * 64, 'x' * 1024 * 1024, '')
            launch.assert_not_called()

    def test_bad_report_is_rejected_and_container_is_reconciled(self):
        process = Mock(returncode=0)
        process.communicate.return_value = (b'{"passed":true}', None)
        with patch('reputation_layout_probe.subprocess.Popen', return_value=process), \
             patch('reputation_layout_probe.reconcile_container') as reconcile:
            with self.assertRaises(StateError):
                probe_rendered_page('sha256:' + 'a' * 64, '', '')
            reconcile.assert_called_once()

    def test_timeout_cannot_return_success(self):
        process = Mock()
        process.communicate.side_effect = [subprocess.TimeoutExpired('probe', 35), (b'', None)]
        process.poll.return_value = None
        with patch('reputation_layout_probe.subprocess.Popen', return_value=process), \
             patch('reputation_layout_probe.reconcile_container') as reconcile:
            with self.assertRaises(StateError):
                probe_rendered_page('sha256:' + 'a' * 64, '', '')
            process.kill.assert_called_once()
            reconcile.assert_called_once()
