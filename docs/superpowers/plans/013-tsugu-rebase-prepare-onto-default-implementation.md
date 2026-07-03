# Spec 013 Implementation Plan — tsugu 0.8.0 (prepare/converge freshness-rebase)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement spec 013 across the `tsugu` plugin so `tsugu:prepare` freshness-rebases in-progress work branches and `tsugu:converge` offers the refresh as its first per-branch decision, then ship tsugu **0.8.0** (schema 6).

**Architecture:** `tsugu` is a prose skill — the deliverable is edits to `SKILL.md` + `references/` + `templates/`, gated by the **content-regression harness** `tools/tsugu/test-skill-content.sh` (assertions: `need`/`refute` against SKILL.md, `need_in <file> <regex>` against other files, `need_file`). The harness is our test loop: **add the anchors first (they fail), then make the prose satisfy them.** The single source of truth for prose content is **spec 013** (`docs/superpowers/specs/013-tsugu-rebase-prepare-onto-default-design.md`, on `main`) — each task implements a named Change (A–E) / section from it; do not re-derive the design, transcribe it.

**Tech Stack:** Markdown skill files; bash content-regression test (`tools/tsugu/test-skill-content.sh`); JSON plugin manifests. No build step.

## Global Constraints

- **Version:** `tsugu` `0.7.0 → 0.8.0` in **both** `.claude-plugin/marketplace.json` (the `tsugu` entry) and `plugins/tsugu/.claude-plugin/plugin.json`.
- **Schema:** `tsugu-schema: 5 → 6`. Fresh `init` writes the flag `yes`; the 5→6 migration pins `no` into existing repos; the schema stamp is written **last** in any migration.
- **Flag default:** `rebase-prepare-onto-default` fresh-init default `yes`; **absent reads as `no` (fail-safe)** — `yes` only ever from an explicit field.
- **Backend:** the automatic rebase uses `git rebase --merge` (forces the union-capable merge backend).
- **Recency:** claim/staleness reads **author-date** (`%aI` / `--sort=-authordate`), never committer-date.
- **Force-push:** **pinned + ancestor-guarded** `--force-with-lease=<branch>:<sha>`; never bare; first-push (create) carve-out; skip on pre-fetch divergence.
- **Invariants preserved:** never auto-merge; no public coordination without approval; derived state / no status field; script-free (no shipped scripts); committed footprint stays inside `.tsugu/` (the new `.tsugu/.gitattributes` is the one addition).
- **Scope honesty:** claim mergeability + early merge-conflict surfacing, **not** `file:line` anchor validity.
- **Stale-stamp hygiene** (per user global rule): when migrating the schema stamp, grep for and remove leftover `schema-5`/older stamps across `SKILL.md`, git-recipes, and `init` prose before committing.

---

## File Structure

| File | Responsibility for this change |
| --- | --- |
| `plugins/tsugu/skills/tsugu/templates/policy.md` | schema-6 stamp; new `## Freshness` section (flag `yes`) |
| `plugins/tsugu/skills/tsugu/templates/gitattributes` (**new**) | shipped as `.tsugu/.gitattributes`: `context.md merge=union` |
| `plugins/tsugu/skills/tsugu/SKILL.md` | prepare rebase step (A), conflict posture (B), author-date recency (C), force-with-lease (D); converge behind-default + refresh offer (E); `init` writes the flag + gitattributes; schema `5→6` |
| `plugins/tsugu/skills/tsugu/references/git-recipes.md` | `## Freshness` mode table; author-date prose; force-with-lease guard (pinned+ancestor+first-push); cold-start materialize-work-branch ordering |
| `plugins/tsugu/skills/tsugu/references/migrations.md` | new `5 → 6` step |
| `plugins/tsugu/skills/tsugu/references/policy-and-intake.md` | `### ## Freshness` field subsection |
| `plugins/tsugu/skills/tsugu/README.md` | user-facing description of the freshness-rebase + flag |
| `CLAUDE.md` (repo root) | tsugu paragraph: schema 6, lineage `…→013`, converge-refresh note |
| `.claude-plugin/marketplace.json` + `plugins/tsugu/.claude-plugin/plugin.json` | version `0.8.0`; descriptions note the freshness-rebase + schema 6 |
| `tools/tsugu/test-skill-content.sh` | new spec-013 anchors (interwoven per task) |

Task order is dependency-driven: **templates → SKILL prepare → SKILL converge → git-recipes → migrations → policy-and-intake → README → CLAUDE.md → version bump → full green**. Each task adds its own anchors to `test-skill-content.sh` first.

---

### Task 1: Policy template + gitattributes template + schema-6 stamp

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/templates/policy.md`
- Create: `plugins/tsugu/skills/tsugu/templates/gitattributes`
- Test: `tools/tsugu/test-skill-content.sh`

**Interfaces:**
- Produces: the `## Freshness` section shape (`rebase-prepare-onto-default: yes`) and the `.tsugu/.gitattributes` content (`context.md merge=union`) that Tasks 2/4/5 reference; the `tsugu-schema: 6` stamp that Tasks 2/5/8 assert.

- [ ] **Step 1: Add failing anchors** to `tools/tsugu/test-skill-content.sh` (new `# --- Spec 013 ---` block):

```bash
need_in 'plugins/tsugu/skills/tsugu/templates/policy.md' 'tsugu-schema: 6'                 "policy template stamps schema 6"
need_in 'plugins/tsugu/skills/tsugu/templates/policy.md' '## Freshness'                     "policy template has Freshness section"
need_in 'plugins/tsugu/skills/tsugu/templates/policy.md' 'rebase-prepare-onto-default: yes' "policy template defaults the flag yes"
need_file 'plugins/tsugu/skills/tsugu/templates/gitattributes'                              "gitattributes template shipped"
need_in 'plugins/tsugu/skills/tsugu/templates/gitattributes' 'context\.md merge=union'      "gitattributes unions context.md"
```

- [ ] **Step 2: Run test, confirm these fail.** Run: `bash tools/tsugu/test-skill-content.sh` → Expected: FAIL on the first new anchor (`schema 6`), since the template still says schema 5.

- [ ] **Step 3: Bump the stamp** in `templates/policy.md`: change `tsugu-schema: 5` → `tsugu-schema: 6` (first line).

- [ ] **Step 4: Add the `## Freshness` section** to `templates/policy.md` (place after `## Push`), implementing spec 013 "The flag" + the comment rationale:

```markdown
## Freshness

# Should an UNATTENDED `prepare` rebase in-progress work branches onto the current default,
# to keep the whole queue mergeable while you're away? `yes` = rebase every run (history
# rewrite; force-with-lease on pushed branches); `no` = pre-013 behavior, no rebase.
# Absent reads as `no` (fail-safe). Converge's human-present refresh offer is independent
# of this flag. Costs of `yes`: churn + union-interleave on long-idle branches (see spec 013).
rebase-prepare-onto-default: yes
```

- [ ] **Step 5: Create `templates/gitattributes`** with exactly:

```gitattributes
# Shipped by `tsugu:init` as .tsugu/.gitattributes. Intentional, flag-independent:
# context.md is narrative and should never block any merge or rebase.
context.md merge=union
```

- [ ] **Step 6: Run test, confirm Task-1 anchors pass.** Run: `bash tools/tsugu/test-skill-content.sh` → Expected: the 5 Task-1 anchors PASS (later tasks' anchors, if added, still fail).

- [ ] **Step 7: Commit.**

```bash
git -C /dev/shm/dong3/spec-013-impl add plugins/tsugu/skills/tsugu/templates/policy.md plugins/tsugu/skills/tsugu/templates/gitattributes tools/tsugu/test-skill-content.sh
git -C /dev/shm/dong3/spec-013-impl commit -m "feat(tsugu): policy template schema 6 + Freshness flag + gitattributes union (spec 013)"
```

---

### Task 2: SKILL.md — prepare routine (Changes A/B/C/D)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (the `prepare` numbered steps; the `Multi-agent` recency prose; the `init` step; the schema stamp)
- Test: `tools/tsugu/test-skill-content.sh`

**Interfaces:**
- Consumes: the flag name/default (Task 1), `git rebase --merge`, author-date, the pinned force-with-lease (Global Constraints).
- Produces: the prepare-side vocabulary Task 3 (converge) and Task 4 (git-recipes) cross-reference.

- [ ] **Step 1: Add failing anchors** (append to the spec-013 block):

```bash
need 'rebase-prepare-onto-default'                          "prepare reads the freshness flag"
need 'git rebase --merge'                                   "forced merge backend"
need 'absent .*→ .*no|fail-safe'                            "flag absent reads no (fail-safe)"
need '--force-with-lease=<branch>:'                         "pinned force-with-lease"
need 'author-date|--sort=-authordate|%aI'                   "recency keys off author-date"
need 'skip working (the|that) branch this run'              "abort => skip working this run"
need 'bare-submodule'                                       "bare-submodule pairs excluded"
refute '--sort=-committerdate|committer-date .*claim'       "no committer-date recency read"
```

- [ ] **Step 2: Run test, confirm fails.** Run: `bash tools/tsugu/test-skill-content.sh` → FAIL on `rebase-prepare-onto-default` (not yet in SKILL.md).

- [ ] **Step 3: Implement the prepare rebase step (Change A)** — after the queue-partition step, add the rebase step transcribing spec 013 §"Change A" (A1 rebase on the local checked-out branch; the flag read absent→no; the in-progress-only set; A3 **bare-submodule pairs excluded**). Use `git rebase --merge <remote>/<default>`.

- [ ] **Step 4: Implement the conflict posture (Change B)** — content context.md auto-unions (via the shipped gitattributes); any real conflict → `git rebase --abort`, **skip working the branch this run**, surface for converge; **no committed status/narrative write on abort**. Reference `references/git-recipes.md` for the mechanics (don't inline the full recipe).

- [ ] **Step 5: Implement author-date recency (Change C)** — in the `Multi-agent` recency section (and any staleness read), state the claim/staleness read keys off **author-date** (rebase preserves it); remove/avoid any committer-date phrasing.

- [ ] **Step 6: Implement force-with-lease note (Change D)** — the pinned, divergence-guarded `--force-with-lease=<branch>:<sha>`; local-first pushes nothing; point to git-recipes for the ancestor-guard + first-push detail.

- [ ] **Step 7: Update `init` + schema** — `init` writes the `## Freshness` default and the `.tsugu/.gitattributes`; bump every SKILL.md `Schema 5`/`schema 5` reference to 6 and extend the lineage to `…→ 013`. Grep for stale `schema-5`/`Schema 5` and fix all.

- [ ] **Step 8: Run test, confirm Task-2 anchors pass** (and Task-1 still pass). Run: `bash tools/tsugu/test-skill-content.sh`.

- [ ] **Step 9: Commit.**

```bash
git -C /dev/shm/dong3/spec-013-impl add plugins/tsugu/skills/tsugu/SKILL.md tools/tsugu/test-skill-content.sh
git -C /dev/shm/dong3/spec-013-impl commit -m "feat(tsugu): prepare freshness-rebase step + author-date recency + schema 6 (spec 013 A-D)"
```

---

### Task 3: SKILL.md — converge (Change E)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (the `converge` steps)
- Test: `tools/tsugu/test-skill-content.sh`

**Interfaces:**
- Consumes: the prepare-side flag + force-with-lease vocabulary (Task 2).
- Produces: the converge behavior README (Task 7) and CLAUDE.md (Task 8) summarize.

- [ ] **Step 1: Add failing anchors:**

```bash
need 'behind default by N|behind-default'                   "converge surfaces behind-default"
need 'refresh onto current default first'                   "refresh is the first per-branch decision"
need 'git switch --create prepare/'                         "cold-start materializes the WORK branch"
need 'refresh-created|pre-existing divergence'              "reconcile-push gated by divergence origin"
refute 'git switch --create <accepted-prefix>/'             "cold-start never mints the accepted name"
```

- [ ] **Step 2: Run test, confirm fails.**

- [ ] **Step 3: Implement Change E** transcribing spec 013 §"Change E": E1 status view surfaces **"behind default by N"** + local/remote divergence; E2 refresh is the **first** per-branch decision (Y/n, default Y, "refresh first", may batch), on the **work branch** `prepare/<slug>` (cold-start `git switch --create prepare/<slug> <remote>/prepare/<slug>`, never the accepted name); accept mints the accepted name; E3 human-present conflict handling; E4 not gated by the prepare flag / interactive so never silent; E5 bare-submodule pair refreshed here; the **pushed-repo reconcile** gated to refresh-created divergence (print force-with-lease), pre-existing divergence → "integrate remote first", never a clobber. Keep "still no build/verify/push".

- [ ] **Step 4: Run test, confirm Task-3 anchors pass** (Tasks 1–2 still pass).

- [ ] **Step 5: Commit.**

```bash
git -C /dev/shm/dong3/spec-013-impl add plugins/tsugu/skills/tsugu/SKILL.md tools/tsugu/test-skill-content.sh
git -C /dev/shm/dong3/spec-013-impl commit -m "feat(tsugu): converge surfaces behind-default + offers refresh first (spec 013 E)"
```

---

### Task 4: git-recipes.md — Freshness mode-table + guards

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/git-recipes.md` (`## Freshness`; the recency prose; the accept/handoff recipe)
- Test: `tools/tsugu/test-skill-content.sh`

**Interfaces:**
- Consumes: the flag, author-date, `--merge`, pinned force-with-lease (Tasks 1–3).

- [ ] **Step 1: Add failing anchors:**

```bash
need_in 'plugins/tsugu/skills/tsugu/references/git-recipes.md' 'merge-base --is-ancestor'   "divergence ancestor-guard in recipe"
need_in 'plugins/tsugu/skills/tsugu/references/git-recipes.md' '--force-with-lease=<branch>:' "pinned lease in recipe"
need_in 'plugins/tsugu/skills/tsugu/references/git-recipes.md' 'git rebase --merge'          "recipe forces merge backend"
need_in 'plugins/tsugu/skills/tsugu/references/git-recipes.md' 'authordate|%aI'              "recipe recency keys off author-date"
```

- [ ] **Step 2: Run test, confirm fails.**

- [ ] **Step 3: Rewrite `## Freshness`** as a **who's-present → posture mode table** (manual-resume: stop-and-ask · unattended prepare: abort+skip · converge: resolve/park live · maintenance: rebase→verify), promote it from optional to the flag-gated automatic prepare step, and add: forced `git rebase --merge`; content-context.md auto-union; any real conflict → abort+skip; the **pinned + ancestor-guarded + first-push** `--force-with-lease` block (transcribe spec 013 §"Change D" recipe verbatim, incl. `pre`/`sha` capture, the divergence gate BEFORE rebase, and the first-push carve-out). Update the recency/classification prose to **author-date**. Update the accept/handoff recipe with the cold-start **materialize-work-branch-then-refresh** ordering (accepted name minted only at accept). Remove the old "does not freshness-rebase" flat line where 013 revises it.

- [ ] **Step 4: Run test, confirm Task-4 anchors pass** (Tasks 1–3 still pass).

- [ ] **Step 5: Commit.**

```bash
git -C /dev/shm/dong3/spec-013-impl add plugins/tsugu/skills/tsugu/references/git-recipes.md tools/tsugu/test-skill-content.sh
git -C /dev/shm/dong3/spec-013-impl commit -m "feat(tsugu): git-recipes Freshness mode-table + divergence/first-push guards + author-date (spec 013)"
```

---

### Task 5: migrations.md — the 5 → 6 step

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/migrations.md`
- Test: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Add failing anchors:**

```bash
need_in 'plugins/tsugu/skills/tsugu/references/migrations.md' '5 ?(→|->|to) ?6'                 "migrations has a 5->6 step"
need_in 'plugins/tsugu/skills/tsugu/references/migrations.md' 'rebase-prepare-onto-default: no'  "5->6 pins the flag no"
need_in 'plugins/tsugu/skills/tsugu/references/migrations.md' 'gitattributes'                    "5->6 adds the gitattributes"
```

- [ ] **Step 2: Run test, confirm fails.**

- [ ] **Step 3: Add the `5 → 6` step** transcribing spec 013 §"Schema 5 → 6 and the compat migration": write explicit `rebase-prepare-onto-default: no` when `## Freshness` is absent (preserve pre-013 *unattended* behavior); add `.tsugu/.gitattributes` (`context.md merge=union`) **unconditionally** (the one intentional flag-independent non-preservation); stamp written **last**; `init/*`-branch + human-approved PR on a push-protected default. Follow the existing per-step format in the file.

- [ ] **Step 4: Run test, confirm Task-5 anchors pass.**

- [ ] **Step 5: Commit.**

```bash
git -C /dev/shm/dong3/spec-013-impl add plugins/tsugu/skills/tsugu/references/migrations.md tools/tsugu/test-skill-content.sh
git -C /dev/shm/dong3/spec-013-impl commit -m "feat(tsugu): migrations 5->6 (pin flag no + add gitattributes) (spec 013)"
```

---

### Task 6: policy-and-intake.md — the `## Freshness` field docs

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/policy-and-intake.md`
- Test: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Add failing anchor:**

```bash
need_in 'plugins/tsugu/skills/tsugu/references/policy-and-intake.md' 'rebase-prepare-onto-default'  "policy-and-intake documents the Freshness field"
```

- [ ] **Step 2: Run test, confirm fails.**

- [ ] **Step 3: Add a `### ## Freshness` field subsection** mirroring the existing per-field subsections (`### ## Push`, etc.): what `rebase-prepare-onto-default` gates (prepare-side only — the unattended, history-rewriting, force-pushing rebase), that converge's refresh is flag-independent, the merge-backend requirement, and the absent→`no` fail-safe read.

- [ ] **Step 4: Run test, confirm passes.**

- [ ] **Step 5: Commit.**

```bash
git -C /dev/shm/dong3/spec-013-impl add plugins/tsugu/skills/tsugu/references/policy-and-intake.md tools/tsugu/test-skill-content.sh
git -C /dev/shm/dong3/spec-013-impl commit -m "docs(tsugu): policy-and-intake documents the Freshness field (spec 013)"
```

---

### Task 7: README.md — user-facing

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/README.md`

- [ ] **Step 1: Add the user-facing paragraph** — unattended `prepare` keeps in-progress branches current against default (the `rebase-prepare-onto-default` flag, default on for fresh repos); converge surfaces "behind default by N" and offers the refresh; the union/author-date/lease guarantees in plain terms; the honest scope (mergeability, not anchor validity). No test anchor required (README is user prose), but keep it consistent with SKILL.md.

- [ ] **Step 2: Commit.**

```bash
git -C /dev/shm/dong3/spec-013-impl add plugins/tsugu/skills/tsugu/README.md
git -C /dev/shm/dong3/spec-013-impl commit -m "docs(tsugu): README notes the freshness-rebase + Freshness flag (spec 013)"
```

---

### Task 8: CLAUDE.md (repo root) — tsugu paragraph

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the tsugu paragraph** — `Schema 5` → `Schema 6`; lineage `… → 012 → 013`; note the converge refresh (accept is no longer flatly "does not rebase" — converge *offers* a freshness-refresh; completion still gated); add spec 013 to the Spec list. Per repo convention CLAUDE.md rides straight to `main`, but here it is part of the feature branch's change set (it documents shipped behavior) — commit it on the branch with the rest.

- [ ] **Step 2: Commit.**

```bash
git -C /dev/shm/dong3/spec-013-impl add CLAUDE.md
git -C /dev/shm/dong3/spec-013-impl commit -m "docs: CLAUDE.md tsugu paragraph -> schema 6, lineage 013, converge-refresh note"
```

---

### Task 9: Version bump — tsugu 0.8.0

**Files:**
- Modify: `.claude-plugin/marketplace.json` (the `tsugu` entry, currently `0.7.0`)
- Modify: `plugins/tsugu/.claude-plugin/plugin.json` (`0.7.0`)
- Test: `tools/tsugu/test-skill-content.sh`

> **NOTE (post-hoc correction):** `plugins/tsugu/.claude-plugin/plugin.json` has **no `version` field** — only `.claude-plugin/marketplace.json` carries plugin versions. The bump described below is marketplace.json-only; the `plugin.json` line above does not apply.

> **Version numbers are the known error trap** (a flat grep for `"version": "0.8.0"` matches *any* plugin, and `marketplace.json` carries a version for all nine). Assert the **tsugu** entry precisely with `jq`, and prove **no other plugin's version moved**.

- [ ] **Step 1: Add failing, tsugu-precise anchors** (jq-based, not a flat grep):

```bash
# precise: the tsugu entry specifically, in BOTH manifests
[ "$(jq -r '.plugins[]|select(.name=="tsugu")|.version' "$ROOT/.claude-plugin/marketplace.json")" = "0.8.0" ] \
  || fail "marketplace tsugu entry not at 0.8.0"; pass "marketplace tsugu == 0.8.0"
[ "$(jq -r '.version' "$ROOT/plugins/tsugu/.claude-plugin/plugin.json")" = "0.8.0" ] \
  || fail "plugin.json tsugu not at 0.8.0"; pass "plugin.json tsugu == 0.8.0"
```

  (Add `command -v jq >/dev/null || fail "jq required"` near the top of the spec-013 block if the harness doesn't already depend on jq.)

- [ ] **Step 2: Run test, confirm fails.**

- [ ] **Step 3: Bump ONLY the tsugu entry** `0.7.0 → 0.8.0` in `marketplace.json` (the object with `"name": "tsugu"`) and in `plugins/tsugu/.claude-plugin/plugin.json`. Update the tsugu `description` in both to note the freshness-rebase + schema 6 if the description enumerates features. **Do not touch any other plugin's version.**

- [ ] **Step 4: Prove no collateral version change.** Run:
  `git -C /dev/shm/dong3/spec-013-impl diff main -- .claude-plugin/marketplace.json | grep -E '^\+.*"version"'`
  → Expected: **exactly one** added `"version": "0.8.0"` line (the tsugu entry). If more than one version line changed, revert the stray edit. Also confirm the marketplace's own top-level `"version"` (line ~8, the marketplace manifest version) is only bumped if you intend to — it is distinct from the tsugu plugin version.

- [ ] **Step 5: Run test, confirm passes.**

- [ ] **Step 6: Commit.**

```bash
git -C /dev/shm/dong3/spec-013-impl add .claude-plugin/marketplace.json plugins/tsugu/.claude-plugin/plugin.json tools/tsugu/test-skill-content.sh
git -C /dev/shm/dong3/spec-013-impl commit -m "chore(tsugu): bump 0.7.0 -> 0.8.0 (spec 013, schema 6)"
```

---

### Task 10: Full green + self-consistency sweep

**Files:**
- Test: `tools/tsugu/test-skill-content.sh`
- Possible touch-ups across all edited files.

- [ ] **Step 1: Run the full content-regression test.** Run: `bash tools/tsugu/test-skill-content.sh` → Expected: **all** anchors (pre-existing + spec-013) PASS, no FAIL.

- [ ] **Step 2: Stale-stamp grep.** Run: `grep -rn 'schema 5\|schema-5\|tsugu-schema: 5\|0\.7\.0' plugins/tsugu docs/superpowers/plans/013-* tools/tsugu` in the worktree → confirm no stale schema-5 / 0.7.0 references remain (except historical mentions in migrations.md describing the *from* state). Fix any leak, commit.

- [ ] **Step 3: Cross-file consistency read.** Skim SKILL.md ↔ git-recipes.md ↔ policy template ↔ migrations ↔ README for agreement on: flag default (`yes` fresh / absent `no`), `git rebase --merge`, author-date, pinned+guarded lease, converge "refresh first". Fix drift, commit if needed.

- [ ] **Step 4: Version sanity (explicit, per standing guidance).** Re-run Task 9's collateral guard (`git diff main -- .claude-plugin/marketplace.json plugins/tsugu/.claude-plugin/plugin.json`) and eyeball it: **only** the tsugu plugin version moved 0.7.0→0.8.0, in both manifests, and nothing else's version changed. Version numbers are the documented error trap — do not skip this even when the test is green.

- [ ] **Step 5: Verification-before-completion.** Do not claim done until Step 1 shows all-PASS output. Then take the **whole** change set through the review-loop gate (Claude+Codex local, then a PR + Copilot) before merge to `main` — the review-loop is mandatory here, and it must scrutinize the version numbers specifically.

---

## Self-Review (run after drafting, before executing)

- **Spec coverage:** Changes A–E → Tasks 2–4; flag/schema → Tasks 1/5/9; docs → Tasks 6–8. Files-touched table of spec 013 ↔ this plan's File Structure: all rows covered.
- **Placeholder scan:** prose content is transcribed from spec 013 sections at execution time (the spec is the detailed source, committed and stable on `main`) — each task names the exact section and the exact anchors; no "TBD".
- **Type/name consistency:** flag name `rebase-prepare-onto-default`, section `## Freshness`, template file `templates/gitattributes` → `.tsugu/.gitattributes`, `git rebase --merge`, `--force-with-lease=<branch>:<sha>` used identically across tasks.
