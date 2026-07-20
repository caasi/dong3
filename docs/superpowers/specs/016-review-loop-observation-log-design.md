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
  difficulty, roster composition, deduplication strictness and author scope decisions. The columns
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

**`review`** — one line per round, written by the loop. A *run* is one `/review-loop` invocation
from start to stop, called an *episode* in § A3 of the skill; a *round* is one
dispatch-review-fix iteration inside it.

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

**`object`** — one line each time the author objects, written by a prompt hook.

- `tier` is `redo` (the whole output is unusable), `again` (this was already corrected once), or
  `fix` (one specific error). If a message carries more than one token, the order `redo` > `again` >
  `fix` decides which is written.
- `run` is present only when the hook can learn which run it is inside. See *Before implementing*.

Unknown keys are ignored by any reader. Keys may be added later without changing what is already
written.

## How the author objects

Three tokens, typed in a message the author was already sending:

    #redo   #again   #fix

A `UserPromptSubmit` hook matches them as whitespace-delimited words and appends one line.

Three rules prevent a machine-generated token from being recorded as an author objection, or the
hook from disturbing the session:

1. **The hook writes nothing when the payload carries `agent_type`.** Reviewer subagents run under
   model-composed prompts, and § Facilitator discipline in the skill requires reviewer text to be
   quoted verbatim. A reviewer's own text can therefore carry these tokens. This rule's premise is
   unverified; see *Before implementing*.
2. **The hook writes nothing to stdout, and always exits 0.** A `UserPromptSubmit` hook's stdout is
   added to the prompt context. A non-zero exit shows the author a hook-error notice, and exit code
   2 erases the message the author was typing. So the hook reports no failure through its exit
   status: when it cannot write, it writes nothing and exits 0.
3. **A token inside a fenced code block does not count.** A message quoting this spec would
   otherwise register objections. Inline code spans are not handled; that false positive is accepted.

`#` is used because `!` already runs a shell command in this harness.

**Off switch:** `REVIEW_LOOP_LOG=0` stops both writers.

## Where it goes

`~/.claude/review-loop.log`, beside the existing `~/.claude/review-loop.local.md`. Mode 0600.

Never `${CLAUDE_PLUGIN_ROOT}`, which the marketplace replaces on update. Never inside a repository
under review — § Learning capture in the skill already appends a narrative journal there, per round
and per repository; this log is separate and global.

The path is a fixed constant, so it cannot land inside a repository under review unless the home
directory is one. If the resolved path is inside a git work tree, the writer writes nothing — and,
per rule 2, still exits 0. A dotfiles repository that owns `~/.claude/` is the realistic case.

One `write()` per line under `O_APPEND`, so two loops in two worktrees interleave lines but never
split one.

## Before implementing

Checked against `https://code.claude.com/docs/en/hooks.md`:

- `UserPromptSubmit` exists. Its common input fields are `session_id`, `prompt_id`,
  `transcript_path`, `cwd`, `permission_mode` and `hook_event_name`, and it additionally receives
  **`prompt`**, the text the author submitted. That is what rule 3 reads.
- Its decision-control fields are `decision: "block"` and `reason`. **Stdout is added to the prompt
  context**, which is what rule 2 guards against. A non-zero exit produces a hook-error notice, and
  exit code 2 blocks the prompt and erases it.
- No model id, fast flag, turn number or context usage is available to the hook. Reasoning effort
  **is** available, as the `$CLAUDE_EFFORT` environment variable. Nothing in this design needs any
  of them.

Two things to confirm against the installed version, not from the documentation and not from memory:

1. **Whether `UserPromptSubmit` fires inside a subagent at all, and whether `agent_type` is present
   when it does.** The documentation introduces `agent_id` and `agent_type` as fields added "inside a
   subagent", as a general condition over hook inputs, and does not list them for this event. A
   `Task`-dispatched brief is not a user prompt. If the event never fires there, rule 1 is inert and
   its justification is wrong; if it does fire, the field still needs confirming.
2. **How a script invoked by the loop learns which run it is in**, so `review` and `object` lines can
   share a `run` value. If there is no channel, `object` lines carry no `run` and the two event kinds
   are joined by timestamp alone. That is a smaller loss than it sounds: most objections observed so
   far fall outside any run.

If the hook does not exist, the fallback is a slash command, at higher friction.

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
test separates those.

## An example, and what it is evidence of

`review` and `object` lines from one working day, reconstructed from the session that produced this
spec:

    2026-07-20T11:08:19Z  object  tier=redo
    2026-07-20T12:30:06Z  object  tier=redo
    2026-07-20T13:47:52Z  review  run=x7k2p9  round=1  reviewers=opus-4-8:19,sonnet-5:9,gpt-5.5:5
    2026-07-20T14:05:13Z  object  run=x7k2p9  tier=fix
    2026-07-20T14:52:31Z  review  run=x7k2p9  round=2  reviewers=opus-4-8:17,sonnet-5:7,gpt-5.5:1
    2026-07-20T16:58:03Z  object  run=x7k2p9  tier=again  end=stopped

In that session, eight of ten objections came before the first review round, during design rather
than during review. **That is one session, so it is an observation and not yet a reason.** It is the
weak evidence behind making the hook global rather than attaching it to a run; if a second session
splits evenly, the choice should be revisited. Sibling spec 014 grades its own comparable evidence
the same way.

The session also ran the direction guard in every round, which § Reviewer roster does not permit —
it is held back and one-shot. That is a misuse of the skill, not of the format, and it is the kind
of thing these lines would make visible.

## Testing

- Each token produces one line at the right tier; two tokens in one message produce one line at the
  stronger tier per the stated order; a token in a fenced code block produces none.
- A prompt carrying `agent_type` produces no line.
- The hook writes nothing to stdout and exits 0 on every path, including every failure path.
- With the resolved path inside a git work tree, the hook writes nothing and still exits 0.
- With `REVIEW_LOOP_LOG=0`, neither writer writes.
- A new file has mode 0600.
- Two writers appending 1000 lines each produce 2000 whole lines.
- A round where a reviewer drops out lists only the reviewers that returned a review.
- A reviewer whose reported model id contains a space or an `=` is written with those characters
  removed, and the line still parses into the expected number of fields.
- No line contains a path separator or more than 64 characters in any value.

## Acceptance criteria

- [ ] The two items under *Before implementing* are answered in writing, before any code.
- [ ] The hook writes `object` lines with no model involvement in detection.
- [ ] The hook is silent on stdout and exits 0 on every path.
- [ ] The writer refuses inside a git work tree without a non-zero exit.
- [ ] The log file is created with mode 0600.
- [ ] Concurrent appends never split a line.
- [ ] The loop writes one `review` line per round, with per-reviewer counts and reported model ids.
- [ ] The off switch stops both writers.
- [ ] Nothing is displayed to the author.
- [ ] All tests above pass.
