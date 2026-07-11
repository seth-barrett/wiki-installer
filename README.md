# LLM Wiki Starter

A portable, agent-maintained Markdown wiki. It is a normal folder first—not a vendor-specific harness, a surprise automation stack, or an opaque RAG bucket.

## What the starter ZIP contains

```text
my-wiki/
├── AGENTS.md                       # shared operating rules for every harness
├── CLAUDE.md                       # Claude Code pointer to the shared rules
├── START_HERE.md                   # Obsidian, agent, privacy, and platform setup
├── raw/                            # immutable source archive
├── wiki/                           # compiled, linked knowledge
│   ├── Index.md                    # query routing
│   ├── Log.md                      # meaningful-change log
│   ├── Concepts/
│   ├── Topics/
│   ├── Code-Patterns/
│   ├── Comparisons/
│   └── Temporal-Trackers/
├── Agent-Skills/llm-wiki/SKILL.md # optional portable workflow reference
└── scripts/validate_vault.py       # local structure/link validator
```

## Default: download the cross-platform starter ZIP

After `v0.1.3` is published, download [llm-wiki-starter-0.1.3.zip](https://github.com/seth-barrett/wiki-installer/releases/download/v0.1.3/llm-wiki-starter-0.1.3.zip), extract it anywhere you keep personal files, and open the inner `llm-wiki-starter-0.1.3` folder as an Obsidian vault.

This is the normal path for Windows, macOS, and Linux. It executes no downloaded code, uses no public key by default, and does not require WSL or Hermes.

### Windows

1. Extract the ZIP under `Documents` or another private folder.
2. Install [Obsidian](https://obsidian.md/download), then select **Open folder as vault** and choose the inner `llm-wiki-starter-0.1.3` folder, not its parent.
3. Start whichever agent harness you use from that folder.

### Choose any agent harness

- **Codex:** start it in the vault root; it can follow `AGENTS.md`.
- **Claude Code:** start it in the vault root; `CLAUDE.md` points it to the shared rules in `AGENTS.md`.
- **Hermes:** use it on Linux, macOS, or WSL. On Windows, Hermes can use a vault stored in your Windows home folder through `/mnt/c/...`.
- **Anything else:** begin with: “Read `START_HERE.md` and `AGENTS.md`, then follow those rules before editing this vault.”

The starter never installs or configures an agent. `Agent-Skills/` is optional reference material, not a global skill installation.

### Optional ZIP provenance verification

Routine use only needs the ZIP. For a higher trust bar, the release’s signed `release-manifest.json` also binds `starter_archive` to the ZIP’s exact filename, size, and SHA-256. Verify that manifest with the published Ed25519 key, then compare its `starter_archive.sha256` with your downloaded file (`Get-FileHash` in PowerShell or `sha256sum` on Unix). This is optional because opening the ZIP does not execute code; it is available when you want authenticity beyond normal GitHub transport/account trust.

## Optional signed installer: Linux or WSL only

The project also offers a signed Bash installer for people who want a new private vault created automatically on a Linux filesystem. It is optional convenience—not a prerequisite for the vault, Obsidian, Claude Code, Codex, or other harnesses.

The installer uses Linux `renameat2` to prevent an attacker from redirecting the target directory. Because it downloads and executes code, its bootstrap embeds a public key and verifies the signed release manifest before extraction. The same manifest also optionally authenticates the starter ZIP; the public key is never required to simply use the folder.

Run this only in Linux or WSL, not Windows PowerShell, CMD, Git Bash, macOS, or a `/mnt/c/...` target:

```bash
(v=v0.1.3; d=$(mktemp -d); trap 'rm -rf "$d"' EXIT; k='LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUNvd0JRWURLMlZ3QXlFQVdZV0NUYzZYTlVXcWVyOWpCaVN1UzJhUnZMK25aeWdzWm8weStHMy9Pck09Ci0tLS0tRU5EIFBVQkxJQyBLRVktLS0tLQo='; curl -fsSLo "$d/bootstrap.sh" "https://github.com/seth-barrett/wiki-installer/releases/download/$v/bootstrap.sh" && curl -fsSLo "$d/bootstrap.sh.sig" "https://github.com/seth-barrett/wiki-installer/releases/download/$v/bootstrap.sh.sig" && printf %s "$k" | openssl base64 -d -A > "$d/release-public-key.pem" && openssl pkeyutl -verify -pubin -inkey "$d/release-public-key.pem" -rawin -in "$d/bootstrap.sh" -sigfile "$d/bootstrap.sh.sig" && bash "$d/bootstrap.sh" --path "$HOME/llm-wiki" --yes)
```

The authenticated bootstrap verifies the signed release manifest, exact archive size, SHA-256, and tar-entry safety before extraction or installation. It is not `curl | bash`; that would execute the one file we need to authenticate. The optional `--agent hermes` flag only adds a workspace-local Hermes note; it never configures Hermes globally.

## Safety behavior

- The starter ZIP is ordinary Markdown plus a local validator. It does not execute code or alter system configuration.
- The optional installer refuses existing destinations, home/current directories, and symlink destinations.
- The optional installer stages and validates the full workspace before one same-filesystem move; the created root is `0700` and its files are `0600`.
- Nothing modifies agent profiles, credentials, models, tools, services, webhooks, cron jobs, or databases.
- Nothing initializes Git inside your knowledge vault.

## Use the wiki

1. Save original material in `raw/`; do not rewrite it.
2. Start your agent from the wiki root.
3. Tell it to read `AGENTS.md` before making wiki changes.
4. Route broad questions through `wiki/Index.md`.
5. Validate structural changes:

```bash
python3 scripts/validate_vault.py .
```

## Local development

```bash
python3 -m unittest discover -s tests -v
bash tests/test_installer.sh
bash tests/test_release.sh
```

The test suite generates ephemeral Ed25519 keys; it never needs the real release-signing key. To inspect a locally signed installer artifact, create a throwaway key and output directory:

```bash
work=$(mktemp -d)
openssl genpkey -algorithm Ed25519 -out "$work/private.pem"
openssl pkey -in "$work/private.pem" -pubout -out "$work/public.pem"
bash scripts/package_release.sh --output "$work/dist" --signing-key "$work/private.pem" --public-key "$work/public.pem"
```

`tests/test_release.sh` verifies both artifacts: the plain cross-platform ZIP contents and an offline authenticated bootstrap whose tampered archive is rejected before the destination exists.

## Release process

1. Update `VERSION` and the pinned version in `bootstrap.sh`.
2. Run the full local verification suite.
3. Complete the public-release audit: secrets, identity, private paths, personal workflow, licenses, and intended IP disclosure.
4. Create a GitHub `release` environment with required reviewers and place `WIKI_INSTALLER_SIGNING_KEY` only in that environment. The release job will not access the key until the environment approves it; CI uses a throwaway key instead.
5. Require the `test` check on `main`, block force-pushes and branch deletion, and keep `vX.Y.Z` tags immutable after creation. The workflow rejects a tag unless it matches `VERSION` and the dispatched `main` commit.
6. Publish the key fingerprint through an independently controlled channel before announcing the signed installer. Confirm that fingerprint through that channel before asking others to run the installer command.
7. Create and push the matching immutable `vX.Y.Z` tag only after approval. Then dispatch the `Publish release` workflow from `main`, supplying that exact tag; it builds and publishes both the starter ZIP and the signed installer assets.

There is deliberately no in-place updater. Re-run the optional installer only for a new, empty wiki; do not treat a personal knowledge base like a disposable config directory.

## Installer first-use trust and key rotation

Only the optional one-line installer uses the release public key. Its current fingerprint is:

```text
SHA-256: 5120dc21bb493cc6a1b69eb345df226772d152e19d12a6059a43993766f32ad0
```

On a first visit, the README and key both arrive from the same repository. That is **trust on first use (TOFU)**: it detects a later release-asset substitution only after the user has independently retained or verified the key; it cannot independently authenticate a compromised repository on the first visit. Confirm the fingerprint through the separately controlled [public key-fingerprint Gist](https://gist.github.com/seth-barrett/07ade6203f159f095a7b6d9c0aa32177) before using the signed installer.

A key rotation must be announced through that independent channel with both old and new fingerprints. The maintainer should publish one final release signed by the old key, then require users to re-verify the new key before using a bootstrap that embeds it.

## License

[MIT](LICENSE)
