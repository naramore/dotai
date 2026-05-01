# `expansion` example

Demonstrates template substitution: a step in the caller marked with `expand = "<callee>"` is replaced at cook-time by the callee's `[[template]]` steps.

## Files

- `expansion-callee.formula.toml` — sub-formula with `type = "expansion"` and `[[template]]` steps (`fetch → transform`)
- `expansion-caller.formula.toml` — caller with a `do-work` step that expands the callee
- `expected-cook.json` — `bd cook expansion-caller` output (with `source` field stripped)

## Cook target

```bash
bd cook expansion-caller
```

## Verified behavior (bd v1.0.3)

✅ Cook materializes the expansion: `do-work` is replaced by `fetch → transform`. The first template step (`fetch`) inherits the parent step's `needs = ["prep"]`.

## Substitution in expansion templates

Three placeholder forms are recognized in `[[template]]` step `id`/`title`/`description` fields. Verified empirically:

| Placeholder | Substituted with | Example |
|---|---|---|
| `{target}` | The parent step's `id` | `id = "{target}.draft"` + parent step `feature-x` → `id = "feature-x.draft"` |
| `{target.title}` | The parent step's `title` | `title = "Draft for: {target.title}"` + parent title `Build feature X` → `title = "Draft for: Build feature X"` |
| `{target.description}` | The parent step's `description` | `description = "drafting {target.description}"` + parent desc `the X feature work` → `description = "drafting the X feature work"` |

Substitution is **lexical** (string replace) — it works wherever the placeholders appear in the template's text fields. Used heavily in production by `gastown/internal/formula/formulas/tdd-cycle.formula.toml` and `rule-of-five.formula.toml` to produce per-target id chains like `<target>.write-tests → <target>.verify-red → <target>.implement → <target>.verify-green → <target>.refactor`.

## Wrinkle to watch

If the caller has any *downstream* step with `needs = ["do-work"]`, bd v1.0.3 leaves the dependency dangling (the expanded id no longer exists). This example deliberately has no downstream dependents on `do-work` to stay clean. If you need downstream wiring, verify your bd version's rewiring behavior with a smoke test before depending on it.
