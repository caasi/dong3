# 016 — an observation log for review-loop

**Status:** Design
**Plugin:** `review-loop`
**Extends:** [003](003-review-loop-headless-codex-design.md), [009](009-review-loop-codex-sandbox-fix-design.md), [014](014-review-loop-reviewer-roster-design.md)
**Source:** [caasi/dong3#56](https://github.com/caasi/dong3/issues/56). That issue's proposal is withdrawn; see *What moved*.
**Target version:** `review-loop` 0.6.0 → 0.7.0

Unqualified `§` references point to `plugins/review-loop/skills/review-loop/SKILL.md`.

## What this is

A log. It records what happens during a review-loop run and what the author marks while working.
It computes nothing, displays nothing, and changes no exit rule.

**Analysis is deliberately out of scope.** Weights, scores, thresholds and validation tests are not
designed here and must not be designed until real data exists. Designing them now means fitting
machinery to a corpus nobody has seen.

**Only one thing cannot be deferred: what gets recorded.** A field omitted now cannot be added
retrospectively, because the state it would hold is gone when the run ends. That is the whole
reason this spec exists ahead of any analysis.

## What moved

Issue #56 proposed logging rounds-to-convergence as a capability signal. Withdrawn. The count mixes
artifact difficulty, the `K` policy, roster composition and author decisions, and it falls when a
reviewer drops out, so a degraded run scores better.

What a person actually notices, when a model is unreliable on a given day, is in the interaction:
an instruction dropped, a point corrected twice, a claim reasserted after refutation. The reference
is the session's own earlier state, which is on record. So the log records the interaction, and the
loop's own round state, and stops there.

Supporting material for the withdrawal — the four-repository backtest, the literature review, and
the numbers quoted below — is in the issue thread and its direction-change comment. Those numbers
are not repeated here, because this spec does not rest on them.

## What is recorded

Two sources write to one file.

1. **A hook** records the author's marks, from tokens typed in messages the author was sending anyway.
2. **A script, called by the loop**, records per-round state.

### Marks

    #redo    the whole output is unusable
    #again   this point was already corrected once
    #fix     one specific error

A `UserPromptSubmit` hook matches these by regular expression and appends a record. **No model is
involved in detection.** The author is declaring the event, not estimating it.

Matching rules, so the hook is implementable without invention:

- A token counts only when it stands alone as a whitespace-delimited word.
- Text inside a fenced code block is ignored. This needs fence tracking, not a bare regular
  expression; the implementation must scan for fences first.
- If a message carries more than one distinct token, the strongest wins: `redo` over `again` over
  `fix`. Repeats of the same token in one message count once.

**Blocking verification before implementation.** Confirm against the installed Claude Code version
that `UserPromptSubmit` exists **and what its payload contains**. An earlier draft assumed the hook
could supply the model id, the reasoning effort, the fast flag, the turn index and context usage.
It cannot: the documented payload carries `session_id`, `prompt_id`, `transcript_path`, `cwd`,
`permission_mode` and `hook_event_name`. The schema below therefore takes from the hook only what
the hook has, and everything else is joined later on `session`. If `UserPromptSubmit` is absent, the
fallback is a slash command at higher friction.

`#` is used because `!` already runs a shell command in this harness.

### Per-round state

Written by a script, on the same pattern as `copilot.sh` and `pr-comments.sh` — never as an
instruction in prose. A prompt instruction is skipped nondeterministically, and the model most
likely to skip it is a degraded one, which is the condition of most interest. Sequential `round`
numbers make a gap inside a run visible.

## Schema

One JSON object per line, at `~/.claude/review-loop.stats.jsonl`.

### mark

```json
{"schema": 1, "kind": "mark", "session": "<session_id>", "ts": "2026-07-20T14:22:31Z",
 "tier": "redo | again | fix", "inferred": false, "cwd": "<path>"}
```

Only fields the hook actually receives. Model, effort and context are **not** here; they are joined
through `session` against the records below.

`inferred` marks the one permitted guess: two `fix` marks on the same topic may be recorded as an
`again`. Any later analysis can then run with and without it. The rule for "same topic" is not
settled and is listed as an open question; until it is, only explicit marks are written and
`inferred` is always `false`.

### session

```json
{"schema": 1, "kind": "session", "session": "<id>", "date": "2026-07-20",
 "event": "start | end", "ts": "...",
 "model": "<id>", "effort": "<level>", "fast": false,
 "turns": 96, "duration_min": 210}
```

Written by `SessionStart` and `SessionEnd` hooks, whose availability is part of the same blocking
verification. Two records per session, so a session that never ends cleanly still has a start.

### round

```json
{"schema": 1, "kind": "round", "session": "<id>", "run": "<id>", "round": 3, "ts": "...",
 "repo": "<short label, no path separator>", "base": "<sha>", "head": "<sha>",
 "target_state": "committed | uncommitted | dirty", "snapshot": "<sha or null>",
 "pr": 42, "target_kind": "code | spec | plan | doc | mixed",
 "enrolled": ["claude", "codex"], "live": ["claude"],
 "models": {"claude": "<id>", "codex": "<id or null>"},
 "dropped": {"codex": "usage-limit | absent | failed | non-review"},
 "degraded": {"codex": "ghost-rerun | range-mismatch | resume-last | resume-fresh"},
 "verdicts": {"claude": true, "codex": null},
 "still_open_count": {"claude": 0},
 "suspected_drift": ["claude"],
 "fix_round": true, "k_signal": 2, "k_running": 2,
 "findings": {"raised": {"claude": 5}, "survived_crosscritique": {"claude": 3},
              "reproduced": 2, "unreproduced": 1, "dismissed": 1,
              "resolved": {"t1": 2, "t2": 1, "t3": 0}},
 "crosscritique": {"ran": true, "attacked": true},
 "checks": {"ran": true, "failed": false, "kind": ["test"]},
 "codex_form": "native | embedded | n/a",
 "codex_route": "preflight | detector | mismatch | n/a",
 "sandbox": "usable | broken | unknown",
 "guard": {"proposed": false, "accepted": null, "model": null, "verdict": null},
 "author": {"a0_override": false, "t2t3_decisions": 2, "t2t3_overrides": 1}}
```

`k_signal` is null when `fix_round` is false; `K` only ratchets on fix-rounds (§ A3).

`snapshot` holds the sha of a throwaway commit or tree written for an `uncommitted` or `dirty`
target. Without it `head` does not contain what was reviewed, and nothing about that run can be
recomputed later. Runs with `snapshot: null` and a non-`committed` `target_state` are permanently
non-derivable; the writer must record that rather than hide it. Design-artifact review of unpushed
work is a first-class case (§ Codex mechanics), not an edge case, so refusing these runs is not an
option.

`codex_form` records which path actually ran. `codex_route` records what decided it. Both are
needed: under sticky embedded convergence (§ Codex mechanics) later rounds stay embedded while
`sandbox` may still read `usable`, so form is not derivable from route and sandbox.

`reproduced` / `unreproduced` / `dismissed` close the gap between `raised` and `resolved`. § A3
requires reproduction before acting and requires an unreproduced finding to be surfaced as such. A
reviewer producing many irreproducible findings is a distinct event from a reviewer producing few
findings, and after the run the two are indistinguishable without these counts.

### run_end

```json
{"schema": 1, "kind": "run_end", "run": "<id>", "ts": "...",
 "end_reason": "k-dry | copilot-clean | repeat-guard | author-stopped | abandoned",
 "final_round": 5, "k_final": 2}
```

`codex-limit` and `codex-failed` are **not** end reasons. § Exit conditions is explicit that a Codex
usage limit stops only the Codex sub-loop and the rest of the loop continues. Those events are
already carried by `dropped` on the round where they happen.

`abandoned` has no call site — it is the absence of one. It is written by reconciliation, not by the
loop: a `run` with no `run_end` and no new round for seven days is closed as `abandoned` by the same
one-shot command that the author runs to read the log. This is stated because the earlier draft
listed the value with nothing able to write it.

### Why each recorded field is unrecoverable

| Field | Reason |
|---|---|
| marks | The author's judgement at that moment. Nothing else captures it. |
| `verdicts`, `still_open_count` | Stated per round per reviewer (§ A3). Only the loop sees them. |
| `enrolled` / `live` / `dropped` / `degraded` | § A3 treats an unavailable reviewer as done. A quiet round on a degraded panel is a different event, and afterwards the two look identical. A `resume-fresh` fallback means Codex lost its memory of earlier rounds. |
| `k_signal` / `k_running` | The facilitator's judgement of whether each resolved finding had a runnable check. Never written down. |
| `codex_form` / `codex_route` / `sandbox` | Native `review` silently false-cleans on a broken sandbox host against unpushed commits. `route: detector` means a false-clean was caught this run. |
| findings counts | Cross-critique, reproduction and dismissal are facilitator judgements made at the time. |
| `models`, `guard.model` | The roster's models change over months. The direction guard is the most expensive reviewer, so its identity matters most. |
| `author` | The A0 pass and the T2/T3 decision are the author acting inside the loop, at no cost. |
| `snapshot` | For a non-committed target this is the only handle on what was reviewed. |
| `base` / `head` / `repo` / `pr` | The join key, and what links a run to its forge reviews. |

### Not recorded

- **`still_open` and `reason` text** from the verdict object. Only the boolean and the count.
- **Any path, diff, prompt or finding text.** A mark records its tier and timestamp, never the message.
- **Any derived measurement**: effect profile, diff size, file counts, test presence. These are
  recomputed from the commit range, so the current defects of the deriving tool are not frozen into
  the corpus. `fxrank` is the case in point: it has open P1 defects (#74, #76, #53, #52) and a P2
  affecting its confidence channel (#77), so a reading stored today would be wrong in a way no later
  version could repair.
- **Any score, weight or probability.** See *What this is*.

`repo` is a short label with no path separator, not a full path. An earlier draft stored a salted
hash; that protected nothing, because a full commit sha sits in the same record and identifies a
public repository through any code search.

## Storage

Beside the existing `~/.claude/review-loop.local.md`. Never `${CLAUDE_PLUGIN_ROOT}`, which the
marketplace replaces on update. Never inside a repository under review.

Enforced, not documented: the writer refuses if the resolved path is inside a git work tree, and
creates the file with mode 0600. `~/.claude/` holds files symlinked into a dotfiles repository that
is pushed, so this file must be excluded there.

One `write()` per record under `O_APPEND`, with records bounded at 4096 bytes so a single write is
atomic. Fields are append-only; a reader ignores unknown fields and skips unknown `schema` values.
The file is never truncated; if it is rotated, it is copied to a dated sibling.

## Nothing is displayed

No score, no count and no analysis is shown to the author during a session or at run end.

The reason is not that a number would gain unearned authority, though it would. It is that
**displaying anything contaminates the collection**: it changes what the author attends to and how
they mark, and the marks are the data.

An offline one-shot command may read the log. It is the same command that performs the `abandoned`
reconciliation above. It prints records, not conclusions.

## The one stopping rule

Everything else about analysis is deferred, but not this, because a log nobody feeds is a cost with
no return.

> **If, in any month after the first, fewer than half the sessions that contained a review-loop run
> also contain at least one mark, the marking habit has not taken and this is abandoned.**

This is written down now because it is the outcome easiest to explain away later, and because it
tests the one assumption the whole design rests on and nobody has tested: that the author sustains
marking at all.

## Deferred, with the reason

- **A label channel.** An earlier draft asked the author, at run end, how the model had behaved. It
  is dropped for now. It would only fire for runs that reached a review-loop, so a bad day that
  stopped work before that point would be recorded as absent rather than bad — the same
  survivorship bias that sank the original #56 proposal. It also has no independent reference: the
  author's marks and the author's verdict minutes later are one observer reporting one impression
  through two channels. Reconsider only after the marks have survived the stopping rule above.
- **Weights, scores, thresholds and validation tests.** No data exists to fit them to.
- **Phase B facilitator state** — Copilot comment tiering and the B5 repeat-guard judgement. These
  are time-of-run judgements and are genuinely unrecoverable, so this is a knowing loss, taken to
  keep the first version small.

## Testing

- A message containing each token produces exactly one `mark` with the right tier; a message with
  none produces none; a token inside a fenced code block produces none; a message with two distinct
  tokens produces one record at the stronger tier.
- With the resolved path inside a git work tree, the writer exits non-zero and writes nothing.
- A newly created file has mode 0600.
- Two writers appending 1000 records each produce 2000 parseable lines.
- A reader skips a record with `schema: 99` and reports how many it skipped.
- A run where Codex hits its usage limit mid-loop produces `dropped` on that round and **no**
  `run_end` for that event; the loop continues.
- A run abandoned mid-way gains `end_reason: abandoned` when the reconciliation command is run
  seven days later, and not before.
- An `uncommitted` target either records a `snapshot` sha or records `snapshot: null`, and never
  records a `head` that does not contain the reviewed content without saying so.
- A corpus scan finds no free-text field longer than 64 characters, and no field containing a path
  separator except `cwd`.

## Acceptance criteria

- [ ] `UserPromptSubmit`, `SessionStart` and `SessionEnd` are confirmed present, and their payloads
      confirmed to contain the fields the schema takes from them.
- [ ] The hook writes `mark` records with no model involvement in detection.
- [ ] The loop writes `round` records through a script at every round, and `run_end` at every exit
      path that has a call site.
- [ ] The reconciliation command closes abandoned runs and is the only writer of that value.
- [ ] Nothing is displayed to the author.
- [ ] All tests above pass.
- [ ] The stopping rule is carried into the implementation plan unchanged.

## Open questions

1. What defines "the same topic" for an inferred `again`? Until this is answered mechanically, the
   inference is not implemented and `inferred` is always false. The declared `#again` has the same
   ambiguity — it asserts a relation to an earlier turn, which the author can misremember — so the
   answer should cover both.
2. How does the writer obtain a `snapshot` for an uncommitted target without disturbing the work
   tree? A `git stash create` style throwaway commit is the obvious candidate and is unverified.
3. `task_kind` is dropped from the schema for now, because the author would have to declare it and
   nothing consumes it yet. Is it recoverable later from the commit range alone?
4. Is there a completeness check for the loop's own writes? The records are emitted by the agent
   whose behaviour is of interest, so a degraded model is the one most likely to skip them.
   Sequential round numbers catch a gap inside a run; a wholly missing run is not caught by
   anything proposed here.
