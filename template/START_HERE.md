# Start Here

This is a plain Markdown folder. On Windows, open it directly in Obsidian and start your preferred agent from this same folder. You do not need WSL, Hermes, signature verification, or another installer to use it.

## Windows first

1. In [Obsidian](https://obsidian.md/download), choose **Open folder as vault** and select this folder. Do not create a second vault inside it.
2. Keep original sources in `raw/`. They are evidence; do not rewrite them after capture.
3. Start your agent in this folder, then tell it to read `AGENTS.md` before it changes anything.
4. Use `wiki/Index.md` to find a topic page and `wiki/Log.md` to see meaningful changes.

## Use any agent harness

- **Claude Code:** start it here. `CLAUDE.md` directs it to the shared `AGENTS.md` contract.
- **Codex:** start it here and let it follow `AGENTS.md`.
- **Another harness:** paste this at the start of a session:

  ```text
  Read START_HERE.md and AGENTS.md. Follow those rules before editing this vault.
  ```

- **Hermes:** optional. It is not required for this vault. If you already use Hermes from WSL, it can work against a vault stored in your Windows home folder.

The vault is not tied to any one agent. The optional `Agent-Skills/llm-wiki/SKILL.md` is reference material, not a global installation or configuration requirement.

## Optional: Linux and WSL installer

The project also provides a signed Bash installer for people who deliberately want a new private vault created on a Linux filesystem. It is not part of normal Windows use. If you choose it on Windows, run it inside WSL and install under the Linux home directory (for example `~/llm-wiki`), not `/mnt/c/...`.

That installer uses a public key because it downloads and executes code. The normal starter ZIP does not execute anything. Its exact filename, size, and SHA-256 are also bound by the optional signed release manifest if you want extra provenance checking.

## Privacy baseline

- This vault is private by default. Do not publish `raw/`, agent configuration, credentials, or notes without reviewing them first.
- A remote model may receive files you ask it to read. Choose the model/provider deliberately.
- This starter does not initialize Git inside the vault. If you later add Git, make the repository private unless you intentionally sanitize the content for publication.

## Check the structure

From this directory:

```bash
python3 scripts/validate_vault.py .
```

That confirms the expected folders and Obsidian wikilinks are intact.