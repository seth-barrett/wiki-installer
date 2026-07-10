# My LLM Wiki

A personal knowledge base maintained by you and your AI agent.

## Start here

1. Put source material in `raw/`. Keep it immutable after capture.
2. Start your agent from this folder so it can read `AGENTS.md`.
3. Ask the agent to summarize, connect, or update the compiled pages in `wiki/`.
4. Browse `wiki/Index.md` when you need a route into the knowledge base.

## Hermes

From this folder, run:

```bash
hermes
```

Then ask Hermes to read and follow `AGENTS.md` before working in the wiki. The optional `Agent-Adapters/Hermes.md` file contains the same workspace-safe guidance.

## Safety baseline

- `raw/` is evidence. The agent must not rewrite it.
- `wiki/` is the compiled, editable knowledge layer.
- Never put secrets or credentials in this folder.
- Treat raw material as private by default. Only share sources you are authorized to redistribute.
- A remote model may receive content you ask it to read. Choose your model/provider deliberately and do not send sensitive material without explicit approval.
- Review `wiki/Log.md` when you want to understand what changed and why.
