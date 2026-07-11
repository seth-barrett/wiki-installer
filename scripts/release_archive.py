#!/usr/bin/env python3
"""Preflight release inputs and validate the Linux release archive contract."""

from __future__ import annotations

import argparse
import os
import stat
import tarfile
from pathlib import Path, PurePosixPath


def _validate_entry(path: Path) -> None:
    mode = path.lstat().st_mode
    if stat.S_ISLNK(mode):
        raise ValueError(f"Release input contains a symlink: {path}")
    if not (stat.S_ISDIR(mode) or stat.S_ISREG(mode)):
        raise ValueError(f"Release input contains an unsafe entry: {path}")


def validate_release_input(path: Path) -> None:
    """Reject symlinks and special files without following any source links."""
    _validate_entry(path)
    if not path.is_dir():
        return

    for parent, directories, files in os.walk(path, followlinks=False):
        parent_path = Path(parent)
        for name in [*directories, *files]:
            _validate_entry(parent_path / name)


def validate_tar_archive(archive_path: Path, expected_root: str) -> None:
    """Require a single safe payload root containing an executable installer."""
    seen: set[str] = set()
    installer_path = f"{expected_root}/install.sh"
    installer_is_regular = False

    try:
        with tarfile.open(archive_path, mode="r:gz") as archive:
            for member in archive.getmembers():
                path = PurePosixPath(member.name)
                normalized = path.as_posix()
                if not normalized or path.is_absolute() or ".." in path.parts:
                    raise ValueError(f"Release archive contains an unsafe path: {member.name}")
                if normalized in seen:
                    raise ValueError(f"Release archive contains a duplicate path: {member.name}")
                seen.add(normalized)
                if normalized != expected_root and not normalized.startswith(expected_root + "/"):
                    raise ValueError(f"Release archive has an unexpected root: {member.name}")
                if not (member.isdir() or member.isreg()):
                    raise ValueError(f"Release archive contains an unsafe entry: {member.name}")
                if member.mode & 0o077:
                    raise ValueError(f"Release archive has unsafe permissions: {member.name}")
                if normalized == installer_path and member.isreg():
                    installer_is_regular = True
    except (OSError, tarfile.TarError) as error:
        raise ValueError(f"Unable to inspect release archive: {archive_path}") from error

    if not installer_is_regular:
        raise ValueError("Release archive is missing a regular install.sh")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    preflight = subparsers.add_parser("preflight", help="validate source inputs")
    preflight.add_argument("paths", nargs="+", type=Path)

    verify_tar = subparsers.add_parser("verify-tar", help="validate a built tar.gz archive")
    verify_tar.add_argument("--archive", required=True, type=Path)
    verify_tar.add_argument("--root", required=True)

    arguments = parser.parse_args(argv)
    try:
        if arguments.command == "preflight":
            for path in arguments.paths:
                validate_release_input(path)
        else:
            validate_tar_archive(arguments.archive, arguments.root)
    except ValueError as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
