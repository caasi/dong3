# 016 — review-loop: an observation log

**Status:** Design
**Plugin:** `review-loop`
**Extends:** [003](003-review-loop-headless-codex-design.md), [009](009-review-loop-codex-sandbox-fix-design.md), [014](014-review-loop-reviewer-roster-design.md)
**Source:** [caasi/dong3#56](https://github.com/caasi/dong3/issues/56). That issue's proposal is withdrawn; the evidence for withdrawing it is posted as a comment there.
**Target version:** `review-loop` 0.6.0 → 0.7.0

Unqualified `§` references point to `plugins/review-loop/skills/review-loop/SKILL.md`.

## What this is

A log. It records what the author marks while working, and a small amount of per-round state from
a review-loop run.

**Analysis is out of scope.** Weights, scores, thresholds and validation tests are not designed
here, and must not be designed until real data exists.

**Only one question cannot be deferred: what to record.** State that exists only while a run
happens is gone when the run ends. Everything else can wait.

## What moved

Issue #56 proposed logging rounds-to-convergence as a capability signal. Withdrawn. The count mixes
artifact difficulty, the `K` policy, roster composition and author decisions, and it falls when a
reviewer drops out, so a degraded run scores better. The evidence — a four-repository backtest, two
literature reviews, and an escaped-defect analysis — is posted to #56.

What a person notices when a model is unreliable is in the interaction: an instruction dropped, a
point corrected twice, a claim reasserted after refutation. The reference is the session's own
earlier state.

## The rule that decides the schema

> **Record what cannot be reconstructed. Point at everything else.**

An earlier draft recorded about forty fields per round. Most of them summarised judgements the loop
had already stated in its own output, and that output is in the session transcript on disk. A
summary of a substrate is worth less than a pointer to the substrate.

So three things are genuinely gone at run end:

1. **The author's marks.** Never written anywhere else.
2. **The pointers** that let the substrate be found again.
3. **The transcript itself**, which is on a retention clock.

Point 3 is a real limit, stated rather than solved: the transcript directory holds a few hundred
files and prunes at around thirty days. Anything recoverable only from a transcript expires with
it. Choosing which fields to promote into the log ahead of that expiry is an analysis decision,
and analysis is deferred. The small set below is therefore what is cheap, short-lived, and
independent of the transcript's contents.

## Marks

    #redo    the whole output is unusable
    #again   this point was already corrected once
    #fix     one specific error

A `UserPromptSubmit` hook matches these and appends a record.

Matching rules:

- A token counts only as a whitespace-delimited word.
- Fenced code blocks are skipped. This needs fence tracking, not a bare regular expression.
- Inline code spans are **not** skipped. This is a known false-positive source and is accepted for
  now; a message discussing the tokens will produce marks.
- If a message carries more than one distinct token, the strongest wins: `redo`, then `again`,
  then `fix`. Repeats of one token in one message count once.
- **The hook writes nothing when the payload carries `agent_type`.** Subagent prompts are composed
  by a model, and § Facilitator discipline requires reviewer text to be quoted verbatim, so a
  reviewer's own text can contain these tokens. Without this rule a machine-authored token would be
  recorded as an author mark, and the claim that no model takes part in detection would be false.
- **The hook writes nothing to stdout.** A `UserPromptSubmit` hook's stdout is added to the prompt
  context, so any output would enter the session and change what the author attends to.

`#` is used because `!` already runs a shell command in this harness.

### Blocking verification before implementation

Confirm against the installed Claude Code version, not from memory:

- that `UserPromptSubmit`, `SessionStart` and `SessionEnd` exist;
- **what each payload actually contains.** An earlier draft assumed the prompt hook could supply the
  model id, reasoning effort, fast flag, turn index and context usage. It cannot. `SessionStart` and
  `SessionEnd` appear to carry `model` only as an optional field, and to carry no reasoning-effort
  or fast flag at all, so those two fields have no verified source and are not in the schema below;
- **whether `UserPromptSubmit` stdout is injected**, since the silence rule depends on it;
- **how a script invoked by the loop learns the session id.** The documented channel is the hook
  payload, which a script does not receive. An undocumented environment variable exists on at least
  one host. Without a verified answer the `mark` records cannot be joined to the `round` records,
  and the log is two disconnected halves.

If a hook is unavailable, the fallback is a slash command at higher friction.

### Off switch

Setting `REVIEW_LOOP_STATS=0` disables all writing, from the hook and from the loop. This is the
machine's first always-on prompt hook, so an off switch is required, not optional. Issue #56 asked
for one in its original body.

## Schema

One JSON object per line at `~/.claude/review-loop.stats.jsonl`.

### mark

```json
{"schema": 1, "kind": "mark", "session": "<session_id>", "ts": "2026-07-20T14:22:31Z",
 "tier": "redo | again | fix", "cwd": "<path>", "transcript": "<transcript_path>"}
```

Only fields the hook receives. `transcript` is the handle to everything else about the moment.

An earlier draft allowed an inferred `again`, derived from two `fix` marks on the same topic. It is
removed. "The same topic" was never defined mechanically, and an inference the corpus cannot
separate from a declaration is a silent contamination.

### session

```json
{"schema": 1, "kind": "session", "session": "<id>", "event": "start | end", "ts": "...",
 "transcript": "<path>", "cwd": "<path>", "model": "<id or null>"}
```

Two records per session, so a session that never ends cleanly still has a start. `model` is null
when the payload omits it. Turn counts and durations are not recorded; they are in the transcript,
and nothing consumes them yet.

### round

```json
{"schema": 1, "kind": "round", "session": "<id>", "run": "<globally unique id>", "round": 3,
 "ts": "...", "transcript": "<path>",
 "repo": "<short label, no path separator>", "base": "<sha>", "head": "<sha>",
 "target_state": "committed | uncommitted | dirty", "pr": 42,
 "reviewers": {"claude-opus": {"model": "<id>", "verdict": true},
               "claude-sonnet": {"model": "<id>", "verdict": false},
               "codex": {"model": "<id or null>", "verdict": null,
                         "dropped": "usage-limit | absent | failed | non-review | ghost",
                         "degraded": "ghost-rerun | range-mismatch | resume-last | resume-fresh"}},
 "fix_round": true, "k_signal": 2,
 "codex_form": "native | embedded | n/a",
 "codex_route": "preflight | detector | mismatch | n/a",
 "sandbox": "usable | broken | unknown"}
```

`reviewers` is keyed per **reviewer instance**, not per family. The roster runs two Claude models at
once (§ Reviewer roster), so a bare `claude` key would lose one of them. The key is the enrolment
name from `~/.claude/review-loop.local.md`.

`verdict: null` means the reviewer did not report this round, which § A3 treats as done when the
reviewer is unavailable. `dropped` and `degraded` are absent unless they apply.

`run` must be globally unique. § Codex mechanics allows a PR number or a branch slug as a run id;
both collide across repositories in a single global file.

`k_signal` is null when `fix_round` is false; `K` only ratchets on fix-rounds (§ A3). `k_running`
is not recorded because it is the running maximum of `k_signal` over the run.

`codex_form` records which path ran; `codex_route` records what decided it. Both are needed:
under sticky embedded convergence (§ Codex mechanics) later rounds stay embedded while `sandbox`
may still read `usable`, so form is not derivable from the other two. `route: detector` means a
silent false-clean was caught this round.

`target_state`: `committed` means `head` contains the reviewed content; `dirty` means tracked files
differ from `head`; `uncommitted` means the target was the working diff. **For the last two, what
was reviewed is not recoverable, and the record says so by carrying that value.** An earlier draft
proposed a `snapshot` sha to preserve them. It is dropped: the obvious method produces an
unreferenced object that `git gc` prunes, and it omits untracked files, which § Codex mechanics
requires for an uncommitted target. A snapshot mechanism can be added later; recording a false
handle now would be worse than recording none.

### run_end

```json
{"schema": 1, "kind": "run_end", "session": "<id>", "run": "<id>", "ts": "...",
 "end_reason": "k-dry | copilot-clean | repeat-guard | author-stopped"}
```

`codex-limit` and `codex-failed` are **not** end reasons: § Exit conditions is explicit that a usage
limit stops only the Codex sub-loop. Those events are carried by `dropped` on the round.

`final_round` and `k_final` are not recorded; both derive from the run's `round` records.

An earlier draft also carried `abandoned`, written by a later reconciliation pass. It is dropped.
The value had no trigger, no derivation for its own fields, and could not see a run whose round
writes were missed — which is the failure it existed to make visible. **A run with no `run_end` is
simply a run with no `run_end`**, and any later reader can treat it as unfinished. That is the same
information without a mechanism that cannot deliver it.

### Not recorded

- **Verdict text.** § A3's verdict object carries `still_open` and `reason`; only the boolean is taken.
- **Any path, diff, prompt or finding text.** A mark carries its tier and timestamp, never the message.
- **Findings counts, cross-critique outcomes, reproduction and dismissal counts, tier
  classifications, `suspected_drift`, direction-guard details, author A0 and T2/T3 decisions.** All
  of these are stated in the loop's own output and are therefore in the transcript, which the
  records point at. They were in an earlier draft because an analysis that no longer exists wanted
  them. If a later analysis needs one past the transcript's retention, it is added then, and the
  loss of the earlier period is accepted.
- **Any derived measurement**: effect profile, diff size, file counts, test presence. These are
  recomputed from the commit range when `target_state` is `committed`. `fxrank` is the case in
  point: it has open P1 defects (#74, #76, #53, #52) and a P2 affecting its confidence channel
  (#77), so a reading stored today would be wrong in a way no later version could repair.
- **Any score, weight or probability.**

## Storage

At `~/.claude/review-loop.stats.jsonl`, beside the existing `~/.claude/review-loop.local.md`. Never
`${CLAUDE_PLUGIN_ROOT}`, which the marketplace replaces on update. Never inside a repository under
review — § Learning capture already writes a per-run journal there, and this file is deliberately
separate from it: that journal is narrative and in-repo, this log is structured and global.

The writer refuses if the resolved path is inside a git work tree, and creates the file with mode
0600.

`~/.claude` is not itself a git work tree on the reference host; the dotfiles repository symlinks
individual paths into it, so a new file there is not picked up by that repository. On a host where
`~/.claude` is a work tree, the refusal above applies.

One `write()` per record under `O_APPEND`. Records are bounded at 4096 bytes; a record that would
exceed the bound is written truncated with `"truncated": true` rather than dropped. Atomicity of
concurrent appends at that size is a property of the local filesystem, not a portable guarantee, so
the concurrency test below is the actual check. Fields are append-only; a reader ignores unknown
fields and skips unknown `schema` values. The file is never truncated; a rotation copies to a dated
sibling.

## Nothing is displayed

No score, count or analysis is shown to the author during a session or at run end. Displaying
anything changes what the author attends to, and the marks are the data.

One exception, because the alternative is worse. The stopping rule below is a number the design has
pre-committed to acting on, and nothing would compute it otherwise. A one-shot command prints that
ratio and its denominator, and nothing else. It concerns the author's own habit, not the artifact,
so seeing it cannot bias a mark that was already made or not made.

## The one stopping rule

> **Over any three consecutive months that each contain at least eight sessions, if fewer than half
> of all sessions contain at least one mark, the marking habit was not adopted and this is
> abandoned.**

Three consecutive months, so one month of leave or of non-review work cannot end the project. A
minimum of eight sessions, so the rule does not resolve on two or three observations. The
denominator is **all sessions**, not only those containing a review-loop run, because the hook is
global and the habit being tested is global.

This is written down now because it is the outcome easiest to dismiss without acting on it later,
and because it tests the one assumption nobody has tested: that the author sustains marking.

## Deferred, with the reason

- **A label channel.** An earlier draft asked the author at run end how the model had behaved. It
  would fire only for runs that reached a review-loop, so a bad day that stopped work earlier would
  be recorded as absent rather than bad — the survivorship bias that sank the original proposal. It
  also had no independent reference: the marks and a verdict minutes later are one observer
  reporting one impression twice.
- **Weights, scores, thresholds, validation tests.** No data exists to fit them to.
- **A completeness check for loop-written records.** The `round` records are emitted by the agent
  whose behaviour is of interest, so a degraded model is the one most likely to skip them.
  Sequential `round` numbers reveal a gap inside a run; a wholly missing run is not detected. This
  is a known hole with no proposed fix.
- **A snapshot for non-committed targets**, and **finding identity** for tracking a reviewer that
  re-raises the same item across rounds. Both are real; neither is needed to start recording.

## Testing

- Each token in a message produces one `mark` at the right tier; a message with none produces none;
  a token in a fenced code block produces none; two distinct tokens produce one record at the
  stronger tier.
- A prompt carrying `agent_type` produces no `mark`.
- The hook writes nothing to stdout under every path, including its error paths.
- With `REVIEW_LOOP_STATS=0` set, neither the hook nor the loop writes anything.
- With the resolved path inside a git work tree, the writer exits non-zero and writes nothing.
- A newly created file has mode 0600.
- Two writers appending 1000 records each produce 2000 parseable lines on the target filesystem.
- A record exceeding 4096 bytes is written truncated and carries `"truncated": true`.
- A reader skips a record with `schema: 99` and reports how many it skipped.
- A run where Codex hits its usage limit mid-loop produces `dropped` on that round, no `run_end` for
  that event, and later rounds without Codex.
- A `mark` and a `round` from the same session share a `session` value.
- A corpus scan finds no free-text field except `cwd` and `transcript`, and no field longer than 64
  characters except those two.

## Acceptance criteria

- [ ] The four items under *Blocking verification* are answered against the installed version, in
      writing, before any code is written.
- [ ] The hook writes `mark` records with no model involvement in detection, and is silent.
- [ ] The off switch works for both writers.
- [ ] The loop writes a `round` record per round through a script, and a `run_end` at each exit path
      that has a call site.
- [ ] Nothing is displayed except the stopping-rule ratio, on request.
- [ ] All tests above pass.
- [ ] The stopping rule is carried into the implementation plan unchanged.

## Open questions

1. Does the session id reach a loop-invoked script through any documented channel? If not, the join
   depends on an undocumented environment variable, and that dependency must be stated in the plan.
2. Is `run` best generated as a random suffix, or as `repo` plus branch plus a timestamp? It must be
   unique across repositories in one file.
3. The transcript retention period is observed, not documented. If it is shorter than assumed, more
   fields must be promoted into the log sooner, and this spec should be revisited rather than
   patched.
