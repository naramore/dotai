---
name: convoy-spec
description: Use this skill when the user is working on a multi-item decomposition — a bead-ready doc, a convoy / parent issue / epic, or a task / sub-issue inside one. Drafting, decomposing a design doc into linked items, wiring dependencies, classifying quality metadata (risk_tier, blast_radius, reversibility, security_sensitivity, cognitive_demand, scope boundaries), or reviewing a decomposition before dispatch. Backend-neutral over beads, Linear, or any tracker with parent/child + dependency primitives. Typical intents: "decompose this PRD into tasks", "break this work into a convoy", "set up an epic with sub-issues", "wire up dependencies for these sub-issues", "is this decomposition ready to dispatch", "review this convoy before dispatch". Delegates per-task spec body to issue-spec; backend encoding to references/backend-{beads,linear}.md. Do NOT use for single-item work (use issue-spec) or upstream PRD / design / adversarial-review authoring.
---

# convoy-spec

Three artifacts, one workflow:

```
bead-ready doc                   (terminal artifact of the planning pipeline)
      │
      └──► [decomposition step]
                ├──► convoy      (parent — coordinates child tasks)
                ├──► task 1      (child — uses issue-spec format + convoy extensions)
                ├──► task 2
                └──► task N
```

This skill encodes the format and quality vocabulary for all three. It does
not decide what to build — it tells you how to write the artifacts that
make a convoy dispatchable.

**Backend-neutral.** Convoy + task are *conceptual roles*. Each is realized
in concrete primitives by a storage backend (beads, Linear, etc.). See
**Storage backends** below for the per-backend encoding references.

## Core principle: judgment vs. transport

Following [Zero Framework Cognition](https://steve-yegge.medium.com/zero-framework-cognition-a-way-to-build-resilient-ai-applications-56b090ed3e69):

- **Qualities are transport** — enumerated values with finite ranges, populated
  from gathered context. The schema defines what gets measured.
- **Populating qualities is cognition** — the model judges; the schema validates
  the output shape.
- **Decision matrices are policy** — deterministic rules that consume quality
  values to route decisions. They never produce values; they only consume them.

This skill teaches the schema and the criteria for judgment. **Never embed
the judgment logic itself.** A reviewer agent that spots a `risk_tier`
violation should cite the criterion and let the model re-judge — not run a
heuristic flowchart.

## When to load

Load when the user (or a calling formula) is doing any of:

- Authoring or editing a bead-ready doc (the artifact a planning pipeline emits)
- Drafting a convoy — its description, scope, invariants, or holdout policy
- Drafting a task that lives inside a convoy
- Decomposing a bead-ready doc into a convoy + tasks (mechanical step of item creation)
- Reviewing decomposition quality before dispatch
- Adjudicating quality-inheritance overrides (task vs. convoy)

Skip when:

- Authoring a single standalone item with no convoy context — use `issue-spec`.
- Writing the upstream PRD, design doc, or adversarial probes — those are
  *upstream* of bead-ready and don't use this skill.
- Implementing a task — implementation is the formula's job; this skill
  is for spec authoring.

## The three artifacts at a glance

| Artifact | Purpose | Format reference |
|---|---|---|
| **Bead-ready doc** | Terminal planning artifact. Carries everything the decomposition step needs. Single source of truth for what becomes the convoy + tasks. | [`references/format-bead-ready.md`](references/format-bead-ready.md) |
| **Convoy spec** | Parent item's description + structured metadata. Coordinates cross-task scope, invariants, dispatch order, holdout policy, merge atomicity. | [`references/format-convoy.md`](references/format-convoy.md) |
| **Task spec (in convoy)** | Per-task spec. Same body as `issue-spec` plus convoy-context section + extra metadata fields. | [`references/format-task.md`](references/format-task.md) |

The decomposition step that turns the first into the second + third is its
own discipline:

- [`references/decomposition-discipline.md`](references/decomposition-discipline.md)

## Storage backends

Convoy + task are conceptual roles. Each backend realizes them in its own
primitives. The format and quality schema are identical across backends;
the encoding (where labels go, how dependencies are wired, how the journal
is kept) differs.

| Backend | Convoy = | Task = | Dependency = | Reference |
|---|---|---|---|---|
| **beads** | `bead` (type: `convoy`) | `bead` (type: `task`) | `bd dep add` edge | [`references/backend-beads.md`](references/backend-beads.md) |
| **Linear** | parent issue | sub-issue | "blocked by" relation | [`references/backend-linear.md`](references/backend-linear.md) |

### Backend selection (default behavior)

When not told otherwise, detect from project context:

| Detected | Default backend |
|---|---|
| `.beads/` directory exists in the repo, no Linear MCP available | beads |
| Linear MCP available, no `.beads/` directory | Linear |
| Both | ask once, remember for the session |
| Neither | ask |

Override by saying so explicitly: "encode this convoy in Linear" /
"use beads for this one." A per-convoy backend mix is allowed but
discouraged — it complicates the audit trail.

## Quality vocabulary at a glance

Three groups, set on different artifacts. Full enums, sources, and consumers
are in [`references/qualities-schema.md`](references/qualities-schema.md).

| Group | Set on | Examples |
|---|---|---|
| **Spec qualities** | bead-ready doc + convoy + tasks | `risk_tier`, `blast_radius`, `reversibility`, `security_sensitivity`, `cross_repo_coupling`, `cognitive_demand`, `domain_novelty`, `template_coverage`, `spec_completeness`, `adversarial_severity` |
| **Holdout qualities** | convoy / per-task holdout artifacts | `derivation_method`, `category_coverage`, `testability`, `independence`, `seal_status` |
| **PR qualities** | implementation PR for each task | `change_type`, `change_risk` (mapped from `risk_tier`), `impact`, `author_type`, `evidence_completeness`, `spec_conformance`, `verification_status`, `coupling_status`, `review_confidence`, `holdout_result` |

Each quality has a finite enum, a defined source (mechanical / AI-judged /
human-attested), and named consumers (which gates read it). If you find
yourself wanting a quality value outside its enum, that's a schema gap —
extend the schema explicitly, don't smuggle a free-text value.

## Quality inheritance: convoy → task

Default-with-override. Most tasks inherit convoy values; per-task overrides
go in section 6 of the bead-ready doc and are recorded on the task's
metadata.

| Quality | Inherits | Override |
|---|---|---|
| `risk_tier` | yes | down only (`medium` → `low` OK; `medium` → `high` not OK) |
| `blast_radius` | yes | down only |
| `reversibility` | not inherited — set per-task | n/a (each task has its own rollback story) |
| `security_sensitivity` | yes | both directions |
| `cognitive_demand` | yes | both directions |
| `scope_allowed_paths` | tighten the convoy's | must be a subset |
| `scope_forbidden_paths` | extend the convoy's | inherit + add |
| `scope_invariants` | extend the convoy's | inherit + add |

A task wanting `risk_tier` *higher* than its convoy is a decomposition
smell — see [`references/decomposition-discipline.md`](references/decomposition-discipline.md).

## Workflow: authoring a bead-ready doc → convoy + tasks

1. **Confirm you're past the upstream gates.** PRD reviewed, design doc
   reviewed, adversarial probes returned no `critical` findings. If not,
   you're upstream of this skill — go finish those.
2. **Pick a backend** if not already implied by context (see Storage
   backends above).
3. **Draft the bead-ready doc** per [`references/format-bead-ready.md`](references/format-bead-ready.md).
   Tick every box in section 9 self-validation before handoff.
4. **Decompose** per [`references/decomposition-discipline.md`](references/decomposition-discipline.md):
   create the convoy, then each task in section 5 order, wire dependencies
   from section 7, run cross-bead self-validation.
5. **Populate qualities** per [`references/qualities-schema.md`](references/qualities-schema.md).
   Convoy first; tasks inherit and override. Halt on illegal overrides.
   Encoding details (where each value lives in the backend) are in the
   relevant `backend-*.md`.
6. **Holdout pipeline** (if `holdout_enabled`): derive criteria, seal,
   pin digest into specs. Then `spec_lifecycle = frozen`.
7. **Hand off to dispatch.** The convoy formula reads the manifest and
   dispatches children per `workflow_type` in dependency order, with
   model selection driven by `cognitive_demand`.

## Workflow: drafting a single task spec

For a task being authored or edited in isolation (e.g., a Spec Amendment
Request mid-execution; convoy already exists):

1. **Use `issue-spec`** alongside this skill for the per-item spec
   template, AC standards, and PLAN/DONE protocol.
2. Add the convoy-context sections per [`references/format-task.md`](references/format-task.md):
   parent convoy, position in graph, inherited invariants, inherited
   forbidden paths, cross-task AC references.
3. Set the convoy-specific metadata fields (`role`, `convoy_parent`,
   `workflow_type`, plus the inherited / overridden quality fields) per
   the relevant `backend-*.md`.
4. Confirm at least one AC tests the *intent*, not just the literal words —
   this is what makes holdout derivation possible.
5. Confirm `scope_allowed_paths` doesn't overlap with any sibling task that
   isn't graph-ordered against this one (run the file-contention check
   from [`references/decomposition-discipline.md`](references/decomposition-discipline.md)).

## Workflow: reviewing a decomposition before dispatch

For an existing convoy + tasks that need a quality check before the
formula dispatches them:

1. **Read the bead-ready doc** and verify section 9 self-validation is
   fully ticked. Halt if not.
2. **Read the convoy** and confirm metadata matches the qualities schema
   (no free-text values, all enums valid, no upward `risk_tier` overrides
   from any task).
3. **Run cross-bead self-validation** per [`references/decomposition-discipline.md`](references/decomposition-discipline.md):
   file contention, AC contradictions, risk-tier consistency against
   path-pattern triggers, convoy-level coverage, holdout coverage,
   backend uniformity.
4. **Surface specific findings** — name the exact convoy/task IDs and
   the criterion violated. Do not silently fix.
5. **Approve only if all halt-conditions are absent.** A single halt is a
   blocker; "minor concerns only" is approval-eligible if you note them.

## Anti-patterns at the skill level

| Anti-pattern | Why it fails |
|---|---|
| Embedding heuristic decision logic in this skill ("if X then high") | Violates ZFC — judgment stays with the model. Skill provides criteria, not flowcharts |
| Using this skill for standalone work outside a convoy | Use `issue-spec` instead; convoy-specific metadata is dead weight |
| Treating the bead-ready doc as a discussion artifact | It's a decision artifact. Open questions belong upstream (PRD / design) |
| Decomposing a bead-ready doc that hasn't passed self-validation (section 9) | Errors propagate into the work graph where they're expensive to fix |
| Reclassifying risk tier "for ergonomics" during decomposition | Defeats the gate that exists for a reason. If the gate is wrong, fix the gate |
| Adding new content during decomposition (filling design gaps) | Decomposition is mechanical-with-judgment, not authoring. Halt and send back upstream |
| Per-task `scope_allowed_paths` that overlap with siblings without a dependency edge | File contention during parallel execution; one task will lose silently |
| Convoy-level `risk_tier` lower than the highest child | Misleads gates into easier auto-approval than the children warrant |
| Splitting a single convoy across two backends to "ease handoff" | The audit trail fragments; pick one backend per convoy |

## Templates

Starter scaffolds in `assets/templates/`. Each pairs with a format
reference — populate by reading the matching `references/format-*.md`,
not by guessing from the template alone.

| Template | Pair with |
|---|---|
| [`assets/templates/bead-ready.md.tmpl`](assets/templates/bead-ready.md.tmpl) | [`references/format-bead-ready.md`](references/format-bead-ready.md) |
| [`assets/templates/convoy.md.tmpl`](assets/templates/convoy.md.tmpl) | [`references/format-convoy.md`](references/format-convoy.md) |
| [`assets/templates/task.md.tmpl`](assets/templates/task.md.tmpl) | [`references/format-task.md`](references/format-task.md) + `issue-spec` |

## Quick reference

```
1. Bead-ready doc = single source of truth for decomposition
2. Convoy = parent item, owns scope/invariants/atomicity for the set
3. Task = child item, issue-spec format + convoy-context section + extra metadata
4. Backend (beads / Linear / ...) decides the encoding, not the schema
5. Qualities are transport (enum schema)
6. Populating qualities is cognition (model judges)
7. Decision matrices are policy (deterministic rules consuming qualities)
8. Inheritance: convoy → task, default-with-override, never override risk up
9. Halt on decomposition errors; never silently fix
```
