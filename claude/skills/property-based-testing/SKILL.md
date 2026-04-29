---
name: property-based-testing
description: >-
  How to design property-based tests — pick a property strategy, write
  generators that don't poison the suite, work with shrinking, and
  configure the runner for CI. Covers John Hughes' five canonical
  strategies (validity, postcondition, metamorphic, inductive, model-
  based) and points to per-language recipes for Go (`rapid`), Python
  (`Hypothesis`), Rust (`proptest`), and Elixir (`StreamData`). Load
  this whenever the user mentions PBT, property tests, generators,
  shrinking, invariant testing, metamorphic testing, QuickCheck,
  Hypothesis, proptest, StreamData, or rapid; before adding tests for
  serialization round-trips, parsers, sorting/filtering, encoding,
  validation/normalization, state machines, or any code with
  invariants over arbitrary input; and when an existing PBT suite is
  flaky, slow, or producing confusing counterexamples (often a
  generator problem, not a test problem).
---

# Property-Based Testing — Best Practices

Language-agnostic guidance for writing property tests that actually find bugs. Grounded in John Hughes, *"How to Specify It!"* (Chalmers, 2020), which presents five canonical approaches to specifying properties of pure functions.

## Core principle

**PBT tests *rules*, not *examples*.** An example test says "given X, expect Y." A property test says "for *all* valid inputs, this rule holds." The framework generates hundreds of inputs, checks the rule against each, and on failure *shrinks* the input to a minimal counterexample — usually the fastest path to root cause.

## When to use it

| Scenario | PBT? | Why |
|----------|------|-----|
| Serialization / deserialization | Yes | Round-trip: `decode(encode(x)) == x` |
| Parsers and formatters | Yes | Round-trip + validity |
| Sorting, filtering, set ops | Yes | Easy invariants (ordered, subset, idempotent) |
| Encoding / decoding / compression | Yes | Paired functions with inverse relationships |
| Data validation / normalization | Yes | Idempotency, shape preservation, range invariants |
| State machines / protocol logic | Yes | Model-based testing catches state-dependent bugs |
| Business-rule combinatorics | Yes | Permission matrices, pricing rules, eligibility |
| Pure algorithmic code | Yes | Reference implementation or known properties |
| Simple CRUD with no logic | No | Examples suffice; PBT adds overhead |
| UI rendering | No | Properties hard to express; visual regression is better |
| One-off scripts | No | Investment > value |

If a function has *invariants* — rules that should hold regardless of input — PBT will find bugs example tests miss.

## The five property strategies

Each has different cost, expressiveness, and bug-finding power. Layer multiple strategies on the same function for higher confidence.

### 1. Validity — `is_valid(f(x))`

The output satisfies a validity predicate, regardless of value. Easiest to write. Weak alone — a function returning a constant valid output passes — so combine with other strategies.

Examples: `is_sorted(sort(xs))`, `is_uuid(generate_id())`, `is_lowercase(normalize_email(e))`.

### 2. Postcondition — `postcondition(x, f(x))`

Specific relationships between input and output. Stronger than validity; directly tests the function's contract. Watch out: don't reimplement the function in the postcondition. State *what* should be true, not *how* to compute it.

Examples: insert-then-lookup returns the inserted value; sort preserves elements; filter-by-P leaves only P-satisfying elements.

### 3. Metamorphic — `f(transform(x)) ~ f(x)`

Relate the outputs of two related calls. You don't need to predict the exact output — only how outputs relate when inputs change in known ways. Excellent when computing the expected output is hard.

Examples: `sort(xs ++ [y]) == sort([y] ++ xs)`; `size(filter(p, xs)) <= size(xs)`; broadening a query returns at least the same results.

### 4. Inductive (reference) — `f_optimized(x) == f_reference(x)`

Test against a known-correct (often slow or simple) implementation. Very high bug-finding power when a reference exists. Risk: if the reference is also buggy, you're testing "do they share bugs?"

Examples: hand-optimized sort vs stdlib sort; custom JSON parser vs library parser; fast path vs brute force.

### 5. Model-based — `to_obs(model) == to_obs(real)`

Apply the same operation sequence to the real implementation and a simple model (often a list or map), then check observable agreement. Most powerful for stateful systems; most complex to set up.

Examples: model a DB table as a list of maps; model a cache as a map; model a queue as a list.

## Choosing and layering strategies

| Starting point | Strategy | Effort |
|----------------|----------|--------|
| Want to start somewhere | Validity | Low |
| Paired functions (encode/decode) | Round-trip postcondition | Low |
| Known rules about output | Postconditions | Medium |
| Hard to predict output | Metamorphic | Medium |
| Have a slow correct version | Reference | Medium |
| Stateful system | Model-based | High |

Layering for `sort`: (1) output is sorted, (2) output contains exactly the input elements, (3) `sort(sort(xs)) == sort(xs)`, (4) `my_sort == stdlib_sort`. Each layer catches bugs the others miss.

## Generator design

Generators are the foundation. A property test is only as good as the inputs it generates.

1. **Reflect realistic domains.** Don't generate arbitrary strings for an email field — generate things that look like emails, including unicode, very long local parts, missing `@`.
2. **Include edge cases explicitly.** Boundary values with meaningful probability: empty collections, zero, negatives, max values, single-element lists.
3. **Compose from building blocks.** Build complex generators from simple ones using your library's combinators.
4. **Constrain, don't filter.** Generators that produce valid data directly beat random + reject. Filtering wastes test budget and degrades shrinking.
5. **Keep generators fast.** Slow generators mean fewer cases per second, which means less coverage. No I/O, no expensive computation.
6. **Bound sizes.** Huge inputs slow tests without finding more bugs — bound collections (e.g., 0–50 elements) unless explicitly testing scale.

### Common generator patterns

| Pattern | What to generate |
|---------|------------------|
| Bounded numerics | Integers in a realistic range, not `i64::MIN` to `i64::MAX` |
| Structured strings | Strings matching expected formats (emails, URLs, identifiers) |
| Optional / nullable | `None`/`null` with meaningful probability (~20%) |
| Collections | Empty, single-element, and bounded sizes |
| Enums / variants | All variants, weighted by expected frequency |
| Composite structs | Build from field-level generators, respecting field constraints |
| Dependent fields | When B depends on A, generate A first, derive B |

### Test your generators

A broken generator silently undermines every property that uses it. If `user_gen()` occasionally produces age `-1` or empty names, every property test using it exercises an input space you didn't intend — and not the one you did. The properties may still pass (because the function under test handles bad input gracefully), or fail with confusing counterexamples that waste debugging time.

The fix is one extra property per custom generator:

```
for all x drawn from my_generator: is_valid(x) == true
```

This is the cheapest high-value property you can write — it turns a silent failure mode into a loud, immediate test failure. Write one whenever you build a custom composite generator, anything with dependent fields, anything reused across many test files, and after modifying an existing generator.

## Shrinking

When a property fails, the framework shrinks the failing input toward a minimal counterexample. This is one of PBT's most powerful features.

- **Don't fight the shrinker.** Prefer built-in generators with shrinking support over custom random generation.
- **Preserve invariants while shrinking.** If your generator enforces constraints (e.g., sorted lists), the shrinker must too. Modern libraries (Hypothesis, proptest, rapid) handle this with integrated shrinking.
- **Use the shrunk counterexample.** It's usually the clearest demonstration of the bug. Convert it into a regression example test.
- **Flaky property → more cases or better generators, not fewer.** Intermittent failures are real signal, not noise.

## CI configuration

| Setting | Local dev | CI |
|---------|-----------|----|
| Cases per property | 1000+ | 100–300 |
| Shrink iterations | Unlimited | Bounded (~1000) |
| Regression files | Yes | Yes (committed) |
| Per-property timeout | Generous | Bounded |

- **Seed your tests** for reproducibility; store failing seeds in CI artifacts.
- **Commit regression files** (`proptest-regressions/`, `.hypothesis/examples/`) — otherwise the next CI run won't replay the known-failing case and bugs can silently regress.
- Most bugs surface in the first ~100 cases; the local/CI ratio above reflects that.

## Per-language recipes

Concrete setup, generators, and example tests live in:

- Go (`rapid`) — [references/go-rapid.md](references/go-rapid.md)
- Python (`Hypothesis`) — [references/python-hypothesis.md](references/python-hypothesis.md)
- Rust (`proptest`) — [references/rust-proptest.md](references/rust-proptest.md)
- Elixir (`StreamData`) — [references/elixir-streamdata.md](references/elixir-streamdata.md)

Load the relevant reference once you know the target language; the strategy and generator guidance above is language-independent.

## Common property recipes

| Recipe | Property | Use for |
|--------|----------|---------|
| Round-trip | `decode(encode(x)) == x` | Serialization, compression, encryption, formatting/parsing |
| Idempotency | `f(f(x)) == f(x)` | Normalization, canonicalization, deduplication, cache ops |
| Invariant preservation | `invariant(f(x))` | Sorting (ordered), filtering (subset), validation (schema) |
| Commutativity | `f(x, y) == f(y, x)` | Set operations, math, merge |
| Monotonicity | `x ≤ y → f(x) ≤ f(y)` | Pricing, scoring, ranking |
| Oracle / reference | `f_fast(x) == f_ref(x)` | Optimized reimplementations, algorithm verification |
| Identity / no-op | `f(x, identity) == x` | Merge with empty, add zero, multiply by one, apply empty diff |
| Size relationships | `size(filter(p, x)) ≤ size(x)` | Collection ops, aggregations |

## Anti-patterns

| Anti-pattern | Why it fails | Fix |
|--------------|--------------|-----|
| Reimplementing `f` inside the property | Tests "do two copies of my code agree?", not correctness | Use structural properties, or a *different* known-correct implementation |
| Generate-then-filter aggressively | Wastes test budget; most inputs are discarded; shrinking is poor | Build a generator that produces valid data directly |
| Properties that are always true | Catches no bugs; common when the property is a tautology or guaranteed by types | Ask "what bug would make this fail?" — if you can't name one, the property is too weak |
| Ignoring the shrunk counterexample | The minimal case is the fastest path to root cause | Understand the shrunk case first; convert it to a named regression test |
| Many concerns in one property | When it fails, you don't know which aspect broke; shrinking is degraded | One property per concept; layer focused properties |
| Flaky properties from external state | Non-determinism makes failures unreproducible | Make the function pure or mock externals; PBT is best on pure / deterministic code |
| Regression files in `.gitignore` | The next run won't replay the known-failing case; bugs silently regress | Commit `proptest-regressions/` and `.hypothesis/` |

## PBT vs example-based testing

Complementary, not competing.

| Aspect | Example tests | Property tests |
|--------|---------------|----------------|
| Readability | High — shows intent | Medium — requires understanding generators |
| Coverage | Specific known cases | Broad input space |
| Edge-case discovery | Manual | Automatic via the framework |
| Documentation value | Strong (examples show usage) | Weaker (rules, not usage) |
| Maintenance | One test per case | One property covers many cases |
| Best for | Happy paths, known edges, API docs | Invariants, algorithmic correctness, unknown edges |

When a property test finds a bug, convert the shrunk counterexample into a named example test for regression — keep both.

## Quick reference

```
Strategies (layer them):
  1. VALIDITY      — is_valid(f(x))
  2. POSTCONDITION — postcondition(x, f(x))
  3. METAMORPHIC   — f(transform(x)) relates to f(x)
  4. INDUCTIVE     — f(x) == f_reference(x)
  5. MODEL-BASED   — observable(real) == observable(model)

Generators:
  Constrain, don't filter. Bound sizes. Test the generator itself.

Shrinking:
  Trust it. Preserve invariants. Convert the shrunk case to a regression test.

CI:
  Fewer cases (~200), bounded shrinks, commit regression files.
```

Origin: John Hughes, *"How to Specify It!: A Guide to Writing Properties of Pure Functions"*, Trends in Functional Programming (TFP 2019), Chalmers University of Technology. LNCS vol. 12053, 2020.
