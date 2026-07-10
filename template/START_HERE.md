# Start Here

This folder is a private, Obsidian-compatible Markdown vault for you and your AI agent. The vault is plain files: Obsidian is optional, but it is the recommended desktop app for browsing and editing them.

## First five minutes

1. Install [Obsidian](https://obsidian.md/download) if you want a desktop editor.
2. In Obsidian, choose **Open folder as vault** and select this folder. Do not create a second vault inside it.
3. Keep original sources in `raw/`. They are evidence; do not rewrite them after capture.
4. Start your AI agent from this folder, then tell it to read `AGENTS.md` before it changes anything.
5. Use `wiki/Index.md` to find the right topic page, and review `wiki/Log.md` to see meaningful changes.

## Windows users: run the installer in WSL2

The installer and agent workflow are Linux-based. On Windows, use Ubuntu through WSL2 rather than PowerShell or Git Bash.

1. In an elevated PowerShell window, install WSL2 and Ubuntu:

   ```powershell
   wsl --install -d Ubuntu
   ```

   Restart if Windows requests it, then launch **Ubuntu** and create the Linux username/password.
2. In the Ubuntu terminal, install the installer prerequisites:

   ```bash
   sudo apt update && sudo apt install -y python3 curl openssl tar gzip
   ```

3. Run the signed installer command from the project README **inside Ubuntu**. Keep the vault in your Linux home directory, for example `~/llm-wiki`; do **not** use `/mnt/c/...`. The installer’s atomic safety guarantee depends on the Linux filesystem.
4. In Windows Obsidian, choose **Open folder as vault** and use this network path, replacing the placeholders:

   ```text
   \\wsl.localhost\Ubuntu\home\<linux-user>\llm-wiki
   ```

   If that alias does not resolve, use `\\wsl$\Ubuntu\home\<linux-user>\llm-wiki` instead. If your distribution has a different name, run `wsl -l -v` in PowerShell and substitute that name.
5. Install and run your chosen agent inside Ubuntu from the vault directory. For Hermes, use the current [Hermes installation documentation](https://hermes-agent.nousresearch.com/docs), then run `cd ~/llm-wiki && hermes`.

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
