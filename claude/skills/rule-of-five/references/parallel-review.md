# Parallel review — variants of single-lens narrowing

Rule-of-five (sequential-compounding) is one shape of a more general principle: **partition critique by single lens, then converge**. Two other shapes share that principle but trade off context for independence in different ways. This reference names the three variants and gives a choose-which rubric for picking between them.

The canonical sequential-compounding implementation is in [`../SKILL.md`](../SKILL.md). This reference covers the parallel and iterative-convergence variants and when each earns its cost.

## The shared bones

All three variants enforce the same discipline. Skipping any of these is what makes a multi-stage review degenerate into ceremony:

1. **Single-lens per leg/pass** — never combine lenses inside a unit of work; combining is what defeats the technique
2. **Explicit synthesis step** — never trust the implicit average of independent legs; name a consolidation step
3. **Severity classification** — critical/major/minor (or pass/fail/error/skip) gates whether to proceed, re-probe, or escalate
4. **Convergence ceiling** — hard cap on iteration count; escalate to human at the cap rather than looping
5. **Skip preambles** — short-circuit when the artifact already exists or risk metadata says "not applicable"
6. **Artifact-grounded handoff** — every leg writes to a known path; synthesis reads those paths, not in-context summaries

What varies between the three: how the legs are sequenced, whether they iterate, and how lenses are chosen.

## The three variants

### Variant A: Sequential-compounding (the canonical rule-of-five)

| Aspect | Shape |
|---|---|
| Sequencing | One draft + N sequential single-lens passes |
| Iteration | One-shot per pass |
| Lens choice | Universal (correctness, clarity, edge cases, excellence) |
| Each pass's input | Output of the previous pass |
| Buys you | **Compounding context** — pass N knows what passes 1..N-1 did |
| Costs you | **Shared framing** — later passes inherit earlier passes' assumptions |

See [`../SKILL.md`](../SKILL.md) for the prompts, lens definitions, and run-in-session instructions.

**When this is the right shape**: code review, prose refinement, design-doc polish — anywhere a single author is iteratively narrowing a single artifact and shared context across passes is a feature.

### Variant B: Parallel fan-out + synthesis

| Aspect | Shape |
|---|---|
| Sequencing | N independent single-lens legs run in parallel |
| Iteration | One-shot per leg |
| Lens choice | Domain-specific (taxonomy chosen for the artifact type) |
| Each leg's input | The same shared artifact, no inter-leg context |
| Buys you | **Independence** — no leg is anchored by another's framing |
| Costs you | **No compounding** — each leg starts fresh; can't build on prior insight |
| Required step | **Synthesis** — explicit consolidation that dedups, ranks, and resolves contradictions across legs |

**When this is the right shape**: PRD review, design exploration, adversarial probing — anywhere shared blind spots are the dominant risk and you want lenses that *don't see each other's outputs*. Parallel legs are how you avoid the "everyone agrees because they're all reading the same prior summary" failure mode.

**Worked examples in [gastown](https://github.com/gastownhall/gastown/tree/main/internal/formula/formulas)**:

- `mol-idea-to-beads.toml` Phase 2 (PRD review): 6 lenses — requirements, gaps, ambiguity, feasibility, scope, stakeholders
- `mol-idea-to-beads.toml` Phase 4 (design exploration): 6 lenses — api, data, ux, scale, security, integration
- `mol-refinery-verify.toml` L6 (advisory review): 5 lenses with **cross-model independence** (different model family per leg)

**The independence dial**: stronger fan-out runs each leg under a different model family or different agent, so framing biases don't propagate. Weakest fan-out is parallel calls to the same model — still better than serial-with-shared-context, but the independence ceiling is lower. If the legs are about catching *training-data-shared* blind spots, cross-family is the only thing that helps.

### Variant C: Iterative-convergence with severity gate

| Aspect | Shape |
|---|---|
| Sequencing | Parallel fan-out + synthesis, repeated |
| Iteration | Loop until convergence OR N-round ceiling |
| Lens choice | Domain-specific |
| Each round's input | Updated artifact from previous round's synthesis |
| Buys you | **Verification that the fix didn't break something else** |
| Costs you | **Round-budget overhead** — each round runs the full fan-out |
| Required gates | **Severity classification** (which findings block) + **convergence ceiling** (hard round cap) |

**When this is the right shape**: the artifact mutates between rounds (e.g., design doc edits in response to reviewer findings), and you need to verify mutation didn't introduce new issues. Without the iteration, parallel fan-out is one-shot — you ship whatever the synthesis produces. With iteration, you can demand convergence.

**Worked examples in gastown**:

- `mol-idea-to-beads.toml` Phase 5 (PRD alignment): 6 lenses × 2 legs each, 3-round ceiling
- `mol-idea-to-beads.toml` Phase 6 (plan self-review): same shape as Phase 5
- `mol-adversarial-review.toml` (= Phase 7): 5 probes with severity gate + 4-round convergence ceiling

**The convergence-ceiling rule**: pick the cap *before* you start. Adversarial typically caps at 4 rounds because by round 5 you're either escalating to human judgment or you've identified a fundamental issue the reviewer loop can't fix. Infinite loops here are how reviews quietly consume entire days. The cap is the artifact, not a suggestion.

## How to choose

Walk this in order:

1. **Is the artifact mutating between rounds?**
   - Yes → **Variant C** (iterative-convergence). The whole point of the loop is to verify mutations.
   - No → continue.

2. **Are shared blind spots the dominant risk?**
   - Yes → **Variant B** (parallel fan-out). Independence is what you're paying for.
   - No → continue.

3. **Does compounding context across lenses help?**
   - Yes → **Variant A** (sequential-compounding, the canonical rule-of-five).
   - No → consider whether you need *any* multi-pass review, or whether a single careful pass is enough.

### Independence vs. compounding tradeoff

The fundamental tension. Sequential-compounding lets pass 3 say "I see pass 2 already addressed X, so I'll focus on Y" — that's accumulated context, and it's how passes build on each other. Parallel fan-out denies that on purpose: if leg 5's view of "scope" was anchored by leg 1's framing of "requirements," fan-out's whole independence guarantee collapses.

Pick by asking: **what's the failure mode I'm most worried about?**

- "I'll miss bugs by trying to think about everything at once" → sequential-compounding wins
- "I'll get the same blind spot from every reviewer because they're all reading the same context" → parallel fan-out wins
- "I'll fix the surface issue and create a new one underneath" → iterative-convergence wins

### Universal vs. domain-specific lens choice

Sequential-compounding uses a *universal* lens taxonomy (correctness, clarity, edge cases, excellence) because the artifacts vary but the failure modes generalize. Parallel fan-out and iterative-convergence use *domain-specific* taxonomies because the lens names ARE the taxonomy of failure modes for that artifact — a PRD has different failure modes than a design doc has different failure modes than a deploy plan.

Heuristic: if the artifact type is varied (any code, any prose), use a universal taxonomy. If the artifact type is fixed (always a PRD, always a deploy plan), invest in a domain-specific taxonomy — it earns its cost on the second instance.

### When to fall back to a single pass

Multi-stage review is overhead. Skip it when:

- The change is small enough that a single careful read catches what matters (the SKILL.md "Skip on trivial changes" rule)
- The artifact is throwaway (one-off script, exploratory notebook)
- You're under time pressure that makes the round-budget unacceptable AND the failure mode of "I missed something" is reversible (small commit, easy rollback)

A single careful pass is *not* worse than a sloppy multi-pass review. Discipline matters more than ceremony.

## Anti-patterns specific to fan-out and convergence

The SKILL.md anti-patterns table covers sequential-compounding traps. These are the additional ones for Variants B and C:

| Anti-pattern | Why it fails |
|---|---|
| Parallel legs that share intermediate context | Defeats the independence guarantee — you've built a sequential review with extra steps |
| Skipping the synthesis step | The "implicit average" of N legs is whatever leg 1 said most loudly; you need an explicit consolidation pass |
| Convergence loop with no hard ceiling | The loop never ends on hard problems; ceilings force escalation when the loop can't finish |
| Severity classification with no gate behavior | Classifying findings as "critical" without using the classification to block is just labeling |
| Same-model fan-out treated as cross-model independence | Same-model legs share training-data biases; fan-out across families is what buys real independence |
| Domain-specific lenses chosen by the agent doing the review | The taxonomy IS the prior; let the artifact author or skill define it, not the reviewer mid-flight |
| Reusing one round's synthesis as the next round's prompt context | Now round N+1's legs are anchored by round N's framing — you've collapsed iterative-convergence into sequential-compounding with extra cost |

## Sibling pattern (NOT a rule-of-five variant)

`mol-refinery-verify.toml` L1–L5 is **layered depth gates** keyed off risk metadata, not a multi-lens review. L1 (static) → L2 (runtime) → L3 (property) → L4 (mutation) → L5 (holdout) escalate verification cost based on `risk_tier` / `blast_radius`, with later layers conditional on metadata. This is **cost-tiered verification**, a sibling pattern — it shares "single-lens per layer" with rule-of-five but the dispatch logic is fundamentally different (escalating cost gates, not lens partitioning).

If this pattern needs written-down meta-guidance later, give it its own skill (`tiered-verification`?). One example is not yet a pattern; defer until a second instance shows up.
