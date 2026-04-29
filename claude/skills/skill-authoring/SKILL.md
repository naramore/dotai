---
name: skill-authoring
description: How to create and update agent skills following the agentskills.io specification. Covers directory structure, SKILL.md format, frontmatter fields, body content, progressive disclosure, testing, iteration, and validation. Load this when creating a new skill, updating an existing skill, iterating on skill quality, optimizing a skill description, or reviewing skill compliance.
---

# Skill Authoring — agentskills.io Specification

Create and update agent skills that conform to the [agentskills.io specification](https://agentskills.io/specification).

## Core Principle

**A skill is executable knowledge, not documentation.**

Skills are loaded into agent context to provide specialized instructions for specific tasks. Every line must earn its place — if it doesn't help an agent perform the task, remove it.

## Workflow

The process of creating a good skill:

1. **Capture intent** — understand what the skill should do and when it should trigger
2. **Write a draft** — create SKILL.md with frontmatter and instructions
3. **Test** — run realistic prompts with the skill loaded and evaluate results
4. **Iterate** — improve based on feedback, retest, repeat until satisfied
5. **Validate** — verify spec compliance before shipping

Don't over-invest in step 2. A rough draft tested early beats a polished draft tested never.

## Capturing Intent

Before writing, answer these questions:

1. **What should this skill enable?** — the specific capability
2. **When should it activate?** — user phrases, contexts, and tasks that trigger it
3. **What's the expected output?** — format, structure, artifacts produced
4. **What are the edge cases?** — unusual inputs, error conditions, ambiguous situations

If the current conversation already contains a workflow to capture (e.g., the user says "turn this into a skill"), extract answers from conversation history first: tools used, step sequence, corrections made, input/output formats observed. The user may need to fill gaps and should confirm before proceeding.

## Creating a New Skill

### 1. Choose a name

The name is the skill's identity. It must:

- Be 1-64 characters
- Contain only lowercase alphanumeric characters (`a-z`, `0-9`) and hyphens (`-`)
- Not start or end with a hyphen
- Not contain consecutive hyphens (`--`)
- Match the parent directory name exactly

Good: `jwt-auth`, `db-migration`, `api-design`
Bad: `JWT-Auth`, `db--migration`, `-api-design`, `my_skill`

### 2. Create the directory structure

```
skill-name/
├── SKILL.md          # Required: metadata + instructions
├── scripts/          # Optional: executable code
├── references/       # Optional: supplementary documentation
├── assets/           # Optional: templates, schemas, resources
└── ...               # Any additional files or directories
```

Only `SKILL.md` is required. Add optional directories only when they provide clear value.

### 3. Write the SKILL.md

The file has two parts: YAML frontmatter and Markdown body. Use [the starter template](assets/TEMPLATE.md) as a starting point.

## Frontmatter Reference

```yaml
---
name: skill-name                    # Required
description: What this does...      # Required
license: MIT                        # Optional
compatibility: Requires Python 3.9+ # Optional
metadata:                           # Optional
  author: your-name
  version: "1.0"
allowed-tools: Read Write Bash      # Optional, experimental
---
```

### Required Fields

| Field | Constraints | Purpose |
|-------|-------------|---------|
| `name` | 1-64 chars, lowercase alphanumeric + hyphens, no leading/trailing/consecutive hyphens, must match directory name | Unique identifier |
| `description` | 1-1024 chars, non-empty | Tells agents what the skill does and when to activate it |

### Optional Fields

| Field | Constraints | Purpose |
|-------|-------------|---------|
| `license` | Any string (keep short) | License name or reference to bundled license file |
| `compatibility` | 1-500 chars | Environment requirements: target product, system packages, network needs |
| `metadata` | Map of string keys to string values | Arbitrary key-value pairs for client-specific properties |
| `allowed-tools` | Space-separated string | Pre-approved tools the skill may use (experimental, support varies) |

### Writing a Good Description

The `description` is the primary signal agents use to decide whether to load a skill. It must answer:

1. **What does this skill do?** — the capability it provides
2. **When should it be used?** — the triggers and contexts for activation

Include specific keywords that help agents match tasks to skills. Agents tend to under-trigger skills, so descriptions should be slightly "pushy" about when to activate — name the contexts explicitly, even ones that seem obvious.

**Strong:**
```yaml
description: >-
  How to write database migration scripts using Alembic. Covers schema
  changes, data migrations, rollback strategies, and testing locally.
  Load this when creating, modifying, or troubleshooting database
  migrations, even if the user doesn't mention Alembic by name.
```

**Weak:**
```yaml
description: Database stuff.
```

## Body Content

The Markdown body after the frontmatter contains the skill instructions. There are no format restrictions — write whatever helps agents perform the task effectively.

### Recommended Structure

1. **Title** — H1 with skill name and purpose
2. **Core principle** — 1-2 sentences on why this matters
3. **Main content** — step-by-step instructions, decision tables, examples
4. **Anti-patterns** — common mistakes to avoid
5. **Quick reference** — TL;DR for experienced users

### Writing Philosophy

- **Explain the why** — today's LLMs respond better to motivated reasoning than rigid directives. Explaining *why* something matters is more effective than ALL-CAPS MUSTs and NEVERs. If you catch yourself reaching for heavy-handed rules, reframe as reasoning instead.
- **Generalize, don't overfit** — skills run across many diverse prompts. Avoid narrow instructions that only work for your test examples. Make guidance flexible enough to adapt to situations you haven't imagined.
- **Imperative mood** — "Create the file" not "You should create the file"
- **Concrete over abstract** — show exact commands, file paths, code snippets
- **Decision tables** — use tables for "when to use X vs Y" guidance
- **Complete examples** — include full, runnable code examples with language identifiers

### Size Budget

Keep `SKILL.md` under **500 lines** and under **5000 tokens**. If your skill exceeds this, split detailed reference material into files under `references/`.

## Optional Directories

### `scripts/`

Executable code that agents can run during skill execution. Scripts must be self-contained or clearly document dependencies, include helpful error messages, and handle edge cases gracefully.

### `references/`

Supplementary documentation loaded on demand, not at skill activation. Keep individual reference files focused — smaller files mean less context consumed.

### `assets/`

Static resources: templates, schemas, images, data files.

## Progressive Disclosure

Skills are loaded in three tiers — design for this:

| Tier | What's Loaded | When | Token Budget |
|------|---------------|------|-------------|
| **Metadata** | `name` + `description` | At startup, for all skills | ~100 tokens |
| **Instructions** | Full `SKILL.md` body | When skill is activated | < 5000 tokens |
| **Resources** | Files in `scripts/`, `references/`, `assets/` | Only when explicitly needed | As needed |

Put everything an agent needs for the common case in `SKILL.md`. Move deep-dive content to `references/`. The main `SKILL.md` must be useful on its own — never assume reference files will be loaded.

## File References

When referencing other files in your skill, use relative paths from the skill root:

```markdown
See [the reference guide](references/api-guide.md) for advanced usage.
Run the setup script: `scripts/setup.sh`
```

Rules:
- Keep references one level deep from `SKILL.md`
- Avoid deeply nested reference chains (file A → file B → file C)
- Every referenced file must exist in the skill directory

## Testing and Iteration

After writing a draft, test it:

1. **Create 2-3 realistic test prompts** — things a real user would actually say, not abstract requests. Include detail, context, and edge cases.
2. **Run with the skill loaded** — observe whether the agent follows the instructions correctly.
3. **Evaluate results** — check outputs against expected behavior. Look for patterns: did the agent misinterpret something? Ignore a section? Over-apply a rule?
4. **Improve the skill** — generalize from specific failures. If the agent struggles, the instructions may be ambiguous rather than wrong.
5. **Repeat** — iterate until the skill reliably produces good results across diverse prompts.

When improving, focus on:

- **Removing what doesn't help** — if instructions aren't improving outputs, cut them. Keep the prompt lean.
- **Explaining why over adding rules** — a well-motivated paragraph beats ten bullet points
- **Watching for repeated work** — if the agent keeps writing the same helper script across runs, bundle it in `scripts/`
- **Reading transcripts, not just outputs** — if the skill makes the agent waste time on unproductive steps, remove those instructions

For rigorous eval with subagents, grading, benchmarks, and a review viewer, see [the eval workflow](references/eval-workflow.md).

## Description Optimization

After creating or improving a skill, consider optimizing the description for better triggering accuracy. The process: generate realistic trigger/non-trigger eval queries, test whether the agent activates the skill correctly, then iterate on the description.

For the full optimization loop with automated tooling, see [description optimization](references/description-optimization.md).

## Updating an Existing Skill

When modifying a skill:

1. **Read the current SKILL.md** — understand what exists before changing it
2. **Validate the name** — the `name` field must still match the directory name
3. **Preserve the description's intent** — if updating, ensure it still accurately describes when to activate
4. **Check references** — if you rename or remove files, update all references in SKILL.md
5. **Verify size** — confirm the updated file stays under 500 lines
6. **Test progressive disclosure** — ensure the main SKILL.md is self-sufficient without reference files

### Common Update Operations

| Operation | Steps |
|-----------|-------|
| **Add a section** | Add to SKILL.md if under 500 lines; otherwise create a reference file and link to it |
| **Add a script** | Create in `scripts/`, add usage instructions to SKILL.md body |
| **Rename the skill** | Rename directory AND update `name` field — they must match |
| **Split a large skill** | Extract reference material to `references/`, keep core instructions in SKILL.md |
| **Add examples** | Prefer inline in SKILL.md; use `assets/` only for large templates |

## Validation Checklist

Before considering a skill complete, verify:

### Frontmatter
- [ ] `name` is present and 1-64 chars
- [ ] `name` contains only lowercase alphanumeric + hyphens
- [ ] `name` has no leading, trailing, or consecutive hyphens
- [ ] `name` matches the parent directory name exactly
- [ ] `description` is present and 1-1024 chars
- [ ] `description` explains both what the skill does AND when to use it
- [ ] `compatibility` (if present) is 1-500 chars
- [ ] `metadata` (if present) has only string keys and string values
- [ ] YAML frontmatter is enclosed in `---` delimiters

### Structure
- [ ] `SKILL.md` exists in the skill root directory
- [ ] `SKILL.md` is under 500 lines
- [ ] All referenced files exist at their specified paths
- [ ] File references use relative paths from skill root
- [ ] No deeply nested reference chains

### Content Quality
- [ ] Instructions are actionable, not just descriptive
- [ ] Examples are complete and runnable
- [ ] The skill is self-sufficient without loading reference files
- [ ] No redundant content — every line earns its place

## Programmatic Validation

Use the [skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref) library to validate:

```bash
skills-ref validate ./my-skill
```

If `skills-ref` is unavailable, use the Validation Checklist above as the offline alternative.

## Complete Example

A minimal, spec-valid skill:

```yaml
---
name: commit-format
description: >-
  Enforce conventional commit message format. Load this when creating
  commits, reviewing commit messages, or setting up commit hooks.
---

# Commit Format

Format all commit messages as: `type(scope): description`

## Types

| Type | When |
|------|------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | No behavior change |

## Rules

1. Subject line under 72 characters
2. Use imperative mood: "add" not "added"
3. No period at the end of the subject

## Anti-Patterns

| Anti-Pattern | Why It Fails |
|-------------|-------------|
| "fixed stuff" | No type prefix, vague description |
| "feat: Added the new user registration flow." | Past tense, period, too long |
```

## Anti-Patterns

| Anti-Pattern | Why It Fails |
|-------------|-------------|
| Description says "A skill for X" without explaining when to activate | Agents can't match tasks to the skill |
| SKILL.md over 500 lines with no reference files | Wastes context budget on rarely-needed detail |
| Name uses uppercase or underscores | Violates spec; validation will reject it |
| Name doesn't match directory | Spec requires exact match; breaks resolution |
| "See external URL for details" as the only content | Skills must be self-contained; network may not be available |
| Empty `scripts/` or `references/` directories | Don't create structure you don't use yet |
| Reference files that duplicate SKILL.md content | Wastes tokens when both are loaded |
| Vague description: "Helps with coding" | No activation signal; skill will never be matched |
| Giant monolith covering multiple unrelated tasks | Split into focused skills; one skill = one capability |
| ALL-CAPS MUSTs instead of explaining reasoning | LLMs respond better to motivated guidance than rigid rules |
| Instructions that only work for specific examples | Skills run across many prompts; generalize |

## Bundled Tools

This skill includes scripts and reference docs for advanced workflows:

| Tool | Purpose |
|------|---------|
| `scripts/quick_validate.py` | Validate skill frontmatter and structure |
| `scripts/generate_review.py` | Launch eval result viewer (qualitative + quantitative) |
| `scripts/aggregate_benchmark.py` | Aggregate grading results into benchmark stats |
| `scripts/run_loop.py` | Automated description optimization loop |
| `scripts/run_eval.py` | Run trigger eval queries against a skill |
| `scripts/improve_description.py` | Generate improved description candidates |
| `scripts/package_skill.py` | Package a skill directory into a `.skill` file |
| `scripts/generate_report.py` | Generate benchmark report |
| `references/eval-workflow.md` | Full eval workflow (spawn, grade, benchmark, review) |
| `references/description-optimization.md` | Description optimization process |
| `references/schemas.md` | JSON schemas for evals, grading, benchmarks |
| `references/grader.md` | Subagent instructions for grading assertions |
| `references/comparator.md` | Subagent instructions for blind A/B comparison |
| `references/analyzer.md` | Subagent instructions for benchmark analysis |
| `assets/eval_review.html` | HTML template for eval query review |
| `assets/viewer.html` | HTML template for eval result viewer |
| `assets/TEMPLATE.md` | Starter template for new skills |

## Quick Reference

```
1. Intent:    Understand what, when, and why before writing
2. Name:      lowercase, alphanumeric + hyphens, 1-64 chars, matches directory
3. Create:    mkdir skill-name && edit skill-name/SKILL.md
4. Format:    YAML frontmatter (name + description required) + Markdown body
5. Describe:  Explain what + when; be "pushy" about activation contexts
6. Size:      SKILL.md < 500 lines, < 5000 tokens
7. Split:     Heavy content → references/, scripts → scripts/, templates → assets/
8. Test:      Run 2-3 realistic prompts, evaluate, iterate
9. Optimize:  Run description optimization loop for triggering accuracy
10. Update:   Read first, preserve description intent, verify name match
11. Validate: scripts/quick_validate.py, or: skills-ref validate ./skill-name
```
