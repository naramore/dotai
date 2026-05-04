#!/usr/bin/env bash
# sync-from-repo.sh — Install skills from this repo into ~/.claude/skills/
# Usage: ./scripts/sync-from-repo.sh [--dry-run]
#
# For each skill directory in claude/skills/, mirrors its contents into
# ~/.claude/skills/<name>/ via `rsync -a --delete`. Skills that exist locally
# but are NOT in the repo are left untouched — only repo-tracked skills are
# managed by this script.
#
# Options:
#   --dry-run    Show what would change without copying anything

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
REPO_SKILLS="$REPO_DIR/claude/skills"
LOCAL_SKILLS="$HOME/.claude/skills"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

RSYNC_FLAGS=(-a --delete --exclude=.DS_Store)
$DRY_RUN && RSYNC_FLAGS+=(-n -i)

if [ ! -d "$REPO_SKILLS" ]; then
  echo "ERROR: $REPO_SKILLS does not exist" >&2
  exit 1
fi

if $DRY_RUN; then
  echo "==> Dry run: showing what would change (repo → ~/.claude/skills/)"
else
  echo "==> Syncing skills from repo to $LOCAL_SKILLS"
  mkdir -p "$LOCAL_SKILLS"
fi

count=0
for skill_dir in "$REPO_SKILLS"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  dest="$LOCAL_SKILLS/$skill_name/"

  if $DRY_RUN; then
    echo ""
    echo "--- $skill_name ---"
  fi

  $DRY_RUN || mkdir -p "$dest"
  rsync "${RSYNC_FLAGS[@]}" "$skill_dir" "$dest"
  count=$((count + 1))
done

echo ""
if $DRY_RUN; then
  echo "==> Dry run complete ($count skills inspected). Run without --dry-run to apply."
else
  echo "==> Done. $count skills synced to $LOCAL_SKILLS"
fi
