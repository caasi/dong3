# review-loop

An assisted (not autonomous) adversarial review panel for changes — code or design
artifacts (specs, plans, docs). Local reviewers answer blind on the same unfixed diff,
then attack each other's findings. Only once that gate is clean does it reach for the
forge reviewer (GitHub Copilot is the built-in adapter). It never merges on its own.

## What this is

A Claude Code skill that loops reviewers over a diff until they stop finding
problems, classifying every comment into tiers and pausing for your judgment on the
architectural ones. The point of the local-first ordering: Claude and Codex
reviewing **together** catch different classes of issues and tighten the diff before
it ever reaches GitHub, so Copilot has much less to flag and rounds converge faster.

## Reviewer roster (by heterogeneity)

Decorrelated error modes are the only reason a second reviewer catches what the first
missed, so panelists are ranked by how different they are — not by how good they are.

1. **Tier 1 — a different model family**, actually called: `codex`, another enrolled
   coding CLI, or a user-declared endpoint (always `trust: user-asserted`, and never
   counted as heterogeneous evidence).
2. **Tier 2 — a different Claude model**, pinned by `/review-loop:init`. Same family,
   so agreement here is *weak* evidence and the gate says so.
3. **Fresh-context only** — a Claude subagent on the session's own model. What a
   zero-config host gets. The weakest verdict there is.

Panelists answer **blind and in parallel** on the same unfixed diff, then attack each
other's findings. A **forge reviewer** (Phase B) is not a panelist: it appears only once
a PR/MR exists. GitHub Copilot is the one built-in adapter.

## Requirements

- **Always usable:** the Claude subagent reviewer.
- **Codex (optional):** the `codex` CLI on `PATH` (tmux optional — opens a
  live-watch pane only when you ask). `jq` is used to read the resume `thread_id` from `codex`'s
  `--json` stream; without it, Codex resume falls back to `--last`.
- **Forge reviewer (optional):** the built-in adapter is GitHub Copilot — an authenticated
  `gh` CLI and `jq`, GitHub PRs only, and **no enrollment needed**. Another forge's reviewer
  is reachable by declaring it and its three commands.

## Tiers

- **T1 mechanical** — typos, lint, null checks, doc fixes. Auto-fixed **only through the
  gate**: a local panelist's T1 finding needs `reproduced`, or `survived` an adversary with
  high confidence and a concrete falsification condition. A forge reviewer's T1 comment is
  auto-fixed on its own merits — it never faced a panel.
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
- The **built-in** forge adapter is GitHub-only (it uses `gh` + GitHub GraphQL). Other
  forges are reachable by declaring a reviewer and its three commands; none ships. With
  no forge reviewer available, the local panel is the whole loop.

## `/review-loop:init` (optional)

Discovers which coding CLIs this host has, works out **how to call each one by
actually calling it**, and records the result in `~/.claude/review-loop.local.md`
(project override: `<project-root>/.claude/review-loop.local.md`). Re-run it
whenever the host changes; it is idempotent and preserves your opt-outs.

It never writes a secret: endpoints are stored by name, and their url and
`api_key_env` stay in the `chat-subagent` registry.

**Copilot is one adapter, not the only possible remote reviewer.** Phase B is a
forge-reviewer slot with three operations — request, poll, recognize a clean pass.
GitHub Copilot ships as the built-in binding of those operations. Other forges have
review agents; this skill names none and implements none, because an adapter nobody
here can run would poll forever or report a clean pass that never happened. Declare
one, supply its three commands and an unambiguous `clean_when`, and the loop drives
it. The built-in Copilot adapter needs **no enrollment**: a GitHub PR with an
authenticated `gh` reaches it exactly as before, unless you opt out. With no forge
reviewer **available**, Phase B is skipped and the local panel is the whole loop.
