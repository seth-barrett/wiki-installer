---
name: llm-wiki
description: Maintain a compounding Markdown knowledge base with immutable raw sources, compiled wiki pages, query routing, and auditable updates.
---

# LLM Wiki

Use this skill when ingesting source material, answering from the wiki, maintaining its structure, or crystallizing durable work into reusable knowledge.

## Workflow

1. Read `AGENTS.md` and `wiki/Index.md` before changing anything.
2. Treat `raw/` as immutable evidence. Never modify it.
3. For a question, route through `wiki/Index.md`, then read the smallest relevant page cluster.
4. For a new source, update existing compiled pages first. Create a new page only when the concept is independently reusable.
5. Keep claims tied to available evidence. Flag uncertainty instead of fabricating certainty.
6. Update `wiki/Index.md` when a change improves routing, and append meaningful changes to `wiki/Log.md`.
7. Run `python3 scripts/validate_vault.py .` after structural edits.

## Boundaries

- Do not put credentials, secrets, or sensitive private data into the wiki.
- Ask before destructive, bulk, external, costly, or runtime-affecting work.
- Do not create automatic persistent backups. Use temporary rollback only during an in-flight multi-file change.
