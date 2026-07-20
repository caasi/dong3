# 016 — review-loop: an observation log

**Status:** Design
**Plugin:** `review-loop`
**Extends:** [014](014-review-loop-reviewer-roster-design.md)
**Source:** [caasi/dong3#56](https://github.com/caasi/dong3/issues/56). Two earlier proposals on that issue — a rounds-to-convergence metric and a `P(clean)` posterior — are withdrawn; the evidence is in the comments there.
**Target version:** `review-loop` 0.6.0 → 0.7.0

Unqualified `§` references point to `plugins/review-loop/skills/review-loop/SKILL.md`.

## What this is

A line-oriented log, in the Unix style. One line per event, plain text, readable with `grep`.

**It is append-only, and that is its organising property.** A line is written once and never changed. A new writer
joins by appending, with no coordination and no migration. A new key appears on new lines and old
lines stay valid. Nothing in this design may require reading a line back to update it.

It answers two questions later: **which reviewers ran a round and how many findings each raised**,
and **when the author objected**.

Analysis is out of scope.

## Non-goals

- **No score, threshold or probability.**
- **No comparison of finding counts across runs or across reviewers.** A count mixes artifact
  difficulty, roster composition, deduplication strictness and author scope decisions; see #56.
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

    2026-07-20T13:47:52Z  review  project=github.com-caasi-dong3  run=x7k2p9  round=1  reviewers=claude-opus-4-8:19,claude-sonnet-5:9,gpt-5.5:5
    2026-07-20T14:31:02Z  object  project=github.com-caasi-dong3  session=0f3c8a1e-…  tier=redo

`project` is on every line. This file is global — one file for every repository and every host — so
without it no line says where it came from. It is what makes one file sufficient instead of one file
per project.

Both writers derive it the same way, from a directory: the hook uses the `cwd` in its payload,
`log.sh` uses its own. Neither is necessarily the repository root, so both run the same three steps:

1. **`git remote get-url origin`, if it succeeds.** Remove the scheme, remove the whole `userinfo@`
   component **including any password or token**, remove a trailing `.git`, then replace every `/`
   and `:` with a hyphen:

       https://github.com/caasi/dong3.git        →  github.com-caasi-dong3
       git@gitlab.com:group/subgroup/repo.git    →  gitlab.com-group-subgroup-repo

   Removing the whole userinfo component matters: an HTTPS remote can carry
   `https://oauth2:<token>@host/a/b.git`, and a rule that strips only a `git@`-shaped prefix would
   write that token into this file as part of `project`. The file is append-only, so a credential
   written once cannot be removed.

   The host is kept because this author works on two forges, and `github.com/acme/api` and
   `gitlab.com/acme/api` are different projects. Every path segment is kept because GitLab subgroups
   nest arbitrarily, and dropping the separator would merge `group/sub-a/repo` with
   `group/sub-b/repo`. This is the project's identity rather than the checkout's, so two clones
   agree. Two remotes that differ only in where a hyphen already sat still collide; that is accepted.
   A repository with remotes but no `origin` falls through to step 2.

2. **Otherwise the repository's own directory name**, from
   `git rev-parse --path-format=absolute --git-common-dir`. That path is `<root>/.git` for an
   ordinary clone and `<super>/.git/modules/<name>` for a submodule, so: if its basename is `.git`,
   take the parent directory's basename; otherwise take the basename with a trailing `.git` removed.
   Both shapes were checked against real repositories.

   **Not `--show-toplevel`**, which in a linked worktree returns the worktree's own path. This
   project's convention is that branch work happens in a RAM-disk worktree, so `--show-toplevel`
   would fragment one project across as many slugs as it has had worktrees.

3. **`project=none`** when the directory is in no repository at all. The hook runs on every message,
   including in sessions started outside any work tree, and a line still records that an objection
   happened.

Any character the value rules forbid is removed from the result. A slug records no directory
structure.

The hook receives the harness session id and cannot learn the run token the loop minted, and the
loop's script has no documented way to read the session id. So `review` lines carry
`run` and no `session`; `object` lines carry `session` and no `run`. Nothing joins an objection to a
round except time order, and that is enough for everything this log claims.

`session` is the id **in full**, as the hook receives it. The omission check below matches it against
the transcript's session id exactly, which is the only reason that check is exact rather than
approximate. The example abbreviates it for width; real lines do not.

**`review`** — one line per round, written by the loop. A *run* is one `/review-loop` invocation
from start to stop, called an *episode* in § A3; a *round* is one dispatch-review-fix iteration
inside it.

- `run` is 6 lowercase alphanumeric characters, minted once per run by `log.sh` from `/dev/urandom`
  rather than by the agent, which is not a random source. It must not be a branch slug: branches are
  reused, so a slug does not stay unique within one project over time.
- `round` is a positive integer, starting at 1, increasing by one per round within a run.
- `reviewers` pairs each reviewer that returned a review this round with the count it raised. A
  reviewer that dropped out, hit a usage limit or was absent is simply not listed, so no separate
  field is needed. The panel total is the sum.
- **The count is of findings the reviewer returned, before cross-critique and before tiering.** § A1
  makes cross-critique optional and § Tiers puts classification after it, so a post-processing count
  would be undefined on rounds where neither ran.
- Each key is the **model id the reviewer reported**, not its roster nickname. § Exit conditions
  requires the verdict to report what actually ran, verified; a nickname stops identifying weights
  within a year.
- **A reported model id is percent-encoded, and the value rules above do not apply to it.** `%`
  first, as `%25`, then whitespace, `=`, `/`, `,` and `:`. `%` must come first or a reported `a,b` and
  a reported `a%2Cb` collide. Dropping characters instead would merge two reviewers into one key, and
  spec 014 enrols endpoints whose ids carry a path separator — `meta-llama/Llama-3.3-70B`. Encoding
  rather than dropping also removes the question of which operation runs first.
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
  `fix` (one specific error). If a message carries more than one marker, the order `redo` > `again` >
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
plugin is enabled. That scope is what the global file needs — a record of work across projects, not
of one review loop — and it is why `project` is on every line.

**Installation cannot be asked about; writing can, and is.** A plugin ships its hooks in
`hooks/hooks.json`, which the harness merges the moment the plugin is enabled, so no disclosure can
precede installation. Writing the hook into `~/.claude/settings.json` instead would allow an ask, but
it makes `init` write a file it does not touch today. So the hook ships with the plugin and **stays
inert until the author agrees**.

**The answer lives in the roster config, and the hook reads it directly.** `init` writes
`~/.claude/review-loop.local.md` and, per `commands/init.md`, that file is "overridden per project by
`<project-root>/.claude/review-loop.local.md`". The hook resolves both, from the `cwd`
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

A two-file scheme keeps the answer in one file and a marker the hook reads in a second. The two can
disagree, and both directions are bad. A recorded `no` with a surviving marker means the hook writes
against a decline. A recorded `yes` with a missing marker means the hook is inert forever while
`init` never asks again, which looks exactly like an author who stopped objecting. One file has
neither failure.

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
3. **A marker inside a fenced code block or an inline code span does not count.** A message discussing
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

The caller passes only those keys. The script supplies the timestamp and `project`, applies the value
rules, and performs the guard. It takes no `session` key: the session id is not available to a script the loop
invokes, so `review` lines carry none, as stated in *Format*.

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
thirty days. Within that window, extract the markers from **user-role message content only**, applying
the same fence and code-span rule the hook applies, and compare the resulting session ids against the
`session` values on `object` lines. The difference is the omission rate.

A bare `grep` over the transcript directory matches this document's own text being discussed, not
only real objections, which is the case rule 3 excludes. Without both filters the check reports total
omission where there was none.

**The `review` side is not measurable, and that is accepted.** A round line has no author-typed
antecedent, so nothing independent records that a round happened. It is also written by the agent
during the loop, which is where an underperforming agent is most likely to skip it. Sequential
`round` values reveal a gap inside a run; a run that was never logged at all is invisible. No fix is
proposed.

A log that receives no `object` lines gives no benefit and should be removed. Objections are written
when the model fails, so a quiet period may mean a good period rather than an abandoned habit; the
omission check above is what separates that from a broken writer.

## What is not recorded, and why

- **No message text, paths, diffs or finding text.** A line carries counts and identifiers.
- **`project` is the exception worth naming.** With it the file becomes a list of every project the
  author has worked in on that host. A repository name is usually harmless and sometimes is not. The
  file is mode 0600 and outside any repository, and that is the whole of its protection.
- **No derived measurement** — diff size, file counts, effect profile. All are recomputable from git
  later, and the tools that derive them still change. `fxrank` is one example: it has open P1
  defects (#74, #76, #53, #52), so a reading stored today would be wrong in a way no later version
  could repair.

Everything else the loop knows — per-reviewer verdicts, tier classifications, the `K` signal, Codex
sandbox routing — is stated in the loop's own output and is in the session transcript. Those
transcripts prune at about thirty days, so anything not on a line above is lost after that. That is
accepted: deciding what to keep past thirty days is an analysis decision, and analysis is deferred.

A round that raised ten findings, two of them wrong, logs the same numbers as a round that raised ten
sound ones. Judging review quality needs
the transcript, within its thirty days.

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
- Stopping the loop between rounds produces a `review` line carrying `project`, `run` and
  `end=stopped`, with no `round` key, and a reader counts the run as finished.
- A second `init` run with the key already present, in either state, does not ask again.
- With `REVIEW_LOOP_LOG=0`, neither writer writes.
- A new file has mode 0600.
- Two writers appending 1000 lines each produce 2000 whole lines.
- Both writers, run from the same repository, produce the same `project` value — including from a
  subdirectory, and including from a linked worktree, where the value is the main checkout's and not
  the worktree directory's.
- An `origin` of each URL form — HTTPS with `.git`, SSH in scp form, and a nested path of three or
  more segments — produces the slug in the table above, with the host kept and no segment merged.
- **A plain non-bare clone with no remote produces a non-empty slug**, and so does a linked worktree
  of it. A bare-repository fixture does not exercise this; the fixture must be an ordinary clone.
- A clone with an `upstream` remote and no `origin` falls through to step 2, and produces the same
  slug as the same clone with no remote at all.
- A submodule reached through step 2 produces the name of its path in the superproject, which is what
  `.git/modules/` is keyed by, not the name of the repository it was cloned from.
- A remote carrying a userinfo component produces a slug with no part of that component in it.
- A directory in no repository produces `project=none`.
- A value containing a space, an `=` or a path separator is written with those characters removed.
- A reported model id containing `%`, whitespace, `=`, `/`, `,` or `:` is percent-encoded, `%` first,
  and two ids that differ only in those characters stay distinct. `meta-llama/Llama-3.3-70B` survives
  with its path separator encoded rather than removed.
- A line that would exceed 1024 bytes is not written.
- A round where a reviewer drops out lists only the reviewers that returned a review.
- In a run that ends on a round, the last round carries `end` and earlier rounds do not.
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
- [ ] The hook reads both configs and writes only when `observation-log: yes` resolves. A project
      config overrides the global one. The three states and the override are tested.
- [ ] Item 1 under *The hook* — whether `UserPromptSubmit` fires inside a subagent, and whether
      `agent_type` is present — is answered in writing before any code.
- [ ] The hook writes `object` lines with no model involvement in detection.
- [ ] Neither writer ever exits non-zero. The hook writes nothing to stdout on any path. `log.sh`
      writes nothing to stdout except the token printed by `new-run`.
- [ ] Both writers refuse when the log file's own directory is inside a git work tree.
- [ ] The log file is created with mode 0600.
- [ ] Concurrent appends never split a line.
- [ ] The loop writes one `review` line per round from § A3, with per-reviewer counts and reported
      model ids, percent-encoded rather than subject to the value rules.
- [ ] Every line carries `project`, both writers derive it identically, and a linked worktree yields
      the main checkout's slug.
- [ ] The hook and `log.sh` both source their formatting and guard code from `logline.sh`, so the
      value rules cannot apply to one and not the other.
- [ ] The off switch stops both writers.
- [ ] The omission check is documented with its user-role and fence filters, not as a bare `grep`.
- [ ] § A3 of `SKILL.md` gains the round-logging instruction, and `commands/init.md` gains the
      disclosure and the recorded answer.
- [ ] Both edits gain anchors in `tools/review-loop/test-skill-content.sh`, which reads only
      `SKILL.md` today and must be extended to a second file.
- [ ] `hooks/hooks.json` declares the hook command and its 5-second timeout. Nothing in this design
      runs without it.
- [ ] `.claude-plugin/marketplace.json` records the version bump in the header.
- [ ] All tests above pass.
