# Step Issue-Metadata Reference

bd creates issues from steps when a formula is "rigged" (turned into actual tracker tickets). Several `Step` fields decorate the resulting issue with metadata. These fields are preserved through `bd cook` (verified empirically) and consumed by downstream tooling that creates issues.

## Fields

| Field | Type | Use for |
|---|---|---|
| `type` | string | Issue type (e.g., `"task"`, `"bug"`, `"epic"`, `"human"`). Runtime/tracker-defined |
| `title` | string | Issue title (already covered — every step has one) |
| `description` | string | Issue description (already covered — every step has one) |
| `notes` | string | Secondary notes shown alongside description; useful for hand-off context that shouldn't be in the main description |
| `priority` | int | Numeric priority (lower = higher priority by convention; check your runtime) |
| `labels` | []string | Issue labels for categorization |
| `assignee` | string | Default assignee for the issue |
| `metadata` | map[string]any | Arbitrary key-value metadata; runtime-defined keys |

## Worked example

```toml
[[steps]]
id          = "fix-auth-bug"
title       = "Fix auth bug in token validation"
description = "JWT validation rejects valid tokens after expiry refresh"
notes       = "Reproduced via session-replay; see incident #INC-4523"
type        = "bug"
priority    = 1
labels      = ["security", "blocker", "auth"]
assignee    = "alice"
[steps.metadata]
sentry_issue   = "PROJ-12345"
related_pr     = "https://github.com/org/repo/pull/678"
slack_thread   = "https://slack.com/..."
```

Cooked output preserves every field:

```json
{
  "id": "fix-auth-bug",
  "title": "Fix auth bug in token validation",
  "description": "JWT validation rejects valid tokens after expiry refresh",
  "notes": "Reproduced via session-replay; see incident #INC-4523",
  "type": "bug",
  "priority": 1,
  "labels": ["security", "blocker", "auth"],
  "assignee": "alice",
  "metadata": {
    "sentry_issue": "PROJ-12345",
    "related_pr": "https://github.com/org/repo/pull/678",
    "slack_thread": "https://slack.com/..."
  }
}
```

## Field NOT present in `Step`: `acceptance`

Some gastown production formulas use `acceptance = "..."` on each step (e.g., `shiny.formula.toml`):

```toml
[[steps]]
id         = "design"
title      = "Design"
acceptance = "Design doc committed covering approach, trade-offs, files to change"
```

**Empirically verified:** `bd cook` silently DROPS the `acceptance` field — it does not appear in the cooked proto. The Go `Step` struct has no corresponding field. Treat `acceptance` as a comment-as-data convention used by some downstream consumer that reads the raw TOML (not the cooked proto), or as cosmetic documentation. Don't rely on bd preserving it.

If you need acceptance criteria preserved through the cook stage, use `notes` or embed in `description`:

```toml
[[steps]]
id          = "design"
title       = "Design"
description = """
Design the change.

**Acceptance:** Design doc committed covering approach, trade-offs, files to change.
"""
```

## What bd cook does NOT validate

bd cook does not validate:
- That `priority` falls in any specific range
- That `assignee` is a known user
- That `labels` match any existing label set
- That `type` is a recognized issue type
- That `metadata` keys are known

These are downstream consumer concerns (the issue tracker, the rigging step). Use them anyway — bd happily roundtrips them, and they become available to whatever tool turns cooked steps into issues.

## Sources

- `gastownhall/beads/internal/formula/types.go` — `Step` struct fields
