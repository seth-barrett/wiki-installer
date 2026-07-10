"""Tests for Linux no-replace workspace placement."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.atomic_install import move_without_replace


class AtomicInstallTests(unittest.TestCase):
    def create_workspace(self, parent: Path) -> Path:
        workspace = parent / "workspace"
        workspace.mkdir()
        (workspace / "sentinel.txt").write_text("verified payload", encoding="utf-8")
        return workspace

    def test_moves_a_workspace_into_a_new_destination(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            stage_parent = root / "stage"
            destination_parent = root / "destination-parent"
            stage_parent.mkdir()
            destination_parent.mkdir()
            self.create_workspace(stage_parent)

            move_without_replace(stage_parent, "workspace", destination_parent, "wiki")

            self.assertFalse((stage_parent / "workspace").exists())
            self.assertEqual(
                (destination_parent / "wiki" / "sentinel.txt").read_text(encoding="utf-8"),
                "verified payload",
            )

    def test_late_destination_symlink_is_not_followed_or_replaced(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            stage_parent = root / "stage"
            destination_parent = root / "destination-parent"
            outside = root / "outside"
            stage_parent.mkdir()
            destination_parent.mkdir()
            outside.mkdir()
            self.create_workspace(stage_parent)
            (destination_parent / "wiki").symlink_to(outside, target_is_directory=True)

            with self.assertRaises(FileExistsError):
                move_without_replace(stage_parent, "workspace", destination_parent, "wiki")

            self.assertTrue((stage_parent / "workspace" / "sentinel.txt").is_file())
            self.assertFalse((outside / "sentinel.txt").exists())

    def test_symlinked_destination_parent_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            stage_parent = root / "stage"
            real_parent = root / "real-parent"
            symlinked_parent = root / "symlinked-parent"
            stage_parent.mkdir()
            real_parent.mkdir()
            symlinked_parent.symlink_to(real_parent, target_is_directory=True)
            self.create_workspace(stage_parent)

            with self.assertRaises(OSError):
                move_without_replace(stage_parent, "workspace", symlinked_parent, "wiki")

            self.assertTrue((stage_parent / "workspace" / "sentinel.txt").is_file())
            self.assertFalse((real_parent / "wiki").exists())


if __name__ == "__main__":
    unittest.main()
