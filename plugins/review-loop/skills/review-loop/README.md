# review-loop

An assisted (not autonomous) multi-reviewer convergence loop for changes — code or
design artifacts (specs, plans, docs). It runs local reviewers first and only then
reaches for GitHub Copilot, and it never merges on its own.

## What this is

A Claude Code skill that loops reviewers over a diff until they stop finding
problems, classifying every comment into tiers and pausing for your judgment on the
architectural ones. The point of the local-first ordering: Claude and Codex
reviewing **together** catch different classes of issues and tighten the diff before
it ever reaches GitHub, so Copilot has much less to flag and rounds converge faster.

## Reviewer roster (in priority order)

1. **Claude subagent** — always; needs nothing extra.
2. **Codex** (headless `codex exec review`) — when `codex` is on `PATH`; tmux only
   adds an optional live-watch pane.
3. **GitHub Copilot** — only for GitHub PR targets, after the local gate is clean.

## Requirements

- **Always usable:** the Claude subagent reviewer.
- **Codex (optional):** the `codex` CLI on `PATH` (tmux optional — only for a
  live-watch pane).
- **Copilot phase (optional):** an authenticated `gh` CLI and `jq`; GitHub PRs only.

## Tiers

- **T1 mechanical** — typos, lint, null checks, doc fixes — auto-fixed.
- **T2 local refactor** — extraction, naming, validation — resolved with you first.
- **T3 architectural** — module moves, API shape, "should this exist" — your call.

For document targets, findings are about clarity, consistency, structure, and
factual accuracy; the TDD / one-commit-per-item discipline applies only where there
is executable behavior.

## How to use

```text
review this branch with review-loop
```

Or the slash command:

```text
/review-loop              # current branch vs base
/review-loop 1234         # open PR #1234 (adds Copilot)
```

## Non-goals

- Not autonomous — you decide T2/T3 fixes and the final merge.
- Not a squash-merge tool — defaults to a merge commit to preserve history.
- The Copilot path is GitHub-only; on other forges the local Claude + Codex gate
  still applies.
