# Examples

Runnable examples for each composition primitive covered by the skill. Every example is a minimal TOML pair (or single file for prose-directive) plus an `expected-cook.json` capturing the actual `bd cook` output.

## Contents

| Directory | Primitive | Cook target | Verified materialization (bd v1.0.3) |
|---|---|---|---|
| [`extends/`](extends/) | `extends` (inheritance) | `extends-child` | ✅ |
| [`expansion/`](expansion/) | `expansion` (template substitution) | `expansion-caller` | ✅ |
| [`advice/`](advice/) | `advice` (before / after / around, inline) | `advice-three-forms` | ✅ all three forms materialize |
| [`aspect/`](aspect/) | aspect formula + `compose.aspects` (cross-formula advice) | `aspect-secured` | ✅ aspect's advice materializes across extends boundary |
| [`compose/`](compose/) | `compose` `bond_points` + `hooks` (cross-formula bonding) | `compose-a`, `compose-b` | ⚠️ schema only |
| [`compose-expand/`](compose-expand/) | `[compose] [[expand]]` (formula-level expand rule) | `compose-expand-caller` | ✅ materializes identically to inline `Step.Expand` |
| [`branch/`](branch/) | `[compose] [[branch]]` (parallel branches + join) | `branch-test` | ✅ wires from-step → N parallel branches → join |
| [`loop/`](loop/) | `Step.Loop` (count) | `loop-count` | ✅ unrolls count=N to N sequential iterations |
| [`children/`](children/) | `Step.Children` (nested steps) | `children-test` | ✅ preserves nested hierarchy in cooked proto |
| [`prose-directive/`](prose-directive/) | runtime-conditional pattern | `prose-directive-example` | N/A — not a bd schema feature |

## Running the structural evals

```bash
./scripts/run-structural-evals.sh
```

The script:

1. Creates a fresh tempdir
2. `bd init`s a beads workspace inside it
3. Copies all example formulas into `.beads/formulas/`
4. Runs `bd cook` on each example's target formula
5. Strips the per-run absolute `source` path from each output
6. Diffs against the example's `expected-cook.json`
7. Cleans up the tempdir on exit (via `trap`)

Requires `bd` v1.0+ and `jq` on PATH.

## Why expected-cook captures current behavior even when the primitive is incomplete

For `advice` and `compose`, bd v1.0.3 doesn't fully materialize the composition — but the `expected-cook.json` still captures the actual current cook output. The eval acts as a **regression detector**: if a future bd version starts materializing advice or compose, the cook output will change and the eval will fail loudly, prompting an update to both the expected output and the surrounding documentation. Until then, the eval guarantees that today's incomplete behavior is at least stable and known.
