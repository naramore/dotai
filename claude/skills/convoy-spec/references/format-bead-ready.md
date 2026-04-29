# Bead-Ready Doc Format

The artifact consumed by the decomposition step. It carries everything
needed to mechanically + judgment-fully derive a convoy and its child
tasks — no further upstream context required.

The name "bead-ready" is the artifact's proper noun (kept across
backends). It signals "this doc is ready to be turned into trackable
work items, whatever your backend is."

## When this format is used

A bead-ready doc is the **terminal artifact of the planning pipeline**. By
the time it exists:

- Problem and goals are settled (PRD-equivalent content).
- Design has been reviewed and adversarially probed (no critical findings open).
- Risk and scope decisions are made — the doc carries the *outputs* of judgment, not the questions that produced them.
- The next step is mechanical: read this doc, create the convoy + tasks.

If any of those aren't true, you're working upstream of bead-ready (in the
PRD / design-review / adversarial pipeline). Don't stretch this format to
hold open questions — those go in the PRD or design doc.

## Required structure

```markdown
# Bead-Ready: <initiative slug>

## 1. Initiative Summary
A 3-5 sentence executive summary. What is being built, why, and who is the
primary beneficiary. Concrete enough that an outside reader knows the
problem space without loading other docs.

## 2. Provenance
- **review_id:** <slug used by upstream artifacts>
- **artifact paths:**
  - PRD: <path>
  - Design doc: <path>
  - Adversarial synthesis: <path>
- **upstream maturity level reached:** L0 | L1 | L2 | L3 | L4 | L5
- **adversarial review outcome:** clean | minor | major (no critical permitted)
- **target backend:** beads | linear | ... (chosen for this convoy)

## 3. Initiative Qualities
Top-level qualities that apply to the convoy as a whole. Per-task overrides
go in section 6. See `references/qualities-schema.md` for enums and
populating criteria.

| Quality | Value | Rationale |
|---------|-------|-----------|
| risk_tier | <critical \| high \| medium \| low> | <why this tier — cite criterion> |
| blast_radius | <local \| component \| system \| org> | <which systems / cohorts> |
| reversibility | <instant \| procedural \| costly \| irreversible> | <rollback strategy summary> |
| security_sensitivity | <none \| indirect \| direct \| critical> | <which subsystems touched> |
| cross_repo_coupling | <none \| coupled \| chain> | <which repos> |
| cognitive_demand | <routine \| standard \| frontier> | <complexity drivers> |
| domain_novelty | <routine \| familiar \| novel> | <prior pattern matches> |
| template_coverage | <full \| high \| partial \| novel> | <template id if applicable> |

## 4. Scope Boundaries
Allowed and forbidden paths apply to the **convoy as a whole**. Per-task
boundaries (typically tighter) go in section 6.

### In-scope
- repos: <repo>, <repo>
- paths: <glob>, <glob>
- targets / cohorts: <selector>

### Out-of-scope
- <thing 1>
- <thing 2>

### Forbidden paths (any task touching these is a hard error)
- repo: <repo>
  paths:
  - <glob>
- ...

### Invariants (must hold across every task)
- <invariant 1 — e.g., "no service restarts without explicit AC">
- <invariant 2>

## 5. Convoy Decomposition
A flat list of the work units that will become tasks. One row per
task. Order is not significant (dependencies are declared in section 6).

| Task slug | Title | Workflow type | Risk override | Cognitive override | Files / paths |
|-----------|-------|---------------|---------------|-------------------|---------------|
| <slug-1> | <imperative title> | <work:feature \| work:bugfix \| ...> | <critical..low or "—"> | <override or "—"> | <paths> |
| <slug-2> | ... | ... | ... | ... | ... |

If a row would have a `risk_tier` *higher* than the convoy-level value, that's
a decomposition smell — either the convoy-level rating is wrong or the task
should be moved to its own initiative.

## 6. Per-Task Specs
For each task in section 5, a sub-section in the form below. The body of each
sub-section is the **task spec** (see `references/format-task.md`) — full
content, not a stub.

### Task: <slug-1>
<full task spec body — Problem / Approach / Files / Acceptance Criteria /
Out of Scope / Test Plan, plus quality overrides if any>

### Task: <slug-2>
...

## 7. Dependency Graph
Declared as adjacency edges. Must be a DAG.

```
<slug-1> → <slug-3>      # slug-3 needs slug-1
<slug-2> → <slug-3>
<slug-3> → <slug-4>
```

Or as a table if more than ~6 tasks:

| Task | Depends on |
|------|-----------|
| <slug-1> | — |
| <slug-2> | — |
| <slug-3> | <slug-1>, <slug-2> |
| <slug-4> | <slug-3> |

## 8. Holdout Plan (skip if all tasks are `low` risk or holdouts disabled)
- **categories required:** negative_scope, rollback, idempotency, scope_enforcement
- **derivation_method:** systematic | augmented | creative | manual
- **independence:** independent | same_model | same_session
- **rationale per task:** <task-slug>: <which holdout categories apply and why>

## 9. Decomposition Self-Validation
Confirm before handoff to the decomposition step:

- [ ] Every design-doc implementation section maps to ≥1 task
- [ ] No two tasks have overlapping `scope_allowed_paths` (file contention)
- [ ] No task's AC contradicts another task's AC or the convoy invariants
- [ ] Dependency graph is acyclic
- [ ] No task has `risk_tier` higher than the convoy's
- [ ] Tasks touching identity / key material / signing paths are `critical`
- [ ] Tasks touching auth / access-control / security-control paths are `high` or higher
- [ ] Tasks touching boot / init / privilege-escalation paths are `high` or higher
- [ ] At least one AC per task tests the *intent*, not just the literal words
- [ ] Target backend is named in section 2

If any box is unchecked, this doc is not bead-ready. Fix the underlying
issue (split tasks, adjust scope, rewire dependencies) before handoff.
```

## Why this shape

- **Single source of truth.** The decomposition step reads only this doc — no
  need to chase the PRD or design doc again. Provenance pointers exist for
  audit and for re-runs (decomposition formulas may use them as skip-checks,
  looking for substantive content at known paths).
- **Qualities top-level + overridable.** Most tasks inherit convoy-level
  qualities; the table in section 5 + sub-sections in section 6 capture
  exceptions explicitly. Avoids the failure mode where every task copies
  the same risk tier and they drift over time.
- **Scope boundaries at two levels.** Convoy-level boundaries protect
  against scope leakage (a task's "out-of-scope" is meaningless if the
  convoy itself is unbounded). Task-level boundaries protect against
  parallel-execution contention.
- **Self-validation as part of the doc.** Section 9 is a checklist the
  author runs before handoff. The decomposition step rejects docs with
  unchecked boxes — keeps the failure-to-decompose loop tight.
- **Backend named explicitly.** Avoids the failure mode where the same
  initiative gets half-encoded in beads and half in Linear because no
  one decided up front.

## What does NOT go in a bead-ready doc

- **Open questions / unresolved options.** Those belong upstream (PRD,
  design doc). Bead-ready is a decision artifact, not a discussion.
- **Implementation prose.** Each task spec gets a Files + Approach
  section, not a code dump. Code is the implementer's job.
- **Adversarial review history.** Outcomes (clean/minor/major) go in
  section 2; the round-by-round logs stay in `.plan-reviews/$REVIEW_ID/`.
- **Non-judgment narrative.** No "we considered X but chose Y" — that's
  design-doc material. Bead-ready states the chosen path.
- **Backend-specific syntax.** No `bd update --set-metadata` snippets, no
  Linear field references. Backend encoding lives in the per-backend
  reference docs and is applied during decomposition, not at authoring time.

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Tasks without per-task qualities or boundaries | Convoy-level inheritance becomes opaque; reviewers can't tell what was set deliberately vs. left default |
| Forbidden paths only on the convoy, never on tasks | Two parallel tasks can still collide on allowed paths; per-task `scope_allowed_paths` is what prevents contention |
| Dependency graph as prose ("X must happen before Y") | Not machine-checkable; the decomposition step can't wire deps without parsing prose |
| Section 9 self-validation skipped or partial | Means decomposition errors land in the work graph, not in this doc — much more expensive to fix downstream |
| Holdout plan written for `low`-risk-only convoys | Wastes review cycles on holdouts that won't be run anyway; skip section 8 entirely |
| Backend left unspecified in section 2 | Half-encodes the convoy in two backends; pick before drafting |
