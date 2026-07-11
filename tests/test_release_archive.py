"""Adversarial tests for the Linux release archive contract."""

from __future__ import annotations

import io
import tarfile
import tempfile
import unittest
from pathlib import Path

from scripts.release_archive import validate_tar_archive


class ReleaseArchiveTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.archive_path = Path(self.temporary_directory.name) / "release.tar.gz"
        self.root = "wiki-installer-0.1.5"

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def _write_archive(self, entries: list[tarfile.TarInfo] | None = None) -> None:
        with tarfile.open(self.archive_path, mode="w:gz") as archive:
            root_entry = tarfile.TarInfo(self.root)
            root_entry.type = tarfile.DIRTYPE
            root_entry.mode = 0o700
            archive.addfile(root_entry)

            installer_bytes = b"#!/usr/bin/env bash\nexit 0\n"
            installer_entry = tarfile.TarInfo(f"{self.root}/install.sh")
            installer_entry.size = len(installer_bytes)
            installer_entry.mode = 0o700
            archive.addfile(installer_entry, io.BytesIO(installer_bytes))

            for entry in entries or []:
                data = io.BytesIO(b"payload") if entry.isreg() else None
                if data is not None:
                    entry.size = len(data.getvalue())
                archive.addfile(entry, data)

    def test_accepts_a_safe_archive_contract(self) -> None:
        readme = tarfile.TarInfo(f"{self.root}/README.md")
        readme.mode = 0o600
        self._write_archive([readme])

        validate_tar_archive(self.archive_path, self.root)

    def test_rejects_link_and_special_members(self) -> None:
        for label, member_type in (
            ("symlink", tarfile.SYMTYPE),
            ("hardlink", tarfile.LNKTYPE),
            ("fifo", tarfile.FIFOTYPE),
        ):
            with self.subTest(member=label):
                member = tarfile.TarInfo(f"{self.root}/{label}")
                member.type = member_type
                member.linkname = "/tmp/outside"
                member.mode = 0o700
                self._write_archive([member])

                with self.assertRaisesRegex(ValueError, "unsafe entry"):
                    validate_tar_archive(self.archive_path, self.root)

    def test_rejects_unsafe_paths_duplicate_members_and_modes(self) -> None:
        cases: list[tuple[str, list[tarfile.TarInfo], str]] = []

        traversal = tarfile.TarInfo("../escape")
        traversal.mode = 0o600
        cases.append(("traversal", [traversal], "unsafe path"))

        unexpected_root = tarfile.TarInfo("other-root/README.md")
        unexpected_root.mode = 0o600
        cases.append(("unexpected root", [unexpected_root], "unexpected root"))

        duplicate_one = tarfile.TarInfo(f"{self.root}/README.md")
        duplicate_one.mode = 0o600
        duplicate_two = tarfile.TarInfo(f"{self.root}/README.md")
        duplicate_two.mode = 0o600
        cases.append(("duplicate", [duplicate_one, duplicate_two], "duplicate path"))

        world_readable = tarfile.TarInfo(f"{self.root}/README.md")
        world_readable.mode = 0o744
        cases.append(("unsafe mode", [world_readable], "unsafe permissions"))

        for label, entries, message in cases:
            with self.subTest(case=label):
                self._write_archive(entries)

                with self.assertRaisesRegex(ValueError, message):
                    validate_tar_archive(self.archive_path, self.root)


if __name__ == "__main__":
    unittest.main()
