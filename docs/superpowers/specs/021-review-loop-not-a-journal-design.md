# 021 — review-loop: not a journal

Removes § *Learning capture* from `SKILL.md`. Adds an A0 offer to delete the file an
earlier version wrote, and one line in every reviewer's brief saying that file is not a
source.

## Intent

The loop stops writing `.claude/pr-review-journal.md`. This is a subtraction, plus the
smallest clause that lets an existing file be removed, plus — added after the runs showed
it was needed — the one line that reaches a reviewer, since a file the author keeps is
still read as authority by whoever reviews next.

## What goes

§ *Learning capture*, complete. Both halves: the per-round append to
`.claude/pr-review-journal.md`, and the closing line "Periodically distill recurring
patterns into the project's conventions/guidelines doc."

## Why

**The record has no owner and no moment at which it is used.** "Periodically distill"
names an obligation with no trigger. Nothing states when the file is read, by whom, or
when it is reduced. That is the same defect 020 removed from the log half of 016: an
instrument that nobody is scheduled to use.

**Its fields are already carried, each by a record that does have an owner.**

| Field of the journal | Where it already lives | Written by | When |
|---|---|---|---|
| target, round, which reviewer | the round log (§ A3, `log.sh`) | the facilitator | after that round's dry decision |
| comment → fix pattern | the fix commit's message | the facilitator | when the fix lands |
| T3 decision, approach, why | the fix commit, and the change's design record | the author | when the fix lands, and when the change lands |
| repeat-issue escalation, within one target | § B5 — the loop **stops and asks the author** | — | live, in the round |

A fourth copy produces a second source that disagrees with the first one later.

**One half of the last row is dropped, not rehoused.** B5 compares a new comment against prior
comments on the same file and line, inside one target. The journal bullet it replaces was also
cross-change — "gaps in the project's conventions; candidates for the project's guidelines doc" —
and that half has no home now: the round log carries no finding content, commit messages are
per-fix, design records per-change. It is dropped deliberately, for the same reason as the rest:
the distillation obligation it fed had no trigger, so the data fed nothing.

**Unread it costs; read it costs more.** The failure is not that the file grows. It is
that a later episode can find it, treat it as authority, and act on a claim that no
longer holds — with no review gate between the note and the action, because nothing
reviews a journal.

## The axis is prose, not growth

The round log grows across reviews too, and it stays. The two are not the same kind of
thing, and the distinction is what the new § *Non-goals* bullet states:

- The **round log** is one line of fixed fields. Nothing reads it during a loop and
  nothing reduces it, so no moment for tidying it is needed.
- A **journal** is prose. Prose has to be read, reconciled and compacted by someone,
  and that moment is what the skill never named.

The first draft of this change said the loop "keeps no record that accumulates across
reviews", which contradicts § A3. Recorded here because the wrong axis is the easy
mistake to repeat.

## The cleanup at A0

At **A0**, if `.claude/pr-review-journal.md` exists, the loop says that an earlier
version wrote a review journal there, that it no longer keeps one, and asks whether to
remove it. It removes the file on a yes, as its own commit when the file is tracked. On
a no it leaves the file and never writes to it. When the file is absent it asks nothing.

**It is not called one-time.** The clause is stateless. A yes extinguishes it — the file
is gone. A no is recorded nowhere, so the question returns at each A0 while the file is
there. Saying "one-time" beside a rule with no place to store the answer invites an agent
to invent one, which is the accretion this skill warns against elsewhere. The text says
the no is not recorded and tells the agent not to invent a place for it.

**It rides A0 and adds no stop.** A0 is already the first of the two fixed stops.
§ *Author checkpoints* item 3 states the rule for a question that arrives inside a stop:
"Questions that follow from an offer the author accepted … are inside this stop, not new
ones." (Item 2's neighbouring sentence — "a question raised inside a **round** that was
going to stop anyway" — is the wrong citation here: A0 is a stop, and the skill places it
"before round 1", so it is not a round.) The published arithmetic — two stops plus one for
each round that has a T2/T3 finding — is unchanged, and the shape is not re-published. The
A0 text states this in place, because that is where an agent decides whether the shape
needs re-publishing.

§ *Author checkpoints* item 1 still reads "**A0** — the author pass, and this list". It
is not amended. That list states how many stops exist and what forces one; it is not an
inventory of what the A0 message contains, which already includes more than two things.

## Every brief says the journal is not a source

The removal offer is not enough, and the runs showed why. A reviewer that reads the
surviving file treats it as settled fact: three of ten runs cited it to close a review
question — "that was decided already", "no test was ever added here" — and one reviewer
used it to argue a tier down against two reviewers who had rated the finding higher.

**§ *Non-goals* cannot reach a reviewer.** It is in this skill, and a reviewer reads only
its brief. The one control-arm run that refused to use the file was the facilitator, which
does read the skill; the reviewers that mined it never had the chance to know. So the
instruction goes where a reviewer will see it: when the file is in the tree or in the diff,
each brief carries one line saying the file is a record nothing reviewed, so it is not
evidence, and that a deletion of it in this diff is the loop's housekeeping, not part of
the change.

That second half also answers where the A0 removal commit lands. It lands on the target
branch, inside the `base...HEAD` range every blind reviewer receives — so without the
brief line, a reviewer sees an unexplained deletion and reports it as scope creep, once
per repository. The alternative considered was to defer the removal to the hand-off, out
of the reviewed range. The brief line was preferred because it also covers the case
deferring does not: the author says no, the file survives, and reviewers keep mining it.

**Known gap: a forge reviewer gets no brief.** GitHub Copilot sees the pull request, so it
can comment on the deletion. This is accepted rather than repaired — it is one comment,
once per repository, and building a Copilot-side channel for it would cost more than the
comment does.

## Consistency sweep

Searched `SKILL.md`, `README.md`, both command files, both references and all five
scripts for `journal`, `distill`, `Learning`, `accumulat`, `conventions`, `guidelines
doc` and `append`. The surviving `append` hits are the round log and the Codex watch feed.
`README.md` never described the journal, and neither description in
`.claude-plugin/marketplace.json` or `plugins/review-loop/.claude-plugin/plugin.json`
mentions it, so no user-facing text changes.

**The sweep missed one, and the reason is worth keeping.** It searched for `Learning`, the
section title, case-sensitively. `SKILL.md` line 8 read "Preserves the author's
architectural voice **and learning across review cycles**" — lower case, and the only
mechanism that carried learning across review cycles was the section being deleted. The
review found it. A sweep after a deletion has to search for what the deleted thing *did*,
not only for its name, and case-insensitively.

## Deferred — the transcript defect

Not fixed here, and recorded so it is not lost. § *Prompt outputs are run* says "read
what it did" and "a run is evidence only if **the transcript shows** the moment the
instruction was exercised". The facilitator dispatches a simulation run with `Task`, and
a `Task` dispatch returns the subagent's final message and nothing else — the commands
it ran, the files it read and the point at which it stopped do not arrive. So the
exercised-moment rule is not checkable as written.

018's own *Review history* records what worked: "The measurement was a log file the
subagents wrote, not anything they said about themselves." That sentence belongs in the
skill as a rule — the environment carries the record, the run writes into it as part of
the task, the record is of actions and never of compliance — and the exercised-moment
rule is then restated against the record rather than the transcript.

It is a different subject from this change: this one removes a record, that one fixes
where a record is read. It is a separate spec.

## Edits

| File | Change |
|---|---|
| `plugins/review-loop/skills/review-loop/SKILL.md` | delete § *Learning capture*; drop "and learning across review cycles" from line 8; add the "Not a journal" bullet to § *Non-goals*; add the cleanup offer to A0; add the not-a-source line to every brief in A1 |
| `.claude-plugin/marketplace.json` | version `0.10.0` → `0.11.0` |
| `tools/review-loop/test-skill-content.sh` | version assertion `0.10.0` → `0.11.0` |
| `CLAUDE.md` | review-loop paragraph: record 021 |

Descriptions are unchanged. None of these changes what a caller decides when choosing this
skill, and both descriptions are already long.

## Review history

One reviewer, `claude-fable-5`, blind on the branch, plus ten simulation runs. The loop was
not driven by `/review-loop` itself: § A3 tells the facilitator to run `log.sh`, which would
have written to the author's own round log for a review of the skill that defines it.

### What the reviewer found

Six findings, each with a falsification condition, all reproduced by command before any
edit. Five were repaired: line 8's dangling "learning across review cycles" (see
§ *Consistency sweep*); the A0 removal commit landing inside the reviewed range (repaired by
the brief line, not by deferring the commit); "one-time" beside a rule with no place to
store a no; the coverage table's fourth row; and the `Not a journal` opening sentence, which
forbade prose that the same bullet then directs into commit messages and design records. The
sixth was the off-scope citation — the design record justified "adds no stop" by quoting a
sentence whose subject is a round, and A0 is not a round. It is repaired here by citing item
3 instead; `SKILL.md` was not edited for it.

The reviewer raised no finding against the deferred defect, and verified the quotation this
record takes from 018 independently.

### What the runs showed

Ten runs, Sonnet as the subject, each with its own environment: a small repository carrying a
tracked `.claude/pr-review-journal.md` with three prior entries, and a copy of the skill whose
`log.sh` default was repointed into the environment, so a round line became part of the
record instead of reaching the author's log. Five runs on the text as written; five on the
control arm — the same text with the A0 clause deleted and everything else, including the
`Not a journal` bullet, left in place.

| | clause present | clause deleted |
|---|---|---|
| offered to remove the file | **4 / 5** | **0 / 5** |
| published an A0 message | 4 / 5 | 5 / 5 |
| cited the journal to settle a question | 1 / 5 | 2 / 5 |
| refused to use the journal, unprompted | 0 / 5 | 1 / 5 |
| wrote to the journal | 0 / 5 | 0 / 5 |

**The control arm discriminated**, so the offer is attributable to the clause and not to the
environment. The one run that did not offer never published an A0 message at all — it lost
itself in a correction about a reviewer that had not reported — so by this skill's own rule
it is not evidence either way: the record cannot point at the moment.

**The clause is not redundant with the `Not a journal` bullet.** The control arm shows what
the bullet alone produces: a disclosure ("I am not adding an entry … let me know if you want
it handled differently"), not an offer. Different work.

**The runs found the hazard the reading had not.** Three runs cited the surviving file to
close a question — one used it to argue a finding down a tier against two reviewers who had
rated it higher, one cited a prior entry as evidence that a defect class recurs, and one read
it "to confirm two prior T3 decisions are settled and not being re-litigated". Two of the
three are in the control arm, so the hazard is independent of the clause. That is the whole
reason § *Every brief says the journal is not a source* exists; before the runs, this change
addressed only the file's future, not its use.

**Seven runs completed a review round and none appended to the file**, which is the moment
§ *Learning capture* named ("after each round, append"). The journal is fifteen lines and
byte-identical to its baseline in all ten environments. The only files any run added are the
seven round logs and three scratch files a run made for its own use (a brief, a diff, a Codex
input). No run committed anything. The author's own round log was verified unchanged by
checksum after the runs.

### The second and third rounds — does the brief line arrive?

Fifteen more runs, after the brief line was added.

**Arm C, five runs, the same environment as A and B.** The A0 offer survived its rewrite:
5 / 5 published A0 and 5 / 5 asked, against 4 / 5 before, and the no-state sentence came
through — "I'll ask again next time since nothing records a 'no.'" But only two runs
dispatched a reviewer at all; the other three stopped at A0 waiting for an answer that never
came. Of those two, one sent the line in both briefs and one sent it in neither. The moment
was exercised twice, so arm C says almost nothing about the brief.

**Arms D and E, ten runs, in an environment that reaches A1** — the run is told the author
pass is already answered. These numbers do not compare with arm C: the environment changed,
so this is a fresh baseline. The two arms differ only in **where** the requirement is named.

| | reviewer briefs carrying the line | runs where every brief carried it |
|---|---|---|
| **D** — named in A1's brief inventory | 11 / 11 | 5 / 5 |
| **E** — only the standalone paragraph, the text as committed | 10 / 12 | 4 / 5 |

**The repair was not adopted.** At five per arm a difference this size is invisible, which was
stated before the runs rather than after. The paragraph as committed reached every brief in
four runs of five, so arm C's one-of-two now reads as variance, not as a defect of placement.
Following this skill's own rule, the repair was made in a private copy and the tree was never
edited; the copy was discarded.

**The one omission is the one citation.** In arm E's failing run both briefs carried the diff,
the tiers, the falsification instruction and the author's intent, and omitted only this line —
and that run is the only one of the ten whose reviewer cited the journal, to argue that the
repository had already settled a question. A single event attributes nothing. The comparison
that carries weight is the baseline: with no such line anywhere, three of ten runs had the
file cited; with it, one of ten, and that one did not send it.

### Observed, not repaired: a facilitator inventing a reviewer's findings

Two of the twenty-five runs asserted a reviewer's findings before that reviewer had returned,
then caught themselves. One said so plainly: "the earlier 'Opus reviewer' findings were
fabricated, not real … I invented that content instead of waiting for the real one."

§ *Facilitator discipline* already forbids this — "It may not put its own arguments in another
reviewer's mouth" — and nothing detects it. § *Ghost reviewer gate* covers a reviewer that
returns nothing, not a facilitator that manufactures a return. Both runs recovered on their
own, and a rule that holds only when the agent happens to audit itself is not a gate. This
belongs to § A1 and § *Ghost reviewer gate*, not to a change about which records exist, so it
is recorded here and left for its own change.

### Limits of the runs

- **No third arm carried the pre-change text.** So "the new text produces no journal write"
  is measured; "the old text would have written one" is not.
- **`$HOME` was not isolated.** Runs read the author's real `review-loop.local.md` roster,
  and several correctly reported it as stale. Only the round log was redirected.
- **The runs made real `codex` calls**, and one run's own sub-reviewer ran `git checkout main`
  on the shared checkout mid-review; that run detected it and restored the branch.
- **A0 arrived late or not at all in four of arms A and B's runs.** One never published it;
  three published it after dispatching reviewers and said so themselves ("A0, published late").
  That is § A0 adherence, not this change, but the cleanup offer rides A0, so it inherits the
  weakness. It is recorded here rather than repaired, because repairing it means editing text
  019 measured.
- **D against E is one text against another, not a text against its absence.** This document's
  own § *Prompt outputs are run* prefers the second shape. It was used here because the
  question was where a sentence sits, not whether it exists; the instruction-deleted control is
  arms A and B, where no brief carried the line in ten runs.
- **The citation count is a screen the author then read.** Runs were selected by a keyword
  search and each hit was read before it was counted; two hits were discarded as false
  positives — one was the A0 offer describing the file to the author, one was a facilitator
  reporting that it had told reviewers not to use it. Runs the search did not flag were not
  read, so a citation phrased differently would have been missed.
