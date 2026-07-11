"""Release trust-anchor consistency tests."""

from __future__ import annotations

import base64
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ReleaseTrustAnchorTests(unittest.TestCase):
    @staticmethod
    def _release_job_blocks(workflow: str) -> dict[str, str]:
        jobs_section = workflow.split("\njobs:\n", maxsplit=1)[1]
        job_headers = list(re.finditer(r"(?m)^  (?P<name>[a-z][a-z-]*):\n", jobs_section))
        return {
            header.group("name"): jobs_section[
                header.start() : job_headers[index + 1].start()
                if index + 1 < len(job_headers)
                else len(jobs_section)
            ]
            for index, header in enumerate(job_headers)
        }

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

    def test_release_workflow_waits_for_the_windows_starter_gate(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text(
            encoding="utf-8"
        )

        self.assertIn("windows-starter:", workflow)
        self.assertIn("needs: windows-starter", workflow)

    def test_release_workflow_dispatches_from_main_with_explicit_tag(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("workflow_dispatch:", workflow)
        self.assertIn("release_tag:", workflow)
        self.assertIn("RELEASE_TAG: ${{ inputs.release_tag }}", workflow)
        self.assertNotIn('tags: ["v*"]', workflow)
        self.assertNotIn("protected main commit", workflow)

    def test_release_workflow_uses_trusted_main_and_least_privilege(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "release.yml").read_text(
            encoding="utf-8"
        )
        jobs = self._release_job_blocks(workflow)
        self.assertEqual(set(jobs), {"windows-starter", "publish"})
        windows_job = jobs["windows-starter"]
        publish_job = jobs["publish"]

        self.assertIn("permissions:\n  contents: read", workflow)
        write_capable_jobs = [
            name for name, job in jobs.items() if "      contents: write" in job
        ]
        self.assertEqual(write_capable_jobs, ["publish"])
        self.assertIn("environment: release", publish_job)
        self.assertIn("if: github.ref == 'refs/heads/main'", windows_job)
        self.assertIn("permissions:\n      contents: read", windows_job)
        self.assertIn("ref: refs/heads/main", windows_job)
        self.assertNotIn("contents: write", windows_job)
        self.assertIn("if: github.ref == 'refs/heads/main'", publish_job)
        self.assertIn("permissions:\n      contents: write", publish_job)
        self.assertIn("ref: refs/heads/main", publish_job)
        self.assertEqual(workflow.count("ref: refs/heads/main"), 2)
        self.assertIn(
            "main_commit=$(git ls-remote --exit-code origin refs/heads/main | awk '{print $1}')",
            publish_job,
        )
        self.assertIn('test "$main_commit" = "$(git rev-parse HEAD)"', publish_job)
        self.assertIn(
            'tag_commit=$(git ls-remote --exit-code --tags origin "refs/tags/$RELEASE_TAG^{}" | awk \'{print $1}\')',
            publish_job,
        )
        self.assertIn('test "$tag_commit" = "$main_commit"', publish_job)

    def test_package_release_verifies_the_built_tar_before_signing(self) -> None:
        package_script = (ROOT / "scripts/package_release.sh").read_text(encoding="utf-8")

        tar_creation = package_script.index("tar \\")
        tar_verification = package_script.index("verify-tar")
        manifest_creation = package_script.index(
            'python3 "$PROJECT_ROOT/scripts/release_manifest.py"', tar_verification
        )
        self.assertLess(tar_creation, tar_verification)
        self.assertLess(tar_verification, manifest_creation)
        self.assertIn('--archive "$archive"', package_script[tar_verification:manifest_creation])
        self.assertIn('--root "$payload_name"', package_script[tar_verification:manifest_creation])

    def test_windows_documentation_states_its_non_signature_boundary(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        windows_section = readme.split("## Optional: Linux and WSL installer", maxsplit=1)[0]

        self.assertIn("does not verify the Ed25519 release signature", windows_section)
        self.assertIn("not independent publisher authentication", windows_section)
        self.assertNotIn("Add-Type -TypeDefinition", windows_section)

    def test_security_policy_uses_enabled_private_reporting(self) -> None:
        security_policy = (ROOT / "SECURITY.md").read_text(encoding="utf-8")

        self.assertIn(
            "Use the repository's **Security** tab and select **Report a vulnerability**.",
            security_policy,
        )
        self.assertIn(
            "does not authenticate the ZIP bytes in the default Windows flow",
            security_policy,
        )
        self.assertNotIn("once it is published", security_policy)

    def test_starter_is_harness_neutral(self) -> None:
        template = ROOT / "template"
        start_here = (template / "START_HERE.md").read_text(encoding="utf-8")
        claude_instructions = (template / "CLAUDE.md").read_text(encoding="utf-8")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")

        self.assertIn("Read and follow `AGENTS.md`", claude_instructions)
        self.assertIn("Claude Code", start_here)
        self.assertIn("Codex", start_here)
        self.assertIn("llm-wiki-starter-", readme)
        self.assertIn("Optional: Linux and WSL installer", readme)

    def test_gitignore_blocks_private_key_and_environment_files(self) -> None:
        ignore_rules = (ROOT / ".gitignore").read_text(encoding="utf-8")
        for rule in (".env", ".env.*", "*.pem", "*.key"):
            self.assertIn(rule, ignore_rules)
        self.assertIn("!keys/release-public-key.pem", ignore_rules)


if __name__ == "__main__":
    unittest.main()
