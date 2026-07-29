# 018 — review-loop: prompt outputs are run, code outputs are tested

Issue: https://github.com/caasi/dong3/issues/73

## Intent

`review-loop` gets one new section, and one carve-out at an existing rule. The new
section splits verification by what reads the artifact:

- a **runtime prompt** is read by an agent and its text is the behaviour, so the
  evidence is a run;
- a **deterministic output** is read by a program, so the evidence is a test.

The skill changes in three places: the new section, a carve-out at § Tiers, and
the reproduction rule that named prose as having nothing to run. A fourth change
rides along and is not part of this thesis — the Codex verdict tokens, recorded
under *Changes*.

## The problem

Issue #73. When the change under review is natural language, a reviewer that does
not hold the author's intent produces **accretion**, not correction. Every gap
looks like a missing sentence, so every round adds one. Six rounds on one pull
request added prose and changed no behaviour.

The rule that permits this is at § *Reviewers are asked what would show a finding
wrong*:

> On prose there is nothing to run, so reproduction is **a citation the facilitator
> verifies with a command** — the quotation, its location, and a `grep`.

For a design record that is correct: presence really is the property. For a runtime
prompt it is false. A `grep` shows the source is the source. It cannot show that an
agent who reads a sentence acts on it. So a finding of the form "this text does not
state X" is reproducible, actionable under the current rule, and closed by adding
X. Repeat for six rounds.

The failure is not theoretical. The commit that cut the accreted prose claimed "No
behaviour removed; every anchor that tests behaviour still passes" — and every anchor is a `grep`. The
claim rested on evidence that cannot support it, and nobody noticed, because the
skill had said a passing `grep` was reproduction.

## What the design decides

**1. The evidence instrument follows the reader, per claim.**
Not per artifact kind. A runtime prompt contains genuine presence properties — does
the file contain the command block it says it runs — where `grep` is
correct, and a design record can carry behaviour-bearing instructions. The decision
test is per claim: *could the agent comply without the string appearing?* If yes it
is language and `grep` is the wrong tool. If no, because the string is the
compliance act, `grep` is correct.

**2. A behaviour claim is settled by five independent simulation runs.** Build an
environment, give it to a subagent as a natural task, and read what it did. One run
is a single draw, and a claim resting on it is an anecdote.

**3. Five is fixed in the text, not negotiated per episode.** An earlier draft made
the number a budget the author set before each loop, with a reserve for the dry
rounds and a rule for carrying exhaustion across rounds. All of that machinery
existed only because the number was uncertain. Fixing it deletes the machinery, and
the machinery was where most of the review findings landed.

**4. The runs produce samples, not a signal.** A count answers "edit or not". What
the transcript shows — what the subagent did instead, where it stopped reading,
what it invented to fill a gap — answers "change what". Those four repair kinds
(competing behaviour, placement, salience, genuine gap) cannot be told apart by
reading the prose, and a count destroys them.

**5. Samples give accretion an operational definition.** Text added because a run
showed a gap is a correction. Text added because a reviewer could imagine a gap is
accretion. Before this, the two could only be told apart by taste.

**6. Intent flows one way.** It reaches agents that produce judgements — reviewers,
the direction guard, whoever builds the environment. It never reaches the subagent
that produces a behaviour sample, because telling that subagent the intent tells it
what is under test.

The intent field answers "what is this artifact for and who reads it". It must not
answer "is this change good" — that is the answer sheet, and it converts the loop
from accretion into rubber-stamping.

**7. A repair is tried on a private copy, never on the tree**, so § A1 holds: no
reviewer edits what another reviewer reads.

**8. Nothing mechanical assigns a tier.** A counterexample is evidence about
behaviour; a tier is a judgement about scope of fix. Different axes, no conversion.
This preserves § *Facilitator discipline*: "Tiering (T1/T2/T3) stays facilitator
judgement".


## Rejected alternatives

**A Bayesian confidence threshold.** It was the original intent for this gate. It
fails for two independent reasons. A threshold needs a prior, and the skill already
rules an agent's self-reported confidence inadmissible — "a self-report by the same
weights that produced the finding" — so the threshold has no admissible input.
Second, Bayes updates within a fixed hypothesis set, and every failure in #73 was
the hypothesis nobody had written down. A human who reads five transcripts and
finds one suspicious is adding a hypothesis, which is a different operation, not a
better-executed version of the same one.

**Parallel A/B, five agents per arm.** Rejected on arithmetic. Over all 36 outcome
pairs a two-tailed Fisher exact test is significant at 0.05 in only six cells, all
at near-total separation; 2 of 5 against 4 of 5 gives p = 0.52. The second arm
therefore doubles the cost and buys a result that is only readable when it was
already obvious. Single-arm detection is also weak: at a true failure rate of 0.3,
five runs find at least one failure 83% of the time; at 0.2, 67%.

**Parallel sampling of any kind, with a positive control.** An earlier version ran
five agents at once, treated the result as a counterexample search, and validated
the fixture by deleting the instruction and checking that the fixture noticed.
Rejected because the whole apparatus dies with the sample-size framing, and because
its non-satisfaction branch did not terminate: many instructions guard against
drift the model mostly avoids anyway, so deleting one produces no failure, the
fixture is declared dead, and the retry loop has nothing that bounds it.

**"Zero counterexamples, so do not make the edit".** Rejected as a reverse ratchet.
The fixture's liveness is only ever proven against total deletion, so a defect
whose failure does not surface as symbol absence would become permanently
unfixable. The design would have removed the accretion ratchet and installed a
stasis ratchet. The iteration cap does the same protective work with no veto: five
attempts, then report and let the author rule.

**An artifact-kind table.** Three rows — runtime prompt, deterministic output,
design record — each with its instrument. Cut: the projection from claims onto
artifact kinds is lossy in both directions, and the table implied coverage the
design does not have, since many instructions cannot become an observable at all.

**Human attention routing.** Filtering findings by evidence type and by class
recurrence, to spend the author's attention where their priors have an advantage.
Cut from this change and left for a separate issue: its justification rested on a
claim about the reference run's tier distribution that the author had inferred
rather than observed, and it is a separable design that should not ride in on this
one.

## Declared limits

Written into the rule rather than left blank, because a stated limit does not
create false confidence and a blank one does.

- The procedure detects "the instruction was not followed". It does not detect
  "the environment asks the wrong question". Only the author can see that.
- A run measures a proxy, not compliance. An instruction whose per-instance
  compliance is a judgement can still leave an aggregate signature a run counts.
  The limit is the opposite case: when a control arm shows no difference, "the text
  does nothing" and "this environment is too weak to separate the arms" produce the
  same observation, and no run separates them.
- Human attention is narrower than an agent's. Nothing here widens it.
- A reviewer's repair is validated against the single environment that produced the
  failure. "A repair exists" means relative to that environment.

## Validity

This section is calibrated against the models available when it was written. It is
not a permanent law, and it is deliberately absent from the skill itself: an agent
at run time needs the rule, while the question "does this rule still earn its place"
belongs to a human reading this document.

A more capable model may not need it. If a future agent runs a prompt to check a
behaviour claim without being told to, the section is dead weight and should be cut.
The way to find that out is the check the section itself defines — run the
unmodified artifact and look.

A less capable model may need more. A cheaper model, or the same model under compute
pressure, may need constraints this section does not carry.

Neither direction is predictable and neither should be pre-built. The rule is sized
for what could be measured when it was written, and those measurements are in this
document. Whoever revisits it should re-run rather than re-argue.

## Raised by the panel and not acted on

A blind parallel panel — Opus, Sonnet and Codex — returned seventeen findings on
the version before this one. Acting on all of them would have been the failure this
document is about: none came from a run, and by the rule above, text changed because
a reviewer could imagine a gap is accretion. Three classes were acted on — a claim
that was false, a number that was wrong, and a rule that could not fire. The rest
are recorded here with the reason they were left.

- **Cut the reviewer repair leg, cut the exhaustion rule, cut the § A3 token
  memo.** Two of the three were overtaken: fixing the sample size at five deleted
  the exhaustion rule and its budget machinery outright. The token memo stays by
  the author's decision, and its falsification condition is a run nobody has spent:
  would an agent restore the symmetric pair without it?
- **The reviewer leg cannot be executed by a read-only reviewer.** True of the
  version reviewed. The rewrite drops the reviewer/facilitator split, so no budget
  is allocated to a reviewer that cannot spend it; a reviewer that cannot run says
  so and the facilitator runs the claim.
- **The evidence in *What the runs showed* is an uncommitted self-report.** Correct,
  and the same category this document calls inadmissible when an agent reports its
  own confidence. The fixtures and transcripts are not in the repository. This is
  recorded as a known weakness of the record rather than repaired, because the
  repair is to commit the artifacts and that is a separate change.
- **`run` collides with the `run=` token in the round log.** Named in the text
  rather than renamed, because renaming the log token touches § A3 and the helper
  script, which this change does not.

## Review history

Two model families, blind and in parallel on the first pass, then four convergence
rounds with one of them. Both were asked to judge direction and were told that
their instinct would be to add precision.

- **Codex (gpt-5.5), one pass.** Called part 2 the strongest part and the
  artifact-kind table over-broad. Its load-bearing finding: the statistical
  rationale does not belong in a runtime prompt — "an agent running a review needs
  the command shape and allowed conclusion, not the statistical defense". That is
  the design's own reader-split applied to the design, and it is why the Fisher
  material is in this document and not in the skill.
- **Fable, round 1 (11 findings).** Found three false claims in the author's brief:
  that `grep` counted as ground truth for all text claims (§ A3 already excludes
  judgement findings), that nothing in the machinery detected convergence without
  proof (the direction-guard trigger does), and a tier distribution the author had
  invented. Each exaggeration ran in the direction that made the new design look
  more necessary. Also proposed the cheaper path that this design took.
- **Fable, round 2.** Found the reverse ratchet's replacement half-built: the two
  budget-holders had been given one loop specification although their loops have
  opposite polarity, and the facilitator held all four seats — writes the fix,
  builds the environment, runs it, grades it.
- **Fable, round 3.** Found that "the copy edit is evidence, never the proposed
  fix" was unenforceable ornament, and that § Tiers auto-fixes T1, so a
  typo-sized copy edit could reach the tree with no human in between.
- **Fable, round 4.** Found the first bound did not bound. The counter only
  incremented on failure, so a loop that satisfied the author each round and broke
  again the next incremented nothing: 20 runs a round, 30 rounds, 600 runs, no stop.
  Also found the episode-permanent stop would have made the author's own rewrite
  the one passage exempt from verification.
- **Fable, round 5.** Found that "counts" was doing two jobs — evidential in one
  paragraph, metering in another — so a run that produced no evidence could be read
  as free, in the one mechanism that is the hard stop. Also found the default total
  funded the fix rounds and defunded the K dry rounds that decide termination.

The loop was stopped after round 5 by the design's own rule. By then the surviving
findings were of two kinds: arithmetic, which is settled by counting, and "an agent
could read this two ways", which is a claim about behaviour. Arguing a behaviour
claim is the thing this section exists to replace.

## Verification

This section is a runtime prompt, so it is checked by a run, not by a reading. The
first case is the section itself: build an environment where an agent reviews a
natural-language change, and observe whether it runs the prompt or searches its
text.

The honest risk is stated in advance: if an agent runs the prompt without this
section present, the section is unnecessary and by its own rule should not be
added.

### What the runs showed

Four review episodes, two environment families, Sonnet as the run subject throughout.

**Episode 1 — the unmodified skill.** The reviewer reproduced four findings, every
one by `grep` or a `git show` comparison, and ran nothing. It named the gap itself:
"The grep evidence above is ground truth for text presence only, not for the
judgement that the gate is adequate." The existing escalation axis routed the case
correctly — no runnable ground truth, so propose the direction guard. That is the
answer to the cheaper path proposed in review: the axis ends at "ask a more
expensive reviewer", not at "get evidence", so reclassification alone would not have
produced a single run.

**Episode 2 — with this section.** The reviewer built a fixture, ran nine subagents
across treatment, control and ablation arms, and reported that its own primary
hypothesis was falsified. Three of episode 1's four findings did not survive the
runs; the fourth fell from T2 to a cosmetic T1 with measured behavioural cost of
nil. The ablation arm — the instruction deleted — published to the irreversible
channel, which is what made the other arms' restraint attributable to the text.

Two defects in this design surfaced there. "Run" had no definition, so the reviewer
counted subagent executions while the facilitator counted reviewer passes, and the
reported spend differed by more than four times. And the reviewer built a control
arm nobody had asked for, because without one the result could not be read — the
control had been cut from an earlier draft on the strength of an argument about
non-termination. Both were repaired: the unit is named, and the control is kept
while the retry around it is dropped.

**Episode 3 — the declared limits, probed.** The instruction under test was one
whose per-instance compliance is a judgement: "do not add a caveat unless a reader
would be misled without it". The reviewer did not fall back to `grep` and did not
build a fake observable. It found an aggregate signature and counted it. The control
arm produced the same restrained output as the original text, so in that environment
the instruction's credited effect was not attributable to it. The reviewer reported
that and stopped, citing this section's rule against rebuilding the environment
until it fails.

That episode corrected two claims made here. The limit about unobservable compliance
was too broad. And the control-arm rule overclaimed: a control that shows no
difference cannot tell a text that does nothing from an environment too weak to
separate the arms.

**Episode 4 — the rewritten section, with the sample size fixed at five.** The
reviewer named the routing rule before acting on it: the reader is an agent
executing the procedure, so the claim is a behaviour claim, "the agent could comply
without any particular string appearing", and it ran. It spent five runs per arm
across three arms with no budget supplied to it, which is the evidence that fixing
the number in the text removes the need to negotiate one. The control arm
discriminated — the instruction deleted published to the irreversible channel in
four of five runs, against none in either text arm — and the exercised moment was
identifiable in all fifteen transcripts, because every run reached the tag push and
stood at the publish step. The measurement was a log file the subagents wrote, not
anything they said about themselves.

Two findings that a static read files — the directive lost its imperative mood, and
step 5 lost its own precondition — were recorded as unreproduced, since every run
on the new text stopped and asked. That is the third episode in which reading
produced findings the runs then failed to confirm.

One observation against this design: the reviewer built a third arm carrying the
pre-change text, which is the A/B comparison this document rejects, and its own
report states the limit — at five per arm a degradation of up to roughly forty
percentage points is invisible. The section neither forbids that arm nor says it
rarely pays. Left as observed rather than repaired.

**Cost.** 30 runs across the four episodes. Episode 3 was given an 8-run grant and
spent 6; episode 4 was given no grant and spent five per arm, which is the number
the text now fixes.

## Changes

**Site 1** — a new section in `plugins/review-loop/skills/review-loop/SKILL.md`.

**Site 2** — § Tiers, at "T1 auto-fixed", gains a carve-out naming the new
section. Without it the file contradicts itself: an agent executing the auto-fix
rule without having read the new section follows the older, unconditioned one, and
the withholding rule sits in a section that agent never reaches.
