# Tsugu thin core (schema 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply spec 007 — narrow the Tsugu core to `prepare/*` + merge-commit settlement, relocate the non-containment-landing path to a new `references/advanced.md`, rename handoff→accepted prefixes, restate converge verbs, add the 3→4 migration, and fix `prepare`'s default driver to the provisioned machine — bumping the skill to `tsugu-schema: 4`.

**Architecture:** This is a **documentation/prose refactor of a Claude Code skill**, not executable code. There is **no test runner or build system** for skills in this repo (see CLAUDE.md "What This Is"). Verification is therefore done with `grep`/read assertions against spec 007's seven (now eight) success criteria, plus a final cross-file consistency sweep. SKILL.md and references are system prompts; templates are copied by `init` into a user repo; the spec at `docs/superpowers/specs/007-tsugu-thin-core-design.md` is the source of truth for all wording.

**Tech Stack:** Markdown only. `grep`/`rg` for verification. `git` for commits. No compiler, no tests.

**Source of truth:** `docs/superpowers/specs/007-tsugu-thin-core-design.md` (sections A–F, Affected surface, Success criteria). When this plan says "per spec §B2", open that section and reproduce its content faithfully — do not invent wording.

**Branch / worktree:** These are shippable plugin files (they reach users on `marketplace add`), so per CLAUDE.md this is **code** — work on a feature branch in a RAM-disk worktree (`feat/tsugu-schema-4`), never on `main`. The plan document itself already lives on `main` (planning doc).

**Ordering rationale:** Build the artifacts the rest point at first — the policy **template** (defines the target shape) and the new **`advanced.md`** (SKILL.md links to it) — then the **SKILL.md** core, then the references that elaborate it, then commands / README / CLAUDE.md / marketplace, then a whole-tree consistency sweep.

---

## File Structure

| File | Responsibility | Spec § |
| --- | --- | --- |
| `plugins/tsugu/skills/tsugu/templates/policy.md` | The `init`-written policy skeleton: `## Branch Prefixes` (`prepare/*` only), `## Accepted Prefixes` (`feature/* bugfix/* chore/*`), `## Merge method` (shrunk), `tsugu-schema: 4` | A1, C1, B, Affected surface |
| `plugins/tsugu/skills/tsugu/references/advanced.md` | **NEW.** The non-containment-landing path (squash/rebase/force-push) + the slug-artifact rule for configured-extra-prefix repos | B2, A2 |
| `plugins/tsugu/skills/tsugu/SKILL.md` | Core skill: single `prepare/*`, two-fact/three-row partition + one-line advanced pointer, accepted-prefixes/handoff-as-event, accept/park/drop verbs, F scheduling | A, B, C, D, F |
| `plugins/tsugu/skills/tsugu/references/policy-and-intake.md` | Rename handoff-prefixes → accepted-prefixes; move `## Merge method` forced-squash to advanced.md; handoff branch → accepted branch | C1, B |
| `plugins/tsugu/skills/tsugu/templates/packet.md` | "Suggested handoff branch" / "Handoff Prefix" → accepted terminology | Affected surface |
| `plugins/tsugu/skills/tsugu/references/notes-and-packet.md` | Handoff Prefix / handoff branch → accepted terminology | Affected surface |
| `plugins/tsugu/skills/tsugu/references/git-recipes.md` | Settlement assumes merge commit; completion-tail/cleanup consults `## Legacy Work Prefixes`; pointer to advanced for rewrite landings | B1, E3 |
| `plugins/tsugu/skills/tsugu/references/migrations.md` | New `3→4` step (E1 rename+restamp, E2 collapse+disjointness re-check, E3 per-branch legacy) | E |
| `plugins/tsugu/commands/prepare.md` | Provisioned-machine driver default; cloud degrades | F |
| `plugins/tsugu/commands/converge.md`, `commands/init.md` | Verb naming / accepted-prefixes if referenced | C, D |
| `plugins/tsugu/skills/tsugu/README.md` | User-facing wording (prefixes, verbs, schema 4, scheduling default) | A–F |
| `CLAUDE.md` (repo root) | tsugu paragraph: `Schema 4 (lineage: 004 → 005 → 006 → 007)`, `prepare/*`, accepted-prefixes, spec 007 ref | Affected surface |
| `.claude-plugin/marketplace.json` | Bump tsugu `0.3.0` → `0.4.0`; update description | Affected surface |

**Do NOT** bump the marketplace top-level `metadata.version` — that bumps only on adding/removing a plugin, not a version change (project convention).

---

## Task 1: Rewrite the policy + packet templates to the schema-4 shape

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/templates/policy.md` (currently 54 lines)
- Modify: `plugins/tsugu/skills/tsugu/templates/packet.md` (currently 18 lines)

- [ ] **Step 1: Read the current template and spec §A1/§C1/§B**

Read `plugins/tsugu/skills/tsugu/templates/policy.md` in full and spec 007 sections A1, C1, and the B2 `## Merge method` note + the Affected-surface `templates/policy.md` bullet.

- [ ] **Step 2: Edit the prefix sections + schema stamp**

Apply, faithfully to the spec:
- `## Branch Prefixes` body → `prepare/*` only (remove `investigate/* review/*`).
- Rename `## Handoff Prefixes` → `## Accepted Prefixes`, body → `feature/*  bugfix/*  chore/*`.
- The intro line that lists `prepare/* / investigate/* / review/*` (line ~3) → `prepare/*` only.
- The schema stamp (first line) → `tsugu-schema: 4`.
- The prefix-disjointness comment stays; update it to name `## Accepted Prefixes`.

- [ ] **Step 3: Shrink `## Merge method` per spec §B2 / Affected surface**

Replace the squash-heavy body with: "prefer merge commits; non-containment landings (squash / rebase / force-push) → `references/advanced.md`" **while keeping** the retain-handoff / disable-auto-delete line that `exclude` mode relies on. Reproduce the spec's intended wording.

- [ ] **Step 4: Verify**

```bash
f=plugins/tsugu/skills/tsugu/templates/policy.md
grep -q '^tsugu-schema: 4' "$f" && echo "stamp OK"
grep -q '## Accepted Prefixes' "$f" && ! grep -q '## Handoff Prefixes' "$f" && echo "rename OK"
grep -A2 '## Branch Prefixes' "$f" | grep -q 'prepare/\*' && ! grep -A2 '## Branch Prefixes' "$f" | grep -qE 'investigate/\*|review/\*' && echo "single prefix OK"
grep -A2 '## Accepted Prefixes' "$f" | grep -q 'feature/\*' && echo "accepted defaults OK"
grep -iq 'advanced.md' "$f" && echo "merge-method pointer OK"
grep -iq 'auto-delete' "$f" && grep -iq 'exclude' "$f" && echo "retain-handoff (exclude) retained OK"
```
(The `exclude` conjunct distinguishes the *retained* exclude-mode recommendation from a leftover squash line — the squash-specific framing must be gone from `## Merge method`, only the exclude retain-handoff line stays.)

Also edit **`templates/packet.md`**: `## Suggested handoff branch` → `## Suggested accepted branch`; "under a **Handoff Prefix**" → "under an **Accepted Prefix**". Then:

```bash
p=plugins/tsugu/skills/tsugu/templates/packet.md
! grep -qi 'handoff prefix' "$p" && grep -qi 'accepted' "$p" && echo "packet wording OK"
```
Expected: every line prints its `OK` (incl. `packet wording OK`).

- [ ] **Step 5: Commit**

```bash
git add plugins/tsugu/skills/tsugu/templates/policy.md plugins/tsugu/skills/tsugu/templates/packet.md
git commit -m "feat(tsugu): policy+packet templates → schema 4 (single prepare/*, accepted-prefixes, merge-method shrink)"
```

---

## Task 2: Create `references/advanced.md` (the relocated non-containment path)

**Files:**
- Create: `plugins/tsugu/skills/tsugu/references/advanced.md`

- [ ] **Step 1: Read spec §B2 and §A2**

Read spec 007 §B2 (the full non-containment-landing path: the general class squash/rebase/force-push, narrative-backstop, re-surface-until-confirmed, disable-auto-delete for the rewrite case, rewrite-specific completion-tail trigger) and §A2's last paragraph (the slug-artifact rule for repos that configure extra work prefixes).

- [ ] **Step 2: Write `advanced.md`**

Two sections, faithful to the spec:
1. **Non-containment landings** — squash / rebase-before-merge / force-push. State that the core (SKILL.md) assumes merge commits; this file owns the rewrite path. Include the four bullets from §B2's "advanced path documents" list. Make explicit that the deleted-ref narrative backstop and the retain-handoff/disable-auto-delete recommendation themselves stay in the core (exclude mode needs them) — advanced only adds the rewrite-specific elaboration.
2. **Slug artifact under extra work prefixes** — for repos that configure additional work prefixes, the "same-slug branch under a different work prefix is that item's artifact" rule (swept by the work item's completion tail) lives here.

Reference it the way other references are referenced (`${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/advanced.md`).

- [ ] **Step 3: Verify**

```bash
f=plugins/tsugu/skills/tsugu/references/advanced.md
test -f "$f" && echo "created OK"
grep -qiE 'squash' "$f" && grep -qiE 'rebase' "$f" && grep -qiE 'force-push' "$f" && echo "all three landings OK"
grep -qi 're-surface' "$f" && echo "re-surface OK"
grep -qi 'work prefix' "$f" && grep -qi 'slug' "$f" && echo "slug-artifact rule OK"
```
Expected: all `OK`.

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/advanced.md
git commit -m "feat(tsugu): add references/advanced.md (non-containment landings + extra-prefix slug artifact)"
```

---

## Task 3: Rewrite SKILL.md — A (single prefix) + B (partition + advanced pointer)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (currently 177 lines)

Split SKILL.md across three tasks (3, 4, 5) to keep each edit focused.

- [ ] **Step 1: Read SKILL.md fully + spec §A, §B**

Pay attention to: "The slug is the join key" section (line ~48), the `prepare` step 5 prefix list (line ~120), the partition table + the five condensed notes (lines ~96–111), and any `investigate/* review/*` default.

- [ ] **Step 2: Apply §A edits**

- Default work prefixes everywhere in SKILL.md → `prepare/*` only. Specifically: init defaults (line ~70); prepare step 5 (line ~120); converge candidate enumeration (line ~130) — **reword** the parenthetical "enumerated across all configured work prefixes — defaults `prepare/* investigate/* review/*`, not `prepare/*` alone" to "enumerated across all configured work prefixes (default `prepare/*`)" so §A3 (a repo that *configures* extra prefixes still discovers them) stays true. **NOTE:** line ~130 sits inside the converge section (lines ~125–147) that **Task 4** also edits — **Task 3 owns line 130**; coordinate so the two tasks don't collide on the same lines.
- **SKILL.md `init` routine, line ~74:** the instruction **"Stamp `tsugu-schema: 3`"** → **`4`**. This is the live prose that drives a fresh repo's stamp; if left at `3`, `init` contradicts the schema-4 template and **Success Criterion 1 fails**. (No other task touches this line — it must be done here.)
- "The slug is the join key" section: keep all four legs (work branch, `context.md`, packet, accepted branch); remove the `review/<slug>` "same-slug under different work prefix = artifact" example from the core, replacing it with a one-line pointer to `references/advanced.md` for repos that configure extra work prefixes (per §A2).
- Built-in review/investigate subagents (prepare step 6): they work inside the `prepare/*` branch/worktree, not a separate `review/*` branch.

- [ ] **Step 3: Apply §B edits (the partition)**

- The partition table stays **three rows** (settled / decided-awaiting-merge / in-progress) from **two checked facts** (containment, then slug-pairing). Rename references to `## Handoff Prefixes` → `## Accepted Prefixes` in the table.
- Remove the squash/rewrite elaboration from the five condensed notes; replace with the one-line pointer from §B2: *"A landing that rewrites history (squash, rebase-before-merge, force-push) breaks containment-derived settlement; see `references/advanced.md`."*
- **Keep** in core: the deleted-ref narrative backstop and the retain-handoff/disable-auto-delete recommendation (exclude mode needs them).

- [ ] **Step 4: Verify**

```bash
f=plugins/tsugu/skills/tsugu/SKILL.md
! grep -qE 'investigate/\*\s+review/\*|prepare/\* investigate/\* review/\*' "$f" && echo "single-prefix default OK"
! grep -q '## Handoff Prefixes' "$f" && grep -q '## Accepted Prefixes' "$f" && echo "accepted rename OK"
grep -qi 'advanced.md' "$f" && echo "advanced pointer OK"
grep -qi 'packet' "$f" && echo "join legs intact OK"
grep -q 'tsugu-schema: 4' "$f" && ! grep -q 'tsugu-schema: 3' "$f" && echo "init stamp 4 OK"
```
Expected: all `OK` (incl. `init stamp 4 OK`). Manually confirm the partition table still has 3 rows and no squash elaboration remains inline.

- [ ] **Step 5: Commit**

```bash
git add plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "feat(tsugu): SKILL.md §A/§B — single prepare/*, three-row partition, advanced.md pointer"
```

---

## Task 4: SKILL.md — C (accepted-prefixes / handoff-as-event) + D (converge verbs)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md`

- [ ] **Step 1: Read spec §C, §D and the SKILL.md converge section (lines ~125–147)**

- [ ] **Step 2: Apply §C edits**

- All "handoff branch / handoff prefix" wording → accepted-branch / `## Accepted Prefixes`; frame handoff as the *act of translating at accept time* (per §C2), not a Tsugu-owned namespace. Translation happens only on the PR/handoff path and the exclude public-branch path, **not** the include-mode solo direct merge.

- [ ] **Step 3: Apply §D edits**

- converge step 4 dispositions → named **accept / park / drop** (rename the `Rejected:` disposition at line ~143 → `drop`, keep the "record why" narrative). **Do NOT** touch line ~110 *"Out-of-band PR closure = rejection"* — that "rejection" is the slug-pairing-dissolves narrative, not the disposition; it stays verbatim.
- Add the §D2 statement that **continue is implicit** (every untouched branch is already "continue"; the morning looking-and-leaving view).
- Add the §D3 statement that **promote is orthogonal** (rides any disposition, incl. "drop yet promote the lesson"; a checklist item, not a 5th sibling).
- Keep the §D4 invariant wording (no status field; state derived).

- [ ] **Step 4: Verify**

```bash
f=plugins/tsugu/skills/tsugu/SKILL.md
! grep -qi 'rejected — do not resume' "$f" && echo "disposition renamed OK"      # the line-143 disposition is gone
grep -qi 'drop — do not resume' "$f" && echo "drop verb present OK"               # ...replaced by drop
grep -qi 'Out-of-band PR closure = rejection' "$f" && echo "PR-closure narrative retained OK"  # line 110 survives
grep -qi 'continue' "$f" && grep -qi 'promote' "$f" && echo "continue/promote covered OK"
```
Expected: all four `OK`. These checks are non-vacuous: `disposition renamed OK` fails only if the line-143 rename was skipped; `PR-closure narrative retained OK` fails if line 110 was over-scrubbed.

- [ ] **Step 5: Commit**

```bash
git add plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "feat(tsugu): SKILL.md §C/§D — accepted-prefixes + accept/park/drop, continue implicit, promote orthogonal"
```

---

## Task 5: SKILL.md — F (prepare's default driver = provisioned machine)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (Scheduling & recursion section, line ~174; the frontmatter description; the line-91 cadence sentence)

- [ ] **Step 1: Read spec §F (whole section) + the SKILL.md "Scheduling & recursion" section, line ~91, and the frontmatter `description:`**

- [ ] **Step 2: Apply §F edits**

- "Scheduling & recursion": replace "a *cloud* agent runs it daily" with the provisioned-machine default — an external driver the human starts (local cron / `/loop`) on the machine holding **both** the personal-folder source config **and** the MCP/connector credentials (typically the local homelab). An *unprovisioned* cloud/headless run is allowed but degrades to git-native: config-missing → existing same-machine `converge` notice; auth failure → the run's own log only (no new converge scope, no cross-run diagnostic). Provisioning, not cloud-vs-local, is the distinction.
- Reconcile the two other cloud-framed touchpoints (per §F / Affected surface): line ~91 ("Cadence always comes from an external `/schedule`/cron driver") and the frontmatter `description:` ("wire `prepare` to `/schedule`/cron") — de-emphasize *cloud* `/schedule` in favor of a driver on the provisioned machine. Keep the **no-self-wake** invariant verbatim.

- [ ] **Step 3: Verify**

```bash
f=plugins/tsugu/skills/tsugu/SKILL.md
grep -qi 'provisioned' "$f" && echo "provisioned framing OK"
grep -qi 'cannot self-wake' "$f" && echo "no-self-wake retained OK"
! grep -qi 'a cloud agent runs it daily' "$f" && echo "cloud-default line revised OK"
```
Expected: all `OK`.

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "feat(tsugu): SKILL.md §F — prepare's default driver runs on the provisioned machine"
```

---

## Task 6: `references/policy-and-intake.md` + `notes-and-packet.md` — accepted-prefixes, move squash

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/policy-and-intake.md` (255 lines)
- Modify: `plugins/tsugu/skills/tsugu/references/notes-and-packet.md` (125 lines)

- [ ] **Step 1: Read both files + spec §C1, §B (criterion 2), Affected surface**

In `policy-and-intake.md` find the `## Merge method` section (~line 109) — it currently elaborates the **forced-squash** procedure inline (the squash commit's parents, disable-auto-delete, "awaiting merge"). That elaboration is *core* and must move per criterion 2.

- [ ] **Step 2: Edit `policy-and-intake.md`**

- Rename the handoff-prefixes section/field → accepted-prefixes; defaults → `feature/* bugfix/* chore/*`. Any `prepare/* investigate/* review/*` default → `prepare/*`. Keep prefix-disjointness wording, naming `## Accepted Prefixes`.
- **`## Merge method`:** shrink to "prefer merge commits; non-containment landings (squash / rebase / force-push) → `references/advanced.md`" and **keep** the exclude-mode retain-handoff / disable-auto-delete line; **move the forced-squash elaboration into `advanced.md`** (it should already be there from Task 2 — if Task 2's `advanced.md` doesn't yet capture this exact procedure, add it there now).
- Rename "handoff branch" → "accepted branch" ("handoff" may stay only as the *event* verb).

- [ ] **Step 3: Edit `notes-and-packet.md`**

"Handoff Prefix" → "Accepted Prefix"; "slug-paired handoff branch" → "slug-paired accepted branch"; "## Suggested handoff branch" → "## Suggested accepted branch" (matches the packet template). "handoff" may stay only as the event verb.

- [ ] **Step 4: Verify**

```bash
for f in plugins/tsugu/skills/tsugu/references/policy-and-intake.md plugins/tsugu/skills/tsugu/references/notes-and-packet.md; do
  ! grep -qi 'handoff prefix' "$f" && echo "$f: prefix rename OK" || echo "$f: STILL HAS handoff prefix"
done
g=plugins/tsugu/skills/tsugu/references/policy-and-intake.md
grep -q 'feature/\*' "$g" && echo "defaults OK"
grep -qi 'advanced.md' "$g" && echo "squash moved (pointer present) OK"
```
Expected: both files `prefix rename OK`, plus `defaults OK` and `squash moved (pointer present) OK`. Also confirm by eye that `advanced.md` now contains the forced-squash procedure that left `## Merge method`.

- [ ] **Step 5: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/policy-and-intake.md plugins/tsugu/skills/tsugu/references/notes-and-packet.md
git commit -m "feat(tsugu): policy-and-intake + notes-and-packet → accepted-prefixes; move forced-squash to advanced.md"
```

---

## Task 7: `references/git-recipes.md` — merge-commit settlement + legacy sweep

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/git-recipes.md` (549 lines)

- [ ] **Step 1: Read the file + spec §B1, §E3, Affected-surface git-recipes bullet**

Find the containment/settlement recipes, the squash handling, the completion-tail/cleanup recipe, and any `## Handoff Prefixes` mention.

- [ ] **Step 2: Edit**

- Settlement recipes assume merge commits (containment). Move/point the squash/rewrite recipe to `references/advanced.md` (leave a one-line pointer here).
- Completion-tail / cleanup: also consult a `## Legacy Work Prefixes` note (when present) so artifacts under dropped prefixes stay reachable for sweep; pruning the note once empty is **optional** (a stale-empty note is harmless).
- Rename `## Handoff Prefixes` → `## Accepted Prefixes` references; `prepare/* investigate/* review/*` → `prepare/*`. Also rename "handoff branch" → "accepted branch" throughout (this file has many such mentions); "handoff" may stay only as the *event* verb.

- [ ] **Step 3: Verify**

```bash
f=plugins/tsugu/skills/tsugu/references/git-recipes.md
grep -qi 'Legacy Work Prefixes' "$f" && echo "legacy sweep OK"
grep -qi 'advanced.md' "$f" && echo "advanced pointer OK"
! grep -qi 'handoff prefix' "$f" && echo "prefix rename OK"
```
Expected: all `OK`.

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/git-recipes.md
git commit -m "feat(tsugu): git-recipes.md — merge-commit settlement, legacy-prefix sweep, advanced pointer"
```

---

## Task 8: `references/migrations.md` — the 3→4 step

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/migrations.md` (288 lines)

- [ ] **Step 1: Read the file (esp. the 2→3 step as the format template) + spec §E in full**

- [ ] **Step 2: Write the `3→4` step**

Faithful to §E:
- **E1 (mechanical):** rename `## Handoff Prefixes` → `## Accepted Prefixes` (content verbatim — a schema-3 repo's curated `feat/* fix/*` stay); stamp `tsugu-schema: 4` **last**; push-protected default rides `init/*` + PR.
- **E2:** if `## Branch Prefixes` has more than `prepare/*`, **propose** collapse (human confirms; never auto). After rename+collapse, **re-run work ∩ accepted = ∅** disjointness check; stop-and-ask on overlap; don't commit the collapse until disjoint.
- **E3 (per-branch legacy):** for each branch under removed prefixes, check if `prepare/<slug>` exists:
  - exists (artifact) → ancestry check `git merge-base --is-ancestor <legacy-tip> <remote>/prepare/<slug>`: fully contained → offer delete now (confirmed, tip hash shown); has unique commits → ambiguous (case 3), stop and ask, never auto-delete. If not deleted, record dropped prefixes in `## Legacy Work Prefixes` (sweep consults it; pruning optional, same policy-write path).
  - no `prepare/<slug>` (standalone) → list name + tip hash; offer recreate `git branch prepare/<slug> <tip-sha>` (copy, write-once preserved). After the copy the old ref is redundant: **delete it (recommended), or record its dropped prefix in `## Legacy Work Prefixes` if the human keeps it** — else the retained old ref strands under the collapsed-away prefix (mirrors the artifact case; spec §E3 case 2).
  - ambiguous → stop and ask; never force-overwrite.
- Update the file's 1→2→3 chain language to 1→2→3→4 where it enumerates the contract.

- [ ] **Step 3: Verify**

```bash
f=plugins/tsugu/skills/tsugu/references/migrations.md
grep -qE '3\s*[→-]>?\s*4|3→4' "$f" && echo "3→4 step OK"
grep -qi 'merge-base --is-ancestor' "$f" && echo "ancestry check OK"
grep -qi 'disjoint' "$f" && echo "disjointness re-check OK"
grep -qi 'Legacy Work Prefixes' "$f" && echo "legacy note OK"
```
Expected: all `OK`.

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/migrations.md
git commit -m "feat(tsugu): migrations.md — add 3→4 (rename, collapse+disjointness, per-branch legacy)"
```

---

## Task 9: Commands — prepare.md (driver default) + converge.md/init.md (verbs, prefixes)

**Files:**
- Modify: `plugins/tsugu/commands/prepare.md` (17 lines), `commands/converge.md` (16), `commands/init.md` (14)

- [ ] **Step 1: Read all three + spec §F, §C, §D**

- [ ] **Step 2: Edit**

- `prepare.md`: **definitely needs editing** — its frontmatter hardcodes `defaults prepare/* investigate/* review/*` (→ `prepare/*`) and wires `/schedule`/cron (→ note the provisioned-machine default: external driver — local cron / `/loop` — and that an unprovisioned run degrades to git-native). Don't let this hide behind the "if referenced" hedge.
- `converge.md`: if it names dispositions, use accept / park / drop.
- `init.md`: if it names prefixes/defaults, reflect `prepare/*` + accepted-prefixes + schema 4.

- [ ] **Step 3: Verify**

```bash
grep -qi 'provisioned\|local cron\|/loop' plugins/tsugu/commands/prepare.md && echo "prepare driver OK"
! grep -q 'investigate/\* review/\*' plugins/tsugu/commands/prepare.md && echo "prepare single-prefix OK"
! grep -qiw reject plugins/tsugu/commands/converge.md && echo "converge verbs OK"
```
Expected: all three `OK` (converge.md/init.md may need no edit if they don't name the changed concept — confirm by eye; `prepare.md` definitely changes).

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/commands/
git commit -m "feat(tsugu): commands — prepare driver default, converge verbs, init defaults"
```

---

## Task 10: README.md — user-facing wording

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/README.md` (154 lines)

- [ ] **Step 1: Read README + skim spec 007 (all sections) for the user-facing surface**

- [ ] **Step 2: Edit**

Update: work prefix `prepare/*` (drop investigate/review from the user story), accepted-prefixes, converge verbs (accept/park/drop, continue implicit, promote), schema 4, and the scheduling default (provisioned machine; cloud degrades). Keep README user-facing (no internal mechanics dumps).

- [ ] **Step 3: Verify**

```bash
f=plugins/tsugu/skills/tsugu/README.md
grep -qi 'schema 4\|schema: 4' "$f" && echo "schema OK"
! grep -qiE 'investigate/\* review/\*' "$f" && echo "prefix story OK"
```
Expected: both `OK`.

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/README.md
git commit -m "docs(tsugu): README — schema 4 surface (prepare/*, accepted-prefixes, verbs, driver default)"
```

---

## Task 11: Repo CLAUDE.md + marketplace.json

**Files:**
- Modify: `CLAUDE.md` (repo root, the tsugu paragraph)
- Modify: `.claude-plugin/marketplace.json` (tsugu entry, line ~61–64)

- [ ] **Step 1: Read the tsugu paragraph in CLAUDE.md + the tsugu entry in marketplace.json**

- [ ] **Step 2: Edit CLAUDE.md tsugu paragraph** — enumerate every touch (the paragraph has several):

- `Schema 3 (lineage: 004 → 005 → 006)` → `Schema 4 (lineage: 004 → 005 → 006 → 007)`.
- **Every** `prepare/* investigate/* review/*` occurrence → `prepare/*` (the prepare-routine gloss has it; scan the whole paragraph, there may be more than one).
- handoff prefixes `feat/* fix/*` → **accepted-prefixes** `feature/* bugfix/* chore/*`.
- converge verbs `accept/reject/park` → `accept/park/drop` (continue implicit, promote orthogonal).
- "pending = slug-paired **handoff** branch" → "slug-paired **accepted** branch".
- Append `007-tsugu-thin-core-design.md` to the Spec list.

Keep it one paragraph; don't duplicate counts/versions.

- [ ] **Step 3: Edit marketplace.json**

Bump tsugu `"version": "0.3.0"` → `"0.4.0"`. Update its `description` to reflect schema 4 (single `prepare/*`, accepted-prefixes, non-containment landings advanced). **Do not** touch the top-level `metadata.version`.

- [ ] **Step 4: Verify**

```bash
grep -q '006 → 007' CLAUDE.md && echo "lineage OK"
! grep -q 'investigate/\* review/\*' CLAUDE.md && echo "single-prefix OK"
! grep -q 'accept/reject/park' CLAUDE.md && echo "verbs OK"
! grep -qi 'slug-paired handoff branch' CLAUDE.md && echo "accepted-branch wording OK"
grep -q '007-tsugu-thin-core-design' CLAUDE.md && echo "spec list OK"
python3 -c "import json;d=json.load(open('.claude-plugin/marketplace.json'));t=[p for p in d['plugins'] if p['name']=='tsugu'][0];print('version',t['version']);assert t['version']=='0.4.0'" && echo "version OK"
python3 -c "import json;json.load(open('.claude-plugin/marketplace.json'))" && echo "json valid OK"
```
Expected: every annotated `OK`, `version 0.4.0`, `json valid OK`.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md .claude-plugin/marketplace.json
git commit -m "docs(tsugu): bump to schema 4 / v0.4.0 in CLAUDE.md + marketplace.json"
```

---

## Task 12: Whole-tree consistency sweep (verifies all success criteria)

**Files:** none (read-only verification across the tree). If a check fails, fix the offending file in its own commit.

- [ ] **Step 1: No stale schema-3 vocabulary anywhere in the plugin**

```bash
echo "--- stale '## Handoff Prefixes' outside migrations.md (expect none) ---"
# migrations.md LEGITIMATELY references '## Handoff Prefixes' — it documents the
# 3→4 rename FROM that heading and older-schema state — so exclude it.
rg -n 'Handoff Prefixes' plugins/tsugu --glob '!**/migrations.md' || echo "clean"
echo "--- stale multi-prefix default outside migrations.md (expect none) ---"
# migrations.md legitimately shows 'prepare/* investigate/* review/*' when
# documenting the schema-2→3 state — exclude it, same as the Handoff sweep.
rg -n 'prepare/\* investigate/\* review/\*' plugins/tsugu --glob '!**/migrations.md' || echo "clean"
echo "--- schema stamp is 4 in the template (expect match) ---"
rg -n 'tsugu-schema: 4' plugins/tsugu/skills/tsugu/templates/policy.md
echo "--- no schema-3 stamp lingering in templates (expect none) ---"
rg -n 'tsugu-schema: 3' plugins/tsugu/skills/tsugu/templates || echo "clean"
```
Expected: `clean` / matches as annotated.

- [ ] **Step 2: Success-criteria checklist (spec 007 §Success criteria 1–8)**

Walk each criterion and confirm by grep/read:
1. fresh-init template: `## Branch Prefixes: prepare/*`, `## Accepted Prefixes: feature/* bugfix/* chore/*`, `tsugu-schema: 4` (Task 1).
2. SKILL.md partition = three rows / two checked facts, no rewrite elaboration; advanced.md holds it via a one-line pointer (Task 3).
3. exclude mode, multi-agent forward-compat, omni-repo recursion still in SKILL.md core: `rg -n 'public-branch-tsugu|Multi-agent|omni-repo|recursion' plugins/tsugu/skills/tsugu/SKILL.md`.
4. SKILL.md converge: accept/park/drop named, continue implicit, promote orthogonal (Task 4).
5. migrations.md 3→4 renames, stamps last, proposes collapse on confirmation, legacy per-branch with tip hash (Task 8).
6. migrations.md states 1→2→3→4 contract (Task 8).
7. slug join's four legs intact in SKILL.md; only the extra-prefix artifact example moved to advanced (Task 3 + Task 2).
8. SKILL.md §F: provisioned-machine default, conditional cloud fallback, no-self-wake unchanged (Task 5).

- [ ] **Step 3: Cross-reference integrity**

```bash
echo "--- every references/*.md SKILL.md points to exists ---"
for r in advanced migrations policy-and-intake notes-and-packet git-recipes; do
  test -f "plugins/tsugu/skills/tsugu/references/$r.md" && echo "$r OK" || echo "$r MISSING"
done
echo "--- SKILL.md mentions advanced.md ---"
rg -n 'advanced.md' plugins/tsugu/skills/tsugu/SKILL.md
```
Expected: all `OK`; advanced.md referenced.

- [ ] **Step 4: If everything passes, no commit needed.** If a fix was made, commit it:

```bash
git add -A && git commit -m "fix(tsugu): consistency-sweep fixes for schema 4"
```

---

## Post-plan: review + PR

After all tasks: run the **review-loop** skill on the branch diff (local Claude + Codex gate), then open a PR linking issue #38 and pairing spec/plan 007. Never auto-merge (per review-loop + CLAUDE.md). Default to a merge commit to preserve history.
