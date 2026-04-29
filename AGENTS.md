# AGENTS.md — dotai

Agent contract for the `dotai` repo. If you're an AI agent landing here, this
file tells you what the project is, where things live, and the rules that
apply when you change them.

## Project overview

`dotai` is the public profile for AI-augmented engineering — generic skills,
the `pour` formula executor, and config-shape schemas. It is designed to
compose with a private overlay that supplies concrete values. Nothing
org-specific lands here.

## Guiding principles

See [`PRINCIPLES.md`](PRINCIPLES.md) — read first. P1-P9 govern every
decision in this repo, especially **P2** (public-shape from line one),
**P3** (build where the data lives), and **P9** (generic by default for
mechanical surfaces). When a change feels in tension with a principle,
name the principle and surface the tension before resolving.

## Directory map

```
dotai/
├── claude/skills/       # one skill per subdirectory; SKILL.md + any helpers
├── formulas/
│   ├── library/         # generic *.toml formulas (mol-* and validated me-*)
│   ├── profiles/        # named bundles (minimal/standard/full)
│   ├── config.example.toml
│   └── README.md
└── scripts/             # sync-to-repo.sh / sync-from-repo.sh
```

## Conventions

- **Public-shape from line one.** Any org-specific value (team key, MCP
  server name, priority framework reference, ticket prefix) goes through
  the `config.example.toml` boundary, never hardcoded into a skill or
  formula prompt.
- **Skills follow the [agentskills.io spec](https://agentskills.io/specification).**
  See `claude/skills/skill-authoring/SKILL.md` for the authoring workflow.
- **Formulas are TOML.** Schema lives in `formulas/README.md`; executor
  semantics live in `claude/skills/pour/SKILL.md`.
- **Markdown over prose for agent-facing docs.** Tables and headings parse
  better than paragraphs.

## Safety rails

**Forbidden:**
- Hardcoding org-specific values anywhere in this repo.
- Embedding executable workflow logic in skills (skills are reference;
  formulas are workflow).
- Editing `pour`'s state-mutation rules without a corresponding update to
  the formulas that depend on them.

**Requires review:**
- New skills (must conform to the agentskills.io spec; see `skill-authoring`).
- New formulas in `formulas/library/` (must validate against `pour`'s TOML
  schema and be free of org-specific values).
- Changes to `pour/SKILL.md` (the executor contract).

## Adding a new skill

1. Create `claude/skills/<name>/SKILL.md` with frontmatter (`name`,
   `description`).
2. Follow `skill-authoring` for structure, description optimization, and
   eval setup.
3. Verify it loads cleanly under Claude Code (frontmatter parses, no
   path issues).

## Adding a new formula

1. Validated `me-*` formulas migrate **into** this repo via `git mv` from a
   private overlay after 2-3 weeks of real use. Do not author new formulas
   directly here against zero users.
2. Generic `mol-*` formulas may be added directly if extracted from an
   existing public-safe source.
3. Every formula must reference all org-specific values via `{{var}}`
   placeholders backed by `config.example.toml` keys.

## Commands

This repo has no build step. Sync helpers are in `scripts/`.
