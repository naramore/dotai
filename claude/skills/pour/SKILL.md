---
name: pour
description: >-
  How to execute a bd workflow formula. Covers the three execution-stage
  commands (`bd cook` for inspection, `bd mol pour` for persistent /
  audit-tracked work, `bd mol wisp` for ephemeral one-shots), the
  step-by-step execution loop once a mol exists (`bd mol current` →
  `bd ready` → do the work → `bd close`), and project-agnostic discipline
  rules that projects may override. Load when the user says "pour",
  "wisp", "cook", "run this formula", or "execute mol-X" — or when you
  are inside a mol working through its steps. Skip when the user is
  authoring or editing a formula's TOML schema; that's a different task.
---

# Pour — execute bd workflow formulas

## Core principle

bd has three execution-stage commands; pick the right one for the kind of work, then walk the resulting molecule one step at a time. Don't reimplement what bd already does. Don't skip steps. Don't claim done without doing.

## Decide: cook, pour, or wisp?

| You want to... | Command | Persistence |
|---|---|---|
| Inspect what a formula would create (no DB writes) | `bd cook <formula>` | none — JSON to stdout |
| Run audit-tracked work (multi-session, git-synced) | `bd mol pour <formula>` | persistent in `.beads/` |
| Run one-shot ops / diagnostics with no audit value | `bd mol wisp <formula>` | ephemeral, auto-cleans |

A formula author can hint via `phase = "vapor"` — pouring such a formula produces a warning recommending wisp. Use `--dry-run` on pour or wisp to preview without committing. Use `--var key=value` for variables.

If you're not sure which to use: ask "will I want to look back at this in git history a month from now?" Yes → pour. No → wisp. Just curious what it does → cook.

## Invoke

```bash
# Inspect — compile-time mode keeps {{vars}} as placeholders
bd cook mol-feature
bd cook mol-feature --var name=auth      # runtime mode: substitute vars
bd cook mol-feature --dry-run            # preview only

# Persistent — returns the mol-id; mol lives in .beads/
bd mol pour mol-feature --var name=auth
bd mol pour mol-feature --var name=auth --assignee me   # claim the root

# Ephemeral
bd mol wisp mol-release --var version=1.2.3
```

If `bd mol pour` fails citing a missing required var, supply it with `--var` and retry. If it fails citing a schema problem, the formula needs editing — that's an authoring task, not an execution one.

## Execute the molecule

Once you've poured or wisped, the mol exists in the database. Step descriptions live in the formula definition; bd tracks each step's status against the mol.

The loop:

```bash
# 1. See where you are.
bd mol current <mol-id>
# Status indicators in the output:
#   [done]    — closed
#   [current] — in_progress (you are here)
#   [ready]   — unblocked, claimable
#   [blocked] — waiting on dependencies
#   [pending] — not yet ready

# 2. Pick the next [ready] step (or filter directly).
bd ready --mol <mol-id>

# 3. Do the work the step describes.
#    Read the step's description from the formula. Do that work.

# 4. Close the step.
bd close <step-id> --reason "what you did"

# 5. Optional shortcuts.
bd close <step-id> --continue       # close + claim the next ready step
bd close <step-id> --suggest-next   # close + show newly-unblocked steps

# 6. Repeat until `bd mol current` shows all [done].
```

## Dispatching the work

Step 3 above ("do the work") has two sub-decisions: which agent does it, and whether to parallelize.

**Pick the agent type from step intent.**

| Step intent | Agent type |
|---|---|
| Research, codebase exploration, "find all uses of X" | `Explore` |
| Multi-step design, planning, sequencing decisions | `Plan` |
| Everything else | `general-purpose` or a specialized agent if one fits |

A formula author may override per step with an HTML-comment directive in the step body (e.g. `<!-- agent: Explore -->`). Honor the override when present.

**Parallelize ready bands when reasonable.** `bd ready --mol <id>` returns *all* currently-ready steps; `bd mol show <id> --parallel` highlights groups bd has identified as parallel. When multiple steps are independent, dispatch them concurrently via parallel `Agent` calls in a single message rather than sequentially.

Parallelize when:
- Steps are independent reads (different source systems, different files)
- Steps are independent probes (security scan + perf scan + style review)
- Wall-clock matters and the steps don't share mutable state

Don't parallelize when:
- Steps share state (concurrent edits to the same file, shared DB writes)
- One step's output is meaningfully informative for how to do the next, even if the DAG marks them parallel
- The token / coordination cost of N agents outweighs the wall-clock win

**Synthesize fan-out results before the dependent step runs.** Don't pass raw concatenated outputs forward — the next step needs a coherent input. Merge shape depends on what the parallel steps produced: structured merge by source for independent reads, severity-sorted dedupe for adversarial probes, vote count for consensus checks. Then close each parallel step and continue.

## Default execution discipline

These rules apply unless overridden (see next section). They're project-agnostic — strict enough to keep the audit trail honest, loose enough to fit any workflow.

- **One step at a time.** Read the current step's description. Do that work. Verify it matches the step's intent. Then close.
- **Verify completion before moving on.** A step that names exit criteria — "acceptance: failing tests committed", "**Done when:** PR is open" — only counts as done when those criteria hold. *The command exited 0* is not the same as *the outcome happened.*
- **Don't skip ahead.** If you complete step 4 while step 3 is still open, you've misread the dependency — `bd ready` would not have surfaced step 4. Re-check the DAG.
- **Don't claim done without doing.** `bd close` writes to the audit trail. If the work isn't actually done, the audit trail now lies, and downstream steps will run on assumptions that aren't true.
- **Resume from crash via the database.** On crash, restart, or handoff, `bd mol current <mol-id>` is ground truth. Match it against git state and any in-progress files to find your resume point. The mol IS the state — no separate session memory needed.

## Project-specific overrides

The defaults above suit project-agnostic execution. Many projects need stricter or differently-shaped rules. Before defaulting, check for and honor (in priority order):

1. **The formula's own `description` field** — may declare execution rules ("pause for human review after step 3", "run all `parallel-*` steps concurrently", etc.). Formula intent overrides the generic defaults.
2. **The mol's root issue body or labels** — may carry execution metadata set by the formula author or rigging step.
3. **A project-level execution contract** — typically in the project's `CLAUDE.md`, `AGENTS.md`, or a dedicated file like `EXECUTION.md` at the project root.
4. **Project-loaded skills that wrap pour** — a private overlay may add rules around state mutation, posting gates, journal conventions, body-hash checks, etc. Those project-specific skills are the right home for those concerns; this skill stays minimal.

When project rules conflict with the defaults, project rules win — the project knows its audit and safety needs better than this skill does. When *this skill's* defaults are sufficient (no overrides found), follow them.

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Reading the formula TOML and dispatching agents yourself instead of `bd mol pour` | bd parses, materializes, and tracks the mol; hand-rolling loses the audit trail and competes with the database |
| Cooking a formula to JSON and executing the JSON manually | Cook is for inspection. Pour for execution. The mol is the unit of state |
| Closing steps in any order other than what `bd ready` surfaces | The DAG exists for a reason; out-of-order closes signal a missed dependency |
| Closing a step before doing the work | The audit trail lies; downstream steps may run on assumptions that aren't true |
| Pouring a formula declared `phase = "vapor"` | You'll get a warning and accumulate audit-trail clutter for work that didn't need persistence |
| Using `bd mol wisp` for work you'll need to reference later | Wisps auto-clean; the audit trail you wanted is gone |
| Inventing custom preview/gate vocabulary instead of using `--dry-run` | bd's flags already cover preview; custom gates fragment the operator experience |
| Asking the user "should I close this step?" instead of verifying the work and closing | Confirmation prompts erode under fatigue. Verify the exit criteria, then close — or surface the unmet criterion if you can't verify |

## Quick reference

```
1. Decide:    cook (inspect) | pour (persistent) | wisp (ephemeral)
2. Invoke:    bd cook|mol pour|mol wisp <formula> --var k=v [--dry-run]
3. Loop:      bd mol current <id>  →  pick [ready] step  →  do work  →  bd close <id>
4. Discipline: one at a time, verify, no skipping, no claiming-without-doing
5. Resume:    bd mol current is ground truth on restart
6. Override:  formula description, then project CLAUDE.md/AGENTS.md, then overlay skills win over defaults
```
