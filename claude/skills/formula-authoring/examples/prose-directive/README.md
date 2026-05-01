# `prose-directive` example

Demonstrates the runtime-conditional prose-directive pattern: a step's `description` carries a directive that an AI-interpretive runtime may dispatch on at execution time. **Not a bd schema feature.**

## Files

- `prose-directive-example.formula.toml` — three-step formula whose middle step contains a runtime-dispatch directive in its prose
- `expected-cook.json` — `bd cook prose-directive-example` output (with `source` field stripped)

## Cook target

```bash
bd cook prose-directive-example
```

## Verified behavior (bd v1.0.3)

The cooked proto roundtrips the formula unchanged — the directive in the `gather` step's description is preserved as opaque text. `bd cook` does not recognize, parse, or act on the directive.

Whether any specific runtime materializes the directive at execution time is that runtime's question to answer. The directive syntax (`<runtime> <formula> with <args>`) shown here is illustrative — consult your runtime's docs for the exact convention it recognizes.

## Caveat

If the structural primitives (`extends` / `expand` / `advice` / `compose`) fit the composition need, prefer them — prose-directives are invisible to `bd cook` and to dependency-graph analysis tooling. Use prose-directives only when the composition is genuinely runtime-conditional or when the runtime doesn't yet parse the structural field you'd otherwise reach for.
