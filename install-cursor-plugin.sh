#!/usr/bin/env bash
#
# Build and install this repository as a local Cursor plugin.
#
# Usage:
#   ./install-cursor-plugin.sh [--dry-run]
#
# The source repository remains marketplace-ready at its root. For local
# development, Cursor requires the complete plugin to live under
# ~/.cursor/plugins/local, so this script assembles an exact copy there.

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SOURCE_DIR/.cursor-plugin/plugin.json"
DESTINATION_ROOT="${CURSOR_LOCAL_PLUGIN_ROOT:-$HOME/.cursor/plugins/local}"
PLUGIN_NAME="$(jq -r '.name' "$MANIFEST")"
DESTINATION="$DESTINATION_ROOT/$PLUGIN_NAME"
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$MANIFEST" ]]; then
  echo "Cursor plugin manifest not found: $MANIFEST" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to read $MANIFEST" >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required to assemble the Cursor plugin" >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

mkdir -p "$STAGING_DIR/.cursor-plugin"
rsync -a "$MANIFEST" "$STAGING_DIR/.cursor-plugin/plugin.json"
rsync -a "$SOURCE_DIR/README.md" "$STAGING_DIR/README.md"

while IFS= read -r skill_path; do
  normalized_path="${skill_path#./}"
  source_skill="$SOURCE_DIR/$normalized_path"

  if [[ ! -f "$source_skill/SKILL.md" ]]; then
    echo "Declared skill is missing SKILL.md: $skill_path" >&2
    exit 1
  fi

  rsync -a "$source_skill/" "$STAGING_DIR/$normalized_path/"
done < <(jq -r '.skills[]' "$MANIFEST")

echo "Cursor plugin: $PLUGIN_NAME"
echo "Destination: $DESTINATION"
echo "Skills: $(jq '.skills | length' "$MANIFEST")"

if [[ "$DRY_RUN" -eq 1 ]]; then
  mkdir -p "$DESTINATION_ROOT"
  rsync -ani --delete "$STAGING_DIR/" "$DESTINATION/"
  echo "Dry run complete; no plugin files were changed."
  exit 0
fi

mkdir -p "$DESTINATION"
rsync -a --delete "$STAGING_DIR/" "$DESTINATION/"

if ! diff -qr "$STAGING_DIR" "$DESTINATION" >/dev/null; then
  echo "Plugin verification failed: installed files differ from the package" >&2
  diff -qr "$STAGING_DIR" "$DESTINATION"
  exit 1
fi

echo "Installed and verified: $DESTINATION"
echo "Restart Cursor or run Developer: Reload Window, then verify the plugin in Customize."
