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

    2026-07-20T13:47:52Z  review  run=x7k2p9  round=1  reviewers=claude-opus-4-8:19,claude-sonnet-5:9,gpt-5.5:5
    2026-07-20T14:31:02Z  object  session=0f3c8a1e-…  tier=redo

**The two writers know different things, and the keys follow that rather than pretending otherwise.**
The hook receives the harness session id and cannot learn the run token the loop minted. The loop's
script holds the run token and has no documented way to read the session id. So `review` lines carry
`run` and no `session`; `object` lines carry `session` and no `run`. Nothing joins an objection to a
round except time order, and that is enough for everything this log claims.

`session` is the id **in full**, as the hook receives it. The omission check below matches it against
the transcript's session id exactly, which is the only reason that check is exact rather than
approximate. The example abbreviates it for width; real lines do not.

**`review`** — one line per round, written by the loop. A *run* is one `/review-loop` invocation
from start to stop, called an *episode* in § A3; a *round* is one dispatch-review-fix iteration
inside it.

- `run` is 6 lowercase alphanumeric characters, minted once per run by `log.sh` from `/dev/urandom`
  rather than by the agent, which is not a random source. It must not be a pull request number or a
  branch slug: this log is global, so both collide across repositories, and a branch slug can contain
  a path separator.
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
  it percent-encoded. `%` is encoded first, as `%25`, then `,` as `%2C` and `:` as `%3A`; without that
  order a reported `a,b` and a reported `a%2Cb` collide. Removing the characters instead would map
  `a:b` and `a,b` onto one key and merge two reviewers into one.
- `end` appears on the last `review` line of a run: `end=converged` or `end=stopped` (the author
  ended it). There is no usage-limit value: § Exit conditions is explicit that a usage limit stops
  only the Codex sub-loop, and § A3 counts an unavailable reviewer as done, so a limit never ends a
  run. Without `end`, a run is unfinished. Convergence is the reviewers' own verdict per § A3 and is
  never inferred from a zero count.
- An author who stops the loop between rounds leaves no round in flight to carry `end`. The
  facilitator then writes `review run=<tok> end=stopped` with no `round` and no `reviewers`. This is
  the one `review` line that is not a round, and a reader distinguishes it by the absence of `round`.
  Without it such a run would stay indistinguishable from one that was abandoned.

**`object`** — one line each time the author objects, written by the hook.

- `tier` is `redo` (the whole output is unusable), `again` (this was already corrected once), or
  `fix` (one specific error). If a message carries more than one token, the order `redo` > `again` >
  `fix` decides which is written.
- There is no `run` key. The hook has no channel to the loop's run token, and inventing one would be
  a shared state file to keep in step for a join nothing yet needs.

Unknown keys are ignored by any reader. Keys may be added later without changing what is already
written.

## The hook, and telling the author about it

The author marks an objection with a token in a message they were already sending:

    #redo   #again   #fix

A `UserPromptSubmit` hook matches them as whitespace-delimited words and appends one line. `#` is
used because `!` already runs a shell command in this harness.

This is an always-on prompt hook: it runs on every message, in every repository, for as long as the
plugin is enabled.

**Installation cannot be asked about; writing can, and is.** A plugin ships its hooks in
`hooks/hooks.json`, which the harness merges the moment the plugin is enabled, so no disclosure can
precede installation. Writing the hook into `~/.claude/settings.json` instead would allow an ask, but
it makes `init` write a file it does not touch today. So the hook ships with the plugin and **stays
inert until the author agrees**.

**The answer lives in the roster config, and the hook reads it directly.** `init` writes
`~/.claude/review-loop.local.md` and, per `commands/init.md`, that file is "overridden per project by
`<project-root>/.claude/review-loop.local.md`". The hook resolves both, in that order, from the `cwd`
its payload carries — reading only the global file would let a project-level `observation-log: no` be
ignored, which is the write-against-a-decline case this design exists to avoid.

The key is a **top-level scalar in the file's frontmatter**, and the reader stops at the closing
`---`. That file's body is free-form markdown, and `init` invites the author to write notes in it, so
a match anywhere in the file would be satisfied by a line in `## Notes` or inside a fenced example.
Scoping the read to the frontmatter keeps it a line match and avoids adding a YAML parser as an
always-on dependency.

The three states are:

    absent                 never asked; the hook writes nothing
    observation-log: no    declined; the hook writes nothing
    observation-log: yes   the hook writes

An earlier draft put the answer in `review-loop.local.md` and a separate marker file that the hook
read. Two records of one decision can disagree, and both directions are bad: a recorded `no` with a
surviving marker means the hook writes against a decline, and a recorded `yes` with a missing marker
means the hook is inert forever while `init` never asks again — which looks exactly like an author who
stopped objecting. One file has neither failure.

It does not, however, inherit an ignore rule. `init` offers to add `.claude/*.local.md` to a
*project's* `.gitignore`; the global answer lives in `~/.claude/`, which no such offer covers, and
this document names a dotfiles repository owning `~/.claude/` as a realistic case. So a recorded
`yes` can reach a second host through a dotfiles sync, and the author is never asked there. `init`
therefore treats a config that arrived without being written locally the same as any other: it does
not re-ask, and the disclosure says the answer travels with the file.

`/review-loop:init` asks before writing `yes` — what the hook matches, what a line contains, where the
file goes, that no message text is ever written, that the hook still executes on every message even
while the answer is `no` or absent, and how to remove it. A plugin that records an author's messages
without saying so is not honest, whatever it records.

`init` is idempotent and does not ask again once the key is present in either state; a recorded `no` is
a decision, not an absence. Adding the key does not bump the file's `review-loop-config` stamp, since
absence of the key is a meaningful state and needs no migration. Declining leaves the rest of the
roster setup unaffected; only `object` lines are lost.

Three rules bind the hook:

1. **It writes nothing when the payload carries `agent_type`.** Reviewer subagents run under
   model-composed prompts, and § Facilitator discipline requires reviewer text to be quoted verbatim,
   so a reviewer's own text can carry these tokens. The hooks reference documents `agent_type` as a
   common field, "present when the session uses `--agent` or the hook fires inside a subagent", and
   does not exempt this event — so the premise holds on the documentation. Re-check it against the
   installed harness rather than assuming.

   **The rule costs more than it targets.** The same field marks a main session started with
   `--agent`, so an author working that way gets no `object` lines and no notice. The documentation
   offers no field that separates the two cases. The loss is accepted rather than solved, and it is
   listed here so it is not discovered as a surprise.
2. **It writes nothing to stdout, and always exits 0.** Its stdout is added to the prompt context. A
   non-zero exit shows the author a hook-error notice, and exit code 2 erases the message the author
   is typing. So the hook never reports failure through its exit status: when it cannot write, it
   writes nothing and exits 0.
3. **A token inside a fenced code block or an inline code span does not count.** A message discussing
   this spec would otherwise register objections. This needs fence and span tracking, not a bare
   regular expression.

The hook reads a JSON payload on standard input, so it needs a JSON parser. § Requirements treats
`jq` as optional, and under rule 2 a missing parser means the hook writes nothing and exits 0 — which
reads exactly like an author who stopped objecting. `init` therefore reports a missing parser at
enrollment, and the omission check below is what catches it later.

**Off switch:** `REVIEW_LOOP_LOG=0`. A hook inherits the environment the harness was launched with,
so exporting it in the shell affects sessions started afterwards, and setting it in `settings.json`
under `env` affects every session including the current one. Both are honoured; neither stops a
session already running from a shell that lacks it.

**Timeout:** the hook entry sets a timeout of 5 seconds. `UserPromptSubmit` blocks the harness until
the hook returns, so a hang would stall every message the author sends. Rule 2 covers failure, not
slowness; this covers slowness.

## Where it goes

`~/.claude/review-loop.log`, beside the existing `~/.claude/review-loop.local.md`. Mode 0600.

Never `${CLAUDE_PLUGIN_ROOT}`, which the marketplace replaces on update. Never inside a repository
under review — § Learning capture already appends a narrative journal there, per round and per
repository; this log is separate and global.

The path is a fixed constant, so it cannot land inside a repository under review unless the home
directory is one. The guard runs against the log file's own directory, not the caller's working
directory, which is the repository under review on every call:

    git -C "$(dirname "$LOGFILE")" rev-parse --is-inside-work-tree

The test is the printed value, not the exit status: the command exits 0 and prints `false` inside a
`.git` directory or a bare repository, which is not the case this guard is aimed at. If it prints
`true`, the writer writes nothing and still exits 0. A dotfiles repository that owns
`~/.claude/` is the realistic case.

One `write()` per line under `O_APPEND`, with lines bounded at 1024 bytes, so two loops in two
worktrees interleave lines but never split one. A writer that would exceed the bound writes nothing.

Round lines are written by `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/log.sh`, following the
path convention of the existing helper scripts:

    log.sh new-run                                    # prints a fresh run token, and nothing else
    log.sh review run=<tok> round=<n> reviewers=<list> [end=<reason>]
    log.sh review run=<tok> end=stopped               # a stop between rounds; no round, no reviewers

The caller passes only those keys. The script supplies the timestamp, applies the value rules, and
performs the guard. It takes no `session` key: the session id is not available to a script the loop
invokes, so `review` lines carry none — see *What is not recorded*.

Objection lines are written by the hook at
`${CLAUDE_PLUGIN_ROOT}/hooks/object.sh`. Both writers source the formatting and guard code from
`${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/logline.sh`, so a change to the value rules cannot
apply to one and not the other.

### Where the loop calls it

§ A3 of `plugins/review-loop/skills/review-loop/SKILL.md` gains the instruction, and that edit is the
deliverable — not a runtime property, which nothing here could check.

The facilitator writes one line per round, **after** it has aggregated the verdicts and decided
whether the round was dry. It must be after: a line is written once and never updated, and `end`
cannot be known before the exit condition in § Exit conditions is evaluated for that round.

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
spec, the round-one Claude reviewer filed a finding that claimed a verification it had not received,
and corrected itself two rounds later: "I killed my wait loops and wrote the finding from my own
recollection while presenting it as a checked fact." Both the claim and the correction reached the
facilitator; neither would reach a line here. Judging review quality needs the transcript, within its
thirty days.

## The one thing worth watching

A log that receives no `object` lines gives no benefit, and should be removed rather than left
running.

That is a judgement for the author, not a rule for a script. Objections are written when the model
fails, so a quiet period may mean a good period rather than an abandoned habit, and no automatic test
separates those. The omission check above is what distinguishes a quiet period from a broken writer.

## An example, and what it is evidence of

Six lines from one working day, reconstructed from the session that produced this spec. The day held
more; this is an excerpt chosen to show both event kinds:

    2026-07-20T11:08:19Z  object  session=0f3c8a1e-…  tier=redo
    2026-07-20T12:30:06Z  object  session=0f3c8a1e-…  tier=redo
    2026-07-20T13:47:52Z  review  run=x7k2p9  round=1  reviewers=claude-opus-4-8:19,claude-sonnet-5:9,gpt-5.5:5
    2026-07-20T14:05:13Z  object  session=0f3c8a1e-…  tier=fix
    2026-07-20T14:52:31Z  review  run=x7k2p9  round=2  reviewers=claude-opus-4-8:17,claude-sonnet-5:7,gpt-5.5:1  end=stopped
    2026-07-20T16:58:03Z  object  session=0f3c8a1e-…  tier=again

In that session, eight of ten objections came before the first review round, during design rather
than during review. **That is one session, so it is an observation and not yet a reason.** It is the
weak evidence behind making the hook always-on rather than scoping it to a run.

Spec 014 grades its two hypotheses against project history and states the evidence for one of them
confidently. It does not hedge a single self-referential sample, because it does not use one. This
document does, so the hedge is stated here rather than borrowed.

**That count is reconstructed from the session transcript, and the log cannot produce it.** An
objection line carries `session` and a round line carries `run`, and they share no key. Objections
from two concurrent sessions stay separable — that is what `session` is for, and the omission check
depends on it. What cannot be recovered is which *round* an objection fell inside, and the split
above is stated against rounds. So the instrument for revisiting that choice is the transcript, within
its thirty days — not these lines. A log that cannot evaluate the condition placed on its own design
should say so where the condition is stated.

## Testing

- Each token produces one line at the right tier; two tokens in one message produce one line at the
  stronger tier; a token in a fenced code block or an inline code span produces none.
- A prompt carrying `agent_type` produces no line.
- The hook writes nothing to stdout and exits 0 on every path, including every failure path.
- With the log file's own directory inside a git work tree, and the caller's working directory in an
  unrelated repository, the writer writes nothing and exits 0.
- With no `observation-log` key in `review-loop.local.md`, the hook writes nothing. With
  `observation-log: no`, the hook writes nothing. With `observation-log: yes`, it writes.
- A project config with `observation-log: no` overrides a global `yes`, and the hook writes nothing.
- A file whose frontmatter has no `observation-log` key, but whose `## Notes` body contains the line
  `observation-log: yes`, is read as absent and the hook writes nothing.
- Stopping the loop between rounds produces `review run=<tok> end=stopped` with no `round` key, and a
  reader counts the run as finished.
- A second `init` run with the key already present, in either state, does not ask again.
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
- Two sessions overlapping in time, one carrying an objection and one not, are attributed correctly
  by the omission check. A join on timestamp proximity alone misattributes them; the `session` key is
  what prevents it, and this is the test that shows it.
- `log.sh new-run` prints a 6-character token and nothing else, and two calls differ.

## Acceptance criteria

- [ ] `/review-loop:init` states what the hook does and asks before writing `observation-log: yes` —
      not before installing it, which is not possible. Declining leaves the rest of the roster setup
      working.
- [ ] The hook writes only when `observation-log: yes` resolves, reading the project config before
      the global one, and the three states and the override are tested.
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
- [ ] § A3 of `SKILL.md` gains the round-logging instruction, and `commands/init.md` gains the
      disclosure and the recorded answer.
- [ ] Both edits gain anchors in `tools/review-loop/test-skill-content.sh`, because prose in a system
      prompt is behaviour. **That script reads only `SKILL.md` today** — it hardcodes one path and
      contains no reference to `commands/`. Spec 014 states command docs should be anchored and never
      added one, so this work extends the script to a second file rather than following an existing
      precedent.
- [ ] `hooks/hooks.json` declares the hook command and its 5-second timeout. Nothing in this design
      runs without it.
- [ ] `.claude-plugin/marketplace.json` records the version bump in the header.
- [ ] All tests above pass.
