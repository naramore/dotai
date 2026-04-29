# Backend: Linear

How convoy + tasks are encoded when the target backend is **Linear**.
Use this backend when work needs to be visible to remote agents,
collaborators, or stakeholders who don't have a local beads checkout —
typically when handing work off to remote / cloud-resident agents.

## Mapping

| Convoy-spec role | Linear primitive |
|---|---|
| Convoy | Parent issue |
| Task | Sub-issue (child of the convoy issue) |
| Dependency edge | "Blocked by" relation between sub-issues |
| Description body | Issue description (markdown) |
| Quality metadata | Labels (filter-critical) + custom fields (where configured) + `<!-- meta:start -->...<!-- meta:end -->` description fence (everything else) |
| Journal | Issue comments |
| Lifecycle state | Maps to the team's workflow states (project-configurable) |

Linear has **no arbitrary metadata bag**, so quality metadata is split
across three encoding mechanisms (chosen by what each value is consumed
for):

- **Labels** — anything a downstream tool, view, or workflow filter must
  query on (`risk_tier`, `workflow_type`, `change_risk`, etc.).
- **Custom fields** — preferred for typed scalar values *if your team has
  set up the right ones*. Falls back to labels or fence if not.
- **Description fence** — everything else (path lists, holdout digests,
  scope invariants, lifecycle metadata).

## Operations are MCP-mediated

These instructions assume the Linear MCP server is available (the
runtime exposes tools like `list_issues`, `save_issue`, `save_comment`,
etc.). Exact tool names vary by MCP install — use whichever your runtime
provides. The shape of operations is what matters:

- Create issue → API call with `{ title, description, teamId, projectId, parentId?, labelIds }`
- Update issue → API call with the same shape, targeting an existing ID
- Add relation → API call to create a "blocks" / "blocked by" link
- Add comment → API call appending markdown to the issue's comment thread
- Read issue → API call returning the full issue payload (description, labels, custom fields, comments)

## Creating a convoy

1. **Create the parent issue** in the target team / project.

```
POST issue {
  title: "<initiative title>",
  description: "<convoy spec markdown — see Description body, below>",
  teamId: <team>,
  projectId: <project>,            # convoy and all sub-issues share one project
  labelIds: [
    label("convoy:role:convoy"),
    label("convoy:risk:medium"),
    label("convoy:radius:component"),
    label("convoy:reversibility:procedural"),
    label("convoy:security:indirect"),
    label("convoy:coupling:coupled"),
    label("convoy:demand:standard"),
    label("convoy:novelty:familiar"),
    label("convoy:templates:high"),
    label("convoy:lifecycle:approved"),
    label("convoy:atomicity:all_or_none"),
    label("convoy:adversarial:passed"),
    label("convoy:holdout:n_a"),
    label("convoy:backend:linear"),
  ]
}
```

2. **Set custom fields** if your team has them configured. Recommended set:
   `risk_tier`, `blast_radius`, `cognitive_demand`, `workflow_type`,
   `spec_lifecycle`. If absent, the labels above carry these values.

3. **Embed structured metadata in the description fence** for everything
   that doesn't fit labels / custom fields cleanly.

## Description body (with embedded metadata)

```markdown
# <Initiative Title>

## Purpose
<2-3 sentences>

## Child Task Manifest
| Task | Title | Workflow type | Status |
|------|-------|---------------|--------|
| <linear-id> | ... | work:feature | Backlog |

## Dependency Graph
<linear-id-1> → <linear-id-3>
<linear-id-2> → <linear-id-3>

## Convoy-Level Scope
### In-scope
- repos: ...
- paths: ...

### Out-of-scope
- ...

### Forbidden paths
- repo: ...
  paths:
  - ...

### Invariants
- ...

## Cross-Task Concerns
- ...

## Holdout Policy
- enabled: true
- categories: negative_scope, rollback, idempotency, scope_enforcement
- sealed-artifact ref: <URL to S3 / git blob / etc.>

## Merge Policy
- atomicity: all_or_none
- rebase strategy: ...
- automerge eligibility: ...

## Provenance
- bead-ready doc: <path or URL>
- review_id: <slug>
- adversarial review outcome: clean | minor | major
- adversarial rounds: <n>
- target backend: linear

<!-- convoy:meta:start -->
backend: linear
role: convoy
risk_tier: medium
blast_radius: component
reversibility: procedural
security_sensitivity: indirect
cross_repo_coupling: coupled
cognitive_demand: standard
domain_novelty: familiar
template_coverage: high
scope_allowed_paths: <glob>,<glob>
scope_forbidden_paths: <glob>
scope_invariants: <i1>;<i2>
adversarial_status: passed
adversarial_severity: minor
adversarial_rounds: 2
holdout_status: n_a
holdout_digest:
holdout_jwe_ref:
spec_lifecycle: approved
spec_frozen_at:
merge_atomicity: all_or_none
bead_ready_doc: <path or URL>
review_id: <slug>
<!-- convoy:meta:end -->
```

The fence is the **canonical store** for any value not also in labels /
custom fields. Downstream tools should parse the fence rather than the
prose.

## Creating a task (sub-issue)

```
POST issue {
  title: "<imperative task title>",
  description: "<task spec markdown with convoy-context section + meta fence>",
  teamId: <same as convoy>,
  projectId: <same as convoy>,
  parentId: <convoy issue id>,    # this is what makes it a sub-issue
  labelIds: [
    label("convoy:role:task"),
    label("convoy:risk:medium"),     # task's effective risk_tier
    label("convoy:workflow:work:feature"),
    label("convoy:demand:standard"),
    label("convoy:backend:linear"),
    # ... per qualities-schema
  ]
}
```

The task description includes the standard `issue-spec` body **plus** the
convoy-context section (per `format-task.md`) **plus** a meta fence:

```markdown
... (issue-spec sections) ...

## Convoy Context
- Parent convoy: <linear-id> — <convoy title>
- Position in graph: depends on <linear-id-1>; blocks <linear-id-3>
- Inherited convoy invariants: ...
- Inherited convoy forbidden paths: ...

## Cross-Task AC References
- ...

<!-- convoy:meta:start -->
backend: linear
role: task
convoy_parent: <linear-id>
workflow_type: work:feature
risk_tier: medium
blast_radius: component
reversibility: procedural
security_sensitivity: indirect
cognitive_demand: standard
scope_allowed_paths: <glob>
scope_forbidden_paths: <glob>
scope_invariants: <i>
template_coverage: high
spec_completeness: complete
<!-- convoy:meta:end -->
```

## Wiring dependencies

Use Linear's **"blocked by"** relation. Each adjacency edge in section 7
of the bead-ready doc becomes one relation:

```
POST issue-relation {
  type: "blocked_by",
  issueId: <task-3>,
  relatedIssueId: <task-1>,
}
```

Linear surfaces these in the issue UI ("Blocked by ...") and in views
filtered by blocking status. The convoy formula relies on `blocked_by`
specifically (not `blocks` from the other direction) so the read-back
graph is unambiguous.

## Label namespace conventions

Recommended namespace: `convoy:*` to avoid collisions with team-specific
labels.

| Label key | Values |
|---|---|
| `convoy:role` | `convoy`, `task` |
| `convoy:risk` | `critical`, `high`, `medium`, `low` |
| `convoy:radius` | `local`, `component`, `system`, `org` |
| `convoy:reversibility` | `instant`, `procedural`, `costly`, `irreversible` |
| `convoy:security` | `none`, `indirect`, `direct`, `critical` |
| `convoy:coupling` | `none`, `coupled`, `chain` |
| `convoy:demand` | `routine`, `standard`, `frontier` |
| `convoy:novelty` | `routine`, `familiar`, `novel` |
| `convoy:templates` | `full`, `high`, `partial`, `novel` |
| `convoy:workflow` | `work:feature`, `work:bugfix`, `work:refactor`, `work:spike`, `work:infrastructure`, `work:dependency`, `work:test-authoring`, `work:cleanup`, `work:migration`, `work:performance`, `work:documentation`, `work:hotfix`, `work:configuration`, `work:security` |
| `convoy:lifecycle` | `draft`, `in_review`, `approved`, `frozen`, `executing`, `verifying`, `merged`, `failed` |
| `convoy:atomicity` | `all_or_none`, `sequential`, `independent` |
| `convoy:adversarial` | `passed`, `failed`, `escalated` |
| `convoy:holdout` | `derived`, `sealed`, `skipped`, `n_a` |
| `convoy:backend` | `linear`, `beads` |

Create these label sets once per Linear team. The convoy formula expects
them to exist; if missing, it should create them on first use rather than
failing.

## Lifecycle state mapping

Linear's per-team workflow states are configurable; convoy-spec's
`spec_lifecycle` enum has fixed semantics. Each Linear team maps the two
via project-specific config.

**Default mapping** (most Linear teams have something close to this):

| `spec_lifecycle` | Typical Linear state |
|---|---|
| `draft` | Backlog |
| `in_review` | Todo |
| `approved` | Todo (or a custom "Approved" state if available) |
| `frozen` | Todo (or a custom "Frozen" state) |
| `executing` | In Progress |
| `verifying` | In Review (or "QA" / "Verifying") |
| `merged` | Done |
| `failed` | Cancelled |

If the team has more granular states (e.g., separate "Approved" and
"Frozen"), prefer them. The mapping table belongs in the project's
config file (typically `<overlay>/config/<team>.toml`), not hardcoded in
the convoy formula.

The `convoy:lifecycle:*` label is the **canonical** lifecycle value;
the Linear state is the *display* of it. If they ever diverge, the label
wins.

## Holdout sealing

Linear can't store sealed payloads. The pattern:

1. Seal the holdout artifact (JWE encrypt, JWS sign) **outside Linear** —
   to S3, GCS, a private git repo, or wherever your sealing service
   writes.
2. Record the URL + content hash in:
   - `convoy:holdout:sealed` label (status only)
   - Description fence: `holdout_digest: sha256:<hex>` and
     `holdout_jwe_ref: <URL>` and `holdout_jws_ref: <URL>`
3. Per-task spec YAMLs (if emitted) pin the same digest.

Access control on the sealed artifact is enforced by the storage
backend's ACLs — Linear is just the catalog entry.

## Comments as journal

Append-only. Every formula run that touches the convoy or a task drops
a dated comment.

```
POST comment on convoy issue:
"$(date -Iseconds): convoy created from <bead-ready-doc>. 4 child tasks: <ids>."
"$(date -Iseconds): adversarial review complete (severity=minor, rounds=2). Approved."
"$(date -Iseconds): holdout sealed (digest=sha256:abc...). Lifecycle=frozen."
```

Re-runs of the same formula on the same day get a `(re-run)` suffix in
the comment body. Never edit a prior comment.

## Reading convoy state

The canonical reads:

| Want | Read from |
|---|---|
| Convoy lifecycle | `convoy:lifecycle:*` label OR fence `spec_lifecycle:` (must agree; label is authoritative if not) |
| Risk tier | `convoy:risk:*` label OR custom field `risk_tier` (must agree) |
| Scope paths | Description fence `scope_allowed_paths:` / `scope_forbidden_paths:` |
| Holdout digest | Description fence `holdout_digest:` |
| Child task list | Linear's sub-issues query (parent → children) |
| Dependency graph | Linear's "blocked by" relations across the convoy's sub-issues |
| Journal | Issue comments, in chronological order |

## Cross-team convoys (edge case)

A convoy that spans multiple Linear teams is the *exceptional* case.
Default: pick one team for the convoy and put all sub-issues in the same
team + project. If a task genuinely belongs to a different team:

- Keep the convoy in its primary team.
- Create the task in its proper team but as a *standalone* issue (not a
  sub-issue — Linear's parent-child relation is single-team).
- Use a "related" relation to link the task back to the convoy.
- The convoy formula must handle the missing parent-child link explicitly
  (read related-issues + filter by `convoy:role:task` label + matching
  `convoy_parent` in description fence).

This is friction. Avoid when possible.

## Constraints worth knowing

- **No native arbitrary metadata bag.** Hence the labels + custom fields +
  fence pattern.
- **Sub-issues nest one level only.** Convoy → task is fine. Task → grandchild
  isn't supported the same way; use related-issues instead.
- **No native sealing primitive.** Sealed payloads live in object storage;
  Linear catalogs the digest.
- **Audit log is per-issue.** A convoy formula touching N sub-issues produces
  N separate audit trails. Mitigate via a summary comment on the convoy
  issue at the end of each formula run.
- **Workflow states are per-team.** Lifecycle mapping must be team-aware.
- **Description fence is informally enforced.** Linear doesn't validate the
  fence's contents; the convoy formula must parse + validate on every read.

## Anti-patterns specific to the Linear encoding

| Anti-pattern | Why it fails |
|---|---|
| Quality metadata only in description prose, no labels or fence | Downstream filters can't query; views can't be built; tooling has to LLM-parse the description |
| Different label namespaces across the same convoy's sub-issues | Filter views break; consistency depends on every formula run using the same prefix — pick `convoy:*` and stick |
| Lifecycle state only in Linear workflow state, no `convoy:lifecycle:*` label | Cross-tool consumers without Linear-state visibility can't read the lifecycle |
| Holdout payload posted as a Linear comment or attachment | Linear is not designed to host sealed binary blobs; use real object storage |
| Editing a prior comment | Breaks append-only journal contract |
| Cross-team convoy with sub-issues split across teams | Linear's parent-child is single-team; defaults will be wrong |
| Splitting one convoy half in beads, half in Linear | Audit fragments; pick one backend per convoy and stick |
