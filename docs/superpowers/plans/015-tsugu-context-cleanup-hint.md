# Tsugu post-handoff cleanup hint (spec 015) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship spec 015 — a standing `POST-HANDOFF CLEANUP` block in the tsugu `context.md` template plus an always-loaded agent-md routing pointer, so the finishing agent resets the branch narrative before landing and `merge=union` never pollutes the mainline note; schema 6 → 7.

**Architecture:** Tsugu is a markdown-defined Claude Code skill — there is no runtime code. The unit of work is skill/template/reference **prose**, and the test suite is `tools/tsugu/test-skill-content.sh`, a bash script of grep-based content anchors (`need`/`refute`/`need_in`/`need_file`). TDD here = add the failing content anchor, make the prose edit, watch it pass. Each task is one coherent deliverable (a Change from the spec) with its own anchors and commit. The schema/version stamp bump lands **last** — mirroring tsugu's own "stamp written last" migration rule — so intermediate commits keep the suite green.

**Tech Stack:** Markdown skill files; bash + grep + jq test harness. No build step.

## Global Constraints

- **Test command (run from repo root):** `bash tools/tsugu/test-skill-content.sh` — must end with `All tsugu SKILL.md content checks passed.` and exit 0.
- **Repo root for all paths:** the worktree `/dev/shm/dong3/tsugu-014` (branch `feature/tsugu-post-landing-cleanup`). All paths below are relative to it.
- **The block marker string is exactly `POST-HANDOFF CLEANUP`; the pointer marker is exactly `## tsugu — post-handoff cleanup`.** Fixed within schema 7 — never vary the wording.
- **The block is an HTML comment (`<!-- ... -->`), never a `##` section.**
- **Schema stamp target: `tsugu-schema: 7`. Version target: tsugu `0.9.0` (marketplace.json only — `plugin.json` has no version field).**
- **Commit style:** conventional commits scoped `docs(tsugu):` (spec/skill prose) — this is a docs/skill change; no code. Feature branch only, never `main`.
- **Spec source of truth:** `docs/superpowers/specs/015-tsugu-context-cleanup-hint-design.md` — copy block/pointer text verbatim from it.
- **All new test anchors go under a new `# --- Spec 015 ---` section** at the end of `tools/tsugu/test-skill-content.sh` (before the final `echo`), except the existing-guard flips in Task 10 which edit lines in place.

---

### Task 1: The standing block in the `context.md` template (Change A)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/templates/context.md` (append after the final `## Promotion candidates`; add one line to the opening comment)
- Test: `tools/tsugu/test-skill-content.sh`

**Interfaces:**
- Produces: the canonical block text (marker `POST-HANDOFF CLEANUP`) that Task 4 (init note), Task 7 (migration normalize), and Task 10 depend on being present in the template.

- [ ] **Step 1: Write the failing anchors.** Append to `tools/tsugu/test-skill-content.sh` before the final `echo`:

```bash
# --- Spec 015 ---
CTX='plugins/tsugu/skills/tsugu/templates/context.md'
# NOTE: the block is hard-wrapped verbatim from the spec — every anchor below is a phrase
# that lands WITHIN a single wrapped line (grep is line-oriented; cross-line phrases never match).
need_in "$CTX" '<!-- POST-HANDOFF CLEANUP'                 "block is an HTML comment carrying the marker (not a ## section)"
need_in "$CTX" 'keep this block verbatim; never'          "block self-protection: keep verbatim (end of line 1)"
need_in "$CTX" 'delete it, never retype it'               "block forbids retyping (line 2, byte-identity)"
need_in "$CTX" 'diff against the merge-base'              "knowledge/ reconcile is merge-base-scoped"
need_in "$CTX" 'human.s approval'                         "backstop/promotion needs human approval (single-line phrase)"
grep -Eq '^## tsugu — post-handoff cleanup' "$ROOT/$CTX" && fail "context.md template must NOT contain the agent-md pointer section" || pass "context.md has no agent-md pointer (that belongs in the agent-md template)"
```

- [ ] **Step 2: Run the suite; confirm the new anchors fail.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: FAIL at `block is an HTML comment carrying the marker` (the template does not yet contain the block).

- [ ] **Step 3: Append the block to the template.** In `plugins/tsugu/skills/tsugu/templates/context.md`, after the last line (`## Promotion candidates`), add a blank line then the block **verbatim from spec §The block**:

```
<!-- POST-HANDOFF CLEANUP (standing instruction — keep this block verbatim; never
     delete it, never retype it). After tsugu hands a work branch off (converge
     accept renames prepare/<slug> to an accepted branch and stops), a human takes
     over and finishes the feature with an agent — OUTSIDE tsugu's prepare → converge
     → prune lifecycle, so no tsugu routine runs there. If you are that finishing
     agent: when you and the human are DONE, and BEFORE the branch lands on the
     default branch, reset this context.md back to the mainline form — collapse this
     branch's own story ("Why this ref exists" / "Open questions" / "Next actions")
     into a one-line "what recently landed" note under "Current understanding" — so
     what lands on default is clean and the mainline note does not accumulate a dead
     branch's narrative on merge. Then reconcile the knowledge/ entries THIS branch
     added (diff against the merge-base to find them — never touch inherited mainline
     entries): prune the transient ones; a durable one is promoted to the agent md
     (CLAUDE.md / AGENTS.md) only with the human's approval (that promotion is public
     coordination). BACKSTOP: if this reset was missed and the mainline context.md on
     the default branch already shows a landed branch's story (duplicate "##" section
     headers), the next agent that reads it collapses it the same way — but that edits
     .tsugu/context.md ON THE DEFAULT BRANCH, which is public coordination, so get the
     human's approval first. Leave THIS block in place — it must survive the reset for
     the next work. -->
```

Then, in the template's **opening HTML comment** (the `<!-- context.md — ... -->` header at the top), append this sentence before its closing `-->`: ` The trailing POST-HANDOFF CLEANUP block is a standing instruction, not part of the narrative skeleton; keep it verbatim.`

- [ ] **Step 4: Run the suite; confirm all green.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: PASS — ends with `All tsugu SKILL.md content checks passed.`

- [ ] **Step 5: Commit.**

```bash
git add plugins/tsugu/skills/tsugu/templates/context.md tools/tsugu/test-skill-content.sh
git commit -m "docs(tsugu): plant the standing POST-HANDOFF CLEANUP block in the context.md template (spec 015 Change A)"
```

---

### Task 2: The agent-md pointer template (Change E, template)

**Files:**
- Create: `plugins/tsugu/skills/tsugu/templates/agent-md-pointer.md`
- Test: `tools/tsugu/test-skill-content.sh`

**Interfaces:**
- Produces: the pointer file + marker `## tsugu — post-handoff cleanup` that Task 4 (init writes it), Task 7 (migration adds it), and Task 8 (git-recipes references it) depend on.

- [ ] **Step 1: Write the failing anchors.** Append under the `# --- Spec 015 ---` section:

```bash
PTR='plugins/tsugu/skills/tsugu/templates/agent-md-pointer.md'
need_file "$PTR"                                          "agent-md pointer template shipped"
need_in "$PTR" '^## tsugu — post-handoff cleanup'        "pointer carries its section-heading marker"
need_in "$PTR" 'BEFORE it lands'                         "pointer names the moment: before landing"
need_in "$PTR" 'POST-HANDOFF CLEANUP block'             "pointer routes the agent to the context.md block"
need_in "$PTR" 'public coordination.*approv|approval'   "pointer gates the default-branch collapse on approval"
```

- [ ] **Step 2: Run the suite; confirm failure.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: FAIL at `agent-md pointer template shipped` (file does not exist).

- [ ] **Step 3: Create the file** `plugins/tsugu/skills/tsugu/templates/agent-md-pointer.md` with **verbatim the pointer text from spec §The agent-md pointer (Change E)**:

```
## tsugu — post-handoff cleanup
This repo uses tsugu (git-native prepare/converge). When you FINISH work on an
accepted branch (an <accepted-prefix>/* branch — default feature/* bugfix/* chore/* —
that carries a .tsugu/context.md), then BEFORE it lands on the default branch, read
that file's POST-HANDOFF CLEANUP block and reset the branch narrative to the mainline
form, so the merge does not pollute the mainline note. If you ever find the default
branch's .tsugu/context.md already carrying a landed branch's narrative (duplicate
"##" section headers), collapse it the same way — but that edits the DEFAULT branch
(public coordination), so get the human's approval before you commit it.
```

- [ ] **Step 4: Run the suite; confirm all green.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add plugins/tsugu/skills/tsugu/templates/agent-md-pointer.md tools/tsugu/test-skill-content.sh
git commit -m "docs(tsugu): add the agent-md POST-HANDOFF pointer template (spec 015 Change E)"
```

---

### Task 3: `prepare` step 8 preserves the block byte-for-byte (Change B)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (`prepare` step 8 — "Maintain `context.md` on the work branch …", currently ~line 160)
- Test: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Write the failing anchors.** Append under `# --- Spec 015 ---`:

```bash
need 'do not delete it, and do not retype it|carry the trailing standing block through .*verbatim' "prepare step 8 preserves the block verbatim (Change B)"
# NB: the marker in SKILL prose is backtick-wrapped (`POST-HANDOFF CLEANUP`), so grep for a phrase WITHOUT the marker:
need 'standing instruction, HTML comment'                "prepare step 8 names the standing block (backtick-safe phrase)"
```

- [ ] **Step 2: Run; confirm failure.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: FAIL at `prepare step 8 preserves the block verbatim`.

- [ ] **Step 3: Edit SKILL.md `prepare` step 8.** Find the sentence in step 8 that reads "rewrite the inherited mainline form into the branch's own story; that first rewrite commit *is* the claim" and append immediately after it:

> **Preserve the trailing standing block.** The inherited form ends with a `POST-HANDOFF CLEANUP` block (a standing instruction, HTML comment). When you rewrite the narrative above it, **carry the trailing standing block through verbatim — do not delete it, and do not retype it.** Byte-identity is load-bearing: only an unchanged-on-both-sides block stays a single copy under `context.md`'s `merge=union`; a dropped block is deleted from default on the human's merge, and a retyped (drifted) block is duplicated. If it is ever lost or drifts anyway, an `init` re-run normalizes it (migrations `6→7`). The block is never *acted on* during `prepare` — the reset is the finishing agent's job, after handoff.

- [ ] **Step 4: Run; confirm all green.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add plugins/tsugu/skills/tsugu/SKILL.md tools/tsugu/test-skill-content.sh
git commit -m "docs(tsugu): prepare step 8 preserves the POST-HANDOFF block byte-for-byte (spec 015 Change B)"
```

---

### Task 4: `init` writes the agent-md pointer (Change E, init behavior)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (`init` routine — the "write committed `.tsugu/`" paragraph, ~line 88; the "asked once and human-approved" wording in the appended sentence covers the setup-question requirement, so the init question list is not separately edited)
- Test: `tools/tsugu/test-skill-content.sh`

**Interfaces:**
- Consumes: the pointer template from Task 2 (`templates/agent-md-pointer.md`) and the block from Task 1.

- [ ] **Step 1: Write the failing anchors.** Append under `# --- Spec 015 ---`:

```bash
# specific-to-015 phrases (avoid bare "agent md" / "CLAUDE.md" — those pre-exist in the spine and would false-pass):
need 'always-loaded channel that routes|routes any finishing agent' "init writes the agent-md pointer (Change E)"
need 'never rewrites existing agent.?md'                 "agent-md pointer is append-only, no clobber"
need 'offers to create a minimal'                        "init offers a minimal CLAUDE.md when none exists"
```

- [ ] **Step 2: Run; confirm failure.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: FAIL at `init writes the agent-md pointer`.

- [ ] **Step 3: Edit SKILL.md `init`.** In the paragraph that lists what `init` writes ("Then write committed `.tsugu/` from the plugin templates: `policy.md` … + `.tsugu/.gitattributes` …"), append a new sentence:

> **Also write the agent-md routing pointer.** `init` ensures the repo's agent md (`CLAUDE.md`, and `AGENTS.md` if the repo uses one) carries the standing `## tsugu — post-handoff cleanup` section from `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/templates/agent-md-pointer.md` — the always-loaded channel that routes any finishing agent to the `context.md` `POST-HANDOFF CLEANUP` block before landing. It is **appended as a new section and never rewrites existing agent-md content** (no clobber), **idempotent** (skip when the `## tsugu — post-handoff cleanup` marker is present), and — because it writes a human-facing doc — **asked once and human-approved** (public coordination; `init` is human-present). Absent any agent md, `init` offers to create a minimal `CLAUDE.md`. On a push-protected default it rides the same `init/*` PR as `policy.md`.

- [ ] **Step 4: Run; confirm all green.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add plugins/tsugu/skills/tsugu/SKILL.md tools/tsugu/test-skill-content.sh
git commit -m "docs(tsugu): init writes the always-loaded agent-md POST-HANDOFF pointer (spec 015 Change E)"
```

---

### Task 5: SKILL.md spine + `converge` B4 + `prune` (Change C)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (the spine bullet describing `context.md` ~line 30; `converge` near the B4 prune reminder ~line 216; the `prune` section ~line 249)
- Test: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Write the failing anchors.** Append under `# --- Spec 015 ---`:

```bash
# NB: the marker is backtick-wrapped in SKILL prose; anchor on phrases WITHOUT the marker:
need 'standing, byte-immutable'                          "spine names the byte-immutable standing block (phrase precedes the backtick-wrapped marker)"
need 'converge .*prepares .*never .*collaps|does not collapse .context.md' "converge prepares the block, never collapses"
need 'active detect-and-collapse step'                   "no prepare/converge/prune gains an active detect-and-collapse step (backtick-safe alt)"
```

- [ ] **Step 2: Run; confirm failure.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: FAIL at `spine names the byte-immutable standing block`.

- [ ] **Step 3: Make three edits in SKILL.md.**

(a) **Spine** — in the bullet describing `context.md` ("**`context.md`** — per-ref narrative: each work branch tells its own story; the default branch tells the mainline's."), append:

> The form ends with a **standing, byte-immutable `POST-HANDOFF CLEANUP` block** — a reminder that rides the accept rename to the **finishing agent** (routed by the agent-md pointer), who resets the branch narrative before landing; it is kept byte-for-byte and never deleted, the one immutable region in an otherwise freely-maintained file.

(b) **converge B4** — next to the existing B4 prune reminder ("… run `/tsugu:prune` to sweep the stale `prepare/<slug>` and the settled branch."), add:

> converge **prepares** the handoff context — it leaves the standing `POST-HANDOFF CLEANUP` block intact on the handed-off branch as the finishing agent's reminder — but **does not collapse `context.md`** (the work is not finished at converge). The mainline reset after landing is the finishing agent's job, prompted by that block and the agent-md pointer, not a converge step. *No `prepare` / `converge` / `prune` routine gains an active detect-and-collapse step; `init`'s one-time pointer-write is human-present setup, not a runtime detector.*

(c) **prune** — in the `prune` section, add one line:

> The finish-time **content** reset of a polluted mainline `context.md` is **out of `prune`'s scope** — `prune` sweeps branches, not `context.md` content; that reset lives in the standing block + the agent-md pointer.

- [ ] **Step 4: Run; confirm all green.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add plugins/tsugu/skills/tsugu/SKILL.md tools/tsugu/test-skill-content.sh
git commit -m "docs(tsugu): name the block home in spine/converge/prune; converge prepares not collapses (spec 015 Change C)"
```

---

### Task 6: Reconcile the stale `notes-and-packet.md` paragraph (Change C)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/notes-and-packet.md` (§ "Rewrite on merge-back (`include` mode)", ~lines 46–55; and the `context.md` structure section ~lines 21–31)
- Test: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Write the failing anchors.** Append under `# --- Spec 015 ---`:

```bash
NP='plugins/tsugu/skills/tsugu/references/notes-and-packet.md'
grep -Eq 'there is no state line to clean up afterwards' "$ROOT/$NP" && fail "notes-and-packet still has the stale pre-011 'no state line to clean up' claim" || pass "stale 'Rewrite on merge-back' claim removed"
grep -Eq 'converge. rewrites .context.md. into the .*ready-to-merge mainline narrative' "$ROOT/$NP" && fail "notes-and-packet still says converge rewrites context.md before merge (pre-011)" || pass "notes-and-packet no longer claims converge pre-collapses the mainline"
need_in "$NP" 'finishing agent'                          "notes-and-packet: finishing agent resets before landing"
# notes-and-packet.md is hard-wrapped ~72 cols — keep "POST-HANDOFF CLEANUP" and "inert in `exclude`" each unbroken on one line when authoring:
need_in "$NP" 'POST-HANDOFF CLEANUP'                     "notes-and-packet structure note names the standing block"
need_in "$NP" 'inert.*exclude|exclude.*inert'           "notes-and-packet: block inert in exclude mode"
```

- [ ] **Step 2: Run; confirm failure.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: FAIL at `stale 'Rewrite on merge-back' claim removed` (the stale text is still present).

- [ ] **Step 3: Rewrite the paragraph.** Replace the entire **§ "Rewrite on merge-back (`include` mode)"** paragraph (the one beginning "**Rewrite on merge-back (`include` mode).** Before the work branch merges, `converge` rewrites …" and ending "… resolved by rewriting against the then-current default during the freshness rebase.") with:

> **Reset before landing (`include` mode).** Under 011, `converge` **accept** renames `prepare/<slug>` → `<accepted-prefix>/<slug>` and **stops** — it does **not** rewrite `context.md` to a mainline narrative. The branch's own-story `context.md` rides the rename unchanged; the human and a finishing agent complete the work **outside tsugu's lifecycle**. Because `context.md` carries `merge=union`, landing the branch would otherwise concatenate its whole story onto the mainline note (duplicate `##` headers). So the **finishing agent resets `context.md` to the mainline form before landing** — prompted by the standing `POST-HANDOFF CLEANUP` block and the always-loaded agent-md pointer (spec 015). `converge` itself never rewrites the mainline. If the PR is instead rejected, the branch narrative is rewritten again at the next decision — narrative is maintained freely.

Then, in the `context.md` structure section (the "**On the default branch:** …" bullet or just after it), add:

> The mainline form ends with a **standing, byte-immutable `POST-HANDOFF CLEANUP` block** (an HTML comment, the finishing-agent reminder). It is **inert in `exclude` mode** — the human strips `.tsugu/` before the public PR, so no branch narrative reaches default and there is nothing to reset — and does real work only in `include` mode.

- [ ] **Step 4: Run; confirm all green.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add plugins/tsugu/skills/tsugu/references/notes-and-packet.md tools/tsugu/test-skill-content.sh
git commit -m "docs(tsugu): reconcile the stale pre-011 'Rewrite on merge-back' paragraph to the 011 model (spec 015 Change C)"
```

---

### Task 7: `migrations.md` — new `6 → 7` step (normalize + pointer) (Change D)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/migrations.md` (add a new `## Migration 6→7` section after the `## Migration 5→6` section, ~line 470+)
- Test: `tools/tsugu/test-skill-content.sh`

**Interfaces:**
- Consumes: the block (Task 1) and pointer (Task 2) as the artifacts it installs into existing repos.

- [ ] **Step 1: Write the failing anchors.** Append under `# --- Spec 015 ---`:

```bash
MG='plugins/tsugu/skills/tsugu/references/migrations.md'
need_in "$MG" '6 ?(→|->|to) ?7'                          "migrations has a 6->7 step"
# keep these phrases each on a single line when authoring the section (grep is line-oriented):
need_in "$MG" 're-append one canonical'                  "6->7 normalizes the block (re-append one canonical copy)"
need_in "$MG" 'reserved'                                 "6->7 relies on the reserved marker (no curated-comment collision)"
need_in "$MG" 'agent-md-pointer|agent md.*pointer|## tsugu — post-handoff cleanup' "6->7 adds the agent-md pointer"
need_in "$MG" 'tsugu-schema: 7|tsugu-schema. 7'         "6->7 stamps schema 7 last"
```

- [ ] **Step 2: Run; confirm failure.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: FAIL at `migrations has a 6->7 step`.

- [ ] **Step 3: Add the `## Migration 6→7` section** immediately after the `## Migration 5→6` section (before `## Spec 013` or whatever follows), matching the style of 5→6:

```markdown
## Migration 6→7

Schema 7 is the spec 015 layout: the mainline `context.md` gains a standing
`POST-HANDOFF CLEANUP` block, and the repo's agent md gains a routing pointer. Like
5→6, this is **structural additions only** — no policy default changes, no branch
refs move, no existing `context.md` narrative is rewritten. A schema-1 repo runs
**1→2→3→4→5→6→7** under the N→N+1 contract. Apply these three steps in order on the
`init/*` branch.

**1. Normalize the mainline `context.md` block.** Condition: always (idempotent by
construction). **Strip every** `POST-HANDOFF CLEANUP` HTML-comment block from the
default branch's mainline `.tsugu/context.md`, then **re-append one canonical copy**
(the `templates/context.md` block). One rule heals all three states: absent → adds
it; present-and-canonical → identity; drifted or duplicated (a `prepare` rewrite that
retyped or duplicated it) → collapsed to one canonical copy. The strip matches
**only the HTML-comment shape carrying the reserved marker** — `POST-HANDOFF CLEANUP`
is a **reserved string inside `.tsugu/context.md` comments**, so normalization never
touches the surrounding curated `##` narrative. This is the **first** migration to
modify an existing curated `context.md` (5→6 only added a new file); appending/
normalizing a schema-owned region is "restructure the schema part," not "overwrite
curated content."

**2. Add the agent-md pointer.** Condition: the repo's agent md lacks the
`## tsugu — post-handoff cleanup` marker. Append the section from
`${CLAUDE_PLUGIN_ROOT}/skills/tsugu/templates/agent-md-pointer.md` to `CLAUDE.md`
(and `AGENTS.md` if the repo uses one) — **append-only, never rewriting existing
content**, human-approved (public coordination; `init` is human-present). Absent any
agent md, offer to create a minimal `CLAUDE.md`. Idempotent by the marker.

**3. Stamp `tsugu-schema: 7` — last.** Only after steps 1–2 succeed, update the
`tsugu-schema:` stamp to `7` as the first line of `policy.md`. Until it is written a
re-run re-enters migration 6→7 and each step's condition guard makes the re-entry a
no-op (or, for step 1, an idempotent identity). **Push-protected exception:** the
whole migration (context.md normalize + agent-md pointer + stamp) rides an `init/*`
branch + human-approved PR, stamp the **last** write to land — as 004–013 specify.

This migration changes no policy field, touches no branch refs, and rewrites no
surrounding `context.md` narrative.
```

- [ ] **Step 4: Run; confirm all green.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add plugins/tsugu/skills/tsugu/references/migrations.md tools/tsugu/test-skill-content.sh
git commit -m "docs(tsugu): add the 6->7 migration — normalize block + add agent-md pointer (spec 015 Change D)"
```

---

### Task 8: `git-recipes.md` — agent-md pointer in the init-skeleton recipe (Change E)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/git-recipes.md` (the init-skeleton recipe, ~line 779, where it lists what `init` writes)
- Test: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Write the failing anchor.** Append under `# --- Spec 015 ---`:

```bash
need_in "$GR" 'agent-md-pointer|## tsugu — post-handoff cleanup|agent md.*pointer' "git-recipes init-skeleton writes the agent-md pointer"
```

(`GR` is already defined earlier in the test file as `plugins/tsugu/skills/tsugu/references/git-recipes.md`; reuse it.)

- [ ] **Step 2: Run; confirm failure.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: FAIL at `git-recipes init-skeleton writes the agent-md pointer`.

- [ ] **Step 3: Edit the init-skeleton recipe.** In the numbered recipe step that writes `policy.md` + mainline `context.md` + `knowledge/` + `.gitattributes`, append: ` and append the agent-md routing pointer (templates/agent-md-pointer.md) to CLAUDE.md/AGENTS.md — append-only, marker-idempotent, human-approved.`

- [ ] **Step 4: Run; confirm all green.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add plugins/tsugu/skills/tsugu/references/git-recipes.md tools/tsugu/test-skill-content.sh
git commit -m "docs(tsugu): init-skeleton recipe writes the agent-md pointer (spec 015 Change E)"
```

---

### Task 9: User-facing docs — README + dong3 CLAUDE.md prose (block + pointer)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/README.md`
- Modify: `CLAUDE.md` (dong3 root — the tsugu paragraph; **prose only** here, the schema/lineage number lands in Task 10)
- Test: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Write the failing anchors.** Append under `# --- Spec 015 ---`:

```bash
need_in 'plugins/tsugu/skills/tsugu/README.md' 'POST-HANDOFF|post-handoff cleanup' "README explains the post-handoff cleanup"
need_in 'plugins/tsugu/skills/tsugu/README.md' 'matching pointer'                  "README notes the agent-md routing pointer (specific phrase)"
need_in 'CLAUDE.md' 'post-handoff|POST-HANDOFF'                                     "dong3 CLAUDE.md notes the post-handoff block"
```

- [ ] **Step 2: Run; confirm failure.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: FAIL at `README explains the post-handoff cleanup`.

- [ ] **Step 3: Edit both docs.**

(a) `README.md` — add a short paragraph (near the converge/handoff description):

> **Post-handoff cleanup.** After `converge` hands a branch off, the human finishes it with an agent **outside tsugu's lifecycle**. Because `context.md` carries `merge=union`, landing would concatenate the branch's story onto the mainline note. So the mainline `context.md` ends with a standing **`POST-HANDOFF CLEANUP`** block, and `init` writes a matching pointer into the repo's **`CLAUDE.md`/`AGENTS.md`** (always-loaded) — together they remind the finishing agent to reset the narrative before landing. Passive, best-effort, out-of-lifecycle.

(b) dong3 root `CLAUDE.md` — in the **tsugu** paragraph, add one clause (leave the schema number for Task 10):

> 015 adds a standing **post-handoff cleanup** block in the mainline `context.md` plus an always-loaded **agent-md routing pointer** (`init` writes it to `CLAUDE.md`/`AGENTS.md`) so the finishing agent resets the branch narrative before landing.

- [ ] **Step 4: Run; confirm all green.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add plugins/tsugu/skills/tsugu/README.md CLAUDE.md tools/tsugu/test-skill-content.sh
git commit -m "docs(tsugu): document the post-handoff cleanup in README + dong3 CLAUDE.md (spec 015)"
```

---

### Task 10: Stamp schema 6 → 7 and version 0.8.0 → 0.9.0 everywhere (last)

This lands last, mirroring tsugu's "stamp written last" rule. It bumps every schema/version/lineage stamp **and** updates the pre-existing test guards that assert the old values in the same commit (so the suite never goes red). This also discharges the "stale-stamp guard" concern: the existing `need_in ... 'tsugu-schema: 6'` guards would keep passing against stale files unless flipped.

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/templates/policy.md` (stamp)
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (init stamp line; the migrate-message example; lineage `… → 013 → 015`)
- Modify: `plugins/tsugu/skills/tsugu/references/git-recipes.md` (`tsugu-schema: 6` at ~line 779)
- Modify: `plugins/tsugu/skills/tsugu/references/policy-and-intake.md` (`(current: `6`)` ~line 16; chain ~line 21)
- Modify: `plugins/tsugu/skills/tsugu/references/migrations.md` (the four `1→2→3→4→5→6` chain strings at ~22, ~298, ~442, ~476, and the longhand chain at ~299)
- Modify: `plugins/tsugu/commands/init.md` (schema + chain at ~lines 2, 15; **and** add a note that `init` now also writes the agent-md pointer — the spec's Files-touched row requires it, and nothing else in the plan covers it)
- Modify: `plugins/tsugu/skills/tsugu/README.md` (policy illustration `tsugu-schema: 6`)
- Modify: `CLAUDE.md` (dong3 root — tsugu paragraph: schema 6 → 7, lineage `… → 013 → 015`, spec-list adds `015-tsugu-context-cleanup-hint-design.md`)
- Modify: `.claude-plugin/marketplace.json` (tsugu `version` 0.8.0 → 0.9.0; `description` mentions the post-handoff block)
- Modify: `tools/tsugu/test-skill-content.sh` (flip existing guards)

- [ ] **Step 1: Add new stamp/version anchors AND flip the existing schema-6 / version-0.8.0 guards.** Append new anchors under `# --- Spec 015 ---`:

```bash
need_in 'plugins/tsugu/skills/tsugu/templates/policy.md' 'tsugu-schema: 7'    "policy template stamps schema 7"
need_in 'plugins/tsugu/skills/tsugu/references/policy-and-intake.md' 'current: .7.|schema . 7' "policy-and-intake current schema 7"
need_in 'plugins/tsugu/commands/init.md' '1→2→3→4→5→6→7'                       "init.md migration chain includes schema 7"
need_in 'plugins/tsugu/commands/init.md' 'pointer|agent md'                    "init.md notes init writes the agent-md pointer (spec Files-touched; Opus/Sonnet F4)"
need_in 'plugins/tsugu/skills/tsugu/SKILL.md' 'schema 6→7|migrate .tsugu/ schema 6→7' "SKILL.md migrate-message example says schema 6→7 (not stale 5→6)"
need_in 'plugins/tsugu/skills/tsugu/SKILL.md' '1→2→3→4→5→6→7'                   "SKILL.md init-migrate chain includes schema 7"
need_in 'plugins/tsugu/skills/tsugu/references/policy-and-intake.md' '1→2→3→4→5→6→7' "policy-and-intake chain includes schema 7"
need_in 'plugins/tsugu/skills/tsugu/references/migrations.md' '1→2→3→4→5→6→7'  "migrations chain includes schema 7"
need_in 'CLAUDE.md' '015-tsugu'                                                "dong3 CLAUDE.md references spec 015"
jq -e '.plugins[]|select(.name=="tsugu")|.version=="0.9.0"' "$ROOT/.claude-plugin/marketplace.json" >/dev/null && pass "marketplace tsugu 0.9.0" || fail "marketplace.json: tsugu not at 0.9.0"
jq -e '.plugins[]|select(.name=="tsugu")|.description|test("post-handoff|POST-HANDOFF")' "$ROOT/.claude-plugin/marketplace.json" >/dev/null && pass "marketplace desc notes post-handoff" || fail "marketplace.json: tsugu description missing post-handoff"
```

Then **flip these existing guard lines in place** (change `6`→`7` / `0.8.0`→`0.9.0`), so they assert the current schema, not the stale one:
- line ~139 and ~231 and ~358 and the two at ~139/231: the three `jq … .version=="0.8.0"` and the two `.version == 0.8.0` checks → `"0.9.0"`.
- line ~170 `need 'tsugu-schema: 6|…|schema . 6' "init stamps schema 6 …"` → `'tsugu-schema: 7|schema . 7'`, message "init stamps schema 7".
- line ~207 `need_in "$GR" 'tsugu-schema. 6'` → `'tsugu-schema. 7'`.
- line ~311 `need_in '…/templates/policy.md' 'tsugu-schema: 6'` → `'tsugu-schema: 7'`.
- line ~353 `need_in '…/commands/init.md' 'tsugu-schema: 6'` → `'tsugu-schema: 7'`.
- line ~354 `need_in '…/README.md' 'tsugu-schema: 6'` → `'tsugu-schema: 7'`.

(The chain-string guards at ~216/217/355 use `.`-wildcards or the `1→2→3→4→5→6` substring, which still match `…6→7`, so they need no flip — leave them.)

- [ ] **Step 2: Run; confirm the new/flipped anchors fail.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: FAIL at `policy template stamps schema 7` (and/or `marketplace tsugu 0.9.0`) — the content still says 6 / 0.8.0.

- [ ] **Step 3: Make the content edits.** In each file, change the stamp/version/lineage:
- `templates/policy.md`: first line `tsugu-schema: 6` → `tsugu-schema: 7`.
- `SKILL.md`: the init "**Stamp `tsugu-schema: 6`**" → `7`; the migrate-message example `schema 5→6` → `schema 6→7`; the tsugu lineage references `→ 013` gain `→ 015` (spine + init re-run "a schema-1 repo runs 1→2→3→4→5→6" → `…→6→7`).
- `git-recipes.md` ~779: `tsugu-schema: 6` → `7`.
- `policy-and-intake.md`: `(current: `6`)` → `7`; `1→2→3→4→5→6` → `…→6→7`.
- `migrations.md`: the four `1→2→3→4→5→6` → `1→2→3→4→5→6→7`; the longhand "…, then 5→6" → "…, then 5→6, then 6→7".
- `commands/init.md`: `(1→2→3→4→5→6)` → `…→6→7` (both occurrences); any `tsugu-schema: 6` → `7`; **and add a sentence** that `init` now also writes the agent-md POST-HANDOFF pointer to `CLAUDE.md`/`AGENTS.md` (spec Files-touched requirement).
- `README.md`: policy illustration `tsugu-schema: 6` → `7`.
- dong3 `CLAUDE.md`: `Schema 6 (lineage: 004 → … → 013)` → `Schema 7 (lineage: 004 → … → 013 → 015)`; add `015-tsugu-context-cleanup-hint-design.md` to the spec list.
- `marketplace.json`: tsugu `"version": "0.8.0"` → `"0.9.0"`; in the tsugu `description` **change the embedded `schema 6` → `schema 7`** (do not leave a stale one) and append a clause like `; 015 adds a standing post-handoff cleanup block in context.md + an agent-md routing pointer`.

- [ ] **Step 4: Run; confirm all green.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: PASS — `All tsugu SKILL.md content checks passed.`

- [ ] **Step 5: Commit.**

```bash
git add -A
git commit -m "docs(tsugu): bump schema 6->7 + version 0.9.0, update stale-stamp guards (spec 015)"
```

---

## Final verification

- [ ] **Run the full suite once more from a clean tree.**

Run: `bash tools/tsugu/test-skill-content.sh`
Expected: exits 0, ends with `All tsugu SKILL.md content checks passed.`

- [ ] **Grep sanity — no stray schema-6 / 0.8.0 / stale-chain left.**

Run:
```bash
# schema-6 stamps — EXCLUDE migrations.md (its 5→6 step legitimately stamps `tsugu-schema: 6`):
grep -rn 'tsugu-schema: 6\b' plugins/tsugu/ | grep -v 'references/migrations.md' ; echo "--- version ---"
# version via jq (name/version live on different JSON lines, so a line-grep would false-negative):
jq -r '.plugins[]|select(.name=="tsugu")|.version' .claude-plugin/marketplace.json ; echo "--- stale chains ---"
# any migration chain NOT extended to →7 (the `6` not followed by `→`):
grep -rnP '1→2→3→4→5→6(?![→0-9])' plugins/tsugu/ CLAUDE.md || true
```
Expected: first grep prints **nothing** (all non-migrations schema-6 stamps bumped); `jq` prints `0.9.0`; the chain grep prints **nothing** (every chain reads `…→6→7`). The only legitimate surviving `tsugu-schema: 6` is inside `references/migrations.md` (the 5→6 migration step), which must stay.

- [ ] **Confirm the two artifacts exist and carry their markers.**

Run:
```bash
grep -c 'POST-HANDOFF CLEANUP' plugins/tsugu/skills/tsugu/templates/context.md   # expect >= 1
test -f plugins/tsugu/skills/tsugu/templates/agent-md-pointer.md && echo pointer-ok
```
Expected: `>= 1` and `pointer-ok`.
