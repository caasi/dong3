# review-loop

An assisted (not autonomous) multi-reviewer convergence loop for changes — code or
design artifacts (specs, plans, docs). It runs local reviewers first and only then
reaches for GitHub Copilot, and it never merges on its own.

## What this is

A Claude Code skill that loops reviewers over a diff until they stop finding
problems, classifying every comment into tiers and pausing for your judgment on the
architectural ones. The local reviewers answer **blind and in parallel** on the same
unfixed diff — none sees another's findings — and the verdict names which ones actually
ran. A second look finds what the first missed even by the same weights; whether a
*different* model family adds more is a bonus, never a gate. The local gate runs first
so that by the time a forge reviewer (Copilot) sees the PR, there is much less to flag.

## Reviewer roster

Two reasons to look twice, and they are not equally certain. **More passes is more thinking**:
a fresh pass finds real defects even by the same weights, on any host — same-family passes are
first-class, not a fallback. **Different model families may catch different holes**: plausible,
adopted, and unmeasured — so heterogeneity is a *bonus, not a gate*. The loop never requires a
cross-family reviewer; it just names which ones ran, as disclosure, never to discount a
same-family pass.

Reviewers carry a **role**, set by `/review-loop:init`:

1. **Routine panel** — runs every review, blind and in parallel: the session's own model (fresh
   context), one or more *other* Claude models, and `codex` (a different family). Several at
   once is normal — Opus + Sonnet + gpt-5.5. A declared endpoint may join but never counts as a
   cross-family voice.
2. **Direction guard** — an expensive model (e.g. Fable) held back from every round, proposed
   under the ordinary `/review-loop` only when the escalation rule fires. No sub-command.

Routine reviewers answer **blind and in parallel** on the same unfixed diff — none sees another's
findings — and fixes land after all have reported. A **forge reviewer** (Phase B) is not one of
them: it appears only once a PR/MR exists. GitHub Copilot is the built-in adapter and needs no
enrollment.

## Requirements

- **Always usable:** the Claude subagent reviewer needs nothing extra; `/review-loop:init` can pin it to a different Claude model.
- **Codex (optional):** the `codex` CLI on `PATH` (tmux optional — opens a
  live-watch pane only when you ask). `jq` is used to read the resume `thread_id` from `codex`'s
  `--json` stream; without it, Codex resume falls back to `--last`.
- **Forge reviewer (optional):** the built-in adapter is GitHub Copilot — an authenticated `gh`
  CLI and `jq`, GitHub PRs only, and **no enrollment needed**. Another forge's reviewer is
  reachable by declaring it and its three commands.

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
- The Copilot path is GitHub-only; on other forges the local reviewer gate (the
  enrolled roster — a Claude subagent, others you enrol, Codex when present) still applies.

## `/review-loop:init` (optional)

Discovers which coding CLIs this host has, works out **how to call each one by actually calling
it**, and records the roster *you* want in `~/.claude/review-loop.local.md` (project override:
`<project-root>/.claude/review-loop.local.md`). Re-run it whenever the host changes; it is
idempotent and preserves your opt-outs.

It never writes a secret: endpoints are stored by name, and their url and `api_key_env` stay in
the `chat-subagent` registry. It never asks for `sudo`, and never changes your host.

**Copilot is one adapter, not the only possible remote reviewer.** Phase B is a forge-reviewer
slot with three operations — request, poll, recognize a clean pass. Copilot ships as the built-in
binding and needs no enrollment. Other forges have review agents; this skill names none and
implements none, because an adapter nobody here can run would poll forever or report a clean pass
that never happened. Declare one, supply its three commands and an unambiguous `clean_when`, and
the loop drives it.
