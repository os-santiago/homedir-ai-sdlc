"""Run the workflow preparation section with a fake container runtime."""

from pathlib import Path
import json
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / ".github/workflows/deploy-production.yml").read_text()


class DeploymentPreparationTest(unittest.TestCase):
    def test_runtime_credentials_fail_before_mutation(self):
        start = WORKFLOW.index('            # Validate runtime secrets')
        end = WORKFLOW.index('            # Prepare every replacement', start)
        guard = WORKFLOW[start:end]
        for github, provider in [('', ''), ('test-github', ''), ('', 'test-provider'), ('test-github', 'test-provider')]:
            with self.subTest(github=bool(github), provider=bool(provider)):
                result = subprocess.run(['bash', '-c', 'set -eu\n' + guard + '\necho MUTATION'],
                                        env={'PATH': '/usr/bin:/bin', 'GH_TOKEN': github, 'NVIDIA_API_KEY': provider},
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode == 0, bool(github and provider))
                self.assertEqual('MUTATION' in result.stdout, bool(github and provider))
                self.assertNotIn('test-provider', result.stderr)
        self.assertLess(start, WORKFLOW.index('podman pod stop'))
        self.assertIn('NVIDIA_API_KEY: ${{ secrets.NVIDIA_API_KEY }}', WORKFLOW)
        forwarded = next(line for line in WORKFLOW.splitlines() if 'envs:' in line)
        self.assertIn('NVIDIA_API_KEY', forwarded)
        self.assertNotIn('OPENAI_API_KEY', forwarded)

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
