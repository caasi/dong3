# 016 — an observation log for "is the model reliable today?"

**Status:** Design
**Plugin:** `review-loop`
**Extends:** [014](014-review-loop-reviewer-roster-design.md)
**Source:** [caasi/dong3#56](https://github.com/caasi/dong3/issues/56). That issue's proposal is **withdrawn**; see *What moved, and why*.
**Target version:** `review-loop` 0.6.0 → 0.7.0

## What this changes, in one paragraph

A person can tell within a few hours that a model is not reliable today. This spec records the
observations that impression rests on, so the impression becomes explicit, timestamped and
comparable across months. It records two indicators: **the author's own corrections and redo
requests**, which are strong, and **the number of review rounds**, which is weak. It computes
nothing during collection and displays nothing to the author. `K` keeps sole authority over
termination. No loop behaviour changes.

## What moved, and why

Issue #56 proposed logging rounds-to-convergence as a signal of model capability. Four rounds of
investigation, four repositories, 128 merged pull requests and two literature reviews say that
target cannot work.

- The round count mixes artifact difficulty, the `K` policy, roster composition and author
  decisions. It also falls when a reviewer drops out, so a degraded run scores better.
- A review loop is a **repair mechanism**. Its convergence is therefore the quantity that hides a
  capability change rather than showing it. Anthropic's postmortem of three 2025 inference bugs
  reports that its own evaluations missed a real degradation, "in part because Claude often
  recovers well from isolated mistakes"
  ([source](https://www.anthropic.com/engineering/a-postmortem-of-three-recent-issues), 2025-09-17).
  That is a statement about model evaluation, not about this loop, so read it as an analogy that
  motivated the change, not as a measurement of it.
- Ground truth about defects in the artifact is not obtainable at this scale. Of 267 public
  degradation claims examined, 229 contained no measurement and 38 were scored after the fact.
  None used a task set with a criterion declared in advance.

**The error was the target, not the method.** The investigation asked "is this artifact clean",
which needs ground truth nobody has. The impression a person actually forms is about **the
interaction**, and its reference point is the session's own earlier state, which is on record.

An instruction the author gave at turn 5 is a rule fixed before the search. A correction the author
issues at turn 40 is the author acting as the authority on what they asked for, not as an estimator
of code quality. Both are available immediately, in volume, at no cost.

## What this instrument is for

> It does not need to be more accurate than the author's intuition. It needs to make that intuition
> explicit, timestamped and comparable over time.

The author can already tell that today is worse. What they cannot do is answer, six months later,
whether that period really had more such days or whether memory reshaped it. That is the whole
purpose. A design that promises more than this is overselling a corpus of a few hundred sessions.

## The two indicators

### Primary — the author's corrections and redo requests

Tiered, because the strengths differ by more than the labels suggest.

| Event | What it means | Strength |
|---|---|---|
| **Redo** | the whole output is unusable; start again | strongest |
| **Repeat** | the same point is corrected a second time | very strong |
| **Fix** | one specific error is identified | strong |

**Repeat is the most valuable of the three, because it is least sensitive to task difficulty.** A
hard task produces more corrections; that is a property of the task. Failing again after being
corrected is measured against the model's own state minutes earlier, so the task cancels out.

### Secondary — review rounds

Recorded, and explicitly weak.

An earlier draft of this design excluded the round count as fatally confounded. That was an
overcorrection. Confounded is not the same as uninformative; it means **weak**. A weak sensor is
safe to include when its likelihood ratio is set honestly near 1. The danger is compounding, and
compounding is controlled by setting the ratio low, not by discarding the sensor.

## Capture

**The author marks the event. The tool does not infer it.**

Inferring "was that a correction" from a transcript needs semantic judgement, which returns the
design to opinion. The author marking it is the same principle as a rule fixed in advance: the
author is not estimating, the author is **defining**. There is no discretion to get wrong.

**Mechanism:** a short token inside a message the author was already going to send.

    #redo    the whole output is unusable
    #again   this was already corrected once
    #fix     one specific error

Cost is about five characters and no extra message. A `UserPromptSubmit` hook matches the tokens by
regular expression and appends a record. **No model is involved in detection at any point.**

> **Blocking verification before implementation.** `UserPromptSubmit` must be confirmed to exist and
> to receive the raw prompt text. This repository's own guidance records a past error of proposing a
> hook event that Claude Code does not have. Confirm against the installed version, not from memory.
> If the hook is unavailable, the fallback is a slash command, at higher friction, and the marking
> rate condition in § Failure conditions becomes the first thing at risk.

**The `#` prefix is chosen because `!` already runs a shell command in this harness.**

## The organising rule

> **Record only what cannot be reconstructed later.**

Derived measurements are recomputed, never stored, because the tools that derive them improve.

**Worked example — `fxrank`.** An effect profile of changed code is a plausible covariate: a quiet
review of pure, effect-free code plausibly means more than a quiet review of effect-heavy code,
because more of that artifact was constrained before review. But `fxrank` has open P1 defects that
any stored reading would freeze into the corpus — cross-language comparability is inverted (#74),
the confidence channel is effectively binary (#77), qualified pure calls are over-smeared (#76),
test code leaks into production ranking (#53), and name heuristics misclassify pure predicates
(#52). So the profile is **not** stored. The commit range is stored, and the profile is computed
later by whichever version is current.

**Precondition.** Reconstruction needs the recorded commits to stay reachable. This project's
conventions support that: local branches are not pruned eagerly, and squash merges into primary
branches are avoided. If that changes, the derivable half of this design is lost.

## Schema

One JSON object per line, at `~/.claude/review-loop.stats.jsonl`. Four record kinds.

### mark — written by the hook

```json
{"schema": 1, "kind": "mark", "session": "<id>", "ts": "2026-07-20T14:22:31Z",
 "tier": "redo | again | fix", "turn": 47,
 "model": "<session model id>", "effort": "<level>", "fast": false,
 "context_turns": 47, "context_pct": 0.62}
```

### session — written at session end

```json
{"schema": 1, "kind": "session", "session": "<id>", "date": "2026-07-20",
 "turns": 96, "duration_min": 210,
 "models": ["<id>"], "effort": "<level>", "fast": false,
 "task_kind": "code | prose | mixed | ops",
 "marks": {"redo": 1, "again": 3, "fix": 7},
 "impression": "good | normal | off | null"}
```

`impression` is the author's own one-token verdict on the session, and it is the **label** the
failure conditions test against. It is optional, and null is recorded rather than assumed.

### run — written by the loop, one per round

```json
{"schema": 1, "kind": "run", "session": "<id>", "run": "<id>",
 "repo": "<plain path or short label>", "base": "<sha>", "head": "<sha>",
 "target_state": "committed | uncommitted | dirty",
 "pr": 42,
 "round": 3, "ts": "2026-07-20T15:04:00Z",
 "target_kind": "code | spec | plan | doc | mixed",
 "enrolled": ["claude", "codex"], "live": ["claude"],
 "models": {"claude": "<id>", "codex": "<id or null>"},
 "dropped": {"codex": "usage-limit | absent | failed | non-review"},
 "degraded": {"codex": "ghost-rerun | range-mismatch | resume-last | resume-fresh"},
 "verdicts": {"claude": true, "codex": null},
 "still_open_count": {"claude": 0},
 "suspected_drift": ["claude"],
 "fix_round": true, "k_signal": 2, "k_running": 2,
 "findings": {"raised": {"claude": 5}, "survived_crosscritique": {"claude": 3},
              "resolved": {"t1": 2, "t2": 1, "t3": 0}},
 "crosscritique": {"ran": true, "attacked": true},
 "checks": {"ran": true, "failed": false, "kind": ["test"], "uncommitted": false},
 "codex_route": "preflight | detector | mismatch | n/a",
 "sandbox": "usable | broken | unknown",
 "guard": {"proposed": false, "accepted": null, "verdict": null},
 "author": {"a0_override": false, "t2t3_decisions": 2, "t2t3_overrides": 1}}
```

### run_end — written when a run stops

```json
{"schema": 1, "kind": "run_end", "run": "<id>", "ts": "...",
 "end_reason": "k-dry | copilot-clean | repeat-guard | codex-limit | codex-failed | author-stopped | abandoned",
 "final_round": 5, "k_final": 2}
```

Without `end_reason` an abandoned run is indistinguishable from a converged one. In one studied
repository only 11 of 19 multi-round pull requests ended on a dry round; the rest ended because the
author merged. The exit state of an abandoned run is not an exit state.

### Why each recorded field is unrecoverable

| Field | Reason |
|---|---|
| `mark` records | The author's judgement at that moment. Nothing else captures it. |
| `impression` | Same, and it decays within a day. |
| `verdicts`, `still_open_count` | Stated per round per reviewer (§ A3). Only the loop sees them. |
| `enrolled` / `live` / `dropped` / `degraded` | § A3 treats an unavailable reviewer as done. A quiet round on a degraded set is a different event, and afterwards the two look identical. |
| `k_signal` / `k_running` | The facilitator's judgement of whether each resolved finding had a runnable check. Never written down. |
| `codex_route` / `sandbox` | Native `review` **silently false-cleans** on a broken sandbox host against unpushed commits. `detector` means a false-clean was caught this run — the most informative event in the Codex branch. |
| `findings.raised` / `survived_crosscritique` | Cross-critique exists to kill false positives before they become commits. Recording only survivors makes the kill rate permanently unobservable, and that rate is the one measurement this loop can make that published work cannot. |
| `models` | Over 18 months every model in the roster is replaced. Since the question is about model behaviour, this is the covariate whose absence would make the corpus unable to answer it. Self-reported, and recorded as such. |
| `author` | The A0 pass and the T2/T3 decision are the author acting inside the loop, at no cost. |
| `target_state` | For an uncommitted target, `head` does not contain what was reviewed, so every derived field would evaluate against the wrong tree. |
| `base` / `head` / `repo` / `pr` | The join key. It is what makes the derivable set derivable, and what links a run to its forge reviews. |

### Not recorded

- **`still_open` and `reason` text from the verdict object.** Only the boolean and the count.
- **Any path, diff, prompt, or finding text.** Marks record the tier and the turn number, never the
  message.
- **Any derived measurement**: effect profile, diff size, file counts, test presence.
- **Any computed probability.**

The repository identifier is stored **in plain form**. An earlier draft hashed it with a salt. That
protects nothing, because a full commit sha sits in the same record and identifies a public
repository through any code search. The salt also created an unanswered question about where a
cross-machine secret lives, and a way to orphan every record written before a rotation. The log is
identifying by construction; the protection is the enforcement below.

## Storage

Path `~/.claude/review-loop.stats.jsonl`, beside the existing `~/.claude/review-loop.local.md`.
Never `${CLAUDE_PLUGIN_ROOT}`, which the marketplace replaces on update. Never inside a repository
under review.

Enforced, not documented: the writer refuses if the resolved path is inside a git work tree, and
creates the file with mode 0600. `~/.claude/` holds files symlinked into a dotfiles repository that
is pushed, so this file must be excluded there.

One `write()` per record under `O_APPEND`, with a stated line-size bound, so two loops in two
worktrees cannot interleave. Fields are append-only; a reader ignores unknown fields and skips
unknown `schema` values. The file is never rotated in place; if it is rotated, it is copied to a
dated sibling and never truncated.

## No inference during collection

Nothing computes a score during a session, and nothing is displayed to the author.

The reason is not that a displayed number would gain unearned authority, though it would. It is
that **displaying it contaminates the collection**. It would change what the author attends to and
how they mark. The marks and the impression are the labels, so a corpus gathered while a number was
on screen cannot afterwards be used to test that number.

An offline command may read the log and print an analysis. It must print every parameter it used
beside the result and label itself experimental.

### Known failure modes, recorded so they are not rediscovered as surprises

1. **Weak evidence compounds.** Weakness limits the rate, not the destination. A likelihood ratio of
   1.2 per round reaches a posterior of 0.97 from a prior of 0.5 in 20 rounds. "Weak, therefore
   safe" is false.
2. **Misspecification here is directional.** Review sensors err toward quiet. Random errors partly
   cancel across observations; directional errors accumulate.
3. **The marking rate is itself a behaviour that can drift.** A quiet week may mean a good week or a
   week the author stopped marking. § Failure conditions treats this as a first-class risk.
4. **Task difficulty is not controlled.** `again` is the least exposed of the three tiers, which is
   why it is weighted highest. Separating difficulty properly needs a fixed task set re-run
   periodically, compared pairwise. That is out of scope here and noted as future work.

## Confounders recorded as covariates

`context_turns` and `context_pct`, because a long session degrades for reasons unrelated to the
model. `model`, `effort` and `fast`, because these change within and between sessions. `task_kind`,
declared by the author, coarse on purpose.

## Failure conditions, pre-registered

Fixed now, before any weighting exists, because they are what make this a design rather than an
open-ended activity.

| Test | Fails if | Needs |
|---|---|---|
| **T0 — marking survives** | in any month after the first, marked sessions fall below 50 percent of sessions containing at least one `run` record | the log alone |
| **T3 — non-informativeness** | the session mark count correlates with turn count above 0.9; the signal then measures session length, not reliability | 50 sessions |
| **T4 — parameter dominance** | varying any chosen weight by a factor of 3 moves the session score by more than 0.2 for most sessions | 50 sessions, fixed parameter set |
| **T1 — agreement** | the session score separates `off` sessions from `normal` sessions at an area under the ROC curve whose **lower 95 percent confidence bound** is at or below 0.6 | 40 sessions carrying an impression |
| **T2 — confident and wrong** | among sessions the score called normal, more than 20 percent were marked `off`; minimum subgroup 15 sessions, else "not yet testable" | 40 impressions |

**T3 and T4 must both name the fixed parameter set they run against, pre-registered when the
parameters are first chosen.** Otherwise a failing T3 can be argued away by choosing other
parameters, and the pair becomes unfalsifiable.

**Interim gate at 50 sessions:** run T0, T3 and T4. Any one alone stops the project.

**Verdict horizon: 200 sessions or 12 months, whichever is reached first.**

**Stated in advance because it is the easiest outcome to explain away later:** if at the horizon
there are fewer than 40 sessions carrying an impression, that is a failure verdict. It means the
instrument needs more marking than this workflow sustains.

This target is reachable in a way the withdrawn proposal's was not. The artifact-defect channel
needed roughly 256 merged pull requests for 40 labels, which is about two project lifetimes at
current velocity. Sessions accumulate daily.

## Testing

- **Hook capture:** a message containing each token produces exactly one `mark` record with the
  right tier; a message containing none produces none; a token inside a fenced code block produces
  none.
- **Writer refusal:** with the resolved path inside a git work tree, the writer exits non-zero and
  writes nothing.
- **Mode:** a newly created file is 0600.
- **Concurrency:** two writers appending 1000 records each produce 2000 parseable lines.
- **Schema tolerance:** a reader skips a record with `schema: 99` and reports the count skipped.
- **Round fields:** a run where Codex hits its usage limit mid-loop produces `dropped`, and a
  `run_end` with `end_reason: codex-limit`.
- **No text leakage:** a corpus scan finds no field containing a path separator, a diff marker, or
  more than 64 characters of free text.

## Acceptance criteria

1. `UserPromptSubmit` is confirmed to exist and to receive raw prompt text, or the slash-command
   fallback is implemented instead.
2. The hook writes `mark` records with no model involvement in detection.
3. The loop writes `run` and `run_end` records at every call site, including the paths where a
   reviewer drops out and where the author stops the loop.
4. Nothing is displayed to the author during a session.
5. The offline command prints every parameter beside its result and is labelled experimental.
6. All tests above pass.
7. The failure conditions are copied into the implementation plan unchanged, with the parameter set
   named at the time weights are first chosen.

## Open questions

1. Should `again` be inferable from two `fix` marks on the same topic, or must the author always
   type it? Inference is convenient and it is judgement, which this design otherwise excludes.
2. Where does the session `impression` get asked? A prompt at session end has no reliable trigger,
   and asking the next morning risks it never being answered.
3. `task_kind` is author-declared. Is a four-way split useful, or does it invite unstable
   self-classification that adds noise?
4. Should a `mark` record the turn number only, or also which model output it attaches to when a
   session changed models mid-way?
