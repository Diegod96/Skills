#!/usr/bin/env bash
#
# Build and install this repository as a user-level Grok CLI/TUI plugin.
#
# Usage:
#   ./install-grok-plugin.sh [--dry-run]

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GROK_CATALOG_MANIFEST="$SOURCE_DIR/.grok-plugin/plugin.json"
MARKETPLACE_MANIFEST="$SOURCE_DIR/.grok-plugin/marketplace.json"
PLUGIN_INDEX="$SOURCE_DIR/.grok-plugin/plugin-index.json"
SKILL_MANIFEST="$SOURCE_DIR/.cursor-plugin/plugin.json"
GROK_BIN="${GROK_BIN:-$HOME/.grok/bin/grok}"
PLUGIN_NAME="$(jq -r '.name' "$GROK_CATALOG_MANIFEST")"
PACKAGE_DIR="$SOURCE_DIR/plugins/$PLUGIN_NAME"
PACKAGE_MANIFEST="$PACKAGE_DIR/plugin.json"
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,7p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

for required_file in \
  "$GROK_CATALOG_MANIFEST" \
  "$MARKETPLACE_MANIFEST" \
  "$PLUGIN_INDEX" \
  "$PACKAGE_MANIFEST" \
  "$SKILL_MANIFEST"; do
  if [[ ! -f "$required_file" ]]; then
    echo "Required manifest not found: $required_file" >&2
    exit 1
  fi
done

for required_command in jq rsync; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "$required_command is required to assemble the Grok Bot plugin" >&2
    exit 1
  fi
done

if [[ ! -x "$GROK_BIN" ]]; then
  echo "Grok CLI not found or not executable: $GROK_BIN" >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

mkdir -p "$STAGING_DIR/skills"
rsync -a "$PACKAGE_MANIFEST" "$STAGING_DIR/plugin.json"
rsync -a "$SOURCE_DIR/README.md" "$STAGING_DIR/README.md"

while IFS= read -r skill_path; do
  normalized_path="${skill_path#./}"
  skill_name="${normalized_path##*/}"
  source_skill="$SOURCE_DIR/$normalized_path"

  if [[ ! -f "$source_skill/SKILL.md" ]]; then
    echo "Declared skill is missing SKILL.md: $skill_path" >&2
    exit 1
  fi

  rsync -a "$source_skill/" "$STAGING_DIR/skills/$skill_name/"
done < <(jq -r '.skills[]' "$SKILL_MANIFEST")

"$GROK_BIN" plugin validate "$STAGING_DIR"

echo "Grok Bot plugin: $PLUGIN_NAME"
echo "Marketplace package: $PACKAGE_DIR"
echo "Skills: $(jq '.skills | length' "$SKILL_MANIFEST")"

if [[ "$DRY_RUN" -eq 1 ]]; then
  rsync -ani --delete "$STAGING_DIR/" "$PACKAGE_DIR/"
  echo "Dry run complete; no Grok Bot plugin files were changed."
  exit 0
fi

mkdir -p "$PACKAGE_DIR"
rsync -a --delete "$STAGING_DIR/" "$PACKAGE_DIR/"

if ! diff -qr "$STAGING_DIR" "$PACKAGE_DIR" >/dev/null; then
  echo "Plugin verification failed: installed files differ from the package" >&2
  diff -qr "$STAGING_DIR" "$PACKAGE_DIR"
  exit 1
fi

if ! "$GROK_BIN" plugin marketplace list --json | jq -e --arg path "$SOURCE_DIR" \
  'any(.[]; .kind == "local" and .source.path == $path)' >/dev/null; then
  "$GROK_BIN" plugin marketplace add "$SOURCE_DIR"
fi

installed_source="$("$GROK_BIN" plugin list --json | jq -r --arg name "$PLUGIN_NAME" \
  'first(.[] | select(.name == $name) | .source) // empty')"

if [[ -n "$installed_source" && "$installed_source" != "$PACKAGE_DIR" ]]; then
  "$GROK_BIN" plugin uninstall "$PLUGIN_NAME" --keep-data --confirm
  installed_source=""
fi

if [[ -n "$installed_source" ]]; then
  "$GROK_BIN" plugin update "$PLUGIN_NAME"
else
  "$GROK_BIN" plugin install "$PLUGIN_NAME" --trust
fi

"$GROK_BIN" plugin enable "$PLUGIN_NAME"

echo "Installed, enabled, and verified from the local marketplace: $PACKAGE_DIR"
echo "Reload the Grok Bot Marketplace, then open Installed or search for $PLUGIN_NAME."
