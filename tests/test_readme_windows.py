"""Regression tests for Windows-first public onboarding."""

from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class WindowsReadmeTests(unittest.TestCase):
    def test_windows_is_the_primary_setup_path(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")

        self.assertIn("## Windows (recommended)", readme)
        self.assertLess(
            readme.index("## Windows (recommended)"),
            readme.index("## Optional: Linux and WSL installer"),
        )
        self.assertIn("Open **Windows PowerShell**", readme)

    def test_windows_command_downloads_a_versioned_zip_without_remote_execution(self) -> None:
        version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        readme = (ROOT / "README.md").read_text(encoding="utf-8")

        self.assertIn(f"$v='{version}'", readme)
        self.assertIn(
            "https://github.com/seth-barrett/wiki-installer/releases/download/v$v/"
            "llm-wiki-starter-$v.zip",
            readme,
        )
        self.assertIn("Invoke-WebRequest", readme)
        self.assertIn("ZipFile]::OpenRead", readme)
        self.assertIn("unsafe ZIP member", readme)
        self.assertIn("duplicate ZIP entry", readme)
        self.assertNotIn("irm ", readme.lower())
        self.assertNotIn("| iex", readme.lower())

    def test_windows_setup_script_has_a_testable_archive_input(self) -> None:
        script = (ROOT / "scripts" / "install_windows.ps1").read_text(encoding="utf-8")

        self.assertIn("[string]$ArchivePath", script)
        self.assertIn("[System.IO.Directory]::Move", script)
        self.assertIn("Destination must be new", script)


if __name__ == "__main__":
    unittest.main()
