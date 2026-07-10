# Wiki Installer

A safe starter for a compounding, agent-maintained Markdown wiki.

It gives an AI agent a disciplined knowledge workspace—not a magical RAG upload bucket and not a surprise automation stack.

## What it creates

```text
my-wiki/
├── AGENTS.md                       # governance and writing rules
├── raw/                             # immutable source archive
├── wiki/                            # compiled, linked knowledge
│   ├── Index.md                     # query routing
│   ├── Log.md                       # meaningful-change log
│   ├── Concepts/
│   ├── Topics/
│   ├── Code-Patterns/
│   ├── Comparisons/
│   └── Temporal-Trackers/
├── Agent-Skills/llm-wiki/SKILL.md  # portable workflow skill
├── Agent-Adapters/Hermes.md         # only when Hermes is selected
└── scripts/validate_vault.py        # local structure/link validator
```

## Install

After release `v0.1.1` is published, the pinned one-liner will verify the signed bootstrap **before** it executes it:

```bash
(v=v0.1.1; d=$(mktemp -d); trap 'rm -rf "$d"' EXIT; k='LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUNvd0JRWURLMlZ3QXlFQVdZV0NUYzZYTlVXcWVyOWpCaVN1UzJhUnZMK25aeWdzWm8weStHMy9Pck09Ci0tLS0tRU5EIFBVQkxJQyBLRVktLS0tLQo='; curl -fsSLo "$d/bootstrap.sh" "https://github.com/seth-barrett/wiki-installer/releases/download/$v/bootstrap.sh" && curl -fsSLo "$d/bootstrap.sh.sig" "https://github.com/seth-barrett/wiki-installer/releases/download/$v/bootstrap.sh.sig" && printf %s "$k" | openssl base64 -d -A > "$d/release-public-key.pem" && openssl pkeyutl -verify -pubin -inkey "$d/release-public-key.pem" -rawin -in "$d/bootstrap.sh" -sigfile "$d/bootstrap.sh.sig" && bash "$d/bootstrap.sh" --path "$HOME/llm-wiki" --agent auto --yes)
```

The authenticated bootstrap verifies the signed release manifest, exact archive size, SHA-256, and tar-entry safety before extraction or installation. It is not `curl | bash`; that would execute the one file we need to authenticate.

Prefer inspecting remote code before execution? Use the local/manual route:

```bash
git clone https://github.com/seth-barrett/wiki-installer.git
cd wiki-installer
bash install.sh --path "$HOME/llm-wiki" --agent auto
```

## Safety behavior

- Refuses to write to any existing destination, the home/current directory, or a destination symlink.
- Stages and validates the full workspace before one same-filesystem move; the created root is `0700` and its files are `0600`.
- Does not modify `~/.hermes`, agent profiles, credentials, models, tools, services, webhooks, cron jobs, or databases.
- Creates a workspace-local Hermes adapter only when `--agent hermes` or `--agent auto` detects Hermes.
- Uses no network access after the release payload is verified.
- Does not initialize a Git repository inside your knowledge vault.

Supported platform in v0.1: Linux with Bash and an OpenSSL build that supports Ed25519. Prerequisites: Python 3, `curl`, `openssl`, `tar`, and `gzip`.

## Use the wiki

1. Save original material in `raw/`; do not rewrite it.
2. Start your agent from the wiki root.
3. Tell it to read `AGENTS.md` before making wiki changes.
4. Route broad questions through `wiki/Index.md`.
5. Validate structural changes:

```bash
cd "$HOME/llm-wiki"
python3 scripts/validate_vault.py .
```

With Hermes:

```bash
cd "$HOME/llm-wiki"
hermes
```

## Local development

```bash
python3 -m unittest discover -s tests -v
bash tests/test_installer.sh
bash tests/test_release.sh
```

The test suite generates ephemeral Ed25519 keys; it never needs the real release-signing key. To inspect a locally signed artifact, create a throwaway key and output directory:

```bash
work=$(mktemp -d)
openssl genpkey -algorithm Ed25519 -out "$work/private.pem"
openssl pkey -in "$work/private.pem" -pubout -out "$work/public.pem"
bash scripts/package_release.sh --output "$work/dist" --signing-key "$work/private.pem" --public-key "$work/public.pem"
```

`tests/test_release.sh` performs an offline bootstrap against a locally built release, then verifies that a tampered archive is rejected before the destination exists.

## Release process

1. Update `VERSION` and the pinned version in `bootstrap.sh`.
2. Run the full local verification suite.
3. Complete the public-release audit: secrets, identity, private paths, personal workflow, licenses, and intended IP disclosure.
4. Create a GitHub `release` environment with required reviewers and place `WIKI_INSTALLER_SIGNING_KEY` only in that environment. The release job will not access the key until the environment approves it; CI uses a throwaway key instead.
5. Protect `main`, restrict tag creation to release maintainers, and use signed/protected `vX.Y.Z` tags. The workflow also rejects a tag unless it matches `VERSION` and the current `main` commit.
6. Publish the key fingerprint through an independently controlled channel before announcing the repository. Confirm that fingerprint through that channel before asking others to run the one-liner.
7. Create and push the matching immutable `vX.Y.Z` tag only after approval. Then dispatch the `Publish release` workflow from `main`, supplying that exact tag; it builds the checked release archive and publishes it.

There is deliberately no in-place updater in v0.1. Re-run the installer only for a new, empty wiki; do not treat a personal knowledge base like a disposable config directory.

## First-use trust and key rotation

The one-liner contains the release public key and verifies the downloaded bootstrap before executing it. The current key fingerprint is:

```text
SHA-256: 5120dc21bb493cc6a1b69eb345df226772d152e19d12a6059a43993766f32ad0
```

On a first visit, the README and that key both arrive from the same repository. That is **trust on first use (TOFU)**: it detects a later release-asset substitution only after the user has independently retained or verified the key; it cannot independently authenticate a compromised repository on the first visit. Confirm the fingerprint through the separately controlled [public key-fingerprint Gist](https://gist.github.com/seth-barrett/07ade6203f159f095a7b6d9c0aa32177) before installation.

A key rotation must be announced through that independent channel with both old and new fingerprints. The maintainer should publish one final release signed by the old key, then require users to re-verify the new key before using a bootstrap that embeds it.


## License

[MIT](LICENSE)
