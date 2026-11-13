# Example: one messy note in, two linked pages out

This folder is the result of a real run of the starter, kept so you can see the output before installing anything.

## What was done

1. A fresh vault was created with `install.sh`.
2. One source was dropped into `raw/`: [`2026-11-11-rebase-vs-merge-notes.md`](raw/2026-11-11-rebase-vs-merge-notes.md). It is a sample note written for this demo, not a real team's notes.
3. An AI agent was started in the vault and followed `AGENTS.md` to ingest the source.
4. `python3 scripts/validate_vault.py .` passed.

## What the agent produced

- [`wiki/Comparisons/Rebase-vs-Merge.md`](wiki/Comparisons/Rebase-vs-Merge.md): the rule, a comparison table, the working agreement and the open questions.
- [`wiki/Concepts/Linear-History.md`](wiki/Concepts/Linear-History.md): a reusable concept page that links back to the comparison.
- [`wiki/Index.md`](wiki/Index.md): two new entries in the knowledge map.
- [`wiki/Log.md`](wiki/Log.md): a dated entry recording what changed.

The source in `raw/` was not modified. Every page cites it.

Only `raw/` and `wiki/` are included here. The empty starter folders and the vault's own instruction files are left out.
