# Guiding Principles — dotai

> The why-axioms that prevent architectural drift. Read these first.
> When generated code or design seems to violate one, name the principle.

These principles govern the public `dotai` profile. A private overlay
inherits them and may add its own overlay-specific principles in the
overlay's own `PRINCIPLES.md`.

## P1. Zero Framework Cognition

**Principle:** Judgment-bearing logic stays with the model; deterministic
surfaces stay mechanical.

**Why:** Embedding pattern-matching or heuristic logic in formulas, scripts,
or skills locks in early guesses about ambiguous inputs. The model can
reason about edge cases at call time; a regex or a hardcoded rule cannot.
Mechanical work (parse TOML, sequence a DAG, substitute vars, hash a body)
is fine to encode — judgment ("which agent should run this", "did the step
succeed", "is this a P0") is not.

**Heresy this prevents:** Formulas that try to outsmart the model with
brittle natural-language pattern matching in code.

**Operationalized by:** `pour` skill (mechanical executor that delegates
every judgment to a dispatched agent); formula schema (TOML structure for
mechanics, free-form Markdown for judgment).

## P2. Public-shape from line one

**Principle:** Any org-specific value (team key, MCP server name, priority
framework reference, ticket prefix, state issue ID) goes through the
config-shape boundary, never hardcoded into a formula prompt or skill body.

**Why:** Generic-shape discipline at authoring time costs minutes; ripping
hardcoded values out later is a 70-80% rewrite. Existing formulas authored
without this discipline have proven the point — extraction after the fact
is rewriting, not refactoring.

**Heresy this prevents:** "We'll refactor it generic later" — later never
arrives, and the coupling compounds.

**Operationalized by:** `formulas/config.example.toml` (declares the shape);
`pour` substitutes `{{var}}` from the resolved config layers.

## P3. Build where the data lives

**Principle:** Judgment-bearing formulas (`me-*`) are written in a private
overlay against real data first, then `git mv`'d into `dotai` once
validated. P9 is the complement — purely mechanical surfaces start in
`dotai` directly.

**Why:** Real org context is the only validator. Building generic-first
means designing against zero users; you optimize for imagined needs and
get the abstraction wrong.

**Heresy this prevents:** Speculative generic abstractions polished against
zero real-world friction.

**Operationalized by:** The overlay's `formulas/library/` is the staging
ground; 2-3 weeks of validation before the migration; the migration is a
`git mv` because the boundary held.

## P4. Posting and dispatch are second invocations, never prompts

**Principle:** Any action that mutates the outside world (posting a PR
comment, dispatching a bead, updating a Linear issue body) requires an
explicit second invocation with `--post` / `--dispatch <ids>`. No y/n
prompts at decision points.

**Why:** Confirmation prompts erode under fatigue. A separate command
does not. Especially load-bearing at end-of-day, when judgment is at its
worst and dispatch decisions are most impactful.

**Heresy this prevents:** "Just one tap" defaults that destroy work or
spam channels when an operator is tired or distracted.

**Operationalized by:** `pour` skill enforces `--post` / `--dispatch` as
the only paths to mutation; preview is the default.

## P5. Append-only journal

**Principle:** Formulas never edit prior dated comments. The state-issue
*body* is mutable state; comments are the audit trail.

**Why:** Silent overwrites destroy history. Distinct surfaces for state
(body) vs. history (comments) make rollback and forensics tractable.

**Heresy this prevents:** State/history confusion where you can't tell
what was true at any point in time.

**Operationalized by:** `pour` skill enforces append-only on comments and
single-writer on the body; mutation paths are literal command sequences,
not freeform interpretation.

## P6. Single-writer for state-issue body

**Principle:** Only one formula at a time mutates a given state-issue
body. The four formulas that do (`me-sod`, `me-eod`, `me-priority-review`,
`me-weekly-review`) read-then-write with a body-hash check before save.

**Why:** Concurrent writers on structured Markdown fenced regions always
end in tears. A hash check is cheap insurance against the rare case where
a Linear UI edit collided with a formula run.

**Heresy this prevents:** Lost edits from racing writers, silent fence
corruption, journal/body desync.

**Operationalized by:** `pour` skill's single-writer convention; body-hash
check enforced at save time for state-mutating formulas.

## P7. Run-anytime-safe

**Principle:** Formulas survive skipped days, double-runs, runs out of
order, runs after long absence — never error, never silently overwrite.

**Why:** Real-world execution patterns will diverge from the happy path.
Idempotency theatre breaks the first time you skip a Friday. The cost of
designing for resilience at v0 is far less than retrofitting after the
journal has history.

**Heresy this prevents:** Formulas that look bulletproof on the demo and
break the first time real life intervenes.

**Operationalized by:** `pour` skill's idempotency rules (missing prior,
double-run, long gap, partial state) — degrade to read-only and surface
diff for manual repair when state is malformed.

## P8. Discover, don't embed

**Principle:** Codebase facts come from Read/Grep at use time. AGENTS.md
gives the *map* (directory structure, conventions); code is the source of
truth for code.

**Why:** Embedding code structure in prose docs guarantees rot the moment
files move. Agents are perfectly capable of discovering current state at
use time; pre-baked facts only get in the way.

**Heresy this prevents:** AGENTS.md sections that duplicate file trees and
become subtly wrong over time, misleading every agent that trusts them.

**Operationalized by:** AGENTS.md template structure (map only, no
content duplication); `me-onboard` template enforces the same shape on
generated docs.

## P9. Generic by default for mechanical surfaces

**Principle:** Logic that is purely mechanical — dispatch patterns,
schema validation, idempotency rules, executor semantics, parallel fan-out,
collation envelopes — belongs in `dotai` from line one. Logic that
requires real-world judgment (which sources matter, what counts as done,
what tier a thing is) goes in the overlay first per P3.

**Why:** P3 prevents speculative generality for *judgment-bearing* work.
P9 carves out the inverse: when an operation has no judgment to validate,
keeping it in the overlay just to "earn" graduation is ceremony — it
delays availability for any future overlay and accrues no validation
benefit.

When a formula is on the edge (e.g., `me-gather-inputs` — mechanical
dispatch + judgment-bearing source list), externalize the judgment-bearing
part as config (`[[gather.sources]]` in the overlay) and put the mechanical
part (the dispatch DAG, the collation envelope, the degradation rules) in
`dotai`. The boundary itself is the design.

**Heresy this prevents:** Either pole of the false binary — "build
everything in the overlay then refactor public later" (P3 violation by
abstention) or "build everything generic-first" (P3 violation directly).
The right answer per surface is determined by whether it bears judgment.

**Operationalized by:** Per-formula authoring decision: is this mechanical
or judgment-bearing? Mechanical → `dotai/formulas/library/`. Judgment-
bearing → the overlay's `formulas/library/` until validated. Mixed →
split: mechanical core in `dotai`, judgment-bearing config in the overlay.
