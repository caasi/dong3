# 016 — review-loop: an observation log

**Status:** Design
**Plugin:** `review-loop`
**Extends:** [014](014-review-loop-reviewer-roster-design.md)
**Source:** [caasi/dong3#56](https://github.com/caasi/dong3/issues/56). Two earlier proposals on that issue — a rounds-to-convergence metric and a `P(clean)` posterior — are withdrawn; the evidence is in the comments there.
**Target version:** `review-loop` 0.6.0 → 0.7.0

Unqualified `§` references point to `plugins/review-loop/skills/review-loop/SKILL.md`.

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
- **No claim about review quality.** A count says what was raised, not whether it was right.
- **No computed score or summary is shown to the author.** Objection lines are written by a hook and
  are invisible. Round lines are written by a script the loop calls, so that invocation appears in
  the terminal like any other command — it shows the same counts the round output already reports,
  and nothing derived from them.

## Format

    <UTC timestamp, ISO-8601, trailing Z>  <event>  <key>=<value> ...

Fields are separated by two spaces. Timestamps are UTC so that lines from two hosts sort correctly.
A value contains no whitespace, no `=`, and no path separator; a writer that is handed one drops
those characters rather than writing a malformed line. Key order is as shown below.

Two events.

    2026-07-20T13:47:52Z  review  session=d51240  run=x7k2p9  round=1  reviewers=claude-opus-4-8:19,claude-sonnet-5:9,gpt-5.5:5
    2026-07-20T14:31:02Z  object  session=d51240  run=x7k2p9  tier=redo

`session` is the harness session id, on every line. It is what joins the two event kinds, and it is
what makes the omission check below exact rather than approximate.

**`review`** — one line per round, written by the loop. A *run* is one `/review-loop` invocation
from start to stop, called an *episode* in § A3; a *round* is one dispatch-review-fix iteration
inside it.

- `run` is 8 lowercase alphanumeric characters from a random source, generated once per run. It must
  not be a pull request number or a branch slug: this log is global, so both collide across
  repositories, and a branch slug can contain a path separator.
- `round` is a positive integer, starting at 1, increasing by one per round within a run.
- `reviewers` pairs each reviewer that returned a review this round with the count it raised. A
  reviewer that dropped out, hit a usage limit or was absent is simply not listed, so no separate
  field is needed. The panel total is the sum.
- **The count is of findings the reviewer returned, before cross-critique and before tiering.** § A1
  makes cross-critique optional and § Tiers puts classification after it, so a post-processing count
  would be undefined on rounds where neither ran.
- Each key is the **model id the reviewer reported**, not its roster nickname. § Exit conditions
  requires the verdict to report what actually ran, verified; a nickname stops identifying weights
  within a year. Inside this value `,` and `:` are structural, so a reported id containing either has
  it removed.
- `end` appears on the last `review` line of a run: `end=converged` or `end=stopped` (the author
  ended it). There is no usage-limit value: § Exit conditions is explicit that a usage limit stops
  only the Codex sub-loop, and § A3 counts an unavailable reviewer as done, so a limit never ends a
  run. Without `end`, a run is unfinished. Convergence is the reviewers' own verdict per § A3 and is
  never inferred from a zero count.

**`object`** — one line each time the author objects, written by the hook.

- `tier` is `redo` (the whole output is unusable), `again` (this was already corrected once), or
  `fix` (one specific error). If a message carries more than one token, the order `redo` > `again` >
  `fix` decides which is written.
- `run` is present when the objection falls inside a review-loop run, absent otherwise.

Unknown keys are ignored by any reader. Keys may be added later without changing what is already
written.

## The hook, and telling the author about it

The author marks an objection with a token in a message they were already sending:

    #redo   #again   #fix

A `UserPromptSubmit` hook matches them as whitespace-delimited words and appends one line. `#` is
used because `!` already runs a shell command in this harness.

This is an always-on prompt hook: it runs on every message, in every repository, for as long as it
is installed. **`/review-loop:init` states that plainly and asks before installing it** — what it
matches, what a line contains, where the file goes, that no message text is ever written, and how to
remove it. A plugin that installs an always-on hook without saying so is not honest, whatever the
hook does. Declining leaves the rest of the roster setup unaffected; only `object` lines are lost.

Three rules bind the hook:

1. **It writes nothing when the payload carries `agent_type`.** Reviewer subagents run under
   model-composed prompts, and § Facilitator discipline requires reviewer text to be quoted verbatim,
   so a reviewer's own text can carry these tokens. **This rule's premise is unverified** — the
   documentation introduces `agent_type` as a field added inside a subagent generally and never says
   this event fires there. If the event does not fire for subagents the rule is inert and harmless;
   confirm before implementing.
2. **It writes nothing to stdout, and always exits 0.** Its stdout is added to the prompt context. A
   non-zero exit shows the author a hook-error notice, and exit code 2 erases the message the author
   is typing. So the hook never reports failure through its exit status: when it cannot write, it
   writes nothing and exits 0.
3. **A token inside a fenced code block or an inline code span does not count.** A message discussing
   this spec would otherwise register objections. This needs fence and span tracking, not a bare
   regular expression.

**Off switch:** `REVIEW_LOOP_LOG=0` stops the hook and the loop's writer.

## Where it goes

`~/.claude/review-loop.log`, beside the existing `~/.claude/review-loop.local.md`. Mode 0600.

Never `${CLAUDE_PLUGIN_ROOT}`, which the marketplace replaces on update. Never inside a repository
under review — § Learning capture already appends a narrative journal there, per round and per
repository; this log is separate and global.

The path is a fixed constant, so it cannot land inside a repository under review unless the home
directory is one. The guard runs against the log file's own directory, not the caller's working
directory, which is the repository under review on every call:

    git -C "$(dirname "$LOGFILE")" rev-parse --is-inside-work-tree

If that succeeds, the writer writes nothing and still exits 0. A dotfiles repository that owns
`~/.claude/` is the realistic case.

One `write()` per line under `O_APPEND`, with lines bounded at 1024 bytes, so two loops in two
worktrees interleave lines but never split one. A writer that would exceed the bound writes nothing.

Round lines are written by `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/log.sh`, following the
path convention of the existing helper scripts. Objection lines are written by the hook, which
shares the same formatting and guard code.

### Where the loop calls it

§ A3 is the integration point for `review` lines: the facilitator writes one line after it has
aggregated the round's verdicts and before it decides whether the round was dry. The `end` key is
added on the round that satisfies an exit condition in § Exit conditions.

## The known weakness, and how to measure it

**The `object` side is measurable.** Session transcripts sit under `~/.claude/projects/` for about
thirty days. Within that window, extract the tokens from **user-role message content only**, applying
the same fence and code-span rule the hook applies, and compare the resulting session ids against the
`session` values on `object` lines. The difference is the omission rate.

The user-role and fence filters are not optional refinements. A bare
`grep -l '#redo\|#again\|#fix'` over the transcript directory was run against 36 sessions on the
reference host: it matched exactly one, the session that wrote this spec, and every match was this
document's own text being discussed. Measured that way the check reports total omission where there
was none, because it counts precisely the occurrences rule 3 tells the hook to skip.

**The `review` side is not measurable, and that is accepted.** A round line has no author-typed
antecedent, so nothing independent records that a round happened. It is also written by the agent
during the loop, which is where an underperforming agent is most likely to skip it. Sequential
`round` values reveal a gap inside a run; a run that was never logged at all is invisible. No fix is
proposed.

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

**A count says what was raised, not whether it was right.** A round that raised ten findings, two of
them wrong, logs the same numbers as a round that raised ten sound ones. During the review of this
spec, one reviewer filed a finding claiming a verification it had not received, then corrected itself
two rounds later; the correction is in this branch's review history and in the session transcript,
and the log would show neither the claim nor the correction. Judging review quality needs the
transcript, within its thirty days.

## The one thing worth watching

A log that receives no `object` lines gives no benefit, and should be removed rather than left
running.

That is a judgement for the author, not a rule for a script. Objections are written when the model
fails, so a quiet period may mean a good period rather than an abandoned habit, and no automatic test
separates those. The omission check above is what distinguishes a quiet period from a broken writer.

## An example, and what it is evidence of

Lines from one working day, reconstructed from the session that produced this spec:

    2026-07-20T11:08:19Z  object  session=d51240  tier=redo
    2026-07-20T12:30:06Z  object  session=d51240  tier=redo
    2026-07-20T13:47:52Z  review  session=d51240  run=x7k2p9  round=1  reviewers=claude-opus-4-8:19,claude-sonnet-5:9,gpt-5.5:5
    2026-07-20T14:05:13Z  object  session=d51240  run=x7k2p9  tier=fix
    2026-07-20T14:52:31Z  review  session=d51240  run=x7k2p9  round=2  reviewers=claude-opus-4-8:17,claude-sonnet-5:7,gpt-5.5:1  end=stopped
    2026-07-20T16:58:03Z  object  session=d51240  tier=again

In that session, eight of ten objections came before the first review round, during design rather
than during review. **That is one session, so it is an observation and not yet a reason.** It is the
weak evidence behind making the hook always-on rather than scoping it to a run; if a second session
splits evenly, that choice should be revisited. Sibling spec 014 grades its own comparable evidence
the same way.

## Testing

- Each token produces one line at the right tier; two tokens in one message produce one line at the
  stronger tier; a token in a fenced code block or an inline code span produces none.
- A prompt carrying `agent_type` produces no line.
- The hook writes nothing to stdout and exits 0 on every path, including every failure path.
- With the log file's own directory inside a git work tree, and the caller's working directory in an
  unrelated repository, the writer writes nothing and exits 0.
- With `REVIEW_LOOP_LOG=0`, neither writer writes.
- A new file has mode 0600.
- Two writers appending 1000 lines each produce 2000 whole lines.
- A value containing a space, an `=` or a path separator is written with those characters removed; a
  reported model id containing `,` or `:` likewise.
- A line that would exceed 1024 bytes is not written.
- A round where a reviewer drops out lists only the reviewers that returned a review.
- The last round of a run carries `end`; earlier rounds do not.
- The omission check, run with the user-role and fence filters over a transcript set containing one
  real objection and one quoted token, reports one and not two.

## Acceptance criteria

- [ ] `/review-loop:init` states what the hook does and asks before installing it, and declining
      leaves the rest of the roster setup working.
- [ ] Item 1 under *The hook* — whether `UserPromptSubmit` fires inside a subagent, and whether
      `agent_type` is present — is answered in writing before any code.
- [ ] The hook writes `object` lines with no model involvement in detection.
- [ ] Neither writer ever exits non-zero or writes to stdout.
- [ ] Both writers refuse when the log file's own directory is inside a git work tree.
- [ ] The log file is created with mode 0600.
- [ ] Concurrent appends never split a line.
- [ ] The loop writes one `review` line per round from § A3, with per-reviewer counts and reported
      model ids.
- [ ] The off switch stops both writers.
- [ ] The omission check is documented with its user-role and fence filters, not as a bare `grep`.
- [ ] All tests above pass.
