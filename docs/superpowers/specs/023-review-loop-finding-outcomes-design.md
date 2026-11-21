# 023 — review-loop: the round line gives the outcome of each finding

Amends the section "What the log is" of `020-review-loop-log-is-a-record-design.md`.
Issue #101. Version 0.17.0.

This file is a reference. It was written after the implementation, the simulation runs and the
first review round, and it records what they showed.

## Intent

The round line gave one number for each reviewer: how many findings it returned. That number
cannot separate a reviewer with many false alarms from a reviewer with many correct findings.
Both give a high count.

The round line now also gives, for each reviewer, how many of its findings this change fixes,
how many the loop rejected, how many the author declined, and how many the author deferred.

## Format

```
… review  project=<slug>  run=<tok>  round=<n>  reviewers=a:3,b:3  outcomes=a:1+1+1+0,b:2+0+0+1
```

The caller gives `outcome=<id>:<accepted>+<rejected>+<declined>+<deferred>`, one argument for each
reviewer. `log.sh` writes one `outcomes=` field after `reviewers=` and before `end=`. The ids are
encoded as in `reviewers=`. The four counts are always given, in this order.

Three decisions fix this form:

- **One field, not one field for each count.** `ll_append` drops a line over 1024 bytes whole,
  `reviewers=` included. The bound keeps each line one `write()` under `O_APPEND`
  (`plans/016-review-loop-observation-log.md`, "Line bound"). The first implementation had
  three fields, `accepted=`, `rejected=` and `declined=`, so each id was written four times. Six
  reviewers with 36-character ids then gave a dropped line, where the `reviewers=` line alone
  fits. With one field, each id is written twice.
- **A line over the bound loses only `outcomes=`.** When the line with `outcomes=` is over
  1024 bytes, `log.sh` writes it without `outcomes=`. So a roster that fits in the 0.16.0 line
  still has its round. Only the outcome counts of that round are lost.
- **The counts are not more parts of `reviewer=`.** A reader takes the reviewer id as the text
  before the last `:`. With a third part, the id of every reviewer changes.
- **`+` joins the counts, not `/`.** The value rule of `ll_scrub` removes `/`, so `10/1/1/0`
  becomes `10110`.

A `log.sh` from before 0.17.0 ignores an unknown key, so an old writer drops `outcome=` without an
error. A line from before 0.17.0 has only `reviewers=`. The lines of the log from before 0.17.0
were not changed: no record holds their outcomes, and a migration would have to invent them.

## The four counts

The four counts are disjoint. For each reviewer, they add up to its `reviewer=` count.

- **accepted**: this change fixes the finding. The facilitator fixed it (T1), chose an approach
  for it (T2), or the author chose an approach for it at the T3 stop, also one that the
  facilitator did not recommend.
- **rejected**: the loop does not act on the finding. For example, it did not reproduce, or
  cross-critique refuted it. An unreproduced finding that nobody acts on is rejected.
- **declined**: at the T3 stop of the round, the author said not to fix it.
- **deferred**: at the T3 stop of the round, the author kept the finding but not for this
  change, for example in a new issue.

The four are different results, so the line keeps them apart, and a summary can give them
different weights. A deferred finding is close to accepted for the question "is this reviewer
useful", because the author kept it. It is not accepted for the question "what did this change
fix". The first implementation had no deferred count. Then a T3 answer such as "open an issue for
it later" fitted none of the counts, and the counts could not add up.

The facilitator gives all four, also when a count is 0. So a reader can tell a count of 0 from a
line without counts. When two reviewers return the same finding, the finding counts for each of
the two, because each reviewer found it on its own.

## When the line is written

The declined and deferred counts are known only after the author answers the T3 message of the
round. So in a round that has a T3 finding, the facilitator writes the line after that answer. If
the author stops the loop at that stop, the round line comes first, then the `end=stopped` line.
The line of a round comes before the reviewers of the next round are dispatched. Without this
rule, a session that ends in the next round loses the line too (run v5 below).

Before 0.17.0, SKILL.md did not say whether the line comes before or after the T3 stop. In the
two control runs below, the facilitator wrote it before the stop.

## Limits

- **A late T2 reversal is not counted.** The author can reverse a T2 decision at a later stop.
  The line of that round is already written, and the log is append-only. So the finding stays
  accepted.
- **Accepted is the judgement of the facilitator, not proof that the finding is correct.** When
  the facilitator rejects a correct finding, the numbers of that reviewer look worse. The
  facilitator is also the agent whose work the log records.
- **An unanswered T3 stop leaves no line.** The line waits for the T3 answer, and the usage rows
  come after the line. If the session ends at that stop with no answer, that round has no line
  and no usage rows. Before 0.17.0, the line was written before the stop.
- **`log.sh` does not check the counts.** It does not check that the four counts add up to the
  `reviewer=` count, or that the value has four parts. A comment in `log.sh` states this, and the
  caller is trusted.
- **A long line loses its outcomes.** Each reviewer adds about 2 × (encoded id length) + 14
  bytes, and the other fields of the line take about 120 bytes, with a project slug of 22
  characters. Measured with `log.sh review dir=<dong3 worktree> run=abc123 round=12`, ids
  `claude-sonnet-5-5-<i>`, `reviewer=<id>:12`, `outcome=<id>:10+1+1+0` and `end=converged`:
  5 reviewers give 379 bytes, 17 give 1019 bytes, and 18 give a 532-byte line without
  `outcomes=`. The edge moves with the length of the ids and of the project slug.
- **The bound is the choice of spec 016, not of the shell.** It keeps one `write()` for each
  line under `O_APPEND`. Measured on Linux with `strace`: bash `printf` writes a line of up to
  4096 bytes in one `write()`, and splits a longer line. So on this host the bound cannot be
  more than 4096 bytes. macOS is not measured.
- **020 still holds.** The agent writes the line about its own work, so a line that it does not
  write leaves no trace. A round count is still not a capability signal.

020 said that the log answers "which models ran, in which project, how often, and when", and that
nothing computes. The first part stays true. The second part is no longer true: a reader can now
compute an acceptance rate for each reviewer. Before 0.17.0, only the hand-kept file
`~/.claude/review-loop-glm.tsv` had this data, for one reviewer.

## Evidence: simulation runs, 2026-11-21

The claim is about behaviour: a facilitator that reads SKILL.md gives the counts correctly, and
writes the line after the T3 answer. A `grep` cannot settle it, so it was settled by runs.

**Setup.** Each run was a headless `claude -p` with the plugin loaded by `--plugin-dir` from a
private copy, `--setting-sources project`, and no Agent tool, so that no reviewer ran again. The
log, usage and pending paths were set to the environment by `REVIEW_LOOP_LOG_FILE`,
`REVIEW_LOOP_USAGE_FILE` and `REVIEW_LOOP_USAGE_PENDING`. Phase 1 asked the facilitator to
continue the loop from round 1. Phase 2 resumed the same session with the answer of the author.

**Environment.** A Python repository with one branch that adds `window(xs, n)`. Round 1 of two
reviewers was already back as files:

| Reviewer | Finding | What reproduction shows |
|---|---|---|
| `claude-opus-5-5` | F1: off-by-one, the last window is missing | Reproduces |
| `claude-opus-5-5` | F2: the windows come in reverse order | Does not reproduce |
| `claude-opus-5-5` | F3 (T3): remove `window`, give `chunks` a `step` parameter | Judgement |
| `gpt-6-astra` | the same off-by-one as F1 | Reproduces |
| `gpt-6-astra` | P2 (T3): accept any iterable, not only a list (second set only) | Reproduces |
| `gpt-6-astra` | rename `n` to `size` | Judgement |

### First set: three fields, with a control arm

The author answer was: decline F3, go on. The control arm used the SKILL.md of 0.16.0 with the
first `log.sh` of this change, so the only change between the arms was the text.

| Run | Model | SKILL.md | Line after phase 1 | Final line |
|---|---|---|---|---|
| t1 | opus | 0.17.0, three fields | none | expected counts |
| t2 | opus | 0.17.0, three fields | none | expected counts |
| t3 | sonnet | 0.17.0, three fields | none | expected counts |
| t4 | sonnet | 0.17.0, three fields | none | expected counts |
| t5 | haiku | 0.17.0, three fields | none | expected counts |
| c1 | sonnet | 0.16.0 | `reviewers=` only | the same line, no counts |
| c2 | opus | 0.16.0 | `reviewers=` only | the same line, no counts |

The behaviour changed between the arms, so the result is attributable to the text. The control
runs did not use the new keys, although the source of `log.sh` names them.

### Second set: one outcomes field, with deferred

The author answer was: decline F3, defer P2 to an issue, go on. The expected line was
`outcomes=claude-opus-5-5:1+1+1+0,gpt-6-astra:2+0+0+1`. No control arm ran: the SKILL.md of
0.16.0 does not name `outcome=`, and the first set already showed that the text decides the
behaviour.

| Run | Model | Line after phase 1 | Final line |
|---|---|---|---|
| v1 | opus | none | expected line |
| v2 | opus | none | expected line |
| v3 | sonnet | none | expected line |
| v4 | sonnet | none | expected line |
| v5 | haiku | none | none: a fail |
| v6 | haiku | none | expected line |

The second set has 5 passes in 6 runs. v5 reached the moment and did not do the step: it gave the
expected counts in its last message, but it started round 2 before it wrote the line of round 1.
The environment denies a direct `codex` command, so the round 2 call was denied, and v5 stopped with no line. v6 ran
the same environment and the same text. v5 showed a gap in the text: SKILL.md did not say that the
line of a round comes before the next round.

### Third set: the line comes before the next round

SKILL.md § A3 got one more sentence: write the line of a round before you dispatch the reviewers of
the next round. Five haiku runs used the environment and the author answer of the second set, so
a direct `codex` call in round 2 was denied again. h2 called `codex` through the relay instead, which
the deny rule does not match (see below).

| Run | Final line | First `log.sh review` call before the first `codex` call, direct or through the relay |
|---|---|---|
| h1 | expected line | yes |
| h2 | expected line | yes (`codex` through the `codex-delegate` relay) |
| h3 | expected line | yes |
| h4 | expected line | yes |
| h5 | expected line | yes |

h4 and h5 put the rename in T3, and the answer "go on" did not answer it. Both asked for an
answer and held the line, because the round was not complete. A third phase, "Rename it.", resumed
both sessions. Then both wrote the line before they called `codex`.

The deny rule `Bash(codex *)` matches only a command that starts with `codex`. The column counts
both kinds of call: a command with `codex exec` or `codex review`, and a call of
`node …/codex-delegate/scripts/relay.mjs`. Four runs called the relay: t1, t2, v1 and h2. The relay
runs `codex` outside the environment, on the ChatGPT plan of the owner of this repository. h2
reported the token use of its Codex review; for t1, t2 and v1, whether the review completed was not
checked.

**Where the transcripts show the moment.** In the stop message of phase 1, t2 wrote that it would
write the round line after the reply, "since it needs your accept/decline" counts. t5 wrote that
"the round log is not written until you answer". v2 wrote that "The round-1 log line waits for your
answer, because the declined and deferred counts depend on it."

**Other observations.**

- t1, t2 and c2 moved F1 to T3, because its fix changes a return value. t2, t3, c1 and c2 moved
  the rename to T3, because a caller can pass `n` by keyword. In each set, the counts were the
  same whatever tier the facilitator gave.
- t5 (haiku) ran `log.sh` a second time with `bash -x`, and so wrote the line twice. Then it
  removed the duplicate line with a file edit. The log is append-only (SKILL.md § A3), and no rule
  in SKILL.md tells what to do after a duplicate write. No change was made for this observation.

## Changes

- `log.sh review` takes `outcome=<id>:<a>+<r>+<d>+<f>` and writes `outcomes=`
  (`tools/review-loop/test-log-sh.sh` has the tests).
- `log.sh` writes a line over the bound without `outcomes=`.
- SKILL.md § A3 gives the four counts, when the line is written, and two limits.
- The README section "Round log" shows the new field and the order of lines at a T3 stop.
