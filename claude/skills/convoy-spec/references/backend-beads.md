# Backend: beads

How convoy + tasks are encoded when the target backend is **beads** (the
local-first work-tracking primitive used in the gastown / dotai stack,
backed by Dolt for versioned data).

## Mapping

| Convoy-spec role | beads primitive |
|---|---|
| Convoy | A bead with `type=convoy` (or `type=epic` if the local install lacks a `convoy` type) |
| Task | A bead with `type=task` |
| Dependency edge | `bd dep add <child> --depends-on <parent>` |
| Description body | The bead's `description` field |
| Quality metadata | The bead's metadata bag (`bd update <id> --set-metadata key=value`) |
| Journal | Bead notes (`bd update <id> --notes "..."`) |
| Lifecycle state | `bd update <id> --status <state>` + custom `spec_lifecycle` metadata key |

Beads has an **arbitrary key/value metadata bag** — every key from
`format-convoy.md` and `format-task.md` lands as a metadata entry with
no special encoding. This makes beads the lowest-friction backend for
convoy-spec.

## Creating a convoy

```bash
# Create the parent
CONVOY=$(bd create --title "<initiative title>" --type epic --json | jq -r '.[0].id')
bd update "$CONVOY" --description "$(cat path/to/convoy-spec.md)"

# Quality metadata
bd update "$CONVOY" --set-metadata role="convoy"
bd update "$CONVOY" --set-metadata risk_tier="medium"
bd update "$CONVOY" --set-metadata blast_radius="component"
bd update "$CONVOY" --set-metadata reversibility="procedural"
bd update "$CONVOY" --set-metadata security_sensitivity="indirect"
bd update "$CONVOY" --set-metadata cross_repo_coupling="coupled"
bd update "$CONVOY" --set-metadata cognitive_demand="standard"
bd update "$CONVOY" --set-metadata domain_novelty="familiar"
bd update "$CONVOY" --set-metadata template_coverage="high"
bd update "$CONVOY" --set-metadata scope_allowed_paths="<glob>,<glob>"
bd update "$CONVOY" --set-metadata scope_forbidden_paths="<glob>"
bd update "$CONVOY" --set-metadata scope_invariants="<i1>;<i2>"
bd update "$CONVOY" --set-metadata adversarial_status="passed"
bd update "$CONVOY" --set-metadata adversarial_severity="minor"
bd update "$CONVOY" --set-metadata adversarial_rounds="2"
bd update "$CONVOY" --set-metadata holdout_status="n_a"
bd update "$CONVOY" --set-metadata spec_lifecycle="approved"
bd update "$CONVOY" --set-metadata merge_atomicity="all_or_none"
bd update "$CONVOY" --set-metadata bead_ready_doc="<path>"
bd update "$CONVOY" --set-metadata review_id="<slug>"
bd update "$CONVOY" --set-metadata backend="beads"
```

`spec_lifecycle` and `bd status` are tracked **separately**:

- `bd status` is the bead-tool's lifecycle (`open / in_progress / closed`).
- `spec_lifecycle` is the convoy's planning lifecycle (`draft / approved
  / frozen / executing / verifying / merged / failed`).

A convoy that's `spec_lifecycle=executing` typically has `bd status=in_progress`.

## Creating a task

```bash
TASK=$(bd create --title "<imperative task title>" --type task --priority 2 --json | jq -r '.[0].id')
bd update "$TASK" --description "$(cat path/to/task-spec.md)"

# Convoy-context metadata
bd update "$TASK" --set-metadata role="task"
bd update "$TASK" --set-metadata convoy_parent="$CONVOY"
bd update "$TASK" --set-metadata workflow_type="work:feature"
bd update "$TASK" --set-metadata backend="beads"

# Quality metadata (inherit from convoy unless explicitly overridden)
bd update "$TASK" --set-metadata risk_tier="<inherit-or-override>"
# ... (remaining quality keys per format-task.md)
```

## Wiring dependencies

Each "depends on" edge from section 7 of the bead-ready doc becomes a
single `bd dep` call:

```bash
bd dep add "$TASK_3" --depends-on "$TASK_1"
bd dep add "$TASK_3" --depends-on "$TASK_2"
bd dep add "$TASK_4" --depends-on "$TASK_3"
```

Validate the resulting graph is a DAG:

```bash
bd dep validate "$CONVOY" --recursive
```

## Journal (append-only)

Per the convoy lifecycle, every formula run that touches a convoy or task
appends a dated note. Never edit a prior note.

```bash
bd update "$CONVOY" --notes "$(date -Iseconds): convoy created from <bead-ready-doc>. 4 child tasks, $(echo $TASK_1 $TASK_2 $TASK_3 $TASK_4)."
bd update "$CONVOY" --notes "$(date -Iseconds): adversarial review complete (severity=minor, rounds=2). Approved."
bd update "$CONVOY" --notes "$(date -Iseconds): holdout sealed (digest=sha256:abc...). Lifecycle=frozen."
```

Re-runs of the same formula on the same day get a `(re-run)` suffix in the
note body.

## Lifecycle state mapping

| `spec_lifecycle` | `bd status` | Notes |
|---|---|---|
| `draft` | `open` | Convoy bead exists, decomposition not yet validated |
| `in_review` | `open` | Cross-item self-validation in progress |
| `approved` | `open` | Self-validation passed, holdout pipeline pending (if applicable) |
| `frozen` | `open` | Holdout sealed (or skipped); ready for dispatch |
| `executing` | `in_progress` | Children being implemented |
| `verifying` | `in_progress` | Implementation done; verification stack running |
| `merged` | `closed` (state-reason: completed) | All children merged successfully |
| `failed` | `closed` (state-reason: cancelled or duplicate) | Convoy abandoned or rolled back |

## Holdout artifacts

Holdout payloads (sealed YAML or similar) live on the filesystem at a
known path; the digest goes into bead metadata.

```bash
# After sealing
bd update "$CONVOY" --set-metadata holdout_status="sealed"
bd update "$CONVOY" --set-metadata holdout_digest="sha256:<hex>"
bd update "$CONVOY" --set-metadata holdout_jwe_ref=".plan-reviews/$REVIEW_ID/holdout.jwe"
bd update "$CONVOY" --set-metadata holdout_jws_ref=".plan-reviews/$REVIEW_ID/holdout.jws"

# Pin digest into each per-task spec YAML
for SPEC in .dsf/specs/*.yaml; do
  yq -i ".holdout.contentHash = \"sha256:<hex>\"" "$SPEC"
done
```

## Per-item spec artifacts (optional)

For tasks with `risk_tier ≥ medium`, write a structured spec artifact
alongside the bead:

```bash
cat > ".dsf/specs/$TASK.yaml" <<EOF
id: $TASK
convoy: $CONVOY
title: <bead title>
intent: <what and why>
scope:
  inScope: [...]
  outOfScope: [...]
  allowedPaths: [...]
  forbiddenPaths: [...]
  invariants: [...]
acceptanceCriteria:
  - id: AC-1
    description: ...
    verification: ...
risk:
  tier: medium
  blastRadius: component
  reversibility: procedural
  securitySensitivity: indirect
  cognitiveDemand: standard
workflowType: work:feature
lifecycle: frozen
holdout:
  contentHash: sha256:<hex>
EOF
```

`low`-risk tasks may skip the YAML — bead metadata is sufficient.

## Dispatch hand-off

Beads-native dispatch via `pour`:

```bash
# Dispatch a single task
bd mol pour "$TASK" --formula "$(bd show $TASK --json | jq -r '.[0].metadata.workflow_type | sub("work:";"mol-")')"
```

For gascity / city-overlay dispatch, see the city's local convoy formula —
this skill stops at the bead/spec layer.

## Why beads is the lowest-friction backend

- Arbitrary metadata bag — the schema fits with no encoding tricks.
- Versioned via Dolt — full history, branches, diffs for free.
- Native dependency primitive — no abuse of relations.
- Local-first — no network round-trips during decomposition.
- The `pour` skill ships with this stack.

## Anti-patterns specific to the beads encoding

| Anti-pattern | Why it fails |
|---|---|
| Storing convoy spec in `description` and quality metadata also in `description` | Two sources of truth for metadata; downstream tools won't know which to trust |
| Editing a prior note via `bd update --replace-notes` | Breaks the append-only journal contract; audit trail loss |
| Using `bd status` as the convoy lifecycle | Confuses bead-tool state with planning lifecycle; keep them separate via the `spec_lifecycle` metadata key |
| Skipping `--set-metadata backend="beads"` | Cross-backend tooling can't tell which backend this convoy lives in |
