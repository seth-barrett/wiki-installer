# Contributing

## Before opening a pull request

1. Keep the starter generic. Do not add personal sources, local paths, credentials, private prompts, or agent configuration.
2. Preserve the core boundary: `raw/` is immutable evidence; `wiki/` is compiled knowledge.
3. Add or update behavior tests before changing installer, bootstrap, packaging, or validation code.
4. Run:

```bash
python3 -m unittest discover -s tests -v
bash tests/test_installer.sh
bash tests/test_release.sh
```

## Versioned releases

1. Release signing requires the private Ed25519 key held outside the repository. The release workflow reads it only from `WIKI_INSTALLER_SIGNING_KEY` in the protected GitHub `release` environment; CI uses an ephemeral test key.
2. A release is a trust boundary. Changes to `VERSION`, `bootstrap.sh`, `keys/release-public-key.pem`, the installer, or package contents must keep the release version, trust anchor, and artifact name aligned. The release workflow rejects a tag that does not exactly match `v$(VERSION)`.
