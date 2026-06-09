# Tsugu Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `tsugu` plugin — a single skill + `/tsugu [init|prepare|converge|settle]` command — that lets an agent prepare/converge/settle work using git's DAG as the coordination substrate, per `docs/superpowers/specs/004-tsugu-skill-design.md`.

**Architecture:** A prompt-first Claude Code plugin. `SKILL.md` carries intent, conventions, and routing; `templates/` are written into a user repo by `init`; `references/git-recipes.md` documents the plain-git recipes the agent executes. **Light by design — no shipped scripts, and no prescribed test harness.** The recipes are *documented guidance*, not locked command scripts: future agents execute them with their own judgment. The plugin is registered in `.claude-plugin/marketplace.json`.

**Tech Stack:** Markdown (SKILL/README/references/templates), JSON (plugin.json/marketplace.json), `jq` for JSON sanity. No runtime language, no network, **no helper scripts**.

**Source of truth:** the spec (`004-tsugu-skill-design.md`). Where a step says "per spec §X", copy the exact text/fields/commands from that section — do not paraphrase away precision (coordination-ref, remote/default resolution, claimed-by/at, two-layer intake lifecycle, public-diff guarantee).

**Lightness rule (per the author):** keep this skill light. Do **not** add a lot of helper scripts; give future agents freedom to decide *how* to run the recipes. Verification in this plan is structural + a dogfood checklist; the executor MAY sanity-check any recipe in a throwaway scratch repo at its discretion, but building a test suite is explicitly **not** required.

**Conventions (CLAUDE.md / memory):**
- Implementation is **code** → land on a **feature branch**, not `main`. Use @superpowers:using-git-worktrees for isolation.
- Anything dev-time stays out of `plugins/tsugu/` (the install boundary) — but this plan ships none.
- Bump `marketplace.json` `metadata.version` when adding a plugin (1.3.0 → 1.4.0).
- Commit per task; conventional commits scoped `…(tsugu)`; every commit message ends with the `Co-Authored-By` trailer.
- Run @review-loop on the finished branch.

---

## File Structure

**Ships to users (inside `plugins/tsugu/`):**
- `plugins/tsugu/.claude-plugin/plugin.json` — manifest.
- `plugins/tsugu/commands/tsugu.md` — `/tsugu [routine]` slash command.
- `plugins/tsugu/skills/tsugu/SKILL.md` — the skill prompt.
- `plugins/tsugu/skills/tsugu/references/git-recipes.md` — documented plain-git recipes.
- `plugins/tsugu/skills/tsugu/references/policy-and-intake.md` — policy fields + intake/human-bridge.
- `plugins/tsugu/skills/tsugu/references/notes-and-packet.md` — branch.md/intake/runs/packets/context structure.
- `plugins/tsugu/skills/tsugu/templates/{policy,branch,intake,run,packet}.md` — written into a user repo by `init`.

**Repo-level (not shipped):**
- `.claude-plugin/marketplace.json` — add `tsugu` entry, bump `metadata.version`.
- `README.md`, `CLAUDE.md` — add `tsugu` to plugin lists/details.

**No `tools/tsugu/`, no `plugins/tsugu/.../scripts/`.** Recipes are prose guidance; the agent executes them with native git.

---

## Task 0: Feature branch + worktree

**Files:** none (git setup).

- [ ] **Step 1: Isolated worktree** (use @superpowers:using-git-worktrees; RAM-disk per CLAUDE.md — ask the user to create a RAM disk if absent):

```bash
git fetch origin
git worktree add /Volumes/ramdisk/dong3/tsugu -b feat/tsugu-plugin origin/main
cd /Volumes/ramdisk/dong3/tsugu
```

- [ ] **Step 2: Verify branch** — `git branch --show-current` → `feat/tsugu-plugin` (NOT `main`).

(All later git/file ops happen in this worktree; every commit ends with the `Co-Authored-By` trailer.)

---

## Task 1: Plugin manifest + marketplace registration

**Files:** Create `plugins/tsugu/.claude-plugin/plugin.json`; modify `.claude-plugin/marketplace.json`.

- [ ] **Step 1: `plugins/tsugu/.claude-plugin/plugin.json`**

```json
{
  "name": "tsugu",
  "description": "Git-native preparation & convergence — agents prepare work privately via git's DAG (init/prepare/converge/settle), package evidence for human-agent handoff, and settle cleanly. Never auto-merges; invokes no user-installed skill by default.",
  "author": { "name": "caasi" },
  "homepage": "https://github.com/caasi/dong3",
  "repository": "https://github.com/caasi/dong3",
  "license": "MIT",
  "keywords": ["git", "worktree", "agent-coordination", "preparation", "convergence", "tsugu"],
  "skills": "./skills/",
  "commands": "./commands/"
}
```

- [ ] **Step 2:** Add to `.claude-plugin/marketplace.json` `plugins` array (after `review-loop`), and bump `metadata.version` `"1.3.0"` → `"1.4.0"`:

```json
{
  "name": "tsugu",
  "source": "./plugins/tsugu",
  "description": "Git-native preparation & convergence skill — prepare/converge/settle work over git's DAG; never auto-merges",
  "version": "0.1.0"
}
```

- [ ] **Step 3: Validate**

```bash
jq -e . plugins/tsugu/.claude-plugin/plugin.json >/dev/null && echo plugin-ok
jq -e '.plugins[] | select(.name=="tsugu")' .claude-plugin/marketplace.json >/dev/null && echo entry-ok
jq -e '.metadata.version=="1.4.0"' .claude-plugin/marketplace.json >/dev/null && echo version-ok
```
Expected: `plugin-ok entry-ok version-ok`.

- [ ] **Step 4: Commit** — `feat(tsugu): scaffold plugin manifest + marketplace entry (v0.1.0)`.

---

## Task 2: Templates (written into user repos by `init`)

**Files:** Create `plugins/tsugu/skills/tsugu/templates/{policy,branch,intake,run,packet}.md` — exact bodies from spec §"Templates" (these are load-bearing; the recipes parse `status:`, `claimed-by:`, `claimed-at:`, `coordination-ref:`, `remote:`, `default-branch:`, `linked-branch:`).

- [ ] **Step 1: `policy.md`** — sections: Private Git Space, Public Coordination, Branch Prefixes, `## Remote` (`remote: origin`, `default-branch:`), `## Coordination ref` (`coordination-ref: default`), `## Skill use`, `## Skills Tsugu may use (this repo, opt-in)` (default: none), `## Recursion`.
- [ ] **Step 2: `branch.md`** — `status:` (open|paused|converged|settled), `claimed-by:`, `claimed-at:`, then headed sections.
- [ ] **Step 3: `intake.md`** — `status:` (open|claimed|done|dropped), `linked-branch:`, then sections.
- [ ] **Step 4: `run.md`** + **`packet.md`** — per spec (packet keeps "Candidate next plans" hint + the "Suggested public branch" name/target clarifier).

- [ ] **Step 5: Verify fields**

```bash
t=plugins/tsugu/skills/tsugu/templates
grep -q 'coordination-ref:' $t/policy.md && grep -q 'remote:' $t/policy.md && grep -q 'default-branch:' $t/policy.md && echo policy-ok
grep -q 'claimed-by:' $t/branch.md && grep -q 'claimed-at:' $t/branch.md && grep -q 'status:' $t/branch.md && echo branch-ok
grep -q 'linked-branch:' $t/intake.md && echo intake-ok
test -f $t/run.md && test -f $t/packet.md && echo files-ok
grep -q 'Suggested public branch' $t/packet.md && grep -q 'Candidate next plans' $t/packet.md && echo packet-ok
```
Expected: `policy-ok branch-ok intake-ok files-ok packet-ok`.

- [ ] **Step 6: Commit** — `feat(tsugu): add .tsugu/ templates (policy/branch/intake/run/packet)`.

---

## Task 3: `references/git-recipes.md` — documented git recipes

**Files:** Create `plugins/tsugu/skills/tsugu/references/git-recipes.md`.

Document each recipe as **guidance the agent follows with judgment** — exact commands shown so they're unambiguous, but framed as "here's the reliable way", not a script to run blindly. Each recipe carries the correctness points the spec + review established. (The executor MAY sanity-check any of these in a scratch repo; not required.)

- [ ] **Step 1: "## Read the queue (cold-start safe)"** — `git fetch <remote>` first; resolve `<remote>` (bootstrap with `origin` or the local `policy.md`; re-fetch if the fetched `policy.md` names another remote) and `<default>` (`git symbolic-ref refs/remotes/<remote>/HEAD`, `git remote set-head <remote> --auto` if unset, or a `default-branch` policy field); enumerate work branches with `git branch --remotes --format='%(refname:short)'` filtered to `<remote>/` + the **work** prefixes `prepare|investigate|review` (`public/*` is a settle output, not a queue item), and use each result **verbatim** (do not re-prefix `<remote>/`); read context with `git show <branch-ref>:.tsugu/branch.md`; discover intake via `git ls-tree -r --name-only <remote>/<coordination-ref> -- .tsugu/intake/`, keeping only `*.md` that carry a `status:` field (so `.gitkeep`/`README.md` seeds are ignored).

- [ ] **Step 2: "## Coordination-ref writes"** — a `.tsugu/`-only commit to the coordination ref is private-space (no approval): commit → `git pull --rebase` → push. **On conflict over a contended note, re-read its lifecycle and reconsider — never blind-overwrite a `claimed`/`done`** (agent judgment). Default `coordination-ref` = default branch; if it is push-protected, use a dedicated branch — **prefer an orphan** `tsugu/coord` holding only `intake/` + `context/shared/`, seed empty dirs with `.gitkeep` (git can't track empty dirs), and keep `policy.md`/`templates/` on the default branch.

- [ ] **Step 3: "## Cut a clean public branch"** — `git switch -c public/<x> <remote>/<default>` (cut from the **fetched** ref; use the configured `<remote>`, never a hardcoded `origin`); apply only accepted **code paths** with a path-scoped `git diff <remote>/<default>..prepare/<x> -- <code paths> | git apply --index` (this preserves adds/modifies/**deletes/renames**; do **not** use `git checkout prepare/<x> -- <paths>`, which can't reproduce a deletion); never include `.tsugu/`; sanity: `git diff <remote>/<default>..public/<x> -- .tsugu/` is empty. Opening the PR is human-gated.

- [ ] **Step 4: "## Freshness" + "## Cleanup order"** — resume/refresh a persistent branch by rebasing onto `<remote>/<default>` (never a stale local default); a pushed scratch branch then needs `git push --force-with-lease` (never plain `--force`); **prefer merge** for history-bearing branches; **stop and ask** on non-trivial conflict. Cleanup is always `git worktree remove <path>` **before** `git branch --delete --force <branch>`.

- [ ] **Step 5: "## init skeleton"** — create the `.tsugu/` tree (`intake/`, `context/{shared,dormant,archived}/`, `templates/`), seed each dir with `.gitkeep`, write `policy.md`/templates **only if absent** (idempotent **repair** on re-run; never overwrite a curated `policy.md`); if the default branch is push-protected, write the fixed metadata on an `init/*` branch + a human-approved PR, and don't run `prepare` until it's merged.

- [ ] **Step 6: Sanity-read** the file once (`grep -c '^## ' …` shows the 5+ recipe headings) and **commit** — `docs(tsugu): git-recipes reference (read-queue, coordination-ref, public, freshness, init)`.

---

## Task 4: References — policy-and-intake.md + notes-and-packet.md

**Files:** Create `references/policy-and-intake.md`, `references/notes-and-packet.md`.

- [ ] **Step 1:** `policy-and-intake.md` — every `policy.md` field (Private/Public boundary, prefixes, `remote`, `default-branch`, `coordination-ref`, skill-use + per-repo opt-in, recursion) with one-line semantics; the intake **human-bridge** explanation (tracker → committed intake note, optional, skipped for pure-Tsugu).
- [ ] **Step 2:** `notes-and-packet.md` — structure + lifecycle of `branch.md` (status + claimed-by/at), `intake/` (two-layer inbox vs work model), `runs/`, `packets/`, `context/{shared,dormant,archived}`; the context placement rule **with its omni-repo framing** (same abstraction at every level; write context at the lowest repo level where it stays true; promote upward only when it affects multiple repos).
- [ ] **Step 3: Verify** — `grep -q 'coordination-ref' references/policy-and-intake.md && grep -q 'two-layer\|inbox' references/notes-and-packet.md` (adjust to wording used).
- [ ] **Step 4: Commit** — `docs(tsugu): policy/intake + notes/packet reference docs`.

---

## Task 5: SKILL.md

**Files:** Create `plugins/tsugu/skills/tsugu/SKILL.md`.

- [ ] **Step 1: Frontmatter** — `name: tsugu`; `description:` with trigger phrases ("prepare work before review", "/tsugu", "init/prepare/converge/settle", "carry work forward", "git-native preparation"); make clear it is human-triggered/schedule-wireable and **invokes no user-installed skill by default**.

- [ ] **Step 2: Body** (source: spec). Sections in order:
  1. **継ぐ (tsugu)** name/intent (inherit / continue / carry forward).
  2. **The spine** — git is the message bus; tracker = optional human-bridge; `.tsugu/` committed.
  3. **Routing** — `/tsugu [init|prepare|converge|settle]`; link recipes via `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/git-recipes.md` (link the **file**, not heading anchors — avoids drift).
  4. **The four routines** — concrete steps per spec, incl. the prepare partition table, converge "present & yield + set `converged`", settle outcomes (writes terminal status; ⚙/🔒 marks).
  5. **Private vs public boundary** + **skill-use rule** (no user-installed skill by default; repo `policy.md` opt-in).
  6. **Multi-agent: reserved** (claimed-by/at courtesy; no arbitration in v1).
  7. **Scheduling & recursion** — `prepare` can be wired to `/schedule` / cron, but a SKILL.md **cannot self-wake** (cadence comes from the external driver — see Trigger model); and the **recursive workspace model** (a single repo and an omni-repo are the same abstraction — traverse the tree, work locally or delegate downward, promote upward; context lives at the lowest level where it stays true).
  8. **Templates** — written by init from `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/templates/`.

- [ ] **Step 3: Verify**

```bash
s=plugins/tsugu/skills/tsugu/SKILL.md
grep -q '^name: tsugu' "$s" && echo name-ok
grep -q 'CLAUDE_PLUGIN_ROOT' "$s" && echo refs-ok
! grep -Eiq 'invoke (the )?(review-loop|brainstorming|planning|using-git-worktrees|finishing)' "$s" && echo no-invoke-ok
grep -q '継ぐ' "$s" && echo name-origin-ok
grep -q 'schedule' "$s" && echo sched-ok
grep -Eq 'omni-repo|recursive' "$s" && echo recursion-ok
```
Expected: `name-ok refs-ok no-invoke-ok name-origin-ok sched-ok recursion-ok`.

- [ ] **Step 4: Commit** — `feat(tsugu): SKILL.md (spine, routing, four routines, boundary)`.

---

## Task 6: Slash command

**Files:** Create `plugins/tsugu/commands/tsugu.md`.

- [ ] **Step 1:** Frontmatter (`description`, `argument-hint: "[init|prepare|converge|settle]"`); body routes `$ARGUMENTS` to the routine and invokes the `tsugu` skill; blank arg → list the four routines and ask which.
- [ ] **Step 2: Verify** — `grep -q 'argument-hint' …` and that it references the skill.
- [ ] **Step 3: Commit** — `feat(tsugu): /tsugu [init|prepare|converge|settle] command`.

---

## Task 7: Repo docs (README + CLAUDE.md)

**Files:** Modify `README.md`, `CLAUDE.md`.

- [ ] **Step 1:** Add `tsugu` to the README plugin list (one line, matching existing style).
- [ ] **Step 2:** Add `tsugu` to CLAUDE.md — the `plugins/` tree comment + a **tsugu:** bullet in "Plugin Details" (spec path; note: single skill, **light/script-free**, never auto-merges, invokes no user-installed skill by default).
- [ ] **Step 3: Verify** — `grep -q tsugu README.md && grep -q tsugu CLAUDE.md`.
- [ ] **Step 4: Commit** — `docs(tsugu): add tsugu to README + CLAUDE.md plugin lists`.

---

## Task 8: Validation + dogfood (light)

**Files:** none (verification).

- [ ] **Step 1: JSON + structure sanity**

```bash
jq -e . plugins/tsugu/.claude-plugin/plugin.json >/dev/null
jq -e '.plugins[]|select(.name=="tsugu")' .claude-plugin/marketplace.json >/dev/null
test -f plugins/tsugu/skills/tsugu/SKILL.md && test -f plugins/tsugu/commands/tsugu.md
test "$(ls plugins/tsugu/skills/tsugu/templates/*.md | wc -l | tr -d ' ')" = 5
test "$(ls plugins/tsugu/skills/tsugu/references/*.md | wc -l | tr -d ' ')" = 3
echo structure-ok
```
Expected: `structure-ok`.

- [ ] **Step 2: Manual dogfood** (scratch git repo, plugin installed locally) — checklist:
  - `/tsugu init` → `.tsugu/` skeleton + `policy.md` (with `remote`/`default-branch`/`coordination-ref`); dirs seeded; re-run `init` repairs without overwriting `policy.md`; AGENTS/CLAUDE pointer offered.
  - Drop an intake note; `/tsugu prepare` → fetches, reads the queue from remote refs, opens a `prepare/*` branch, writes `branch.md` (status + claimed-by/at) + a packet, stays externally silent.
  - `/tsugu converge` → presents the packet, sets `status: converged`, invokes no skill.
  - `/tsugu settle` (accepted) → cuts a clean `public/*` (no `.tsugu/` in the diff, deletions preserved), sets `status: settled`, cleanup in correct order.
  - Record results in the PR description.

- [ ] **Step 3 (optional, executor's discretion):** sanity-check any single git recipe in a throwaway scratch repo if a step felt risky. **Not required** — keep tooling light; do not add a test suite.

- [ ] **Step 4:** Commit any fixes; ensure the branch is green.

---

## Task 9: review-loop + finish

- [ ] **Step 1:** Run @review-loop on `feat/tsugu-plugin` (local Claude + Codex gate; Copilot once a PR is open). Fix per tiers (T1 auto; T2/T3 with the author). Never auto-merge.
- [ ] **Step 2:** Per the author's pipeline: **fixup/squash** the implementation commits into a clean set, then **push**.
- [ ] **Step 3:** Open the PR (human-gated) linking the spec + this plan; use @superpowers:finishing-a-development-branch.
- [ ] **Step 4:** After merge, `git worktree remove` the worktree; keep the local branch (per CLAUDE.md).

---

## Notes for the executor

- **Light by design:** no shipped scripts, no test harness. Recipes in `git-recipes.md` are guidance — execute with judgment; verify in a scratch repo only if *you* think a step is risky.
- **Faithfulness gate:** before committing SKILL.md/references, re-read spec §Core intent — nothing may re-center on trackers, self-waking, or single-agent assumptions.
- **Recipe correctness to preserve** (from the spec's review): read the queue from **remote-tracking refs**; resolve `<remote>`/`<default>` explicitly; intake = `*.md` with a `status:` field; public branch via path-scoped `git apply --index` (preserves deletions); freshness rebase + `--force-with-lease`, merge for history-bearing; cleanup `worktree remove` before `branch --delete`; `init` idempotent + seeds empty dirs + never overwrites curated `policy.md`.
- **Full-length options** in any command you write (`--message`, `--remotes`, `--set-upstream`, `--delete`).
