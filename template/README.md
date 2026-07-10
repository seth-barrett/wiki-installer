# My LLM Wiki

A personal knowledge base maintained by you and whichever AI agent you choose.

## Start here

Read `START_HERE.md` first. It explains native Windows/macOS/Linux setup, Obsidian, privacy, and how to use this folder with Claude Code, Codex, Hermes, or another harness.

1. Put source material in `raw/`. Keep it immutable after capture.
2. Start your agent from this folder so it can read `AGENTS.md`.
3. Ask the agent to summarize, connect, or update the compiled pages in `wiki/`.
4. Browse `wiki/Index.md` when you need a route into the knowledge base.

## Use any agent harness

- **Codex:** start it in this folder; it can follow `AGENTS.md`.
- **Claude Code:** start it in this folder; `CLAUDE.md` points it to the shared `AGENTS.md` contract.
- **Hermes:** start it in this folder on Linux, macOS, or WSL. Its optional workspace adapter is not required for the vault to work.
- **Anything else:** tell it: “Read `START_HERE.md` and `AGENTS.md`, then follow those rules before editing.”

## Safety baseline

- `raw/` is evidence. The agent must not rewrite it.
- `wiki/` is the compiled, editable knowledge layer.
- Never put secrets or credentials in this folder.
- Treat raw material as private by default. Only share sources you are authorized to redistribute.
- A remote model may receive content you ask it to read. Choose your model/provider deliberately and do not send sensitive material without explicit approval.
- Review `wiki/Log.md` when you want to understand what changed and why.
