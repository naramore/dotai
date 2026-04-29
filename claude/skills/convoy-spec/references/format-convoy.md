# Convoy Spec Format

A convoy is the **parent** of a coordinated set of tasks. Its spec is the
body of the parent item's description plus structured metadata. The convoy
spec exists to coordinate cross-task concerns: shared scope, invariants,
dispatch order, holdout policy, merge atomicity.

This file describes the format **abstractly**. Concrete encoding (where
metadata lives, how it's set, what the journal looks like) is in the
relevant `backend-*.md` reference.

## When a convoy is required

| Signal | Need a convoy? |
|---|---|
| Single item, ≤5 files, no cross-repo coordination | No — use a standalone work item per `issue-spec` |
| Multiple tasks that must merge as a unit (atomic across repos) | **Yes** |
| Multiple tasks with shared scope boundaries / invariants | **Yes** |
| Multiple tasks with shared holdout policy | **Yes** |
| Independent tasks that happen to be in the same project | No — separate items, no convoy |

If you find yourself creating a convoy with a single child task, collapse it
to a standalone work item.

## Description body

The convoy's description field uses this structure. Quality metadata goes
in the backend's structured-metadata mechanism (bead metadata bag, Linear
labels + custom fields + description fence, etc.) — see the relevant
`backend-*.md`.

```markdown
# <Initiative Title>

## Purpose
2-3 sentences. What this convoy delivers as a unit and why it had to be
coordinated rather than split.

## Child Task Manifest
| Task ID | Title | Workflow type | Status |
|---------|-------|---------------|--------|
| <id> | <title> | <work:feature \| work:bugfix \| ...> | open |
| <id> | <title> | ... | open |

(Updated as children move through their lifecycle. The convoy formula
maintains this; manual edits are an audit smell.)

## Dependency Graph
```
<id-1> → <id-3>
<id-2> → <id-3>
<id-3> → <id-4>
```

## Convoy-Level Scope
### In-scope (across all tasks)
- repos: <repo>, <repo>
- paths: <glob>, <glob>

### Out-of-scope (across all tasks)
- <thing>

### Forbidden paths (any child touching these is a hard error)
- repo: <repo>
  paths:
  - <glob>

### Invariants (must hold after every task merges)
- <invariant>
- <invariant>

## Cross-Task Concerns
What's true *because* these tasks are bundled together — not visible at
the per-task level. Examples:

- "Task `<id-2>` must not run before `<id-1>` because `<id-2>` reads a config
  written by `<id-1>`."
- "Tasks `<id-3>` and `<id-4>` write to overlapping test files but
  to disjoint test groups within them — must not run in parallel."
- "All tasks share the rollback hook at `<path>`."

## Holdout Policy
- **enabled:** true | false
- **scope:** convoy-wide | per-task
- **categories:** negative_scope, rollback, idempotency, scope_enforcement
- **sealed-artifact ref:** <URL or path or "n/a">

## Merge Policy
- **atomicity:** all-or-none | sequential | independent
- **rebase strategy:** <e.g., "rebase children onto convoy base before each merge attempt">
- **automerge eligibility:** <criteria — usually a reference to the merge decision matrix>

## Provenance
- **bead-ready doc:** <path>
- **review_id:** <slug>
- **adversarial review outcome:** clean | minor | major
- **adversarial rounds:** <n>
- **target backend:** beads | linear | ...
```

## Metadata fields (set on the convoy via the backend's metadata mechanism)

These mirror the section-3 qualities from `qualities-schema.md` but apply to
the convoy as a whole. Per-task overrides live on the task items.

| Key | Type | Source | Notes |
|---|---|---|---|
| `role` | enum: `convoy` | mechanical | Identifies this item as a convoy parent |
| `risk_tier` | enum: `critical/high/medium/low` | AI | Convoy-level. Tasks may override *down*; never up |
| `blast_radius` | enum: `local/component/system/org` | AI | Aggregate across tasks |
| `reversibility` | enum: `instant/procedural/costly/irreversible` | AI | Worst case across tasks |
| `security_sensitivity` | enum: `none/indirect/direct/critical` | AI | Worst case |
| `cross_repo_coupling` | enum: `none/coupled/chain` | AI | If `coupled` or `chain`, convoy is required |
| `cognitive_demand` | enum: `routine/standard/frontier` | AI | Convoy-level baseline; tasks may override either way |
| `domain_novelty` | enum: `routine/familiar/novel` | mechanical | From history of similar past items |
| `template_coverage` | enum: `full/high/partial/novel` | mechanical | If a convoy template was used |
| `scope_allowed_paths` | comma-sep globs | bead-ready doc | Convoy-level allow list |
| `scope_forbidden_paths` | comma-sep globs | bead-ready doc | Convoy-level deny list |
| `scope_invariants` | semicolon-sep prose | bead-ready doc | Behavioral invariants |
| `adversarial_status` | enum: `passed/failed/escalated` | from synthesis | Recorded at convoy creation |
| `adversarial_severity` | enum: `clean/minor/major/critical` | from synthesis | Worst across probes |
| `adversarial_rounds` | integer | from synthesis | Rounds to converge |
| `holdout_status` | enum: `derived/sealed/skipped/n_a` | mechanical | Lifecycle of holdout artifact |
| `holdout_digest` | sha256 hex | mechanical | Hash of sealed payload |
| `holdout_categories` | comma-sep | from holdout plan | Which categories apply |
| `spec_lifecycle` | enum: `draft/in_review/approved/frozen/executing/verifying/merged/failed` | state machine | Convoy lifecycle (may map to backend-native states) |
| `spec_frozen_at` | ISO-8601 | mechanical | Timestamp of freeze |
| `merge_atomicity` | enum: `all_or_none/sequential/independent` | from convoy spec | Drives merge policy |
| `bead_ready_doc` | path | mechanical | For audit / re-runs |
| `review_id` | slug | mechanical | Links upstream artifacts |
| `backend` | enum: `beads/linear/...` | mechanical | Which backend this convoy lives in |

How each key is encoded depends on the backend:

- **beads** uses an arbitrary metadata bag — keys map directly. See [`backend-beads.md`](backend-beads.md).
- **Linear** uses labels (for things downstream tools must filter on), custom fields (where configured), and a `<!-- meta:start -->...<!-- meta:end -->` description fence (for everything else). See [`backend-linear.md`](backend-linear.md).

## Why convoy-level scope + invariants

Per-task scope alone can't catch cross-task contention or shared-invariant
breakage. Two tasks each "in scope" for `services/auth/**` can collide on
the same file. The convoy is the only place where "no two tasks may write
the same file" is enforceable. Same for invariants like "no service restart"
that span the whole change set.

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Convoy with one child task | Coordination overhead with no benefit; just use a standalone work item |
| Quality metadata on the description body, not in the backend's metadata mechanism | Not machine-readable; gates and matrices can't consume it |
| Convoy-level `risk_tier` lower than the highest child | Misleads gates into easier auto-approval than the children warrant |
| Empty / TBD `scope_forbidden_paths` on a convoy with multiple repos | Children can step on each other's toes; the convoy spec is the place to lock this down |
| Manually-edited child manifest | Drifts from actual work graph; fix the convoy formula or the dispatch tooling instead |
| `merge_atomicity: all_or_none` without explicit cross-task hooks | Will deadlock when one child is ready and another is blocked |
| Different tasks of one convoy in different backends | Audit trail fragments; pick one backend per convoy |
