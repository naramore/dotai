# Step Control-Flow Reference

Step-level control-flow fields beyond the basic `needs` DAG: `Step.Gate`, `Step.Condition`, `Step.WaitsFor`, `Step.OnComplete`. All four are validated empirically against bd v1.0.3.

For loops and nested children, see the [`examples/loop/`](../examples/loop/) and [`examples/children/`](../examples/children/) runnable examples.

## `Step.Condition`

Conditional execution. The step runs only when the condition evaluates true.

```toml
[[steps]]
id        = "ci-only"
title     = "CI-only step"
condition = "env.CI == 'true'"
```

Conditions follow `internal/formula/condition.go::ParseCondition`. Recognized formats (verified against the regex patterns in the source):

| Format | Pattern | Example |
|---|---|---|
| **Field comparison** | `<field>(.<subfield>)* <op> <value>` | `step.status == 'complete'` |
| **Aggregate** | `(children\|descendants\|steps)(<step>).<all\|any\|count>(<inner>)` | `children(impl).all(status == 'complete')` |
| **File existence** | `file.exists('<path>')` | `file.exists('go.mod')` |
| **Environment variable** | `env.<NAME> <op> <value>` | `env.CI == 'true'` |
| **Steps statistic** | `steps.<stat> <op> <int>` | `steps.complete >= 3` |
| **Count comparison** | `<aggregate>.count(<inner>) <op> <int>` | `children(x).count(status=='done') >= 3` |

Operators: `==`, `!=`, `<`, `<=`, `>`, `>=`. Interpolation-style placeholders like `"{result.done}"` are NOT a valid format — cook rejects them with "unrecognized condition format".

## `Step.Gate`

Synchronization barrier on a step.

```toml
[[steps]]
id    = "deploy"
title = "Deploy to prod"
[steps.gate]
type    = "approval"
timeout = "1h"
# Optional: id = "..." awaiting on a specific gate id
# Optional: await_id = "..." waiting on another gate to release
```

`Gate.Type` is required. `Timeout` is a duration string (e.g., `"30m"`, `"1h"`, `"24h"`). The cooked output preserves the gate metadata on the step. Runtime semantics (what does "approval" mean, how does the gate release) are runtime-defined.

Formula-level alternative: `[compose] [[gate]]` rule (see [`composition-strategies.md`](composition-strategies.md) § compose). The Step.Gate form attaches a gate inline; the compose form lets the gate live separately from the step it gates.

## `Step.WaitsFor`

Cross-step waits, scoped to children of named parent steps.

```toml
[[steps]]
id    = "parent"
title = "Parent"
[[steps.children]]
id = "kid-1"
[[steps.children]]
id = "kid-2"

[[steps]]
id        = "wait-then-act"
title     = "Wait for all of parent's children"
waits_for = "children-of(parent)"
```

`WaitsFor` accepts only three forms (verified empirically — other strings fail validation):

| Form | Meaning |
|---|---|
| `all-children` | Wait until ALL children of the *containing parent* complete |
| `any-children` | Wait until ANY child of the containing parent completes |
| `children-of(<step-id>)` | Wait until all children of the named external step complete |

Common error: `all-children(parent)` — the parenthesized form is only for `children-of`, not `all-children` / `any-children`.

## `Step.OnComplete`

Fan-out behavior triggered when the step completes.

```toml
[[steps]]
id    = "discover"
title = "Discover items"
[steps.on_complete]
for_each = "output.items"        # MUST start with "output."
bond     = "process-item"        # name of the bond to dispatch per item
parallel = true                  # or sequential = true
# Optional: vars = { key = "value" }   passed to each spawned bond
```

`for_each` must reference a step output via the `output.<name>` prefix — bare identifiers (`items`) fail validation. The runtime spawns one instance of the named `bond` per item in the named output collection, in parallel (or sequential).

`OnComplete.Sequential` is the inverse of `Parallel` — set exactly one. Both default to false (no fan-out).

## Combining control-flow fields

Multiple control-flow fields can stack on a single step:

```toml
[[steps]]
id        = "guarded-loop"
title     = "Conditional gated loop"
condition = "env.PHASE == 'execute'"     # only runs in execute phase
[steps.gate]                              # plus an approval gate
type    = "approval"
timeout = "1h"
[steps.loop]                              # plus a count loop
count = 5
[[steps.loop.body]]
id    = "iter"
title = "Iteration"
```

Application order at cook-time: control-flow fields are applied in a defined sequence (loops, branches, gates, then advice expansion). Verify the cooked output if your formula stacks multiple fields — order can matter for `needs` rewiring.

## Sources

- `gastownhall/beads/internal/formula/controlflow.go` — `ApplyControlFlow`, `ApplyLoops`, `ApplyBranches`, `ApplyGates`
- `gastownhall/beads/internal/formula/condition.go` — `ParseCondition`
- `gastownhall/beads/internal/formula/stepcondition.go` — step-level condition evaluation
- `gastownhall/beads/internal/formula/types.go` — `Gate`, `LoopSpec`, `OnCompleteSpec`, `WaitsForSpec`
