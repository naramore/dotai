#!/usr/bin/env bash
# sync-from-repo.sh — Install/restore opencode config from repo to local machine
# Usage: ./scripts/sync-from-repo.sh [--dry-run]
#
# Copies commands, skills, and non-secret config files from the repo to your
# local opencode config directory. Does NOT overwrite opencode.json or
# .claude/settings.json — those must be set up manually with your tokens.
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
  echo "==> Dry run: showing differences (repo → local)"
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
  echo "==> Installing config from repo to local..."
  mkdir -p "$OC_CONFIG/commands" "$OC_CONFIG/skills"
  mkdir -p "$CLAUDE_CONFIG"
  echo "  Installing commands..."
fi

for f in "$REPO_DIR/commands/"*.md; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  sync_file "$f" "$OC_CONFIG/commands/$name" "commands/$name"
done

# --- Skills ---
if $DRY_RUN; then
  echo ""
  echo "Skills:"
else
  echo "  Installing skills..."
fi

for skill_dir in "$REPO_DIR/skills"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  if ! $DRY_RUN; then
    mkdir -p "$OC_CONFIG/skills/$skill_name"
  fi
  for skill_file in "$skill_dir"*; do
    [ -f "$skill_file" ] || continue
    skill_file_name="$(basename "$skill_file")"
    sync_file "$skill_file" "$OC_CONFIG/skills/$skill_name/$skill_file_name" "skills/$skill_name/$skill_file_name"
  done
  # Subdirectories
  for subdir in "$skill_dir"*/; do
    [ -d "$subdir" ] || continue
    sub_name="$(basename "$subdir")"
    if ! $DRY_RUN; then
      mkdir -p "$OC_CONFIG/skills/$skill_name/$sub_name"
    fi
    for sub_file in "$subdir"*; do
      [ -f "$sub_file" ] || continue
      sub_file_name="$(basename "$sub_file")"
      sync_file "$sub_file" "$OC_CONFIG/skills/$skill_name/$sub_name/$sub_file_name" "skills/$skill_name/$sub_name/$sub_file_name"
    done
  done
done

# --- Config files ---
if $DRY_RUN; then
  echo ""
  echo "Config files:"
else
  echo "  Installing config files..."
fi

for f in oh-my-opencode-slim.json dcp.jsonc tui.json \
         package.json opencode-notifier.json babel.config.js; do
  [ -f "$REPO_DIR/config/$f" ] && sync_file "$REPO_DIR/config/$f" "$OC_CONFIG/$f" "config/$f"
done

# --- Summary ---
if $DRY_RUN; then
  echo ""
  echo "==> Dry run complete. No files were changed."
  echo "    Run without --dry-run to apply."
else
  # Install npm dependencies if package.json was updated
  if [ -f "$OC_CONFIG/package.json" ]; then
    echo "  Installing npm dependencies..."
    (cd "$OC_CONFIG" && npm install --silent 2>/dev/null) || echo "  (npm install failed — run manually)"
  fi

  echo ""
  echo "==> Done! Config installed to $OC_CONFIG"
  echo ""

  # Check for opencode.json
  if [ ! -f "$OC_CONFIG/opencode.json" ]; then
    echo "WARNING: opencode.json not found!"
    echo "  Copy the template and fill in your secrets:"
    echo "    cp $REPO_DIR/config/opencode.template.json $OC_CONFIG/opencode.json"
    echo "    # Then edit to add your email, Sourcegraph token, and GitHub token"
    echo ""
  fi

  # Check for .claude/settings.json
  if [ ! -f "$CLAUDE_CONFIG/settings.json" ]; then
    echo "WARNING: .claude/settings.json not found!"
    echo "  Copy the template and fill in your secrets:"
    echo "    cp $REPO_DIR/claude/settings.template.json $CLAUDE_CONFIG/settings.json"
    echo "    # Then edit to add your Anthropic auth token and email"
    echo ""
  fi

  echo "Restart opencode to pick up changes."
fi
