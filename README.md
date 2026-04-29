# dotai

Public profile for AI-augmented engineering: skills, scripts, and a formula
runtime — designed to layer cleanly with a private overlay that holds
org-specific values.

## What's here

```
dotai/
├── claude/skills/    # generic skills loaded by Claude Code / OpenCode
├── formulas/         # composable workflow definitions + executor schema
└── scripts/          # sync helpers
```

## Mental model

`dotai` ships **shape**: generic skills, formula schemas, executor semantics,
config-shape boundary. Concrete values (org names, MCP servers, ticket IDs,
priority frameworks) live in a private overlay that references this profile
as its base layer.

When a tool needs the combined view, it walks both repos: `dotai` first,
overlay second. Anything in the overlay overrides or extends the public layer.

## Skills

Loaded from `claude/skills/`:

- `agents-md-authoring` — drafting style and structure for AGENTS.md files.
- `git-co-author` — AI commit attribution.
- `issue-spec` — issue authoring format.
- `pour` — formula executor (reads TOML, dispatches steps, enforces idempotency).
- `property-based-testing` — generative test design.
- `rule-of-five` — iterative-refinement review pattern.
- `skill-authoring` — meta-skill for creating skills per the agentskills.io spec.

## Formulas

See [`formulas/README.md`](formulas/README.md) for the schema, executor model,
and library status.

## Scripts

- `scripts/sync-to-repo.sh` — copy local Claude Code / OpenCode config into this repo.
- `scripts/sync-from-repo.sh` — copy this repo's config into local Claude Code / OpenCode.

## Discipline

Public-shape from line one: no org-specific values land here. Concrete config
goes in a private overlay; this repo only ships placeholders and schemas.
