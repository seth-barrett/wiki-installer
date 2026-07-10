#!/usr/bin/env python3
"""Validate the portable LLM-wiki's required structure and wikilinks."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

REQUIRED_DIRECTORIES = (
    "raw",
    "wiki/Concepts",
    "wiki/Topics",
    "wiki/Code-Patterns",
    "wiki/Comparisons",
    "wiki/Temporal-Trackers",
)
REQUIRED_FILES = (
    "AGENTS.md",
    "START_HERE.md",
    "wiki/Index.md",
    "wiki/Log.md",
)
WIKILINK_PATTERN = re.compile(r"\[\[([^\]]+)\]\]")


@dataclass(frozen=True)
class ValidationResult:
    issues: list[str]

    @property
    def valid(self) -> bool:
        return not self.issues


def _target_from_link(link: str) -> str:
    """Return the target part of an Obsidian-style wikilink."""
    return link.split("|", maxsplit=1)[0].split("#", maxsplit=1)[0].strip()


def _is_safe_target(target: str) -> bool:
    path = Path(target)
    return bool(target) and not path.is_absolute() and ".." not in path.parts


def _all_wiki_pages(wiki_root: Path) -> list[Path]:
    return sorted(wiki_root.rglob("*.md")) if wiki_root.is_dir() else []


def _resolves_target(target: str, wiki_root: Path, pages: list[Path]) -> bool:
    """Resolve either a path-qualified link or an unambiguous basename."""
    if not _is_safe_target(target):
        return False

    normalized = target.removesuffix(".md")
    if "/" in normalized:
        return (wiki_root / f"{normalized}.md").is_file()

    matches = [page for page in pages if page.stem == normalized]
    return len(matches) == 1


def validate_vault(root: Path) -> ValidationResult:
    """Return structural and wikilink issues for an LLM-wiki root."""
    root = root.expanduser().resolve()
    issues: list[str] = []

    if not root.is_dir():
        return ValidationResult([f"Vault root is not a directory: {root}"])

    for relative_path in REQUIRED_DIRECTORIES:
        if not (root / relative_path).is_dir():
            issues.append(f"Missing required directory: {relative_path}")

    for relative_path in REQUIRED_FILES:
        if not (root / relative_path).is_file():
            issues.append(f"Missing required file: {relative_path}")

    wiki_root = root / "wiki"
    pages = _all_wiki_pages(wiki_root)
    for page in pages:
        relative_page = page.relative_to(root).as_posix()
        content = page.read_text(encoding="utf-8")
        for raw_link in WIKILINK_PATTERN.findall(content):
            target = _target_from_link(raw_link)
            if not _resolves_target(target, wiki_root, pages):
                issues.append(f"Broken wikilink in {relative_page}: [[{raw_link}]]")

    return ValidationResult(issues)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate a portable LLM-wiki directory."
    )
    parser.add_argument("vault", type=Path, help="Path to the wiki root")
    arguments = parser.parse_args(argv)

    result = validate_vault(arguments.vault)
    if result.valid:
        print(f"PASS: {arguments.vault.expanduser().resolve()}")
        return 0

    print("FAIL:")
    for issue in result.issues:
        print(f"- {issue}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
