#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
umask 077

usage() {
  cat <<'USAGE'
Usage: install.sh [options]

Create a new portable LLM-wiki workspace from a verified release payload.

Options:
  --path PATH       New destination directory (default: $HOME/llm-wiki)
  --agent AGENT     auto, hermes, or none (default: auto)
  --source PATH     Verified release payload directory (default: this script's directory)
  --yes             Skip the interactive creation confirmation
  --dry-run         Show the selected action without writing files
  --help            Show this message
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "Release payload is missing $2"
}

require_directory() {
  [[ -d "$1" ]] || die "Release payload is missing $2"
}

reject_symlink_components() {
  local input_path=$1
  local current_path component
  local -a components

  if [[ "$input_path" == /* ]]; then
    current_path=""
  else
    current_path=$(pwd -P)
  fi
  IFS=/ read -r -a components <<< "$input_path"
  for component in "${components[@]}"; do
    [[ -z "$component" || "$component" == "." ]] && continue
    [[ "$component" != ".." ]] || die "Destination path must not contain .."
    current_path="$current_path/$component"
    [[ ! -L "$current_path" ]] || die "Destination path must not contain symlink components"
  done
}

cleanup_stage() {
  if [[ -n "${stage_directory:-}" && -d "$stage_directory" ]]; then
    rm -rf -- "$stage_directory"
  fi
  return 0
}

destination="${HOME}/llm-wiki"
source_directory="$SCRIPT_DIRECTORY"
agent="auto"
yes=false
dry_run=false
path_provided=false
stage_directory=""
trap cleanup_stage EXIT INT TERM

while (( $# > 0 )); do
  case "$1" in
    --path)
      (( $# >= 2 )) || die "--path requires a value"
      destination=$2
      path_provided=true
      shift 2
      ;;
    --agent)
      (( $# >= 2 )) || die "--agent requires a value"
      agent=$2
      shift 2
      ;;
    --source)
      (( $# >= 2 )) || die "--source requires a value"
      source_directory=$2
      shift 2
      ;;
    --yes)
      yes=true
      shift
      ;;
    --dry-run)
      dry_run=true
      shift
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

case "$agent" in
  auto)
    if command -v hermes >/dev/null 2>&1; then
      agent="hermes"
    else
      agent="none"
    fi
    ;;
  hermes|none)
    ;;
  *)
    die "Unsupported agent: $agent (supported: auto, hermes, none)"
    ;;
esac

source_directory=$(cd -- "$source_directory" && pwd)
require_directory "$source_directory/template" "template/"
require_file "$source_directory/skills/llm-wiki/SKILL.md" "skills/llm-wiki/SKILL.md"
require_file "$source_directory/adapters/hermes/Hermes.md" "adapters/hermes/Hermes.md"
require_file "$source_directory/scripts/validate_vault.py" "scripts/validate_vault.py"
require_file "$source_directory/scripts/atomic_install.py" "scripts/atomic_install.py"

[[ -n "$destination" ]] || die "Destination must not be empty"
[[ "$destination" != "/" ]] || die "Destination must not be the filesystem root"
[[ ! -L "$destination" ]] || die "Destination must not be a symlink"
[[ ! -e "$destination" ]] || die "Destination must be new: $destination"

parent_input=$(dirname -- "$destination")
name=$(basename -- "$destination")
reject_symlink_components "$parent_input"
[[ "$name" != "." && "$name" != ".." ]] || die "Destination name is unsafe"
[[ -d "$parent_input" ]] || die "Destination parent must already exist"
parent_directory=$(cd -P -- "$parent_input" && pwd)
destination="$parent_directory/$name"

home_directory=$(cd -P -- "$HOME" && pwd)
current_directory=$(pwd -P)
[[ "$destination" != "$home_directory" ]] || die "Destination must not be the home directory"
[[ "$destination" != "$current_directory" ]] || die "Destination must not be the current directory"

if [[ "$dry_run" == true ]]; then
  printf 'Would create one private LLM-wiki workspace.\n'
  printf 'Selected agent mode: %s\n' "$agent"
  printf 'Network access: none; source payload is local and pre-verified.\n'
  exit 0
fi

if [[ "$yes" != true ]]; then
  [[ -t 0 ]] || die "Non-interactive installs require --path and --yes"
  read -r -p "Create a new LLM wiki workspace? [y/N] " response
  [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]] || die "Installation cancelled"
elif [[ ! -t 0 && "$path_provided" != true ]]; then
  die "Non-interactive installs require an explicit --path"
fi

stage_directory=$(mktemp -d "$parent_directory/.wiki-installer-stage.XXXXXX")
staged_workspace="$stage_directory/workspace"
mkdir -p "$staged_workspace"
cp -R "$source_directory/template/." "$staged_workspace/"
mkdir -p "$staged_workspace/scripts"
cp "$source_directory/scripts/validate_vault.py" "$staged_workspace/scripts/validate_vault.py"
mkdir -p "$staged_workspace/Agent-Skills/llm-wiki"
cp "$source_directory/skills/llm-wiki/SKILL.md" "$staged_workspace/Agent-Skills/llm-wiki/SKILL.md"

if [[ "$agent" == "hermes" ]]; then
  mkdir -p "$staged_workspace/Agent-Adapters"
  cp "$source_directory/adapters/hermes/Hermes.md" "$staged_workspace/Agent-Adapters/Hermes.md"
fi

python3 "$source_directory/scripts/validate_vault.py" "$staged_workspace" >/dev/null \
  || die "Staged template validation failed"
find "$staged_workspace" -type d -exec chmod 700 {} +
find "$staged_workspace" -type f -exec chmod 600 {} +

# Commit with a Linux kernel no-replace primitive while parent directories are pinned.
if ! python3 "$source_directory/scripts/atomic_install.py" \
  --source-parent "$stage_directory" \
  --source-name "workspace" \
  --destination-parent "$parent_directory" \
  --destination-name "$name"; then
  die "Atomic destination commit failed; no existing destination was overwritten"
fi
rmdir -- "$stage_directory"
stage_directory=""

printf 'Installed LLM wiki successfully.\n'
printf 'Start your agent from the new wiki directory and ask it to read AGENTS.md.\n'
