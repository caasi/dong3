# Tsugu local-first prepare (spec 012) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement spec `docs/superpowers/specs/012-tsugu-local-first-prepare-design.md` — make `prepare/*` local-first (push default flips `yes`→`no`; remote push becomes a cross-machine opt-in), and recognize a human takeover of work by **containment** (any non-default/non-work branch carrying the prepare tip → *taken over* → suppress-from-auto-work + surface for human-confirmed cleanup). Bumps `tsugu-schema: 4 → 5` with a compat migration. Closes #52, extends 011.

**Architecture:** Skill-authoring (Markdown prose + JSON manifests), not runtime code. Verified by the repo's content-regression convention — `tools/tsugu/test-skill-content.sh` with `need()`/`refute()`/`need_in()` grep anchors (it already exists from 011 with 72 passing anchors; this plan grows it). TDD = append the task's anchors (red) → edit to match spec 012 → run the guard (green) → commit. The spec is the prose source of truth; anchors pin the load-bearing phrases.

**Tech Stack:** Bash + `grep -E`/`jq` for the content guard. No build system. `git` for the schema-aware reads. JSON edited by hand.

> **Harness edit rule (every task):** the guard ends with `echo "All tsugu SKILL.md content checks passed."`. **Insert each task's `need`/`refute` block immediately BEFORE that final `echo`** — never after it (appending after the echo would make the success line not last, breaking the `tail -1` checks in Task 0 / Task 9). "Append the anchors" in each task means "insert before the final echo."

**Branch discipline:** Implementation (skill behavior change) → **feature branch, never `main`**. Execute in a `/dev/shm` worktree (Task 0). The spec already landed on `main`; this plan only touches plugin files + the test harness.

---

## File Structure

| File | Responsibility | Tasks |
| --- | --- | --- |
| *(workspace)* | `/dev/shm` feature-branch worktree | 0 |
| `tools/tsugu/test-skill-content.sh` | **Existing** content guard (72 anchors from 011); grown with 012 anchors | 1–8 |
| `plugins/tsugu/skills/tsugu/SKILL.md` | Local-first step 8 + schema-aware push read + `init` stamp `5`; soften the flat "remote-tracking refs" queue line; partition gains the **containment takeover** row (distinct from 011 *decided*); **taken-over** disposition (suppress-and-surface, human-confirmed cleanup, never auto-delete); the **auto-push invariant**; *Multi-agent* cross-machine push opt-in; B3 scoping note | 1, 2, 3 |
| `plugins/tsugu/skills/tsugu/references/git-recipes.md` | Rename the two "Read the queue" mode labels (local = default); union local+remote work refs; add the fresh/ref-scoped/normalized/excluding `git for-each-ref --contains` **takeover** recipe; push recipe → opt-in | 4 |
| `plugins/tsugu/skills/tsugu/templates/policy.md` | `tsugu-schema: 5`; `## Push` default `push-prepare-branches: no`; comment notes local-first + cross-machine opt-in + the in-flight-backup tradeoff | 5 |
| `plugins/tsugu/skills/tsugu/references/migrations.md` | **new `## Migration 4→5`** — write explicit `push-prepare-branches: yes` when absent (preserve old behavior); stamp `5` last; `init/*`-branch + PR path on push-protected default | 5 |
| `plugins/tsugu/skills/tsugu/references/notes-and-packet.md` | `prune` doc gains the **taken-over (redundant prepare)** category (surface-and-confirm) | 6 |
| `plugins/tsugu/commands/prune.md`, `commands/prepare.md` | prune desc notes the taken-over category; prepare desc notes local-first | 6 |
| `plugins/tsugu/skills/tsugu/README.md` | Local-first prepare + the cross-machine opt-in, user-facing | 7 |
| `.claude-plugin/marketplace.json` | bump tsugu `0.6.0 → 0.7.0` (versions live **only** here); description notes local-first | 8 |
| `plugins/tsugu/.claude-plugin/plugin.json` | **description only** (this file has **no `version` field** — do not add one) | 8 |

Each task edits a focused file set and is committed independently. SKILL.md changes (Tasks 1–3) are sequenced by spec change so each commit is one coherent shift. The anchors grow monotonically — each run re-checks all prior anchors (built-in regression sweep).

---

## Task 0: Create the feature-branch worktree (run before any edit)

**Files:** none (workspace setup). Must **not** land on `main`.

- [ ] **Step 1: Create the worktree on the RAM disk and cd into it**

```bash
df --human-readable /dev/shm >/dev/null 2>&1 || { echo "no /dev/shm tmpfs — ask the user"; exit 1; }
mkdir -p /dev/shm/dong3
git -C /home/caasi/GitHub/dong3 worktree add /dev/shm/dong3/tsugu-012 -b feat/tsugu-local-first-prepare main
cd /dev/shm/dong3/tsugu-012
```

- [ ] **Step 2: Verify branch + spec reachable**

Run: `git branch --show-current && ls docs/superpowers/specs/012-tsugu-local-first-prepare-design.md && tools/tsugu/test-skill-content.sh | tail -1`
Expected: `feat/tsugu-local-first-prepare`; the spec path; `All tsugu SKILL.md content checks passed.` (the 011 guard already passes here). Every later `git` runs from `/dev/shm/dong3/tsugu-012`.

---

## Task 1: SKILL.md — local-first prepare (push default `no` + schema-aware read + schema 5)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (step 8 push read ~line 142; the "Read the queue from remote-tracking refs" line ~114; the `init` "Stamp tsugu-schema: 4" line ~86)
- Modify: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Append failing anchors**

```bash
# --- Task 1: local-first prepare + schema-aware push read + schema 5 ---
# (dropped bare `need 'push-prepare-branches'` — pre-satisfied by the old default-yes prose)
need 'local-first|stays on local|keep work .*local'   "prepare is local-first by default"
need 'schema 4 else|tsugu-schema: 4.*yes|absent.*schema' "schema-aware push default read"
need 'tsugu-schema: 5|tsugu-schema. 5|schema . 5'     "init stamps schema 5"
need 'cross-machine opt-in'                           "remote push is a cross-machine opt-in (bigram — bare 'opt-in' appears 5x in SKILL already)"
# the OLD unconditional framing must be gone:
refute 'default .yes. when the section is absent'     "old flat 'default yes when absent' removed"
refute 'enumerates only remote-tracking refs'         "old 'only remote-tracking refs' framing removed"
```

- [ ] **Step 2: Run — verify red**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: SKILL.md missing: prepare is local-first by default` (or the first new anchor).

- [ ] **Step 3: Edit SKILL.md** (match spec 012 §"Change A" + §"Schema 4→5")

- Step 8 (~line 142): replace "push it if policy permits (default `yes` when the section is absent)… cold-start discovery enumerates **only** remote-tracking refs, so pushing is what lets the next agent inherit (the branch *is* the message)" with the **local-first** read: commit the local work branch; **push only when `push-prepare-branches: yes`** (cross-machine opt-in). State the **schema-aware default**: *absent → `yes` if `tsugu-schema: 4`, else `no`*. Scope "the branch is the message" to the cross-machine case.
- Soften the `## prepare` step-3 line "**Read the queue from remote-tracking refs**" (~line 114) to **local + remote** work prefixes (mechanics deferred to git-recipes; Task 4 does the recipe).
- `init` (~line 86): "**Stamp `tsugu-schema: 4`**" → **`5`** for a fresh init.

- [ ] **Step 4: Run — verify green**

Run: `tools/tsugu/test-skill-content.sh`
Expected: all PASS (incl. the two refutes).

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "feat(tsugu): local-first prepare — push default no, schema-aware read, schema 5 (spec 012 Change A)"
```

---

## Task 2: SKILL.md — human-takeover detection by containment (Change B)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (the partition "five notes" / derivation region, ~lines 116–130)
- Modify: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Append failing anchors**

```bash
# --- Task 2: human-takeover detection by containment (Change B) ---
need 'taken over|taken-over'                          "takeover state named"
need 'human.?s own branch|own-named|human-named'      "recognizes a human's own-named branch (the #52 gap; 'for-each-ref --contains' alone is a no-op — it already exists at SKILL.md:124)"
need 'non-default.*non-work|non-work.*non-default'    "filter: non-default, non-work ref"
need 'generaliz'                                      "containment generalizes slug-pairing"
need 'script-free|ships no script|not a shipped'      "git-native, no shipped script note"
need 'classification is per-ref|each ref by its own tip|union.{0,12}display' "per-ref/per-tip classification — a divergent local in-progress tip is not suppressed by a stale remote tip's containment (spec A2)"
```

- [ ] **Step 2: Run — verify red**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: SKILL.md missing: takeover state named`.

- [ ] **Step 3: Edit SKILL.md** (match spec 012 §"Change B")

Add a partition note: a `prepare/<slug>` whose tip is **contained** by a **branch** that is neither the default (nor its aliases) nor a work-prefix ref (local or remote) is **taken over** — generalizing 011's accepted-prefix slug-pairing to human-named branches; slug-name pairing **stays** as the complementary squash-catch. Reference the precise recipe (`git for-each-ref --contains`, fresh, `refs/heads`/`refs/remotes` scope, remote-normalized, default-alias + work-ref excluded) as living in `git-recipes.md` (Task 4 writes it). Include the **git-native / script-free** note (the detection is native git + inline filtering, not a shipped script). Update the partition's "decided / not-in-progress" derivation to "slug-paired accepted branch (by name) **OR** any non-default/non-work ref contains the tip." **State the per-ref/per-tip rule (spec A2):** classification runs on a **specific tip** — the union-by-slug is a *display* merge only; when local `prepare/<slug>` and a stale `<remote>/prepare/<slug>` diverge, a stale remote tip contained by a human branch must **not** suppress a newer **local** in-progress tip (use the phrase "Classification is per-ref" so the anchor matches).

- [ ] **Step 4: Run — verify green**

Run: `tools/tsugu/test-skill-content.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "feat(tsugu): recognize human takeover by containment, generalizing slug-pairing (spec 012 Change B)"
```

---

## Task 3: SKILL.md — taken-over disposition + auto-push invariant + Multi-agent opt-in (Changes C, D)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (converge/prune disposition prose; the `## Multi-agent` section ~line 250; step 8 invariant)
- Modify: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Append failing anchors (incl. the critical no-auto-delete refute)**

```bash
# --- Task 3: taken-over disposition (C) + auto-push invariant (D) ---
need 'suppress|suppressed from auto-work'             "taken-over suppresses auto-work"
need 'both human-confirmed|local and remote, both'    "cleanup is local AND remote, both human-confirmed (bare 'human-confirmed' is pre-satisfied by 011 prose)"
need 'never auto-push|auto-push .*work-prefix|only .*work-prefix' "auto-push invariant: only work-prefix"
need 'redundant prepare|taken-over.*prune|prune.*taken-over' "prune taken-over category"
# the disposition must NEVER auto-delete the prepare/redundant ref (the load-bearing safety fix).
# NB: must NOT trip the legit forge 'auto-delete-head-branch' (hyphen) or 011's 'never auto-deletes on a guess'.
refute 'auto-delete[sd]?( the| a| its)?( local| redundant| stale)? (prepare|work branch)|auto-delete[sd]?( the| a)?( local| redundant) ref\b' "no auto-delete of the prepare/redundant ref"
```

- [ ] **Step 2: Run — verify red**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: SKILL.md missing: taken-over suppresses auto-work` (or the refute fails if any "auto-delete local" wording exists — there should be none yet, so it passes; the `need`s fail first).

- [ ] **Step 3: Edit SKILL.md** (match spec 012 §"Change C" + §"Change D")

- **Change C (disposition):** a taken-over `prepare/<slug>` is **suppressed from auto-work** and **surfaced** (at `prune`/`converge`) for the human to confirm — **never silently dropped, never auto-deleted**. A scheduled `prepare` leaves it for `converge`. On confirmation the redundant ref is deleted **local and remote, both human-confirmed**. Add the `prune` **taken-over (redundant prepare)** category (surface-and-confirm; precedence: classify as *settled* when default contains it, else *taken-over*).
- **Change D (invariant):** `prepare` auto-pushes **only** the `<work-prefix>/*` branch it is working, only when `push-prepare-branches: yes` — **never** an accepted-prefix or human-named branch (the human's B3). The cross-machine **agent-to-agent** push exception is deferred to *Multi-agent: reserved*.
- **Multi-agent (~line 250):** note the cross-machine `prepare/*` push as the opt-in / the deferred agent-to-agent push exception.
- **B3 note:** under local-first there is no remote `prepare/<slug>` to delete (011's B3 remote-prepare-delete line survives only in opt-in-push repos).

- [ ] **Step 4: Run — verify green**

Run: `tools/tsugu/test-skill-content.sh`
Expected: all PASS (the no-auto-delete refute confirms the safety property).

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "feat(tsugu): taken-over = suppress-and-surface + human-confirmed cleanup; auto-push invariant (spec 012 Changes C, D)"
```

---

## Task 4: git-recipes.md — local-default queue read + the containment takeover recipe

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/git-recipes.md` (the `## Read the queue` enumeration ~lines 108–135; add the takeover recipe; the push recipe)
- Modify: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Append failing anchors**

```bash
# --- Task 4: git-recipes local-default read + takeover recipe ---
GR='plugins/tsugu/skills/tsugu/references/git-recipes.md'
need_in "$GR" 'local-first .default.'                 "no-push mode relabeled local-first default ('local.*default' fallback dropped — it matches the pre-existing 'stale local default' Freshness line)"
need_in "$GR" 'cross-machine opt-in'                  "pushed mode relabeled cross-machine opt-in"
need_in "$GR" 'for-each-ref --contains'               "takeover containment recipe present (absent in git-recipes today)"
need_in "$GR" 'taken over|takeover'                   "git-recipes has the takeover recipe (replaces the 'fetch --prune' no-op, which already exists at git-recipes.md:41)"
need_in "$GR" 'refs/heads refs/remotes|refs/heads .refs/remotes' "takeover scoped to branch namespaces"
# the work queue must no longer be framed as remote-tracking-only (012 unions local+remote).
# git-recipes.md:98 currently reads "...unlike the work queue, which is remote-tracking" — that must go
# (the naive 'work queue.*local' need is a no-op: it matches that very line 98):
grep -Eiq 'work queue, which is remote-tracking' "$ROOT/$GR" \
  && fail "git-recipes still frames the work queue as remote-tracking-only (012 unions local+remote)" \
  || pass "work queue reframed off remote-tracking-only"
need_in "$GR" 'per-ref|each ref by its own tip'      "git-recipes notes per-ref/per-tip classification"
need_in "$GR" 'tsugu-schema. 5'                       "git-recipes init-skeleton stamps schema 5 (was 4 at :536)"
```

- [ ] **Step 2: Run — verify red**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: plugins/.../git-recipes.md missing: takeover containment recipe present`.

- [ ] **Step 3: Edit git-recipes.md** (match spec 012 §"Change A2" + §"Change B")

- **Do NOT add a duplicate local recipe** — git-recipes already ships the remote ("pushed mode") and local ("No-push mode is local") reads. **Rename the labels** — `pushed mode` → "cross-machine opt-in mode"; "No-push mode is local" → "local-first (default)" — and make the work-queue read the **union of local + remote** work prefixes (mirroring the accepted local+remote block already there). State discovery reads remote work refs **regardless** of push default; only pushing is gated. **Also fix the now-stale note at `git-recipes.md:98`** — "…unlike the work queue, which is remote-tracking" — since the work queue now spans local + remote too.
- **Add the takeover recipe** (a new sub-block under "Read the queue"): the spec 012 §"Change B" `git fetch --prune` + `git for-each-ref --contains "<tip>" refs/heads refs/remotes/<remote>` pipeline, with the documented exclusions (default + aliases `<remote>/<default>`/`<remote>/HEAD`; local **and** remote work-prefix refs; normalize the `<remote>/` prefix before matching — heeding the existing "use the ref verbatim, never re-prefix" note). Non-empty → *taken over* → surface (Change C). No shipped script.
- Push recipe → opt-in (push only when `push-prepare-branches: yes`).
- **Note the per-ref/per-tip rule** in the union read: union-by-slug is display-only; classify each ref by its own tip (mirror the SKILL "Classification is per-ref" wording).
- **Fix the stale schema stamp** in the init-skeleton recipe (`git-recipes.md:536`, "Write `policy.md` (with `tsugu-schema: 4`)") → **`5`** for a fresh init.

- [ ] **Step 4: Run — verify green; then sanity-check no double-prefix**

Run: `tools/tsugu/test-skill-content.sh && grep -n 'origin/origin\|<remote>/<remote>' plugins/tsugu/skills/tsugu/references/git-recipes.md || echo "no double-prefix"`
Expected: all PASS; `no double-prefix`.

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/references/git-recipes.md
git commit -m "docs(tsugu): git-recipes — local-first default queue read + containment takeover recipe (spec 012)"
```

---

## Task 5: templates/policy.md (schema 5 + push default) + migrations.md (4→5)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/templates/policy.md` (line 1 stamp; `## Push` field ~line 13)
- Modify: `plugins/tsugu/skills/tsugu/references/migrations.md` (append `## Migration 4→5`)
- Modify: `plugins/tsugu/commands/init.md` (lines 2/10/15: `(1→2→3→4)`, "stamps `tsugu-schema: 4`", "(1→2→3→4, …")
- Modify: `plugins/tsugu/skills/tsugu/references/policy-and-intake.md` (line 21: "1→2→3→4 for a schema-1 repo")
- Modify: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Append failing anchors**

```bash
# --- Task 5: schema 5 template + 4->5 migration ---
TP='plugins/tsugu/skills/tsugu/templates/policy.md'
MG='plugins/tsugu/skills/tsugu/references/migrations.md'
grep -Eq '^tsugu-schema: 5' "$ROOT/$TP" && pass "template stamped schema 5" || fail "templates/policy.md not stamped tsugu-schema: 5"
grep -Eq '^push-prepare-branches: no' "$ROOT/$TP" && pass "template push default no" || fail "templates/policy.md push default not 'no'"
need_in "$MG" '## Migration 4.5|Migration 4→5'        "migrations has a 4->5 section"
need_in "$MG" 'push-prepare-branches: yes'            "4->5 pins explicit old default yes"
need_in "$MG" 'tsugu-schema: 5|tsugu-schema. 5'       "4->5 stamps schema 5"
need_in 'plugins/tsugu/commands/init.md' '1.2.3.4.5|tsugu-schema. 5' "init.md updated to schema 5 / 1->...->5"
need_in 'plugins/tsugu/skills/tsugu/references/policy-and-intake.md' '1.2.3.4.5|schema . 5' "policy-and-intake updated to 1->...->5 / schema 5"
```

- [ ] **Step 2: Run — verify red**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: templates/policy.md not stamped tsugu-schema: 5`.

- [ ] **Step 3: Edit both files**

- `templates/policy.md`: line 1 `tsugu-schema: 4` → `5`; `## Push` `push-prepare-branches: yes` → `no`; update the comment to note local-first by default + set `yes` for the **cross-machine opt-in** + the in-flight-backup tradeoff.
- `migrations.md`: append `## Migration 4→5` following the file's established pattern (see `## Migration 3→4`): a mechanical step that **writes explicit `push-prepare-branches: yes` into `policy.md` when the field is absent** (preserving the old behavior; never overwrite an explicit value), then a final **"Stamp `tsugu-schema: 5` — last"** step. Honor the push-protected-default rule (write on an `init/*` branch + human-approved PR; stamp last). Also update the file's migration-contract prose that enumerates `1→2→3→4` → `1→2→3→4→5`.
- `commands/init.md`: update the three schema-4 facts — the `description` "(1→2→3→4)" → "(1→2→3→4→5)"; "stamps `tsugu-schema: 4`" → `5`; "(1→2→3→4, stamp written last; the 3→4…" → "(1→2→3→4→5, …".
- `references/policy-and-intake.md`: the migration mention "1→2→3→4 for a schema-1 repo" → "1→2→3→4→5".

- [ ] **Step 4: Run — verify green; validate the stamp is line 1**

Run: `tools/tsugu/test-skill-content.sh && head -1 plugins/tsugu/skills/tsugu/templates/policy.md`
Expected: all PASS; `tsugu-schema: 5`.

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/templates/policy.md plugins/tsugu/skills/tsugu/references/migrations.md
git commit -m "feat(tsugu): schema 4->5 — template default push-prepare-branches: no + compat migration pins old yes (spec 012)"
```

---

## Task 6: notes-and-packet.md prune category + command descriptions

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/notes-and-packet.md`
- Modify: `plugins/tsugu/commands/prune.md`, `plugins/tsugu/commands/prepare.md`
- Modify: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Append failing anchors**

```bash
# --- Task 6: prune taken-over category + command descriptions ---
NP='plugins/tsugu/skills/tsugu/references/notes-and-packet.md'
need_in "$NP" 'taken-over|redundant prepare'          "notes-and-packet documents the taken-over prune category"
need_in 'plugins/tsugu/commands/prune.md' 'taken-over|redundant prepare' "prune command notes taken-over"
need_in 'plugins/tsugu/commands/prepare.md' 'local-first|local by default' "prepare command notes local-first"
```

- [ ] **Step 2: Run — verify red**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: … notes-and-packet documents the taken-over prune category`.

- [ ] **Step 3: Edit the three files**

- `notes-and-packet.md` (the `prune` documentation): add the **taken-over (redundant prepare)** category — a `prepare/<slug>` whose tip a non-work/non-default branch contains; **surface-and-confirm**, never auto-delete; precedence with *settled*.
- `commands/prune.md`: description mentions surfacing the taken-over/redundant-prepare category.
- `commands/prepare.md`: description notes `prepare` is **local-first** (works on local `prepare/*`; remote push is the cross-machine opt-in).

- [ ] **Step 4: Run — verify green**

Run: `tools/tsugu/test-skill-content.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/references/notes-and-packet.md plugins/tsugu/commands/prune.md plugins/tsugu/commands/prepare.md
git commit -m "docs(tsugu): prune taken-over category + command descriptions for local-first (spec 012)"
```

---

## Task 7: README.md — local-first prepare (user-facing)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/README.md`
- Modify: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Append failing anchors**

```bash
# --- Task 7: README local-first ---
RM='plugins/tsugu/skills/tsugu/README.md'
need_in "$RM" 'local-first|local by default'          "README explains local-first prepare"
need_in "$RM" 'cross-machine opt-in'                  "README notes the cross-machine push opt-in (bigram — bare tokens already present in README)"
```

- [ ] **Step 2: Run — verify red**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: … README explains local-first prepare`.

- [ ] **Step 3: Edit README.md**

Explain, in user terms: `prepare` keeps work on **local** `prepare/*` by default; the remote push is a **cross-machine opt-in** (`push-prepare-branches: yes`), which also restores the remote backup of in-flight work; a human who takes the work onto their own branch is recognized by containment and the redundant `prepare/<slug>` is surfaced for cleanup (never auto-deleted). **Also update the stale `tsugu-schema: 4` example at `README.md:91`** → `5` (leave the line-179 link to spec 007 — that's a correct historical reference to the schema-4 spec).

- [ ] **Step 4: Run — verify green**

Run: `tools/tsugu/test-skill-content.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/README.md
git commit -m "docs(tsugu): README — local-first prepare + cross-machine opt-in (spec 012)"
```

---

## Task 8: Version bump + manifest descriptions

**Files:**
- Modify: `.claude-plugin/marketplace.json`, `plugins/tsugu/.claude-plugin/plugin.json`
- Modify: `tools/tsugu/test-skill-content.sh`

- [ ] **Step 1: Append failing anchors (jq-based, portable)**

```bash
# --- Task 8: version 0.7.0 + descriptions ---
jq -e '.plugins[]|select(.name=="tsugu")|.version=="0.7.0"' "$ROOT/.claude-plugin/marketplace.json" >/dev/null \
  && pass "marketplace: tsugu 0.7.0" || fail "marketplace.json: tsugu not at 0.7.0"
jq -e '.plugins[]|select(.name=="tsugu")|.description|test("local-first|local by default")' "$ROOT/.claude-plugin/marketplace.json" >/dev/null \
  && pass "marketplace desc notes local-first" || fail "marketplace.json: tsugu description missing local-first"
jq -e '.description|test("local-first|local by default")' "$ROOT/plugins/tsugu/.claude-plugin/plugin.json" >/dev/null \
  && pass "plugin.json desc notes local-first" || fail "plugin.json: description missing local-first"
```

- [ ] **Step 2: Run — verify red**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: marketplace.json: tsugu not at 0.7.0`. (Verify current is `0.6.0` first: `jq -r '.plugins[]|select(.name=="tsugu")|.version' .claude-plugin/marketplace.json` → `0.6.0`.)

- [ ] **Step 3: Edit the manifests**

- `marketplace.json`: tsugu entry `"version": "0.6.0"` → `"0.7.0"`; description notes **local-first** prepare.
- `plugin.json`: **description only** — it has **no `version` field** (versions live solely in `marketplace.json`, per CLAUDE.md); add `local-first` to the description, do **not** add a version key.

- [ ] **Step 4: Run — verify green; validate JSON**

Run: `tools/tsugu/test-skill-content.sh && jq . .claude-plugin/marketplace.json >/dev/null && jq . plugins/tsugu/.claude-plugin/plugin.json >/dev/null && echo JSON-OK`
Expected: all PASS; `JSON-OK`.

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh .claude-plugin/marketplace.json plugins/tsugu/.claude-plugin/plugin.json
git commit -m "chore(tsugu): bump 0.6.0 -> 0.7.0; descriptions note local-first prepare (spec 012)"
```

---

## Task 9: Full verification + PR

**Files:** none (verification + integration)

- [ ] **Step 1: tsugu guard end-to-end**

Run: `tools/tsugu/test-skill-content.sh`
Expected: every line `PASS`, ending `All tsugu SKILL.md content checks passed.`

- [ ] **Step 2: Other plugins' guards (no cross-plugin regression)**

Run: `tools/review-loop/test-skill-content.sh && tools/old-react/test-validator.sh`
Expected: both pass.

- [ ] **Step 3: Sanity-grep for leftover superseded language**

Run: `grep -rnE 'default .yes. when the section is absent|enumerates only remote-tracking|auto-delete[d]? (the |a )?local' plugins/tsugu/`
Expected: empty — the old push-default framing and any "auto-delete local prepare" wording are gone. Fix and re-run Step 1 if any appear.

- [ ] **Step 4: Schema-migration sanity**

Run: `head -1 plugins/tsugu/skills/tsugu/templates/policy.md; grep -c 'Migration 4' plugins/tsugu/skills/tsugu/references/migrations.md`
Expected: `tsugu-schema: 5`; a non-zero count (the 4→5 section exists). Also confirm `git diff main -- plugins/tsugu/skills/tsugu/templates/policy.md | grep -i 'tsugu-schema'` shows the `4 → 5` change (intended this time, unlike 011).

- [ ] **Step 4a: Catch-all sweep for stale schema-4 / 1→2→3→4 facts in shipped files**

Run: `grep -rnE 'tsugu-schema: 4|1.2.3.4([^.5]|$)' plugins/tsugu/ | grep -vE '007-tsugu-thin-core|Schema 4 is the spec 007|test-skill-content'`
Expected: only **legitimate historical** mentions remain — `migrations.md`'s internal `## Migration 3→4` / "Schema 4 is the spec 007 layout" prose (describing the *past* 3→4 step), and the spec-007 lineage link. **No current-state claim** ( fresh-init stamp, `commands/init.md` description, `policy-and-intake.md` "current schema", `git-recipes.md:536`, `README:91` ) may still say schema 4 / `1→2→3→4` as the present. Fix any straggler and re-run Step 1.

- [ ] **Step 5: Open the PR**

```bash
git push -u origin feat/tsugu-local-first-prepare
gh pr create --title "tsugu: local-first prepare + human-takeover recognition (spec 012)" \
  --body "Implements docs/superpowers/specs/012-tsugu-local-first-prepare-design.md. Closes #52.

- prepare is local-first: push-prepare-branches default no; remote push is a cross-machine opt-in
- recognize a human takeover by containment (any non-default/non-work branch carrying the prepare tip)
- taken-over: suppress-from-auto-work + surface; human-confirmed cleanup, never auto-delete
- explicit auto-push invariant (never auto-push accepted/human branches)
- schema 4 -> 5 with a compat migration pinning the old 'yes' default into existing repos
- content-regression guard: tools/tsugu/test-skill-content.sh

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 6: Review-loop the PR**

Run `/review-loop <PR#>` (local Claude + Codex gate, then Copilot) per project convention. Do not merge autonomously.

---

## Notes for the implementer

- **The spec is the prose source of truth.** Anchors pin load-bearing phrases, not full prose. Where a task says "match spec 012 §X," lift the wording from that section.
- **The biggest safety property** (and its `refute`, Task 3): a taken-over `prepare/<slug>` is **suppressed-and-surfaced, never auto-deleted**. Containment can false-positive on a branch built *on top of* the prepare tip; auto-delete would destroy a still-valid queue item. Keep the no-auto-delete refute green.
- **Don't add a duplicate local-discovery recipe** (Task 4): git-recipes already ships it; 012 flips the default and renames labels.
- **Schema is intended to change this time** (Task 9 Step 4): unlike 011, `tsugu-schema` goes `4 → 5`. The 4→5 migration *pins the old `yes`* so existing repos don't silently flip.
- **Commit per task.** The harness grows monotonically — each run re-checks all prior anchors.
