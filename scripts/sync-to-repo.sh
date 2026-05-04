#!/usr/bin/env bash
# sync-to-repo.sh — Copy skills from ~/.claude/skills/ back into this repo
# Usage: ./scripts/sync-to-repo.sh [--dry-run]
#
# For each skill directory present in claude/skills/, mirrors the local
# ~/.claude/skills/<name>/ contents back into the repo via `rsync -a --delete`.
# Iterates over the REPO's skill list — local skills that aren't tracked
# in the repo are NOT pushed up (the repo is public-shape per AGENTS.md P2).
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
  echo "==> Dry run: showing what would change (~/.claude/skills/ → repo)"
else
  echo "==> Syncing skills from $LOCAL_SKILLS to repo"
fi

synced=0
skipped=0
for skill_dir in "$REPO_SKILLS"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  src="$LOCAL_SKILLS/$skill_name/"

  if [ ! -d "$src" ]; then
    echo "  skip $skill_name (not present in $LOCAL_SKILLS)"
    skipped=$((skipped + 1))
    continue
  fi

  if $DRY_RUN; then
    echo ""
    echo "--- $skill_name ---"
  fi

  rsync "${RSYNC_FLAGS[@]}" "$src" "$skill_dir"
  synced=$((synced + 1))
done

echo ""
if $DRY_RUN; then
  echo "==> Dry run complete ($synced inspected, $skipped skipped). Run without --dry-run to apply."
else
  echo "==> Done. $synced skills synced to repo ($skipped skipped)."
  echo ""
  echo "Next: cd $REPO_DIR && git status && git diff"
fi
