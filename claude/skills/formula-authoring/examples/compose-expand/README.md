# `compose.expand` example

Demonstrates `[compose] [[expand]]` — a formula-level alternative to inline `Step.Expand`. The named target step is replaced by the named expansion formula's template at cook-time.

## Files

- `sub-tpl.formula.toml` — `type = "expansion"` formula with `[[template]]` (`fetch → process`)
- `compose-expand-caller.formula.toml` — caller with one step (`do`) that gets replaced via `[compose] [[expand]]` rule
- `expected-cook.json` — verified `bd cook compose-expand-caller` output

## Cook target

```bash
bd cook compose-expand-caller
```

## Verified behavior (bd v1.0.3)

✅ Cook materializes the expansion. The `do` step is replaced by the template's two steps with `{target}` substitution:

```
do.fetch → do.process
```

## Inline vs compose.expand

| Approach | Where declared | When to use |
|---|---|---|
| **Inline `expand`** (`Step.Expand`) — see [`../expansion/`](../expansion/) | On the step itself: `expand = "sub-tpl"` | The expansion is intrinsic to the step's job |
| **`[compose] [[expand]]`** (this example) | In the formula's `[compose]` block: `target = "<step-id>"`, `with = "<sub-formula>"` | The expansion is layered on, possibly conditionally; or you want to keep the step bodies and the composition rules separated visually |

Both produce identical cooked output. The difference is purely organizational — pick whichever reads more clearly for your formula.

## Sources

- `gastownhall/beads/internal/formula/types.go` — `ExpandRule` (Target/With/Vars), `ComposeRules.Expand []*ExpandRule`
- `gastownhall/beads/internal/formula/expand.go` — `ApplyExpansions` implementation
