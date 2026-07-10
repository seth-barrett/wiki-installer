# Hermes workspace adapter

This starter is deliberately workspace-first: it does not alter `~/.hermes`, profiles, skills, models, tools, gateway settings, or credentials.

## Start a session

```bash
cd /path/to/your/wiki
hermes
```

At the start of a new session, ask Hermes to read and follow `AGENTS.md`. The portable skill is also available at `Agent-Skills/llm-wiki/SKILL.md` if you want to load or adapt it for your own Hermes profile.

## What this adapter does not do

- It does not install a global Hermes skill.
- It does not create a webhook, cron job, service, MCP server, or database.
- It does not change model/provider configuration.

That is intentional. A wiki starter should create a safe knowledge workspace, not quietly rewire somebody's agent.
