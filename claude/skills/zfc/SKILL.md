---
name: zfc
description: >-
  Apply Zero Framework Cognition (ZFC) when designing or writing AI
  applications, agent loops, tool-use harnesses, or any code that consumes
  LLM output. ZFC keeps the host program a thin, deterministic shell and
  delegates every judgment call to the model. Load this when adding regex
  or keyword matching to parse model output, writing classifiers / routers
  / rankers / scorers / fallback heuristics over text, deciding whether
  an agent task is "done", validating LLM responses beyond structural
  schema checks, or building anything Yegge would call an "AI application"
  — even if the user does not say "ZFC" by name.
---

# Zero Framework Cognition (ZFC)

Build AI applications as a **thin, safe, deterministic shell around AI reasoning**. The program does plumbing; the model does thinking. Based on Steve Yegge's [Zero Framework Cognition](https://steve-yegge.medium.com/zero-framework-cognition-a-way-to-build-resilient-ai-applications-56b090ed3e69).

## Core Principle

**If a step requires judgment about meaning, send it back to the model.** Code that tries to interpret natural language, score alternatives, or classify intent will miss synonyms, languages, edge cases, and tone. The model already does this well — duplicating it in code is where AI apps become brittle.

The shell's job is the boring, verifiable stuff: IO, schemas, budgets, retries, mechanical transforms. Everything cognitive belongs in a prompt.

## The Two Lists

Use these as your decision rule when writing or reviewing AI-app code.

### Shell may do (ZFC-compliant)

| Category | Examples |
|----------|----------|
| IO & plumbing | File reads/writes, network calls, serialization, logging, persistence |
| Structural safety | JSON schema validation, type checks, path-traversal prevention, allowlist of tool names |
| Policy enforcement | Token/$ budgets, rate limits, timeouts, retry counts, max-step caps |
| Mechanical transforms | String interpolation, format conversion, base64, sorting by an explicit numeric field the model returned |
| State management | Conversation history, scratchpad files, message threading |
| Typed error handling | Catching exceptions, surfacing structured failures back to the model |

### Shell must not do (ZFC violation)

| Category | Examples |
|----------|----------|
| Heuristic classification | Routing on keywords, regex over model output, "if response contains 'done'…" |
| Local ranking / scoring | Picking among model candidates by code-side weights or similarity scores |
| Semantic analysis | Sentiment, intent, topic, language detection performed in the host program |
| Quality judgments | "Looks like a good answer" / "test-first recommended" rules in code |
| Fallback decision trees | Hand-written rules that take over when the model is "uncertain" |
| Opinionated validation | Anything beyond structural safety — taste belongs to the model |

## Why Heuristics Fail Here

Yegge's central warning, paraphrased: any pattern matcher, ranker, or fallback rule **will miss edge cases** — synonyms ("ended", "concluded", "finalised"), other languages, paraphrase, sarcasm, formatting drift across model versions. The model already handles all of that. Re-implementing a worse version of it in regex is how AI apps rot.

Concrete tell: if you are about to write `if "done" in response.lower()` or a `SequenceMatcher` ratio threshold or a list of "completion keywords", stop. That is the ZFC line.

## The Correct Pattern

1. **Gather** raw context with IO only — no interpretation.
2. **Ask** the model for the decision, with the relevant context and a strict output schema.
3. **Validate** the response structurally (schema/types only — never "is this a good answer").
4. **Execute** the decision mechanically, exactly as returned.
5. **Loop** back to the model on ambiguity, errors, or low confidence — never fall back to local heuristics.

## Example: "Is this task done?"

**ZFC violation** — pattern matching in the shell:

```python
def is_done(response: str) -> bool:
    keywords = ["done", "complete", "finished", "task accomplished"]
    return any(k in response.lower() for k in keywords)
```

Breaks on: "Wrapped up the migration.", non-English replies, "I'm done investigating but the bug remains", any phrasing the author didn't think of.

**ZFC-compliant** — ask the model with a typed answer:

```python
SCHEMA = {"type": "object",
          "properties": {"status": {"enum": ["done", "in_progress", "blocked"]},
                         "reason": {"type": "string"}},
          "required": ["status", "reason"]}

def classify_status(transcript: str) -> dict:
    raw = call_model(
        system="Decide whether the agent has finished the task. "
               "Return JSON matching the schema.",
        user=transcript,
        response_schema=SCHEMA)
    return validate(raw, SCHEMA)   # structural only
```

The shell only checks the JSON shape. The judgment lives in the model.

## Example: Routing a User Request

**Violation** — keyword router:

```python
if "refund" in msg: return billing_agent(msg)
elif "bug" in msg or "error" in msg: return support_agent(msg)
else: return general_agent(msg)
```

**Compliant** — let the model name the route, the shell only dispatches:

```python
route = call_model(prompt=ROUTE_PROMPT, user=msg,
                   response_schema={"enum": ["billing", "support", "general"]})
return AGENTS[route](msg)   # mechanical lookup
```

## Example: Picking the Best of N Candidates

**Violation** — code-side scoring with cosine similarity, length heuristics, or keyword overlap to rank candidates.

**Compliant** — give all N candidates to the model and ask it to return the index (or the chosen text), validated as an integer in `[0, N)`. The shell indexes mechanically.

## When You Genuinely Need Determinism

Some things really are mechanical and should stay in code: parsing a known JSON envelope you defined, applying a `diff` the model produced, checking a path is inside the workspace, enforcing a token budget. The test is **"does this require understanding what the text means?"** — if yes, model; if no, code.

Numeric comparisons against fields the model explicitly produced (e.g. sort by `confidence` it returned) are fine. The model did the judging; the shell just sorts.

## Cost Discipline Within ZFC

ZFC routes everything through a model, so cost matters. Decompose hierarchically and pick the cheapest model that can do each step:

- Haiku-class for narrow extraction, routing, structural decisions
- Sonnet-class for medium reasoning and multi-step planning
- Opus-class for genuinely hard synthesis

Cost is not a license to fall back to heuristics — it's a reason to pick a smaller model, not no model.

## Reviewing Code for ZFC Compliance

When reviewing or editing AI-app code, scan for these red flags:

- `re.search` / `.match` / regex literals applied to model output or user free text
- `if <keyword> in <text>` over LLM responses or natural language
- Lists named `KEYWORDS`, `STOP_WORDS`, `COMPLETION_PHRASES`, `INTENT_PATTERNS`
- Similarity / distance functions (`cosine`, `levenshtein`, `SequenceMatcher`) used to make a decision rather than as a tool offered to the model
- `else:` branches that take over when "the model didn't give a clear answer"
- Hand-tuned thresholds (`if score > 0.7`) where the score itself came from a heuristic
- `try: parse(...) except: <guess>` — guessing on parse failure instead of re-prompting

Each of these is a place to ask: *can this be a prompt instead?*

## Anti-Patterns

| Anti-Pattern | Why It Fails |
|--------------|--------------|
| Regex-parsing LLM output to detect intent | Misses synonyms, languages, paraphrase; breaks on model upgrades |
| Code-side ranker over model candidates | Reintroduces the bias the model was meant to remove |
| Fallback decision tree "for when the model is unsure" | Replaces a smart decider with a worse one at the worst moment |
| Sentiment/quality scoring in the shell | "Good answer" is a judgment — that's the model's job |
| Schema validation that also enforces taste ("response must mention tests") | Mixes structural safety with cognition; move taste into the prompt |
| Caching by exact-string match of free-form prompts | Equivalent prompts miss the cache; let the model or a semantic cache decide |
| Building a mini-NLP layer "just for this one case" | The one case becomes ten; the layer becomes the framework ZFC forbids |

## Quick Reference

```
1. Plumbing in code, judgment in the model.
2. Validate shape, never taste.
3. On ambiguity: re-prompt, don't fall back.
4. No regex / keyword / similarity / threshold over natural language.
5. Mechanical sorts on model-supplied numbers are fine.
6. Cheapest model that can do the job — but always a model.
```
