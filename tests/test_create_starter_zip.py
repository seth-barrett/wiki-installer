"""Tests for safe, reproducible starter ZIP creation."""

from __future__ import annotations

import os
import stat
import tempfile
import unittest
import zipfile
from pathlib import Path

from scripts.create_starter_zip import FIXED_TIMESTAMP, build_starter_zip


class CreateStarterZipTests(unittest.TestCase):
    def create_source(self) -> tuple[Path, Path]:
        temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(temporary_directory.cleanup)
        temporary_root = Path(temporary_directory.name)
        source = temporary_root / "llm-wiki-starter-0.1.3"
        source.mkdir()
        (source / "AGENTS.md").write_text("# Rules\n", encoding="utf-8")
        return temporary_root, source

    def test_rejects_a_symlinked_file_before_creating_an_archive(self) -> None:
        temporary_root, source = self.create_source()
        secret = temporary_root / "synthetic-secret.txt"
        secret.write_text("not for the ZIP\n", encoding="utf-8")
        os.symlink(secret, source / "secret-link.txt")
        archive = temporary_root / "starter.zip"

        with self.assertRaisesRegex(ValueError, "symlink"):
            build_starter_zip(source, archive)

        self.assertFalse(archive.exists())

    def test_rejects_a_symlinked_source_root_before_creating_an_archive(self) -> None:
        temporary_root, source = self.create_source()
        symlinked_source = temporary_root / "starter-source-link"
        os.symlink(source, symlinked_source, target_is_directory=True)
        archive = temporary_root / "starter.zip"

        with self.assertRaisesRegex(ValueError, "symlink"):
            build_starter_zip(symlinked_source, archive)

        self.assertFalse(archive.exists())

    def test_rejects_a_symlinked_directory_before_creating_an_archive(self) -> None:
        temporary_root, source = self.create_source()
        secret_directory = temporary_root / "synthetic-private-directory"
        secret_directory.mkdir()
        (secret_directory / "secret.txt").write_text("not for the ZIP\n", encoding="utf-8")
        os.symlink(secret_directory, source / "linked-directory", target_is_directory=True)
        archive = temporary_root / "starter.zip"

        with self.assertRaisesRegex(ValueError, "symlink"):
            build_starter_zip(source, archive)

        self.assertFalse(archive.exists())

    def test_rejects_a_fifo_before_creating_an_archive(self) -> None:
        temporary_root, source = self.create_source()
        os.mkfifo(source / "events.pipe")
        archive = temporary_root / "starter.zip"

        with self.assertRaisesRegex(ValueError, "unsafe entry"):
            build_starter_zip(source, archive)

        self.assertFalse(archive.exists())

    def test_creates_a_reproducible_archive_with_only_safe_entries(self) -> None:
        temporary_root, source = self.create_source()
        (source / "raw").mkdir()
        (source / "raw" / "source.md").write_text("# Source\n", encoding="utf-8")
        first_archive = temporary_root / "first.zip"
        second_archive = temporary_root / "second.zip"

        build_starter_zip(source, first_archive)
        build_starter_zip(source, second_archive)

        self.assertEqual(first_archive.read_bytes(), second_archive.read_bytes())
        with zipfile.ZipFile(first_archive) as bundle:
            entries = bundle.infolist()

        names = [entry.filename for entry in entries]
        expected_root = f"{source.name}/"
        self.assertEqual(names, sorted(names))
        self.assertEqual(len(names), len(set(names)))
        self.assertTrue(all(name.startswith(expected_root) for name in names))
        self.assertTrue(all(".." not in Path(name).parts for name in names))
        for entry in entries:
            self.assertEqual(entry.date_time, FIXED_TIMESTAMP)
            mode = entry.external_attr >> 16
            if entry.is_dir():
                self.assertTrue(stat.S_ISDIR(mode))
            else:
                self.assertTrue(stat.S_ISREG(mode))


if __name__ == "__main__":
    unittest.main()
