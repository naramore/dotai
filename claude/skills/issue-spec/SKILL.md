---
name: issue-spec
description: Use this skill when the user is working on the text of a single issue, ticket, bug report, feature request, task, or work item — writing one, drafting one, creating one in a tracker (beads, Linear, GitHub Issues, Jira), reviewing one someone else wrote, auditing whether it's specified well enough for an agent or human to implement, or rewriting a vague request into a concrete spec. Also use it for drafting PLAN or DONE comments on an existing issue. Typical intents: "write a bug report for X", "draft an issue / ticket for Y", "create a beads/Linear issue", "spec out this feature", "is this ticket detailed enough", "review this Linear ticket", "help me write a PLAN comment", "turn this into a proper issue". Covers titles, acceptance criteria, files-to-modify, out-of-scope, test plan, and the PLAN/DONE journal protocol. Do NOT use for multi-item decomposition, parent+child task convoys, or cross-repo breakdowns — that belongs to convoy-spec. This is the per-item layer.
---

# Issue Specification Format

How to write one good issue spec. Backend-neutral — the rules below apply
whether the issue lives in beads, Linear, GitHub Issues, Jira, or any
other tracker. Backend-specific encoding (CLI commands, API calls, where
metadata lives) is in `convoy-spec`'s backend reference docs (see
**Storage backends** below).

The spec is the contract — when implementation and spec disagree, the
implementation is wrong.

## How Much Spec Do You Need?

| Scope | Signal | Description Depth |
|-------|--------|-------------------|
| **Trivial** | <10 lines, 1-2 files | Skip the issue entirely — just do it |
| **Small** | Single task, <1 session | 2-3 sentence description + acceptance criteria |
| **Medium** | 3-5 files, multi-step | Full spec template (below) |
| **Large** | 6+ files, cross-cutting | Full spec template; decompose into a convoy + child tasks via the **convoy-spec** skill |

## Title and Type Conventions

**Title rules** (apply to every backend):

- Imperative mood: "Add dark mode toggle" not "Adding dark mode" or "Dark mode added"
- Prefix discovery issues: "Found: edge case in parser"
- Prefix security findings: "SEC: unvalidated input in auth handler"

**Conventional type vocabulary** (most trackers support these or close equivalents):

`bug` | `feature` | `task` | `epic` | `chore`

**Priority** is backend-specific in label/scale but universal in intent:

| Intent | Beads CLI | Linear | GitHub label |
|---|---|---|---|
| Critical / drop everything | `P0` | Urgent | `priority:critical` |
| High / next up | `P1` | High | `priority:high` |
| Medium / default | `P2` | Medium | `priority:medium` |
| Low / when convenient | `P3` | Low | `priority:low` |
| Backlog / unscheduled | `P4` | No priority | `priority:backlog` |

> **Priority scale collision.** Named org-level priority frameworks
> often use `P0`–`P3` with criteria that don't match bead-tool
> semantics. The letter codes overlap; the meanings don't. Check which
> framework you're aligning to before assuming equivalence.

## The Issue as Spec Container

One issue holds the entire lifecycle of one unit of work. Field names
vary by backend; the conceptual roles are identical:

| Conceptual field | Holds | Beads field | Linear field |
|---|---|---|---|
| **Description body** | The spec (Problem, Approach, Files, AC, Out of Scope, Test Plan) | `description` | `description` |
| **Journal** | PLAN before implementation, DONE after, QA verification | `notes` (via `bd update --notes`) | comments |
| **Structured metadata** | Risk, scope, ownership, ad-hoc fields | `metadata` map (key/value bag) | labels + custom fields + description fence |
| **Lifecycle state** | open → in_progress → closed (or backend-equivalent) | `status` | team workflow state |

For backend-specific encoding of each, see **Storage backends** below.

## Spec Template (Medium/Large Scope)

```markdown
### [Title]

**Type:** task | feature | bug | epic | chore
**Priority:** see priority table above
**Estimated effort:** small | small-medium | medium | large
**Dependencies:** none | list of issue IDs
**Status:** Draft | Active | Deferred

#### Problem
2-3 sentences: what's broken/missing and why it matters.

#### Approach
How this will be solved. Strategy, not implementation details.
Tradeoff decisions belong here (e.g., "localStorage over URL params because...").

#### Files to Create/Modify
| File | Action |
|------|--------|
| `path/to/file.md` | CREATE / MODIFY / DELETE / COPY |

If the agent modifies files outside this list, that's a red flag.

#### Content Source / Spec
Detailed requirements: patterns to follow, draft content, API contracts.
Reference existing docs when possible (file + line range).

#### Acceptance Criteria
- [ ] First verifiable checkpoint (binary pass/fail)
- [ ] Second checkpoint
- [ ] ...

#### Out of Scope
What this issue explicitly does NOT cover.
Prevents scope creep and agent gold-plating.

#### Test Plan
1. **Syntax:** Validation command → expected result
2. **Functional:** Manual verification steps
3. **Integration:** How to verify it works with related components
```

## Acceptance Criteria Standards

Every criterion must be:

1. **Binary** — pass/fail, no ambiguity ("returns 200" not "should work")
2. **Verifiable** — checkable by running a command or inspecting output
3. **Independent** — each testable on its own
4. **Scope-appropriate** — small issues need fewer criteria than large ones

**Category checklist** (include all that apply):

| Category | Example |
|----------|---------|
| **Existence** | File exists at `shared/skills/issue-spec.md` |
| **Content** | Covers branch naming, commit format, push strategy |
| **Size** | File is < 100 lines |
| **No duplication** | No overlap with `git-co-author.md` |
| **Syntax** | `python3 -m json.tool file.json > /dev/null` passes |
| **Integration** | References `git-workflow` skill, doesn't duplicate it |
| **Behavior** | Switch to workspace A → filters restore to status=open |

## PLAN/DONE Comment Protocol

Both PLAN and DONE land in the issue's journal surface (beads `notes` /
Linear comments / GitHub issue comments). Append-only — never edit a
prior entry.

**PLAN** (post before writing any code — a checkpoint, not bureaucracy):
```
PLAN:
1. Add helper functions to lib/storage.ts:
   - getFilters(path: string): FilterState | null
   - setFilters(path: string, filters: FilterState): void
2. Update components/filter-bar.tsx: read on mount, write on change
3. Thread databasePath from workspace context
Files: lib/storage.ts, components/filter-bar.tsx, hooks/use-workspace.ts
Test: Unit tests for helpers, manual test of acceptance criteria 1-5
```

Review the plan in ~2 minutes. Correct it if wrong. This catches problems
that would take 20 minutes to fix after implementation.

**DONE** (post after completion — map each acceptance criterion to evidence):
```
DONE: Filter bar persists across workspace switches via localStorage.

Changes:
- lib/storage.ts: Added getFilters/setFilters with key "app:filters:{path}"
- components/filter-bar.tsx: Reads stored filters on mount, writes on change

Acceptance criteria verification:
- [x] Filters persist across switches (manual: steps 2-5 confirmed)
- [x] Filters survive browser restart (manual: step 6 confirmed)
- [x] Filtered view matches tracker output (queried tracker, 14 items match)
- [x] Filters don't bleed between workspaces (workspace B shows defaults)

Unit tests: 3 added, all passing.
Branch: user/feat-filter-persist
Commit: a1b2c3d
```

## When the Issue is Part of a Convoy

When an issue is part of a convoy (parent + child task items dispatched
together), additional quality metadata (`risk_tier`, `blast_radius`,
`cognitive_demand`, `scope_allowed_paths`, etc.) and decomposition rules
apply. Load the **convoy-spec** skill for the convoy-level format, the
qualities schema, and the decomposition discipline. This skill stays
focused on the per-item spec — convoy-spec extends it.

A standalone issue (no convoy parent) uses this skill alone; the extra
metadata is unnecessary.

## Storage backends

This skill describes the spec **shape**. Where each piece actually
lives (CLI command, API call, label namespace, description fence) is
backend-specific. The same backend reference docs that drive
`convoy-spec` apply here:

| Backend | When | Encoding reference |
|---|---|---|
| **beads** | Local-first work, no remote handoff needed | `convoy-spec/references/backend-beads.md` |
| **Linear** | Work that needs to be visible to remote agents / collaborators / stakeholders | `convoy-spec/references/backend-linear.md` |

For a standalone (non-convoy) issue, only the per-item creation +
metadata + comment-journal sections of those docs apply — ignore the
convoy/parent-child machinery.

If the project has no `.beads/` directory and no Linear MCP available,
ask the user which backend to use before authoring.

## Anti-Patterns

- Vague titles: "Fix auth" (which auth? what's broken?)
- Missing acceptance criteria on medium/large issues
- Non-binary criteria: "should work well"
- DONE without verification evidence: "Fixed the filter bar"
- Skipping the PLAN comment (silent assumptions become wrong implementations)
- Out-of-Scope section left empty on medium/large issues — it's the only thing keeping agents from gold-plating
- Files-to-Modify list omitted, then the agent edits half the codebase "while it was there"
- Acceptance criteria that test the implementation rather than the behavior ("uses localStorage" instead of "filters survive page refresh")
- Editing a prior PLAN or DONE entry instead of appending a new one — breaks the journal's append-only contract
- Reusing this skill's per-item template for multi-item / cross-repo work — that's `convoy-spec` territory
- Authoring a spec without choosing a backend first, then half-encoding it across two trackers

## Quick Reference

```
1. Title:    Imperative mood ("Add X", not "Adding X" or "X added")
2. Scope:    Trivial → skip; Small → short desc + AC; Medium/Large → full template
3. Template: Problem / Approach / Files / Content / AC / Out-of-Scope / Test Plan
4. AC:       Binary, verifiable, independent, scope-appropriate
5. PLAN:     Post before code — catches bad assumptions cheaply
6. DONE:     Map every AC to evidence; cite branch + commit
7. Backend:  Pick beads or Linear up front; encoding lives in convoy-spec/references/backend-*.md
8. In-convoy: Also load convoy-spec for parent-child coordination + quality metadata
```
