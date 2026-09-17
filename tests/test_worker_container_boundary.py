"""Validate the closed qualification interface; real enforcement has separate probes."""

import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "platform/scripts"))
from container_boundary import qualification_boundary, runtime_environment


class BoundaryContractTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.fixture = Path(self.temp.name) / "fixture.py"
        self.fixture.write_text("print('fixture')\n")
        self.image = "sha256:" + "a" * 64

    def test_mutable_or_injected_image_and_invalid_deadline_rejected(self):
        for image in ("python:latest", "--privileged", self.image + " --network=host", None):
            with self.subTest(image=image), self.assertRaises(ValueError):
                qualification_boundary(image, self.fixture)
        for seconds in (0, -1, 61, True, "10"):
            with self.subTest(seconds=seconds), self.assertRaises(ValueError):
                qualification_boundary(self.image, self.fixture, seconds)

    def test_unsafe_fixture_mounts_rejected(self):
        link = self.fixture.parent / "link.py"
        link.symlink_to(self.fixture)
        for path in (link, self.fixture.parent, self.fixture.parent / "missing.py", "/tmp/bad:mount"):
            with self.subTest(path=str(path)), self.assertRaises(ValueError):
                qualification_boundary(self.image, path)

    def test_unique_names_and_single_read_only_file_mount(self):
        first = qualification_boundary(self.image, self.fixture)
        second = qualification_boundary(self.image, self.fixture)
        self.assertNotEqual(first.name, second.name)
        self.assertEqual(first.argv.count("--volume"), 1)
        self.assertEqual(first.argv[first.argv.index("--volume") + 1], f"{self.fixture}:/fixture.py:ro,Z")
        self.assertNotIn("--privileged", first.argv)
        self.assertNotIn("--network=host", first.argv)

    def test_runtime_does_not_inherit_credentials_or_remote_endpoint(self):
        with patch.dict(os.environ, {"GH_TOKEN": "fixture", "NVIDIA_API_KEY": "fixture", "CONTAINER_HOST": "ssh://wrong", "PYTHONPATH": "/untrusted"}):
            environment = runtime_environment()
        self.assertFalse({"GH_TOKEN", "NVIDIA_API_KEY", "CONTAINER_HOST", "PYTHONPATH"} & environment.keys())


if __name__ == "__main__":
    unittest.main()
