# Eval Workflow — Testing Skills with Subagents

Detailed workflow for running evaluations on skills. The main SKILL.md covers the general testing philosophy; this reference covers the concrete mechanics.

## Overview

This is one continuous sequence — don't stop partway through.

- Put results in `<skill-name>-workspace/` as a sibling to the skill directory
- Organize by iteration (`iteration-1/`, `iteration-2/`, etc.)
- Within each iteration, each test case gets a directory (`eval-0/`, `eval-1/`, etc.)
- Don't create all directories upfront — create as you go

## Step 1: Spawn All Runs

For each test case, spawn two subagent runs in the same turn — one with the skill, one baseline. Launch everything at once so it finishes around the same time.

**With-skill run:**
```
Execute this task:
- Skill path: <path-to-skill>
- Task: <eval prompt>
- Input files: <eval files if any, or "none">
- Save outputs to: <workspace>/iteration-<N>/eval-<ID>/with_skill/outputs/
```

**Baseline run** (same prompt, depends on context):
- **New skill**: no skill loaded. Save to `without_skill/outputs/`
- **Improving existing skill**: snapshot the old version first (`cp -r <skill-path> <workspace>/skill-snapshot/`), point baseline at snapshot. Save to `old_skill/outputs/`

Write an `eval_metadata.json` for each test case:

```json
{
  "eval_id": 0,
  "eval_name": "descriptive-name-here",
  "prompt": "The user's task prompt",
  "assertions": []
}
```

Give each eval a descriptive name based on what it tests — not just "eval-0".

## Step 2: Draft Assertions While Runs Are In Progress

Don't wait for runs to finish — use the time to draft quantitative assertions.

Good assertions are:
- **Objectively verifiable** — checkable by script or inspection
- **Descriptively named** — readable at a glance in the benchmark viewer
- **Discriminating** — would fail without the skill but pass with it

Subjective skills (writing style, design quality) are better evaluated qualitatively — don't force assertions onto things that need human judgment.

Update `eval_metadata.json` files and `evals/evals.json` with assertions. See [schemas.md](schemas.md) for the full JSON schema.

## Step 3: Capture Timing Data

When each subagent task completes, save timing data immediately to `timing.json`:

```json
{
  "total_tokens": 84852,
  "duration_ms": 23332,
  "total_duration_seconds": 23.3
}
```

This data comes through the task notification and isn't persisted elsewhere — capture it as each notification arrives.

## Step 4: Grade, Aggregate, and Launch Viewer

Once all runs are done:

### 4a. Grade each run

Evaluate assertions against outputs. Save results to `grading.json` in each run directory. The expectations array must use fields `text`, `passed`, and `evidence` — the viewer depends on these exact field names.

For assertions that can be checked programmatically, write and run a script rather than eyeballing it.

See [grader.md](grader.md) for detailed grading instructions.

### 4b. Aggregate into benchmark

```bash
python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name>
```

This produces `benchmark.json` and `benchmark.md` with pass_rate, time, and tokens for each configuration, with mean ± stddev and the delta.

### 4c. Analyst pass

Read the benchmark data and surface patterns the aggregate stats might hide:
- Assertions that always pass regardless of skill (non-discriminating)
- High-variance evals (possibly flaky)
- Time/token tradeoffs

See [analyzer.md](analyzer.md) for what to look for.

### 4d. Launch the viewer

```bash
python scripts/generate_review.py \
  <workspace>/iteration-N \
  --skill-name "my-skill" \
  --benchmark <workspace>/iteration-N/benchmark.json
```

For iteration 2+, add `--previous-workspace <workspace>/iteration-<N-1>`.

For headless/cowork environments, use `--static <output_path>` to write a standalone HTML file instead of starting a server.

### 4e. Tell the user

"I've opened the results in your browser. The 'Outputs' tab shows each test case with feedback boxes. The 'Benchmark' tab shows the quantitative comparison. Come back when you're done reviewing."

## Step 5: Read Feedback

When the user finishes, read `feedback.json`:

```json
{
  "reviews": [
    {"run_id": "eval-0-with_skill", "feedback": "the chart is missing axis labels", "timestamp": "..."},
    {"run_id": "eval-1-with_skill", "feedback": "", "timestamp": "..."}
  ],
  "status": "complete"
}
```

Empty feedback means the user thought it was fine. Focus improvements on test cases with specific complaints.

## Blind Comparison (Advanced)

For rigorous A/B comparison between two skill versions:
1. Give two outputs to an independent agent without revealing which is which
2. Let it judge quality on defined criteria
3. Analyze why the winner won

See [comparator.md](comparator.md) and [analyzer.md](analyzer.md) for details. This is optional — human review is usually sufficient.

## Reference Files

| File | Purpose |
|------|---------|
| [grader.md](grader.md) | How to evaluate assertions against outputs |
| [comparator.md](comparator.md) | How to do blind A/B comparison |
| [analyzer.md](analyzer.md) | How to analyze benchmark results |
| [schemas.md](schemas.md) | JSON structures for evals.json, grading.json, benchmark.json |
