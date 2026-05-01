# `extends` example

Demonstrates inheritance: a child formula inherits all `[vars]` and `[[steps]]` from a parent and adds its own.

## Files

- `extends-base.formula.toml` — parent: declares `setup` step + `greeting` var
- `extends-child.formula.toml` — child: extends the base, adds `work` step depending on inherited `setup`
- `expected-cook.json` — `bd cook extends-child` output (with `source` field stripped)

## Cook target

```bash
bd cook extends-child
```

## Verified behavior (bd v1.0.3)

✅ Cook materializes the inheritance: the proto contains both `setup` (inherited) and `work` (declared in child), plus the inherited `greeting` var.
