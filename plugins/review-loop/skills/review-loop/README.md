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

## How often it stops for you

The loop names its stops before round 1 and holds to them: the author pass at the start,
**one message per round that has a T2/T3 finding** carrying all of them together, and the
hand-off when the gate is clean. So the count is two stops plus one for each such round,
and a round with none does not stop at all. The number of rounds is the reviewers' call,
which is why the loop publishes the arithmetic instead of a single total.

It does not stop in between: whether a round is dry, K, and where the tier boundary falls
are the loop's own judgments. Three cases can add a stop, because the loop cannot continue
by itself — Copilot re-raising a comment that already had a fix, a first-ever Copilot review
that needs one click in the GitHub UI, and a control arm that cannot separate a prompt's
text from its environment. When one fires, the loop names it and re-publishes the shape.

## When a T3 comes back

A T3 finding that raises the same concern as one an earlier round already fixed means the
fix changed the code without settling the question. That round's message then **re-confirms
the direction of the whole change with you** — the earlier finding, the fix commit, what
that fix assumed, and the recurrence — as well as asking for the item's own fix. It is not
an extra stop: that round was going to stop anyway.

How well that holds was measured, and the numbers are in the design record
(`docs/superpowers/specs/019-review-loop-author-checkpoints-design.md`): across ten runs the
loop named the recurrence every time, and asked about the whole change's direction in seven of
them, or eight under a looser reading of one borderline message. The three exception cases above have no runs behind them at all.

## Tiers

- **T1 mechanical** — typos, lint, null checks, doc fixes — auto-fixed.
- **T2 local refactor** — extraction, naming, validation — resolved with you first.
- **T3 architectural** — module moves, API shape, "should this exist" — your call.

T2 and T3 reach you batched by round, not one at a time.

How a finding is settled follows who reads the artifact. A **runtime prompt** — a
`SKILL.md`, an agent-md pointer, a subagent brief — is read by an agent, and its text
is the behaviour, so a claim about that behaviour is settled by **five independent
simulation runs** and never by a string comparison: a `grep` shows the source is the
source, not that an agent who reads it acts. A claim that a string is present is still
settled by a `grep`, because for that claim the check is complete — read the match, since a
substring can match a longer string that means the opposite. **Deterministic
output** — a script, a parser, a schema — keeps test-driven development. For a document
a human reads, findings are about clarity, consistency, structure and factual accuracy.

**A settled finding keeps the command that settled it.** The loop reproduces a finding before
it acts on it. When a command did that, the loop keeps it in a scratch directory outside the
repo. It re-runs every kept command at the start of each round, and before each commit. If a
later round writes the defect back, that kept command fails immediately, and no reviewer round
is spent on it. On executable code the test suite already did this. Prose had no runnable check.

A finding that no command settled keeps nothing. A behaviour claim and a judgement about wording
or design are both in that group, because a `grep` is evidence for a different claim. The loop
keeps the command it ran and never writes a new check afterwards, so there is no moment at which
a cheap `grep` can stand in for the five runs a behaviour claim needs.

How well that holds was measured in simulation runs, against control runs on the same
environment without this rule. The text that ships kept the command in 4 of 5 runs, and no
control run kept it. The full numbers, the models and the known limits are in the design
record — GitHub issue #84, which this change uses in place of a spec.

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

## Round log

The loop writes one line per review round to `~/.claude/review-loop.log`:

```
2026-07-30T05:32:07Z  review  project=<slug>  run=<token>  round=<n>  reviewers=<model>:<count>,...
2026-07-30T05:35:06Z  review  project=<slug>  run=<token>  round=<n>  reviewers=...  end=converged
```

The run's last round carries `end=converged`; if you stop the loop between rounds it writes
`end=stopped` instead, with no `round` and no `reviewers` field.

A `grep` over it answers which models ran, in which project, how often, and when. Nothing
computes and nothing is shown to you during a run.

**It is a record, not a measurement.** Do not read a capability signal into a round count: it
mixes artifact difficulty, the K policy, roster composition and your own decisions, and it falls
when a reviewer drops out mid-run, so a degraded run scores better. The line is also written by
the agent during the loop, so a round it skipped leaves no trace unless the `round` sequence has
a gap. Spec 020 states this where the data is.

**Off switch:** export `REVIEW_LOOP_LOG=0`, or set it under `env` in `settings.json`. To send
the lines elsewhere, set `REVIEW_LOOP_LOG_FILE`.

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
