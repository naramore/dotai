# `advice` example

Demonstrates all three advice forms — `before`, `after`, and `around` — plus `{step.id}` substitution and automatic `needs` rewiring.

## Files

- `advice-three-forms.formula.toml` — three sequential steps (`design → implement → submit`) plus three advice rules:
  - **before** advice on `design` (single inserted step `lint-design`)
  - **after** advice on `submit` (single inserted step `notify-submit`)
  - **around** advice on `implement` (paired step lists: `pre-scan → checkout` before, `post-scan → tag-release` after)
- `expected-cook.json` — verified `bd cook` output (with `source` field stripped)

## Cook target

```bash
bd cook advice-three-forms
```

## Verified behavior (bd v1.0.3)

✅ **Cook materializes all three advice forms.** The cooked proto's `steps` array becomes:

```
lint-design → design → pre-scan → checkout → implement → post-scan → tag-release
                                                       ↘ submit → notify-submit
```

With `needs` chains:

| Step | needs |
|---|---|
| `lint-design` | (none — first in chain) |
| `design` | `[lint-design]` (rewired by before-advice) |
| `pre-scan` | (none — first in around-before chain) |
| `checkout` | `[pre-scan]` (chained within around-before) |
| `implement` | `[design, checkout]` (original `[design]` + last around-before) |
| `post-scan` | `[implement]` (first around-after, depends on target) |
| `tag-release` | `[post-scan]` (chained within around-after) |
| `submit` | `[implement]` (original) |
| `notify-submit` | `[submit]` (rewired by after-advice) |

## Substitution

`{step.id}` placeholders in advice IDs/titles are replaced with the matched step's id at materialization time:

- `id = "lint-{step.id}"` + target `design` → `id = "lint-design"`
- `title = "Lint before {step.id}"` + target `design` → `title = "Lint before design"`

## Target patterns

`AdviceRule.Target` is a **glob pattern**, not just a literal step id. Per `internal/formula/advice_test.go`:

| Pattern | Matches |
|---|---|
| `"design"` | exactly `design` |
| `"*"` | every step |
| `"*.implement"` | `shiny.implement`, `design.implement` (suffix match) |
| `"shiny.*"` | `shiny.design`, `shiny.implement` (prefix match) |
| `"*.refine-*"` | `implement.refine-1`, `implement.refine-2` (both ends) |

Glob patterns enable advice that wraps every step matching a category (e.g., `target = "*"` for telemetry on all steps; `target = "*.review"` for gating all review-typed steps).

## Wrinkle: advice across the extends boundary — use an aspect formula instead

Empirical test: a child formula that `extends` a parent and declares `[[advice]]` targeting an inherited step ID **does not materialize** in bd v1.0.3. The advice declaration is silently dropped from the cooked output.

```toml
# This does NOT work in bd v1.0.3:
formula = "child"
extends = ["parent"]   # parent declares step "deploy"

[[advice]]
target = "deploy"      # targets the inherited step
[advice.before]
id = "audit"
title = "Audit"
# → cooked output contains only the inherited "deploy" step, no "audit"
```

**Canonical workaround: use an aspect formula + `compose.aspects`.** Declare the advice in a separate `type = "aspect"` formula and have the workflow opt in via `[compose] aspects = ["..."]`. This pattern is used in production by `gastown/internal/formula/formulas/shiny-secure.formula.toml` (workflow) + `security-audit.formula.toml` (aspect). See [`../aspect/`](../aspect/) for the runnable example.

The other workaround — declaring advice + targets in the same formula — is what this example demonstrates. Use it when the advice is one-off (specific to a single workflow). Use the aspect pattern when the advice is reusable across multiple workflows.

## Self-matching prevention

Per `advice_test.go::TestApplyAdvice_SelfMatchingPrevention`: an advice rule with `target = "*"` does **not** recursively match its own inserted steps. The application captures the original step ids before applying, then only matches against that set.

## Sources

- `internal/formula/advice.go` — `ApplyAdvice` implementation
- `internal/formula/advice_test.go` — `TestApplyAdvice_Before`, `TestApplyAdvice_After`, `TestApplyAdvice_Around`, `TestApplyAdvice_GlobPattern`, `TestApplyAdvice_SelfMatchingPrevention`, `TestMatchGlob`, `TestMatchPointcut`
- `internal/formula/types.go` — `AdviceRule`, `AdviceStep`, `AroundAdvice`, `Pointcut` struct definitions
