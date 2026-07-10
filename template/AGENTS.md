# LLM Wiki Operating Rules

This folder is a compounding knowledge base. Keep its source material, compiled knowledge, and agent instructions separate.

## Folder contract

- `raw/` is an immutable source archive. Read it, cite it, but never modify, rename, delete, or reorganize its contents.
- `wiki/` is the compiled knowledge layer. Create or update Markdown here when knowledge becomes reusable.
- `wiki/Index.md` is the starting point for broad questions and routing.
- `wiki/Log.md` is the append-only audit trail for meaningful wiki changes.
- `Agent-Skills/` contains portable workflow instructions. `Agent-Adapters/` contains optional, agent-specific launch guidance.

## Before editing

1. Start with `wiki/Index.md`, then read only the relevant topic pages.
2. Treat `raw/` as evidence, not as a conclusion. Do not invent claims, sources, or citations.
3. Check whether an existing page should be updated before creating a new page.
4. Ask before destructive, bulk, external, credential, cost-incurring, or runtime-affecting actions.

## When writing the wiki

- Prefer small, connected updates over one page per source.
- For new Markdown pages, use a clear title, brief purpose, source references when applicable, and useful wikilinks.
- Update `wiki/Index.md` when a new page changes routing or discoverability.
- Append a concise dated entry to `wiki/Log.md` for meaningful changes.
- Keep personal data, credentials, secrets, and private operational details out of shared/exportable wiki content.
- Use temporary rollback only while a multi-file change is in progress; do not create automatic persistent backup clutter.

## Verification

After structural edits, run:

```bash
python3 scripts/validate_vault.py .
```

Fix broken wikilinks and missing required structure before declaring the wiki healthy.
