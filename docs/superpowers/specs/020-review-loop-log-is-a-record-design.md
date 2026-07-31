# 020 — review-loop: the log is a record, not an instrument

Supersedes the hook half of `016-review-loop-observation-log-design.md`.

## Intent

`review-loop` keeps one line per review round and nothing else. The
`UserPromptSubmit` hook, the `object` line, the `#redo`/`#again`/`#fix` marker
convention and the `observation-log` consent key are removed.

No field changes, no new writer, no new behaviour. This is a subtraction.

## What the log is

One line per round, written by the loop:

```
2026-07-30T05:32:07Z  review  project=<slug>  run=<tok>  round=<n>  reviewers=<model>:<count>,...
2026-07-30T05:35:06Z  review  project=<slug>  run=<tok>  round=<n>  reviewers=...  end=converged
```

The last round of a run carries `end=converged`; an author stop writes
`end=stopped` with no `round` and no `reviewers` field (§ A3).

It answers questions of the form "which models ran, in which project, how often,
and when". `grep` answers them; nothing computes.

## What the log is not

**It is not a capability signal, and no conclusion of that kind may rest on it.**
016's first draft (`f6b5fd8`) established why. Two later commits — `1232fbf`,
"cut the analysis, keep the recording", and `5273dd3`, "a Unix-style line log,
nothing more" — removed the argument while keeping the implementation, so the
current 016 no longer holds it and no other file in this repository does either.
It is carried here for that reason, from the draft:

- A round count mixes artifact difficulty, the K policy, roster composition and
  author decisions.
- It falls when a reviewer drops out mid-run, so a degraded run scores better.
- A review loop is a repair mechanism, so its convergence is the quantity that
  hides a capability change rather than the one that shows it.

016 as it stands does record one thing about the half that remains — added by a
later commit than the ones that cut the argument above, which is why this
sentence cites the current file and the ones above cite the draft:

> The `review` side is not measurable, and that is accepted. A round line has no
> author-typed antecedent, so nothing independent records that a round happened.
> It is also written by the agent during the loop, which is where an
> underperforming agent is most likely to skip it.

That still holds. A missing round is invisible unless the `round` sequence has a
gap, and a run that was never logged at all leaves no trace. The log is therefore
a record of what was written, not of what happened.

Both facts are stated here so that a later reader who wants a capability number
finds the reasoning against it in the same file as the data, rather than having
to re-derive it.

## Why only the agent can write the line

A hook cannot write this log, and the removed one never could have.

The end of a review round is known to one party. It is the moment the
facilitator has collected every reviewer's verdict and decided whether the round
was dry — a decision made inside the loop, from content no other process sees.
No harness event corresponds to it. The removed hook fired on
`UserPromptSubmit`, which is the author sending a message: unrelated to a round
boundary, and useless as a write trigger even in principle.

So **requiring the agent to append the line is the only mechanism available**,
and § A3 already does that. This is not a gap waiting for a better hook; it is
the shape of the problem.

**That makes one limit structural rather than incidental.** The log is written
by the agent about its own work, so the agent's failure to write is invisible in
it. A gap in the `round` sequence within a run shows a skipped round. A run that
was never logged, or one that stopped logging after its first round, leaves the
log looking merely quiet.

This is not hypothetical. The review of spec 019 ran nine rounds and this log
holds one line for it — `run=80xlzr round=1`, whose reviewer counts match that
review's first round exactly. The remaining eight rounds are absent, and the
mechanism was working: the facilitator had already worked around a permission
error to write that first line. It then stopped writing.

That instance is recorded here because the log's purpose includes watching how
the agent is doing, and **the first symptom of a bad run is likely to be an
unwritten line**. A reader must treat quiet as ambiguous: either nothing ran, or
something ran and went unrecorded. Nothing in this design separates the two, and
nothing proposed here would.

## Why the hook is removed

016's thesis was to measure the interaction rather than the artifact: an
`UserPromptSubmit` hook would record each time the author objected to an output,
marked by `#redo`, `#again` or `#fix`, and the `review` lines would serve as the
denominator.

The premise was never checked against the author, and it is false. Three things
show it:

1. `observation-log` has never appeared in `~/.claude/review-loop.local.md`, so
   the hook has been inert since it shipped in 0.7.0.
2. The log holds no `object` line. Every line in it is a `review` line.
3. The three markers appear nowhere in this author's own writing. Their only
   occurrences in the repository are inside 016's own spec, plan and notes.

So the machinery — a hook running on every message in every project, a consent
key, a marker vocabulary, a scrubbing rule for session ids, and a test suite —
served an input that was never going to arrive. The `review` line, which is the
part in use, was implemented seven minutes before the hook and does not depend on
it: `log.sh` uses every helper the hook used and one more, so removing the hook
leaves no dead code in `logline.sh`.

## What this costs

016's first draft set out to find out, over eighteen months, whether a
confidence instrument for this loop is possible. Removing the hook ends that
investigation before it produced data. That is the intended outcome: an investigation whose
only input never arrives is not producing data either, and the hook's standing
cost — one process per message, in every project, forever — is paid whether or
not the input arrives.

If the question is taken up again it needs a trigger the author actually
produces. Finding that trigger is not this change's business, and this document
proposes none.

## Changes

**Removed.** `plugins/review-loop/hooks/` (`hooks.json`, `object.sh`);
`tools/review-loop/test-object-sh.sh`; the hook disclosure in
`commands/init.md`; the observation-log section of the skill README; the hook
clause in both plugin descriptions; the hook probe in
`tools/review-loop/test-skill-content.sh`.

**Adjusted.** Comments in `log.sh` and `logline.sh` that name the `object` line,
the hook, or the observation log.

**Unchanged.** The line format, `log.sh`'s two subcommands, every helper in
`logline.sh`, the `REVIEW_LOOP_LOG` and `REVIEW_LOOP_LOG_FILE` environment
variables, and every existing line in an existing log.

Version 0.10.0.
