# Decomposition Discipline

How to derive a convoy + tasks from a bead-ready doc without
introducing the failure modes that show up downstream as scope creep,
file contention, or quality-inheritance drift.

This file describes the discipline **abstractly**. The mechanical steps
(API calls, CLI commands, field updates) are in the relevant
`backend-*.md` reference.

## The decomposition contract

The bead-ready doc is the *upper bound* on what gets created. Decomposition
is a **mechanical step with structured judgment** — it does not invent new
work, expand scope, or reclassify risk silently. If the bead-ready doc is
incomplete, the answer is to fix the doc upstream, not to fill gaps at
decomposition time.

## Order of operations

1. **Parse the bead-ready doc.** Validate sections 1-9 are present and
   section 9's self-validation checklist is fully ticked. If not, halt
   with a structured error pointing at the unchecked items. Read the
   `target backend` from section 2; if absent, halt and ask.
2. **Create the convoy.** Use the format in `format-convoy.md` and the
   encoding in the relevant `backend-*.md`. Populate metadata from
   section 3 (initiative qualities) of the bead-ready doc.
3. **Create tasks in the order they appear in section 5.** Use the
   format in `format-task.md` and the relevant `backend-*.md` encoding.
   For each task, populate metadata from the row in section 5 plus any
   per-task overrides in section 6.
4. **Wire dependencies.** From section 7's adjacency edges. Each backend
   has a native dependency primitive (beads: `bd dep add`; Linear:
   "blocked by" relation). Reject if not a DAG (already self-validated,
   but defense in depth).
5. **Self-validate the work graph.** Run the cross-item checks below; any
   failure halts and reports.
6. **Optionally write per-item spec YAML.** For tasks with `risk_tier ≥
   medium` (i.e., not `low`), emit a structured spec artifact (e.g.,
   DSF-Spec-style YAML) to a known path.
7. **Record the manifest.** Write a manifest of created item IDs back to
   the bead-ready doc's review directory for audit.

## Quality propagation rules

When populating task metadata, apply convoy → task inheritance per
`format-task.md`'s inheritance table. Specifically:

- **`risk_tier`:** task = convoy unless the task row in section 5 has a
  *lower* override. Reject upward overrides; surface as decomposition smell.
- **`scope_allowed_paths`:** task allow list must be a **subset** of the
  convoy's. If the bead-ready doc lists paths in section 6 not present in
  the convoy's section 4 allow list, halt — the bead-ready doc is internally
  inconsistent.
- **`scope_forbidden_paths`:** task list = convoy list + task-specific
  additions (union, never subtraction).
- **`scope_invariants`:** same — union, never subtraction.

## Self-validation: cross-item checks

These run after all items are created but before the convoy is marked
`approved`. Failures halt, do not silently fix.

### File contention

For every pair of sibling tasks `(A, B)`:

- `A.scope_allowed_paths ∩ B.scope_allowed_paths` must be empty *unless*
  the dependency graph orders them (i.e., `A → B` or `B → A`).

If contention is found, the fix is one of:

- Tighten the allow lists so they're disjoint.
- Add a dependency edge so they don't run in parallel.
- Merge the tasks into one (file-level coordination is small enough that
  splitting was premature).

### AC contradictions

For every pair of tasks `(A, B)`:

- No AC of `A` may contradict an AC of `B` or a convoy invariant.
- No task AC may contradict a convoy invariant — even non-pairwise.

This is an AI-judged check (not mechanical). Pass the AC sets to a probe
and ask: "are any of these mutually unsatisfiable?"

### Risk tier consistency

Path-pattern triggers establish floor values for `risk_tier` and
`security_sensitivity`. The categories below are universal; concrete path
globs are project-specific (overlay docs supply the path lists).

- Tasks touching **identity / key material / signing infrastructure** →
  `risk_tier: critical`, `security_sensitivity: critical`.
- Tasks touching **auth, access control, audit logging, security controls**
  (firewall, access policy, identity providers) → `risk_tier: high` or
  higher; `security_sensitivity: direct` or higher.
- Tasks touching **boot chain, init, privilege-escalation, kernel /
  privileged runtime** → `risk_tier: high` or higher (`critical` if also
  identity-adjacent).

These are hard gates, not heuristics — if a task's path globs match these
categories and `risk_tier` is lower, halt and surface the conflict. The
project's path-glob lists for each category live in an overlay reference
doc (typically `<overlay>/docs/convoy-spec-vocabulary-mapping.md`).

### Convoy-level coverage

- Every implementation section in the upstream design doc must map to ≥1
  task. (The bead-ready doc's section 9 already attests to this; this
  check verifies the manifest reflects it.)
- No orphan tasks (tasks not reachable in the dependency graph from any
  root or sink) unless explicitly justified in section 6.

### Holdout coverage

If `holdout_enabled = true`:

- Categories specified in section 8 must include `negative_scope` for any
  convoy with `scope_forbidden_paths`.
- Categories must include `rollback` for any convoy with `reversibility`
  ∈ {`procedural`, `costly`, `irreversible`}.
- If `risk_tier` ∈ {`critical`, `high`}, `independence` must be `independent`.

### Backend uniformity

- Every task's metadata must record the same `backend` value as its convoy.
- If section 2 of the bead-ready doc names a backend that lacks a primitive
  the convoy needs (e.g., a backend with no native dependency relation), halt
  and surface the mismatch — don't silently substitute.

## Anti-patterns at decomposition time

| Anti-pattern | Symptom | Fix |
|---|---|---|
| **Filling gaps in the bead-ready doc during decomposition** | Task specs invent constraints not in the upstream design doc | Halt; send back to design phase |
| **Splitting one logical change into many tiny tasks for "parallelism"** | Lots of inter-task dependencies; complex contention checks | Merge tightly-coupled tasks; the convoy is for *coordination*, not for max parallelism |
| **One mega-task that should be 3-4** | Single task touches >10 files, or has >8 ACs | Split along natural boundaries (subsystem, lifecycle phase, file group) |
| **Reclassifying risk tier "for ergonomics"** | A `high` task gets recorded as `medium` so it can auto-approve | Halt; the gate exists for a reason. If the gate is wrong, fix the gate, not the metadata |
| **Convoy with merge_atomicity = all_or_none and no cross-task hooks** | Children individually mergeable but the convoy never merges | Either drop atomicity or add the explicit hooks |
| **Tasks with `cognitive_demand = frontier` in a convoy where the convoy is `routine`** | Frontier model dispatched for one task while the convoy review uses fast model | Bump the convoy's demand to match the most-demanding task, or split |
| **Backend chosen mid-decomposition** | Some tasks created in beads, some in Linear; manifest fragmented | Restart decomposition with backend named up front in section 2 |

## When decomposition reveals upstream issues

If during decomposition you notice the bead-ready doc is internally
inconsistent (e.g., a task in section 5 references paths excluded by
section 4's forbidden paths), the fix is **not** to silently reconcile it.
Halt, surface the conflict, and send the doc back upstream. Decomposition
is mechanical execution of judgment that's already been made; if the
judgment is wrong, the answer is upstream re-judgment, not downstream
patching.

## Convoy lifecycle hand-off

After self-validation passes:

1. Set convoy `spec_lifecycle = approved`.
2. Run the holdout pipeline (if `holdout_enabled`); on success, set
   `spec_lifecycle = frozen`.
3. Hand off to dispatch — the formulas execute children per
   `workflow_type`, in dependency-graph order, with model selection
   driven by `cognitive_demand`.

After freeze, any change to a child task's spec requires a Spec Amendment
Request against the convoy. The convoy is the unit of frozen contract.

How `spec_lifecycle` values map to backend-native states is backend-specific
— see the lifecycle table in the relevant `backend-*.md`.
