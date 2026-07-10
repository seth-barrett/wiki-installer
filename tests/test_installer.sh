#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEMPORARY_DIRECTORY=$(mktemp -d)
trap 'rm -rf "$TEMPORARY_DIRECTORY"' EXIT

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

HOME="$TEMPORARY_DIRECTORY/home"
export HOME
mkdir -p "$HOME"

vault="$TEMPORARY_DIRECTORY/wiki"
"$REPO_ROOT/install.sh" \
  --source "$REPO_ROOT" \
  --path "$vault" \
  --agent hermes \
  --yes

assert_file "$vault/AGENTS.md"
assert_file "$vault/README.md"
assert_file "$vault/START_HERE.md"
assert_file "$vault/raw/.gitkeep"
assert_file "$vault/wiki/Index.md"
assert_file "$vault/wiki/Log.md"
assert_file "$vault/scripts/validate_vault.py"
assert_file "$vault/Agent-Skills/llm-wiki/SKILL.md"
assert_file "$vault/Agent-Adapters/Hermes.md"
[[ "$(stat -c '%a' "$vault")" == "700" ]] || fail "workspace is not private"
[[ "$(stat -c '%a' "$vault/AGENTS.md")" == "600" ]] || fail "workspace files are not private"
assert_not_exists "$HOME/.hermes"
if compgen -G "$TEMPORARY_DIRECTORY/.wiki-installer-stage.*" >/dev/null; then
  fail "installer left a staging directory behind"
fi
python3 "$vault/scripts/validate_vault.py" "$vault"

default_agent="$TEMPORARY_DIRECTORY/default-agent"
"$REPO_ROOT/install.sh" --source "$REPO_ROOT" --path "$default_agent" --yes
assert_not_exists "$default_agent/Agent-Adapters"

if "$REPO_ROOT/install.sh" --source "$REPO_ROOT" --path "$vault" --agent hermes --yes; then
  fail "installer accepted an existing vault"
fi

nonempty="$TEMPORARY_DIRECTORY/nonempty"
mkdir -p "$nonempty"
printf 'do not overwrite\n' > "$nonempty/notes.md"
if "$REPO_ROOT/install.sh" --source "$REPO_ROOT" --path "$nonempty" --agent none --yes; then
  fail "installer accepted a non-empty directory"
fi

preview="$TEMPORARY_DIRECTORY/preview"
"$REPO_ROOT/install.sh" \
  --source "$REPO_ROOT" \
  --path "$preview" \
  --agent none \
  --yes \
  --dry-run
assert_not_exists "$preview"

no_adapter="$TEMPORARY_DIRECTORY/no-adapter"
"$REPO_ROOT/install.sh" \
  --source "$REPO_ROOT" \
  --path "$no_adapter" \
  --agent none \
  --yes
assert_not_exists "$no_adapter/Agent-Adapters"

if "$REPO_ROOT/install.sh" --source "$REPO_ROOT" --path "$HOME" --agent none --yes; then
  fail "installer accepted the user's home directory as a destination"
fi
assert_not_exists "$HOME/AGENTS.md"

symlink_target="$TEMPORARY_DIRECTORY/symlink-target"
mkdir -p "$symlink_target"
printf 'do not follow links\n' > "$symlink_target/sentinel.txt"
symlink_destination="$TEMPORARY_DIRECTORY/symlink-destination"
ln -s "$symlink_target" "$symlink_destination"
if "$REPO_ROOT/install.sh" --source "$REPO_ROOT" --path "$symlink_destination" --agent none --yes; then
  fail "installer followed a destination symlink"
fi
assert_file "$symlink_target/sentinel.txt"
assert_not_exists "$symlink_target/AGENTS.md"

symlink_parent_target="$TEMPORARY_DIRECTORY/symlink-parent-target"
mkdir -p "$symlink_parent_target"
symlink_parent="$TEMPORARY_DIRECTORY/symlink-parent"
ln -s "$symlink_parent_target" "$symlink_parent"
if "$REPO_ROOT/install.sh" --source "$REPO_ROOT" --path "$symlink_parent/wiki" --agent none --yes; then
  fail "installer accepted a destination below a symlinked parent"
fi
assert_not_exists "$symlink_parent_target/wiki"

fake_bin="$TEMPORARY_DIRECTORY/fake-bin"
mkdir -p "$fake_bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$fake_bin/hermes"
chmod 755 "$fake_bin/hermes"

auto_agent="$TEMPORARY_DIRECTORY/auto-agent"
PATH="$fake_bin:$PATH" "$REPO_ROOT/install.sh" \
  --source "$REPO_ROOT" \
  --path "$auto_agent" \
  --agent auto \
  --yes
assert_file "$auto_agent/Agent-Adapters/Hermes.md"

printf 'PASS: installer behavior\n'
