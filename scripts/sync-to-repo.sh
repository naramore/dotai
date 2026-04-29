#!/usr/bin/env bash
# sync-to-repo.sh — Copy local opencode config into repo for version control
# Usage: ./scripts/sync-to-repo.sh [--dry-run]
#
# This copies your current local config into the repo directory structure.
# SECRETS ARE EXCLUDED — opencode.json and .claude/settings.json contain tokens
# and are managed via template files instead.
#
# Options:
#   --dry-run    Show what would change without copying anything

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OC_CONFIG="$HOME/.config/opencode"
CLAUDE_CONFIG="$HOME/.claude"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "==> Dry run: showing differences (local → repo)"
  echo ""
fi

# Compare a source file to a destination file. In dry-run mode, show the diff.
# In normal mode, copy the file.
sync_file() {
  local src="$1" dst="$2" label="${3:-}"

  if $DRY_RUN; then
    if [ ! -f "$dst" ]; then
      echo "  + NEW: ${label:-$dst}"
    elif ! diff -q "$src" "$dst" &>/dev/null; then
      echo "  ~ CHANGED: ${label:-$dst}"
      diff --unified=3 "$dst" "$src" 2>/dev/null | head -30 || true
      echo ""
    fi
  else
    cp "$src" "$dst"
  fi
}

# --- Commands ---
if $DRY_RUN; then
  echo "Commands:"
else
  echo "==> Syncing local config to repo..."
  echo "  Syncing commands..."
  mkdir -p "$REPO_DIR/commands"
fi

for f in "$OC_CONFIG/commands/"*.md; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  sync_file "$f" "$REPO_DIR/commands/$name" "commands/$name"
done

# Check for commands in repo that no longer exist locally
for f in "$REPO_DIR/commands/"*.md; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  if [ ! -f "$OC_CONFIG/commands/$name" ]; then
    if $DRY_RUN; then
      echo "  - REMOVED locally: commands/$name"
    else
      echo "  Removing commands/$name (no longer exists locally)"
      rm "$f"
    fi
  fi
done

# --- Skills ---
if $DRY_RUN; then
  echo ""
  echo "Skills:"
else
  echo "  Syncing skills..."
fi

for skill_dir in "$OC_CONFIG/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  [[ "$skill_name" == ".DS_Store" ]] && continue
  if ! $DRY_RUN; then
    mkdir -p "$REPO_DIR/skills/$skill_name"
  fi
  if [ -f "$skill_dir/SKILL.md" ]; then
    sync_file "$skill_dir/SKILL.md" "$REPO_DIR/skills/$skill_name/SKILL.md" "skills/$skill_name/SKILL.md"
  fi
  # Subdirectories (scripts, references, subagents)
  for subdir in "$skill_dir"*/; do
    [ -d "$subdir" ] || continue
    sub_name="$(basename "$subdir")"
    if ! $DRY_RUN; then
      mkdir -p "$REPO_DIR/skills/$skill_name/$sub_name"
    fi
    for sub_file in "$subdir"*; do
      [ -f "$sub_file" ] || continue
      sub_file_name="$(basename "$sub_file")"
      sync_file "$sub_file" "$REPO_DIR/skills/$skill_name/$sub_name/$sub_file_name" "skills/$skill_name/$sub_name/$sub_file_name"
    done
  done
done

# Check for skills in repo that no longer exist locally
for skill_dir in "$REPO_DIR/skills"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  if [ ! -d "$OC_CONFIG/skills/$skill_name" ]; then
    if $DRY_RUN; then
      echo "  - REMOVED locally: skills/$skill_name/"
    else
      echo "  Removing skills/$skill_name/ (no longer exists locally)"
      rm -rf "$skill_dir"
    fi
  fi
done

# --- Config files ---
if $DRY_RUN; then
  echo ""
  echo "Config files:"
else
  echo "  Syncing config files..."
  mkdir -p "$REPO_DIR/config"
fi

for f in oh-my-opencode-slim.json dcp.jsonc tui.json \
         package.json opencode-notifier.json babel.config.js; do
  [ -f "$OC_CONFIG/$f" ] && sync_file "$OC_CONFIG/$f" "$REPO_DIR/config/$f" "config/$f"
done

# --- Summary ---
if $DRY_RUN; then
  echo ""
  echo "==> Dry run complete. No files were changed."
  echo "    Run without --dry-run to apply."
else
  echo ""
  echo "==> Done! Files synced to $REPO_DIR"
  echo ""
  echo "NOTE: opencode.json and .claude/settings.json are NOT synced (contain secrets)."
  echo "If you've changed provider/model config, manually update:"
  echo "  - config/opencode.template.json"
  echo "  - claude/settings.template.json"
  echo ""
  echo "Next: cd $REPO_DIR && git diff && git add -A && git commit"
fi
