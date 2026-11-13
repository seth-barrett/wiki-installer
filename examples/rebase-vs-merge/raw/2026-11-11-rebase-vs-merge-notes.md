# rebase vs merge - notes after the release branch mess

(sample source written for the wiki-installer demo; not a real team)

- lost ~half a day tuesday bc two people rebased the shared release branch and force pushed. commits "disappeared" (they were still in reflog, recovered)
- rule we agreed: never rebase a branch someone else has pulled. rebase rewrites commits = new hashes, anyone who based work on the old ones is now diverged
- merge keeps both histories + adds a merge commit. safe on shared branches. downside: history gets noisy, lots of "Merge branch main into..." commits
- rebase = replay my commits on top of latest main. linear history, easier git bisect, easier to read the log
- compromise: rebase your OWN feature branch locally before opening the PR, then merge (or squash-merge) into main
- if you must force push your own branch: --force-with-lease not --force. it refuses if the remote moved since you last fetched
- open q: squash merge vs merge commit for PRs? squash loses per-commit detail but main stays 1 commit per PR. not decided
- todo: branch protection on release/* so force push is blocked
