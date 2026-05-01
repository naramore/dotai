# `[vars]` Reference — VarDef Schema

`Formula.Vars` is `map[string]*VarDef`. Each entry under `[vars.<name>]` declares a variable that can be referenced in step `description` fields via `{{<name>}}` substitution.

## Schema (per `types.go`)

```go
type VarDef struct {
    Description string   `json:"description,omitempty"`
    Default     *string  `json:"default,omitempty"`
    Required    bool     `json:"required,omitempty"`
    Enum        []string `json:"enum,omitempty"`
    Pattern     string   `json:"pattern,omitempty"`
    Type        string   `json:"type,omitempty"`
}
```

All six fields are independently optional. Verified empirically — all roundtrip in `bd cook` output.

## Per-field semantics

| Field | Use for | Example |
|---|---|---|
| `description` | Human-readable purpose of the variable | `description = "Target deployment environment"` |
| `default` | Fallback value used when no override is provided. Stored as a pointer so absence vs explicit-empty are distinguishable | `default = "staging"` |
| `required` | If true, the runtime must collect a value before dispatching (no fallback to default) | `required = true` |
| `enum` | Closed set of valid values; runtime should reject anything else | `enum = ["dev", "staging", "prod"]` |
| `pattern` | Regex the value must match | `pattern = "^[0-9]+$"` |
| `type` | String tag for runtime use (e.g., `"string"`, `"number"`, `"bool"`). bd cook does not validate the value against the type — that's the runtime's job | `type = "string"` |

## Worked example

```toml
formula = "deploy-something"
version = 1

[vars.environment]
description = "Target deployment environment"
required    = true
enum        = ["dev", "staging", "prod"]
type        = "string"

[vars.retries]
description = "Number of retries on failure"
default     = "3"
pattern     = "^[0-9]+$"
type        = "number"

[[steps]]
id          = "deploy"
title       = "Deploy"
description = "Deploy to {{environment}} with up to {{retries}} retries"
```

Cooked output preserves the full `vars` block:

```json
"vars": {
  "environment": {
    "description": "Target deployment environment",
    "enum": ["dev", "staging", "prod"],
    "required": true,
    "type": "string"
  },
  "retries": {
    "default": "3",
    "description": "Number of retries on failure",
    "pattern": "^[0-9]+$",
    "type": "number"
  }
}
```

Note: bd cook stores `default` as a string (matching `*string` in the Go struct). Runtime consumers do the type coercion based on the `type` field.

## Substitution

`{{<name>}}` in step `description` strings is replaced at runtime (bd cook's compile mode preserves the placeholder; runtime mode substitutes). See `bd cook --help` § `--mode` and `--var`.

The `{{...}}` substitution does NOT walk into TOML tables/arrays — it only operates on top-level string fields. If you need substitution inside a table-valued field (e.g., `expand_vars = { since = "{{window_start}}" }`), the runtime is responsible for performing the substitution; bd cook leaves it as a literal string.

## Convoy formulas use `[inputs]`, not `[vars]`

`type = "convoy"` formulas (see gastown's `code-review.formula.toml`) declare runtime parameters under `[inputs]` with a different schema (`required_unless`, `type`, etc.). This skill does not cover convoy in depth — see the gastown source for examples.

## Sources

- `gastownhall/beads/internal/formula/types.go` — `VarDef` struct
- `gastownhall/beads/internal/formula/parser.go` — TOML parsing of vars
