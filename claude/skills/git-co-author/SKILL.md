---
name: git-co-author
description: >-
  Add a Co-authored-by trailer to git commits so the AI agent (or agents)
  that helped write the code get attribution in the commit history. Load
  this any time a commit is being created or amended — `git commit`,
  `git commit -m`, `git commit --amend`, commits dispatched by any
  higher-level commit skill, or commits made via the GitHub MCP /
  `gh api` — even if the user didn't say "co-author". Also load when
  reviewing or fixing existing commit messages that lack attribution,
  or when multiple agents (orchestrator + oracle) contributed to one
  commit and need separate trailers.
---

# Git Co-Author — AI Agent Attribution

Append a `Co-authored-by` trailer to commits the AI helped author. It's a small change to the commit message and a real signal in `git log` / `git blame` for anyone auditing how a change was made.

## Trailer format

```
Co-authored-by: <display-name> <email>
```

Trailers go at the very end of the commit message, in the trailer block, separated from the body by a blank line. Git surfaces them this way; tools like GitHub parse them this way.

```
feat: add user authentication flow

Implement OAuth2 PKCE flow with token refresh and session management.

Co-authored-by: Claude <noreply@anthropic.com>
```

## Agent identity

Use the identity that matches the model that **wrote or edited the code being committed** — not the model that merely answered a question about it.

| Provider | Model family | Display name | Email |
|----------|--------------|--------------|-------|
| Anthropic | Claude (any version) | `Claude` | `noreply@anthropic.com` |
| OpenAI | GPT / o-series / Codex | `ChatGPT` | `noreply@openai.com` |
| Google | Gemini (any version) | `Gemini` | `noreply@google.com` |

Unknown or unlisted provider:
```
Co-authored-by: AI Assistant <noreply@example.com>
```

If multiple agents contributed (e.g., an oracle diagnosed and the orchestrator implemented), include one trailer per agent — order doesn't matter to git.

## Rules and the why behind them

- **Always include a trailer when an AI made the edits being committed.** The point is durable attribution; skipping it for "small" commits is exactly when blame goes wrong later.
- **Pass the trailer in `git commit -m`, not via an interactive editor.** Editors aren't reliably available in agent harnesses, and a HEREDOC-style `-m` keeps formatting under your control.
- **Preserve any existing trailers.** Append yours; don't replace ones the user or another agent already added.
- **Don't add yourself if you didn't actually edit the code being committed.** A commit that only stages files the human wrote shouldn't claim AI co-authorship.
- **Match the model that did the work, not the most powerful model in the session.** A Haiku subagent that wrote the patch is the co-author, not the Opus orchestrator that supervised.

## Commit message shape

Single-agent:

```bash
git commit -m "$(cat <<'EOF'
type: short description

Optional longer body explaining the why.

Co-authored-by: Claude <noreply@anthropic.com>
EOF
)"
```

Multi-agent (oracle + orchestrator):

```bash
git commit -m "$(cat <<'EOF'
fix: resolve race condition in session handler

Root cause identified by the oracle agent; fix implemented by the orchestrator.

Co-authored-by: ChatGPT <noreply@openai.com>
Co-authored-by: Claude <noreply@anthropic.com>
EOF
)"
```

HEREDOC keeps newlines and trailer spacing intact — `-m "..."` with embedded `\n` does not, and that breaks GitHub's trailer parsing.

## Layering with other commit skills

If a separate commit skill is also loaded (one that handles atomic-commit strategy, message style, or conventional-commits formatting), let it own the body and let this skill own the trailer. The two compose: that skill writes the subject and body, this skill appends the `Co-authored-by` line(s) before the commit is dispatched.

If those skills' instructions and this skill's instructions ever conflict on trailer text, the trailer rules here win — they exist specifically to standardize attribution across projects.

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Omitting the trailer on "trivial" commits | Trivial commits are exactly where attribution drift accumulates unnoticed |
| Crediting `Claude Opus 4.6` / `Claude Sonnet 4.7` as the display name | The display name is `Claude`; version is implicit and changes; pinning it in `git log` ages badly |
| Adding the trailer to commits where the AI didn't author the code | Pollutes the signal — the trailer should mean something |
| Using `\n` inside `-m "..."` to embed the trailer | Many shells don't expand it; the trailer ends up on the subject line and GitHub stops parsing it |
| Replacing existing co-author trailers with your own | Loses prior attribution; trailers are additive |
| Adding the orchestrator instead of the subagent that wrote the code | Misattributes work to the model that supervised, not the one that authored |

## Quick reference

```
1. AI edited the code being committed?            → add trailer
2. Trailer goes at the end, after a blank line.
3. Format: Co-authored-by: <Name> <email>
4. Multiple authors → one line each, any order.
5. Use HEREDOC for `-m`, not embedded \n.
6. Display name = provider family, no version.
7. Preserve any existing trailers; append yours.
```
