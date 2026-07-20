# 016 — review-loop: an observation log

**Status:** Design
**Plugin:** `review-loop`
**Extends:** [003](003-review-loop-headless-codex-design.md), [009](009-review-loop-codex-sandbox-fix-design.md), [014](014-review-loop-reviewer-roster-design.md)
**Source:** [caasi/dong3#56](https://github.com/caasi/dong3/issues/56). Two proposals on that issue are withdrawn — the original round-count metric, and the shadow-mode `P(clean)` posterior that replaced it. The evidence for both withdrawals is the second comment there.
**Target version:** `review-loop` 0.6.0 → 0.7.0

Unqualified `§` references point to `plugins/review-loop/skills/review-loop/SKILL.md`.
Earlier drafts of this spec carried more; `git log -p` on this file records what was cut and why.

## What this is

A log. It records what the author marks while working, and a small amount of per-round state from a
review-loop run.

**Analysis is out of scope.** Weights, scores, thresholds and validation tests are not designed here
and must not be designed until real data exists.

**Only one question cannot be deferred: what to record.** State that exists only while a run happens
is gone when the run ends.

## What moved

Issue #56 first proposed logging rounds-to-convergence as a capability signal, then a per-round
`P(clean)` posterior. Both are withdrawn, for reasons and evidence recorded on the issue.

The short version: a review loop is a repair mechanism, so its convergence hides a capability change
rather than showing it; and every candidate ground truth for calibrating a posterior turned out to
be an opinion, an artifact of the observation process, or written after the fact.

What a person notices when a model is unreliable is in the interaction: an instruction dropped, a
point corrected twice, a claim reasserted after refutation. The reference is the session's own
earlier state.

## The rule that decides the schema

Two rules, and the second is the one that actually sizes the round record. An earlier draft claimed
only the first, which would have deleted most of what the schema keeps.

> **1. Record what cannot be reconstructed at all.**
> **2. Record what the writer already holds when it writes, if recovering it later means parsing a
> transcript that expires.**

Rule 1 covers the author's marks and the pointers. Rule 2 is a cost judgement, not a derivation: a
field already in a variable costs nothing to write, while recovering it later requires a model to
read a transcript, inside a retention window. Naming rule 2 makes the boundary an owned decision
rather than a claimed consequence.

Everything the loop states in its output is in the session transcript. So the transcript is the
substrate, and the log points at it.

### Transcripts expire, so a marked one is preserved

The transcript directory holds roughly 830 files and prunes at about thirty days. Observed, not
documented.

That matters more than it first appears, and it is why the following mechanism exists rather than a
larger schema. **The marks are relational.** `#again` means "this point was already corrected once";
its content is a relation to an earlier turn. The record carries no message text, deliberately. Once
the transcript is gone, an `again` is a tier with no referent — the author flagged a repeat, and what
repeated is unknown. The same holds for `redo` and `fix`.

So the marks do not outlive the transcript. Only their counts do.

**When a mark fires, the hook preserves that session's transcript**: a hard link into
`~/.claude/review-loop-transcripts/<session_id>.jsonl`, created once per session. A hard link shares
the inode, so the preserved copy keeps growing with the session and survives the pruning of the
original. If the link fails because the target is on another filesystem, the hook records
`preserved: false` and the session's transcript is treated as expiring.

The cost is bounded by hypothesis: marks are rare, so few sessions are preserved. Preserving the
substrate is cheaper than promoting more summaries of it into the schema, and it is the only change
that keeps a mark interpretable after thirty days.

## Marks

    #redo    the whole output is unusable
    #again   this point was already corrected once
    #fix     one specific error

A `UserPromptSubmit` hook matches these and appends a record.

Matching rules:

- A token counts only as a whitespace-delimited word.
- Fenced code blocks are skipped. This needs fence tracking, not a bare regular expression.
- Inline code spans are **not** skipped. This is a known false-positive source, accepted for now: a
  message discussing the tokens will produce marks.
- If a message carries more than one distinct token, the strongest wins: `redo`, then `again`, then
  `fix`. Repeats of one token in one message count once.
- **The hook writes nothing when the payload carries `agent_type`.** Subagent prompts are composed by
  a model, and § Facilitator discipline requires reviewer text to be quoted verbatim, so a reviewer's
  own text can carry these tokens. Without this rule a machine-authored token becomes an author mark,
  and the claim that no model takes part in detection is false.
- **The hook writes nothing to stdout.** A `UserPromptSubmit` hook's stdout is added to the prompt
  context, so any output enters the session and changes what the author attends to.

`#` is used because `!` already runs a shell command in this harness.

### Blocking verification before implementation

Confirm against the installed Claude Code version, not from memory, and write the answers down:

1. That `UserPromptSubmit`, `SessionStart` and `SessionEnd` exist.
2. **That `agent_type` appears in a subagent's `UserPromptSubmit` payload.** The rule above is the
   only barrier protecting the no-model-in-detection claim, so its field must be verified.
3. **What `SessionStart` and `SessionEnd` each carry.** They differ: `SessionStart` documents `model`
   as optional, `SessionEnd` documents no `model` at all, and documents a `reason` field. Neither
   documents reasoning effort or a fast flag, so those are not in the schema.
4. **Whether `UserPromptSubmit` stdout is injected**, since the silence rule depends on it.
5. **How a script invoked by the loop learns the session id.** The documented channel is the hook
   payload, which a script does not receive. An undocumented environment variable exists on at least
   one host. Without a verified answer the marks cannot be joined to the rounds, and the log is two
   disconnected halves.

If a hook is unavailable, the fallback is a slash command at higher friction.

### Off switch

`REVIEW_LOOP_STATS=0` disables writing. This is the machine's first always-on prompt hook, so an off
switch is required; #56 asked for one in its original body.

The two writers run in different environments — the hook inherits the interactive session, the script
inherits whatever the loop gives it. **A mixed state is legal and is recorded**: a session with marks
and no round records is indistinguishable from the completeness hole below, so the switch is read and
its state written on the `session` record.

## Schema

One JSON object per line at `~/.claude/review-loop.stats.jsonl`.

### mark

```json
{"schema": 1, "kind": "mark", "session": "<session_id>", "ts": "2026-07-20T14:22:31Z",
 "tier": "redo | again | fix", "cwd": "<path>", "transcript": "<path>", "preserved": true}
```

`preserved` records whether the hard link succeeded, so a later reader knows whether the mark still
has a referent.

### session

```json
{"schema": 1, "kind": "session", "session": "<id>", "event": "start | end", "ts": "...",
 "transcript": "<path>", "cwd": "<path>",
 "model": "<id or null>", "reason": "<SessionEnd reason or null>", "stats_enabled": true}
```

`model` is present only on `start`, and only when the payload carries it. `reason` is present only on
`end`; it is cheap, documented, and describes how a session terminated, which a transcript may not
show for an abnormal end.

### round

```json
{"schema": 1, "kind": "round", "session": "<id>", "run": "<globally unique id>", "round": 3,
 "ts": "...", "transcript": "<path>",
 "repo": "<slug>", "base": "<sha>", "head": "<sha>",
 "target_state": "committed | uncommitted | dirty", "pr": 42,
 "reviewers": {"<key>": {"model": "<id or null>", "verdict": true,
                         "drift": false,
                         "dropped": "usage-limit | absent | failed | non-review | ghost",
                         "degraded": "ghost-rerun | range-mismatch | resume-last | resume-fresh"}},
 "fix_round": true, "k_signal": 2, "guard_discharged": false,
 "codex_form": "native | embedded | n/a",
 "codex_route": "preflight | detector | mismatch | n/a",
 "sandbox": "usable | broken | unknown"}
```

**`reviewers` must carry an entry for every enrolled reviewer**, so a missing key is a write failure
rather than an ambiguity. A reviewer that is enrolled but not on the host gets `dropped: absent`.
§ Exit conditions makes panel composition the one thing the loop must disclose honestly, so an
absent entry would defeat that.

The key must be stable across re-enrolment and unique across project-level roster overrides. The
enrolment names in `~/.claude/review-loop.local.md` are free-form table cells (`Opus`,
`codex (gpt-5.5)`), so the key is a slug derived from them by a rule the implementation states once,
not the cell text.

`drift` carries § A3's `suspected_drift`. It is the loop's one machine-side unreliability flag, and
unreliability is this log's subject, so it is kept while richer finding-level counts are not.

`verdict: null` means the reviewer did not report this round, which § A3 treats as done when the
reviewer is unavailable.

`guard_discharged` is required because `k_running` and `k_final` are **not** recorded on the argument
that they are the running maximum of `k_signal`. That argument is incomplete: § A3 also says a clean
direction-guard audit discharges a `K ≥ 2` hold, which lowers the effective `K` below that maximum.
One bit restores the derivation.

`run` must be globally unique. § Codex mechanics allows a PR number or a branch slug as a run id;
both collide across repositories in one global file.

`codex_form` records which path ran; `codex_route` records what decided it. Both are needed: under
sticky embedded convergence later rounds stay embedded while `sandbox` may still read `usable`.
`route: detector` means a silent false-clean was caught this round.

`target_state` is decided in this order, and exactly one value applies:

1. the target was the working diff (`--uncommitted`) → `uncommitted`;
2. otherwise, tracked files differ from `head` at review time → `dirty`;
3. otherwise → `committed`.

Only `committed` guarantees that `head` contains what was reviewed. For the other two the reviewed
content is not recoverable, and the record says so by carrying that value. A snapshot handle was
considered and rejected: the available methods produce an unreferenced object that `git gc` prunes,
and omit untracked files, which § Codex mechanics requires for an uncommitted target.

### run_end

```json
{"schema": 1, "kind": "run_end", "session": "<id>", "run": "<id>", "ts": "...",
 "end_reason": "k-dry | copilot-clean | repeat-guard | author-stopped | aborted"}
```

`codex-limit` and `codex-failed` are **not** end reasons: § Exit conditions is explicit that a usage
limit stops only the Codex sub-loop. Those events are carried by `dropped` on the round.

`aborted` is included because § Codex mechanics names abort as a reached code path, distinct from a
crash. A run with no `run_end` at all is simply unfinished, and any reader can see that; no field is
needed for it.

`final_round` and `k_final` are not recorded; both derive from the run's `round` records, given
`guard_discharged`.

### Not recorded

- **Verdict text.** § A3's verdict object carries `still_open` and `reason`; only the boolean is taken.
- **Any path, diff, prompt or finding text.** A mark carries its tier and timestamp, never the message.
- **Findings counts, cross-critique outcomes, reproduction and dismissal counts, tier
  classifications, direction-guard details, author A0 and T2/T3 decisions.** All are stated in the
  loop's output, so they are in the transcript that every record points at, and a marked session's
  transcript is preserved. If a later analysis needs one past retention for an unmarked session, it
  is added then, and the earlier loss is accepted.
- **Any derived measurement**: effect profile, diff size, file counts, test presence. These are
  recomputed from the commit range when `target_state` is `committed`. `fxrank` is the case in point:
  it has open P1 defects (#74, #76, #53, #52) and a P2 affecting its confidence channel (#77), so a
  reading stored today would be wrong in a way no later version could repair.
- **Any score, weight or probability.**

## Storage

At `~/.claude/review-loop.stats.jsonl`, beside the existing `~/.claude/review-loop.local.md`.
Preserved transcripts go under `~/.claude/review-loop-transcripts/`. Never `${CLAUDE_PLUGIN_ROOT}`,
which the marketplace replaces on update. Never inside a repository under review — § Learning capture
already writes a narrative journal there, and this log is deliberately separate: that one is prose and
per-repo, this one is structured and global.

The writer refuses if the resolved path is inside a git work tree, and creates files with mode 0600.

`~/.claude` is not itself a git work tree on the reference host; the dotfiles repository symlinks
individual paths into it, so a new file there is not picked up by that repository. On a host where
`~/.claude` is a work tree, the refusal above applies.

One `write()` per record under `O_APPEND`. A record is bounded at 4096 bytes. **Overflow is handled by
field elision, not byte truncation**: the writer drops `transcript`, then `cwd`, then `base` and
`head`, then reviewer `model` values, in that order, until the record fits, then adds
`"elided": ["<field>", ...]` and serialises. A byte-truncated record would not parse, and the
concurrency test below requires every line to parse. Atomicity of concurrent appends at that size is a
property of the local filesystem, not a portable guarantee, so that test is the actual check.

A reader ignores unknown fields and skips unknown `schema` values. Field additions do not bump
`schema`; the skip path exists for corruption, not for evolution.

## Nothing is displayed

No score, count or analysis is shown to the author during a session or at run end. Displaying anything
changes what the author attends to, and the marks are the data.

One exception. The stopping rule below is a number the design has pre-committed to acting on, and
nothing else would compute it. **A `SessionStart` hook evaluates it and, when a window has resolved
against the rule, prints one line naming the window and the ratio.** It is otherwise silent. This
concerns the author's own habit, not the artifact, so seeing it cannot bias a mark already made or
not made. Without a trigger the rule would fail exactly as the deleted `abandoned` field did.

## The one stopping rule

> **Over any three consecutive months that each contain at least eight sessions, if fewer than half of
> all sessions contain at least one mark, the marking habit was not adopted and this is abandoned.**

Three consecutive months, so leave or a stretch of non-review work cannot end it. Eight sessions
minimum, so it does not resolve on two or three observations. The denominator is all sessions, not
only those containing a run, because the hook is global.

**The rule confounds two things, and the author decides between them.** Marks fire when the model
fails, so a genuinely good quarter produces few marks and reads the same as an abandoned habit. The
rule therefore reports rather than acts: when a window resolves against it, the author is told, and
the author decides whether the cause was the habit or the world. Automating that decision would let a
good quarter kill the project.

## Deferred, with the reason

- **A label channel.** Asking the author at run end how the model behaved would fire only for runs
  that reached a review-loop, so a bad day that stopped work earlier would be recorded as absent
  rather than bad. It also has no independent reference: the marks and a verdict minutes later are one
  observer reporting one impression twice.
- **Weights, scores, thresholds, validation tests.** No data exists to fit them to.
- **A completeness check for loop-written records.** The `round` records are emitted by the agent whose
  behaviour is of interest, so a degraded model is the one most likely to skip them. Sequential `round`
  numbers reveal a gap inside a run; a wholly missing run is not detected. A known hole with no
  proposed fix.
- **Finding identity**, for tracking a reviewer that re-raises the same item across rounds. It is the
  reviewer-side analogue of `#again` and it is real; `still_open` counts alone cannot express it.
- **Recording an unexplained reversal.** § Facilitator discipline treats it as a sycophancy flag. It is
  a time-of-run judgement, so the transcript is the only record, and only for marked sessions.

## Testing

- Each token in a message produces one `mark` at the right tier; a message with none produces none; a
  token in a fenced code block produces none; two distinct tokens produce one record at the stronger
  tier.
- A prompt carrying `agent_type` produces no `mark`.
- The first mark in a session creates the hard link; a later mark in the same session does not create
  a second; a link across filesystems fails and records `preserved: false`.
- The hook writes nothing to stdout on every path, including its error paths.
- With `REVIEW_LOOP_STATS=0`, neither writer writes, and a session where only one writer sees the
  variable records `stats_enabled` accordingly.
- With the resolved path inside a git work tree, the writer exits non-zero and writes nothing.
- Newly created files have mode 0600.
- Two writers appending 1000 records each produce 2000 parseable lines on the target filesystem.
- A record that would exceed 4096 bytes is written with fields elided, parses, and lists them in
  `elided`.
- A reader skips a record with `schema: 99`, reports how many it skipped, and accepts a record
  carrying an unknown field.
- A round on a working-diff target records `uncommitted`; a `--base` target on a tree with modified
  tracked files records `dirty`; the same target on a clean tree records `committed`.
- A round record carries an entry for every enrolled reviewer, including one absent from the host.
- A run where Codex hits its usage limit mid-loop produces `dropped` on that round, no `run_end` for
  that event, and later rounds without Codex.
- A `mark` and a `round` from one session share a `session` value.
- A corpus scan finds no field longer than 64 characters except `cwd` and `transcript`.

## Acceptance criteria

- [ ] The five items under *Blocking verification* are answered against the installed version, in
      writing, before any code is written.
- [ ] The hook writes `mark` records with no model involvement in detection, and is silent.
- [ ] The first mark of a session preserves that session's transcript.
- [ ] The off switch works for both writers, and a mixed state is recorded rather than hidden.
- [ ] The loop writes a `round` record per round through a script, and a `run_end` at each exit path
      that has a call site. The implementation enumerates which of § Exit conditions' paths those are.
- [ ] Nothing is displayed except the stopping-rule line, and only when a window resolves.
- [ ] All tests above pass.
- [ ] The stopping rule is carried into the implementation plan unchanged.

## Open questions

1. Does the session id reach a loop-invoked script through any documented channel? If not, the join
   depends on an undocumented environment variable, and the plan must say so.
2. Is `run` best generated as a random suffix, or as repository plus branch plus timestamp?
3. Preserved transcripts accumulate without bound. Marks are rare by hypothesis, but that hypothesis
   is exactly what the stopping rule tests, so it should not also be the storage plan.
