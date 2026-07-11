#!/usr/bin/env python3
"""Create a canonical, signed-release manifest for release artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

SEMVER_PATTERN = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--starter-archive", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args(argv)

    if not SEMVER_PATTERN.fullmatch(arguments.version):
        parser.error("--version must be MAJOR.MINOR.PATCH")

    archive = arguments.archive.resolve()
    expected_name = f"wiki-installer-{arguments.version}.tar.gz"
    if not archive.is_file() or archive.name != expected_name:
        parser.error(f"--archive must be an existing {expected_name} file")

    starter_archive = arguments.starter_archive.resolve()
    expected_starter_name = f"llm-wiki-starter-{arguments.version}.zip"
    if not starter_archive.is_file() or starter_archive.name != expected_starter_name:
        parser.error(
            f"--starter-archive must be an existing {expected_starter_name} file"
        )

    manifest = {
        "archive": {
            "name": archive.name,
            "sha256": sha256(archive),
            "size": archive.stat().st_size,
        },
        "starter_archive": {
            "name": starter_archive.name,
            "sha256": sha256(starter_archive),
            "size": starter_archive.stat().st_size,
        },
        "version": arguments.version,
    }
    arguments.output.write_text(
        json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
