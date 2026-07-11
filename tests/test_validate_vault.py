"""Behavioral tests for the portable LLM-wiki structure validator."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.validate_vault import validate_vault


class ValidateVaultTests(unittest.TestCase):
    def create_valid_vault(self) -> Path:
        temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(temporary_directory.cleanup)
        root = Path(temporary_directory.name) / "vault"

        for relative_path in (
            "raw",
            "wiki/Concepts",
            "wiki/Topics",
            "wiki/Code-Patterns",
            "wiki/Comparisons",
            "wiki/Temporal-Trackers",
        ):
            (root / relative_path).mkdir(parents=True, exist_ok=True)

        (root / "AGENTS.md").write_text("# Wiki rules\n", encoding="utf-8")
        (root / "CLAUDE.md").write_text("# Claude instructions\n", encoding="utf-8")
        (root / "START_HERE.md").write_text("# Start here\n", encoding="utf-8")
        (root / "wiki/Log.md").write_text("# Wiki log\n", encoding="utf-8")
        (root / "wiki/Topics/Example.md").write_text("# Example\n", encoding="utf-8")
        (root / "wiki/Index.md").write_text(
            "# Index\n\n- [[Topics/Example]]\n", encoding="utf-8"
        )
        return root

    def test_accepts_a_complete_vault_with_a_resolved_path_link(self) -> None:
        root = self.create_valid_vault()

        result = validate_vault(root)

        self.assertTrue(result.valid, result.issues)
        self.assertEqual(result.issues, [])

    def test_reports_missing_required_structure(self) -> None:
        root = self.create_valid_vault()
        (root / "wiki/Log.md").unlink()

        result = validate_vault(root)

        self.assertFalse(result.valid)
        self.assertIn("Missing required file: wiki/Log.md", result.issues)

    def test_reports_a_missing_start_here_guide(self) -> None:
        root = self.create_valid_vault()
        (root / "START_HERE.md").unlink()

        result = validate_vault(root)

        self.assertFalse(result.valid)
        self.assertIn("Missing required file: START_HERE.md", result.issues)

    def test_reports_a_missing_claude_instruction_pointer(self) -> None:
        root = self.create_valid_vault()
        (root / "CLAUDE.md").unlink()

        result = validate_vault(root)

        self.assertFalse(result.valid)
        self.assertIn("Missing required file: CLAUDE.md", result.issues)

    def test_reports_a_broken_wikilink(self) -> None:
        root = self.create_valid_vault()
        (root / "wiki/Index.md").write_text(
            "# Index\n\n- [[Topics/Missing]]\n", encoding="utf-8"
        )

        result = validate_vault(root)

        self.assertFalse(result.valid)
        self.assertIn(
            "Broken wikilink in wiki/Index.md: [[Topics/Missing]]",
            result.issues,
        )

    def test_accepts_an_unambiguous_bare_wikilink(self) -> None:
        root = self.create_valid_vault()
        (root / "wiki/Index.md").write_text(
            "# Index\n\n- [[Example]]\n", encoding="utf-8"
        )

        result = validate_vault(root)

        self.assertTrue(result.valid, result.issues)


if __name__ == "__main__":
    unittest.main()
