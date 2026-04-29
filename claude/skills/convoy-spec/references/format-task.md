# Task Spec Format (within a convoy)

A task within a convoy uses the **same per-item spec format as
`issue-spec`** for the description body, plus convoy-specific metadata
fields and a small set of additions to the spec sections.

This file documents only the *additions*. For the base spec template,
acceptance-criteria standards, PLAN/DONE protocol, and anti-patterns, see
the `issue-spec` skill. For backend-specific encoding (where each
metadata field actually lives), see the relevant `backend-*.md`.

## What's the same as `issue-spec`

- Title rules, type vocabulary (`task`, `bug`, `feature`, etc.)
- Spec template (Problem / Approach / Files / AC / Out of Scope / Test Plan)
- Acceptance criteria standards (binary, verifiable, independent, scope-appropriate)
- PLAN comment before implementation, DONE comment after
- Anti-patterns

If you're authoring a work item that does **not** live in a convoy, stop here
and use `issue-spec` directly. The rest of this file is convoy-specific.

## What's added when the task is in a convoy

### 1. Two extra description sections

Append these after the standard sections:

```markdown
#### Convoy Context
- **Parent convoy:** <id> — <convoy title>
- **Position in graph:** depends on <id-1>, <id-2>; blocks <id-3>
- **Inherited convoy invariants** (must hold after this task merges):
  - <invariant 1 — copied from convoy spec, do not edit>
  - <invariant 2>
- **Inherited convoy forbidden paths:**
  - <glob 1>
  - <glob 2>

#### Cross-Task AC References
For ACs that depend on or extend another task's contract:

- "AC-3 depends on AC-7 of <id-1> (config key written by sibling task)"
- "Out-of-scope: any change to the rollback hook owned by <id-4>"
```

The convoy context section is **read-only on the task** — it's a copy of
the convoy-level constraints for offline reference. Edits go to the convoy
spec; the convoy formula re-syncs children.

### 2. Required metadata extensions

On top of any metadata `issue-spec` describes, every task in a convoy
carries the keys below. The mechanism for setting them is backend-specific
(see `backend-*.md`).

| Key | Type | Source | Notes |
|---|---|---|---|
| `role` | enum: `task` | mechanical | Identifies this item as a convoy child |
| `convoy_parent` | item ID | mechanical | The convoy this task belongs to |
| `workflow_type` | enum (see below) | AI | Categorizes the work; dispatcher maps to formula |
| `risk_tier` | enum: `critical/high/medium/low` | AI | May override convoy *downward*, never upward |
| `blast_radius` | enum: `local/component/system/org` | AI | Often inherited from convoy |
| `reversibility` | enum: `instant/procedural/costly/irreversible` | AI | Per-task — a single rollback step within the convoy |
| `security_sensitivity` | enum: `none/indirect/direct/critical` | AI | Per-task |
| `cognitive_demand` | enum: `routine/standard/frontier` | AI | Drives implementer + reviewer model selection |
| `scope_allowed_paths` | comma-sep globs | bead-ready doc | **Tighter than convoy.** Disjoint from sibling tasks |
| `scope_forbidden_paths` | comma-sep globs | bead-ready doc | Inherits convoy forbidden + adds task-specific |
| `scope_invariants` | semicolon-sep | bead-ready doc | Per-task invariants beyond convoy invariants |
| `template_coverage` | enum: `full/high/partial/novel` | mechanical | Per-task template match |
| `spec_completeness` | enum: `complete/partial/insufficient` | mechanical | Schema validation result |

### 3. `workflow_type` vocabulary

Each task names the **category** of work. The dispatcher maps category
to a concrete formula (e.g., dotai's library uses `mol-<category>.toml`,
but that mapping is a dispatcher detail — the spec carries the category,
not the formula filename).

Pick by *nature of the work*, not by *what looks closest*.

| Work nature | `workflow_type` | When |
|---|---|---|
| New capability | `work:feature` | Net-new behavior, new API, new subsystem |
| Bug fix | `work:bugfix` | Correcting defective existing behavior |
| Refactor | `work:refactor` | Restructuring without changing behavior |
| Research / spike | `work:spike` | Feasibility exploration; produces decision, not code |
| CI/CD / tooling | `work:infrastructure` | Build system, deploy config, CI pipelines |
| Dependency update | `work:dependency` | Upgrade, pin, or remove dependencies |
| Test coverage | `work:test-authoring` | Add or improve tests (not feature tests bundled with features) |
| Cleanup | `work:cleanup` | Dead code, lint fixes, formatting |
| Migration | `work:migration` | Move between systems, APIs, or versions |
| Performance | `work:performance` | Optimization with benchmark targets |
| Documentation | `work:documentation` | Docs, runbooks, READMEs |
| Emergency fix | `work:hotfix` | Production incident; skips normal flow |
| Config change | `work:configuration` | Config values, flags, thresholds, templates |
| Security | `work:security` | Vulnerability remediation, hardening |

Domain-specific overlays (e.g., infrastructure-specific feature flow) are
resolved at dispatch time based on overlay config — always assign the
generic `work:*` category here.

### 4. Acceptance-criteria addition: intent vs. literal

In a convoy, every task should have **at least one AC that tests the
*intent* behind the contract, not just the literal words**. This is what
makes holdout derivation possible — the holdout asks the same intent
question with a different verification.

```markdown
#### Acceptance Criteria
- [ ] Literal: config file at <path> contains <expected setting>
- [ ] Intent: target hosts achieve the desired outcome (clock sync within
      60s of boot; auth check returns within SLA; etc.) using a means
      reachable from the production environment (will continue to pass if
      the underlying source URL changes due to a downstream constraint)
```

The literal AC catches regressions in implementation; the intent AC
catches regressions in *what we were actually trying to achieve*.

## Quality inheritance rules

Convoy → Task inheritance is **default-with-override**:

| Quality | Inheritance | Override direction allowed |
|---|---|---|
| `risk_tier` | Default from convoy | Down only (`medium` convoy → `low` task OK; `medium` → `high` *not* OK) |
| `blast_radius` | Default from convoy | Down only |
| `reversibility` | Per-task (no inheritance) | n/a |
| `security_sensitivity` | Default from convoy | Both directions allowed (a single task may be more or less sensitive) |
| `cognitive_demand` | Default from convoy | Both directions allowed |
| `scope_allowed_paths` | **Tighten** the convoy's allow list | Must be a subset of the convoy's |
| `scope_forbidden_paths` | **Extend** the convoy's deny list | Inherit + add |
| `scope_invariants` | **Extend** the convoy's invariants | Inherit + add |

If a task wants `risk_tier` *higher* than its convoy's, that's a
decomposition smell — see `decomposition-discipline.md` for the fix.

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Task with no `convoy_parent` metadata | Falls outside convoy coordination; merge policy can't atomically gate it |
| Task `scope_allowed_paths` overlaps with a sibling | File contention during parallel execution; one will lose |
| Task duplicates the convoy invariants in its own description with edits | Drift between convoy and task; the convoy is the source of truth |
| Task overrides `risk_tier` upward to bypass convoy-level human gates | Defeats the convoy's gate uniformity; if needed, restructure into a separate convoy |
| Task picks `workflow_type` by file extension instead of by work nature | Wrong formula gets dispatched; e.g., a refactor PR running through `work:feature`'s self-review |
| Per-task `role` metadata missing | Mechanical tooling can't distinguish convoy from standalone tasks |
| Task description copies the convoy spec wholesale | Wastes context, drifts over time; reference the convoy by ID instead |
| Task in a different backend than its convoy | Audit trail fragments; the convoy is the unit of backend-binding |
