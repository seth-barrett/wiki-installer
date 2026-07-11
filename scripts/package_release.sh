#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly PROJECT_ROOT
VERSION=$(tr -d '[:space:]' < "$PROJECT_ROOT/VERSION")
readonly VERSION

usage() {
  cat <<'USAGE'
Usage: package_release.sh --signing-key PATH --public-key PATH [--output DIRECTORY]

Build a deterministic installer archive, a canonical manifest, and Ed25519
signatures for both the manifest and bootstrap script.
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "Missing file: $1"
}

sign_file() {
  local file=$1
  local signature="$file.sig"
  openssl pkeyutl -sign -inkey "$signing_key" -rawin -in "$file" -out "$signature"
  openssl pkeyutl -verify -pubin -inkey "$public_key" -rawin \
    -in "$file" -sigfile "$signature" >/dev/null
}

output_directory="$PROJECT_ROOT/dist"
signing_key=""
public_key=""
while (( $# > 0 )); do
  case "$1" in
    --output)
      (( $# >= 2 )) || die "--output requires a value"
      output_directory=$2
      shift 2
      ;;
    --signing-key)
      (( $# >= 2 )) || die "--signing-key requires a value"
      signing_key=$2
      shift 2
      ;;
    --public-key)
      (( $# >= 2 )) || die "--public-key requires a value"
      public_key=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "VERSION must use semantic versioning"
[[ -n "$signing_key" ]] || die "--signing-key is required"
[[ -n "$public_key" ]] || die "--public-key is required"
require_file "$signing_key"
require_file "$public_key"
for required_path in \
  "template" \
  "template/CLAUDE.md" \
  "skills/llm-wiki/SKILL.md" \
  "adapters/hermes/Hermes.md" \
  "scripts/create_starter_zip.py" \
  "scripts/release_archive.py" \
  "scripts/validate_vault.py" \
  "scripts/atomic_install.py" \
  "install.sh" \
  "bootstrap.sh" \
  "scripts/release_manifest.py"; do
  [[ -e "$PROJECT_ROOT/$required_path" ]] || die "Missing release input: $required_path"
done

python3 "$PROJECT_ROOT/scripts/release_archive.py" preflight \
  "$PROJECT_ROOT/template" \
  "$PROJECT_ROOT/skills" \
  "$PROJECT_ROOT/adapters" \
  "$PROJECT_ROOT/scripts/create_starter_zip.py" \
  "$PROJECT_ROOT/scripts/release_archive.py" \
  "$PROJECT_ROOT/scripts/validate_vault.py" \
  "$PROJECT_ROOT/scripts/atomic_install.py" \
  "$PROJECT_ROOT/scripts/release_manifest.py" \
  "$PROJECT_ROOT/install.sh" \
  "$PROJECT_ROOT/bootstrap.sh" \
  "$PROJECT_ROOT/VERSION" \
  || die "Release inputs contain a symlink or unsafe filesystem entry"

mkdir -p "$output_directory"
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/wiki-installer-package.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

payload_name="wiki-installer-$VERSION"
payload_directory="$temporary_directory/$payload_name"
archive="$output_directory/$payload_name.tar.gz"
starter_name="llm-wiki-starter-$VERSION"
starter_directory="$temporary_directory/$starter_name"
starter_archive="$output_directory/$starter_name.zip"
manifest="$output_directory/release-manifest.json"
bootstrap="$output_directory/bootstrap.sh"

mkdir -p "$payload_directory"
cp -R "$PROJECT_ROOT/template" "$payload_directory/template"
cp -R "$PROJECT_ROOT/skills" "$payload_directory/skills"
cp -R "$PROJECT_ROOT/adapters" "$payload_directory/adapters"
mkdir -p "$payload_directory/scripts"
cp "$PROJECT_ROOT/scripts/validate_vault.py" "$payload_directory/scripts/validate_vault.py"
cp "$PROJECT_ROOT/scripts/atomic_install.py" "$payload_directory/scripts/atomic_install.py"
cp "$PROJECT_ROOT/install.sh" "$payload_directory/install.sh"
cp "$PROJECT_ROOT/VERSION" "$payload_directory/VERSION"

python3 "$PROJECT_ROOT/scripts/release_archive.py" preflight "$payload_directory" \
  || die "Staged Linux payload contains a symlink or unsafe filesystem entry"

mkdir -p "$starter_directory"
cp -R "$PROJECT_ROOT/template/." "$starter_directory/"
mkdir -p "$starter_directory/scripts"
cp "$PROJECT_ROOT/scripts/validate_vault.py" "$starter_directory/scripts/validate_vault.py"
mkdir -p "$starter_directory/Agent-Skills/llm-wiki"
cp "$PROJECT_ROOT/skills/llm-wiki/SKILL.md" "$starter_directory/Agent-Skills/llm-wiki/SKILL.md"

python3 "$PROJECT_ROOT/scripts/create_starter_zip.py" \
  --source "$starter_directory" \
  --archive "$starter_archive"

# Release archives contain only owner-readable files and directories.
tar \
  --sort=name \
  --mtime='@0' \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  --mode='u+rwX,go-rwx' \
  -C "$temporary_directory" \
  -czf "$archive" \
  "$payload_name"

python3 "$PROJECT_ROOT/scripts/release_archive.py" verify-tar \
  --archive "$archive" \
  --root "$payload_name" \
  || die "Built release archive violates the safe payload contract"

python3 "$PROJECT_ROOT/scripts/release_manifest.py" \
  --archive "$archive" \
  --starter-archive "$starter_archive" \
  --version "$VERSION" \
  --output "$manifest"
cp "$PROJECT_ROOT/bootstrap.sh" "$bootstrap"
chmod 700 "$bootstrap"

sign_file "$manifest"
sign_file "$bootstrap"

printf 'Created signed release archive: %s\n' "$archive"
printf 'Created cross-platform starter ZIP: %s\n' "$starter_archive"
printf 'Created signed manifest: %s\n' "$manifest"
printf 'Created signed bootstrap: %s\n' "$bootstrap"
