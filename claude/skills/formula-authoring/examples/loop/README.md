# `Step.Loop` examples

Demonstrates iteration via `Step.Loop`. A step with a `[steps.loop]` block declares loop config + a `[[steps.loop.body]]` array of body steps; bd cook unrolls the loop into the cooked proto.

## Files

- `loop-count.formula.toml` — `count = 3` loop with a single body step
- `expected-cook.json` — verified `bd cook` output for the count loop
- `loop-until.formula.toml` — `until + max` dev↔review loop (runtime-deferred form)
- `expected-cook-until.json` — verified `bd cook` output for the until loop

## Cook targets

```bash
bd cook loop-count
bd cook loop-until
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
| `until = "<condition>" + max = N` | Cooks to a SINGLE iteration with the loop config in the **first body step's** `labels` metadata. The runtime is expected to honor the until condition; cook does not unroll. Example label: `loop:{"max":5,"until":"steps.complete >= 3"}`. **See "until + max status in bd v1.0.3" below — this form is currently a no-op end-to-end.** |

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

## `until + max` status in bd v1.0.3

Verified end-to-end against bd v1.0.3 (Homebrew) on 2026-05-11 using `loop-until.formula.toml`:

| Stage | Result |
|---|---|
| `bd cook` of formula | ✅ Succeeds. Loop body emits a single `iter1` per body step. The `loop:{"max":N,"until":"..."}` JSON is attached to the **first body step only** as a `labels` entry. |
| `bd mol pour` of cooked proto | ❌ The `loop:{...}` label is **stripped** when issues are materialized — the poured Implement issue has `labels: null`. |
| Runtime re-emission via `bd ready` after closing one pass | ❌ No re-emission. After closing Design + Implement + Review, `bd ready` advances directly to Ship. No `iter2` is created. |
| `needs` chains around the dissolved wrapper | ❌ Both `dev needs design` (inherited via the wrapper) and `ship needs dev-review` (downstream of the wrapper id) are dropped silently — Design / Implement / Ship all surface as ready in parallel after pour. |

**Net:** in bd v1.0.3, `until + max` is schema-valid and round-trips through cook, but is functionally a no-op once you pour and execute. If you need optional looping (e.g. dev↔review with bounded retries), today you must either:

1. **Express the loop inside a single step** — let one `Implement` step's agent body re-invoke a reviewer subagent and iterate internally, never closing the step until the reviewer is satisfied or `max` is hit. The loop then lives in the agent's prompt, not in bd's DAG.
2. **Use `count = N` with conditional bodies** — unroll the maximum number of pairs at cook time and put a `condition` on each body step that short-circuits once approved. Bloats the cooked DAG but keeps the iteration visible in `bd mol show`.
3. **File a bd feature request** — for first-class until-loop support, bd needs to (a) preserve the `loop:` label through pour, and (b) teach the mol state machine to re-open or re-emit the body steps when the until condition fails after a pass.

## Sources

- `gastownhall/beads/internal/formula/controlflow.go` — `ApplyLoops` implementation
- `gastownhall/beads/internal/formula/condition.go` — `ParseCondition` syntax
