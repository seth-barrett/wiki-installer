"""Release trust-anchor consistency tests."""

from __future__ import annotations

import base64
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ReleaseTrustAnchorTests(unittest.TestCase):
    def test_bootstrap_embeds_the_committed_public_key(self) -> None:
        public_key = (ROOT / "keys/release-public-key.pem").read_text(encoding="utf-8")
        bootstrap = (ROOT / "bootstrap.sh").read_text(encoding="utf-8")

        self.assertIn(public_key.strip(), bootstrap)

    def test_readme_pins_the_committed_public_key(self) -> None:
        public_key = (ROOT / "keys/release-public-key.pem").read_bytes()
        expected_base64 = base64.b64encode(public_key).decode("ascii")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")

        self.assertIn(expected_base64, readme)

    def test_bootstrap_version_matches_release_version(self) -> None:
        version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        bootstrap = (ROOT / "bootstrap.sh").read_text(encoding="utf-8")

        self.assertRegex(bootstrap, rf'readonly VERSION="{re.escape(version)}"')
    def test_workflows_use_immutable_action_pins(self) -> None:
        expected_actions = {
            "actions/checkout": "9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0",
            "actions/setup-python": "ece7cb06caefa5fff74198d8649806c4678c61a1",
        }
        for workflow_name in ("ci.yml", "release.yml"):
            workflow = (ROOT / ".github" / "workflows" / workflow_name).read_text(
                encoding="utf-8"
            )
            for action, revision in expected_actions.items():
                self.assertIn(f"uses: {action}@{revision}", workflow)

    def test_release_workflow_requires_a_protected_environment(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("environment: release", workflow)

    def test_release_workflow_dispatches_from_protected_main(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("workflow_dispatch:", workflow)
        self.assertIn("release_tag:", workflow)
        self.assertIn("RELEASE_TAG: ${{ inputs.release_tag }}", workflow)
        self.assertNotIn('tags: ["v*"]', workflow)

    def test_gitignore_blocks_private_key_and_environment_files(self) -> None:
        ignore_rules = (ROOT / ".gitignore").read_text(encoding="utf-8")
        for rule in (".env", ".env.*", "*.pem", "*.key"):
            self.assertIn(rule, ignore_rules)
        self.assertIn("!keys/release-public-key.pem", ignore_rules)


if __name__ == "__main__":
    unittest.main()
