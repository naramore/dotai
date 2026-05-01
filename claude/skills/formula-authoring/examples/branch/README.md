# `compose.branch` example

Demonstrates parallel-branches-with-join via `[compose] [[branch]]`. A `from` step fans out to N parallel branches; all branches converge at a `join` step.

## Files

- `branch-test.formula.toml` — `main` step + 3 branch steps (`branch-a`, `branch-b`, `branch-c`) + `merge` join + `[compose] [[branch]]` rule wiring them
- `expected-cook.json` — verified `bd cook` output

## Cook target

```bash
bd cook branch-test
```

## Verified behavior (bd v1.0.3)

✅ Cook materializes the wiring:
- Each branch step's `needs` is set to `["main"]` (depend on the from-step)
- The join step's `needs` is set to `["branch-a", "branch-b", "branch-c"]` (depend on all branches)

```
       ↗ branch-a ↘
main → → branch-b → → merge
       ↘ branch-c ↗
```

The branch and join steps **must pre-exist** in the formula's `[[steps]]` array — `compose.branch` wires them; it does not create them. If the listed step IDs aren't found, cook fails with `branch: parallel step "X" not found` or `branch: join step "Y" not found`.

## Why use `compose.branch` instead of declaring `needs` directly

You could achieve the same DAG by declaring each branch step with `needs = ["main"]` and the join with `needs = ["branch-a", "branch-b", "branch-c"]`. The `compose.branch` rule centralizes the fan-out structure as a single declarative block, which is easier to read and refactor when the branch list changes. It also documents *intent* (this is a parallel-with-join structure) in a way that scattered `needs` arrays do not.

## Sources

- `gastownhall/beads/internal/formula/types.go` — `BranchRule` (From/Steps/Join)
- `gastownhall/beads/internal/formula/controlflow.go` — `ApplyBranches`
