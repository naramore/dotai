# `aspect` example — cross-formula advice via `compose.aspects`

Demonstrates the canonical pattern for applying advice across formula boundaries: a separate **aspect formula** (`type = "aspect"`) declares the advice rules, and a **workflow formula** opts in via `[compose] aspects = ["aspect-name"]`. This is how `gastown/internal/formula/formulas/shiny-secure.formula.toml` applies `security-audit.formula.toml`.

## Files

- `aspect-base.formula.toml` — workflow formula with `design → implement → submit` steps
- `aspect-security.formula.toml` — `type = "aspect"` formula declaring `[[advice]]` rules and `[[pointcuts]]`
- `aspect-secured.formula.toml` — workflow formula that `extends = ["aspect-base"]` and applies the aspect via `[compose] aspects = ["aspect-security"]`
- `expected-cook.json` — verified `bd cook aspect-secured` output

## Cook target

```bash
bd cook aspect-secured
```

## Verified behavior (bd v1.0.3)

✅ **Cook materializes the aspect's advice across the extends boundary.** The cooked proto contains both the inherited base steps AND the aspect's wrapping steps, with `needs` chained correctly:

```
design → implement-prescan → implement → implement-postscan
                                       ↘ submit-prescan → submit → submit-postscan
```

The aspect's two `[[advice]]` rules (one targeting `implement`, one targeting `submit`) each materialize their `around.before` and `around.after` steps, with `{step.id}` substitution producing per-target ids (`implement-prescan` vs `submit-prescan`).

## Why this pattern beats the inline-advice-in-child pattern

The `examples/advice/` example shows advice declared inline in the same formula as its targets. That works, but doesn't compose across formula boundaries — declaring `[[advice]]` in a child formula targeting a step inherited via `extends` is silently dropped (see `examples/advice/README.md` § "Wrinkle").

This aspect example uses the canonical bd mechanism instead:

| Approach | Where advice lives | Cross-boundary? |
|---|---|---|
| Inline `[[advice]]` (see `examples/advice/`) | Same formula as the target steps | ❌ Does not cross extends |
| **Aspect formula + `compose.aspects`** (this example) | Separate `type = "aspect"` formula | ✅ Composes onto any workflow that opts in |

The split-and-compose model is also more reusable: one aspect formula (e.g., `security-audit`) can be applied to N different workflows via `aspects = [...]`, without duplicating the advice rules.

## Aspect formula structure

An aspect formula:

- Has `type = "aspect"`
- Declares `[[advice]]` rules at the top level (same schema as inline advice — `target` glob, `before`/`after`/`around`)
- Optionally declares `[[pointcuts]]` (matchers — also at the top level) so tooling can discover what step patterns the aspect targets
- Has no `[[steps]]` of its own (the advice rules are the entire payload)

## Workflow opt-in

The consuming workflow:

- Has `type = "workflow"` (or omits `type`, which defaults to workflow)
- May `extends = [...]` other workflow formulas to inherit steps
- Adds `[compose] aspects = ["aspect-name", ...]` to apply one or more aspects

The `aspects` value is an array — multiple aspects can be applied to one workflow, and they materialize in declaration order.

## Sources

- `gastownhall/gastown/internal/formula/formulas/security-audit.formula.toml` — production aspect formula this example is modeled on
- `gastownhall/gastown/internal/formula/formulas/shiny-secure.formula.toml` — production workflow that applies security-audit
- `gastownhall/beads/internal/formula/types.go` — `FormulaType` enum (aspect = "aspect"), `ComposeRules.Aspects []string`
- `gastownhall/beads/internal/formula/advice.go` + `advice_test.go` — advice application semantics
