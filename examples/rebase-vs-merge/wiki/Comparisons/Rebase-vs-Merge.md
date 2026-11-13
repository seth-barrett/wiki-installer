# Rebase vs Merge

When to rebase and when to merge, and the one rule that prevents lost work.

## The rule

Never rebase a branch someone else has pulled. Rebasing rewrites commits and gives them new hashes, so anyone who based work on the old commits is left diverged.

## Comparison

| | Merge | Rebase |
|---|---|---|
| What it does | Keeps both histories and adds a merge commit | Replays your commits on top of the latest target branch |
| Safe on shared branches | Yes | No |
| Resulting history | Noisy, with many "Merge branch..." commits | Linear (see [[Linear-History]]) |
| Rewrites commit hashes | No | Yes |

## Working agreement

1. Rebase your own feature branch locally before opening a pull request.
2. Merge or squash-merge the pull request into `main`.
3. If you must force-push your own branch, use `--force-with-lease`, not `--force`. It refuses to push if the remote moved since your last fetch.

## What went wrong

Two people rebased the shared release branch and force-pushed. Commits appeared to be lost and cost about half a day. They were recovered from the reflog.

## Open questions

- Squash-merge or merge commit for pull requests? Squashing keeps `main` at one commit per pull request but loses per-commit detail. Not decided.
- Branch protection on `release/*` to block force-pushes is still a to-do.

## Sources

- `raw/2026-11-11-rebase-vs-merge-notes.md`
