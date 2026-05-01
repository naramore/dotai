# Composition Strategies — Deep Reference

Per-primitive coverage of bd's formula composition mechanisms. The main `SKILL.md` covers the inventory and decision tree; this reference covers each primitive's full schema, materialization semantics (verified against bd v1.0.3 where applicable), and known gaps.

Authoritative source for everything below: `gastownhall/beads/internal/formula/types.go`. Re-read it when in doubt; the schema can evolve faster than this doc. Where this reference shows verified `bd cook` output, the runnable example lives at [`../examples/<primitive>/`](../examples/).

## 1. `extends` — inheritance

### Schema

```toml
formula = "child-formula"
extends = ["parent-formula", "another-parent"]   # ordered
```

`Formula.Extends []string` per types.go.

### Semantics

The child formula inherits:
- All `[vars.*]` definitions from each parent
- All `[[steps]]` from each parent
- All `[[template]]` entries (if the parent is `type = "expansion"`)

The child can:
- Add new `[vars.*]` entries (these augment the inherited set)
- Add new `[[steps]]` (these are appended after inherited steps)
- Override an inherited step by declaring a step with the same `id`
- Override a `[vars.*]` entry by re-declaring it

The child cannot remove an inherited step or var directly; if you need to drop something, the parent shouldn't have included it.

### When to use

- A family of formulas share setup/teardown/safety-rails; extract a base and have each child inherit
- You want shared `[vars]` defaults across a family

### Worked example

See [`../examples/extends/`](../examples/extends/) — `extends-base.formula.toml` declares `setup` step and `greeting` var; `extends-child.formula.toml` extends it and adds a `work` step depending on the inherited `setup`. The expected cook output (in `expected-cook.json`) shows both steps and the inherited var in the resolved proto.

### Edge cases

- **Diamond inheritance** — `extends = ["A", "B"]` where both A and B extend C. C's contents are deduplicated; conflicts resolved by extends order
- **Step ID collision** — a child step with the same id as a parent step **overrides** (replaces) the parent step entirely, not merges
- **Var override** — same: child re-declaration replaces parent definition

### Verified behavior

✅ bd v1.0.3 cooks extends end-to-end. Inherited steps and vars appear in the cooked proto.

---

## 2. `expansion` — template substitution

### Schema

**On the expansion formula (the sub-formula):**

```toml
formula = "expansion-callee"
type    = "expansion"
version = 1

[[template]]
id    = "fetch"
title = "..."
description = "..."

[[template]]
id    = "transform"
needs = ["fetch"]
description = "..."
```

**On the parent formula:**

```toml
[[steps]]
id     = "do-work"
title  = "Do the work via expansion"
needs  = ["prep"]
expand = "expansion-callee"            # name of the expansion formula
```

`Step.Expand string` + `Formula.Template []*Step` + `Formula.Type FormulaType` (= `"expansion"`) per types.go.

### Semantics

At cook-time (per `internal/formula/expand.go`):

1. `ApplyExpansions(steps, compose, parser)` walks the parent's steps
2. Any step with a non-empty `Expand` field is matched against the expansion formula by name
3. `MaterializeExpansion(f, targetID, vars)` replaces the target step with a deep copy of the expansion formula's `Template` steps
4. The expansion formula's first template step inherits the parent step's `needs` (so the chain attaches at the top)

### When to use

- A reusable workflow chunk that gets dropped into multiple parent formulas
- The chunk is meaningfully self-contained and worth maintaining as its own unit

### Worked example

See [`../examples/expansion/`](../examples/expansion/) — `expansion-callee.formula.toml` declares the template (`fetch → transform`); `expansion-caller.formula.toml` has a `do-work` step that expands it. The cooked output (in `expected-cook.json`) shows `prep → fetch → transform`, with the expansion's first step (`fetch`) inheriting `do-work`'s `needs`.

### Edge cases

- **Downstream `needs` rewiring** — if a downstream step in the parent has `needs = ["<expanded-step-id>"]`, behavior in bd v1.0.3 is to leave the dependency dangling (the expanded step's id no longer exists in the cooked output). Author defensively: avoid downstream steps that depend on the expanded step, or verify your bd version's rewiring behavior
- **Recursion** — an expansion that itself contains `expand` references is allowed; watch for cycles
- **Type field is required** — without `type = "expansion"`, the `[[template]]` block isn't recognized

### Verified behavior

✅ bd v1.0.3 cooks expansion end-to-end. Template steps replace the parent step in the cooked proto. The downstream-rewiring caveat above is the one known wrinkle.

---

## 3. `advice` — around-target wrappers

### Schema (per types.go)

```go
type AdviceRule struct {
    Target string         // glob pattern matching step IDs (e.g. "design", "*.implement", "shiny.*", "*")
    Before *AdviceStep    // single step inserted before target
    After  *AdviceStep    // single step inserted after target
    Around *AroundAdvice  // wraps target with multiple before AND after steps
}

type AdviceStep struct {
    ID          string             // supports {step.id} substitution
    Title       string             // supports {step.id} substitution
    Description string
    Type        string
    Args        map[string]string
    Output      map[string]string
}

type AroundAdvice struct {
    Before []*AdviceStep   // list — multiple steps chained before target
    After  []*AdviceStep   // list — multiple steps chained after target
}

type Pointcut struct {
    Glob  string
    Type  string
    Label string
}
```

```toml
# Single formula declaring all three advice forms.
formula = "advice-three-forms"
version = 1

[[steps]]
id = "design"
title = "Design"
description = "design phase"

[[steps]]
id = "implement"
title = "Implement"
needs = ["design"]
description = "implementation phase"

# BEFORE: one step inserted before `design`. Target's `needs` is rewired
# to depend on the inserted step.
[[advice]]
target = "design"
[advice.before]
id = "lint-{step.id}"     # → "lint-design"
title = "Lint before {step.id}"

# AROUND: paired LISTS of steps wrapping `implement`.
[[advice]]
target = "implement"
[advice.around]
before = [
  { id = "pre-scan", title = "Pre-scan" },
  { id = "checkout", title = "Checkout" }
]
after = [
  { id = "post-scan", title = "Post-scan" },
  { id = "tag-release", title = "Tag release" }
]
```

`Pointcut`s define matchers (glob/type/label) for cases where pointcut-style matching is more useful than `AdviceRule.Target`'s single glob string. Both `MatchGlob` and `MatchPointcut` are tested in `internal/formula/advice_test.go`.

### Semantics

Per `advice.go::ApplyAdvice` and the test cases in `advice_test.go`:

1. The function captures the set of **original** step IDs before applying advice (prevents self-matching against inserted steps)
2. For each step, find every advice rule whose `Target` glob matches the step's id
3. For each matching rule:
   - **before**: insert the before-step ahead of the target; target's `needs` becomes `[before-step.id]`
   - **after**: insert the after-step following the target; after-step's `needs` becomes `[target.id]`
   - **around**: insert the `before` list ahead of target (chained: each step needs the prior); target's `needs` includes the **last** before-step. Insert the `after` list following the target (chained: first needs target, each subsequent needs the prior)
4. `{step.id}` placeholders in inserted-step `id`/`title` are substituted with the matched step's id

The target step itself is **preserved** (unlike expansion, which replaces).

### When to use

- Cross-cutting concerns that shouldn't be in the target step's body — telemetry, audit logging, gating, retries
- Any concern that applies to N steps matching a glob pattern (e.g., `target = "*.review"` to gate all review-typed steps)

### Worked example

See [`../examples/advice/`](../examples/advice/) — `advice-three-forms.formula.toml` covers all three forms (`before`, `after`, `around`) plus `{step.id}` substitution. The `expected-cook.json` shows the complete materialized DAG with proper `needs` rewiring.

### Verified behavior

✅ **bd v1.0.3 cooks all three advice forms end-to-end** (before / after / around), including:
- `{step.id}` substitution in inserted step IDs and titles
- automatic `needs` rewiring (target depends on inserted-before; inserted-after depends on target; around chains)
- glob target matching (`*`, `*.suffix`, `prefix.*`, `*.middle-*`)
- self-matching prevention (a `target = "*"` rule does not recursively match its own insertions)

### Wrinkle: advice across the extends boundary

⚠️ Empirical test: a child formula that `extends` a parent and declares `[[advice]]` targeting an **inherited** step is silently dropped — the cooked output contains only the inherited steps with no advice materialized.

**Use § 4 (`aspect` formula + `compose.aspects`) for cross-extends advice instead.** Inline `[[advice]]` is the right tool for same-formula advice; the aspect pattern is the right tool for cross-formula advice. Both use the same underlying materialization machinery.

---

## 4. `aspect` formula + `compose.aspects` — cross-formula advice

### Schema

```go
// FormulaType is one of: "workflow", "expansion", "aspect", "convoy".
// An aspect formula has type = "aspect" and declares Advice + Pointcuts only.
type Formula struct {
    // ... fields including:
    Type      FormulaType
    Advice    []*AdviceRule
    Pointcuts []*Pointcut
    Compose   *ComposeRules
    // ...
}

// ComposeRules.Aspects is the workflow-side opt-in.
type ComposeRules struct {
    // ...
    Aspects []string  // names of aspect formulas to apply
    // ...
}
```

```toml
# aspect-security.formula.toml
formula = "aspect-security"
type    = "aspect"
version = 1

[[advice]]
target = "implement"
[advice.around]
[[advice.around.before]]
id    = "{step.id}-prescan"
title = "Security prescan for {step.id}"
[[advice.around.after]]
id    = "{step.id}-postscan"
title = "Security postscan for {step.id}"

# Optional — pointcuts make the targeted step patterns discoverable.
[[pointcuts]]
glob = "implement"
```

```toml
# aspect-secured.formula.toml — workflow that opts in
formula = "aspect-secured"
type    = "workflow"
extends = ["aspect-base"]

[compose]
aspects = ["aspect-security"]
```

### Semantics

At cook-time, the workflow's `[compose] aspects = [...]` list is processed: each named aspect formula is loaded and its `[[advice]]` rules are applied to the workflow's resolved step list (after `extends` inheritance). The application uses the same `ApplyAdvice` machinery as inline advice (`internal/formula/advice.go`), so all the same semantics apply: glob target matching, `{step.id}` substitution, automatic `needs` rewiring, self-matching prevention.

### When to use

- Same advice should apply to **multiple** workflows (e.g., one `security-audit` aspect applied to every release-class workflow)
- Advice needs to wrap steps inherited via `extends` — inline `[[advice]]` does not cross the extends boundary, but aspects do
- You want the advice rules to be a separately-versioned, separately-named unit

### Worked example

See [`../examples/aspect/`](../examples/aspect/) — three formulas: `aspect-base` (workflow with steps), `aspect-security` (aspect with around-advice), `aspect-secured` (workflow that extends + applies). The `expected-cook.json` shows the materialized 7-step DAG.

### Aspect formula constraints

- `type = "aspect"` is required
- The body declares `[[advice]]` (the payload) and optionally `[[pointcuts]]` (discoverable matchers)
- An aspect formula does NOT declare its own `[[steps]]` — it has no executable body of its own; the advice rules ARE the payload

### Verified behavior

✅ bd v1.0.3 materializes aspect-applied advice across the extends boundary. Verified empirically against `gastown/internal/formula/formulas/{security-audit, shiny-secure}.formula.toml` patterns and our own `examples/aspect/`.

### Why this exists alongside inline advice

Inline `[[advice]]` (covered in § 3) is for advice declared in the **same formula** as its targets. The aspect+compose pattern is for advice that needs to live **separately** from the targets — either for reuse across workflows or to apply to inherited steps. Both use the same underlying `ApplyAdvice` machinery; only the *declaration site* differs.

---

## 5. `compose` — the umbrella for formula-level rules

`Formula.Compose` is `*ComposeRules`. Beyond `aspects` (covered above in § 4), it carries five additional rule lists. Each is empirically tested below against bd v1.0.3.

### 5a. `compose.expand` — formula-level expand rules ✅

Equivalent to `Step.Expand` declared on the step itself, but lives in the `[compose]` block. The named target step is replaced by the named expansion formula's template at cook-time.

```toml
[compose]
[[compose.expand]]
target = "do"
with   = "sub-tpl"
```

Materializes identically to inline `Step.Expand`. Use when you want to keep step bodies and composition rules visually separated, or when the expansion is layered on rather than intrinsic to the step. See [`../examples/compose-expand/`](../examples/compose-expand/).

### 5b. `compose.branch` — parallel branches with join ✅

Wires a `from` step to N parallel branch steps that converge at a `join` step. All four step IDs must pre-exist in `[[steps]]`.

```toml
[compose]
[[compose.branch]]
from  = "main"
steps = ["branch-a", "branch-b", "branch-c"]
join  = "merge"
```

Cook output sets each branch step's `needs` to `["main"]` and the join step's `needs` to all branches. See [`../examples/branch/`](../examples/branch/).

### 5c. `compose.gate` — formula-level gates ✅

Adds a gate to a named step. The gate's metadata is added to the step's `labels` array in cooked output.

```toml
[compose]
[[compose.gate]]
before    = "deploy"
condition = "env.READY == 'true'"
```

Functionally similar to `Step.Gate` declared inline; the formula-level form keeps gates separate from step bodies. The condition syntax follows the same patterns as `Step.Condition` (see [`control-flow.md`](control-flow.md) § Condition).

### 5d. `compose.bond_points` + `compose.hooks` — cross-formula bonding ⚠️

See § 6 below — schema-only in bd v1.0.3.

### 5e. `compose.map` — parameterized fan-out ⚠️

Intended pattern: a step's runtime output (referenced via `select = "output.<name>"`) drives parameterized expansion of a named formula `with`.

```toml
[compose]
[[compose.map]]
select = "output.sources"
with   = "sub-tpl"
[compose.map.vars]
key = "value"
```

**Empirically:** the rule roundtrips in cooked output as metadata, but no fan-out steps are materialized at cook-time. Likely runtime-driven (the runtime sees the rule + the matching `OnComplete.for_each` and dispatches). Treat as schema-only for cook-time purposes; verify your runtime supports the materialization before depending on it.

---

## 6. `compose.bond_points` + `compose.hooks` — cross-formula bonding

### Schema (per types.go)

```go
type ComposeRules struct {
    BondPoints []*BondPoint
    Hooks      []*Hook
    Expand     []*ExpandRule
    Map        []*MapRule
    Branch     []*BranchRule
    Gate       []*GateRule
    Aspects    []string
}

type BondPoint struct {
    ID          string
    Description string
    AfterStep   string
    BeforeStep  string
    Parallel    bool
}

type Hook struct {
    Trigger string             // matches a BondPoint id
    Attach  string             // step id to attach
    At      string             // "before" / "after"
    Vars    map[string]string
}
```

```toml
# Source side — declares a bond point
formula = "compose-a"
version = 1

[[steps]]
id    = "build"
title = "Build"
description = "build"

[compose]
[[compose.bond_points]]
id         = "after-build"
after_step = "build"
```

```toml
# Target side — declares a hook subscribing to the bond point
formula = "compose-b"
version = 1

[[steps]]
id    = "notify"
title = "Notify"
description = "notify"

[compose]
[[compose.hooks]]
trigger = "after-build"
attach  = "notify"
at      = "before"
```

### Semantics (intended)

A formula declares `bond_points` (named seams) and/or `hooks` (named subscriptions to bond points). Cross-formula composition binds them at cook-time, producing a multi-formula molecule.

### When to use

- A release pipeline bonds to a notification pipeline at "after_complete"
- Two domain-specific workflows that share an attachment seam but are otherwise independent

### Worked example

See [`../examples/compose/`](../examples/compose/) — `compose-a.formula.toml` declares the bond point; `compose-b.formula.toml` declares the hook.

### Verified behavior

⚠️ **bd v1.0.3 roundtrips the compose declarations but does not perform cross-formula composition.** Empirical test: cooking either formula in isolation produces a proto containing the `compose` block as metadata (bond_points and hooks are present), but no actual binding between the two formulas occurs. The mechanism for invoking cross-formula compose at cook-time is not exercised by `bd cook <formula>` against either side individually. Treat as **schema-recognized but not yet materialized**. Verify against bd source + a smoke test before depending on compose.

---

## 7. `prose-directive` — runtime-conditional pattern

### Not a bd schema field

This is a convention recognized by some AI-interpretive runtimes at execution time. There is no corresponding field in `Formula` or `Step` — `bd cook` sees only the parent's step body as opaque text.

```toml
[[steps]]
id          = "gather"
description = """
<runtime> `gather-inputs` with `since=<setup.window_start>`. The composed
formula returns the standard envelope ...
"""
```

### Semantics

Runtimes that interpret step bodies via an LLM may recognize a directive in the prose and dispatch the named sub-formula at runtime. The directive's syntax is runtime-specific — consult your runtime's docs.

### When to use

- The dispatch is genuinely runtime-conditional (e.g., the executor decides which sub-formula to invoke based on prior step output)
- The runtime supports the directive AND the structural primitives (extends/expand/advice/compose) don't fit
- Quick prototyping before refactoring to a structural primitive

### When NOT to use

- The composition is statically known at authoring time → use `expand` instead
- Multiple parents need to invoke the same sub-formula → `expand` (with shared sub-formula) gives you tooling visibility; prose buries the composition

### Edge cases

- **bd cook ignores prose-directives entirely** — they're just text in a step body
- **Sub-formula composition is invisible to dependency analysis** — tools can't tell that formula A depends on formula B
- **Runtime-specific** — a formula authored for one runtime's prose-directive convention won't necessarily work under another runtime

### Verified behavior

N/A — bd cook produces the parent formula unchanged (the prose body roundtrips as opaque text). Whether any specific runtime materializes the directive is that runtime's question to answer.

See [`../examples/prose-directive/`](../examples/prose-directive/) for a schema-illustrative example.

---

## Cross-primitive composition rules

You can combine primitives in a single formula:

- A formula that `extends` a base AND uses `expand` in its own steps
- An expansion formula whose `[[template]]` includes steps that themselves `expand` other formulas
- A formula that uses both `compose` (cross-formula bonds) and prose-directive (runtime dispatch within steps)

The `bd cook` resolution order is approximately: extends first (inherit), then expansion (replace), then advice (wrap), then compose (bond). Verify against `internal/formula/expand.go` for current resolution semantics.

## When a primitive's behavior is unverified

For `advice` and `compose` (and any future schema additions), the honest authoring move is:

1. Read the struct definition in `types.go`
2. Write a minimal test formula
3. `bd cook <formula>` and inspect the proto JSON
4. If the cooked proto materializes the composition, the primitive works in your bd version
5. If the cooked proto roundtrips the declaration but doesn't materialize composition, the primitive is schema-only — choose a different primitive or wait for bd to implement materialization

Schema presence ≠ runtime support. The runnable [`examples/`](../examples/) directory captures this distinction explicitly.
