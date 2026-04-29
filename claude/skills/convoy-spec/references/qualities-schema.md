# Qualities Schema

Structured metadata that AI judgment outputs conform to. **Transport, not
cognition** — the schema defines what gets measured, not how to decide.

> Vocabulary is generic by design. Where an org uses a different scale
> (e.g., `T0..T3` instead of `critical..low`, `sev1..sev5` instead of the
> impact enum below, `A1/A2/B` instead of the verification-status enum,
> a domain-specific list of security paths), the mapping lives in an
> overlay reference doc (typically
> `<overlay>/docs/convoy-spec-vocabulary-mapping.md`). The *schema shape*
> here is universal; only labels change.

## Tier ordering convention

For ordinal comparisons in this document and downstream:

```
risk_tier:           critical > high > medium > low
blast_radius:        org > system > component > local
reversibility:       irreversible > costly > procedural > instant
security_sensitivity: critical > direct > indirect > none
adversarial_severity: critical > major > minor > clean
cognitive_demand:    frontier > standard > routine
change_risk:         high > medium > low
impact:              sev1 > sev2 > sev3 > sev4 > sev5
```

"≤ medium" means `medium` or `low`. "≥ high" means `high` or `critical`.

## ZFC compliance model

```
Layer 1: GATHER (transport)     Collect diff, design doc, evidence artifacts
Layer 2: AI JUDGES (cognition)  Populate quality values from gathered context
Layer 3: VALIDATE (transport)   Schema check: required qualities present, values in range
Layer 4: POLICY EVALUATES       Deterministic rules consume qualities to route decisions
```

No quality below contains heuristic routing logic. Each has:

- **Enumerated values** — finite, well-defined
- **Source** — `mechanically computed` | `AI-judged` | `human-attested`
- **Consumers** — which gates / formulas / dispatch decisions read it

The decision matrices at the bottom of this file are **policy** — they
consume quality values, they don't produce them.

---

## 1. Spec qualities (set on bead-ready doc + propagated to convoy / tasks)

These feed gates that run between bead-ready synthesis and dispatch.

### 1.1 `risk_tier`

Primary routing signal for all gates.

| Value | Definition | Gate effect |
|-------|-----------|-------------|
| `critical` | Identity / key material / signing infrastructure / custody-adjacent | All gates always human |
| `high` | Security-sensitive: auth, audit, firewall, crypto, compliance | All gates always human |
| `medium` | Infrastructure-impacting: boot chain, networking, storage, kernel, core platform | Conditional on other qualities |
| `low` | Low-impact: documentation, logging, monitoring, non-critical config | Conditional, most can be AI-handled |

- **Source:** AI-judged from spec scope + changed subsystems
- **Consumers:** every dispatch and merge gate

### 1.2 `blast_radius`

How widely the change can affect the system.

| Value | Definition |
|-------|-----------|
| `local` | Single instance / process / test environment / dev box |
| `component` | One subsystem, module, or class of instances |
| `system` | A full service group, environment, or region |
| `org` | Platform-wide, every consumer / dependent / fleet member |

- **Source:** AI-judged from spec scope + target environment
- **Consumers:** spec-approval, merge-approval. `org` → always human regardless of risk tier

### 1.3 `reversibility`

Can the change be rolled back without data loss or extended outage?

| Value | Definition |
|-------|-----------|
| `instant` | Revert commit, re-deploy. No side effects |
| `procedural` | Rollback requires steps but is well-understood |
| `costly` | Rollback requires significant effort, downtime, or manual intervention |
| `irreversible` | Cannot be undone (disk format, key rotation, data migration) |

- **Source:** AI-judged from spec rollback plan + change type
- **Consumers:** spec-approval, merge-approval. `irreversible` or `costly` → always human

### 1.4 `template_coverage`

What percentage of the spec was populated from a known template vs. novel
authorship.

| Value | Definition |
|-------|-----------|
| `full` | ≥90% from template; only variable substitution |
| `high` | 70-89% from template; minor novel sections |
| `partial` | 30-69% from template; significant novel content |
| `novel` | <30% from template; mostly original authorship |

- **Source:** Mechanically computed by comparing spec fields to template defaults
- **Consumers:** spec-authorship gate. `full` + `low` risk → AI can author. `novel` → human writes

### 1.5 `domain_novelty`

Has this type of change been successfully completed before by agents?

| Value | Definition |
|-------|-----------|
| `routine` | ≥5 prior successful completions of same change pattern |
| `familiar` | 1-4 prior completions; pattern is known |
| `novel` | No prior completions; first time for this pattern |

- **Source:** Mechanically computed from bead history (count of similar past beads with successful outcomes)
- **Consumers:** spec-authorship gate. `novel` → human always authors

### 1.6 `cross_repo_coupling`

Does this change require coordinated changes in other repositories?

| Value | Definition |
|-------|-----------|
| `none` | Self-contained in one repo |
| `coupled` | Requires sibling changes (e.g., implementation + tests in different repos) |
| `chain` | Part of a multi-repo propagation chain |

- **Source:** AI-judged from spec scope + changeSets
- **Consumers:** spec-approval, merge-approval. `chain` → always human spec approval; `coupled` → convoy required

### 1.7 `security_sensitivity`

Does this change touch security-relevant subsystems?

| Value | Definition |
|-------|-----------|
| `none` | No security relevance |
| `indirect` | Touches infra that supports security (logging, monitoring) |
| `direct` | Touches security controls (auth, access control, audit, firewalls, identity providers) |
| `critical` | Touches key material, signing infrastructure, identity issuance, custody-equivalent assets |

- **Source:** AI-judged from spec scope + files touched
- **Consumers:** all gates. `critical` → all gates always human + security-team review

### 1.8 `adversarial_severity`

Worst severity from adversarial probe findings.

| Value | Definition |
|-------|-----------|
| `clean` | No findings or informational only |
| `minor` | Minor issues that don't affect correctness |
| `major` | Significant issues that could cause incorrect implementation |
| `critical` | Issues that could cause safety, security, or data loss |

- **Source:** AI-judged by adversarial probes (severity-gate step)
- **Consumers:** fix-loop, spec-approval. `critical` → always human; `clean`/`minor` + `medium`/`low` risk → auto-approve eligible

### 1.9 `cognitive_demand`

How much reasoning capability does this change require for correct
implementation and review? **Orthogonal to `risk_tier`** — a `low` risk
change can be `frontier` (novel algorithm in a low-risk area) and a
`high` risk change can be `routine` (standard security patch).

| Value | Definition | Model tier |
|-------|-----------|-----------|
| `frontier` | Novel architecture, complex multi-system reasoning, subtle invariants | Frontier (top-tier reasoning model) |
| `standard` | Moderate complexity, well-scoped implementation, familiar patterns | Mid-tier model |
| `routine` | Templated, single-file or formulaic changes | Low-tier / fast model |

- **Source:** AI-judged from spec scope, AC complexity, subsystem interactions, domain novelty
- **Consumers:**
  - **Implementer model selection:** `frontier` → frontier model; `routine` → low-tier
  - **Reviewer model selection:** Reviewer ≥ implementer tier
  - **Adversarial probe model:** Different model family at ≥ same tier (independence)
  - **Cost budgeting:** `routine` beads get lower token budgets

### 1.10 `spec_completeness`

Are all required structural fields populated?

| Value | Definition |
|-------|-----------|
| `complete` | All required fields present, all AC have verification + evidence |
| `partial` | Some required fields missing or AC without verification plan |
| `insufficient` | Multiple required sections absent |

- **Source:** Mechanically computed by schema validation
- **Consumers:** spec-approval. `insufficient` → reject before reaching gate; `complete` required for any auto-approve

---

## 2. Holdout qualities (set on convoy / per-bead holdout artifacts)

Only relevant when the convoy includes holdout-gated beads (typically
`critical` / `high` / `medium` risk). Skip the entire section if your
pipeline doesn't use sealed holdouts.

### 2.1 `derivation_method`

How were the holdout criteria derived?

| Value | Definition |
|-------|-----------|
| `systematic` | All criteria from systematic transformation rules (negative_scope, rollback, idempotency, scope_enforcement) |
| `augmented` | Systematic derivation + additional AI-suggested criteria |
| `creative` | AI-generated criteria not from systematic rules |
| `manual` | Human-authored criteria |

- **Source:** Mechanically tagged by the holdout-derive step
- **Consumers:** holdout-acceptance gate. `systematic` + `low` risk → auto-accept eligible

### 2.2 `category_coverage`

| Value | Definition |
|-------|-----------|
| `full` | All 4 categories: negative_scope, rollback, idempotency, scope_enforcement |
| `partial` | 2-3 categories present |
| `minimal` | Only 1 category present |

- **Source:** Mechanically computed by checking holdout criteria categories
- **Consumers:** holdout-acceptance. `full` required for auto-accept

### 2.3 `testability`

| Value | Definition |
|-------|-----------|
| `automated` | All criteria can be checked by scripts/tools with no human observation |
| `semi_automated` | Most criteria scriptable; some require human verification |
| `manual` | Criteria require human judgment to evaluate |

- **Source:** AI-judged from holdout criterion descriptions + verification methods
- **Consumers:** holdout-acceptance. `automated` preferred for higher autonomy levels

### 2.4 `independence`

Was the holdout derived independently from the spec author?

| Value | Definition |
|-------|-----------|
| `independent` | Different model family or human derived holdout |
| `same_model` | Same model family but different session/context |
| `same_session` | Same session that authored the spec |

- **Source:** Mechanically tagged
- **Consumers:** holdout-acceptance. `same_session` → human review always required for `critical`/`high` risk

### 2.5 `seal_status`

| Value | Definition |
|-------|-----------|
| `sealed` | Encrypted (e.g., JWE) + signed (e.g., JWS), content hash pinned in public spec |
| `pinned` | Content hash pinned but not encrypted |
| `open` | Holdout criteria visible to implementer |

- **Source:** Mechanically computed by checking seal artifacts
- **Consumers:** spec-freeze. `sealed` required before spec can freeze

---

## 3. PR / merge qualities (set on the implementation PR for each task)

These feed the merge-approval gate. Most map down from spec qualities.

### 3.1 `change_type`

Industry-standard (ITIL-derived) change-management classification.

| Value | Definition |
|-------|-----------|
| `routine` | Standard, well-understood change |
| `nonroutine` | Unusual change requiring extra scrutiny |
| `emergency` | Break-glass change bypassing normal process |

- **Source:** AI-judged from diff context (or selected by author if process requires)
- **Consumers:** merge-approval. `emergency` → always human + incident ticket required

### 3.2 `change_risk`

PR-level risk derived from the spec's `risk_tier` plus diff-time factors
(scope changes, surprise files, etc.). Distinct from spec `risk_tier` —
the PR can carry more risk than the spec planned for if scope drifted.

| Value | Definition | Default mapping from `risk_tier` |
|-------|-----------|----------------------------------|
| `low` | Minimal chance of negative impact | `low` |
| `medium` | Moderate chance or limited blast radius | `medium` |
| `high` | Significant chance of broad impact | `critical` or `high` |

- **Source:** AI-judged from diff + spec `risk_tier` + spec `blast_radius` + `reversibility`. May escalate above the spec mapping if scope drift is detected.
- **Consumers:** merge-approval. `high` → always human

### 3.3 `impact`

Severity if the change causes a problem.

| Value | Definition |
|-------|-----------|
| `sev5` | No customer / consumer impact, cosmetic or internal |
| `sev4` | Minor impact, workaround available |
| `sev3` | Moderate impact, degraded experience or partial failure |
| `sev2` | Major impact, significant outage |
| `sev1` | Critical: complete outage, data loss, security breach |

Downstream consumers may map this to a project-specific incident scale.

- **Source:** AI-judged from blast radius + affected subsystems
- **Consumers:** merge-approval. `sev1`/`sev2` → always human

### 3.4 `author_type`

| Value | Definition |
|-------|-----------|
| `human` | Human-authored PR |
| `agent_supervised` | Agent-authored, human reviewed spec |
| `agent_autonomous` | Agent-authored, AI-approved spec (conditional gate passed) |

- **Source:** Mechanically tagged from bead metadata + gate decisions
- **Consumers:** merge-approval. `agent_autonomous` + `change_risk = high` → always human

### 3.5 `evidence_completeness`

| Value | Definition |
|-------|-----------|
| `full` | All expected artifacts present |
| `partial` | Some artifacts present but gaps |
| `missing` | No evidence bundle |

- **Source:** Mechanically computed by checking for expected artifacts
- **Consumers:** merge-approval. `full` required for any auto-merge

### 3.6 `spec_conformance`

| Value | Definition |
|-------|-----------|
| `conforming` | All spec AC addressed, no out-of-scope changes |
| `partial` | Some AC addressed, others pending |
| `divergent` | Changes outside spec scope detected |
| `no_spec` | No linked spec (legacy PR or hotfix) |

- **Source:** AI-judged from diff vs. spec AC + scope boundaries
- **Consumers:** merge-approval. `divergent` or `no_spec` → always human

### 3.7 `verification_status`

Which verification lanes have completed.

| Value | Definition |
|-------|-----------|
| `static_complete` | All static checks passed (lint, type-check, unit tests, schema validators) |
| `static_runtime_complete` | Static + runtime smoke / integration tests passed |
| `full_complete` | Static + runtime + privileged / real-infra / production-equivalent verification passed |
| `incomplete` | Not all required lanes completed |

Each project defines what fills each lane (e.g., a firmware project's
"privileged / real-infra" lane is hardware soak; a SaaS project's is
canary in production).

- **Source:** Mechanically computed from CI/verification pipeline results
- **Consumers:** merge-approval. Required lane set determined by `risk_tier` (typically: `low` → `static_complete`; `medium` → `static_runtime_complete`; `high`/`critical` → `full_complete`)

### 3.8 `coupling_status`

| Value | Definition |
|-------|-----------|
| `standalone` | No cross-repo coupling |
| `siblings_ready` | All sibling PRs exist and pass verification |
| `siblings_pending` | Some sibling PRs not yet ready |
| `siblings_missing` | Required sibling PRs don't exist |

- **Source:** Mechanically computed from convoy bead status
- **Consumers:** merge-approval. `siblings_missing` → cannot merge

### 3.9 `review_confidence`

| Value | Definition |
|-------|-----------|
| `high` | Reviewer confident change is correct and complete |
| `medium` | Reviewer mostly confident, minor concerns |
| `low` | Reviewer has significant concerns |
| `conflicting` | Multi-model review produced disagreement |

- **Source:** AI-judged by review agent(s)
- **Consumers:** merge-approval. `low` or `conflicting` → always human

### 3.10 `holdout_result`

| Value | Definition |
|-------|-----------|
| `passed` | All sealed holdout criteria satisfied |
| `partial` | Some holdout criteria satisfied, others not evaluated |
| `failed` | One or more holdout criteria failed |
| `not_evaluated` | Holdout exists but hasn't been run |
| `no_holdout` | No holdout for this spec |

- **Source:** Mechanically computed from holdout evaluation results
- **Consumers:** merge-approval. `failed` → reject; `no_holdout` acceptable for `low` risk

---

## Decision matrices (policy — consumes qualities, doesn't produce them)

### Spec approval

```
AUTO-APPROVE when ALL:
  risk_tier            ∈ {medium, low}
  blast_radius         ∈ {local, component}
  reversibility        ∈ {instant, procedural}
  template_coverage    ∈ {full, high}
  security_sensitivity ∈ {none, indirect}
  adversarial_severity ∈ {clean, minor}
  spec_completeness    == complete

ALWAYS HUMAN when ANY:
  risk_tier            ∈ {critical, high}
  blast_radius         == org
  reversibility        ∈ {costly, irreversible}
  security_sensitivity ∈ {direct, critical}
  adversarial_severity == critical
  spec_completeness    ∈ {partial, insufficient}
```

### Holdout acceptance

```
AUTO-ACCEPT when ALL:
  risk_tier            ∈ {medium, low}
  derivation_method    == systematic
  category_coverage    == full
  testability          == automated
  seal_status          == sealed

ALWAYS HUMAN when ANY:
  risk_tier            ∈ {critical, high}
  derivation_method    ∈ {creative, manual}
  category_coverage    == minimal
  independence         == same_session  AND risk_tier ∈ {critical, high}
```

### Merge approval

```
AUTO-MERGE when ALL:
  change_risk           == low
  impact                ∈ {sev5, sev4}
  evidence_completeness == full
  spec_conformance      == conforming
  verification_status   ≥ required_for_risk_tier
  coupling_status       ∈ {standalone, siblings_ready}
  review_confidence     == high
  holdout_result        ∈ {passed, no_holdout}
  change_type           == routine

ALWAYS HUMAN when ANY:
  change_risk           == high
  impact                ∈ {sev1, sev2}
  evidence_completeness ∈ {partial, missing}
  spec_conformance      ∈ {divergent, no_spec}
  review_confidence     ∈ {low, conflicting}
  holdout_result        == failed
  change_type           == emergency
  author_type           == agent_autonomous AND change_risk == high
```

---

## Quality flow across artifacts

Spec qualities propagate forward through holdout to PR:

```
BEAD-READY / CONVOY              HOLDOUT                   TASK PR
──────────────────────           ───────                   ───────
risk_tier ─────────────────────────────────────────────→ change_risk (mapped)
blast_radius ──────────────────────────────────────────→ impact (mapped)
reversibility ─────────────────────────────────────────→ (informs change_risk)
security_sensitivity ──────────────────────────────────→ (informs impact)
cross_repo_coupling ───────────────────────────────────→ coupling_status
spec_completeness ─────────────────────────────────────→ spec_conformance
adversarial_severity ──→ derivation_method ────────────→ review_confidence
cognitive_demand ──────→ (informs model tier) ─────────→ review_confidence
template_coverage      category_coverage               evidence_completeness
domain_novelty         testability                     verification_status
                       independence                    holdout_result
                       seal_status                     author_type
                                                       change_type
```

Spec qualities set the bar. Holdout qualities ensure evaluation rigor. PR
qualities verify the bar was met.

---

## ZFC compliance summary

| Source type | Qualities | ZFC layer |
|-------------|-----------|-----------|
| **Mechanically computed** | template_coverage, domain_novelty, spec_completeness, category_coverage, seal_status, evidence_completeness, verification_status, coupling_status, holdout_result, independence, author_type | Transport — deterministic computation |
| **AI-judged** | risk_tier, blast_radius, reversibility, security_sensitivity, adversarial_severity, cross_repo_coupling, cognitive_demand, change_type, change_risk, impact, spec_conformance, review_confidence, testability, derivation_method | Cognition — AI populates, schema validates |
| **Policy-evaluated** | All decision matrices above | Policy — deterministic rules consuming quality values |

**No quality contains heuristic routing logic.** Each is either a measurement
(transport) or an AI judgment with schema validation (cognition). Decision
matrices are deterministic policy — they consume quality values, they don't
compute them.
