# Linear History

A commit history with no merge commits, where each commit follows the previous one in a single line.

## Why it matters

- `git bisect` is easier to run.
- The log is easier to read.

## How to get it

- Rebase your own feature branch onto the latest `main` before opening a pull request.
- Squash-merge pull requests so `main` holds one commit per pull request. This loses per-commit detail.

## The cost

Rebasing rewrites commit hashes, so it is only safe on branches nobody else has pulled. See [[Rebase-vs-Merge]] for the rule and the comparison.

## Sources

- `raw/2026-11-11-rebase-vs-merge-notes.md`
