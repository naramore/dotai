# `compose` example

Demonstrates schema-correct cross-formula bonding declarations: a source formula declares a `bond_point`; a target formula declares a `hook` subscribing to that bond point's trigger name.

## Files

- `compose-a.formula.toml` — source: declares `[[compose.bond_points]]` named `after-build`
- `compose-b.formula.toml` — target: declares `[[compose.hooks]]` with `trigger = "after-build"`
- `expected-cook-a.json` — `bd cook compose-a` output
- `expected-cook-b.json` — `bd cook compose-b` output

## Cook targets

```bash
bd cook compose-a
bd cook compose-b
```

## Verified behavior (bd v1.0.3)

⚠️ **Schema-recognized but not materialized.** Cooking each formula in isolation roundtrips the `compose` block as metadata in the proto (`bond_points` and `hooks` are present in the JSON output), but no actual cross-formula composition happens. There's no `bd` command that takes both formulas and produces a bonded multi-formula molecule via these declarations.

The `expected-cook-{a,b}.json` files capture current cook output as regression baselines. If a future bd version implements compose materialization (likely via a new command or a `--bond` flag on cook), this eval will fail and prompt an update.

Treat compose as **schema-supported but unverified for runtime materialization** until an empirical test against your bd version proves otherwise.
