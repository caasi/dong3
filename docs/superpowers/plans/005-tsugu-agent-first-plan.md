# Tsugu v1.1 (agent-first revisions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship spec 005 — three namespaced commands, intake-source recording, the derived-state lifecycle (slug pairing + containment, pure-narrative `context.md`, `knowledge/`), and `tsugu-schema` migration — across the tsugu plugin's 14 affected files.

**Architecture:** This is a prose-artifact plugin (SKILL.md + commands + templates + references); there is no build system or test runner. Every task therefore replaces "failing test first" with **deterministic grep assertions**: each task ends by running exact `grep` checks with expected output (the prose equivalent of a passing test), then commits. The spec at `docs/superpowers/specs/005-tsugu-agent-first-design.md` is the single source of truth — every task cites the spec section it implements; where wording is load-bearing (the partition table, the orientation principle, recipes), this plan embeds it verbatim.

**Tech Stack:** Markdown, git, `grep`, `jq` (for the two JSON metadata files). Conventional commits scoped `feat(tsugu)` / `docs(tsugu)` / `chore`.

**Worker context rules (read first):**

- Implementation goes on a **feature branch in a RAM-disk worktree** (Task 0). Never commit to `main`. Every git command must run inside the worktree (`cd` into it or use `git -C <worktree>`); a worktree shares `.git/` with the main checkout, so a `git commit` from the wrong cwd lands on whatever branch the main checkout has.
- The repo does not GPG-sign (verified: `git config --get commit.gpgsign` is unset) — commit normally.
- `plugins/tsugu/` is the **install boundary**: everything inside ships to users. Do not add dev tooling, scripts, or scratch files there.
- 004 (`docs/superpowers/specs/004-tsugu-skill-design.md`) remains in the repo untouched — it is a historical document that 005 supersedes in named places. **Do not edit 004.**

---

## File structure (what ships after this plan)

```text
plugins/tsugu/
  .claude-plugin/plugin.json           # MODIFY: description → three routines
  commands/
    tsugu.md                           # DELETE
    init.md                            # NEW  thin router → /tsugu:init
    prepare.md                         # NEW  thin router → /tsugu:prepare
    converge.md                        # NEW  thin router → /tsugu:converge
  skills/tsugu/
    SKILL.md                           # REWRITE: three routines, derived state
    README.md                          # REWRITE: surface + lifecycle + diagram
    references/
      git-recipes.md                   # REWRITE: containment/slug recipes
      notes-and-packet.md              # REWRITE: context.md, knowledge/, loads
      policy-and-intake.md             # REWRITE: new fields, landed:, recon.
      migrations.md                    # NEW: rules + migration 1→2
    templates/
      branch.md                        # DELETE (replaced by context.md)
      context.md                       # NEW: pure narrative, per-ref
      policy.md                        # REWRITE: schema 2 fields
      intake.md                        # MODIFY: landed: field
      packet.md                        # MODIFY: suggested-branch comment
      run.md                           # MODIFY: slug-keyed filename note
.claude-plugin/marketplace.json        # MODIFY: tsugu description + 0.1.0→0.2.0
CLAUDE.md                              # MODIFY: tsugu section (three commands)
```

Spec cross-reference: "Affected surface" table in
`docs/superpowers/specs/005-tsugu-agent-first-design.md`.

---

### Task 0: Worktree on the RAM disk

**Files:** none (environment setup)

- [ ] **Step 1: Check for the RAM disk**

Run: `ls /Volumes/ramdisk 2>/dev/null && echo "RAM disk present" || echo "no RAM disk"`

If **absent**: STOP and ask the human to create one (their call on size; suggested command for 4 GB: `diskutil erasevolume HFS+ "ramdisk" $(hdiutil attach -nomount ram://8388608)`). Do not create it yourself; do not fall back to an in-repo worktree.

- [ ] **Step 2: Create the worktree + feature branch**

```bash
git -C /Users/caasi/GitHub/caasi/dong3 worktree add /Volumes/ramdisk/dong3/spec-005 -b feat/tsugu-v1.1 main
```

- [ ] **Step 3: Verify**

Run: `git -C /Volumes/ramdisk/dong3/spec-005 status --short --branch`
Expected: `## feat/tsugu-v1.1` and a clean tree.

All subsequent tasks run inside `/Volumes/ramdisk/dong3/spec-005`. Paths below are relative to that worktree root.

---

### Task 1: Templates — `context.md` replaces `branch.md`

**Spec:** C2 (pure narrative, per-ref, runnable evidence, no lineage).

**Files:**
- Create: `plugins/tsugu/skills/tsugu/templates/context.md`
- Delete: `plugins/tsugu/skills/tsugu/templates/branch.md`

- [ ] **Step 1: Write `templates/context.md`** with exactly this content:

```markdown
<!-- context.md — this ref's situation and origin, in pure narrative.
     No status, no claim fields, no recorded lineage: live state is derived
     from refs and the DAG (see SKILL.md). On the default branch this file
     describes the mainline (what this repo is, where the mainline stands,
     what recently landed — init writes the first version). A new work branch
     inherits the mainline form; rewriting it into the branch's own story is
     the first act of real work, and that rewrite commit is the claim. -->
## Why this ref exists
## Current understanding
## Open questions
## Next actions
## Verification
<!-- prefer runnable evidence — a committed repro script, a failing test, a
     probe — over prose claims; the next inheritor re-runs instead of
     re-trusting -->
## Promotion candidates
## This work's files
<!-- links to this slug's packet and run notes, e.g.
     packets/<slug>.md · runs/<slug>-<date-time>.md -->
```

- [ ] **Step 2: Delete the old template**

```bash
git rm plugins/tsugu/skills/tsugu/templates/branch.md
```

- [ ] **Step 3: Verify**

Run: `grep -c "status:" plugins/tsugu/skills/tsugu/templates/context.md`
Expected: `0`
Run: `ls plugins/tsugu/skills/tsugu/templates/`
Expected: `context.md intake.md packet.md policy.md run.md` (no `branch.md`)

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/templates/
git commit --message "feat(tsugu): context.md template replaces branch.md — pure narrative, per-ref (spec 005 C2)"
```

---

### Task 2: Templates — `policy.md` schema 2

**Spec:** C3–C6 fields, B recorded form, housekeeping threshold, D stamp. The Ripple bullet lists every field.

**Files:**
- Rewrite: `plugins/tsugu/skills/tsugu/templates/policy.md`

- [ ] **Step 1: Replace the file** with exactly this content:

```markdown
tsugu-schema: 2
## Private Git Space (agent may do freely)
create/commit/push `prepare/*` / `investigate/*` / `review/*` branches; worktrees; write `.tsugu/*`;
run tests; try reversible patches; dispatch own (built-in) review subagents
## Public Coordination (ask first)
open MR/PR; tracker comment / status change; assign reviewers; Slack;
public commitments; move findings into human-facing docs; irreversible cleanup
## Branch Prefixes
prepare/*  investigate/*  review/*
<!-- work prefixes (the queue). Must be DISJOINT from Handoff Prefixes — init
     and migration validate this. -->
## Handoff Prefixes
feat/*  fix/*
<!-- human-workflow branches converge cuts for PRs. A branch here with the
     same slug as a work branch = that work is decided, awaiting merge. -->
## Public branch
public-branch-tsugu: include
<!-- include (default): the work branch is what merges; its .tsugu/ evidence
     lands on the default branch as durable shared memory.
     exclude: cut a clean public branch by path — no .tsugu/ in the PR diff. -->
## Merge method
Prefer merge commits — do not squash-merge tsugu-managed branches: derived
settlement depends on preserved history. If a human system forces a squash,
converge confirms the landing and records `landed: <sha>` in the intake note.
## Housekeeping
stale-after: 30 days
<!-- converge surfaces in-progress branches / open intake notes older than
     this for human-decided cleanup; a scheduled prepare never cleans. -->
## Remote
remote: origin                   # authoritative remote for fetch + branch enumeration (multi-remote safety)
default-branch:                  # optional; if blank, resolved from <remote>/HEAD
## Coordination ref
coordination-ref: default        # where intake/ + knowledge/ are written.
<!-- `default` is a sentinel = the repo's default branch (resolves to <default>, not a
branch literally named "default"). Set to a branch (e.g. tsugu/coord) only if the
default branch is push-protected. -->
## Intake Sources
default: git-native. Each additional source below is read on every prepare run.
<!-- a source = a name, ONE read instruction (shell command / file path / MCP
     tool name), and an interpretation hint. Not limited to task systems —
     RSS feeds, security watches (YARA/CVE), CI queries fit the same shape.
- name: my-todos
  read: `cat ~/notes/todo.md`
  notes: lines starting with "- [ ]" are open tasks; mention repo names to scope.
-->
## Skill use
Tsugu invokes no user-installed skill by default; it uses native git + its own
built-in capabilities. Humans trigger workflow skills (planning, review-loop, …)
by keyword.
## Skills Tsugu may use (this repo, opt-in)
None by default. List user-installed skills Tsugu may use during human-absent
prepare in THIS repo (e.g. systematic-debugging). Repo-local only — the shipped
SKILL.md never names skills.
## Recursion
Recurse into submodules / child repos only when relevant to the current goal /
intake / branch.
```

- [ ] **Step 2: Verify**

Run: `grep -c "tsugu-schema: 2" plugins/tsugu/skills/tsugu/templates/policy.md`
Expected: `1`
Run: `grep -n "public/\*" plugins/tsugu/skills/tsugu/templates/policy.md`
Expected: no output (the `public/*` prefix is retired — spec supersession table)
Run: `grep -c "context/shared" plugins/tsugu/skills/tsugu/templates/policy.md`
Expected: `0` (coordination-ref comment now says `knowledge/`)

- [ ] **Step 3: Commit**

```bash
git add plugins/tsugu/skills/tsugu/templates/policy.md
git commit --message "feat(tsugu): policy.md template schema 2 — handoff prefixes, public-branch-tsugu, merge method, housekeeping, intake form (spec 005 B/C/D)"
```

---

### Task 3: Templates — `intake.md`, `packet.md`, `run.md`

**Spec:** C4 (`landed:` write-once, validated), Ripple (packet comment, run filename).

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/templates/intake.md`
- Modify: `plugins/tsugu/skills/tsugu/templates/packet.md`
- Modify: `plugins/tsugu/skills/tsugu/templates/run.md`

- [ ] **Step 1: `intake.md`** — replace the two header fields and keep the body sections unchanged, so the file reads:

```markdown
status: open          # open | claimed | done | dropped
linked-branch:        # write-once breadcrumb set when status → claimed
landed:               # write-once; set at the done flip ONLY when landing is not
                      # containment-derivable (a forced squash). Validate before
                      # writing: the SHA must resolve and be contained in the
                      # fetched default ref.
## Observed source    (git-native self-note / agent-discovered / human-bridge: <ref>)
## Summary
## Related repos
## Initial guess
## Need human context
```

- [ ] **Step 2: `packet.md`** — replace the final section + comment (everything else unchanged):

```markdown
## Suggested handoff branch
<!-- the slug-paired branch converge will cut under a Handoff Prefix.
     include mode: same commits as the work branch (merge it as-is);
     exclude mode: cut fresh from default, accepted changes applied by path. -->
```

(Replaces `## Suggested public branch` and its "not push this branch as-is" comment.)

- [ ] **Step 3: `run.md`** — prepend one comment line:

```markdown
<!-- filename: runs/<slug>-<date-time>.md — slug-keyed so accumulated runs on
     the default branch stay attributable to their work item -->
```

- [ ] **Step 4: Verify**

Run: `grep -c "landed:" plugins/tsugu/skills/tsugu/templates/intake.md`
Expected: `1`
Run: `grep -c "Suggested public branch" plugins/tsugu/skills/tsugu/templates/packet.md`
Expected: `0`
Run: `grep -c "runs/<slug>-<date-time>.md" plugins/tsugu/skills/tsugu/templates/run.md`
Expected: `1`

- [ ] **Step 5: Commit**

```bash
git add plugins/tsugu/skills/tsugu/templates/
git commit --message "feat(tsugu): intake landed: field, handoff-branch packet wording, slug-keyed run filenames (spec 005 C4 + ripple)"
```

---

### Task 4: `references/git-recipes.md` — containment & slug recipes

**Spec:** C4 (partition + checks), C1 (converge flows), Ripple bullet for this file.

**Files:**
- Rewrite: `plugins/tsugu/skills/tsugu/references/git-recipes.md`

This is a section-by-section rewrite. Keep the existing document's voice (recipes-not-scripts preamble, full-length CLI options, resolved `<remote>`/`<default>` placeholders) and these sections **unchanged in substance**: "Read the queue" steps 1–3 (fetch --prune / resolve remote / resolve default), "Coordination-ref writes" (only path rename: `context/shared` → `knowledge/`), "Freshness", "Cleanup order".

- [ ] **Step 1: Update "Read the queue" steps 4–7:**

  - Step 4 (enumerate): work prefixes default becomes `prepare`, `investigate`, `review` from policy's Branch Prefixes; **also enumerate the configured Handoff Prefixes** (`feat`, `fix`, legacy `public`) into a separate handoff list for slug pairing. Remove the "Do not include public/*" sentence (the prefix is retired; legacy `public/*` arrives via Handoff Prefixes — see migrations).
  - Step 5 (read context): `git show <branch-ref>:.tsugu/context.md`, with the compat line: *fall back to `.tsugu/branch.md` when `context.md` is absent (schema-1 branch); treat a legacy `status: settled` as skip, surface a legacy `converged` at converge.*
  - Step 6 (intake notes): path stays `.tsugu/intake/`; no change beyond surrounding wording.
  - Step 7 (partition): **replace the status×claimed table verbatim with the spec's C4 table:**

```markdown
| Fact | State | Disposition |
| --- | --- | --- |
| tip contained in `<remote>/<default>` (in `exclude` mode: the slug-paired public branch's tip) — or its intake note records a valid `landed:` | **settled** | skip; completion-tail / cleanup candidate |
| a branch with the **same slug** exists under a configured Handoff Prefix | **decided, awaiting merge** | skip as a candidate; shown in converge's awaiting-merge section |
| neither | **in progress** | candidate: read `context.md`, judge from the narrative |
```

  followed by the exact checks:

```bash
# settled? (containment)
git merge-base --is-ancestor <branch-ref> <remote>/<default> && echo settled
# pending? (slug pairing — names, not commits)
slug="${branch#*/}"   # strip the work prefix
git branch --remotes --format='%(refname:short)' \
  | grep -E "^<remote>/(feat|fix|public)/${slug}$"   # configured handoff prefixes
```

  and these rules as prose bullets (from C4): zero-commit branches are exempt from the whole table (claimed-linked = interrupted work; note-less = request-by-branch; never cleanup targets); slugs are never reused — collisions surface at converge as naming conflicts; claims = the `context.md` rewrite commit's author + timestamp, degrading to pure recency under one shared git identity; zero-commit claim recency comes from the note's claimed-flip commit on the coordination ref; a `landed:` SHA is validated on read (must resolve + be contained in default, else reconciliation).

- [ ] **Step 2: Replace "Cut a clean public branch" with two converge arms:**

  **"Hand off for merge (include mode — default)"**: freshness-rebase the work branch onto `<remote>/<default>` → verify → rewrite `context.md` to the ready-to-merge mainline narrative → push → either the human merges the work branch directly (solo), or:

```bash
git branch <handoff-prefix>/<slug> <work-branch>     # same commits, second name, same slug
git push --set-upstream <remote> <handoff-prefix>/<slug>
# the human opens/approves the PR on the handoff branch
```

  Update the handoff branch only by **merge**, never rebase. Divergence (work tip has commits the handoff lacks) and no-shared-history collision flags apply in include mode only.

  **"Cut a clean public branch (exclude mode)"**: keep the existing recipe (three-dot path-scoped diff, `git apply --index --binary`, the `.tsugu/`-empty sanity check) with two adjustments — the branch is named `<handoff-prefix>/<slug>` (same slug, so pending derives from pairing), and landing is later confirmed via *this* branch's containment in default.

- [ ] **Step 3: Add a "Completion tail" section** (from C1, order is load-bearing):

```markdown
Once landing is confirmed — containment, or the human's converge confirmation
recording `landed: <sha>` where a squash was forced — run, in this order:
1. promote reusable knowledge into `.tsugu/knowledge/` (coordination-ref write);
2. flip the intake note `claimed → done` (+ `landed:` only when not
   containment-derivable; validate the SHA before writing);
3. only then clean up: `git worktree remove <path>` before
   `git branch --delete --force <branch>` — the handoff branch too, if the
   forge didn't already delete it.
Branch deletion comes last: the branch is the landing evidence. Idempotent —
interrupted before the flip, the note stays claimed with its branch intact and
a later tidy re-enters the whole tail.
```

- [ ] **Step 4: Update "init skeleton":** directory list becomes `.tsugu/intake`, `.tsugu/knowledge`, `.tsugu/templates` (seeded with `.gitkeep`); `policy.md` written with `tsugu-schema: 2`; add one line: *re-run on an older schema applies `references/migrations.md` in order, stamp last.* Update the coordination-ref bootstrap paths (`context/shared` → `knowledge/`).

- [ ] **Step 5: Verify**

Run: `grep -n "branch.md" plugins/tsugu/skills/tsugu/references/git-recipes.md`
Expected: only lines that mention the **legacy fallback** (schema-1 compat)
Run: `grep -c "merge-base --is-ancestor" plugins/tsugu/skills/tsugu/references/git-recipes.md`
Expected: ≥ 1
Run: `grep -n "context/shared" plugins/tsugu/skills/tsugu/references/git-recipes.md`
Expected: no output
Run: `grep -n "status: open" plugins/tsugu/skills/tsugu/references/git-recipes.md`
Expected: no output in any partition table (intake-note lifecycle mentions are fine)

- [ ] **Step 6: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/git-recipes.md
git commit --message "feat(tsugu): git-recipes — containment+slug partition, handoff/exclude arms, completion tail, knowledge/ paths (spec 005 C1/C4)"
```

---

### Task 5: `references/notes-and-packet.md` — note semantics

**Spec:** C2, C3, Ripple bullet for this file.

**Files:**
- Rewrite: `plugins/tsugu/skills/tsugu/references/notes-and-packet.md`

- [ ] **Step 1: Rewrite section by section:**

  - **`context.md` section** (replaces the `branch.md` section): per-ref pure narrative; the inherit → rewrite cycle; the rewrite commit *is* the claim; merge-back rewrite to the ready-to-merge mainline narrative (include mode); links to this slug's own packet/runs; runnable-evidence preference; **no status, no claim fields, no lineage** (lineage-to-mainline is ancestry; a forced squash gets `landed:` instead; cross-work-branch lineage is scratch-grade). Backward-compat paragraph: legacy `branch.md` accepted when `context.md` absent; legacy `status:` folded into narrative on next touch (`settled` → cleanup candidate, `converged` → surface at converge).
  - **`intake/` section**: two-layer table updated — the work layer's status column is replaced by "derived from refs and the DAG (see SKILL.md partition)". Lifecycle text: flip to `claimed` records `linked-branch:`; flip to `done` happens at confirmed landing as the completion tail's last-before-cleanup step, recording `landed: <sha>` only when a forced squash severed containment (validated on write and read); a claimed note whose branch vanished without evidence is a reconciliation case for the human. Dedup + slugs-never-reused.
  - **`runs/` section**: filename `runs/<slug>-<date-time>.md`; same body sections.
  - **`packets/` section**: final bullet becomes `## Suggested handoff branch` with the include/exclude meaning (mirror Task 3 Step 2).
  - **`knowledge/` section** (replaces `context/`): exactly three clauses — location (coordination ref), promotion gate (deliberate act only), internal organization belongs to the agents (no prescribed layout; the old shared/dormant/archived tiers are gone). Then the **load-semantics paragraph** from C2: accumulated `runs/`/`packets/` on default are inherited archive — never read wholesale; navigate via the active branch's `context.md` or an intake breadcrumb; `knowledge/` is the only curated tier.
  - Keep the "Context placement rule (omni-repo framing)" section, renaming its directory references to `knowledge/`.

- [ ] **Step 2: Verify**

Run: `grep -c "shared/\|dormant/\|archived/" plugins/tsugu/skills/tsugu/references/notes-and-packet.md`
Expected: `0` (tier taxonomy gone; a prose mention of "the old tiers" is allowed only inside the compat/migration note, which lives in migrations.md, not here)
Run: `grep -n "status:" plugins/tsugu/skills/tsugu/references/notes-and-packet.md`
Expected: only intake-lifecycle lines and the legacy-compat paragraph

- [ ] **Step 3: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/notes-and-packet.md
git commit --message "feat(tsugu): notes-and-packet — context.md semantics, knowledge/ gate+location, slug-keyed runs, load rules (spec 005 C2/C3)"
```

---

### Task 6: `references/policy-and-intake.md` — field semantics

**Spec:** B, C4–C6 fields, Ripple bullet for this file.

**Files:**
- Rewrite: `plugins/tsugu/skills/tsugu/references/policy-and-intake.md`

- [ ] **Step 1: Update field docs** to match the Task 2 template: `tsugu-schema` (stamp, written last by migrations), `## Branch Prefixes` (work-only, disjointness rule), `## Handoff Prefixes` (slug pairing = pending), `## Public branch` (`include|exclude` semantics, one paragraph each), `## Merge method` (recommendation + forced-squash consequence), `## Housekeeping` (`stale-after`, derived staleness, human-decided cleanup, prepare never cleans), `coordination-ref` (knowledge/ paths). Keep Remote / default-branch / Skill-use / opt-in / Recursion sections as they are.

- [ ] **Step 2: Rewrite the intake half:** the configuration moment (init asks; first interactive prepare backstop; the exact ask-once question from spec B; confirmed-negative recorded form; push-protected persistence via `init/*` PR; never block headless), the recorded form (name / one `read:` instruction / `notes:` hint; RSS / YARA / CVE / CI breadth with `curl --silent <url>` as the feed example), the dedup rule + slugs-never-reused + re-opens out of scope, `landed:` semantics (write-once, forced-squash only, validated both directions), and the reconciliation rule.

- [ ] **Step 3: Verify**

Run: `grep -c "Handoff Prefixes" plugins/tsugu/skills/tsugu/references/policy-and-intake.md`
Expected: ≥ 1
Run: `grep -n "curl -s " plugins/tsugu/skills/tsugu/references/policy-and-intake.md`
Expected: no output (full-length options only: `curl --silent`)

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/policy-and-intake.md
git commit --message "feat(tsugu): policy-and-intake — schema-2 fields, intake configuration moment + recorded form, landed:/reconciliation (spec 005 B/C4-C6)"
```

---

### Task 7: `references/migrations.md` — new file

**Spec:** D (rules + Migration 1→2, verbatim).

**Files:**
- Create: `plugins/tsugu/skills/tsugu/references/migrations.md`

- [ ] **Step 1: Write the file** with: a header stating the contract (init re-run decision: fresh / repair / migrate; each step *condition → actions → what must not be touched*; actions idempotent; **stamp written last**; behavior-changing fields may ask once; non-mechanical conflict stops and asks; push-protected defaults ride an `init/*` PR with coordination-ref changes deferred until merge, readers accepting both `context/` and `knowledge/` meanwhile), then **Migration 1→2** as eight numbered steps copied in substance from spec D: (1) `public-branch-tsugu` ask-once default include; (2) `## Handoff Prefixes` default `feat/* fix/*` + work-only Branch Prefixes, **appending legacy `public/*` to Handoff Prefixes**; (3) merge-commit recommendation line; (4) Intake Sources re-wrap (non-mechanical entries → ask-once or `read: TODO (ask the human)`); (5) `git mv .tsugu/context .tsugu/knowledge` (tier subdirs ride along as plain folders); (6) refresh `.tsugu/templates/` from the plugin (`branch.md` → `context.md`; `intake.md` gains `landed:`); (7) write the default branch's mainline `context.md` if absent; (8) `tsugu-schema: 2` last. Close with the live-branch rule: work branches are not migrated centrally; legacy reads per the compat rules.

- [ ] **Step 2: Verify**

Run: `grep -c "tsugu-schema: 2" plugins/tsugu/skills/tsugu/references/migrations.md`
Expected: ≥ 1
Run: `grep -n "stamp" plugins/tsugu/skills/tsugu/references/migrations.md | head -3`
Expected: lines stating the stamp is written last

- [ ] **Step 3: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/migrations.md
git commit --message "feat(tsugu): migrations reference — rules + schema 1→2 steps (spec 005 D)"
```

---

### Task 8: `SKILL.md` — the system prompt

**Spec:** the whole of C, plus A routing; Ripple bullet for SKILL.md. This is the highest-leverage file — it is what the agent actually reads.

**Files:**
- Rewrite: `plugins/tsugu/skills/tsugu/SKILL.md`

- [ ] **Step 1: Frontmatter description** — rewrite the trigger surface: three routines (`/tsugu:init`, `/tsugu:prepare`, `/tsugu:converge`), drop "settle converged work into clean public form", keep the trigger phrases ("prepare work before review", "carry work forward", "git-native preparation"), keep "human-triggered and schedule-wireable", "invokes no user-installed skill by default", "never auto-merges".

- [ ] **Step 2: Spine** — keep the 継ぐ naming + "git is the message bus" sections; update the legibility bullet (`branch.md` → `context.md`); add the orientation principle **verbatim from spec C** (the blockquote: refs/DAG carry every fact the partition reads; text = narrative + write-once records; record only what an operation severed, at the moment it stops being derivable) and the slug paragraph (slug = universal join key; one slug = one work item; same-slug work branches are its artifacts; work/handoff prefix sets disjoint).

- [ ] **Step 3: Routing** — three routines; deferred-mechanics pointers now include `references/migrations.md`.

- [ ] **Step 4: `init`** — 004 flow plus: push question defaults **yes**; schema stamp on fresh init; the three-way re-run decision (fresh / idempotent repair / migrate via migrations.md); prefix-disjointness validation.

- [ ] **Step 5: `prepare`** — keep external-silence posture, fetch-first, policy read, push step; **replace the partition** with the C4 table + the seven notes in condensed form (slug pairing; merge-method recommendation + landed:; out-of-band closure = rejection; include-mode divergence; recency claims; zero-commit exemption + slugs-never-reused; intake closing + reconciliation); add the intake-source backstop (ask once when interactive + unconfigured; confirmed-negative form; never block headless; push-protected persistence).

- [ ] **Step 6: `converge`** — the C1 routine verbatim in structure: fetch-first; candidate list + ask (argument skips); awaiting-merge section (PR-less orphans; include-mode divergence + collision flags; neither heuristic in exclude); **housekeeping section** (stale-after threshold, derived staleness, human-decided per item, prepare never cleans); packet layout + open questions + reconciliation; the four dispositions with the include/exclude arms and the ordered completion tail; the read-only steps 1–3 note ("looking and leaving is first-class — the morning status view"); never auto-merge.

- [ ] **Step 7: Remove the `settle` section entirely.** Boundary + multi-agent sections: claims derived from commits (no claimed-by fields; shared-identity → pure recency; v2 staleness window); `context.md` in all examples; scheduling + recursion sections unchanged except wording.

- [ ] **Step 8: Verify**

Run: `grep -n "settle" plugins/tsugu/skills/tsugu/SKILL.md`
Expected: no routine named settle; allowed only in a historical aside if any (target: zero mentions)
Run: `grep -c "context.md" plugins/tsugu/skills/tsugu/SKILL.md`
Expected: ≥ 5
Run: `grep -n "claimed-by" plugins/tsugu/skills/tsugu/SKILL.md`
Expected: no output (or only inside the legacy-compat sentence)
Run: `grep -n "status: open" plugins/tsugu/skills/tsugu/SKILL.md`
Expected: only intake-note lifecycle mentions, never branch state

- [ ] **Step 9: Commit**

```bash
git add plugins/tsugu/skills/tsugu/SKILL.md
git commit --message "feat(tsugu): SKILL.md — three routines, derived-state partition, converge absorbs settle (spec 005 A/C)"
```

---

### Task 9: Commands — three thin routers

**Spec:** A.

**Files:**
- Delete: `plugins/tsugu/commands/tsugu.md`
- Create: `plugins/tsugu/commands/init.md`, `plugins/tsugu/commands/prepare.md`, `plugins/tsugu/commands/converge.md`

- [ ] **Step 1: Write `commands/init.md`:**

```markdown
---
description: Set up or migrate the repo's .tsugu/ workspace + policy.md — asks the minimum; idempotent; re-running migrates older schemas (tsugu-schema)
---

# /tsugu:init

Invoke the `tsugu` skill and run the **init** routine. Pass `$ARGUMENTS` through
as free-form context.

Load-bearing invariants the skill enforces: idempotent repair (never overwrites
a curated `policy.md`); version-stamped migration with the stamp written last;
push-protected defaults ride an `init/*` branch + human-approved PR.
```

- [ ] **Step 2: Write `commands/prepare.md`:**

```markdown
---
description: Human-absent preparation — fetch, derive the queue from refs, work privately on prepare/* branches, push evidence. External silence
---

# /tsugu:prepare

Invoke the `tsugu` skill and run the **prepare** routine. Pass `$ARGUMENTS`
through as free-form context.

Load-bearing invariants the skill enforces: external silence (interrupt only if
unsafe, destructive, or blocked); state derived from refs and the DAG — no
status fields; pushes by policy (default yes); asks where tasks come from once,
only when interactive and unconfigured — a scheduled run never blocks; invokes
no user-installed skill by default. Wire this routine to /schedule or cron — it
cannot self-wake.
```

- [ ] **Step 3: Write `commands/converge.md`:**

```markdown
---
description: Human-present convergence — morning status view (read-only until you decide), then decide and complete dispositions in-session. Never auto-merges
argument-hint: "[branch]"
---

# /tsugu:converge

Invoke the `tsugu` skill and run the **converge** routine. `$ARGUMENTS` may name
a branch to converge directly, skipping the selection question.

Load-bearing invariants the skill enforces: steps before the disposition are
read-only — running this just to look (how many branches are workable, what
awaits merge, what is stale) is a first-class use; merging/opening the PR is
the human's act — Tsugu never auto-merges; housekeeping (stale branches) is
human-decided per item.
```

- [ ] **Step 4: Delete the old router**

```bash
git rm plugins/tsugu/commands/tsugu.md
```

- [ ] **Step 5: Verify**

Run: `ls plugins/tsugu/commands/`
Expected: `converge.md init.md prepare.md`
Run: `grep -L "tsugu" plugins/tsugu/commands/*.md`
Expected: no output (each file invokes the skill)

- [ ] **Step 6: Commit**

```bash
git add plugins/tsugu/commands/
git commit --message "feat(tsugu): three namespaced commands replace the /tsugu:tsugu router (spec 005 A)"
```

---

### Task 10: `README.md` — user-facing docs

**Spec:** Affected-surface row for README.

**Files:**
- Rewrite: `plugins/tsugu/skills/tsugu/README.md`

- [ ] **Step 1: Rewrite**, keeping the existing tone and the 継ぐ/what-this-is framing:

  - "The four routines" → **"The three routines"** (init / prepare / converge), converge described as decision + completion in one human-present session, with the morning-status-view sentence.
  - "How to invoke" block → `/tsugu:init`, `/tsugu:prepare`, `/tsugu:converge [branch]` (no bare `/tsugu`, no settle).
  - The `.tsugu/` diagram → `context.md` ("this ref's situation, pure narrative — every branch and the mainline"), `knowledge/` ("promoted knowledge; structure is the agents' own"), `runs/<slug>-<date-time>.md`, no `branch.md`.
  - Add a short **"State is derived"** section: no status fields; settled = merged (containment), pending = a slug-paired handoff branch exists; **prefer merge commits — do not squash-merge tsugu-managed branches** (forced squash → converge records `landed:`).
  - Clean-cut content moves into a sentence under converge: `public-branch-tsugu: exclude` keeps `.tsugu/` out of PR diffs for collaborative repos; `include` (default) lands evidence on the mainline.
  - Spec links: keep 004, add `../../../../docs/superpowers/specs/005-tsugu-agent-first-design.md`.

- [ ] **Step 2: Verify**

Run: `grep -n "settle\|four routines" plugins/tsugu/skills/tsugu/README.md`
Expected: no output
Run: `grep -c "005-tsugu-agent-first-design.md" plugins/tsugu/skills/tsugu/README.md`
Expected: `1`

- [ ] **Step 3: Commit**

```bash
git add plugins/tsugu/skills/tsugu/README.md
git commit --message "docs(tsugu): README — three routines, derived state, knowledge/, 005 spec link"
```

---

### Task 11: Metadata — `plugin.json`, `marketplace.json`, root `CLAUDE.md`

**Spec:** Affected-surface rows for the three metadata files.

**Files:**
- Modify: `plugins/tsugu/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json` (tsugu entry only)
- Modify: `CLAUDE.md` (tsugu paragraphs only)

- [ ] **Step 1: `plugin.json`** — replace the `description` value with:

```text
Git-native preparation & convergence — agents prepare work privately via git's DAG (init/prepare/converge), state derived from refs not files, evidence packaged for human–agent handoff. Never auto-merges; invokes no user-installed skill by default.
```

- [ ] **Step 2: `marketplace.json`** — in the tsugu entry: bump `version` `0.1.0` → `0.2.0`; update its `description` to the three-routine wording (mirror Step 1, shortened to the entry's existing style).

- [ ] **Step 3: Root `CLAUDE.md`** — update the two tsugu blocks: the repository-structure one-liner and the **tsugu:** plugin-details paragraph — three routines (init/prepare/converge, converge = decision + completion + morning status view), derived state (no status fields; slug pairing + containment; merge commits recommended), `.tsugu/` may land on the mainline by default (`public-branch-tsugu: include|exclude`), `context.md`/`knowledge/` names, "Three slash commands: `/tsugu:init|prepare|converge`", spec pointer becomes 004 + 005.

- [ ] **Step 4: Verify**

Run: `jq -r '.description' plugins/tsugu/.claude-plugin/plugin.json | grep -c settle`
Expected: `0`
Run: `jq -r '.plugins[] | select(.name=="tsugu") | .version' .claude-plugin/marketplace.json`
Expected: `0.2.0`
Run: `grep -n "init|prepare|converge|settle" CLAUDE.md`
Expected: no output

- [ ] **Step 5: Commit**

```bash
git add plugins/tsugu/.claude-plugin/plugin.json .claude-plugin/marketplace.json CLAUDE.md
git commit --message "chore(tsugu): metadata to three-routine surface; bump tsugu to 0.2.0"
```

---

### Task 12: Repo-wide consistency sweep

**Files:** none (verification only; fix anything found, amend nothing — new commits)

- [ ] **Step 1: Removed-mechanism sweep** over the shipped plugin:

```bash
grep -rn "settle" plugins/tsugu/ ; echo "---"
grep -rn "claimed-by\|claimed-at" plugins/tsugu/ ; echo "---"
grep -rn "context/shared\|context/dormant\|context/archived" plugins/tsugu/ ; echo "---"
grep -rn "branch\.md" plugins/tsugu/
```

Expected: `settle` — zero hits (or only inside a quoted legacy/compat sentence); `claimed-*` — only legacy-compat mentions; `context/{shared,dormant,archived}` — only `references/migrations.md`; `branch.md` — only legacy-fallback/compat/migration passages.

- [ ] **Step 2: New-mechanism presence sweep:**

```bash
grep -rln "context.md" plugins/tsugu/skills/tsugu/ | sort
grep -rln "Handoff Prefixes" plugins/tsugu/skills/tsugu/ | sort
grep -rn "curl -s \|grep -E\" -r\b" plugins/tsugu/ | grep -v "full-length" || echo "options clean"
```

Expected: `context.md` in SKILL.md, README, all three original references + templates; `Handoff Prefixes` in policy template, policy-and-intake, git-recipes, SKILL.md; short-option scan clean (written docs use full-length options).

- [ ] **Step 3: Fix anything found, one commit per finding** (`fix(tsugu): …`).

---

### Task 13: Local review gate + PR

- [ ] **Step 1: Run the review loop on the branch.** Use the `review-loop` skill (`/review-loop feat/tsugu-v1.1`) — local Claude subagent + headless Codex gate over the full branch diff vs `main`. Fix findings per its tier protocol (T1 auto-fix; T2/T3 to the author), one commit per item.

- [ ] **Step 2: Push and open the PR (human-gated):**

```bash
git push --set-upstream origin feat/tsugu-v1.1
```

PR title: `feat(tsugu): v1.1 — agent-first revisions (spec 005)`. Body: summary of the four lines A–D, link to `docs/superpowers/specs/005-tsugu-agent-first-design.md` and this plan; note that merging this PR is what makes `/tsugu:init` migrations available to dogfooding repos. End the body with the standard generated-with footer. **Do not merge** — the author decides.

- [ ] **Step 3: After the human merges:** remove the worktree, keep the branch:

```bash
git -C /Users/caasi/GitHub/caasi/dong3 worktree remove /Volumes/ramdisk/dong3/spec-005
```

---

## Out of scope (do not do)

- Editing spec 004 or any non-tsugu plugin.
- Adding scripts, validators, or test fixtures anywhere under `plugins/tsugu/` (install boundary; tsugu is script-free by design).
- Running `/tsugu:init` migrations against real repos — that is post-merge dogfooding, not this plan.
- Marketplace `metadata.version` — that bumps only when plugins are added/removed, not updated.
