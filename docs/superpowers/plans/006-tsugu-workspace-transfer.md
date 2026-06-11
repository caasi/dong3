# Tsugu v2 (schema 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the `tsugu` skill to schema 3 — collapse committed `.tsugu/` to `policy.md` + `context.md` + `knowledge/`, move observation sources / opt-in skills / packets to a per-machine personal folder, remove the intake-note machinery, and ship a 2→3 migration.

**Architecture:** This is a **documentation/skill rewrite**, not executable code — the deliverables are markdown (`SKILL.md`, references, templates, command routers) plus two JSON manifests. There is no unit-test harness; verification is **consistency greps** (the shrunk shipped skill must not reference removed concepts except where migration legitimately describes leaving them behind) plus the **`review-loop` skill** (Claude + Codex local gate) as the integration gate. Work happens on a feature branch in a RAM-disk worktree per the repo's git conventions.

**Tech Stack:** Markdown (Claude Code skill format), JSON manifests, `git`, `grep`/`rg`, the `review-loop` plugin.

**Source of truth:** `docs/superpowers/specs/006-tsugu-workspace-transfer-design.md` (read it before starting — every task cites its sections). Lineage: specs 004/005 remain historical.

---

## Pinned implementation details (deferred by the spec as "implementation detail")

The spec left two things as implementation detail; this plan **fixes** them:

1. **Personal folder path.** `~/.claude/tsugu/<project-key>/`, mirroring Claude Code's own `~/.claude/projects/<key>/` convention.
   - `<project-key>` = `git rev-parse --path-format=absolute --git-common-dir`, with a trailing `/.git` (or `/.git/worktrees/<wt>`) reduced to the **repo root absolute path**, then path separators (`/`) replaced by dashes — e.g. `/Users/x/GitHub/dong3` → `-Users-x-GitHub-dong3`. Stable across worktrees (the common dir is shared); per-machine-per-human (absolute paths differ per machine — fine, personal data never transfers).
   - Layout:
     ```
     ~/.claude/tsugu/<project-key>/
       config.md          # relocated personal sections: ## Intake Sources, ## Skills (opt-in)
       packets/<slug>.md  # converge decision-view (derived, personal)
     ```
2. **Personal config shape.** One `config.md` with two sections (`## Intake Sources`, `## Skills (opt-in)`), each independently bearing a confirmed-empty marker so "unset" is distinct from "confirmed none". This is the faithful relocation of the two former `policy.md` sections.

These are pinned here so the README and SKILL.md can reference a concrete path. Treat the exact dashification as the convention; if Claude Code's own key derivation differs in a detail, match it.

---

## File structure (what changes, and its single responsibility)

| File | Responsibility after the rewrite | Action |
| --- | --- | --- |
| `plugins/tsugu/skills/tsugu/templates/policy.md` | shared coordination policy **only** | modify (remove personal sections; redefine public-branch; drop landed/squash-records wording) |
| `plugins/tsugu/skills/tsugu/templates/config.md` | **personal** config template (sources + opt-in skills) | **create** |
| `plugins/tsugu/skills/tsugu/templates/context.md` | per-ref / mainline narrative | modify (drop the runs/packets links section) |
| `plugins/tsugu/skills/tsugu/templates/packet.md` | personal converge decision-view | modify (note it is personal; keep mode hint) |
| `plugins/tsugu/skills/tsugu/templates/intake.md` | — | **delete** |
| `plugins/tsugu/skills/tsugu/templates/run.md` | — | **delete** |
| `plugins/tsugu/skills/tsugu/SKILL.md` | the spine + three routines + single-layer state model | rewrite (shrink) |
| `plugins/tsugu/skills/tsugu/references/policy-and-intake.md` | shared policy fields + personal-config pointer | rewrite (collapse) |
| `plugins/tsugu/skills/tsugu/references/notes-and-packet.md` | `context.md` + `knowledge/` + personal packet | rewrite (collapse) |
| `plugins/tsugu/skills/tsugu/references/git-recipes.md` | cold-start read, single-layer partition, handoff, freshness, cleanup, smaller init skeleton, personal-folder bootstrap | rewrite (shrink) |
| `plugins/tsugu/skills/tsugu/references/migrations.md` | migrations 1→2 **and** 2→3 | modify (append 2→3) |
| `plugins/tsugu/commands/{init,prepare,converge}.md` | thin routers, schema-3 invariants | modify |
| `plugins/tsugu/skills/tsugu/README.md` | user-facing v2 overview | rewrite |
| `plugins/tsugu/.claude-plugin/plugin.json` | plugin metadata | modify (description) |
| `.claude-plugin/marketplace.json` | marketplace manifest | modify (description + version bump 0.2.0 → 0.3.0) |
| `CLAUDE.md` (root) | repo guidance — tsugu section | modify |

**Removed-concept vocabulary** (must NOT survive in the shipped skill except inside `migrations.md`, which describes leaving them behind): `intake/` as a committed dir, intake-note `status:`/`open`/`claimed`/`done`/`dropped` lifecycle, `linked-branch:`, `landed:`, `runs/`, repo-seeded `templates/`, "reconciliation case", the two-layer/inbox partition.

---

## Task 0: Worktree setup

**Files:** none (environment).

- [ ] **Step 1: Confirm RAM disk and create the worktree + feature branch**

The repo's `CLAUDE.md` requires multi-task plan execution in a RAM-disk worktree, and code changes on a feature branch (never `main`). RAM disk is at `/Volumes/ramdisk`.

```bash
git -C /Users/caasi/GitHub/caasi/dong3 worktree add /Volumes/ramdisk/dong3/tsugu-v2 -b feat/tsugu-schema-3 main
cd /Volumes/ramdisk/dong3/tsugu-v2
```

- [ ] **Step 2: Verify you are on the feature branch in the worktree**

Run: `git -C /Volumes/ramdisk/dong3/tsugu-v2 rev-parse --abbrev-ref HEAD`
Expected: `feat/tsugu-schema-3`

> **Every git command in later tasks runs from this worktree** (`cd /Volumes/ramdisk/dong3/tsugu-v2` or `git -C …`). A commit from the wrong cwd lands on `main`. No GPG signing is configured for this repo, so no key warm-up is needed.

All paths below are relative to the worktree root.

---

## Task 1: Templates

**Spec:** §F (templates kept/removed), §A2 (personal config shape), §A3 (policy split), §E1 (context.md), §E2 (public-branch redefine), §C3 (retain-handoff).

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/templates/policy.md`
- Create: `plugins/tsugu/skills/tsugu/templates/config.md`
- Modify: `plugins/tsugu/skills/tsugu/templates/context.md`
- Modify: `plugins/tsugu/skills/tsugu/templates/packet.md`
- Delete: `plugins/tsugu/skills/tsugu/templates/intake.md`, `plugins/tsugu/skills/tsugu/templates/run.md`

- [ ] **Step 1: Rewrite `templates/policy.md` (shared sections only)**

Stamp `tsugu-schema: 3` on line 1. **Remove** the `## Intake Sources` and `## Skills Tsugu may use (this repo, opt-in)` sections entirely (they relocate to `config.md`). **Keep** `## Skill use` (the shipped invariant). **Redefine** `## Public branch`'s comment to the WIP-knowledge framing (§E2): include = the work branch's prep DAG + its `context.md` land on the default branch as committed WIP knowledge; `knowledge/` lands on the coordination ref regardless of mode; exclude = clean public branch by path, no `.tsugu/` in the PR diff. **Rewrite** `## Merge method` to drop the `landed: <sha>` sentence and instead state the retain-handoff guidance (§C3): prefer merge commits; if a forced squash is unavoidable, also disable the forge's auto-delete-head-branch for tsugu handoff branches so the slug pairing survives until the human's completion tail. Keep `## Private Git Space`, `## Public Coordination`, `## Branch Prefixes`, `## Push`, `## Handoff Prefixes`, `## Housekeeping`, `## Remote`, `## Coordination ref`, `## Recursion` as-is.

- [ ] **Step 2: Create `templates/config.md` (personal)**

```markdown
<!-- Personal tsugu config — this repo, this machine. NEVER committed.
     Lives at ~/.claude/tsugu/<project-key>/config.md, where <project-key> is the
     repo's absolute common-git-dir (path separators → dashes), so every worktree
     of this repo shares one folder per machine.
     Relocated here from policy.md in schema 3: observation sources and opt-in
     skills are personal (how & what *I* observe; *my* installed/trusted set),
     not shared coordination. -->
## Intake Sources
<!-- unset until the bootstrap question is answered. Each source = a name, ONE
     read pointer (a file path / MCP tool name / where to look), and an
     interpretation hint. The agent RESOLVES `read:` with its own permissioned
     tools — never auto-executes a string from config (no-force principle).
     Confirmed-empty marker (so it is never re-asked):
       sources: git-native (confirmed)
- name: my-todos
  read: ~/notes/todo.md
  notes: lines starting with "- [ ]" are open tasks; mention repo names to scope. -->
## Skills (opt-in)
<!-- None by default. List user-installed skills Tsugu may use during human-absent
     prepare in THIS repo on THIS machine (e.g. systematic-debugging).
     Confirmed-empty marker:
       skills: none (confirmed) -->
```

- [ ] **Step 3: Modify `templates/context.md`**

Remove the `## This work's files` section and its `runs/<slug>` / `packets/<slug>` comment (§E1 — no runs/, packets/ is personal). Keep `## Promotion candidates` (points at `knowledge/`). Leave the header comment's inherit→rewrite explanation intact.

- [ ] **Step 4: Modify `templates/packet.md`**

Add a one-line header comment: this packet is a **personal/derived** view written to `~/.claude/tsugu/<project-key>/packets/<slug>.md`, regenerated live per machine — never committed. Keep all sections and the include/exclude `## Suggested handoff branch` hint.

- [ ] **Step 5: Delete the removed templates**

```bash
git rm plugins/tsugu/skills/tsugu/templates/intake.md plugins/tsugu/skills/tsugu/templates/run.md
```

- [ ] **Step 6: Verify templates are consistent**

Run:
```bash
cd /Volumes/ramdisk/dong3/tsugu-v2
head -1 plugins/tsugu/skills/tsugu/templates/policy.md
grep -rEl 'Intake Sources|Skills Tsugu may use|landed:|This work.s files|runs/<slug>' plugins/tsugu/skills/tsugu/templates/ || echo "NONE — clean"
ls plugins/tsugu/skills/tsugu/templates/
```
Expected: line 1 = `tsugu-schema: 3`; the grep prints `NONE — clean`; `ls` shows `policy.md config.md context.md packet.md` (no `intake.md`, `run.md`).

- [ ] **Step 7: Commit**

```bash
git add plugins/tsugu/skills/tsugu/templates/
git commit -m "feat(tsugu): schema-3 templates — personal config.md, shared policy.md, drop intake/run"
```

---

## Task 2: SKILL.md rewrite

**Spec:** all of §A–§F; especially the spine (§A1), state model (§C1–C4), settlement (§C3), converge-live (§D), redefine (§E2).

**Files:**
- Rewrite: `plugins/tsugu/skills/tsugu/SKILL.md`

- [ ] **Step 1: Rewrite the spine and routing**

Frontmatter `description`: keep the routine surface; drop any "intake note" / two-layer framing. In the body:
- State committed `.tsugu/` = **`policy.md` + `context.md` + `knowledge/`** only (the committed **WIP-knowledge** layer — a richer sibling of AGENTS.md/CLAUDE.md, §A1). Everything operational lives in **personal config** (`~/.claude/tsugu/<project-key>/`) + the skill's own shipped norms.
- Keep the **no-force principle** bullet (it still governs resolving personal `read:` pointers).
- Replace the legibility bullet's mention of `.tsugu/intake/` with: branch names + per-ref `context.md` are what a cold-start agent reconstructs the queue from.
- Keep "the slug is the join key" but drop the intake-note from the join set (slug joins the work branch, its `context.md`, its **personal** packet, and the handoff branch).
- Update the deferred-mechanics pointer list to the new reference set (no policy `landed:`/reconciliation; notes-and-packet covers context.md + knowledge/ + personal packet; templates referenced from `${CLAUDE_PLUGIN_ROOT}`, not seeded into the repo).

- [ ] **Step 2: Rewrite the three routines**

- **init:** writes only `policy.md` (shared) + mainline `context.md` + seeds `knowledge/`; stamps `tsugu-schema: 3`; reads templates from `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/templates/` (no repo `templates/` dir, no `intake/` dir). Keep prefix-disjointness validation, the three-way re-run decision (fresh / repair / migrate), and push-protected `init/*` PR rule.
- **prepare:** fetch → read queue from refs (no intake-note discovery) → **single-layer partition** (§C1: settled by containment / decided by slug-paired handoff / else in-progress); zero-commit branches exempt; claims by commit recency. **Personal-folder bootstrap** (§A2): when the personal config is absent and the run is interactive, ask once — separately for sources and opt-in skills — record confirmed-negative markers; headless → fall back, surface at converge. A source signal becomes a `prepare/<slug>` branch directly (no committed note). Keep push-by-default and own-subagent dispatch.
- **converge:** fetch-first, **read branches live** (§D) to build the status view; regenerate the **personal** packet (not a committed artifact). Steps 1–3 read-only (morning status view). Disposition: include = merge work branch (prep DAG + rewritten mainline `context.md` land); exclude = clean public branch by path. **Completion tail** (§C3): confirm landing → promote to `knowledge/` → delete worktrees then both branches. No intake-note flip. **Forced-squash + retain-handoff + narrative backstop** spelled out. Never auto-merges.

- [ ] **Step 3: Update the boundary, multi-agent, scheduling, recursion sections**

Boundary table unchanged. Multi-agent: drop the zero-commit-claim-from-coordination-ref-note rule (no notes); claims are pure commit recency. Remove every remaining mention of `runs/`, `intake/` notes, `landed:`, "reconciliation case".

- [ ] **Step 4: Verify SKILL.md self-consistency**

Run:
```bash
cd /Volumes/ramdisk/dong3/tsugu-v2
grep -nE 'intake/|landed:|runs/|claimed|reconciliation|status:' plugins/tsugu/skills/tsugu/SKILL.md || echo "NONE — clean"
grep -c 'knowledge/\|context.md\|personal' plugins/tsugu/skills/tsugu/SKILL.md
```
Expected: the first grep prints `NONE — clean` (no removed-vocabulary survives); the second prints a non-zero count (the new model is present). If any removed term legitimately must appear, justify it in the commit body — but the target is zero.

- [ ] **Step 5: Commit**

```bash
git add plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "feat(tsugu): rewrite SKILL.md to schema 3 — committed WIP knowledge, single-layer state, personal config"
```

---

## Task 3: references/policy-and-intake.md → shared policy + personal-config pointer

**Spec:** §A3, §A2 (bootstrap), §F (collapse), no-force principle.

**Files:**
- Rewrite: `plugins/tsugu/skills/tsugu/references/policy-and-intake.md`

- [ ] **Step 1: Collapse the document**

Keep the one-line semantics of every **shared** `policy.md` field (update `tsugu-schema` to current `3`; redefine `## Public branch` per §E2; rewrite `## Merge method` to the retain-handoff guidance, no `landed:`). **Delete** the entire intake human-bridge / recorded-form / dedup-by-note / `landed:` semantics / reconciliation-rule body. **Replace** it with a short **"Personal config (not in the repo)"** section: sources + opt-in skills live in `~/.claude/tsugu/<project-key>/config.md`; the bootstrap question (interactive prepare OR converge, separately for sources and skills, confirmed-negative markers, headless fallback — §A2); the no-force principle for resolving `read:` pointers; and the **weakened, accepted** source dedup (live-ref only — §C4). Consider renaming the file conceptually to "policy and personal config" but keep the filename (referenced by `${CLAUDE_PLUGIN_ROOT}` paths in SKILL.md — a rename is extra churn; only do it if SKILL.md's pointer is updated in lockstep).

- [ ] **Step 2: Verify**

Run:
```bash
cd /Volumes/ramdisk/dong3/tsugu-v2
grep -nE 'landed:|claimed → done|reconciliation|linked-branch|status: open' plugins/tsugu/skills/tsugu/references/policy-and-intake.md || echo "NONE — clean"
grep -c 'personal\|config.md\|git-native (confirmed)' plugins/tsugu/skills/tsugu/references/policy-and-intake.md
```
Expected: first grep `NONE — clean`; second non-zero.

- [ ] **Step 3: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/policy-and-intake.md
git commit -m "feat(tsugu): collapse policy-and-intake reference — shared fields + personal config, drop intake machinery"
```

---

## Task 4: references/notes-and-packet.md → context.md + knowledge/ + personal packet

**Spec:** §E1 (context.md), §B (knowledge free-form), §D (personal packet), §F.

**Files:**
- Rewrite: `plugins/tsugu/skills/tsugu/references/notes-and-packet.md`

- [ ] **Step 1: Collapse to the two surviving committed notes + the personal packet**

Keep `context.md` semantics (per-ref pure narrative; inherit→rewrite; merge-back rewrite in include mode; no-lineage; schema-compat `branch.md` fallback) but **remove** the "## This work's files" links to `runs/`/`packets/` and the "accumulated runs/packets archive loaded via active branch" load-semantics. Rewrite `knowledge/` as a **free-form wiki** (drop the three-clause/promotion-gate framing; keep the omni-repo lowest-level-that-stays-true placement rule). Replace the `intake/` two-layer table and the `runs/` section with a short **packet-is-personal** note: the packet is a derived view in `~/.claude/tsugu/<project-key>/packets/<slug>.md`, regenerated live at converge (§D), never committed; machine B needs no packet from machine A.

- [ ] **Step 2: Verify**

Run:
```bash
cd /Volumes/ramdisk/dong3/tsugu-v2
grep -nE 'Inbox|two-layer|status: open|runs/<slug>|landed:' plugins/tsugu/skills/tsugu/references/notes-and-packet.md || echo "NONE — clean"
```
Expected: `NONE — clean`.

- [ ] **Step 3: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/notes-and-packet.md
git commit -m "feat(tsugu): notes-and-packet reference — context.md + free-form knowledge/, packet goes personal"
```

---

## Task 5: references/git-recipes.md → simpler partition, drop intake writes, add bootstrap

**Spec:** §C1 (partition), §C3 (completion tail + retain-handoff), §A2 (personal folder + key derivation), §G (init skeleton), §F.

**Files:**
- Rewrite: `plugins/tsugu/skills/tsugu/references/git-recipes.md`

- [ ] **Step 1: Keep the load-bearing git recipes, drop the removed ones**

**Keep & simplify:** cold-start read-the-queue (fetch/prune, resolve `<remote>`/`<default>`), enumerate work + handoff branches (drop the intake-note discovery sub-step), the **two-fact partition** (containment + slug-pairing; remove the `landed:`-validation row and the zero-commit-claim-from-note rule), include-mode handoff cut, exclude-mode by-path clean cut, freshness, cleanup order, and a **smaller init skeleton** (`mkdir .tsugu/knowledge` only — no `intake/`, no `templates/`; seed `knowledge/.gitkeep`; write `policy.md` + mainline `context.md`; read templates from `${CLAUDE_PLUGIN_ROOT}`).
**Remove:** the coordination-ref **intake** write protocol, the `landed:` validation, and the completion-tail **intake flip** — the completion tail becomes promote → delete worktrees → delete both branches.
**Add:** a short **personal-folder bootstrap recipe** — derive `<project-key>` via `git rev-parse --path-format=absolute --git-common-dir` (strip `/.git`, dashify), write `~/.claude/tsugu/<project-key>/config.md` and `packets/`; resolve `read:` pointers with permissioned tools. **Add** the retain-handoff note to the handoff-cut recipe (recommend disabling forge auto-delete-head-branch on the squash path; narrative backstop when it can't be).

Note: `knowledge/` still lives on the coordination ref, so keep the coordination-ref **write protocol** for `knowledge/` promotion (it is no longer used for `intake/`, which is gone).

- [ ] **Step 2: Verify**

Run:
```bash
cd /Volumes/ramdisk/dong3/tsugu-v2
grep -nE 'intake/<slug>|claim intake|landed:|note_has_valid_landed|flip the linked intake' plugins/tsugu/skills/tsugu/references/git-recipes.md || echo "NONE — clean"
grep -c 'git-common-dir\|knowledge/\|--is-ancestor' plugins/tsugu/skills/tsugu/references/git-recipes.md
```
Expected: first grep `NONE — clean`; second non-zero (partition + bootstrap + knowledge writes present).

- [ ] **Step 3: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/git-recipes.md
git commit -m "feat(tsugu): git-recipes — single-layer partition, personal-folder bootstrap, drop intake writes/landed"
```

---

## Task 6: references/migrations.md → add migration 2→3

**Spec:** §G (the five migration steps + cross-ref/idempotency/ordering), the migration contract.

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/migrations.md`

- [ ] **Step 1: Keep 1→2, append 2→3**

Leave the migration contract and **Migration 1→2** intact (schema-1 repos still need it; they run 1→2→3). Add a **Migration 2→3** section transcribing §G's five steps verbatim in intent:
1. Move `## Intake Sources` + `## Skills Tsugu may use (this repo, opt-in)` from `policy.md` into the migrating machine's `~/.claude/tsugu/<project-key>/config.md`; remove both from `policy.md`. Re-entrant (durable personal copy re-derivable from old `policy.md` until the removal lands). Other machines re-ask via the bootstrap behavior.
2. Remove the relocated/removed committed paths **per-path / `git rm -r --ignore-unmatch <path>`** (idempotent on partial trees — `runs/`/`packets/` may never have been seeded), and **split across refs**: `intake/` on the coordination ref; `runs/`/`packets/`/`templates/` on the default branch; coord-ref deletion confirmed **before** the schema stamp (mirroring 1→2's rename ordering).
3. Redefine `public-branch-tsugu` wording (§E2); remove `landed:`/intake-flip wording.
4. Switch template reads to `${CLAUDE_PLUGIN_ROOT}` (no repo `templates/`); drop the `context.md` runs/packets links.
5. Stamp `tsugu-schema: 3` **last**.
Schema-history note: schema 3 = this layout.

- [ ] **Step 2: Verify the flag and the ordering claim**

Run:
```bash
cd /Volumes/ramdisk/dong3/tsugu-v2
grep -n 'ignore-unmatch' plugins/tsugu/skills/tsugu/references/migrations.md   # must be --ignore-unmatch, NOT --ignore-unmatched
grep -nE 'Migration 1→2|Migration 2→3|tsugu-schema: 3' plugins/tsugu/skills/tsugu/references/migrations.md
git rm --ignore-unmatched 2>&1 | head -1   # sanity: confirms the bad form errors
```
Expected: the flag appears as `--ignore-unmatch`; both migration sections present; the last command prints `error: unknown option 'ignore-unmatched'` (proving the good form was chosen).

- [ ] **Step 3: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/migrations.md
git commit -m "feat(tsugu): add migration 2→3 (relocate personal sections, drop intake/runs/packets/templates, stamp schema 3)"
```

---

## Task 7: command routers

**Spec:** §C (no intake), §D (live converge), §A2 (personal config).

**Files:**
- Modify: `plugins/tsugu/commands/init.md`, `plugins/tsugu/commands/prepare.md`, `plugins/tsugu/commands/converge.md`

- [ ] **Step 1: Update the invariant blurbs**

- `init.md`: schema-3 stamp; no repo `intake/`/`templates/` dirs created; idempotent repair / migrate (1→2→3).
- `prepare.md`: "asks where tasks come from once" → "bootstraps personal config (sources + opt-in skills) once when interactive; a scheduled run never blocks"; state from refs, single-layer.
- `converge.md`: add "reads branches **live**; the packet is a personal/derived view"; keep read-only-status-view + never-auto-merge.

- [ ] **Step 2: Verify**

Run:
```bash
cd /Volumes/ramdisk/dong3/tsugu-v2
grep -nE 'intake|status field' plugins/tsugu/commands/*.md || echo "NONE — clean"
```
Expected: `NONE — clean` (or only an acceptable "no status field" phrasing — review the hit if any).

- [ ] **Step 3: Commit**

```bash
git add plugins/tsugu/commands/
git commit -m "feat(tsugu): command routers reflect schema 3 — personal-config bootstrap, live converge"
```

---

## Task 8: README.md

**Spec:** §A1, §A2, §C, §E2, all final-shape tables.

**Files:**
- Rewrite: `plugins/tsugu/skills/tsugu/README.md`

- [ ] **Step 1: Rewrite the user-facing overview**

Replace the `.tsugu/` namespace diagram with the schema-3 shape (`policy.md` + `context.md` + `knowledge/`) and a **personal folder** block (`~/.claude/tsugu/<project-key>/` → `config.md`, `packets/`). Update "State is derived" (single-layer: containment + slug-pairing; no intake notes, no `landed:`). Update the `public-branch-tsugu` description to the WIP-knowledge framing. Drop runs/intake/packets from the committed picture. Add the spec 006 link; keep 004/005 as lineage.

- [ ] **Step 2: Verify**

Run:
```bash
cd /Volumes/ramdisk/dong3/tsugu-v2
grep -nE 'intake/|runs/|landed:' plugins/tsugu/skills/tsugu/README.md || echo "NONE — clean"
grep -c '006\|personal\|knowledge/' plugins/tsugu/skills/tsugu/README.md
```
Expected: first `NONE — clean`; second non-zero.

- [ ] **Step 3: Commit**

```bash
git add plugins/tsugu/skills/tsugu/README.md
git commit -m "docs(tsugu): README for schema 3 — committed knowledge layer + personal folder"
```

---

## Task 9: manifests (plugin.json + marketplace.json)

**Spec:** §F affected-surface; memory: bump marketplace metadata version on change.

**Files:**
- Modify: `plugins/tsugu/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Update descriptions and bump version**

`plugin.json` description → schema-3 shape (committed `.tsugu/` = policy + context + knowledge; personal config; state derived; never auto-merges; no user-installed skill by default). `marketplace.json` tsugu entry: same-spirit description **and** `version` `0.2.0` → `0.3.0`. If the marketplace top-level `metadata.version` exists, bump it too (per the repo memory rule for adding/removing plugins — here it is a description/version change, so bump only if the convention covers content changes; otherwise leave).

- [ ] **Step 2: Verify JSON validity**

Run:
```bash
cd /Volumes/ramdisk/dong3/tsugu-v2
python3 -c "import json;json.load(open('plugins/tsugu/.claude-plugin/plugin.json'));json.load(open('.claude-plugin/marketplace.json'));print('JSON OK')"
grep '"version"' .claude-plugin/marketplace.json | grep -A0 '0.3.0' && echo "version bumped"
```
Expected: `JSON OK`; the tsugu `version` reads `0.3.0`.

- [ ] **Step 3: Commit**

```bash
git add plugins/tsugu/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(tsugu): bump to 0.3.0 and update manifests for schema 3"
```

---

## Task 10: root CLAUDE.md tsugu section

**Files:**
- Modify: `CLAUDE.md` (root) — the `**tsugu:**` paragraph under "Plugin Details".

- [ ] **Step 1: Rewrite the tsugu paragraph**

Committed `.tsugu/` = `policy.md` + `context.md` + `knowledge/` (WIP knowledge); observation sources / opt-in skills / packets in the personal global folder; intake notes / `runs/` / `landed:` removed; state single-layer (containment + slug-pairing); converge reads branches live; schema 3. Keep the never-auto-merge / no-user-skill / light invariants. Update the spec pointer to add `006`.

- [ ] **Step 2: Verify**

Run:
```bash
cd /Volumes/ramdisk/dong3/tsugu-v2
grep -nE 'intake/|runs/|landed:' CLAUDE.md | grep -i tsugu || echo "tsugu line clean"
grep -n '006-tsugu' CLAUDE.md
```
Expected: tsugu line clean; the `006` spec is referenced.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update root CLAUDE.md tsugu section for schema 3"
```

---

## Task 11: Integration gate (consistency sweep + review-loop) and PR

**Files:** none new — verification + PR.

- [ ] **Step 1: Whole-skill consistency sweep**

The removed vocabulary must not survive anywhere in the **shipped** skill except `migrations.md` (which describes leaving it behind):

```bash
cd /Volumes/ramdisk/dong3/tsugu-v2
rg -nE 'intake/|\blanded:|\bruns/|linked-branch|reconciliation case|status: (open|claimed)' \
   plugins/tsugu/skills/tsugu plugins/tsugu/commands \
   --glob '!plugins/tsugu/skills/tsugu/references/migrations.md'
```
Expected: **no output** (every match would be a leak). Investigate and fix any hit before proceeding. Also confirm the templates dir no longer contains `intake.md`/`run.md` and that `config.md` exists.

- [ ] **Step 2: Self-review the full diff for prose coherence**

Read `git diff main...feat/tsugu-schema-3` end to end once. Check: no dangling cross-references between SKILL.md and the renamed/rewritten references; every `${CLAUDE_PLUGIN_ROOT}` pointer still resolves to a file that exists; the spec's success criteria 1–9 are each satisfied by some shipped text.

- [ ] **Step 3: Run the review-loop local gate**

Invoke the `review-loop` skill on the branch (local Claude + Codex gate — the same gate used on the spec). Target: `feat/tsugu-schema-3` vs `main`. Resolve T1 mechanically, T2/T3 with the user, until both reviewers are clean. (Do **not** open a GitHub PR until the local gate is clean; the skill enforces this.)

- [ ] **Step 4: Open the PR (human-gated)**

After the local gate is clean, open a PR for `feat/tsugu-schema-3` linking issue #36 and spec 006. Let the review-loop add Copilot. **Never auto-merge** — the user decides.

```bash
cd /Volumes/ramdisk/dong3/tsugu-v2
gh pr create --base main --head feat/tsugu-schema-3 \
  --title "feat(tsugu): schema 3 — the workspace holds only what transfers" \
  --body "Implements spec 006 (docs/superpowers/specs/006-tsugu-workspace-transfer-design.md). Closes #36. <summary of the shrink + migration>"
```

- [ ] **Step 5: Post-merge cleanup (after the user merges)**

Remove the worktree, keep the local branch (offline backup):
```bash
git -C /Users/caasi/GitHub/caasi/dong3 worktree remove /Volumes/ramdisk/dong3/tsugu-v2
```

---

## Notes for the executor

- **No TDD harness exists** for this skill — "verification" is the consistency greps in each task plus the Task 11 review-loop. Do not invent a test framework; the greps are the regression guard.
- **Don't paste spec prose verbatim into the skill** — the skill is the operative instruction set (tight, imperative), the spec is the rationale. Write skill text fresh, guided by the cited spec sections; keep the skill materially **smaller** than v1.1 (the whole point — current shipped sizes: SKILL.md 168, git-recipes 493, policy-and-intake 316, notes-and-packet 188 lines; expect meaningful reductions in the references especially).
- **Keep full-length CLI options** in all recipes (repo convention: `--message`, `--set-upstream`, `--ignore-unmatch`, …).
- **One commit per task** (already structured that way); if a task's review turns up a fix, that fix is its own commit per the repo's "separate commit per issue" rule.
- Conventional-commit scopes: `feat(tsugu):` for behavior-affecting skill content, `docs(tsugu):` for README/CLAUDE.md, `chore(tsugu):` for manifests.
