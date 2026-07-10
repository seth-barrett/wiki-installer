# Security Policy

## Scope

Report vulnerabilities in the installer, bootstrap, release packaging, validator, or repository configuration.

Do **not** open a public issue for a suspected vulnerability that could cause arbitrary writes, checksum bypass, credential exposure, or unsafe execution. Use GitHub's private security-advisory reporting for this repository once it is published, or contact the maintainer privately through the repository profile.

## Supported versions

Only the latest tagged release is supported.

## Security design

- A pinned public key verifies the bootstrap before execution; the authenticated bootstrap verifies an Ed25519-signed release manifest, then exact archive size and SHA-256 before extraction.
- The public key and one-liner are delivered together in the repository README on first use. This is TOFU, not an independent proof of publisher identity: users should compare `SHA-256: 5120dc21bb493cc6a1b69eb345df226772d152e19d12a6059a43993766f32ad0` with a separately controlled maintainer channel before installation.
- Key rotation requires an independent announcement of old and new fingerprints, plus a final old-key-signed release.
- Archive entries are rejected before extraction when they use traversal, absolute paths, duplicate names, non-regular members, unsafe permissions, or an unexpected release root.
- The installer rejects existing, home/current-directory, and symlink destinations; it validates an isolated staging tree before an atomic move into a new private workspace.
- The starter never edits agent-global configuration or credential files.
- The starter never installs services, webhooks, cron jobs, databases, or dependencies.

Users should inspect scripts before running them and keep their personal `raw/` sources, agent configuration, and credentials out of public repositories.
