---
name: linear-pr
description: >-
  End-to-end "Linear issue to PR" loop in one shot: sync the default
  branch, cut a branch named after the Linear issue ID, stage (optionally
  filtered) working-tree changes, commit with a co-author trailer, push,
  and open a PR pre-filled from the repo's PR template plus the Linear
  issue URL. Invoke as `/linear-pr ISSUE-ID [filter]`. Load whenever the
  user wants to ship a Linear-tracked change without running the seven
  manual git/gh/Linear steps by hand — even if they only say "open a PR
  for ABC-123", "ship this for ABC-123", or just paste a Linear ticket ID
  with some changes staged.
---

# linear-pr

Take a Linear issue ID and a working tree of edits and produce a PR. The
skill is opinionated about *order* and *failure handling* because the
manual version is seven steps and the painful failure modes (silent stash,
branch reuse, missing Linear link) all happen when one of those steps gets
skipped or papered over.

## Inputs

| Arg | Required | Default | Meaning |
|---|---|---|---|
| `<ISSUE-ID>` | yes | — | Linear identifier, e.g. `ABC-123` (case-insensitive). Uppercased for commit subject and PR title; lowercased for branch name. |
| `[filter]` | no | all changes | Selects which working-tree changes to commit. Treated as a literal pathspec if it looks like one (`config/`, `*.toml`); otherwise as a semantic description matched against `git status` (e.g. `config`, `auth handler`). Not a commit message — the message comes from Linear. |

## Preflight

1. **Linear MCP present?** If `mcp__linear__get_issue` is not available in the session, print `Linear MCP not available — install/enable the Linear MCP server and retry.` and stop. The Linear URL on the issue is the entire reason this skill is integrated; without it we'd be hardcoding a workspace, which violates AGENTS.md P2.
2. Call `mcp__linear__get_issue` with the ID. Capture `identifier`, `title`, `url`. If the fetch fails, surface the error verbatim and stop — do not guess the title or construct a URL.
3. Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'` (fallback `main`). Don't hardcode `main` or `master`.

## Procedure

1. **Sync default branch.** `git switch <default> && git pull --ff-only origin <default>`. Uncommitted changes are *expected* — they're the whole reason the skill was invoked. Git carries them through both commands and only complains on actual conflict; if it does, stop and surface the error rather than stashing silently. Silent stash is the failure mode that loses people's work.
2. **Create branch.** `git switch -c <issue-id-lowercased>`. If the branch already exists locally or on origin, stop. Reusing a branch silently is how you end up commingling two issues' work.
3. **Stage changes.**
   - No `[filter]` → `git add -A`.
   - With `[filter]` → read `git status --short`, pick the files matching the filter (literal pathspec if it parses as one, otherwise semantic match), `git add` exactly those, and echo the staged list before committing so the user can object.
   - If nothing ends up staged, stop.
4. **Commit.** Subject: `<ISSUE-ID>: <issue title>`. Append the `Co-authored-by` trailer per the `git-co-author` skill — HEREDOC with real newlines, never `\n` inside `-m "..."`.
5. **Push.** `git push -u origin <branch>`.
6. **Find PR template.** First hit wins:
   - `.github/pull_request_template.md`
   - `.github/PULL_REQUEST_TEMPLATE.md`
   - `PULL_REQUEST_TEMPLATE.md` (repo root)
   - `.github/PULL_REQUEST_TEMPLATE/*.md` (first alphabetically)
   - Fallback: [`assets/pull_request_template.md`](assets/pull_request_template.md) bundled with this skill.
7. **Open PR.** `gh pr create --title "<ISSUE-ID>: <issue title>" --body "$(...)"`. Body construction:
   - If the chosen template contains `{{LINEAR_URL}}`, substitute it with the issue URL.
   - Otherwise append a blank line and `Linear: <url>` to the end.

## Worked example

```bash
# /linear-pr ABC-123 config

# (after Linear fetch returns title="Allow per-env config overrides", url=https://linear.app/acme/issue/ABC-123/...)

git switch main && git pull --ff-only origin main
git switch -c abc-123
git add config/ config.example.toml          # filter "config" matched these
git commit -m "$(cat <<'EOF'
ABC-123: Allow per-env config overrides

Co-authored-by: Claude <noreply@anthropic.com>
EOF
)"
git push -u origin abc-123
gh pr create --title "ABC-123: Allow per-env config overrides" --body "$(cat <<'EOF'
## Linear

https://linear.app/acme/issue/ABC-123/allow-per-env-config-overrides

## Summary
...
EOF
)"
```

## Failure modes

Fail fast — don't auto-recover. The recovery cost is much lower than the cost of silently doing the wrong thing.

| Condition | Action | Why |
|---|---|---|
| `mcp__linear__get_issue` not available | Print the install hint and stop | Without Linear we'd hardcode workspace URLs |
| Linear API call fails | Surface error verbatim, stop | Don't guess the title or URL |
| `git switch` / `git pull` reports a real conflict | Surface git's message, stop | Silent stash loses work |
| Target branch already exists (local or origin) | Stop with branch name | Branch reuse commingles issues |
| Nothing staged after filter | Stop | Filter probably matched zero files; user needs to know |
| `gh pr create` fails (e.g. PR exists for branch) | Surface gh's message, stop | Don't try to update an existing PR — different operation |

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| Stashing dirty changes before `git switch` | Hides the changes the user wanted committed; easy to forget the pop |
| Constructing the Linear URL from a workspace constant | Org-specific value baked into a public skill (violates AGENTS.md P2); breaks for any other Linear workspace |
| Reusing an existing branch named `<issue-id>` | Mixes prior work into this commit; confuses PR diff |
| Using `\n` inside `git commit -m "..."` for the trailer | Many shells don't expand it; trailer ends up on subject line and GitHub stops parsing it |
| Auto-substituting the commit message when `[filter]` is empty | `[filter]` is for selecting files, not the message — the message always comes from the Linear title |
| Hardcoding `main` instead of detecting the default branch | Breaks on `master`, `trunk`, or repos with non-conventional defaults |
| Calling `gh pr edit` if PR already exists | "Open PR" is the contract; updating an existing PR is a different intent — escalate, don't silently do the wrong thing |

## Quick reference

```
1. Linear MCP available? → no: stop with install hint
2. Fetch issue (id, title, url)
3. Detect default branch
4. Switch to default, ff-only pull (let dirty tree ride along)
5. git switch -c <id-lowercased>     (stop if branch exists)
6. Stage: filter or git add -A       (stop if nothing staged)
7. Commit: "<ID>: <title>" + Co-authored-by trailer (HEREDOC)
8. git push -u origin <branch>
9. Find PR template (repo → bundled fallback)
10. gh pr create with template body + Linear URL substituted/appended
```
