---
name: rule-of-five
description: >-
  Iterative refinement workflow — one draft pass plus four single-lens
  refinement passes (correctness, clarity, edge cases, excellence) over
  the same artifact, each examining the previous pass's output through
  one focus only. Produces noticeably better code, prose, design docs,
  or RFCs than a single all-at-once review. Load this when the user
  asks for a "self-review", "review passes", "rule of five",
  "refinement", "polish", or to "make this production-ready" / "ship-
  quality" / "make it shine"; also load before finalizing a non-trivial
  module, RFC, or README, when starting a refactor on existing code
  (which counts as the draft), and any time the user wants higher
  quality than a single pass would give. Skip on trivial changes
  (under ~10 lines or obvious one-line fixes) where overhead exceeds
  value.
---

# Rule of Five — Iterative Refinement Review

Language-agnostic refinement: produce a draft, then run four single-lens passes over it. Each pass examines the *output of the previous pass*, so refinement compounds — the agent isn't starting fresh, it's re-reading its own work from a new angle with full context of why decisions were made. Originally Jeffrey Emanuel's empirical finding; codified by Steve Yegge as a formula in [Gastown](https://github.com/gastownhall/gastown).

## Core principle

**Sequential narrowing beats simultaneous optimization.** Four passes through one lens each produce dramatically better results than one pass trying to balance correctness, clarity, robustness, and polish at the same time. The single-lens discipline is what makes the technique work — combining lenses defeats it.

## The five passes

### Pass 0 — Draft (breadth over depth)

> "Initial attempt at: {target}. Don't aim for perfection. Get the shape right. Breadth over depth."

- Cover all functional requirements, even roughly.
- Establish structure, API surface, data flow.
- Leave rough edges, TODOs, suboptimal names — refinement comes next.
- Do not agonize over naming, optimize prematurely, or polish error messages yet.

**Exit criteria:** every requirement is addressed, even if roughly.

### Pass 1 — Correctness (is the logic sound?)

> "First refinement pass. Focus: CORRECTNESS. Fix errors, bugs, mistakes. Is the logic sound?"

- Off-by-one errors, boundary conditions
- Null / empty-collection handling
- Type correctness — do conversions lose data?
- Control flow — every branch reachable, no missing cases?
- Return values — every path returns the right thing?
- Concurrency — race conditions, deadlocks, shared mutation?
- Resource management — files / connections / locks closed?
- Algorithm correctness — does the approach actually solve the problem?

**Language-specific gotchas to scan for:**

| Language | Common correctness traps |
|----------|--------------------------|
| Elixir | Pattern-match exhaustiveness, message-ordering assumptions, GenServer state consistency |
| Go | Ignored error returns, goroutine leaks, defer ordering |
| Python | Mutable default arguments, iterator exhaustion, integer division |
| TypeScript | `null` vs `undefined`, `===` vs `==`, async/await error propagation |
| Rust | Lifetime issues, `unwrap` on `None`/`Err`, integer overflow in release |
| Java | Null references, equals/hashCode contract, swallowed checked exceptions |

**Exit criteria:** no bugs you can identify remain.

### Pass 2 — Clarity (can someone else understand this?)

> "Second refinement pass. Focus: CLARITY. Can someone else understand this? Simplify. Remove jargon."

- **Naming**: do names describe *what* and *why*, not *how*? `validate_issue_status` beats `proc_data`, `pending_dependencies` beats `tmp`.
- **Function size**: split anything that does more than one thing.
- **Comments**: explain *why*; remove anything that just restates the code.
- **Abstraction level**: is each function at a consistent level?
- **Cleverness**: replace clever code with straightforward code where you can.
- **Dead code**: drop commented-out code, unused imports, unreachable branches.
- **Locality**: is code where a reader would expect to find it?

**The 6-month test:** if you came back to this in six months, would you understand it immediately? If not, clarify.

**Exit criteria:** a competent developer unfamiliar with the project can read it without asking questions.

### Pass 3 — Edge cases (what could go wrong?)

> "Third refinement pass. Focus: EDGE CASES. What could go wrong? What's missing? Handle the unusual."

- Empty inputs, boundary values, max/min, single-element collections
- Invalid inputs — wrong types, malformed data, unexpected formats
- Timing — called twice? concurrently? after shutdown?
- Failures — network timeout, disk full, permission denied, downstream dead
- Scale — works for 0 items? 1? 1 million?
- Encoding — Unicode, multi-byte, special characters in paths
- State — wrong order? before init? after close?
- Configuration — missing, empty, invalid

**Error-handling audit:**
- Are errors propagated, not swallowed?
- Do messages have enough context to diagnose?
- Are *expected* failures handled gracefully (no panics)?
- Are *unexpected* failures logged with full context?

**Exit criteria:** you can't think of a scenario that would cause unexpected behavior, data loss, or a confusing error.

### Pass 4 — Excellence (make it shine)

> "Final polish. Focus: EXCELLENCE. This is the last pass. Make it shine. Is this something you'd be proud to ship?"

- **Consistency** with neighboring code's conventions
- **Performance** — obvious inefficiencies, unnecessary allocations, N+1, repeated work
- **API ergonomics** — pleasant to use? discoverable?
- **Test quality** — do tests document behavior? property-based for algorithmic code?
- **Error messages** — actionable; tell the user what to do, not just what went wrong
- **Logging** — enough to debug in prod, not so much it's noisy
- **Commit message** explains *why*, not just *what*
- **PR-reviewer pass** — read the diff as if reviewing it; what would you flag?

**The pride test:** if this code had your name on it permanently — public repo, conference talk, blog post — would you be comfortable? If not, change that.

**Exit criteria:** you'd approve this PR without requesting changes.

## When to use it

| Scenario | Use? | Notes |
|----------|------|-------|
| New module or significant feature | Yes | Full sequence |
| Bug fix under ~20 lines | No | Direct fix; overhead exceeds value |
| Refactoring existing code | Yes | Existing code is the draft — start at Pass 1 |
| Documentation, README, prose | Yes | Clarity and edge cases matter for prose too |
| Reviewing someone else's PR | Passes 1–4 only | Their code is the draft |
| Design docs / RFCs | Yes | Each pass sharpens the design |
| Configuration / infrastructure | Passes 1 + 3 only | Correctness and edge cases dominate |

For large changes (200+ lines), don't run all five passes on everything at once — break into logical units (one module, one API surface) and refine each unit independently. Compounding refinement loses focus when the surface area is too large.

## Running it in an existing session

When you already have context loaded and a draft produced, issue the four refinement prompts sequentially:

```
1. "Now do a refinement pass focused on CORRECTNESS.
    Fix errors, bugs, mistakes. Is the logic sound?"
2. "Now do a refinement pass focused on CLARITY.
    Can someone else understand this? Simplify. Remove jargon."
3. "Now do a refinement pass focused on EDGE CASES.
    What could go wrong? What's missing? Handle the unusual."
4. "Final polish. Focus on EXCELLENCE.
    Make it shine. Is this something you'd be proud to ship?"
```

Each pass examines the *same artifact* through one lens. Resist re-litigating earlier passes' concerns mid-flight — naming nits in the correctness pass, edge cases in the clarity pass. Stay in lens.

## Where it fits

Run after tests and lint pass — Rule of Five is self-review, not debugging. By the time a human reviewer sees the PR, it has been through four focused passes, so the human can spend their attention on architecture and design rather than naming and missed edge cases.

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Combining lenses ("check correctness and clarity at the same time") | Single-lens focus is the entire mechanism — combining defeats it |
| Skipping the draft and trying to write perfect code on attempt one | The draft is what gives refinement passes something meaningful to act on; permission to be rough is what makes the loop work |
| Spending the correctness pass renaming things | Naming is Pass 2 (clarity); stay in the current lens, note nits and revisit later |
| Running Rule of Five before tests pass | This is self-review, not debugging — fix tests first, then refine |
| Applying full sequence to a one-line config change | Overhead exceeds value; the table above lists when to skip |
| Running all five passes on 500 lines at once | Refinement loses focus; split into logical units and refine each |

## Quick reference

```
Pass 0: DRAFT       — Get the shape right. Breadth over depth.
Pass 1: CORRECTNESS — Fix errors, bugs, mistakes. Is the logic sound?
Pass 2: CLARITY     — Can someone else understand this? Simplify.
Pass 3: EDGE CASES  — What could go wrong? What's missing?
Pass 4: EXCELLENCE  — Make it shine. Would you be proud to ship this?

Single-lens per pass. Sequential, not simultaneous. Same artifact each time.
```
