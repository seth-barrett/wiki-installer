# Start Here

This is a plain Markdown folder. It works as an Obsidian vault and as a project folder for any AI-agent harness. You do not need WSL, Hermes, a public key, or an installer to use the vault itself.

## First five minutes

1. Extract the `llm-wiki-starter-<version>.zip` release asset anywhere you normally keep personal files. On Windows, a folder under `Documents` is fine.
2. Install [Obsidian](https://obsidian.md/download) if you want a desktop editor. In Obsidian, choose **Open folder as vault** and select this folder. Do not create a second vault inside it.
3. Keep original sources in `raw/`. They are evidence; do not rewrite them after capture.
4. Start your preferred agent in this folder, then tell it to read `AGENTS.md` before it changes anything.
5. Use `wiki/Index.md` to find the right topic page, and review `wiki/Log.md` to see meaningful changes.

## Use any agent harness

- **Claude Code:** start it in this folder. `CLAUDE.md` directs it to the shared `AGENTS.md` contract.
- **Codex:** start it in this folder and let it follow `AGENTS.md`.
- **Hermes:** use it on Linux, macOS, or WSL. On Windows, Hermes can work from WSL against a vault stored in your Windows home folder, for example `/mnt/c/Users/<windows-user>/Documents/llm-wiki`.
- **Another harness:** paste this at the start of a session:

  ```text
  Read START_HERE.md and AGENTS.md. Follow those rules before editing this vault.
  ```

The vault is not tied to any one agent. The optional `Agent-Skills/llm-wiki/SKILL.md` is reference material, not a global installation or configuration requirement.

## Optional signed installer: Linux or WSL only

The project also provides an optional signed Bash installer for people who want a new private vault created automatically on a Linux filesystem. That installer uses a public key because it downloads and executes code; the plain starter ZIP does not execute anything and does not require key verification.

Do not use that installer from Windows PowerShell, CMD, or Git Bash. If you use it on Windows, run it inside WSL and install into the Linux home directory, such as `~/llm-wiki`, rather than `/mnt/c/...`.

## Privacy baseline

- This vault is private by default. Do not publish `raw/`, agent configuration, credentials, or notes without reviewing them first.
- A remote model may receive the files you ask it to read. Choose the model/provider deliberately.
- This starter does not initialize Git inside the vault. If you later add Git, make the repository private unless you intentionally sanitize the content for publication.

## Check the structure

From this directory:

```bash
python3 scripts/validate_vault.py .
```

That confirms the expected folders and Obsidian wikilinks are intact.
