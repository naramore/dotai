# dotai/formulas

Composable workflow definitions ("formulas") dispatched by the `pour` skill.

```
formulas/
├── library/              # generic *.toml formulas (one file per formula)
├── profiles/             # named bundles (lists of formulas)
├── config.example.toml   # config-shape boundary; project copies + fills
└── README.md             # this file
```

## Namespaces

- **`mol-*`** — bead-scoped, autonomous agent workflows (one unit of work).
- **`me-*`** — operator-scoped, human-in-the-loop workflows.

## Status

`library/` and `profiles/` are intentionally empty. New `me-*` formulas are
authored in a private overlay first (per "build where the data lives") and
`git mv`'d here once validated. Generic `mol-*` formulas may be added
directly when extracted from a public-safe source.

## TOML schema (v1)

```toml
description = """First line is the agent-facing short description."""
formula     = "<formula-id>"     # must match filename without .toml
version     = 1                  # bumped on backward-incompatible changes

[vars.<name>]
description = "What this variable is for"
required    = true               # default: false
default     = "<value>"          # required if not `required`

[[steps]]
id          = "<step-id>"        # unique within formula
title       = "Human-readable step title"
needs       = ["<other-step-id>"] # DAG dependencies; omit for entry steps
description = """
Markdown body the executor passes to the dispatched agent. May contain
fenced code blocks; `{{var}}` placeholders are substituted from `[vars]`.

**Exit criteria:** explicit, verifiable condition the executor checks
before marking the step done.
"""
```

Steps form a DAG via `needs`. The executor parallelizes sibling branches
and serializes dependents. See `claude/skills/pour/SKILL.md` for executor
semantics, idempotency rules, and posting/dispatch gates.

## Config

Org-specific values referenced by formula prompts (state issue ID, MCP
server names, priority framework refs, ticket prefixes) come from
`config.example.toml` keys, resolved against a project's local config and
any private overlay. **Never hardcode org-specific values in formula
prompts.**

## Profiles

Named bundles in `profiles/*.toml` group formulas for `init-project.sh`
to install at project bootstrap. Conventional names: `minimal`, `standard`,
`full`. Currently empty pending the first generic formulas.

## Invocation

Formulas are dispatched via the `pour` skill — there is no standalone CLI
at v0. Typical invocation:

> "Pour `<formula>`."
> "Pour `<formula>` with `<var>=<value>`."
