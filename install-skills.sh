#!/usr/bin/env bash
#
# install-skills.sh — install the salesforce-skills set into Claude, Codex, or Cursor.
#
# Usage:
#   ./install-skills.sh claude   [--global|--project]   (default: global)
#   ./install-skills.sh codex    [--global]              (Codex is user-level only)
#   ./install-skills.sh cursor   [--project]              (Cursor is project-level only)
#   ./install-skills.sh all      [--global|--project]     (installs to all three)
#
#   --dry-run   Show what would happen without copying anything.
#   --list      List the skills this script will install, then exit.
#
# Run this from inside the extracted salesforce-skills folder (i.e. the folder
# containing this script, apex-architecture/, implement/, README.md, etc.),
# or from anywhere — it locates its own directory automatically.
#
# What it does NOT install: the integration/ folder. Those are reference docs
# (the corrected standards doc, the decision log, the interrogate lens) meant
# to be read by a human or dropped manually into another tool's reference
# folder — not skills an agent auto-loads.

set -euo pipefail

# ---- locate the skills next to this script, regardless of cwd ------------
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKILLS=()
for d in "$SOURCE_DIR"/*/; do
  name="$(basename "$d")"
  if [[ "$name" == "integration" ]]; then
    continue
  fi
  if [[ -f "$d/SKILL.md" ]]; then
    SKILLS+=("$name")
  fi
done

if [[ ${#SKILLS[@]} -eq 0 ]]; then
  echo "No skill folders with a SKILL.md found next to this script in $SOURCE_DIR" >&2
  echo "Make sure install-skills.sh sits alongside apex-architecture/, implement/, etc." >&2
  exit 1
fi

# ---- arg parsing -----------------------------------------------------------
TARGET=""
SCOPE=""
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --global) SCOPE="global" ;;
    --project) SCOPE="project" ;;
    --dry-run) DRY_RUN=1 ;;
    --list)
      printf '%s\n' "${SKILLS[@]}"
      exit 0
      ;;
    -h|--help)
      TARGET="--help"
      ;;
    claude|codex|cursor|all)
      TARGET="$arg"
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

usage() {
  cat >&2 <<EOF
Usage: $0 <claude|codex|cursor|all> [--global|--project] [--dry-run] [--list]

  claude   Installs to ~/.claude/skills (global, default) or ./.claude/skills (--project)
  codex    Installs to ~/.agents/skills (Codex is user-level; --project is not supported)
  cursor   Installs to ./.cursor/skills (Cursor is project-level; --global is not supported)
  all      Installs to all three using the sensible default for each

Run from inside a git repo when targeting codex or cursor project scope, so
./.claude or ./.cursor land in the right place.
EOF
}

if [[ -z "$TARGET" ]]; then
  usage
  exit 1
fi

# ---- copy helper ------------------------------------------------------------
install_to() {
  local dest_root="$1"
  local label="$2"

  mkdir -p "$dest_root"
  echo ""
  echo "== $label =="
  echo "Destination: $dest_root"

  for skill in "${SKILLS[@]}"; do
    local dest="$dest_root/$skill"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  [dry run] would sync $skill -> $dest"
      continue
    fi

    mkdir -p "$dest"
    # rsync if available (handles deletions of stale files cleanly), else cp fallback
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete "$SOURCE_DIR/$skill/" "$dest/"
    else
      rm -rf "$dest"
      cp -R "$SOURCE_DIR/$skill" "$dest"
    fi
    echo "  installed: $skill"
  done
}

# ---- per-agent targets -------------------------------------------------------
do_claude() {
  local scope="${SCOPE:-global}"
  case "$scope" in
    global) install_to "$HOME/.claude/skills" "Claude — global (~/.claude/skills)" ;;
    project) install_to "$(pwd)/.claude/skills" "Claude — project (./.claude/skills)" ;;
  esac
}

do_codex() {
  if [[ "$SCOPE" == "project" ]]; then
    echo "Note: Codex's documented skill path is user-level (~/.agents/skills)." >&2
    echo "Installing there. If your Codex version supports a project-level path," >&2
    echo "check its docs and rerun with that path directly." >&2
  fi
  install_to "$HOME/.agents/skills" "Codex — user-level (~/.agents/skills)"
}

do_cursor() {
  if [[ "$SCOPE" == "global" ]]; then
    echo "Note: Cursor skills are project-scoped; there is no confirmed global path." >&2
    echo "Installing to ./.cursor/skills in the current directory instead." >&2
  fi
  install_to "$(pwd)/.cursor/skills" "Cursor — project (./.cursor/skills)"
  echo ""
  echo "  Cursor's native context primitive is Rules (.cursor/rules/*.mdc), not"
  echo "  SKILL.md. Whether Cursor's harness auto-loads a bare .cursor/skills/"
  echo "  folder has been inconsistent across Cursor versions. If these don't"
  echo "  show up as available skills after a restart, package them as a Cursor"
  echo "  plugin instead (a skills/ folder inside a plugin manifest, the same"
  echo "  layout the pstack plugin uses for unslop and interrogate) and install"
  echo "  via Cursor's plugin/marketplace flow."
}

case "$TARGET" in
  claude) do_claude ;;
  codex) do_codex ;;
  cursor) do_cursor ;;
  all)
    do_claude
    do_codex
    do_cursor
    ;;
  --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown or missing target: $TARGET" >&2
    usage
    exit 1
    ;;
esac

echo ""
echo "Done. ${#SKILLS[@]} skills processed: ${SKILLS[*]}"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "(dry run — nothing was actually copied)"
fi
