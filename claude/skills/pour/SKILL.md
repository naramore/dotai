---
name: pour
description: >-
  Execute a dotai formula (mol-* or me-*) defined as TOML. Resolves the
  formula file, collects required [vars] in one batched prompt, runs steps
  in DAG order with parallel fan-out where dependencies allow, verifies
  each step's exit criteria, and keeps posting / dispatch / state-body
  mutation behind explicit second invocations (`--post`, `--dispatch`).
  Load this whenever the user says "pour", "run", or "execute" a named
  formula, or when one formula's step composes another via a `pour`
  directive. Also load before editing anything that reads the TOML
  formula schema, the journal-comment convention, or the state-issue
  body-hash check.
---

# pour — formula executor (v0)

The runtime for `dotai` formulas. The formula author writes intent in TOML; this skill turns intent into dispatched work.

## Core principles (baked into every rule below)

- **Zero Framework Cognition.** The shell parses TOML, sequences the DAG, substitutes vars, and verifies structure. Every judgment call (which agent, what to write, did the step succeed) goes to a model — never a code-side heuristic over natural language.
- **Preview by default.** Posting and dispatch are second invocations, not y/n prompts. Confirmation prompts erode under fatigue; an explicit second command does not.
- **Append-only journal.** Runs leave dated comments; nothing edits prior history.
- **Single-writer body.** At most one formula mutates a given state issue body per run; before save, re-read and hash-check.
- **Run-anytime-safe.** Missing prior runs, double runs, long gaps, malformed state must all degrade gracefully — never error, never silently overwrite.

If you find yourself wanting to relax one of these, stop and surface the conflict to the user.

## When to load

- "pour `<formula>`" / "run `<formula>`" / "execute `<formula>`"
- a step in another formula whose body says `pour <formula>`

Skip when the user is *authoring or editing* a formula's TOML — that's a different task (formula schema lives in `formulas/README.md`).

## Inputs

1. **Formula ID** — filename without `.toml` (e.g., `me-sod`).
2. **Variable bindings** for `[vars]` declared `required = true`. Ask once, batched, before dispatch. Never prompt mid-execution.
3. **Mode flags** (optional): `--post`, `--dispatch <ids>`. Absent means preview-only.

## Lookup order

Resolve the formula path in this order; first hit wins:

1. `./.beads/formulas/<formula>.toml`           (project-local)
2. `<private_overlay>/formulas/library/<formula>.toml`  (overlay, if configured)
3. `<public_profile>/formulas/library/<formula>.toml`   (`dotai`)

`public_profile` and `private_overlay` come from `[paths]` in the project's `config.toml` (template at `formulas/config.example.toml`).

## TOML schema

The full schema is in `formulas/README.md`. Before dispatching, validate:

- `formula` field equals the filename without `.toml`.
- `version` is an integer ≤ `1`. A higher version means the formula assumes a runtime this skill doesn't have — refuse to execute and report the version mismatch.
- Every `needs` reference points to a declared step `id`.
- The DAG is acyclic.
- Every required `[vars.<name>]` is collected before the first step runs.

Refuse to dispatch on any failure. Do not fall back to freeform interpretation of a malformed formula — that defeats the point of TOML being the contract.

## Execution

### 1. Resolve

Locate, parse, validate (above). Collect required vars in one batched prompt. Substitute `{{var}}` in step `description` strings.

### 2. Build the DAG

Topological sort into parallel bands. A band's steps all have their dependencies satisfied and no dependency on a sibling.

- Sequential band → single agent.
- Parallel band → multiple `Agent` calls in **one message**, so they run concurrently.

### 3. Dispatch

For each step:

- Pick the agent type from step intent: research/lookup → `Explore`; multi-step planning → `Plan`; otherwise `general-purpose`. A formula may override by including an HTML-comment directive in the step body (e.g., `<!-- agent: Explore -->`).
- Pass the substituted `description` as the agent prompt **verbatim**, plus the step `title`, formula `description`, and resolved vars.
- Read the agent's structured result. If the body names `**Exit criteria:**`, verify them. "The command ran" is not proof of outcome — verify the outcome.

### 4. Synthesize

For parallel bands, merge results into one structured digest before any dependent step runs. The merge shape depends on the band:

| Band shape | Synthesis |
|---|---|
| Independent reads (Linear + GitHub + calendar) | Structured merge by source |
| Adversarial probes | Keep all findings, dedupe, sort by severity |
| Voting / consensus | Count agreement, surface dissent |

### 5. Terminal handoff

Print the formula's terminal artifact (digest, diff, brief) to the user. Never auto-post to GitHub/Linear/Slack. Never auto-dispatch beads. Record the run in the formula's journal surface (next section).

## State mutation rules

The four formulas allowed to mutate the operator state-issue body are: `me-sod`, `me-eod`, `me-priority-review`, `me-weekly-review`. For these:

- **Single-writer.** Only one of these formulas mutates the body in any given run. Refuse if another `pour` invocation is mid-run on the same state issue (check via a local lockfile keyed on `state_issue_id`; release on completion or after a 2h stale timeout). *Why:* concurrent writers race; the journal can recover from anything except an overwrite of a partial write.
- **Body-hash check.** Before saving, re-read the issue body and compare its hash to what was read at the start of the run. If changed, surface the diff and refuse to overwrite. The operator decides resolution. *Why:* the operator may have edited by hand between read and write; their edit is the source of truth.
- **Fence-bounded edits.** Only the region between `<!-- me:state:start -->` and `<!-- me:state:end -->` is mutable. Everything outside the fence is preserved verbatim. *Why:* the operator owns the rest of the body; the formula only owns its fenced section.
- **Append-only journal.** Every run drops a new dated comment on the state issue. Never edit a prior comment. Re-runs of the same formula on the same day add a `(re-run)` suffix to the comment heading. *Why:* journal history is the audit trail; rewriting it loses the trail.

For all other formulas: no state-issue body mutation. They may post comments (advisory journal), but only when invoked with `--post`.

## Posting / dispatch gates

- Default mode is preview. Nothing posts to GitHub/Linear/Slack and no beads dispatch unless the user opted in on the invocation.
- Opt-in is a **second invocation**, never a y/n prompt:
  - `pour me-pr-review --post <pr>` posts review comments.
  - `pour me-eod --dispatch <bead-ids>` dispatches overnight beads.
- If a formula's body asks the executor to "ask the user before posting", ignore that instruction. The gate is the second invocation. *Why:* a y/n prompt at the end of a long run gets reflexively approved when tired; a separate command requires deliberate intent.

## Run-anytime-safe behavior

These cases must work from v0; retrofitting after the journal has history is painful.

- **Missing prior comment.** `me-eod` with no morning SOD comment for the day reconciles against the issue body alone; never errors. `me-sod` with no prior EOD reads back to the most recent EOD comment, however old, and labels the gap.
- **Double-run.** Running the same formula twice in one day produces an updated brief and a *second* dated comment tagged `(re-run)`, not a silent overwrite.
- **Long gap.** First run after N days off summarizes the gap (priority drift, items past their SLA, in-flight bead status) before producing today's output.
- **Partial state.** If the state-issue body is missing the parse fence or has malformed entries, degrade to read-only mode and surface the diff for manual repair. Never silently overwrite.

## Subagent dispatch patterns

| Pattern | When | Tool shape |
|---|---|---|
| **Single agent** | Sequential step with one clear question | One `Agent` call, default `general-purpose` |
| **Fan-out** | Independent reads (e.g., Linear + GitHub + calendar) | Multiple `Agent` calls in **one message**; synthesize on return |
| **Adversarial probes** | Multi-perspective review formulas | Fan-out with distinct prompts per probe; aggregate by severity |
| **Council** | Cross-model consensus | Fan-out with same prompt to different models; vote-count results |

## Variable substitution

- `{{var}}` → resolved string from `[vars]` (required-confirmed or default).
- Substitution is **textual** in the step `description` field only. No substitution in `id`, `title`, `needs` — those are structural.
- `{{var}}` referenced with no default and not declared `required = true` is a formula-author bug. Refuse to dispatch and report which step references it.

## Satisfaction checklist

Before declaring a formula complete, confirm:

- [ ] Every step's `**Exit criteria:**` was verified, not just attempted.
- [ ] All parallel-band results were synthesized; nothing dropped silently.
- [ ] State-mutating formulas: body-hash unchanged since read; single-writer lock released; append-only comment posted with today's date.
- [ ] Posting/dispatch: nothing posted/dispatched unless `--post` / `--dispatch` was on the invocation.
- [ ] Idempotency: re-running this exact invocation now would produce a `(re-run)` comment, not an error or silent overwrite.
- [ ] Terminal artifact handed to the user (digest, diff, brief, or "no change today").

If any box can't be ticked, surface what's incomplete and stop. Do not fabricate completion.

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Regex / keyword matching to decide if a step "succeeded" | Fragile across phrasing and languages — verify the named exit criterion instead |
| Auto-posting because "the user obviously meant to" | Erodes the preview-by-default invariant; require the second invocation |
| Editing a prior journal comment to "fix" it | Breaks append-only audit trail; post a new dated comment with the correction |
| Overwriting state body without re-reading first | Loses operator hand-edits made between read and write |
| Prompting mid-run for a missing required var | Disrupts parallel bands; collect all required vars before dispatch |
| Falling back to freeform when TOML parse fails | The TOML is the contract — refuse and report, don't guess |
| Sequencing parallelizable steps | Wastes wall-clock; if `needs` doesn't connect them, fan them out in one message |

## Quick reference

```
1. Resolve     → project → overlay → public; first hit wins
2. Validate    → version ≤ 1, DAG acyclic, needs resolve, vars collected
3. Plan        → topo-sort into parallel bands
4. Dispatch    → fan out parallel bands in one message; verify exit criteria
5. Synthesize  → merge band results before dependents run
6. Hand off    → preview to user; --post / --dispatch is a second invocation
7. Journal     → dated comment, append-only; (re-run) suffix on same-day repeats
8. State body  → hash-check before save; fenced region only; single-writer
```
