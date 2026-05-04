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
| **Inline `expand`** (`Step.Expand`) — see [`../expansion/`](../expansion/) | On the step itself: `expand = "sub-tpl"` | The expansion is intrinsic to the step's job AND no other parent step depends on it |
| **`[compose] [[expand]]`** (this example) | In the formula's `[compose]` block: `target = "<step-id>"`, `with = "<sub-formula>"` | Other parent steps depend on the expanded step (this form auto-rewires `needs`); or you want the expansion declared separately from the step body |

**Cooked output is NOT identical** (bd v1.0.3, verified). The semantic difference:

- **Inline `Step.Expand`** leaves downstream `needs = ["<expanded-id>"]` references **dangling** — the expanded id no longer exists, but the dep is preserved verbatim. See [`../expansion/expected-cook.json`](../expansion/expected-cook.json) (the `report` step keeps `needs = ["do-work"]` even though `do-work` is gone).
- **`[compose] [[compose.expand]]`** auto-rewires downstream `needs = ["<target>"]` to the expansion's **last template step**. Sibling consumers in the parent stay correctly wired.

Prefer `compose.expand` whenever the parent has steps that depend on the expanded step.

## `{target}` substitution is optional and orthogonal

This example's `sub-tpl.formula.toml` uses `id = "{target}.fetch"` to namespace template ids under the parent step (`do.fetch`, `do.process`). That substitution is purely cosmetic for ids — it does **not** affect downstream-needs rewiring (rewiring works on raw template ids too; see `references/composition-strategies.md` § 5a). Use `{target}` to:

- Avoid id collisions when the same expansion is materialized into N parent steps in one formula
- Avoid collisions between template ids and sibling step ids in the parent
- Make cooked output self-documenting about which expansion produced which step

## Sources

- `gastownhall/beads/internal/formula/types.go` — `ExpandRule` (Target/With/Vars), `ComposeRules.Expand []*ExpandRule`
- `gastownhall/beads/internal/formula/expand.go` — `ApplyExpansions` implementation
