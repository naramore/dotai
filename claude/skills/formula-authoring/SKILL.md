---
name: formula-authoring
description: >-
  How to author and edit bd workflow formulas (`*.formula.toml` files). Covers
  the four formula types and the composition + control-flow primitives bd's
  schema supports — extends, expansion, advice, aspect+compose, branch, loop,
  and the prose-directive pattern — with a decision tree for picking the right
  primitive and a draft-cook script for validating as you go. Load when
  authoring or editing any `.formula.toml`, debugging "why isn't my sub-formula
  being invoked", or asked anything about bd's formula schema, composition,
  templates, advice, or aspects.
---

# Formula Authoring

Construct **valid, quality, composable** bd workflow formulas. The bd schema offers six structural composition mechanisms plus four control-flow primitives plus one runtime convention; picking the wrong one (or missing the menu entirely) leads to brittle formulas that don't survive `bd cook` and can't be refactored cleanly.

## Core principle

**Survey the schema before authoring; cook your draft before declaring done.** Two complementary moves:

1. *Survey:* the canonical schema is `internal/formula/types.go` in [gastownhall/beads](https://github.com/gastownhall/beads). The decision tree below covers the most common authoring choices; the reference docs cover the rest. Don't author from recall — bd has more primitives than any one runtime exposes.
2. *Cook:* run `scripts/cook-draft.sh <your-formula>.formula.toml` while authoring. The cooked proto JSON is ground truth — if it's not what you expected, fix the formula before moving on. See § "Validate your draft" below.

The canonical authoring lapse — using a prose-directive (`description = "<runtime> <formula>..."`) where a clean structural `expand = "<formula>"` would do — happens when an author works from runtime docs without consulting bd's full schema, then never cooks the formula to see the runtime drop the directive.

## Quick start

1. Copy [`assets/TEMPLATE.formula.toml`](assets/TEMPLATE.formula.toml) and rename to `<your-name>.formula.toml`.
2. Edit the placeholders (the formula `name` field MUST equal the filename without `.formula.toml`).
3. Walk the decision tree below to pick composition primitives.
4. `scripts/cook-draft.sh <your-name>.formula.toml` — confirm the cooked proto matches your intent.
5. Iterate.

## Formula types

`Formula.Type` drives what the body declares. Pick the type before anything else.

| `type =` | Body shape | Use for |
|---|---|---|
| `"workflow"` (default) | `[[steps]]` array | Top-level executable workflows |
| `"expansion"` | `[[template]]` array (no `[[steps]]`) | Sub-formulas invoked via `Step.Expand` or `[compose] [[expand]]` |
| `"aspect"` | `[[advice]]` + optional `[[pointcuts]]` (no `[[steps]]`) | Reusable cross-cutting advice applied to workflows via `[compose] aspects = [...]` |
| `"convoy"` | `[inputs]` + `[prompts]` | Parallel-leg fan-out workflows. Out of scope here — see gastown's `code-review.formula.toml` if you need one |

## Decision tree

Walk top-to-bottom; first match wins. For each match, follow the link to the runnable example.

### Composition (cross-formula reuse)

1. **N formulas share `[vars]` or initial `[[steps]]`?** → `extends` a base. See [`examples/extends/`](examples/extends/).
2. **One step's job is "execute formula X end-to-end"?** → `expand`. Convert X to `type = "expansion"` with `[[template]]`. See [`examples/expansion/`](examples/expansion/) (or [`examples/compose-expand/`](examples/compose-expand/) for the `[compose] [[expand]]` form).
3. **Need to wrap existing steps with telemetry / gating / audit logging?**
   - Targets are in the **same formula**: inline `[[advice]]`. See [`examples/advice/`](examples/advice/).
   - Targets are inherited via `extends`, OR the same advice should apply to N workflows: extract a `type = "aspect"` formula and apply via `[compose] aspects = [...]`. See [`examples/aspect/`](examples/aspect/).
4. **Two whole workflows attach at named seams?** → `[compose] [[bond_points]]` + `[[hooks]]`. ⚠️ Schema-only in bd v1.0.3; cook a smoke test before relying on it. See [`examples/compose/`](examples/compose/).
5. **Runtime supports prose-directives, AND the dispatch is genuinely runtime-conditional?** → prose-directive in step body. See [`examples/prose-directive/`](examples/prose-directive/).

### Control flow (within-formula structure)

These compose with the choices above (some with caveats — see [Compatibility matrix](#compatibility-matrix)).

| Question | Primitive | Example |
|---|---|---|
| Step that runs N times sequentially? | `[steps.loop] count = N` | [`examples/loop/`](examples/loop/) |
| Parallel split with explicit join? | `[compose] [[branch]]` | [`examples/branch/`](examples/branch/) |
| Step has logical sub-tasks? | `[[steps.children]]` | [`examples/children/`](examples/children/) |
| Step needs an approval gate? | `[steps.gate]` (or `[compose] [[gate]]`) | [`references/control-flow.md`](references/control-flow.md) |
| Step runs conditionally? | `condition = "env.X == 'val'"` | [`references/control-flow.md`](references/control-flow.md) |
| Step waits for another step's children? | `waits_for = "children-of(<id>)"` | [`references/control-flow.md`](references/control-flow.md) |
| Step fans out per output item? | `[steps.on_complete] for_each = "output.X"` | [`references/control-flow.md`](references/control-flow.md) |

If you reach prose-directive (step 5) by default rather than by elimination, you've probably skipped a primitive — re-walk the tree.

## Validate your draft

`bd cook` is the canonical authoring-side validator: if cook produces the proto you expect, the formula is schema-valid. Don't ship a formula you haven't cooked.

```bash
# Cook a single draft formula:
scripts/cook-draft.sh my-workflow.formula.toml

# Cook with helpers (e.g., aspect + workflow that applies it):
scripts/cook-draft.sh aspect-base.formula.toml my-aspect.formula.toml my-secured.formula.toml
# (cooks the LAST file; the others are loaded into the workspace so cross-references resolve)

# Pass extra bd args after `--`:
scripts/cook-draft.sh deploy.formula.toml -- --mode=runtime --var environment=staging
```

The script creates an ephemeral `.beads/` workspace, copies your draft(s) into `.beads/formulas/`, runs `bd cook`, strips the per-run `source` field, and cleans up on exit. Requires `bd` and `jq` on PATH.

**Two failure modes to watch for in the cooked output:**
- Steps you declared are *missing* — a primitive's materialization isn't applying. Common cause: declaring `[[advice]]` in a child formula targeting an inherited step (use the aspect pattern instead — see decision tree step 3).
- Steps you didn't declare are *present* — composition is materializing fields you forgot about. Usually fine, but verify the `needs` chains are what you wanted.

## Compatibility matrix

What composes cleanly with what (verified empirically against bd v1.0.3). ✅ = both materialize; ⚠️ = works with caveat; ❌ = conflict.

| Combination | Result |
|---|---|
| `extends` × `extends` (multi-parent / diamond) | ✅ inheritance order is left-to-right |
| `extends` × child `[[steps]]` with same id | ✅ child overrides parent's step entirely |
| `extends` × child `[vars.X]` redeclaring parent's | ✅ child's default overrides parent's |
| `extends` × child `Step.Expand` referencing inherited step | ✅ |
| `extends` × child `[[advice]]` targeting inherited step | ❌ silently dropped — use aspect pattern instead |
| `extends` × `[compose] aspects` (workflow inherits another workflow's aspects) | ✅ aspects propagate transitively |
| `[compose] aspects` × multiple aspects on one workflow | ✅ apply in declaration order |
| `[compose] aspects` × inline `[[advice]]` on same workflow | ✅ both apply (parallel before-deps) |
| Aspect formula `extends` another aspect formula | ⚠️ only the child aspect's advice applies; parent's is NOT inherited |
| Aspect targeting expanded steps via glob (e.g., `target = "*.expanded"`) | ✅ aspects apply after expansion materializes |
| Aspect with multiple `[[advice]]` rules on the same target | ✅ all rules apply, in declaration order |
| `[[template]]` step with its own `expand` field (nested expansion) | ⚠️ inner expand is dropped — only the outer template step appears |
| `Step.Loop` × `Step.Gate` on the same wrapper step | ⚠️ gate is LOST after loop unrolling |
| `Step.Loop` × `Step.Condition` on the same wrapper step | ⚠️ condition is LOST after loop unrolling |
| `Step.Loop` × `[[steps.children]]` on the same wrapper step | ⚠️ children are LOST after loop unrolling |
| `Step.Loop` × `[compose] [[branch]]` referencing the loop wrapper | ❌ loop dissolves the wrapper before branch wires it |
| `Step.Expand` × `[compose] [[expand]]` on the same target | ❌ Step.Expand consumes the step first; compose.expand can't find it |
| Parent downstream `needs = ["<expanded-id>"]` × inline `Step.Expand` | ❌ left dangling in cooked output (bd v1.0.3) |
| Parent downstream `needs = ["<expanded-id>"]` × `[compose] [[compose.expand]]` | ✅ auto-rewired to last template step |
| Template `id = "{target}.<verb>"` × `[compose] [[compose.expand]]` | ✅ `{target}` substituted to parent step id; rewiring still works |
| `[[pointcuts]]` declared with no advice referencing them | ✅ roundtrip as metadata; no effect on cook |

**General rule:** any control-flow primitive that *dissolves* the wrapper step (loop, expand) loses other primitives attached to that same step. Attach them to a sibling step or to one of the body/template steps instead.

## Quality conventions

These follow gastown's production formulas (`gastown/internal/formula/formulas/`). Not enforced by bd, but consistent with how the broader corpus is authored — diverging without reason will surprise downstream consumers.

| Aspect | Convention | Example |
|---|---|---|
| **Filename** | `<name>.formula.toml` (the `.formula.toml` suffix is **required** for bd discovery) | `mol-bugfix.formula.toml` |
| **Formula `name` field** | kebab-case, matches filename without suffix | `formula = "mol-bugfix"` |
| **Type prefixes** | `mol-*` for top-level molecules, `aspect-*` or domain-named for aspects, no prefix for shared bases | `mol-feature`, `security-audit`, `shiny` |
| **Step `id`** | kebab-case; for templates use `{target}.<verb>` | `id = "design"`, `id = "{target}.write-tests"` |
| **`title`** | Imperative, ≤ ~50 chars, sentence-case | `"Implement {{feature}}"` |
| **`description`** | Multi-line markdown is fine; be specific. Embed acceptance criteria in markdown if they need to survive cook (the bare `acceptance` field is silently dropped) | `"""Write tests. **Acceptance:** failing tests committed."""` |
| **`notes`** | Use for hand-off context that shouldn't crowd the description | `"Reproduced via session-replay; see INC-4523"` |
| **Var names** | snake_case | `[vars.window_hours]`, `[vars.target_environment]` |
| **`{{var}}` substitution** | Only walks step `description` strings — does NOT walk into TOML tables; runtime handles those | `description = "Deploy to {{environment}}"` |
| **Var substitution at expansion time** | When a template formula is materialized into a parent via `expand` / `compose.expand`, bd substitutes the expansion's vars-with-defaults into template `description` strings using the default value (unless the parent binds the var). Required-no-default vars stay as `{{name}}`. Avoid literal `{{name}}` tokens in prose that *describes* placeholders, or accept that they'll render as the default in cooked output | `default = "partial"` → `` `{{degradation}}` `` becomes `` `{partial}` `` after cook |
| **Dependency declaration** | Use `needs`, not `depends_on`. Both fields exist and roundtrip independently; production formulas use `needs` | `needs = ["design"]` |

Browse [gastown's formula corpus](https://github.com/gastownhall/gastown/tree/main/internal/formula/formulas) for ~50 worked examples in production.

## Worked example — prose-directive vs structural `expand`

A step that needs to invoke another formula end-to-end can be written two ways. The wrong way:

```toml
[[steps]]
id          = "gather"
description = """
Run the `gather-inputs` formula with `since=<setup.window_start>`.
The composed formula returns the standard envelope ...
"""
```

Cooked, this step's body is opaque text — `bd cook` doesn't know it composes another formula, dependency-graph tooling can't see it, and refactors across consumers will drift. The right way is `expand`:

```toml
[[steps]]
id     = "gather"
title  = "Fan-out reads via gather-inputs"
needs  = ["setup"]
expand = "gather-inputs"
```

…paired with a `gather-inputs.formula.toml` of `type = "expansion"` declaring `[[template]]` instead of `[[steps]]`. After cooking, the parent's `gather` step is replaced by the template's full DAG and the cooked proto reflects the actual composition.

**One wrinkle**: inline `expand` leaves downstream `needs = ["gather"]` dangling in cooked output (bd v1.0.3 — see [`references/composition-strategies.md`](references/composition-strategies.md) § 2 edge cases). If any sibling step in the parent waits on the expanded step, switch to the `[compose] [[compose.expand]]` form, which auto-rewires those references to the expansion's last template step:

```toml
[[steps]]
id          = "gather"
title       = "Fan-out reads via gather-inputs"
needs       = ["setup"]
description = "stub; replaced by gather-inputs at cook time"

# ...other steps including downstream consumers like:
[[steps]]
id    = "diff"
needs = ["gather"]      # auto-rewired to the last template step after cook

[compose]
[[compose.expand]]
target = "gather"
with   = "gather-inputs"
```

The `expand` family survives `bd cook`, can be reasoned about by tooling, and won't drift across consumers.

The trap — picking prose where a structural primitive would do — is the most common authoring mistake bd's broader schema is designed to prevent. The decision tree above surfaces the structural primitive first; the cook script catches the mistake if it slips through.

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Authoring without cooking the draft (relying on the formula "looking right") | Many failure modes are silent — advice dropped at the extends boundary, `acceptance` field stripped, runtime fields not parsed by your runtime. The cooked proto is the only ground truth |
| Treating one runtime's docs as the canonical schema | Runtimes parse subsets; you'll miss `expansion`/`advice`/`compose` and over-use prose-directive (the most common authoring mistake) |
| Defaulting to prose-directive without walking the decision tree | Composition becomes invisible to `bd cook`; refactoring across consumers gets harder |
| Inlining what should be a sub-formula | When the next workflow needs the same chunk, you'll either copy-paste-drift or do an awkward retro-extraction |
| Stacking `loop` / `expand` with other primitives on the same step | Anything that dissolves the step loses the others — see compatibility matrix |
| Declaring `[[advice]]` in a child formula targeting inherited steps | Silently dropped; use `aspect` + `compose.aspects` |
| Using the `acceptance` field expecting it to survive cook | bd's TOML parser silently drops unknown fields. Embed acceptance criteria in `description` markdown if it needs to round-trip |
| Authoring an aspect formula with `[[steps]]` | Aspect formulas have no executable body — `[[steps]]` is ignored. The advice rules ARE the payload |
| Skipping `type = "expansion"` on a sub-formula | Without the type field, the `[[template]]` block isn't recognized as an expansion target |
| Treating `extends` and `expand` as interchangeable | `extends` copies fields into the child at the formula level; `expand` replaces a single step at cook time. Different semantics |

## Reference index

The reference files cover deeper material than the decision tree's common-case answers. Load on demand.

| Reference | Covers |
|---|---|
| [composition-strategies.md](references/composition-strategies.md) | Per-primitive schema and semantics for every composition primitive in `Formula.Compose` |
| [control-flow.md](references/control-flow.md) | `Step.Gate` / `Step.Condition` / `Step.WaitsFor` / `Step.OnComplete` with empirically-verified syntax tables (including the strict condition-format grammar and `waits_for` accepted forms) |
| [var-def.md](references/var-def.md) | Full `[vars]` schema: `default`, `required`, `enum`, `pattern`, `type`, `description` |
| [issue-metadata.md](references/issue-metadata.md) | Step issue-level fields (`type`, `priority`, `labels`, `assignee`, `notes`, `metadata`) and the dropped `acceptance` non-field |

Bundled scripts and assets:

| Path | Purpose |
|---|---|
| [`scripts/cook-draft.sh`](scripts/cook-draft.sh) | Cook one or more draft formulas in an ephemeral workspace; print the proto |
| [`scripts/run-structural-evals.sh`](scripts/run-structural-evals.sh) | Verify the bundled examples still cook to the expected proto (regression detector) |
| [`assets/TEMPLATE.formula.toml`](assets/TEMPLATE.formula.toml) | Starter template for a new workflow formula |
| [`examples/`](examples/) | Runnable examples per primitive — each with formula TOML, expected cook output, and README |
