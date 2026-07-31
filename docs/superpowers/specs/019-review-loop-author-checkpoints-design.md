# 019 — review-loop: author checkpoints, and a recurring T3 re-confirms direction

Issue: https://github.com/caasi/dong3/issues/70

## Intent

Two changes, both in `plugins/review-loop/skills/review-loop/SKILL.md`.

1. **The stop shape is published at A0 and then held.** Three kinds of point — the
   author pass, one message per round that has a T2/T3 finding, the hand-off — plus
   named exceptions, each of which re-publishes the shape when it fires.
2. **A T3 that comes back is read as a drift signal.** That round's message
   re-confirms the direction of the whole change with the author, as well as asking
   for the item's own fix.

No counter, no cap, no deferral list. The first change bounds the stops by naming
them in advance. The second is what the stops are *for*.

## Scope

This document covers the author-stop shape and the recurring-T3 rule. The behaviour
change is one file, `SKILL.md`; the catalogue surfaces follow it (§ Changes). Three things
it deliberately does not touch:

- **K** (§ A3). How K is sized is not what this issue is about and § A3 is untouched.
  § *Author checkpoints* does name K among the facilitator's own judgements, because three
  of five runs on a text carrying neither of two named K instructions stopped the author
  for K in a round that had no findings, which breaks the shape this issue asks for. Which sentence
  suppresses that stop is not isolated by those runs (§ Verification).
- **§ B0**, which opens a pull request with no author stop. Whether the loop may do
  that is a different bound and belongs in its own issue.
- **The helper scripts.** An earlier draft of this branch repaired a missing executable
  bit on `log.sh` and `logline.sh` — § A3 tells the facilitator to run the first, and both
  are committed `100644`, so the documented call fails for anyone who installs the plugin.
  It is a real defect, it is not this issue's, and it was withdrawn from here. The version
  bump and the catalogue surfaces were withdrawn at the same time and are back, once the
  runs were in.

## The problem

Issue #70. § Tiers said, per round:

> resolve T2/T3 with the author first (quote the comment, draft 2–3 approaches with
> trade-offs, recommend one, wait for their pick)

One blocking question for each T2/T3 finding, in each round, from each reviewer.
Nothing bounds the product, and the loop's value is that it runs while the author does
something else.

**Under the stop count is a second problem, and it is the one that matters.** A
reviewer that raises the same architectural concern again, after a fix, is saying the
fix changed the code without settling the question. Left to the facilitator, each
recurrence produces another local decision, and the change drifts away from where the
author wanted it while every individual step looks defensible. Counting the stops does
nothing about this. Re-asking about the direction does.

**Half the complaint is not the number.** Issue #70's reference section says the author
also did not know how many stops to expect.

## What the design decides

**1. Publish the stops; do not count them.** A cap needs a counter, a deferral list,
and a rule for what happens to a deferred finding. Naming the stops in advance costs
nothing to maintain.

**2. Name the kinds of stop, not a single total.** `review-loop` runs until-dry
(§ A3), so the number of rounds belongs to the reviewers' verdicts and cannot be known
at A0. The contract names three kinds and states the baseline arithmetic — two stops plus one
for each round that has a T2/T3 finding — with named exceptions that re-publish it. A promised total the loop cannot keep would be
worse than no promise.

**3. One message per round, not one per finding.** Every T2/T3 finding of a round goes
into one message; one reply settles them all.

**4. A recurring T3 makes that message a direction question.** Compare by concern, not
by wording — a reviewer that renames an objection has not raised a new one. The message
gives the earlier finding, the fix commit, what that fix assumed, and the recurrence,
then asks whether the change is still going where the author wants. The item still
arrives with its approaches and a recommendation, as every T2/T3 finding does; the
direction question is what the recurrence adds. This is a different subject from
`suspected_drift` (§ A1), which reports that the *review* is aimed off-target — a
distinction a reviewer had to point out. It is still where the direction guard is worth
proposing, on the ordinary axis: an API-shape question has no runnable ground truth.

**5. It is not an extra stop.** A recurring T3 is a T3, so that round already stops.
What changes is what the message asks. An earlier draft called it a fourth exception
that "adds a stop"; ten runs showed every one of them merging it into the round's own
message, which is the correct behaviour and not what the text said. Later drafts then
made the direction-guard proposal a fourth exception instead, which reviewers found to be
legislating an act four other sections already own. § *Author checkpoints* now says
nothing about the direction guard at all.

## Rejected alternatives

Issue #70 lists four directions. This design takes the fifth, added in the issue's own
comment: publish the stops, then hold to them.

**Cap escalations per round (direction 2).** Needs the counter and the deferral list,
and a deferred T3 is a decision the author needed *before* that round's fixes landed.

**Apply some T2 with a recorded rationale, review at the end (direction 3).** Moves the
author's decision after the edit. § Tiers already lands architectural decisions before
mechanical edits, because the reverse produces commits that must be redone.

**Cap the rounds (direction 4).** § A3 is loop-until-dry precisely because a round
count is not the stop signal. A round cap replaces the reviewers' verdict with a number
chosen in advance, and can end an episode with open findings and call it converged.

**A recurrence rule for every tier, matching § B5.** § B5 fires on any repeated
comment. Restricting the local rule to T3 is deliberate: a repeated T1 is a mechanical
miss, and stopping the loop for it spends the author's attention on something no
direction question can improve.

## Declared limits

**The contract is prose, and nothing enforces it.** A facilitator that stops outside the
shape, without naming an exception, breaks the text and no check fires. This is the same enforcement class as § A1's
blindness rule and § B5's guard.

**"The same concern" is a judgement.** Comparing by concern is what makes the rule
catch a reworded recurrence, and it is also what lets a facilitator argue itself out of
one. § B5 has carried the same weakness since it was written, and there is no
counter-free way to remove it.

**The stop count is not observable after the fact.** `log.sh` records the run token,
the round number, and each reviewer's finding count, with no field for an author stop.
No past episode's stop count can be verified from the log, and this change's effect
cannot be measured from it.

## Changes

**Site 1** — a new § *Author checkpoints* before § Flow, published by § A0.

**Site 2** — § Tiers: the per-round escalation sentence becomes one message per round,
and the recurring-T3 direction rule is added below it.

Both in `plugins/review-loop/skills/review-loop/SKILL.md`.

**Site 3** — the catalogue: version 0.9.0, the two plugin descriptions, both READMEs, the
`/review-loop` command file, this repository's `CLAUDE.md`, and the metadata test's pinned
version and its probe for the new sentence. These landed after the runs, not before, so
what they describe is what was measured.

## Review history

**Round 1** — Opus 5 (6 findings), Sonnet 5 (4), codex gpt-5.5 (0, `CONVERGED`, on the
embedded-diff path, so it saw the diff and not the file and could not check the new
section against the sections it governs).

Opus found the contract disagreeing with the file in five places: the fix-round
predicate against § A3's definition, the direction-guard proposal's timing, the
hand-off's three further asks, `no counter` against `give the new count`, and a
catalogue surface giving the loop a decision the skill gives the author. Sonnet verified
every `§` reference and found a misquote in this document plus two idioms. Opus also
read the section as three parts argument to two parts contract, and observed that all
three contradictions were inside the argument — which is why the section was trimmed
instead of extended.

**Round 2** — Opus 5 (14), Sonnet 5 (3 new; all four of its round-1 findings verified
resolved, and cross-surface consistency confirmed by command), codex gpt-5.5 (3).

Codex and Opus independently found the same defect: the recurrence rule said it "adds a
stop", and every run merged it into the round's message instead. That finding is why the
rule now says the opposite. Both also found this document reading the K result as a
success when the runs show K still reaching the author. Opus corrected four numbers in
§ Verification and named three limits the section had not declared. Every correction is
in the current text.

Two reviewer claims did not survive checking. Codex read "the measurement is that log"
as mixing measured facts with self-report; the log holds each author-directed message in
full, and the classifications come from those bodies. Opus reported the observation log
as holding zero fixture entries; three remain.

**Round 3** — Opus 5 (11), Sonnet 5 (2), codex gpt-5.5 (0, `CONVERGED`).

Opus found that the K result in § Verification was produced by a sentence this branch had
withdrawn, and that on the shipped text three of the five new runs stop the author in a
dry round. That is the finding the § *Author checkpoints* judgement list now answers. It
also found the rule equating its own drift with `suspected_drift`, which § A1 defines
about the review rather than the change; that the "not that one item" wording conflicted
with § Tiers' requirement to carry approaches and a recommendation, and that no run had
followed it; and six numbers or labels in § Verification that did not survive
re-derivation, including a claim that the artifacts were not retained when they were, and
a paraphrase printed as a quotation. Sonnet confirmed every cross-reference, the 4-to-3
exception count and the two-file scope, and found one more idiom.

Opus also reported that its own round-2 list was not recoverable from any artifact on this
host, so it verified the five findings this document names and declared the rest
unverifiable rather than resolved.

## Verification

Both changes are behaviour claims about a runtime prompt, so they are settled by runs.
Sonnet was the run subject throughout, told nothing about what was under test and never
asked whether it complied. The model choice is from the dispatch configuration; the
fixtures record no per-run model. Three fixtures were built and five arm sets run on them. One fixture could not
separate the claim it was made for, one was void, and one works. All three are described
here, because the failures are what the numbers below rest on.

### The recurrence rule: environment, and why the first two did not work

The claim is that a T3 raising a concern an earlier round already fixed makes that round's
message a question about the direction of the whole change.

**The first environment could not separate it.** A branch was reviewed from round 1, and
the recurrence was the same function's signature, quoted at the same `file:line` in both
rounds. So "the whole change" and "the item" named the same object, and a same-location
match would find the recurrence without any comparison by concern.

**The second was void.** It moved round 1 into inherited history, which is right, but two
defects made it answer nothing. The "fix commit" it recorded had an empty diff — one run
found that and corrected the journal. And the recurrence carried a falsification condition
that the round-1 fix satisfied, so eight of ten runs reproduced the finding, refuted it, and
never reached the recurrence rule. Both arms did that, correctly: reproduction runs before
escalation. Ten runs, no answer.

**The third works, and was checked before it ran.** Round 1 is inherited history: a real
fix commit whose diff does what the journal says, and a journal recording the three
approaches, the author's choice and the reasoning behind it. This round's recurrence is the
same concern at a different location in different words — round 1 was the positional
parameter count at the function definition, this is that the same function computes the
totals and decides the presentation, quoted at the call site — and its falsification
condition is false in the tree, so reproduction confirms it. A second architectural finding,
unrelated to the signature, is present as a false-positive check. Three clean panel rounds
follow, so K is reachable and does not dominate.

### What the runs showed

Five runs on the changed text, five on the text it replaces.

| | links it to round 1 | names it a recurrence | cites what that fix assumed | asks about the whole change |
|---|---|---|---|---|
| with the rule | 5 of 5 | **5 of 5** | 5 of 5 | **4 of 5** |
| without it | 5 of 5 | **0 of 5** | 5 of 5 | **0 of 5** |

Column 2 is scored on the label: does the message call the finding a recurrence, something
that has come back, or a question the earlier fix did not settle? The word *recurring* or
*recurrence* appears in every one of the five runs with the rule and in none of the five
without it. Four of the control runs do identify the finding as round 1's declined approach
returning — "the same coupling axis as round 1's declined approach (c), which you rejected
then" — which is why column 1 credits them. What they do not do is treat that as changing
what the message asks.

**Two columns do not separate, and that is a result.** Both arms read the journal, linked
the finding to round 1, and quoted the reasoning the earlier fix rested on. Reading the
history is not this rule's contribution; the loop already does it.

**What the rule changes is what the message then asks.** Without it the finding becomes an
options list: "the same coupling axis as round 1's declined approach (c) (split
compute/format), which you rejected then … Options: (a) no change, reaffirm round 1's
reasoning; (b) split into compute_totals() + format_report() now; (c) keep one function but
add a totals-only helper alongside it. Recommend: (a)". With
it, the message states that the earlier fix did not settle the question: "the `99058d5` fix
made the args keyword-only; **it did not settle whether the function should be split**, and
this finding is that same question coming back." One run named the recurrence and still
handled it as an item, which is why the last column is 4 of 5.

**The rule is not over-applied.** The unrelated architectural finding is mentioned in
seventeen sentences across the five runs, and no sentence calls it a recurrence.

### The published stop shape

An earlier environment, ten runs, measured the shape. It was published at A0 in 5 of 5 runs
on the changed text and 0 of 5 on the old text — the clean separation. The number of
author-directed messages did not fall: 4.8 per run against 5.0, counted after excluding four
entries that runs spent working around a bug in the fixture's own author channel — a raw
`grep -c` gives 5.0 and 5.6 and does not reproduce the pair. And the batching sentence
caused nothing measurable: all ten runs batched a round's T2/T3 findings into one message,
the control included. It stays because it removes the licence to do otherwise.

### Two things the runs refuted, and one they removed

**"A recurring T3 adds a stop"** was in an early draft. Ten runs merged the recurrence into
the round's own message and none sent a second one, so the text described behaviour that did
not occur. It now says the opposite.

**A sentence about K** was added after three of five runs sent the dry round its own author
message to argue about K. Four of five did the same on the text carrying that sentence, so it
suppressed nothing, and reading those messages showed none of them asking the author to *set*
K: each reported that the environment could not produce the second dry round its own rule
required. The sentence was removed as text no run earned.

**The reason first written here for that removal was wrong, and the arms refute it.** It said
the gap belonged to the fixture. One fixture served three texts and the rate ranges across
them — 0 of 5, 3 of 5, 4 of 5 — so a constant cannot be the cause. What separates the arm that
never spent the stop is that its text carried a clause, in § A3, saying K is not the author's
question. That clause is outside this design's scope and was withdrawn from the branch before
these runs; the two texts also differ in six further edits, so the attribution is not
isolated. Recorded as an observation, not as a decision.

**A general sentence, added one commit earlier for a different reason, is the one the runs
used by name.** It replaced a fourth exception about the direction guard, not the K sentence — both
were present together in the runs cited here. Two of them named it to disclose exactly this
situation: "This adds an unnamed stop, so I'm naming it and re-publishing the checkpoint shape
(per the loop's own rule for a stop it didn't already list)."

### The shipped text, run

Five runs on the exact file this branch ships, in the third environment, against the same
five control runs. Its § Tiers recurrence rule is byte-identical to the text the first five
used — the two differ by one line, about K, elsewhere in the file — so the ten pool.

One of the five wrote its two messages outside the fixture, for the reason given under
§ *The instrument produced two false positives*; they were recovered in full and are scored
here with the rest.

| | names it a recurrence | asks about the whole change |
|---|---|---|
| the shipped rule (10 runs) | **10 of 10** | **7 of 10** |
| `main` (5 runs) | 0 of 5 | 0 of 5 |

**The criterion for the direction column, and the run that sits on its edge.** A message
scores when it puts a question to the author about where the change as a whole is going, rather
than only about how to fix the item. Two runs score no under it: one re-asks the item alone,
and one asks whether a decision taken in round 1 still holds — "is splitting compute from
presentation still out of scope while there is one caller, or has this second finding changed
that?" That second one is a boundary case, and a reviewer scored it the other way. Read as a
yes it makes the column 8 of 10 rather than 7. The figure below is the stricter reading.

**The direction column is noisier than either five suggested on its own.** It was 4 of 5 in
the first batch and 3 of 5 in the second, across a one-line difference that has nothing to do
with the rule. That spread is the five-per-arm limit doing exactly what this document declares
it does. The pooled 7 of 10 separates from 0 of 5; either five alone would have misstated it,
one high and one low.

**The rule is not over-applied here either.** One sentence appeared to call the unrelated
finding a recurrence. Reading it settles the matter — "round 2's two T3 findings (the
recurring compute/presentation split, and `write_report`'s module placement)" attaches the
word to the first item in a list of two. A sentence-level search cannot see that, and this is
the second time in this document that a scoring script produced a false count a reading then
corrected.

**On the dry round**, none of the five spent a separate message. K is reachable in this
environment, so this is not a test of the sentence that was removed; it is only evidence that
removing it did no harm.

### The instrument produced two false positives

An earlier draft of this section reported two runs that claimed author exchanges which never
happened, and called the behaviour a defect of the agent. A later draft retracted one of the
two. Both retractions were wrong in the same direction, and the correct count of fabricated
exchanges in this corpus is **zero**.

The author channel resolved its log as `${ASK_LOG:-$PWD/asks.log}`, so a run that invoked
`./ask.sh` from a working directory other than its own wrote outside the fixture. Two runs,
in two different environments and about an hour apart, did that from the same directory. Their
messages went into one file, which was found later in an unrelated repository: three blocks
from the first run, then two from the second, numbered 4 and 5 because the script numbers a
block by counting the blocks already in the file. Each run's own log stayed empty, and each
looked, from its own directory, like a run that had reported an exchange it never had.

The attribution is checkable, and it takes two steps rather than one. The first three blocks
are byte-identical to three message files the first run had drafted in its own directory, so
they are settled by string comparison.

The last two need more care than the first draft of this paragraph gave them. It cited the
round-1 fix commit `99058d5`, the location `src/report.py:22` and the panel wording "a locale,
a footer and a title" — but all three are inherited from that environment's template, so every
one of its fifteen runs carries them. They identify the environment, not the run. The
"7 commits ahead" in the hand-off block is no better: four other runs in the same environment
are also seven ahead. **What settles it is that this run is the only one of forty-five with an
empty `asks.log`**, and the two orphan blocks are exactly what a run is missing when its log is
empty: one round-2 message and one hand-off. A reviewer re-derived the attribution
independently and reached the same run; the argument printed here did not, until now.

**What this costs, and what it is worth.** The instrument this document trusts produced a
false positive of the thing it exists to detect. It reported a run as having sent nothing when
that run had sent everything, because the log it was read from was not the file the run wrote
to. None of the review rounds recorded in § Review history caught it. It was found by
noticing a file in a repository that had nothing to do with the experiment, after the change
had merged. Any future
fixture should set `ASK_LOG` to an absolute path rather than let it default to the working
directory — and, more generally, a log is evidence only when the channel is known to write
where the reader looks.

The rule that every count in § Verification is read from the ask logs rather than from a run's
own account is unchanged, and this episode is the strongest argument for it: the run whose
messages went astray described them accurately in its journal, and it was the *log* that was
wrong. Reading the journal alone would have been right here and wrong elsewhere; reading the
log alone was wrong here. Neither is sufficient on its own when the channel can misplace its
own record.

### Declared limits

**One fixture, one model, and a supplied panel.** § A1's blind parallel dispatch is never
exercised, because the panel output is delivered as a file. Neither is any forge path, so
§ B5, the first-ever-Copilot case and the control-arm case have no runs behind them.

**Five per arm bounds what the numbers mean.** A clean 5-to-0 split is a signal; a
degradation of up to roughly forty percentage points would be invisible.

**Recurrence is tested once, on a T3.** Whether the rule fires when the earlier finding was
T1 or T2 is not measured, and by the text it should not.

**The stop-shape result comes from an earlier draft**, not from the shipped text. The
recurrence result does not: see the next section.

**The artifacts are not committed, by decision.** The fixtures and every run log lived under
the session's scratch directory, and each review round's reviewer re-derived the numbers from
them there. They are not kept, because a fixture is built for the text it tests: this one
encodes one recurrence, at one location, with a falsification condition chosen to be false
against one tree. A later change to the rule needs a fixture built for that change, and a
stored one would invite reuse rather than rebuilding. What is worth carrying forward is the
design, and it is written above: put round 1 in inherited history with a real fix commit,
state the recurrence at a different location in different words, make its falsification
condition false in the tree so reproduction confirms it, include one unrelated finding as a
false-positive check, and leave enough clean rounds that K does not dominate.
