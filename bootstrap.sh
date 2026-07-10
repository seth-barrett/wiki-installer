#!/usr/bin/env bash
set -euo pipefail

# This value is intentionally pinned. Each vX.Y.Z tag ships a matching bootstrap.
readonly VERSION="0.1.1"
readonly DEFAULT_RELEASE_BASE_URL="https://github.com/seth-barrett/wiki-installer/releases/download/v$VERSION"

usage() {
  cat <<'USAGE'
Usage: bootstrap.sh [installer options]

Downloads and authenticates a signed release manifest, checks the archive size
and SHA-256, rejects unsafe tar entries, then runs install.sh from the verified
payload. All options are forwarded to install.sh.

Environment overrides are for offline tests and self-hosted mirrors only:
  LLM_WIKI_RELEASE_BASE_URL
  LLM_WIKI_PUBLIC_KEY_PATH
  LLM_WIKI_ALLOW_INSECURE_TEST_TRANSPORT=1
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

for argument in "$@"; do
  case "$argument" in
    --source|--source=*)
      die "--source is not accepted by the authenticated bootstrap"
      ;;
  esac
done

require_command curl
require_command openssl
require_command python3
require_command tar
require_command gzip

release_base_url=${LLM_WIKI_RELEASE_BASE_URL:-$DEFAULT_RELEASE_BASE_URL}
release_base_url=${release_base_url%/}
payload_name="wiki-installer-$VERSION"
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/wiki-installer-bootstrap.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

public_key="$temporary_directory/release-public-key.pem"
if [[ -n "${LLM_WIKI_PUBLIC_KEY_PATH:-}" ]]; then
  [[ -f "$LLM_WIKI_PUBLIC_KEY_PATH" ]] || die "Configured public key path does not exist"
  cp "$LLM_WIKI_PUBLIC_KEY_PATH" "$public_key"
else
  cat > "$public_key" <<'PUBLIC_KEY'
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAWYWCTc6XNUWqer9jBiSuS2aRvL+nZygsZo0y+G3/OrM=
-----END PUBLIC KEY-----
PUBLIC_KEY
fi
chmod 600 "$public_key"
openssl pkey -pubin -in "$public_key" -noout >/dev/null \
  || die "Pinned release public key is invalid"

curl_options=(-fsSL)
if [[ "${LLM_WIKI_ALLOW_INSECURE_TEST_TRANSPORT:-}" == "1" ]]; then
  : # file:// mirrors are intentionally allowed only for offline tests.
else
  curl_options+=(--proto '=https' --proto-redir '=https')
fi

manifest="$temporary_directory/release-manifest.json"
manifest_signature="$manifest.sig"
archive="$temporary_directory/$payload_name.tar.gz"
curl "${curl_options[@]}" "$release_base_url/release-manifest.json" -o "$manifest"
curl "${curl_options[@]}" "$release_base_url/release-manifest.json.sig" -o "$manifest_signature"

openssl pkeyutl -verify -pubin -inkey "$public_key" -rawin \
  -in "$manifest" -sigfile "$manifest_signature" >/dev/null \
  || die "Release manifest signature verification failed"

metadata=$(python3 - "$manifest" "$VERSION" "$payload_name.tar.gz" <<'PY'
import json
import re
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
expected_version = sys.argv[2]
expected_name = sys.argv[3]
try:
    data = json.loads(manifest_path.read_text(encoding='utf-8'))
    if set(data) != {'archive', 'version'} or data['version'] != expected_version:
        raise ValueError
    archive = data['archive']
    if set(archive) != {'name', 'sha256', 'size'}:
        raise ValueError
    if archive['name'] != expected_name:
        raise ValueError
    if not isinstance(archive['size'], int) or archive['size'] <= 0:
        raise ValueError
    if not isinstance(archive['sha256'], str) or not re.fullmatch(r'[0-9a-f]{64}', archive['sha256']):
        raise ValueError
except (OSError, ValueError, TypeError, json.JSONDecodeError):
    raise SystemExit(1)
print(f"{archive['size']} {archive['sha256']}")
PY
) || die "Release manifest is malformed or does not match this bootstrap"

expected_size=${metadata%% *}
expected_sha256=${metadata##* }
curl "${curl_options[@]}" "$release_base_url/$payload_name.tar.gz" -o "$archive"
actual_size=$(wc -c < "$archive" | tr -d '[:space:]')
[[ "$actual_size" == "$expected_size" ]] \
  || die "Release archive size does not match the signed manifest"

if ! python3 - "$archive" "$expected_sha256" <<'PY'
import hashlib
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected = sys.argv[2]
digest = hashlib.sha256()
with path.open('rb') as stream:
    for chunk in iter(lambda: stream.read(1024 * 1024), b''):
        digest.update(chunk)
raise SystemExit(0 if digest.hexdigest() == expected else 1)
PY
then
  die "Release archive SHA-256 does not match the signed manifest"
fi

if ! python3 - "$archive" "$payload_name" <<'PY'
import sys
import tarfile
from pathlib import PurePosixPath

archive_path, expected_root = sys.argv[1:]
seen = set()
try:
    with tarfile.open(archive_path, mode='r:gz') as archive:
        for member in archive.getmembers():
            path = PurePosixPath(member.name)
            normalized = path.as_posix()
            if not normalized or path.is_absolute() or '..' in path.parts:
                raise ValueError('unsafe path')
            if normalized in seen:
                raise ValueError('duplicate path')
            seen.add(normalized)
            if normalized != expected_root and not normalized.startswith(expected_root + '/'):
                raise ValueError('unexpected root')
            if not (member.isdir() or member.isreg()):
                raise ValueError('non-regular archive member')
            if member.mode & 0o077:
                raise ValueError('unsafe archive permissions')
        if f'{expected_root}/install.sh' not in seen:
            raise ValueError('missing installer')
except (OSError, tarfile.TarError, ValueError):
    raise SystemExit(1)
PY
then
  die "Release archive contains unsafe or incomplete entries"
fi

extraction_directory="$temporary_directory/extracted"
mkdir -p "$extraction_directory"
tar -xzf "$archive" -C "$extraction_directory"
payload_directory="$extraction_directory/$payload_name"
[[ -f "$payload_directory/install.sh" ]] \
  || die "Verified release payload did not contain install.sh"

bash "$payload_directory/install.sh" --source "$payload_directory" "$@"
