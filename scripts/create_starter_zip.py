#!/usr/bin/env python3
"""Build a deterministic starter ZIP from regular files and directories only."""

from __future__ import annotations

import argparse
import os
import stat
import sys
import zipfile
from pathlib import Path

FIXED_TIMESTAMP = (1980, 1, 1, 0, 0, 0)


def _source_entries(source: Path) -> list[Path]:
    """Return sorted source entries, rejecting links and special files first."""
    source_mode = source.lstat().st_mode
    if stat.S_ISLNK(source_mode):
        raise ValueError(f"Starter source must not be a symlink: {source}")
    if not stat.S_ISDIR(source_mode):
        raise ValueError(f"Starter source must be a directory: {source}")

    entries: list[Path] = []
    for parent, directories, files in os.walk(source, followlinks=False):
        parent_path = Path(parent)
        for name in sorted([*directories, *files]):
            path = parent_path / name
            mode = path.lstat().st_mode
            if stat.S_ISLNK(mode):
                raise ValueError(f"Starter source contains a symlink: {path}")
            if not stat.S_ISDIR(mode) and not stat.S_ISREG(mode):
                raise ValueError(f"Starter source contains an unsafe entry: {path}")
            entries.append(path)
    return sorted(entries, key=lambda path: path.relative_to(source).as_posix())


def build_starter_zip(source: Path, archive: Path) -> None:
    """Create a deterministic ZIP without following source links."""
    source = source.absolute()
    archive = archive.absolute()
    entries = _source_entries(source)

    with zipfile.ZipFile(
        archive, mode="w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as bundle:
        for path in entries:
            relative = path.relative_to(source).as_posix()
            name = f"{source.name}/{relative}"
            mode = path.lstat().st_mode
            if stat.S_ISDIR(mode):
                info = zipfile.ZipInfo(f"{name}/", date_time=FIXED_TIMESTAMP)
                info.create_system = 3
                info.external_attr = (0o40700 << 16) | 0x10
                info.compress_type = zipfile.ZIP_DEFLATED
                bundle.writestr(info, b"")
            else:
                info = zipfile.ZipInfo(name, date_time=FIXED_TIMESTAMP)
                info.create_system = 3
                info.external_attr = 0o100600 << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                bundle.writestr(info, path.read_bytes())


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--archive", required=True, type=Path)
    arguments = parser.parse_args(argv)

    try:
        build_starter_zip(arguments.source, arguments.archive)
    except ValueError as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
