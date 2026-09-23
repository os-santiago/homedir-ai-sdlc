"""Run the workflow preparation section with a fake container runtime."""

from pathlib import Path
import json
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / ".github/workflows/deploy-production.yml").read_text()


class DeploymentPreparationTest(unittest.TestCase):
    def test_runtime_credentials_fail_before_mutation(self):
        start = WORKFLOW.index('            # Validate runtime secrets')
        end = WORKFLOW.index('            # Prepare every replacement', start)
        guard = WORKFLOW[start:end]
        for github, provider, litellm in [('', '', ''), ('test-github', '', 'test-litellm'),
                ('', 'test-provider', 'test-litellm'), ('test-github', 'test-provider', ''),
                ('test-github', 'test-provider', 'test-litellm')]:
            with self.subTest(github=bool(github), provider=bool(provider), litellm=bool(litellm)):
                result = subprocess.run(['bash', '-c', 'set -eu\n' + guard + '\necho MUTATION'],
                                        env={'PATH': '/usr/bin:/bin', 'GH_TOKEN': github,
                                             'NVIDIA_API_KEY': provider, 'LITELLM_API_KEY': litellm},
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode == 0, bool(github and provider and litellm))
                self.assertEqual('MUTATION' in result.stdout, bool(github and provider and litellm))
                self.assertNotIn('test-provider', result.stderr)
                self.assertNotIn('test-litellm', result.stderr)
        self.assertLess(start, WORKFLOW.index('podman pod stop'))
        self.assertIn('NVIDIA_API_KEY: ${{ secrets.NVIDIA_API_KEY }}', WORKFLOW)
        forwarded = next(line for line in WORKFLOW.splitlines() if 'envs:' in line)
        self.assertIn('NVIDIA_API_KEY', forwarded)
        self.assertNotIn('OPENAI_API_KEY', forwarded)
        self.assertIn('LITELLM_API_KEY', forwarded)

    def test_implementation_runtime_key_is_required_and_injected_without_logging(self):
        component = ROOT / 'future-go/components/implementation'
        template = json.loads((component / 'config-litellm.json').read_text())
        self.assertEqual(template['model']['apiKey'], '')
        self.assertTrue(all(profile['apiKey'] == '' for profile in template['profiles'].values()))
        for key in ('', 'test-only-runtime-value'):
            with self.subTest(present=bool(key)), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                home = root / 'home'
                (home / '.sc-agent').mkdir(parents=True)
                config = home / '.sc-agent/config.json'
                config.write_text(json.dumps(template))
                service = root / 'implementation-service'
                service.write_text('#!/bin/sh\necho STARTED\n')
                service.chmod(0o700)
                result = subprocess.run(['bash', '-c', (component / 'entrypoint.sh').read_text()],
                    cwd=root, env={'PATH':'/usr/bin:/bin', 'HOME':str(home), 'LITELLM_API_KEY':key},
                    text=True, capture_output=True)
                self.assertEqual(result.returncode == 0, bool(key))
                self.assertEqual('STARTED' in result.stdout, bool(key))
                if key:
                    self.assertNotIn(key, result.stdout + result.stderr)
                    saved = json.loads(config.read_text())
                    self.assertEqual(saved['model']['apiKey'], key)
                    self.assertTrue(all(p['apiKey'] == key for p in saved['profiles'].values()))
                    self.assertEqual(config.stat().st_mode & 0o077, 0)

    def test_image_configuration_has_no_credentials(self):
        config = json.loads((ROOT / 'container/sc-agent-config.json').read_text())
        self.assertEqual(config['activeProfile'], 'nvidia')
        self.assertEqual(config['model']['baseUrl'], config['profiles']['nvidia']['baseUrl'])
        self.assertNotIn('apiKey', json.dumps(config))
        containerfile = (ROOT / 'container/Containerfile.worker').read_text()
        self.assertNotIn('"apiKey"', containerfile)
        self.assertIn('COPY container/sc-agent-config.json', containerfile)

    def test_failed_pull_preserves_running_deployment(self):
        start = WORKFLOW.index("            # Prepare every replacement")
        end = WORKFLOW.index("            # Create worker environment", start)
        preparation = WORKFLOW[start:end].replace("${{ env.REPOSITORY }}", "registry/example")
        for failure in ("worker", "dashboard", "implementation", "none"):
            with self.subTest(failure=failure):
                script = "\n".join([
                    "set -eu",
                    "GITHUB_SHA=abc123",
                    f"FAIL_COMPONENT={failure}",
                    'podman() { echo "$*"; if [ "$1" = pull ] && [ "$2" = "registry/example:${FAIL_COMPONENT}-abc123" ]; then return 42; fi; }',
                    preparation,
                    "podman pod stop ai-sdlc",
                ])
                result = subprocess.run(["bash", "-c", script], text=True, capture_output=True)
                if failure == "none":
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.splitlines(), [
                        "pull registry/example:worker-abc123",
                        "pull registry/example:dashboard-abc123",
                        "pull registry/example:implementation-abc123",
                        "pod stop ai-sdlc",
                    ])
                else:
                    self.assertEqual(result.returncode, 42, result.stderr)
                    self.assertNotIn("pod stop", result.stdout)

    def test_workflow_orders_preparation_before_mutation(self):
        deploy = WORKFLOW.split("  notify-deployment:", 1)[1]
        self.assertNotIn("if: always()", deploy.split("    steps:", 1)[0])
        for component in ("worker", "dashboard", "implementation"):
            self.assertIn(f"needs.build-{component}.result == 'success'", deploy.split("    steps:", 1)[0])
            self.assertIn(component + '-${GITHUB_SHA}', deploy)
        self.assertLess(deploy.index("for component in"), deploy.index("podman pod stop"))
        script = deploy.split("          script: |", 1)[1]
        self.assertIn("set -e", script[:100])
        self.assertNotIn(":worker-latest)", script)
        self.assertNotIn(":dashboard-latest\n", script)
        self.assertNotIn(":implementation-latest\n", script)


if __name__ == "__main__":
    unittest.main()
