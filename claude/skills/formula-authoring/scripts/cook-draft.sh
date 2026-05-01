#!/usr/bin/env bash
# Cook one or more draft .formula.toml files in an ephemeral workspace.
#
# Usage:
#   cook-draft.sh <path-to-formula.toml> [<path-to-other-formula.toml> ...] [-- <bd-cook-args>]
#
# Cooks the LAST positional formula by default (the others are loaded into the
# workspace so cross-formula composition like `extends` / `compose.aspects`
# can resolve). Pass extra `bd cook` args after `--`.
#
# Examples:
#   cook-draft.sh my-formula.formula.toml
#   cook-draft.sh base.formula.toml my-aspect.formula.toml secured.formula.toml
#   cook-draft.sh deploy.formula.toml -- --mode=runtime --var environment=staging

set -euo pipefail

command -v bd >/dev/null || { echo "FATAL: bd not on PATH (install: brew install gastownhall/tap/bd)" >&2; exit 2; }
command -v jq >/dev/null || { echo "FATAL: jq not on PATH" >&2; exit 2; }

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <formula.toml> [<other.toml> ...] [-- <bd-cook-args>]" >&2
  exit 64
fi

# Split positional formulas from trailing bd-cook args.
formulas=()
cook_args=()
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--" ]]; then
    shift
    cook_args=("$@")
    break
  fi
  formulas+=("$1")
  shift
done

if [[ ${#formulas[@]} -eq 0 ]]; then
  echo "FATAL: at least one .formula.toml file required" >&2
  exit 64
fi

# Validate every input exists
for f in "${formulas[@]}"; do
  [[ -f "$f" ]] || { echo "FATAL: not a file: $f" >&2; exit 66; }
  [[ "$f" == *.formula.toml ]] || { echo "WARN: $f is not named *.formula.toml — bd will not discover it"; }
done

target="${formulas[-1]}"
target_name="$(basename "$target" .formula.toml)"

tmpdir="$(mktemp -d)"
trap "rm -rf $tmpdir" EXIT

(cd "$tmpdir" && bd init >/dev/null 2>&1)
mkdir -p "$tmpdir/.beads/formulas"

for f in "${formulas[@]}"; do
  cp "$f" "$tmpdir/.beads/formulas/$(basename "$f")"
done

echo "→ Cooking $target_name (workspace: $tmpdir)" >&2
BEADS_DIR="$tmpdir/.beads" bd cook "$target_name" "${cook_args[@]}" | jq 'del(.source)'
