#!/usr/bin/env bash
# Structural evals for formula-authoring examples.
# Cooks each example with bd in an ephemeral tempdir and diffs against
# the example's expected-cook*.json (with the per-run `source` field stripped).

set -euo pipefail

skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
examples_dir="$skill_dir/examples"

command -v bd >/dev/null || { echo "FATAL: bd not on PATH"; exit 2; }
command -v jq >/dev/null || { echo "FATAL: jq not on PATH"; exit 2; }

tmpdir="$(mktemp -d)"
trap "rm -rf $tmpdir" EXIT

(cd "$tmpdir" && bd init >/dev/null 2>&1)
mkdir -p "$tmpdir/.beads/formulas"
cp "$examples_dir"/*/*.formula.toml "$tmpdir/.beads/formulas/"

# Map each expected-cook*.json file to the formula it should be compared against.
# Convention:
#   examples/<dir>/expected-cook.json     → cook formula <dir>-child if present, else <dir>-caller, else <dir>-advisor, else <dir>-example
#   examples/<dir>/expected-cook-<name>.json → cook formula <dir>-<name>
#
# Explicit mapping below avoids guessing wrong on edge cases.
declare -a tests=(
  "extends:extends-child:expected-cook.json"
  "expansion:expansion-caller:expected-cook.json"
  "advice:advice-three-forms:expected-cook.json"
  "aspect:aspect-secured:expected-cook.json"
  "compose:compose-a:expected-cook-a.json"
  "compose:compose-b:expected-cook-b.json"
  "compose-expand:compose-expand-caller:expected-cook.json"
  "branch:branch-test:expected-cook.json"
  "loop:loop-count:expected-cook.json"
  "children:children-test:expected-cook.json"
  "prose-directive:prose-directive-example:expected-cook.json"
)

failures=0
passes=0

for entry in "${tests[@]}"; do
  IFS=":" read -r dir formula expected_file <<< "$entry"
  expected_path="$examples_dir/$dir/$expected_file"

  if [[ ! -f "$expected_path" ]]; then
    echo "SKIP  $dir / $formula  (no $expected_file)"
    continue
  fi

  actual="$(BEADS_DIR="$tmpdir/.beads" bd cook "$formula" 2>/dev/null | jq 'del(.source)')"
  expected="$(jq 'del(.source)' "$expected_path")"

  if diff <(echo "$actual") <(echo "$expected") >/dev/null; then
    echo "PASS  $dir / $formula"
    passes=$((passes + 1))
  else
    echo "FAIL  $dir / $formula"
    diff <(echo "$expected") <(echo "$actual") | sed 's/^/      /'
    failures=$((failures + 1))
  fi
done

echo
echo "Results: $passes passed, $failures failed"
exit $failures
