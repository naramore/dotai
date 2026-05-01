# `Step.Loop` example

Demonstrates iteration via `Step.Loop`. A step with a `[steps.loop]` block declares loop config + a `[[steps.loop.body]]` array of body steps; bd cook unrolls the loop into the cooked proto.

## Files

- `loop-count.formula.toml` — `count = 3` loop with a single body step
- `expected-cook.json` — verified `bd cook` output

## Cook target

```bash
bd cook loop-count
```

## Verified behavior (bd v1.0.3)

✅ **`count = N` unrolls to N sequential iterations.** Body step IDs become `<wrapper-id>.iter<N>.<body-id>`. Each iteration's `needs` chains from the previous one.

```
before → go.iter1.iter → go.iter2.iter → go.iter3.iter → after
```

⚠️ The `after` step's `needs = ["go"]` references the original wrapper id `go` — but `go` itself doesn't appear in the cooked steps array (the wrapper is dissolved into its iterations). This is a dangling reference in v1.0.3. To depend on the loop's last iteration, use `needs = ["<wrapper>.iter<N>.<body-id>"]` directly, which requires knowing the loop count statically.

## Other loop forms

| Loop form | Cook behavior |
|---|---|
| `count = N` | ✅ Unrolls to N iterations (this example) |
| `range = "1..N"` | ✅ Unrolls to N iterations. **Wrinkle:** `{i}` substitution in body step IDs/titles does NOT work — the literal `{i}` is preserved unsubstituted in the cooked output |
| `until = "<condition>" + max = N` | Cooks to a SINGLE iteration with the loop config in the iteration's `labels` metadata. The runtime is expected to honor the until condition; cook does not unroll. Example label: `loop:{"max":5,"until":"steps.complete >= 3"}` |

## Valid `until` condition syntax

Per `internal/formula/condition.go`, conditions follow these patterns (verified empirically):

| Pattern | Example |
|---|---|
| Field comparison | `step.status == 'complete'` |
| Aggregate over children | `children(step).all(status == 'complete')` |
| File existence | `file.exists('go.mod')` |
| Environment variable | `env.CI == 'true'` |
| Steps statistic | `steps.complete >= 3` |

A condition like `"{result.done}"` (interpolation-style) is NOT a valid format — `bd cook` rejects it with "unrecognized condition format."

## Sources

- `gastownhall/beads/internal/formula/controlflow.go` — `ApplyLoops` implementation
- `gastownhall/beads/internal/formula/condition.go` — `ParseCondition` syntax
