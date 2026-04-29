---
name: agents-md-authoring
description: >-
  How to write and maintain AGENTS.md files following the open agents.md
  standard. Covers section structure, repo-type adaptation, safety rails,
  and cross-repo coordination. Load this when creating a new AGENTS.md,
  updating a stale one, auditing a repo for agent readiness, writing agent
  instructions, or when the user mentions "AGENTS.md", "agent operating
  model", or making a repo work well for AI coding agents.
---

# AGENTS.md Authoring

Write AGENTS.md files that give AI coding agents the context to work safely and effectively in any repository.

## Core Principle

**AGENTS.md is a README for agents** — a dedicated, predictable place for build steps, test commands, safety rails, and conventions that agents need but would clutter a human README. Every section must help an agent *do work*, not just understand the project.

## When to Write AGENTS.md

| Situation | Action |
|-----------|--------|
| New repository | Create AGENTS.md at root alongside README.md |
| Existing repo without one | Audit the repo, then generate AGENTS.md |
| Monorepo with subprojects | Root AGENTS.md + nested AGENTS.md per package |
| Repo already has CLAUDE.md | AGENTS.md complements it — CLAUDE.md is Claude-specific, AGENTS.md is universal |
| Updating after major changes | Revise affected sections, verify commands still work |

## Authoring Workflow

1. **Read the repo** — README, CI config, Makefile/package.json, existing agent files (CLAUDE.md, .cursor/rules)
2. **Run the commands** — verify build, test, lint, format actually work before documenting them
3. **Identify the dangerous** — what should agents never do? What requires human approval?
4. **Write the AGENTS.md** — follow the section structure below
5. **Validate** — ensure every command listed actually runs successfully

## Section Structure

AGENTS.md is plain Markdown with no required fields. Use these sections based on what the repo needs — skip sections that don't apply.

### Required Sections (Every Repo)

#### 1. Project Overview
One paragraph: what this is, what it does, why it exists. Agents need context to make good decisions.

```markdown
## Project Overview

Render-orchestrator is a Go gRPC service that schedules and tracks 3D
animation render jobs across multiple cloud GPU providers (RunPod,
CoreWeave, Vast.ai) via a vendor-agnostic API.
```

#### 2. Commands
The most critical section. List every command an agent needs, grouped by purpose.

```markdown
## Commands

### Build
make build              # Build server binary + renderctl CLI
make docker-build       # Build Docker image

### Test
make test               # Unit tests (race detector + coverage)
make test-all           # Full pipeline (build + format + lint + test + docker)

### Lint & Format
make format             # ALWAYS run before committing
make lint               # golangci-lint

### Run
make run                # Local server on port 9090
```

Rules for commands:
- Use code blocks with comments explaining each command
- Mark commands that MUST run before committing (format, lint)
- Mark commands that require credentials or special access
- Include single-test patterns (agents iterate on individual tests frequently)

#### 3. Code Conventions
What an agent must follow when writing code in this repo.

```markdown
## Code Conventions

- TypeScript strict mode, single quotes, no semicolons
- Functional components with hooks, no class components
- All Go IPC commands return `Result<T, String>`
- Shell scripts use `set -euo pipefail`
- Conventional commits: `feat:`, `fix:`, `chore:` (lowercase, no period)
```

### Recommended Sections (Most Repos)

#### 4. Architecture
Brief structural map so agents know where things live and how they connect.

```markdown
## Architecture

### Key Directories
- `internal/client/provider/` — Provider implementations (RunPod, CoreWeave, Vast.ai)
- `internal/operation/` — Async operation handling (renders take 30+ min)
- `cmd/server/` — Server entrypoint and wiring
- `e2e/` — End-to-end tests (require running server)

### Request Flow
gRPC Request → JobsServer → provider.Provider interface
→ SDK call → OpStore (async) → render.Operation response
```

#### 5. Testing Instructions
How to run tests, what different test tiers mean, and what agents should verify.

```markdown
## Testing

### Test Tiers
- **Unit (Tier A):** `make test` — secretless, runs in CI, must pass before merge
- **Integration (Tier B):** `make integration` — requires provider API keys
- **E2E:** `make e2e` — requires running server + render-cli

### Running a Single Test
CGO_ENABLED=1 go test -race -run TestFunctionName ./internal/path/...

### What to Test
- Always add/update tests for changed code
- Run `make test-all` before committing
- Fix any test failures before submitting PR
```

#### 6. CI/CD
What runs automatically and what agents should know about the pipeline.

```markdown
## CI/CD

- PRs run: lint + format check + unit tests + Docker build
- Merge to main triggers: production CD pipeline (e.g., ArgoCD)
- Required checks: `build-tools` must pass before merge
```

### Safety-Critical Sections (Sensitive Repos)

#### 7. Safety Rails
What agents must NOT do. Critical for infrastructure, security, and financial repos.

```markdown
## Safety Rails

### Forbidden Actions
- Do NOT modify GPU pool config (`config/gpu_pools.json`) without human review
- Do NOT change security tool configs (eBPF probes, runtime monitors) without approval
- Do NOT run `make deploy` — deployment is human-approved only
- Do NOT commit secrets, credentials, or API keys

### Requires Human Approval
- Changes to scheduler logic (`internal/scheduler/`)
- Changes to CODEOWNERS
- Any modification to provisioning templates affecting security tooling
- Provider API key rotation or credential changes

### Sensitive Paths
- `security/` — runtime monitor integrations (CODEOWNERS enforced)
- `config/provisioning/` — worker image templates (changes affect all rendering nodes)
- `.cloudprovisioner.yml` — cloud resource provisioning
```

#### 8. Credential & Secret Handling

```markdown
## Credentials

- Never hardcode secrets — use environment variables or vault
- SSH keys: ephemeral per-session, never committed
- Provider API keys: stored in CI secrets, never in code
- MFA required for production deploy operations
```

### Optional Sections (When Applicable)

#### 9. Non-Interactive Shell Commands
Essential when the repo runs on systems with interactive aliases.

```markdown
## Non-Interactive Commands

Always use non-interactive flags to prevent agent hangs:
- `cp -f`, `mv -f`, `rm -f` (not bare `cp`, `mv`, `rm`)
- `apt-get -y install` (not bare `apt-get install`)
- `ssh -o BatchMode=yes` (fail instead of password prompt)
```

#### 10. Cross-Repo Coordination
When changes in this repo affect other repos.

```markdown
## Cross-Repo Dependencies

This repo is part of a render pipeline:
asset-prep (input) → scene-validator (validate) → render-orchestrator (provision+run) → result-archiver (publish)

### When Changes Here Affect Other Repos
- Provisioning template changes may require matching probe updates in `infra/runtime-monitors`
- Job descriptor format changes must be coordinated with `infra/scene-validator`
- New worker image variants need corresponding test configs in `infra/scene-validator`
```

#### 11. Task Management Integration

```markdown
## Task Management

This project uses beads (br) for issue tracking:
- `br ready` — find available work
- `br show <id>` — view issue details
- `br claim <id>` — claim work
- `br close <id>` — complete work
```

#### 12. Nested AGENTS.md (Monorepos)
Place additional AGENTS.md files in subpackages. The closest file to the edited code takes precedence.

## Adapting by Repo Type

| Repo Type | Emphasize | De-emphasize |
|-----------|-----------|--------------|
| **Application (Go, Python, etc.)** | Commands, testing, architecture, CI | Safety rails (unless security-critical) |
| **Infrastructure / OS** | Safety rails, credentials, cross-repo deps, forbidden actions | UI conventions |
| **Test Framework** | Test tiers, how to add tests, test conventions, local targets | Architecture depth |
| **Configuration Repo** | Validation commands, schema rules, cross-repo coordination | Build system |
| **Library / SDK** | API conventions, versioning, backward compat, examples | Deployment |
| **Monorepo** | Root + nested structure, package-specific commands | Single-project conventions |

## Relationship to Other Agent Files

| File | Purpose | Scope |
|------|---------|-------|
| **AGENTS.md** | Universal agent instructions (agents.md standard) | All AI agents |
| **CLAUDE.md** | Claude-specific project context | Claude Code only |
| **`.cursor/rules/`** | Cursor-specific rules | Cursor only |
| **`.copilotignore`** | Files Copilot should ignore | GitHub Copilot only |
| **`.ai-code-conventions/`** | Repo-specific code rules | Claude Code only |

When both AGENTS.md and CLAUDE.md exist, AGENTS.md covers universal instructions (commands, safety, architecture). CLAUDE.md can contain Claude-specific context or be migrated into AGENTS.md.

## Quality Checklist

Before considering an AGENTS.md complete:

- [ ] Every command listed has been verified to run
- [ ] Commands section covers: build, test, lint, format (at minimum)
- [ ] Single-test pattern documented (agents iterate on individual tests)
- [ ] Forbidden actions listed for sensitive repos
- [ ] Architecture gives enough structure to navigate the codebase
- [ ] No stale commands or outdated paths
- [ ] File is under 200 lines (move details to docs/ if needed)
- [ ] No secrets, credentials, or internal URLs that shouldn't be exposed

## Anti-Patterns

| Anti-Pattern | Why It Fails |
|-------------|-------------|
| Duplicating the README verbatim | Agents get the same info from README; AGENTS.md should add what README doesn't cover |
| Listing commands without verifying they work | Agents will run broken commands and waste cycles debugging |
| No safety rails on infra repos | Agents may modify boot flows, security configs, or deploy without understanding the blast radius |
| Giant wall of text with no structure | Agents parse structured sections; prose blocks get lost in context |
| Documenting every file in the repo | Focus on key directories and patterns; agents can explore the rest |
| `NEVER DO X` without explaining why | Agents follow motivated reasoning better than arbitrary rules |
| Outdated commands after refactoring | Stale AGENTS.md is worse than no AGENTS.md — agents trust it |

## Quick Reference

```
1. Read the repo first — README, CI, Makefile, existing agent files
2. Verify all commands before documenting them
3. Required: Project Overview, Commands, Code Conventions
4. Recommended: Architecture, Testing, CI/CD
5. Safety-critical repos: Safety Rails, Credentials, Forbidden Actions
6. Monorepos: root + nested AGENTS.md per package
7. Keep under 200 lines — move deep content to docs/
8. Update when commands, structure, or conventions change
```
