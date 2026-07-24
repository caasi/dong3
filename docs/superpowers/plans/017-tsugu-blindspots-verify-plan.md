# 017 — Tsugu blindspots + converge-verify: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.
>
> Pairs with `docs/superpowers/specs/017-tsugu-blindspots-verify-design.md` (same
> prefix). Read the spec first — this plan implements it and does not restate its rationale.

**Goal:** Add a `## Blindspots` section to tsugu's `context.md` template, name the blindspot sweep on
`prepare` (with decision-free disposable-code grounding kept as evidence), and add a verify-findings reminder
to `converge` — all as documentation edits to the tsugu skill, with **no schema bump**.

**Architecture:** tsugu ships as prose skill files (`SKILL.md`, `templates/`, `references/`, `commands/`) plus
a grep-based content test (`tools/tsugu/test-skill-content.sh`). This plan is a sequence of prose edits; the
"test" for each is a content anchor (`need` / `need_in` / `refute`) added to the test script **first** (it
fails red), then satisfied by the edit (green). There is no compiler or unit runner — the anchor grep IS the
materialized check.

**Tech Stack:** Markdown skill files; Bash content test (`set -euo pipefail`, helpers `need` / `refute` /
`need_in` / `need_file`).

## Global Constraints

- **No schema bump.** Leave every `tsugu-schema: 7` literal untouched (`migrations.md`, `policy-and-intake.md`,
  `templates/policy.md`, `README.md`, `commands/init.md`, `git-recipes.md`, dong3 root `CLAUDE.md`). Add **no**
  migration step and **no** schema anchor to the test. (Spec §*Why 017 does not bump the schema*.)
- **Implementation rides a feature branch** (dong3 convention: code/skill edits on a branch; the 017 spec +
  this plan are planning docs and may land on `main`). Branch: `feat/017-tsugu-blindspots-verify`.
- **Conventional commits, scoped `tsugu`:** `feat(tsugu):` for skill-behaviour edits, `docs(tsugu):` for
  README / root `CLAUDE.md`, `test(tsugu):` for the content-anchor additions when committed alone.
- **ASD-STE100 house rules** for the instructional prose added to `SKILL.md` / `README.md` / `commands/`: no
  idiom, one term per concept, short sentences.
- **`## Blindspots` is a branch-working section** — it collapses with the branch story at the 015 POST-HANDOFF
  reset (spec F2). Its placement (after `## Open questions`) and the reset clause (Task 4) both follow from
  that.
- Run `bash tools/tsugu/test-skill-content.sh` at the end of every task; it must exit `PASS` before the commit.

---

### Task 1: `## Blindspots` section in the `context.md` template (Change A)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/templates/context.md`
- Test: `tools/tsugu/test-skill-content.sh`

**Interfaces:**
- Produces: the `## Blindspots` header + filter comment that Task 2 (prepare records into it), Task 3 (spine
  bullet names it), and Task 4 (notes-and-packet section list, reset clause) all reference.

- [ ] **Step 1: Add the failing content anchors**

In `tools/tsugu/test-skill-content.sh`, add under a new `# --- Task: 017 Blindspots template ---` block:

```bash
need_in 'plugins/tsugu/skills/tsugu/templates/context.md' '^## Blindspots'  "context.md template has ## Blindspots"
need_in 'plugins/tsugu/skills/tsugu/templates/context.md' 'material \+ grounded'  "Blindspots filter comment (single-line phrase)"
```

**Anchor discipline (the test file documents this at its own lines 367–368):** every anchor must be a phrase
that lands **within one physical line** (grep is line-oriented, no `-z`), is **case-exact** (the helper greps
without `-i`), and has **no pre-existing match** (verified today: SKILL.md / README.md / converge.md /
notes-and-packet.md carry none of the new phrases). The `context.md` template is hard-wrapped, so Step 3 keeps
`material + grounded` unbroken on one line.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: `FAIL: plugins/tsugu/skills/tsugu/templates/context.md missing: context.md template has ## Blindspots`

- [ ] **Step 3: Insert the section into the template**

In `plugins/tsugu/skills/tsugu/templates/context.md`, add `## Blindspots` **after** `## Open questions` and
**before** `## Next actions` (it stays well above the trailing POST-HANDOFF CLEANUP block):

```
## Open questions
## Blindspots
<!-- unknown unknowns the territory sweep surfaced (convention traps, historical
     pitfalls, unnamed consumers, patterns to follow).
     Filter: material + grounded — it changes architecture/data/security/scope
     AND is rooted in observed source, not a generic preference.
     A branch-working section: it resets with this branch's story on handoff
     (not a question list — that is Open questions). -->
## Next actions
```

Keep `Filter: material + grounded — …` on **one physical line** so the `material \+ grounded` anchor matches
(this is the single-line rule from Step 1's discipline note).

Then extend the template's opening comment (the `<!-- context.md — … -->` block at the top) with one line:
`## Blindspots holds the prepare territory sweep's unknown unknowns (material + grounded; not a question
list) — a branch-working section, reset with the story on handoff.`

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: `PASS: context.md template has ## Blindspots` and `PASS: Blindspots filter comment` (all other lines still PASS).

- [ ] **Step 5: Commit**

```bash
git add plugins/tsugu/skills/tsugu/templates/context.md tools/tsugu/test-skill-content.sh
git commit -m "feat(tsugu): add ## Blindspots section to context.md template (017 Change A)"
```

---

### Task 2: `prepare` blindspot sweep + decision-free disposable-code grounding (Change B)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (`prepare` steps 7–8, lines ~159–160)
- Test: `tools/tsugu/test-skill-content.sh`

**Interfaces:**
- Consumes: `## Blindspots` (Task 1).
- Produces: the "keep the probe as evidence / cleanup deferred to human-present" behaviour Task 3's converge
  reminder and Task 4's reset clause rely on.

- [ ] **Step 1: Add the failing content anchors**

Add under `# --- Task: 017 prepare blindspot sweep (Change B) ---`:

```bash
need 'blindspot sweep|blindspot intent'                 "prepare step 7 names the blindspot sweep"
need 'material \+ grounded'                              "step 8 material+grounded filter bar"
need 'the code is the evidence'                          "prepare keeps the probe as evidence"
need 'Cleanup is deferred to the human-present'          "prepare-probe cleanup deferred to converge/finishing"
need 'flagged and routed'                                "taste-questions flagged and routed, not mined"
```

(`need 'decision-free'` already exists at test line 24 — **do not duplicate it**. SKILL.md is one long
physical line per step, so single-line phrases are safe — but when writing Step 4 keep each anchored phrase
(`material + grounded`, `the code is the evidence`, `Cleanup is deferred to the human-present`, `flagged and
routed`) **contiguous on one line** and **lowercase-exact**; the anchors match Step 4 verbatim.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: `FAIL: SKILL.md missing: prepare step 7 names the blindspot sweep`

- [ ] **Step 3: Edit `prepare` step 7 (SKILL.md ~line 159)**

Append one sentence to step 7 (the "dispatch your own review/investigate subagents" step): name the
**blindspot sweep** as an explicit intent of that pass — read the territory for unknown unknowns (convention
traps, historical pitfalls, the second consumer nobody enumerated, the pattern the codebase already follows).
It is a blindspot *intent* on the existing subagents, not a new subagent.

- [ ] **Step 4: Edit `prepare` step 8 (SKILL.md ~line 160)**

Add to step 8 (the "maintain `context.md`" step): each surviving blindspot is recorded under `## Blindspots`
with the **material + grounded** filter (a line earns its place only if it changes architecture / data /
security / scope AND is rooted in observed source). A blindspot that is really a *taste*-question is **flagged
and routed** to brainstorming at converge, never mined in `prepare`. `prepare` MAY write **decision-free**
disposable code to ground a blindspot and **keeps it** as rerunnable evidence — a committed repro script under
`## Verification`, or `knowledge/` if reusable — because the code is the evidence; it does **not** delete it
while the human is absent. Cleanup is **deferred to the human-present phase** (`converge` / finishing), where
the probe is removed once the real work has **landed** or is **confirmed useless** (riding 015's POST-HANDOFF
reset + `prune`). Keep the prose within the ASD-STE house rules.

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: all five new anchors `PASS`; every pre-existing line still `PASS` (esp. the `refute` lines untouched).

- [ ] **Step 6: Commit**

```bash
git add plugins/tsugu/skills/tsugu/SKILL.md tools/tsugu/test-skill-content.sh
git commit -m "feat(tsugu): prepare blindspot sweep + decision-free probe kept as evidence (017 Change B)"
```

---

### Task 3: `converge` verify-findings reminder + spine bullet (Change C)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (`converge` step 4→5 / packet-hint region ~lines 248–250; spine
  `context.md` bullet)
- Test: `tools/tsugu/test-skill-content.sh`

**Interfaces:**
- Consumes: `## Blindspots` (Task 1); the prepare-probe evidence model (Task 2).

- [ ] **Step 1: Add the failing content anchors**

Add under `# --- Task: 017 converge verify reminder (Change C) ---`:

```bash
need 'verify .{0,20}findings|Verify before you route'   "converge verify-findings reminder present"
need 'reminder, not a routine step'                     "verify is a reminder, not a routine step"
need 'not a .{0,6}fifth .{0,12}(disposition|verb)'      "verify reminder is not a fifth disposition"
need 'branch-working'                                   "spine context.md bullet names Blindspots as branch-working"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: `FAIL: SKILL.md missing: converge verify-findings reminder present`

- [ ] **Step 3: Add the reminder to `converge`**

At the boundary **after** step 4's disposition and the step-5 approval line, near the closing "packet may
**hint** which workflow skill fits … but must not fire it" line (SKILL.md ~250), insert the reminder:

> **Verify before you route.** Before the human triggers a workflow skill on this branch, verify the branch's findings — the `## Blindspots`
> lines especially — together with the human. Where a runnable check is cheap, write disposable code to turn a
> claimed fact into a checked one, then delete it (the human watched it run — it is evidence, not a
> deliverable). This is a **reminder, not a routine step** and **not a fifth disposition verb**; it gates
> nothing, sets no status field, and is skipped for trivial mechanical work.

**Do not** reproduce the maintenance-path "freshness-rebase … → verify … → rewrite" chain (test line 38's
`refute` guards it — keep the reminder textually clear of the refresh/accept mechanics).

- [ ] **Step 4: Name `## Blindspots` in the spine `context.md` bullet**

In the spine description of `context.md` (the "## The spine" region), add one clause: the skeleton now carries
`## Blindspots` (narrative; material + grounded), a branch-working section reset with the story on handoff. No
schema note.

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: the three new anchors `PASS`; all pre-existing lines still `PASS`.

- [ ] **Step 6: Commit**

```bash
git add plugins/tsugu/skills/tsugu/SKILL.md tools/tsugu/test-skill-content.sh
git commit -m "feat(tsugu): converge verify-findings reminder before skills fire (017 Change C)"
```

---

### Task 4: Second consumers — notes-and-packet, commands, README (Change A/B/C sync + F2 reset clause)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/notes-and-packet.md` (section list ~25–27; reset paragraph)
- Modify: `plugins/tsugu/commands/prepare.md`, `plugins/tsugu/commands/converge.md`
- Modify: `plugins/tsugu/skills/tsugu/README.md` (prose only — **no stamp change**)
- Test: `tools/tsugu/test-skill-content.sh`

**Interfaces:**
- Consumes: everything from Tasks 1–3.

- [ ] **Step 1: Add the failing content anchors**

```bash
need_in 'plugins/tsugu/skills/tsugu/references/notes-and-packet.md' '## Blindspots'  "notes-and-packet lists ## Blindspots"
need_in 'plugins/tsugu/skills/tsugu/references/notes-and-packet.md' 'collapses Blindspots'  "F2 reset clause (one-line phrase)"
need_in 'plugins/tsugu/skills/tsugu/references/notes-and-packet.md' 'remaining uncertaint'  "verify reminder feeds packet remaining uncertainties"
need_in 'plugins/tsugu/commands/prepare.md'  '[Bb]lindspot'   "prepare command mentions blindspots"
need_in 'plugins/tsugu/commands/converge.md' 'verify findings'  "converge command names the verify reminder (not pre-existing)"
need_in 'plugins/tsugu/skills/tsugu/README.md' '[Bb]lindspot' "README mentions blindspots"
```

Anchor notes: `converge.md` already contains the bare word "verify" (line 18, a 013-vintage phrase), so the
anchor is the **two-word** `verify findings` (confirmed absent today). `collapses Blindspots` is a two-word
phrase — Step 3 keeps those two words **adjacent on one physical line** (`notes-and-packet.md` is ~72-col
hard-wrapped). `remaining uncertaint` is absent today, so red-first holds.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: `FAIL: plugins/tsugu/skills/tsugu/references/notes-and-packet.md missing: notes-and-packet lists ## Blindspots`

- [ ] **Step 3: Edit `notes-and-packet.md`**

(a) In the `context.md` section list (lines ~25–27) add `## Blindspots` to the enumerated sections.
(b) In the reset paragraph (the finish-time collapse guidance), add the **F2 clause** — write it so the words
**`collapses Blindspots`** stay adjacent on one line, e.g. *"the finishing agent collapses Blindspots together
with the branch's own story before landing."* The byte-immutable 015 POST-HANDOFF block cannot name the new
section under the no-bump decision, so this mutable file carries the instruction; without it a literal reset
leaves `## Blindspots` polluting the mainline (the 015 duplicate-`##` BACKSTOP still self-heals, one landing
late).
(c) Add one clause noting the **converge verify-findings reminder feeds the packet's "remaining
uncertainties"** (the spec's notes-and-packet row).

- [ ] **Step 4: Edit the command files**

`commands/prepare.md`: one clause — `prepare` surfaces blindspots into `context.md`'s `## Blindspots` (material
+ grounded) and may keep a decision-free probe as evidence.
`commands/converge.md`: one clause — `converge` reminds the agent to verify findings with the human before
routing to a skill. No chain-string / schema change.

- [ ] **Step 5: Edit `README.md` (prose only)**

Add user-facing prose (no `tsugu-schema` edit): `prepare` now surfaces blindspots (unknown unknowns) into
`## Blindspots`; `converge` reminds the agent to verify findings with the human before a skill runs — the
small-loop check pulled one phase earlier.

- [ ] **Step 6: Run the test to verify it passes, then commit**

Run: `bash tools/tsugu/test-skill-content.sh` → all new anchors `PASS`.

```bash
git add plugins/tsugu/skills/tsugu/references/notes-and-packet.md plugins/tsugu/commands/prepare.md \
        plugins/tsugu/commands/converge.md plugins/tsugu/skills/tsugu/README.md tools/tsugu/test-skill-content.sh
git commit -m "feat(tsugu): sync second consumers + F2 reset clause for ## Blindspots (017)"
```

---

### Task 5: Metadata + refutation anchors — marketplace version, root CLAUDE.md, guard rails

**Files:**
- Modify: `.claude-plugin/marketplace.json` (tsugu `0.9.0 → 0.10.0`; description)
- Modify: `CLAUDE.md` (dong3 root — tsugu paragraph)
- Test: `tools/tsugu/test-skill-content.sh`

**Interfaces:**
- Consumes: all prior tasks (this is the closing consistency pass).

- [ ] **Step 1: Add the closing anchors**

**Flip the four existing tsugu-version assertions — do not add a new one.** The test already hard-asserts
`tsugu == 0.9.0` via `jq` in **four** places: lines **139–140, 231–232, 358–359, 430** (blocking finding F-1 —
leaving them makes the suite `FAIL` the instant the version bumps). Change each `"0.9.0"` → `"0.10.0"` (and the
`pass` strings). These flipped assertions **are** the red-first anchor: they fail until Step 3 bumps
`marketplace.json`, then pass. Do **not** add a file-wide `grep '"0.10.0"'` — it is unscoped (`compose` is
already `0.11.0`, so a file-wide grep false-greens). Leave every `tsugu-schema: 7` / schema-7 assertion in the
same block (line ~420) **untouched** — no bump.

Then add the CLAUDE.md anchor + the **durable tree-wide no-bump gate** (executable, not a comment):

```bash
need_in 'CLAUDE.md' '017-tsugu-blindspots-verify'            "root CLAUDE.md lists spec 017"
refute 'tsugu-schema: 8'                                     "no schema-8 stamp in SKILL.md"
# tree-wide no-bump gate — the stamp lives in templates/policy.md, migrations.md, README.md, commands/init.md,
# policy-and-intake.md, NOT only SKILL.md; guard the whole tree with a REAL check (never a comment):
! grep -rn 'tsugu-schema: 8' "$ROOT/plugins/tsugu" >/dev/null 2>&1 \
  || fail "tsugu-schema: 8 leaked — 017 is a no-bump change"
pass "no-bump invariant: no tsugu-schema: 8 anywhere under plugins/tsugu"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: `FAIL: marketplace.json: tsugu not at 0.10.0` — the flipped assertion at line ~140, red until Step 3 bumps the version.

- [ ] **Step 3: Bump the marketplace version + description**

In `.claude-plugin/marketplace.json`, tsugu `0.9.0 → 0.10.0`; append to its description: adds `## Blindspots`
(prepare surfaces unknown unknowns) + a converge verify-findings reminder. **No schema mention.** (Confirm
`plugins/tsugu/.claude-plugin/plugin.json` has no `version` field — leave it; do not add a schema mention.)

- [ ] **Step 4: Update the dong3 root `CLAUDE.md` tsugu paragraph**

Lineage `… → 013 → 015 → 017`; add `017-tsugu-blindspots-verify-design.md` to the spec list; one clause on
`## Blindspots` + the converge verify reminder. **Schema stays 7** — do not write "schema 8". This file rides
straight to `main` per the docs convention.

- [ ] **Step 5: Run the full test, then commit**

```bash
bash tools/tsugu/test-skill-content.sh   # all PASS — incl. the 4 flipped 0.10.0 assertions + the tree-wide no-bump gate
```

```bash
git add .claude-plugin/marketplace.json CLAUDE.md tools/tsugu/test-skill-content.sh
git commit -m "feat(tsugu): bump marketplace 0.10.0 + doc sync, no schema bump (017)"
```

---

## Self-Review

- **Spec coverage:** Change A → Task 1; Change B (sweep, filter, keep-probe-as-evidence, deferred cleanup,
  flag-and-route) → Task 2; Change C (verify reminder, spine bullet) → Task 3; second consumers + F2 reset
  clause → Task 4; marketplace + root CLAUDE.md + no-bump guard → Task 5. §*Why no schema bump* is honoured by
  the Global Constraint + the Task 5 guard (no migration task, no stamp edit, tree-wide schema-8 check). Q2
  placement (after `## Open questions`) → Task 1 Step 3.
- **No-op dropped:** the spec dropped the `git-recipes.md` row (init recipe reads the template by reference);
  no task touches it, matching the finalized Files-touched table.
- **Refutation coverage:** the spec's "refute status-field / fifth-disposition / taste-mining" become the
  positive anchors in Task 2 (`flagged and routed`) and Task 3 (`not a fifth disposition`, `reminder, not a
  routine step`); a clean grep for the *absence* of a status field is not reliable, so it stays a review-read
  item, noted here rather than forced into a brittle `refute`.
- **Anchor discipline (added after plan review — three reviewers executed the greps against the drafted
  prose):** every content anchor is a **single-physical-line, case-exact** phrase with **no pre-existing
  match** (verified by grep before drafting). The version bump **flips the four existing `0.9.0` jq
  assertions** (lines 139/231/358/430) rather than adding an unscoped file-wide grep — F-1 was blocking: the
  suite would otherwise `FAIL` the moment the version changed. The no-bump invariant is a **tree-wide
  executable gate**, not a SKILL-only `refute` or a comment.
- **Ordering:** Task 1 produces the header every later task references; Tasks 2–3 are the behaviour edits;
  Task 4 syncs consumers; Task 5 closes metadata + guards. Each task is independently testable and committable.
