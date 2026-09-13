"""Run the workflow preparation section with a fake container runtime."""

from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / ".github/workflows/deploy-production.yml").read_text()


class DeploymentPreparationTest(unittest.TestCase):
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
