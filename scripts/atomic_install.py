#!/usr/bin/env python3
"""Atomically move an installer staging directory without replacing a destination."""

from __future__ import annotations

import argparse
import ctypes
import errno
import os
from pathlib import Path

AT_FDCWD = -100
RENAME_NOREPLACE = 1
DIRECTORY_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW


def _validate_name(name: str, label: str) -> None:
    if not name or name in {".", ".."} or Path(name).name != name:
        raise ValueError(f"{label} must be one path component")


def _open_directory_without_symlinks(path: Path) -> int:
    """Open every directory component with O_NOFOLLOW and return a pinned fd."""
    absolute_path = path.absolute()
    descriptor = os.open("/", DIRECTORY_FLAGS)
    try:
        for component in absolute_path.parts[1:]:
            next_descriptor = os.open(component, DIRECTORY_FLAGS, dir_fd=descriptor)
            os.close(descriptor)
            descriptor = next_descriptor
    except BaseException:
        os.close(descriptor)
        raise
    return descriptor


def _rename_noreplace(
    source_directory_fd: int,
    source_name: str,
    destination_directory_fd: int,
    destination_name: str,
) -> None:
    libc = ctypes.CDLL(None, use_errno=True)
    try:
        renameat2 = libc.renameat2
    except AttributeError as error:
        raise OSError(errno.ENOSYS, "renameat2 is unavailable; refusing non-atomic install") from error

    renameat2.argtypes = [
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    ]
    renameat2.restype = ctypes.c_int
    result = renameat2(
        source_directory_fd,
        source_name.encode("utf-8"),
        destination_directory_fd,
        destination_name.encode("utf-8"),
        RENAME_NOREPLACE,
    )
    if result != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, os.strerror(error_number), destination_name)


def move_without_replace(
    source_parent: Path, source_name: str, destination_parent: Path, destination_name: str
) -> None:
    """Move source_parent/source_name to destination_parent/destination_name once only.

    The destination parent is resolved component-by-component without following
    symlinks and the final move uses RENAME_NOREPLACE. Any unsupported or racy
    filesystem fails closed without overwriting or following the destination.
    """
    _validate_name(source_name, "source name")
    _validate_name(destination_name, "destination name")
    source_fd = _open_directory_without_symlinks(source_parent)
    destination_fd = _open_directory_without_symlinks(destination_parent)
    try:
        _rename_noreplace(source_fd, source_name, destination_fd, destination_name)
    finally:
        os.close(source_fd)
        os.close(destination_fd)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-parent", required=True, type=Path)
    parser.add_argument("--source-name", required=True)
    parser.add_argument("--destination-parent", required=True, type=Path)
    parser.add_argument("--destination-name", required=True)
    arguments = parser.parse_args(argv)

    try:
        move_without_replace(
            arguments.source_parent,
            arguments.source_name,
            arguments.destination_parent,
            arguments.destination_name,
        )
    except (OSError, ValueError) as error:
        print(f"ERROR: atomic workspace placement failed: {error}", file=os.sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
