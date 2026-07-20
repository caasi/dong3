# 016 — review-loop: an observation log

**Status:** Design
**Plugin:** `review-loop`
**Extends:** [014](014-review-loop-reviewer-roster-design.md)
**Source:** [caasi/dong3#56](https://github.com/caasi/dong3/issues/56). Two earlier proposals on that issue — a rounds-to-convergence metric and a `P(clean)` posterior — are withdrawn; the evidence is in the comments there.
**Target version:** `review-loop` 0.6.0 → 0.7.0

## What this is

A line-oriented log, in the Unix style. One line per event, plain text, greppable with no tools.

It answers two questions later: **which models ran a review, how many errors did they find**, and
**when did the author object**.

Analysis is out of scope. No score, no threshold, no probability. The format is deliberately not a
schema, so a later field costs a column and no migration.

## Format

    <ISO-8601 timestamp>  <event>  <key>=<value> ...

Two events.

    2026-07-20T14:22:31Z  review  run=a3f2c1  round=3  models=opus,sonnet,gpt-5.5  findings=5
    2026-07-20T14:31:02Z  object  run=a3f2c1  tier=redo

**`review`** — one line per round, written by the loop.

- `models` lists the reviewers that actually returned a review this round. A reviewer that dropped
  out, hit a usage limit or was absent is simply not in the list, so no separate field is needed.
- `findings` is the count of findings that round, after cross-critique.

**`object`** — one line each time the author objects, written by a prompt hook.

- `tier` is `redo` (the whole output is unusable), `again` (this was already corrected once), or
  `fix` (one specific error).
- `run` is present when the objection falls inside a review-loop run, absent otherwise.

Unknown keys are ignored by any reader. Keys may be added later without changing what is already
written.

## How the author objects

Three tokens, typed in a message the author was already sending:

    #redo   #again   #fix

A `UserPromptSubmit` hook matches them as whitespace-delimited words and appends one line. If a
message carries more than one, the strongest wins.

Three rules keep the data honest, and they are the only mechanism this design needs:

1. **The hook writes nothing when the payload carries `agent_type`.** Reviewer subagents are
   dispatched with model-composed prompts, and § Facilitator discipline requires reviewer text to be
   quoted verbatim, so a reviewer's own text can contain these tokens. Without this rule a machine
   token is recorded as an author objection.
2. **The hook writes nothing to stdout.** A `UserPromptSubmit` hook's stdout is added to the prompt
   context, so any output would enter the session.
3. **A token inside a fenced code block does not count.** A message quoting this spec would
   otherwise produce objections. Inline code spans are not handled; that false positive is accepted.

`#` is used because `!` already runs a shell command in this harness.

**Off switch:** `REVIEW_LOOP_STATS=0` stops both writers.

## Where it goes

`~/.claude/review-loop.log`, beside the existing `~/.claude/review-loop.local.md`. Mode 0600.

Never `${CLAUDE_PLUGIN_ROOT}`, which the marketplace replaces on update. Never inside a repository
under review — § Learning capture already appends a narrative journal there, per round and per repo;
this log is separate and global.

The writer refuses if the resolved path is inside a git work tree.

One `write()` per line under `O_APPEND`, so two loops in two worktrees interleave lines but never
split one.

## Before implementing

Checked against `https://code.claude.com/docs/en/hooks.md`, so rules 1 and 2 rest on the
documentation rather than on recollection:

- `UserPromptSubmit` exists. Its documented stdin fields are `session_id`, `prompt_id`,
  `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`, and optionally `agent_id` and
  `agent_type`. **`agent_type` is documented**, so rule 1 is implementable.
- Its documented control surface is `decision: "block"`, `additionalContext`, and **stdout as
  context**, which is what rule 2 guards against.
- No model id, reasoning effort, fast flag, turn number or context usage is available to the hook,
  and there is no documented way to obtain them. Nothing above needs them.

Two things still to confirm against the installed version, not from memory:

1. **The raw prompt text field.** The documentation lists the envelope above but does not name the
   field carrying the prompt, even though the hook plainly receives it. Rule 3 and the whole
   matching step depend on reading it.
2. **How a script invoked by the loop learns which run it is in**, so `review` and `object` lines can
   share a `run` value. If there is no reliable channel, `object` lines carry no `run` and the two
   event kinds are joined by timestamp only. That is a smaller loss than it sounds: most objections
   in practice fall outside any run.

If the hook does not exist, the fallback is a slash command, at higher friction.

## What is not recorded, and why

- **No message text, paths, diffs or finding text.** A line carries counts and identifiers.
- **No derived measurement** — diff size, file counts, effect profile. All are recomputable from git
  later, and the tools that derive them still change. `fxrank` is the case in point: it has open P1
  defects (#74, #76, #53, #52), so a reading stored today would be wrong in a way no later version
  could repair.
- **No score, weight or probability.**
- **Nothing is displayed to the author.** Showing a number would change what the author attends to,
  and the objections are the data.

Everything else the loop knows — per-reviewer verdicts, tier classifications, the `K` signal, Codex
sandbox routing — is stated in the loop's own output and is in the session transcript. Those
transcripts prune at about thirty days, so anything not on a line above is lost after that. That is
accepted: deciding what to keep past thirty days is an analysis decision, and analysis is deferred.

**`findings` counts what was found, not whether it was right.** A round that produced ten findings,
two of them wrong, logs the same number as a round that produced ten sound ones. This was observed
during the review of this spec: a reviewer filed a finding claiming a verification it had not
received, then corrected itself. The log would show neither the claim nor the correction. Judging
review quality needs the transcript, within its thirty days.

**Most objections fall outside any run.** In the session that produced this spec, eight of ten came
before the first review round, during design. That is why the hook is global rather than tied to a
review-loop run.

## The one thing worth watching

A log nobody feeds is a cost with no return. If, after a few months, review lines exist and object
lines do not, the habit was not adopted and this should be removed rather than left running.

That is a judgement for the author, not a rule for a script. Objections fire when the model fails, so
a quiet period may mean a good period rather than an abandoned habit, and no automatic test can tell
those apart.

## Testing

- Each token produces one line at the right tier; two tokens in one message produce one line at the
  stronger tier; a token in a fenced code block produces none.
- A prompt carrying `agent_type` produces no line.
- The hook writes nothing to stdout on every path, including its error paths.
- With `REVIEW_LOOP_STATS=0`, neither writer writes.
- With the resolved path inside a git work tree, the writer exits non-zero and writes nothing.
- A new file has mode 0600.
- Two writers appending 1000 lines each produce 2000 whole lines.
- A round where a reviewer drops out lists only the reviewers that returned a review.
- No line contains a path separator or more than 64 characters in any value.

## Acceptance criteria

- [ ] The four items under *Before implementing* are answered in writing, before any code.
- [ ] The hook writes `object` lines with no model involvement in detection, and is silent.
- [ ] The loop writes one `review` line per round.
- [ ] The off switch stops both writers.
- [ ] Nothing is displayed to the author.
- [ ] All tests above pass.
