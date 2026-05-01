# `Step.Children` example

Demonstrates nested step hierarchy via `Step.Children`. A parent step declares `[[steps.children]]` sub-steps; the cooked output preserves the nesting.

## Files

- `children-test.formula.toml` — `phase-1` parent with two children (`subA`, `subB`); `phase-2` follows
- `expected-cook.json` — verified `bd cook` output

## Cook target

```bash
bd cook children-test
```

## Verified behavior (bd v1.0.3)

✅ Cook preserves the nesting in the proto: each parent step in the cooked `steps` array has a `children: [...]` array containing its sub-steps. Child-internal `needs` (e.g., `subB needs subA`) are preserved within the children array.

## When to use `children` vs separate top-level steps

| Pattern | Use when |
|---|---|
| `[[steps]]` (flat) | Steps are peers in the overall DAG and may be referenced by other top-level steps via `needs` |
| `[[steps.children]]` (nested) | Steps belong to a parent grouping; children are a logical sub-DAG of the parent |

Children are not directly addressable as `needs` targets from steps outside their parent (only the parent's id is referenceable from siblings).

## Combination with `WaitsFor`

A separate top-level step can wait for the parent's children using `waits_for = "children-of(<parent-id>)"`. See [`../../references/control-flow.md`](../../references/control-flow.md) § "WaitsFor".

## Sources

- `gastownhall/beads/internal/formula/types.go` — `Step.Children []*Step`
