# Description Optimization

The `description` field in SKILL.md frontmatter is the primary mechanism that determines whether an agent invokes a skill. This guide covers how to systematically optimize it for accurate triggering.

## How Skill Triggering Works

Skills appear in the agent's available_skills list with their name + description. The agent decides whether to consult a skill based on that description.

Key insight: agents only consult skills for tasks they can't easily handle on their own. Simple, one-step queries like "read this PDF" may not trigger a skill even if the description matches perfectly, because the agent can handle them directly. Complex, multi-step, or specialized queries reliably trigger skills when the description matches.

This means eval queries should be substantive enough that the agent would actually benefit from consulting a skill.

## Step 1: Generate Trigger Eval Queries

Create 20 eval queries — a mix of should-trigger (8-10) and should-not-trigger (8-10):

```json
[
  {"query": "the user prompt", "should_trigger": true},
  {"query": "another prompt", "should_trigger": false}
]
```

Queries must be realistic — concrete, specific, with detail like file paths, personal context, column names, URLs. Use a mix of lengths. Focus on edge cases rather than clear-cut examples.

**For should-trigger queries:**
- Different phrasings of the same intent — formal, casual, abbreviated
- Cases where the user doesn't name the skill but clearly needs it
- Uncommon use cases and edge cases
- Cases where this skill competes with another but should win

**For should-not-trigger queries:**
- Near-misses that share keywords but actually need something different
- Adjacent domains, ambiguous phrasing
- Cases where a naive keyword match would fire but shouldn't
- Don't make these obviously irrelevant — "Write a fibonacci function" as a negative for a PDF skill tests nothing

## Step 2: Review with User

Present the eval set to the user. They can edit queries, toggle should-trigger, add/remove entries.

If the `assets/eval_review.html` template is available, use it:
1. Replace `__EVAL_DATA_PLACEHOLDER__` with the JSON array (no quotes — it's a JS variable)
2. Replace `__SKILL_NAME_PLACEHOLDER__` with the skill's name
3. Replace `__SKILL_DESCRIPTION_PLACEHOLDER__` with the current description
4. Write to a temp file and open it

## Step 3: Run the Optimization Loop

```bash
python -m scripts.run_loop \
  --eval-set <path-to-trigger-eval.json> \
  --skill-path <path-to-skill> \
  --model <model-id> \
  --max-iterations 5 \
  --verbose
```

Use the model ID from the current session so the triggering test matches what the user actually experiences.

The loop:
1. Splits eval set into 60% train / 40% held-out test
2. Evaluates current description (running each query 3 times for reliability)
3. Proposes improvements based on what failed
4. Re-evaluates on both train and test
5. Iterates up to 5 times
6. Selects best description by **test score** (not train) to avoid overfitting

## Step 4: Apply the Result

Take `best_description` from the JSON output and update the skill's SKILL.md frontmatter. Show the user before/after and report the scores.

## Tips for Writing Triggering Descriptions

- **Be slightly "pushy"** — agents tend to under-trigger, so lean into naming activation contexts explicitly
- **Name the obvious** — "even if the user doesn't mention X by name"
- **Cover both what and when** — "How to do X. Load this when Y, Z, or W."
- **Use action verbs** — "Load this when creating, modifying, or troubleshooting..."
- **Include synonyms** — users say things differently than you expect
