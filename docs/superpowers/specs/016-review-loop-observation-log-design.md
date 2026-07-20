# 016 — review-loop: an observation log

**Status:** Design
**Plugin:** `review-loop`
**Extends:** [014](014-review-loop-reviewer-roster-design.md)
**Source:** [caasi/dong3#56](https://github.com/caasi/dong3/issues/56). Two earlier proposals on that issue — a rounds-to-convergence metric and a `P(clean)` posterior — are withdrawn; the evidence is in the comments there.
**Target version:** `review-loop` 0.6.0 → 0.7.0

## What this is

A line-oriented log, in the Unix style. One line per event, plain text, readable with `grep`.

It answers two questions later: **which reviewers ran a round and how many findings each raised**,
and **when the author objected**.

Analysis is out of scope. The format is deliberately not a schema, so a later field costs one new
key and no migration.

## Non-goals

- **No score, threshold or probability.** Two earlier drafts computed one; both are withdrawn on #56.
- **No comparison of finding counts across runs or across reviewers.** A count mixes artifact
  difficulty, roster composition, deduplication strictness and author scope decisions. The keys
  below make such a comparison easy to attempt and it remains invalid; see #56 for why.
- **No claim about review quality.** `findings` counts what was raised, not whether it was right.
- **Nothing is displayed to the author.** Showing a number would change what the author attends to,
  and the objections are the data.

## Format

    <UTC timestamp, ISO-8601, trailing Z>  <event>  <key>=<value> ...

Timestamps are UTC so that lines from two hosts sort correctly. Values contain no whitespace, no
`=`, and no path separator.

Two events.

    2026-07-20T13:47:52Z  review  run=x7k2p9  round=1  reviewers=opus-4-8:19,sonnet-5:9,gpt-5.5:5
    2026-07-20T14:31:02Z  object  run=x7k2p9  tier=redo

**`review`** — one line per round. A *run* is one `/review-loop` invocation from start to stop,
called an *episode* in § A3 of the skill; a *round* is one dispatch-review-fix iteration inside it.

- `run` is a random token, lowercase alphanumeric, generated once per run. It must not be a pull
  request number or a branch slug: this log is global, so both collide across repositories, and a
  branch slug can contain a path separator.
- `reviewers` pairs each reviewer that returned a review this round with the count it raised. A
  reviewer that dropped out, hit a usage limit or was absent is simply not listed, so no separate
  field is needed. The panel total is the sum.
- Each key is the **model id the reviewer reported**, not its roster nickname. § Exit conditions
  requires the verdict to report what actually ran, verified; a nickname stops identifying weights
  within a year.
- `end` appears on the last round of a run: `end=converged`, `end=stopped` (the author ended it), or
  `end=limit` (a reviewer's usage limit ended it). Without it, a run is unfinished. Convergence is
  the reviewers' own verdict per § A3 and is never inferred from a zero count.

**`object`** — one line each time the author objects.

- `tier` is `redo` (the whole output is unusable), `again` (this was already corrected once), or
  `fix` (one specific error). If a message carries more than one token, the order `redo` > `again` >
  `fix` decides which is written.
- `run` is present when the objection falls inside a review-loop run, absent otherwise.

Unknown keys are ignored by any reader. Keys may be added later without changing what is already
written.

## How a line gets written

Both events are written by the agent, through one script.

    scripts/log.sh review run=x7k2p9 round=1 reviewers=opus-4-8:19,sonnet-5:9
    scripts/log.sh object run=x7k2p9 tier=fix

The script stamps the timestamp, refuses to write outside its fixed path, and creates the file with
mode 0600. It never fails loudly: when it cannot write, it writes nothing and exits 0, so a logging
problem never interrupts the author.

The author marks an objection with a token in a message they were already sending:

    #redo   #again   #fix

`#` is used because `!` already runs a shell command in this harness. A token inside a fenced code
block or an inline code span is quoted text, not a mark — a message discussing this spec must not
produce lines.

**Off switch:** `REVIEW_LOOP_LOG=0`.

### The known weakness, and how to measure it

An earlier draft captured objections with a `UserPromptSubmit` hook. That is dropped. The hook's
only advantage was immunity from the agent forgetting to write, and it carried real costs: a
non-zero exit erases the message the author is typing, stdout is injected into the prompt context,
and its central rule depended on `agent_type` being present in a subagent — which the documentation
never states for that event, so the rule may have been inert.

What remains is one real defect. **The agent writes the lines, and a degraded agent is the one most
likely to omit them**, so lines go missing exactly when they matter most. That is directional, not
random.

It is also measurable, cheaply, without new machinery. Session transcripts sit under
`~/.claude/projects/` for about thirty days. Within that window:

    grep -l '#redo\|#again\|#fix' ~/.claude/projects/*/*.jsonl

Every session in that list should have `object` lines with matching timestamps. The difference is
the omission rate. Run it occasionally. **If omission turns out to be high, or correlated with
anything else in the log, the hook becomes worth its cost — and the format does not change when it
is added.**

## Where it goes

`~/.claude/review-loop.log`, beside the existing `~/.claude/review-loop.local.md`. Mode 0600.

Never `${CLAUDE_PLUGIN_ROOT}`, which the marketplace replaces on update. Never inside a repository
under review — § Learning capture in the skill already appends a narrative journal there, per round
and per repository; this log is separate and global.

The path is a fixed constant, so it cannot land inside a repository under review unless the home
directory is one. If the resolved path is inside a git work tree, the script writes nothing. A
dotfiles repository that owns `~/.claude/` is the realistic case.

One `write()` per line under `O_APPEND`, so two loops in two worktrees interleave lines but never
split one.

## What is not recorded, and why

- **No message text, paths, diffs or finding text.** A line carries counts and identifiers.
- **No derived measurement** — diff size, file counts, effect profile. All are recomputable from git
  later, and the tools that derive them still change. `fxrank` is the case in point: it has open P1
  defects (#74, #76, #53, #52), so a reading stored today would be wrong in a way no later version
  could repair.

Everything else the loop knows — per-reviewer verdicts, tier classifications, the `K` signal, Codex
sandbox routing — is stated in the loop's own output and is in the session transcript. Those
transcripts prune at about thirty days, so anything not on a line above is lost after that. That is
accepted: deciding what to keep past thirty days is an analysis decision, and analysis is deferred.

**`findings` counts what was raised, not whether it was right.** A round that raised ten findings,
two of them wrong, logs the same numbers as a round that raised ten sound ones. During the review of
this spec, one reviewer filed a finding claiming a verification it had not received, then corrected
itself two rounds later; the log would show neither the claim nor the correction. Judging review
quality needs the transcript, within its thirty days.

## The one thing worth watching

A log that receives no `object` lines gives no benefit, and should be removed rather than left
running.

That is a judgement for the author, not a rule for a script. Objections are written when the model
fails, so a quiet period may mean a good period rather than an abandoned habit, and no automatic
test separates those. The omission check above is what distinguishes a quiet period from a broken
writer.

## An example, and what it is evidence of

Lines from one working day, reconstructed from the session that produced this spec:

    2026-07-20T11:08:19Z  object  tier=redo
    2026-07-20T12:30:06Z  object  tier=redo
    2026-07-20T13:47:52Z  review  run=x7k2p9  round=1  reviewers=opus-4-8:19,sonnet-5:9,gpt-5.5:5
    2026-07-20T14:05:13Z  object  run=x7k2p9  tier=fix
    2026-07-20T14:52:31Z  review  run=x7k2p9  round=2  reviewers=opus-4-8:17,sonnet-5:7,gpt-5.5:1
    2026-07-20T16:58:03Z  object  run=x7k2p9  tier=again  end=stopped

In that session, eight of ten objections came before the first review round, during design rather
than during review. **That is one session, so it is an observation and not yet a reason.** It is the
weak evidence behind logging objections outside a run at all; if a second session splits evenly, the
choice should be revisited. Sibling spec 014 grades its own comparable evidence the same way.

The session also ran the direction guard in every round, which § Reviewer roster does not permit —
it is held back and one-shot. That is a misuse of the skill, not of the format, and it is the kind
of thing these lines would make visible.

## Testing

- `log.sh review …` and `log.sh object …` each append one line in the stated format, with a UTC
  timestamp the caller did not supply.
- The script writes nothing and exits 0 when the resolved path is inside a git work tree.
- The script exits 0 on every failure path, and writes nothing to stdout.
- With `REVIEW_LOOP_LOG=0`, the script writes nothing.
- A new file has mode 0600.
- Two writers appending 1000 lines each produce 2000 whole lines.
- A value containing a space, an `=` or a path separator is rejected, and the script writes nothing
  rather than a malformed line.
- A round where a reviewer drops out lists only the reviewers that returned a review.

## Acceptance criteria

- [ ] `log.sh` appends both event kinds in the stated format.
- [ ] The script never exits non-zero and never writes to stdout.
- [ ] The script refuses inside a git work tree, and refuses malformed values.
- [ ] The log file is created with mode 0600.
- [ ] Concurrent appends never split a line.
- [ ] The loop writes one `review` line per round, with per-reviewer counts and reported model ids.
- [ ] The off switch stops writing.
- [ ] Nothing is displayed to the author.
- [ ] The omission check is documented where the author will find it.
- [ ] All tests above pass.
