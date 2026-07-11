#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEMPORARY_DIRECTORY=$(mktemp -d)
trap 'rm -rf "$TEMPORARY_DIRECTORY"' EXIT
VERSION=$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "expected file: $1"
}

assert_not_exists() {
  [[ ! -e "$1" ]] || fail "expected path to be absent: $1"
}

create_minimal_starter_archive() {
  local archive_path=$1
  python3 - "$archive_path" "$VERSION" <<'PY'
import sys
import zipfile
from pathlib import Path

archive = Path(sys.argv[1])
version = sys.argv[2]
with zipfile.ZipFile(archive, mode="w", compression=zipfile.ZIP_DEFLATED) as bundle:
    bundle.writestr(f"llm-wiki-starter-{version}/README.md", "# Starter\n")
PY
}

signing_key="$TEMPORARY_DIRECTORY/release-private.pem"
public_key="$TEMPORARY_DIRECTORY/release-public.pem"
openssl genpkey -algorithm Ed25519 -out "$signing_key"
openssl pkey -in "$signing_key" -pubout -out "$public_key"

dist="$TEMPORARY_DIRECTORY/dist"
bash "$REPO_ROOT/scripts/package_release.sh" \
  --output "$dist" \
  --signing-key "$signing_key" \
  --public-key "$public_key"

archive="$dist/wiki-installer-$VERSION.tar.gz"
starter_archive="$dist/llm-wiki-starter-$VERSION.zip"
manifest="$dist/release-manifest.json"
manifest_signature="$manifest.sig"
bootstrap="$dist/bootstrap.sh"
bootstrap_signature="$bootstrap.sig"
for required_file in "$archive" "$starter_archive" "$manifest" "$manifest_signature" "$bootstrap" "$bootstrap_signature"; do
  assert_file "$required_file"
done

python3 - "$manifest" "$archive" "$starter_archive" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
for key, archive_argument in (("archive", sys.argv[2]), ("starter_archive", sys.argv[3])):
    archive = Path(archive_argument)
    expected = {
        "name": archive.name,
        "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
        "size": archive.stat().st_size,
    }
    actual = manifest.get(key)
    if actual != expected:
        raise SystemExit(f"manifest {key} did not bind {archive.name}: {actual!r}")
PY

python3 - "$starter_archive" "$VERSION" <<'PY'
import sys
import zipfile
from pathlib import Path

archive = Path(sys.argv[1])
version = sys.argv[2]
root = f"llm-wiki-starter-{version}/"
with zipfile.ZipFile(archive) as bundle:
    names = set(bundle.namelist())
required = {
    f"{root}AGENTS.md",
    f"{root}CLAUDE.md",
    f"{root}START_HERE.md",
    f"{root}README.md",
    f"{root}raw/.gitkeep",
    f"{root}scripts/validate_vault.py",
    f"{root}Agent-Skills/llm-wiki/SKILL.md",
}
missing = required - names
if missing:
    raise SystemExit(f"starter ZIP is missing: {sorted(missing)}")
if any(name.startswith(f"{root}Agent-Adapters/") for name in names):
    raise SystemExit("starter ZIP must not select a harness-specific adapter")
PY

starter_extract="$TEMPORARY_DIRECTORY/starter-extract"
python3 - "$starter_archive" "$starter_extract" <<'PY'
import sys
import zipfile
from pathlib import Path

archive = Path(sys.argv[1])
destination = Path(sys.argv[2])
with zipfile.ZipFile(archive) as bundle:
    bundle.extractall(destination)
PY
starter_root="$starter_extract/llm-wiki-starter-$VERSION"
python3 "$starter_root/scripts/validate_vault.py" "$starter_root"
assert_not_exists "$starter_root/Agent-Adapters"

symlink_source="$TEMPORARY_DIRECTORY/symlink-source"
mkdir -p "$symlink_source"
cp -a "$REPO_ROOT/." "$symlink_source/"
rm -rf "$symlink_source/.git"
synthetic_secret="$TEMPORARY_DIRECTORY/synthetic-release-secret.txt"
printf 'not for the release\n' > "$synthetic_secret"
ln -s "$synthetic_secret" "$symlink_source/template/synthetic-secret-link.txt"
symlink_dist="$TEMPORARY_DIRECTORY/symlink-dist"
if bash "$symlink_source/scripts/package_release.sh" \
  --output "$symlink_dist" \
  --signing-key "$signing_key" \
  --public-key "$public_key"; then
  fail "release packaging accepted a template symlink"
fi
assert_not_exists "$symlink_dist/llm-wiki-starter-$VERSION.zip"

openssl pkeyutl -verify -pubin -inkey "$public_key" -rawin \
  -in "$manifest" -sigfile "$manifest_signature"
openssl pkeyutl -verify -pubin -inkey "$public_key" -rawin \
  -in "$bootstrap" -sigfile "$bootstrap_signature"

HOME="$TEMPORARY_DIRECTORY/home"
export HOME
mkdir -p "$HOME"

vault="$TEMPORARY_DIRECTORY/bootstrap-vault"
LLM_WIKI_PUBLIC_KEY_PATH="$public_key" \
LLM_WIKI_RELEASE_BASE_URL="file://$dist" \
LLM_WIKI_ALLOW_INSECURE_TEST_TRANSPORT=1 \
  bash "$bootstrap" --path "$vault" --agent none --yes
assert_file "$vault/AGENTS.md"
assert_file "$vault/Agent-Skills/llm-wiki/SKILL.md"
assert_file "$vault/scripts/validate_vault.py"
assert_not_exists "$vault/Agent-Adapters"
python3 "$vault/scripts/validate_vault.py" "$vault"

corrupt_archive="$TEMPORARY_DIRECTORY/corrupt-archive"
mkdir -p "$corrupt_archive"
cp "$archive" "$manifest" "$manifest_signature" "$bootstrap" "$bootstrap_signature" "$corrupt_archive/"
printf 'tampered\n' >> "$corrupt_archive/wiki-installer-$VERSION.tar.gz"
unsafe_archive_destination="$TEMPORARY_DIRECTORY/unsafe-archive"
if LLM_WIKI_PUBLIC_KEY_PATH="$public_key" \
LLM_WIKI_RELEASE_BASE_URL="file://$corrupt_archive" \
LLM_WIKI_ALLOW_INSECURE_TEST_TRANSPORT=1 \
  bash "$corrupt_archive/bootstrap.sh" --path "$unsafe_archive_destination" --agent none --yes; then
  fail "bootstrap accepted a signed manifest whose archive digest did not match"
fi
assert_not_exists "$unsafe_archive_destination"

corrupt_manifest="$TEMPORARY_DIRECTORY/corrupt-manifest"
mkdir -p "$corrupt_manifest"
cp "$archive" "$manifest" "$manifest_signature" "$bootstrap" "$bootstrap_signature" "$corrupt_manifest/"
printf 'tampered\n' >> "$corrupt_manifest/release-manifest.json"
unsafe_manifest_destination="$TEMPORARY_DIRECTORY/unsafe-manifest"
if LLM_WIKI_PUBLIC_KEY_PATH="$public_key" \
LLM_WIKI_RELEASE_BASE_URL="file://$corrupt_manifest" \
LLM_WIKI_ALLOW_INSECURE_TEST_TRANSPORT=1 \
  bash "$corrupt_manifest/bootstrap.sh" --path "$unsafe_manifest_destination" --agent none --yes; then
  fail "bootstrap accepted a manifest with an invalid signature"
fi
assert_not_exists "$unsafe_manifest_destination"

untrusted_source_destination="$TEMPORARY_DIRECTORY/untrusted-source-destination"
if LLM_WIKI_PUBLIC_KEY_PATH="$public_key" \
LLM_WIKI_RELEASE_BASE_URL="file://$dist" \
LLM_WIKI_ALLOW_INSECURE_TEST_TRANSPORT=1 \
  bash "$bootstrap" --path "$untrusted_source_destination" --agent none --yes --source "$REPO_ROOT"; then
  fail "bootstrap accepted a caller-provided --source override"
fi
assert_not_exists "$untrusted_source_destination"

unsafe_archive="$TEMPORARY_DIRECTORY/unsafe-entries"
mkdir -p "$unsafe_archive"
unsafe_starter_archive="$unsafe_archive/llm-wiki-starter-$VERSION.zip"
create_minimal_starter_archive "$unsafe_starter_archive"
python3 - "$unsafe_archive/wiki-installer-$VERSION.tar.gz" "$VERSION" <<'PY'
import io
import sys
import tarfile
from pathlib import Path

archive_path = Path(sys.argv[1])
version = sys.argv[2]
root = f"wiki-installer-{version}"
with tarfile.open(archive_path, mode="w:gz") as archive:
    root_entry = tarfile.TarInfo(root)
    root_entry.type = tarfile.DIRTYPE
    root_entry.mode = 0o700
    archive.addfile(root_entry)

    install_bytes = b"#!/usr/bin/env bash\nexit 0\n"
    install_entry = tarfile.TarInfo(f"{root}/install.sh")
    install_entry.size = len(install_bytes)
    install_entry.mode = 0o700
    archive.addfile(install_entry, io.BytesIO(install_bytes))

    traversal_bytes = b"escape"
    traversal_entry = tarfile.TarInfo("../escape")
    traversal_entry.size = len(traversal_bytes)
    traversal_entry.mode = 0o600
    archive.addfile(traversal_entry, io.BytesIO(traversal_bytes))
PY
python3 "$REPO_ROOT/scripts/release_manifest.py" \
  --archive "$unsafe_archive/wiki-installer-$VERSION.tar.gz" \
  --starter-archive "$unsafe_starter_archive" \
  --version "$VERSION" \
  --output "$unsafe_archive/release-manifest.json"
openssl pkeyutl -sign -inkey "$signing_key" -rawin \
  -in "$unsafe_archive/release-manifest.json" \
  -out "$unsafe_archive/release-manifest.json.sig"
cp "$bootstrap" "$bootstrap_signature" "$unsafe_archive/"
unsafe_entries_destination="$TEMPORARY_DIRECTORY/unsafe-entries-destination"
if LLM_WIKI_PUBLIC_KEY_PATH="$public_key" \
LLM_WIKI_RELEASE_BASE_URL="file://$unsafe_archive" \
LLM_WIKI_ALLOW_INSECURE_TEST_TRANSPORT=1 \
  bash "$unsafe_archive/bootstrap.sh" --path "$unsafe_entries_destination" --agent none --yes; then
  fail "bootstrap accepted a signed archive containing path traversal"
fi
assert_not_exists "$unsafe_entries_destination"

unsafe_link_archive="$TEMPORARY_DIRECTORY/unsafe-link"
mkdir -p "$unsafe_link_archive"
unsafe_link_starter_archive="$unsafe_link_archive/llm-wiki-starter-$VERSION.zip"
create_minimal_starter_archive "$unsafe_link_starter_archive"
python3 - "$unsafe_link_archive/wiki-installer-$VERSION.tar.gz" "$VERSION" <<'PY'
import io
import sys
import tarfile
from pathlib import Path

archive_path = Path(sys.argv[1])
version = sys.argv[2]
root = f"wiki-installer-{version}"
with tarfile.open(archive_path, mode="w:gz") as archive:
    root_entry = tarfile.TarInfo(root)
    root_entry.type = tarfile.DIRTYPE
    root_entry.mode = 0o700
    archive.addfile(root_entry)

    install_bytes = b"#!/usr/bin/env bash\nexit 0\n"
    install_entry = tarfile.TarInfo(f"{root}/install.sh")
    install_entry.size = len(install_bytes)
    install_entry.mode = 0o700
    archive.addfile(install_entry, io.BytesIO(install_bytes))

    link_entry = tarfile.TarInfo(f"{root}/escape")
    link_entry.type = tarfile.SYMTYPE
    link_entry.linkname = "/tmp/outside"
    link_entry.mode = 0o700
    archive.addfile(link_entry)
PY
python3 "$REPO_ROOT/scripts/release_manifest.py" \
  --archive "$unsafe_link_archive/wiki-installer-$VERSION.tar.gz" \
  --starter-archive "$unsafe_link_starter_archive" \
  --version "$VERSION" \
  --output "$unsafe_link_archive/release-manifest.json"
openssl pkeyutl -sign -inkey "$signing_key" -rawin \
  -in "$unsafe_link_archive/release-manifest.json" \
  -out "$unsafe_link_archive/release-manifest.json.sig"
cp "$bootstrap" "$bootstrap_signature" "$unsafe_link_archive/"
unsafe_link_destination="$TEMPORARY_DIRECTORY/unsafe-link-destination"
if LLM_WIKI_PUBLIC_KEY_PATH="$public_key" \
LLM_WIKI_RELEASE_BASE_URL="file://$unsafe_link_archive" \
LLM_WIKI_ALLOW_INSECURE_TEST_TRANSPORT=1 \
  bash "$unsafe_link_archive/bootstrap.sh" --path "$unsafe_link_destination" --agent none --yes; then
  fail "bootstrap accepted a signed archive containing a symlink member"
fi
assert_not_exists "$unsafe_link_destination"

printf 'PASS: authenticated release bootstrap behavior\n'
