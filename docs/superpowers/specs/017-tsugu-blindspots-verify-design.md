# 017 — Tsugu owns the *blindspots* half of the four unknowns: `prepare` surfaces them into a `## Blindspots` section of `context.md`, and `converge` reminds the agent to verify findings with the human before any skill runs (a template + SKILL change, no schema bump)

> Numbered **017**, not 016: the interleaved `docs/superpowers/specs/`
> sequence already holds `016-review-loop-observation-log-design.md`. This spec continues the
> **tsugu** lineage (004–008, 011–013, 015) and takes the next free global number.
>
> Sourced from `caasi/dong3` issue **#67** (body + two comments). The design decisions settled during review
> are recorded at the end.

## Relationship to 004 / 005 / 006 / 007 / 008 / 011 / 012 / 013 / 015

This spec **extends** the tsugu lineage `004 → 005 → 006 → 007 → 008 → 011 → 012 → 013 → 015`. Everything
those specs establish stands: git-native intake, derived state (refs + DAG + containment + recency; no
status fields), the no-skill-orchestration rule, the no-force principle, the storage split (committed
`.tsugu/` vs personal global folder), the work-prefix / accepted-prefix partition, 011's handoff-oriented
converge (accept = mode-agnostic rename **and stop**; completion is the human's; maintenance exception;
curation; `prune`), 012's local-first `prepare`, 013's freshness-rebase + `context.md merge=union`, 015's
standing POST-HANDOFF CLEANUP block + agent-md pointer, and the never-auto-merge /
public-coordination-needs-approval boundary.

017 adds one narrow thing none of them name explicitly: **the `prepare` territory sweep already produces
blindspots (unknown unknowns), but they have no home to be recorded and no named step that produces them;
and the findings a `prepare` branch hands off are never *verified* with the human before a downstream skill
builds on them.** 017 gives blindspots a home and a producing intent on the existing `prepare` steps, and
gives `converge` a verify-first reminder.

## The framing — the four unknowns split by human-presence

The originating idea is the four-unknowns square. Its value here is not a new methodology; it is that the
square **already maps onto tsugu's two phases** by *who must be present*:

| Unknown | Owner in tsugu | Why |
| --- | --- | --- |
| **Known knowns** | `prepare` (existing) | reads the territory, grounds each claim with source/test |
| **Unknown unknowns (blindspots)** | **`prepare` — the one thing 017 adds** | a territory sweep surfaces them; no human needed |
| **Known unknowns** | `prepare` frames → `converge` answers (existing `## Open questions`) | a human-present decision |
| **Unknown knowns (taste)** | **superpowers:brainstorming, NOT tsugu** | extracting a human's implicit taste is the workflow skill's game with the human |

This respects tsugu's spine: *"Tsugu prepares the board. Workflow skills play the game with the human. Tsugu converges the result. It
is not an implementation methodology."* Discovering that a taste-question exists is a blindspot tsugu may
**flag and route**; *mining* the taste (prototypes, reaction, interview) is brainstorming's job, and 017
must not pull it into a tsugu routine.

## The two problems 017 closes

**Problem 1 — blindspots have no home and no producing step.** `prepare` step 7 already dispatches the
agent's own investigate subagents, and step 8 already maintains a narrative `context.md`. But the current
`context.md` skeleton has `## Open questions` (known unknowns — questions a human can answer) and no place
for **unknown unknowns** — the convention trap, the historical pitfall, the second consumer nobody named,
the pattern the codebase already follows. Those get lost in prose or never surfaced, because no step is
named "sweep for what we do not know we do not know," and no section says "record it here."

**Problem 2 — findings ride the handoff unverified.** A line a `prepare` branch records is, at best,
*material + grounded* (rooted in observed source, changes something that matters) — it is **not yet
verified**. `converge` is the first human-present moment. Today `converge` **routes** a branch (accept /
park / drop) and may hint which skill fits, but it does not remind the agent to **verify the findings with
the human first**. So a downstream skill — brainstorming, review-loop, a finishing agent — can inherit a
wrong finding and build on it. This is the same risk as a first edit that looks validated only because the
model chose it, not because it passed a check.

Both problems share one root: **tsugu carries understanding forward, but the understanding is neither fully
*surfaced* (blindspots) nor fully *checked* (verification) before it is handed off.**

## The principle (the spine)

> **`prepare` surfaces the territory including its blindspots; `converge` verifies findings before it
> routes them to a skill.** Discovery of a gap and the closing of it stay in separate homes: `prepare`
> finds *where* the gap is (a blindspot line, or a flagged taste-question); superpowers closes it *with
> the human*. And no finding —
> blindspot or claim — crosses into a downstream skill until the first human-present moment has had the
> chance to verify it, with a runnable check where one is cheap.

Consequences, each a design guard:

- **Blindspots are `prepare`'s output, taste is not.** The territory sweep is human-absent and belongs to
  `prepare`. The moment it discovers an *unknown known* exists ("two plausible UX directions, cannot tell
  which you want"), tsugu **flags and routes** it to brainstorming at converge (via the existing "packet may
  hint which workflow skill fits") — it does **not** open an interview, prototype, or quiz inside a routine.
- **The filter bar for a blindspot is `material` + `grounded`, not `answerable`.** "Answerable by the human"
  is the test for a *question* (a known unknown → `## Open questions`). A surfaced blindspot earns a line if
  it is **material** (changes architecture / data / security / scope) and **grounded** (rooted in observed
  docs / source, not a generic preference). Applying the question-test to a blindspot would wrongly drop the
  ones no single human can just answer — which are the ones worth surfacing.
- **Verification is a reminder, not a routine step.** 017 does **not** add a mandatory verify phase to
  `converge`. It adds a reminder in the handoff context: after a disposition is decided and before a workflow
  skill starts, verify the branch's findings with the human — writing **disposable code** (a probe, a
  failing test, a one-off script; deleted after — it is evidence, not a deliverable) where that
  turns a claimed fact into a checked one. Trivial mechanical work skips it, same right-sizing as the rest of
  tsugu.
- **Disposable code has two homes, split by the same axis.** `prepare` (human-absent) may write disposable
  code for **decision-free** grounding and **keeps it** as rerunnable evidence — it lands in `knowledge/`, never
  in the narrative, and `## Blindspots` carries the one-line index — so the handoff starts richer; the code *is*
  the evidence, so `prepare` does not delete it. `converge` (human-present) writes disposable code to **verify**
  a finding live with the human, then deletes it — the human watched it run, so nothing needs to survive.
  **Cleanup of the prepare-side probe is deferred to the human-present phase** — kept or pruned once the real
  work landed or is confirmed useless, riding 015's **`knowledge/` reconciliation**. Same tool, two phases,
  divided by tsugu's **existing** human-absent / human-present axis (SKILL.md already names the
  decision-free-vs-needs-the-human split) — the probe reuses that line, it does not move it.
- **`## Blindspots` is narrative, `merge=union`-safe, no status field.** Like every `context.md` section it
  is pure prose the state model already permits ("narrative informs judgment, never classification"). It is
  **not** a four-quadrant ledger — only this one section is tsugu's. No `answered/open` field, no lineage —
  a blindspot is confirmed or dissolved in the narrative, never a derived-state transition.

## The change set

| Line | Change | What it supersedes | Issue |
| --- | --- | --- | --- |
| A | **`init` adds a `## Blindspots` section to the `context.md` skeleton.** A new narrative section — the home for the unknown unknowns the `prepare` territory sweep surfaces. Sits among the existing `##` sections (proposed placement: right after `## Open questions`, since the two are the known/unknown pair), **above** the byte-immutable POST-HANDOFF CLEANUP block (015). Opening comment gains a one-line note. `merge=union`-safe, no status field | The skeleton had `## Open questions` (known unknowns) but no place for unknown unknowns; blindspots were lost in prose or never surfaced | #67 |
| B | **`prepare` names the blindspot sweep as an explicit intent on steps 7–8, with a `material` + `grounded` filter bar.** Step 7's investigate subagents gain a **blindspot intent** ("sweep for convention traps, historical pitfalls, unnamed consumers, patterns to follow — what we do not know we do not know"); step 8 records each surviving blindspot as a line under `## Blindspots`. The bar is **material + grounded** (not *answerable* — that is the `## Open questions` test). Discovering a *taste*-question is flagged and routed to brainstorming at converge, never mined in `prepare`. The sweep's **stopping rule is recurrence, not a count**: it reads `## Blindspots` first, and a blindspot the list already carries is not worked again — the repeat is written into the line in prose and handed to the human at converge | Step 7 dispatched investigate subagents with no blindspot intent, no home to record what they found, and no stopping rule | #67 |
| C | **`converge` gains a verify-findings reminder — verify with the human before routing to a skill.** After a disposition is decided (step 4) and before the human triggers a workflow skill (after step 4's disposition, at the step 5 → packet-hint region, SKILL.md:248–250), the handoff context reminds the agent to **verify the branch's findings (blindspots especially) together with the human**, using **disposable code** where a runnable check is cheap (deleted after — evidence, not a deliverable). A **reminder in the handoff context, not a routine step**; skipped for trivial mechanical work | `converge` routed and hinted but never reminded the agent to verify a finding before a downstream skill inherited it | #67 (comment) |
Everything in 004–015 not named here is unchanged. There is **no schema bump** — `## Blindspots` is a
narrative section that grows organically under `merge=union` (see *Why 017 does not bump the schema*), so
017 adds no migration step and no stamp change.

## Change A — `init` adds the `## Blindspots` section

`init` writes the mainline `context.md` from
`${CLAUDE_PLUGIN_ROOT}/skills/tsugu/templates/context.md`; 017 adds a `## Blindspots` section to that
template. Placement: after `## Open questions`, before `## Next actions` / `## Verification` /
`## Promotion candidates`, and well above the trailing POST-HANDOFF CLEANUP block (which must stay the
final lines per 015). The template's opening comment gains one line noting the section holds the territory
sweep's unknown unknowns (material + grounded; not a question list).

On the mainline the section is empty (or a one-line "no open blindspots on the mainline"). A `prepare`
branch fills it as part of rewriting the inherited form into its own story (step 8) — exactly how
`## Open questions` already works. Under `merge=union` an added `## Blindspots` body concatenates cleanly on
the human's merge; nothing about this section blocks a rebase or merge.

Illustrative skeleton position:

```
## Open questions
## Blindspots
<!-- unknown unknowns the territory sweep surfaced: convention traps, historical
     pitfalls, unnamed consumers, patterns to follow. Filter: material (changes
     architecture/data/security/scope) AND grounded (rooted in observed source,
     not a generic preference). Not a question list — that is Open questions. -->
## Next actions
## Verification
```

## Change B — `prepare` names the blindspot sweep (steps 7–8) with the filter bar

Two existing steps gain a blindspot intent; no new numbered step is added.

- **Step 7 (dispatch investigate subagents).** Today it dispatches the agent's own review/investigate
  subagents "when a change deserves a second pass." 017 names one intent of that pass explicitly: **a
  blindspot sweep** — read the territory for the unknown unknowns (convention traps, historical pitfalls,
  the second consumer nobody enumerated, the pattern the codebase already follows). This gives the
  already-dispatched subagent work a *blindspot intent*, not a new subagent.

  **The sweep's stopping rule is recurrence, not a count.** Re-sweeping is encouraged — a second look is
  where a sweep finds what the first missed, and bounding it by a pass count would buy the stopping rule by
  removing the re-checking that makes the sweep worth running. What is worth acting on is the *repeat*.

  **The identity test is list membership**, which is why the sweep **reads `## Blindspots` first**. Nothing
  finer is needed, and nothing finer is available: by step 8's bar every line on that list is already
  material and still unclosed, so "a blindspot the list already carries" is the whole trigger. Stating it as
  three conditions would be false precision — a sweep has no defined act that *closes* a blindspot (closing
  is human-present, at the verify reminder), so "could not close" would qualify nothing.

  A blindspot the list already carries, from this run or an earlier one, **is not worked again**. The
  recurrence says the answer is not in territory a sweep can read, so no further sweep can produce it — a
  human can. `prepare` writes that in the line **in prose**, with what was tried, and leaves it for the
  human at `converge`, whose pre-decision view (step 3) surfaces the `## Blindspots` lines **unordered** —
  the human reads them and judges. **No marker, no flag, no lineage field**: the state-model invariant below
  holds unchanged, and an agent that sorted the view by a recurrence marker would be classifying, which the
  spine forbids. **External silence holds**: the escalation is the record, not an interrupt. Recurrence is
  detectable across runs precisely because `context.md` carries the record on the branch.

  This is the shape `review-loop` uses in its repeat-comment guard — trigger on a concern that came back,
  not on a counter — with one honest difference: B5 keys on `file:line` and fires only after *a fix commit
  was already tried*, so its repeat proves an intervention failed. A sweep re-reads unchanged territory, so
  its repeat proves less. That is the reason the rule stops the sweep and hands over, rather than
  attempting anything itself.
- **Step 8 (maintain `context.md`).** Each surviving blindspot is recorded as a line under `## Blindspots`.
  The **filter bar is `material` + `grounded`** — a line earns its place only if it changes something that
  matters (architecture / data / security / scope) *and* is rooted in observed source, not a generic
  preference. A blindspot that turns out to be a *taste*-question (an unknown known — "which of two UX
  directions do you want") is **flagged and routed**, not answered: it rides the packet hint to brainstorming
  at converge. `prepare` opens no interview, prototype, or quiz — it is human-absent, and taste-mining is the
  workflow skill's game with the human.

The sweep is **discovery plus decision-free grounding**. `prepare` MAY write **disposable code** to ground a
blindspot — but only for **investigation that needs no human decision** (a probe, a `grep` that confirms "the
second consumer exists", a feasibility test). Its purpose is to hand `converge` **rerunnable evidence**, not
just a claim: **keep the probe** — it lands in **`knowledge/`**, never in the narrative, and `## Blindspots`
carries the one-line index and how to re-run it — so the inheritor **re-runs instead of re-trusting**.
`prepare` does **not** delete it: the code *is* the evidence, and deleting it while the human is absent
throws away exactly the richer information the probe existed to carry. There is **no reusability bar at
write time**: keep-or-prune is a judgement the human owns, deliberately deferred to merge time. **Cleanup
is deferred to the human-present phase** — the probe is pruned or promoted once the real work has
**landed** (now superseded) or is **confirmed useless**, which rides 015's **`knowledge/` reconciliation**
(the POST-HANDOFF block's second half: "prune the transient ones; a durable one is promoted to the agent
md … with the human's approval"), not a new mechanism. It does **not** ride `prune`, which deletes
branches and never files. This reuses tsugu's own existing axis — SKILL.md already foregrounds
"the decision-free vs needs-the-human split" (`prepare`, ~:105) and "decision-free code is still
reference/proof, still handed off" (~:109), and the spine already "runs builds/tests as evidence
during `prepare`/`converge`" — so a disposable probe is a strict subset
of `prepare`'s existing charter, not new machinery. What `prepare` does **not** do is **verify** in the
converge sense: any check whose result needs a human's judgment about what counts as settled waits for the
human. A blindspot line is `material + grounded` — and possibly decision-free-probed — but explicitly **not
yet human-verified**. The dividing line is exactly tsugu's spine axis: **decision-free grounding is
human-absent (`prepare`); verification that needs the human is human-present (`converge`).**

## Change C — `converge`'s verify-findings reminder

`converge` step 4 decides a disposition; step 5 waits for approval before public coordination; the closing
line notes the packet may hint which workflow skill fits but must not fire it. 017 inserts a reminder at
that boundary — after the disposition, before a skill runs:

> **Verify before you route.** Before the human triggers a workflow skill on this branch, verify the
> branch's findings — the `## Blindspots` lines especially — *together with the human*. Where a runnable
> check is cheap, write **disposable code** (a probe, a failing test, a one-off script) to turn a
> claimed fact into a checked one, then delete it — it is evidence, not a deliverable. This is a reminder,
> not a routine step: skip it for trivial mechanical work.

Why this is tsugu's job and not brainstorming's: a `## Blindspots` line is *material + grounded* but not yet
*verified*. `converge` is the cheapest place to reject a wrong finding — before a downstream skill depends on
it. This is the **small-loop principle** (prefer a runnable check over judgment) pulled one phase earlier,
onto the findings themselves. It aligns with the `context.md` template's existing `## Verification`
philosophy ("prefer runnable evidence — a committed repro script, a failing test, a probe — over prose
claims"): Change C extends that from the branch's *own claims* to the findings at the *handoff* moment.
`prepare`'s decision-free grounding (Change B) is the human-absent half of this idea; `converge`'s reminder is
the human-present half.

Every finding the human confirms or rejects at `converge` is work the later skill does not repeat.

**Scope guard.** This is a reminder in the handoff context, **not** a routine step and **not** a fifth
disposition verb. It does not gate accept / park / drop, it sets no status field, and it is skipped for
trivial mechanical work — the same right-sizing tsugu applies everywhere. `converge` still invokes no skill
and still never auto-merges.

## Why 017 does not bump the schema

The `tsugu-schema:` stamp versions the committed `.tsugu/` **layout the migrations own** — policy fields, the
`.gitattributes` file, the byte-immutable POST-HANDOFF block (015). `## Blindspots` is none of those: it is a
**pure-narrative section**, `merge=union`-safe, carrying no status field and no byte-identity requirement. So
it needs neither a migration nor a stamp change.

- **Fresh `init`** writes the new `templates/context.md` (with `## Blindspots`) from commit one.
- **Existing repos** gain `## Blindspots` **at the branch level** — the first `prepare` sweep that records a
  blindspot adds the section to that *branch's* `context.md`. The existing repo's **mainline** `context.md`
  keeps its current section set: 015's POST-HANDOFF reset collapses a branch's own-story sections (including
  `## Blindspots`) back to the mainline form *before* landing, so in the designed flow the section never rides
  onto default. That permanent mainline divergence (an old repo's mainline has no `## Blindspots` header) is
  harmless — the section is a branch-level working section, and no reader depends on the mainline carrying it.
  No migration touches the mainline file; no stamp moves. (Concatenation onto the mainline happens only on a
  *missed* reset, which nothing self-heals — see *015's BACKSTOP does not cover this case* below.)

**The one honest tension.** After 017, a freshly-`init`-ed repo and an older repo can both read
`tsugu-schema: 7` yet carry a different `context.md` skeleton (seven sections vs six). This is deliberate and
harmless: the schema contract governs the migration-owned layout, not the free-narrative section list, and a
missing narrative section blocks nothing (`merge=union` tolerates it). A bump to 8 *only* to record "the
template grew one narrative section" would be stamp ceremony with no migration behind it. If a future change
adds a section the **state model actually reads**, that earns a bump; a narrative section does not.

**A second interaction with 015, handled in a mutable file.** 015's POST-HANDOFF CLEANUP block is
**byte-immutable** (only a migration may rewrite it), and its collapse instruction enumerates the sections the
finishing agent resets — "Why this ref exists / Open questions / Next actions". Without a bump, that block
cannot be extended to name `## Blindspots`, so a literal reset could collapse the three named sections and
leave `## Blindspots` riding onto the mainline — the pollution 015 exists to prevent.

**015's BACKSTOP does not cover this case.** The BACKSTOP fires on duplicate `##` headers. A missed
`## Blindspots` collapse does not produce one: the mainline note never writes that section, so only the branch
side changed it since the merge-base, and the merge takes the branch's version as a *single* header. This holds
whether the mainline carries an empty `## Blindspots` (a post-017 repo) or none at all (an older repo).
Verified by merging both shapes under `merge=union`: the blindspot lines land on the mainline and no header is
duplicated. An earlier draft of this spec claimed the BACKSTOP self-heals the case "one landing late"; that
claim was wrong and is withdrawn.

So the instruction must reach the finishing agent by a path it actually reads. That agent works **outside**
tsugu's lifecycle and loads only the agent-md pointer and, through it, the POST-HANDOFF block in `context.md`
— never `references/notes-and-packet.md`. Recording the instruction only there leaves it without a reader.
**The instruction therefore travels with the section it governs**: the `## Blindspots` skeleton comment in
`templates/context.md` already states that the section resets with the branch story, and `prepare` keeps that
comment when it writes the section (SKILL.md, `prepare` step 8). The comment sits in `context.md`, which the
finishing agent does read. `notes-and-packet.md` keeps the same instruction for the tsugu-side reader. Neither
path needs a bump, and the immutable block is untouched.

**What is left uncovered, stated plainly.** With the BACKSTOP claim withdrawn, a *double* miss — the finishing
agent ignores the section comment *and* never reads the note — leaves the blindspot lines on the mainline with
**no detector at all**. Single-header pollution is invisible to every mechanism 015 ships. The residual risk is
accepted here because closing it needs a schema bump, and because removing `merge=union` (issue #71) deletes
the whole failure class rather than adding another detector to it.

## State model (unchanged invariant, restated)

017 sets **no status field**. `## Blindspots` is narrative; the verify reminder produces a
human/agent judgment (and possibly a disposable probe, deleted), never a derived-state transition and never a
recorded flag. State stays derived from refs / DAG / containment / recency. *Narrative informs judgment,
never classification.*

## Files touched

> Additive change — a narrative section plus two behaviour clauses. **No schema stamp moves** (see *Why 017
> does not bump the schema*), so the sprawling stamp-bump checklist 015 needed does not apply here. The
> `tsugu-schema: 7` literals across `migrations.md`, `policy-and-intake.md`, `templates/policy.md`, `README.md`,
> `commands/init.md`, `git-recipes.md`, and the dong3 root `CLAUDE.md` are **left untouched** (the init recipe
renders `context.md` by reference from the template, so it needs no section edit either).

| File | Change |
| --- | --- |
| `plugins/tsugu/skills/tsugu/templates/context.md` | add the **`## Blindspots` section** after `## Open questions` (above the POST-HANDOFF block); opening comment gains a one-line note on what the section holds and the material+grounded filter (Change A) |
| `plugins/tsugu/skills/tsugu/SKILL.md` (`prepare` steps 7–8) | step 7 gains the **blindspot-sweep intent** **and the recurrence stopping rule** (read `## Blindspots` first; a blindspot the list already carries is not worked again, the repeat recorded in prose — no flag); step 8 records surviving blindspots under `## Blindspots` with the **material + grounded** filter; taste-questions are flagged + routed, never mined (Change B) |
| `plugins/tsugu/skills/tsugu/SKILL.md` (`converge` — step 3, and after step 4's disposition at the step 5 → packet-hint region, SKILL.md:248–250) | add the **verify-findings reminder** (verify with the human before a skill runs; disposable code as evidence; reminder-not-step; skip trivial work) (Change C); and, in **step 3's pre-decision view**, surface the branch's `## Blindspots` lines **unordered** — a recurrence may change the disposition, so it must be visible before one is chosen, and the ordering stays the human's (Change B) |
| `plugins/tsugu/skills/tsugu/SKILL.md` (spine `context.md` bullet) | one clause: the skeleton now carries `## Blindspots` (narrative, material+grounded) — no schema note |
| `plugins/tsugu/skills/tsugu/references/notes-and-packet.md` | add `## Blindspots` to the `context.md` section list at lines ~25–27 (it enumerates all six current sections — verified); **add the reset clause** — the finishing agent collapses `## Blindspots` **together with** the branch's own story before landing (the byte-immutable 015 block cannot name it under the no-bump decision, so this mutable file carries it **for the tsugu-side reader**; the finishing agent's copy is the section's own skeleton comment in `context.md` — F2); note the verify-findings reminder feeds the packet's "remaining uncertainties" |
| `plugins/tsugu/commands/prepare.md` | one clause: `prepare` surfaces blindspots into `context.md`'s `## Blindspots` (material + grounded) |
| `plugins/tsugu/commands/converge.md` | one clause: `converge` reminds the agent to verify findings with the human before routing to a skill (no chain-string / schema change) |
| `plugins/tsugu/skills/tsugu/README.md` | user-facing prose only (**no stamp change**): `prepare` now surfaces blindspots (unknown unknowns) into `## Blindspots`; `converge` reminds the agent to verify findings with the human before a skill runs — the small-loop check pulled one phase earlier |
| `CLAUDE.md` (dong3 root) | tsugu paragraph: lineage `… → 015 → 017`, spec-list adds `017-tsugu-blindspots-verify-design.md`, a clause on `## Blindspots` + the converge verify reminder. **Schema stays 7.** Rides straight to `main` per the docs convention, enumerated here so the second consumer stays consistent |
| `.claude-plugin/marketplace.json` | bump tsugu `0.9.0 → 0.10.0` (feature bump, **re-verify current version**); description notes `## Blindspots` + the converge verify reminder (**no schema mention**) |
| `tools/tsugu/test-skill-content.sh` | content anchors: the `## Blindspots` header in the template, the material+grounded filter clause, `prepare`'s blindspot-sweep intent, `converge`'s verify-findings reminder + disposable-code clause; and the recurrence stopping rule. Refutes guard the **superseded** wordings only — the probe's old `## Verification` placement, the withdrawn one-sweep bound, and any `re-raised` marker (which would be the status flag this spec forbids). The no-status-field, not-a-routine-step and no-taste-mining invariants are guarded by `need` anchors on the positive wording, not by refutes. **No schema-stamp anchors — the stamp does not move** |

**No schema migration.** 015's POST-HANDOFF block + agent-md pointer, the 011 handoff model, 012 local-first,
and 013 freshness-rebase are all unchanged, and the `tsugu-schema` stamp stays at **7**.

## Explicitly rejected (from issue #67)

- **Re-packaging the eight grill-for-unknowns skills.** Ground already covered by
  nicobailon / GreatMark / Neeeophytee; 017 borrows the *one load-bearing insight* (the four unknowns split
  by human-presence) and fuses it with tsugu's two phases — it does not re-ship the framework.
- **Any interview / prototype / quiz step inside a tsugu routine.** `prepare` is human-absent; `converge`
  invokes no skill. Taste-mining is brainstorming's job.
- **A four-quadrant ledger in `context.md`.** Only `## Blindspots` is tsugu's; the other three quadrants are
  already served (known knowns → the existing narrative; known unknowns → `## Open questions`; unknown knowns
  → routed to brainstorming).
- **change-quiz / merge-gate.** That is review-loop's home, not tsugu.

017 **additionally** rules out one boundary that is not itemised in #67, but is consistent with comment 2's
scope guard: **an active detector for blindspots, or a mandatory verify phase.** `prepare` may write
**decision-free** disposable code to ground a blindspot (Change B) — that is optional investigation, already
within the spine's "runs builds/tests as evidence during `prepare`", not a mandatory scan-and-block; and
`converge`'s verification is a reminder, not a required phase.

## Design decisions (resolved during review)

- **Section placement (was Q2) → after `## Open questions`.** Not cosmetic — F2 makes `## Blindspots` a
  **branch-working** section (it collapses with the branch story at the POST-HANDOFF reset, like
  `Why this ref exists` / `Open questions` / `Next actions`), so it sits **among the working sections**, not
  with the durable `## Verification` / `## Promotion candidates`. After `## Open questions` it reads as a clean
  uncertainty escalation — *understand → known unknowns → unknown unknowns → next actions*. The alternatives
  (after `## Current understanding`, or before `## Verification`) break that escalation or misgroup it.
  Mechanics are identical under `merge=union`; only reading order and the collapse grouping differ.

- **Whether `prepare` may also write disposable code (was Q3) → yes, scoped to decision-free investigation.**
  `prepare` writes disposable code only for attempts that need **no human decision**, to gather more grounded
  information for the later collaboration; verification that needs the human stays at `converge`. The dividing
  line is tsugu's own human-absent / human-present axis, so it **sharpens** that line rather than blurring it
  (Change B). It does not breach the "no active detector / no mandatory verify phase" boundary: prepare's
  probing is optional and decision-free — the spine already runs builds/tests as evidence during `prepare` —
  and converge's verification is a reminder, not a mandatory phase.
- **Whether to bump the schema (was Q4) → no.** `## Blindspots` is a narrative section that grows organically
  under `merge=union`; a bump with no migration behind it would be stamp ceremony (see *Why 017 does not bump
  the schema*).
- **Existing-repo migration mechanics (was Q1) → moot.** With no bump there is no migration; existing repos
  gain `## Blindspots` organically on the next `prepare` sweep.

## Closes

`#67` — `prepare` surfaces blindspots (unknown unknowns) into a `## Blindspots` section of `context.md`
under a material + grounded filter (steps 7–8; taste-questions flagged and routed to brainstorming), and MAY
ground them with **decision-free** disposable code so the handoff starts richer; `converge` reminds the agent
to **verify** the branch's findings with the human — writing disposable code where a runnable check is cheap —
before any workflow skill runs (a reminder in the handoff context, not a routine step, skipped for trivial
work). Disposable code thus has two homes, split by tsugu's own human-absent / human-present axis. The four
unknowns are split the same way, so this is division of labour, not a new methodology: tsugu owns the
blindspot half and the verify moment; taste stays brainstorming's. **No schema bump** — `## Blindspots` is a
narrative section that grows organically under `merge=union`.
