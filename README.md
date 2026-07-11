# LLM Wiki Starter

A normal Markdown knowledge base you can open in Obsidian and work on with Codex, Claude Code, or any other capable agent. No vendor lock-in, database, or required automation.

## Windows (recommended)

Open **Windows PowerShell** (not Command Prompt), paste this one line, and press Enter. It downloads the `v0.1.5` starter ZIP, extracts it, and creates `Documents\llm-wiki`. It refuses to touch that destination if it already exists.

```powershell
$v='0.1.5';$expectedSize=9604;$expectedSha256='72318761b1e6936bc85790f9f0e16b92629c22f24f4cee961a82338368ede047';$d=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'llm-wiki';$p=[IO.Path]::GetDirectoryName($d);$s=Join-Path $p ('.llm-wiki-stage-'+[guid]::NewGuid());$z="$s.zip";if(Test-Path -LiteralPath $d){throw "Destination already exists: $d"};try{Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/seth-barrett/wiki-installer/releases/download/v$v/llm-wiki-starter-$v.zip" -OutFile $z -ErrorAction Stop;if(([IO.FileInfo]$z).Length -ne $expectedSize){throw 'starter ZIP size did not match the expected value'};if(-not [string]::Equals((Get-FileHash -LiteralPath $z -Algorithm SHA256).Hash,$expectedSha256,[System.StringComparison]::OrdinalIgnoreCase)){throw 'starter ZIP SHA-256 did not match the expected value'};Add-Type -AssemblyName System.IO.Compression.FileSystem;$a=[System.IO.Compression.ZipFile]::OpenRead($z);$h=@{};$n=0;$q="llm-wiki-starter-$v/";try{foreach($e in $a.Entries){$x=$e.FullName;if($x.Contains('\') -or -not $x.StartsWith($q,[System.StringComparison]::Ordinal)){throw "unsafe ZIP member: $x"};$y=$x.Substring($q.Length);if($y.StartsWith('/') -or ($y.Split('/') -contains '..') -or ($y.Split('/') -contains '.')){throw "unsafe ZIP member: $x"};if($h.ContainsKey($x)){throw "duplicate ZIP entry: $x"};$h[$x]=$true;$m=$e.ExternalAttributes -shr 16;$k=$m -band 0xF000;if($y.Length -eq 0){if($k -ne 0x4000){throw "unsafe ZIP member: $x"}}elseif($x.EndsWith('/')){if($k -ne 0x4000){throw "unsafe ZIP member: $x"}}else{if($k -ne 0x8000){throw "unsafe ZIP member: $x"};$n++}};if($n -eq 0){throw 'starter ZIP has no files'}}finally{$a.Dispose()};New-Item -ItemType Directory -Path $s -ErrorAction Stop|Out-Null;Expand-Archive -LiteralPath $z -DestinationPath $s -ErrorAction Stop;$r=Join-Path $s "llm-wiki-starter-$v";if(-not(Test-Path -LiteralPath $r -PathType Container)){throw 'Unexpected starter ZIP layout'};[IO.Directory]::Move($r,$d);Write-Host "Installed to $d"}finally{Remove-Item -LiteralPath $z,$s -Recurse -Force -ErrorAction SilentlyContinue}
```

That command uses only built-in PowerShell to download and unpack a plain ZIP. It does **not** download and execute a remote PowerShell script, install an agent, require a key, or require WSL. It validates the ZIP size and SHA-256 pinned in this README, then validates archive structure. Native Windows PowerShell does not verify the Ed25519 release signature, so this is integrity relative to the README copy you chose—not independent publisher authentication. Review `AGENTS.md` yourself before asking an agent to follow it.

Then:

1. Install [Obsidian](https://obsidian.md/download) if you want a desktop editor.
2. In Obsidian choose **Open folder as vault**, then select `Documents\llm-wiki`.
3. After that review, start your agent in the same folder and ask it to follow `AGENTS.md` before changing anything.

Prefer a browser download? Grab [llm-wiki-starter-0.1.5.zip](https://github.com/seth-barrett/wiki-installer/releases/download/v0.1.5/llm-wiki-starter-0.1.5.zip), extract it under `Documents`, and open the inner `llm-wiki-starter-0.1.5` folder as the vault.

## Use the agent you already have

- **Codex:** start it in `Documents\llm-wiki`; it follows `AGENTS.md`.
- **Claude Code:** start it in that folder; `CLAUDE.md` points to the shared rules in `AGENTS.md`.
- **Anything else:** start it in the vault root and say: “Read `START_HERE.md` and `AGENTS.md`, then follow those rules before editing.”
- **Hermes:** optional. It is not needed for this starter or for Windows use. If you already run it through WSL, it can work against a vault stored in your Windows home folder.

The starter never configures any agent globally. `Agent-Skills/` is reference material inside this vault, not a global skill installation.

## What you just installed

```text
llm-wiki/
├── AGENTS.md                       # shared rules for every agent
├── CLAUDE.md                       # Claude Code pointer to those rules
├── START_HERE.md                   # privacy and first-use guide
├── raw/                            # immutable source archive
├── wiki/                           # reusable, linked knowledge
│   ├── Index.md                    # routing page
│   ├── Log.md                      # meaningful-change log
│   ├── Concepts/
│   ├── Topics/
│   ├── Code-Patterns/
│   ├── Comparisons/
│   └── Temporal-Trackers/
├── Agent-Skills/llm-wiki/SKILL.md # optional workflow reference
└── scripts/validate_vault.py       # local structure/link validator
```

## Use the wiki

1. Put original sources in `raw/`; do not rewrite them after capture.
2. Keep reusable notes and connections in `wiki/`.
3. Route broad questions through `wiki/Index.md`.
4. Read `wiki/Log.md` when you want to know what materially changed.
5. After structural edits, run this from the vault root if you have Python installed:

   ```bash
   python3 scripts/validate_vault.py .
   ```

## Optional: Linux and WSL installer

This is an advanced convenience path, not part of normal Windows setup. It is only for people who specifically want a new private vault automatically created on a Linux filesystem. Use it in Linux or WSL—not Windows PowerShell, CMD, Git Bash, macOS, or `/mnt/c/...`.

<details>
<summary>Signed Linux/WSL installer command</summary>

```bash
(v=v0.1.5; d=$(mktemp -d); trap 'rm -rf "$d"' EXIT; k='LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUNvd0JRWURLMlZ3QXlFQVdZV0NUYzZYTlVXcWVyOWpCaVN1UzJhUnZMK25aeWdzWm8weStHMy9Pck09Ci0tLS0tRU5EIFBVQkxJQyBLRVktLS0tLQo='; curl -fsSLo "$d/bootstrap.sh" "https://github.com/seth-barrett/wiki-installer/releases/download/$v/bootstrap.sh" && curl -fsSLo "$d/bootstrap.sh.sig" "https://github.com/seth-barrett/wiki-installer/releases/download/$v/bootstrap.sh.sig" && printf %s "$k" | openssl base64 -d -A > "$d/release-public-key.pem" && openssl pkeyutl -verify -pubin -inkey "$d/release-public-key.pem" -rawin -in "$d/bootstrap.sh" -sigfile "$d/bootstrap.sh.sig" >/dev/null && chmod 700 "$d/bootstrap.sh" && "$d/bootstrap.sh")
```

</details>

Unlike the Windows ZIP path, that command downloads code. Its embedded public key verifies the bootstrap and signed release manifest before extraction. It creates a new private workspace, refuses unsafe/existing destinations, and never modifies agent profiles, credentials, services, cron jobs, or databases.

## Advanced verification and trust

The Windows starter is ordinary Markdown plus a local validator. It does not execute code when extracted. Routine ZIP use needs no public key.

If you want to verify the ZIP’s published bytes with the stronger Linux/WSL trust chain, the signed `release-manifest.json` binds its exact filename, size, and SHA-256. Verify the manifest with the project Ed25519 public key, then compare its `starter_archive.sha256` field with `Get-FileHash` in PowerShell.

The public key exists only to authenticate code in the optional Linux/WSL installer. First-use trust, fingerprint handling, and key rotation are documented in [SECURITY.md](SECURITY.md). A Gist under the same GitHub identity is a second reference copy—not an independent authentication channel.

## Local development and releases

```bash
python3 -m unittest discover -s tests -v
bash tests/test_installer.sh
bash tests/test_release.sh
```

The test suite uses ephemeral Ed25519 keys; it never needs the real release-signing key. To create a locally signed test payload:

```bash
work=$(mktemp -d)
openssl genpkey -algorithm Ed25519 -out "$work/private.pem"
openssl pkey -in "$work/private.pem" -pubout -out "$work/public.pem"
bash scripts/package_release.sh --output "$work/dist" --signing-key "$work/private.pem" --public-key "$work/public.pem"
```

For a release, update `VERSION` and `bootstrap.sh`, run the complete suite, audit public content, create an immutable matching tag after approval, then manually dispatch `Publish release` from `main`. The protected `release` environment holds the signing key and builds both the ZIP and signed Linux installer assets.

There is deliberately no in-place updater. Treat a personal knowledge base as personal data, not a disposable configuration directory.

## License

[MIT](LICENSE)