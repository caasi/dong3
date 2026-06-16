# Tsugu explore→handoff (spec 011) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement spec `docs/superpowers/specs/011-tsugu-handoff-converge-design.md` — re-align tsugu so `prepare` gathers (doesn't finalize), `converge` accept defaults to a handoff-only rename (with a human-marked maintenance exception), findings curation becomes an orthogonal converge item, and a new `/tsugu:prune` routine sweeps unused branches. Closes #48 and #49.

**Architecture:** This is **skill-authoring**, not runtime code. The deliverables are Markdown prose (SKILL.md, command files, references), JSON manifests (marketplace.json, plugin.json), and the project CLAUDE.md. Verification follows the repo's established **content-regression** convention — a `tools/<plugin>/test-skill-content.sh` script asserting required anchors are present (`need`) and superseded text is gone (`refute`), exactly like `tools/review-loop/test-skill-content.sh`. TDD here = write/extend the anchor test first (red), edit the prose to match spec 011, run the test (green), commit. The spec is the source of truth for the prose; the test pins the load-bearing phrases.

**Tech Stack:** Bash + `grep -E` for the content guard. No build system. `git mv` for renames. JSON edited by hand.

**Branch discipline:** This is implementation (skill behavior change) → **must run on a feature branch**, never `main`. Per the user's worktree convention, execute in a worktree on `/dev/shm` (e.g. `git worktree add /dev/shm/dong3/tsugu-011 -b feat/tsugu-handoff-converge main`). The spec already landed on `main` (009→011 renumber, commit `645af19`); this plan only touches plugin files + the test harness.

---

## File Structure

Files created or modified (from spec 011 §"Files touched"):

| File | Responsibility | Tasks |
| --- | --- | --- |
| `tools/tsugu/test-skill-content.sh` | **New.** Content-regression guard: `need`/`refute` anchors over SKILL.md + cross-file checks (prune.md exists, version, descriptions). The executable acceptance test. | 1–11 (grown task-by-task) |
| `plugins/tsugu/skills/tsugu/SKILL.md` | Frontmatter routing; `prepare` framing (A); `converge` handoff accept (B) + maintenance (C); curation + boundary (D); `prune` routine (E); remove housekeeping block; rename-invariant supersession; submodule converge → handoff | 1–6 |
| `plugins/tsugu/commands/prune.md` | **New.** `/tsugu:prune` command file (invokes the skill's prune routine) | 7 |
| `plugins/tsugu/commands/converge.md` | Description: handoff-only; complete only on human-marked maintenance; points to `prune` | 7 |
| `plugins/tsugu/skills/tsugu/references/git-recipes.md` | Remove default accept recipe + exclude clean-cut + `## Completion tail` step; retain+re-scope rebase/verify recipe to maintenance; add handoff-rename + prune-sweep recipes; state local+remote accepted enumeration; sweep completion-tail cross-refs; keep Freshness + Cleanup-order | 8 |
| `plugins/tsugu/skills/tsugu/references/advanced.md` | Reduce "Bare-submodule two-repo landing" to handoff | 9 |
| `plugins/tsugu/skills/tsugu/references/notes-and-packet.md` | Curation discipline (write-gate, promote-as-move, the line) + knowledge↔agent-md boundary | 10 |
| `.claude-plugin/marketplace.json` | Bump tsugu `0.5.0 → 0.6.0`; description: four routines | 11 |
| `plugins/tsugu/.claude-plugin/plugin.json` | Description: four routines; converge = handoff | 11 |
| `CLAUDE.md` (project root) | tsugu summary: three routines → four; converge = handoff | 12 |

Each task edits a focused file set and is committed independently. The SKILL.md changes (Tasks 1–6) are sequenced by spec change-letter so each commit is one coherent behavior shift.

---

## Task 1: Test harness scaffold + frontmatter & rename-invariant supersession

**Files:**
- Create: `tools/tsugu/test-skill-content.sh`
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (frontmatter `description`; `## The spine` / slug section)

- [ ] **Step 1: Write the failing test (create the harness)**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/../.."
SKILL="$ROOT/plugins/tsugu/skills/tsugu/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

need()   { grep -Eq "$1" "$SKILL" || fail "SKILL.md missing: $2"; pass "$2"; }
refute() { ! grep -Eq "$1" "$SKILL" || fail "SKILL.md still contains (should be gone): $2"; pass "no longer present: $2"; }
need_in()   { grep -Eq "$2" "$ROOT/$1" || fail "$1 missing: $3"; pass "$3"; }
need_file() { [ -f "$ROOT/$1" ] || fail "missing file: $1"; pass "file exists: $1"; }

# --- Task 1: frontmatter routing + rename-invariant supersession ---
need 'tsugu:prune'                          "frontmatter/routing names prune"
need 'never renames the slug'               "rename invariant narrowed to slug"

echo "All tsugu SKILL.md content checks passed."
```

- [ ] **Step 2: Make it executable and run it — verify it fails**

Run: `chmod +x tools/tsugu/test-skill-content.sh && tools/tsugu/test-skill-content.sh`
Expected: `FAIL: SKILL.md missing: frontmatter/routing names prune` (the SKILL.md edits aren't made yet).

- [ ] **Step 3: Edit SKILL.md — frontmatter + rename-invariant note**

Per spec 011 §"Relationship" and the four-routine routing:
- In the YAML frontmatter `description:`, change the routine list from `init/prepare/converge` to include prune — i.e. the lifecycle is `/tsugu:init`, `/tsugu:prepare`, `/tsugu:converge`, `/tsugu:prune`. The string MUST contain `tsugu:prune`.
- In the slug / spine section (where 004–008 state "Tsugu never renames a branch"), add the supersession: identity is the **slug**; handoff renames only the **prefix** (`prepare/<slug>` → `<accepted-prefix>/<slug>`), preserving the slug. The prose MUST contain the phrase `never renames the slug`.

- [ ] **Step 4: Run the test — verify it passes**

Run: `tools/tsugu/test-skill-content.sh`
Expected: both Task-1 lines `PASS`, ending `All tsugu SKILL.md content checks passed.`

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "test(tsugu): content guard + feat(tsugu): four-routine frontmatter + slug-rename supersession (spec 011)"
```

---

## Task 2: SKILL.md — `prepare` gathers, doesn't finalize (Change A)

**Files:**
- Modify: `tools/tsugu/test-skill-content.sh` (add Task-2 anchors)
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (`### prepare (human absent)` section)

- [ ] **Step 1: Add failing anchors**

Append before the final `echo` in `test-skill-content.sh`:

```bash
# --- Task 2: prepare intent (Change A) ---
need 'gather understanding'                 "prepare framed as gather, not finalize"
need 'scope-only'                           "scope-only branch is first-class"
need 'proof-of-feasibility'                 "reference code optional/partial"
need 'decision-free'                        "decision-free vs needs-the-human split"
```

- [ ] **Step 2: Run — verify it fails**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: SKILL.md missing: prepare framed as gather, not finalize`.

- [ ] **Step 3: Edit SKILL.md `prepare` section**

Rewrite the `prepare` intro to match spec 011 §"Change A". It MUST:
- Foreground investigation / root cause / option space / trade-offs / open questions / **decision-free vs needs-the-human** above producing finished code (include the literal `decision-free`).
- State reference code is optional/partial — "proof-of-feasibility and a starting point" (include `proof-of-feasibility`).
- Make a **scope-only** branch (`context.md`, no product/codebase changes) a first-class outcome (include `scope-only` and `gather understanding`).
- Keep the existing partition/push/submodule mechanics unchanged (spec 011 §"Out of scope for 011").

- [ ] **Step 4: Run — verify it passes**

Run: `tools/tsugu/test-skill-content.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "feat(tsugu): prepare gathers understanding, does not finalize (spec 011 Change A)"
```

---

## Task 3: SKILL.md — `converge` accept = handoff-only (Change B) + remove housekeeping

**Files:**
- Modify: `tools/tsugu/test-skill-content.sh` (Task-3 anchors)
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (`### converge` step 4 accept; remove the dedicated housekeeping block)

- [ ] **Step 1: Add failing anchors (need + refute)**

```bash
# --- Task 3: converge accept = handoff (Change B) ---
need 'git branch -m prepare/'               "handoff rename command"
need 'move, not (a )?copy'                  "handoff is a move not a copy"
need 'prints these'                         "B3 remote reconcile is print-only"
need '/tsugu:prune'                         "B4 prune reminder in converge"
need 'handoff-pending window|two-fact partition'  "B1a window guarded by partition"
# superseded default-accept recipe must be gone as the DEFAULT path:
refute 'freshness-rebase onto the fetched default → verify .*→ rewrite'  "old default completion-tail accept"
refute '## .*[Hh]ousekeeping'               "dedicated housekeeping block removed"
```

- [ ] **Step 2: Run — verify it fails**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: SKILL.md missing: handoff rename command`.

- [ ] **Step 3: Edit SKILL.md `converge` accept**

Replace the `converge` accept (the old include/exclude full-tail) with the handoff per spec 011 §"Change B" (B1, B1a, B2, B3, B4, B5):
- B1: `git branch -m prepare/<slug> <accepted-prefix>/<slug>` (move, not copy; slug preserved); cold-start variant `git branch <accepted-prefix>/<slug> <remote>/prepare/<slug>`; collision check before rename. Agent does NOT rebase/verify/rewrite/push/PR.
- B1a: the handoff-pending window is guarded by the **existing two-fact partition** (containment, then slug-pairing across local+remote accepted refs) — no new marker; residual (history-rewrite + deleted accepted) scoped to the 004–008 guarantee level (conservative prepare judgment + prune confirm).
- B2: mode-agnostic; exclude by-path clean-cut removed; `.tsugu/` rides the accepted branch; exclude narrowing stated.
- B3: remote reconcile is print-only (`git push --set-upstream …`, `git push --delete prepare/<slug>`); agent does not run them.
- B4: prune reminder (no current-count claim).
- B5: settlement/slug-pairing tracking dropped; the old "Completion tail" step dissolved → promotion to curation (D), cleanup to prune (E).
- **Remove** the dedicated converge `housekeeping` section; staleness becomes a flag on the normal candidate list (spec 011 §E4).

- [ ] **Step 4: Run — verify it passes**

Run: `tools/tsugu/test-skill-content.sh`
Expected: all PASS (including the two `refute` lines).

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "feat(tsugu): converge accept defaults to handoff-only rename; drop housekeeping block (spec 011 Change B)"
```

---

## Task 4: SKILL.md — maintenance exception (Change C)

**Files:**
- Modify: `tools/tsugu/test-skill-content.sh` (Task-4 anchors)
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (`### converge` — maintenance exception)

- [ ] **Step 1: Add failing anchors**

```bash
# --- Task 4: maintenance exception (Change C) ---
need 'human-marked maintenance'             "maintenance exception is human-marked"
need 'never self-classif'                   "agent never self-classifies maintenance"
need 'never auto-merges'                    "public-coordination boundary intact"
need 'Provenance fallback|ambiguous provenance'  "ambiguous provenance defaults to handoff"
```

- [ ] **Step 2: Run — verify it fails**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: SKILL.md missing: maintenance exception is human-marked`.

- [ ] **Step 3: Edit SKILL.md — add the maintenance exception**

Per spec 011 §"Change C": default is handoff; the **complete** path (rename first → freshness-rebase → verify → ready-to-merge) is unlocked ONLY by an explicit human marking — channel 1 (human-authored task-source designation recorded verbatim in `context.md`; agent must not synthesize from diff content; ambiguous provenance → fall back to channel 2) or channel 2 (live at converge). Still **never auto-merges**; "ready-to-merge" = accepted-branch readiness (exclude repos still strip `.tsugu/` themselves). MUST contain `human-marked maintenance`, `never self-classif`, `never auto-merges`, and a provenance-fallback phrase.

- [ ] **Step 4: Run — verify it passes**

Run: `tools/tsugu/test-skill-content.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "feat(tsugu): human-marked maintenance exception may complete; agent never self-classifies (spec 011 Change C)"
```

---

## Task 5: SKILL.md — findings curation + knowledge↔agent-md boundary (Change D)

**Files:**
- Modify: `tools/tsugu/test-skill-content.sh` (Task-5 anchors)
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (the `promote` / curation prose in `converge`)

- [ ] **Step 1: Add failing anchors**

```bash
# --- Task 5: curation + knowledge<->agent-md boundary (Change D) ---
need 'curat'                                "findings curation present"
need 'CLAUDE\.md|AGENTS\.md|agent md'       "curation targets the agent md"
need 'one place|exactly one place'          "a finding lives in exactly one place"
need 'promote = move|promote-as-move|move, not copy' "promote is move not copy"
```

- [ ] **Step 2: Run — verify it fails**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: SKILL.md missing: findings curation present` (if `curat` is genuinely absent — note the existing `promote` prose may already match; if so this anchor passes early and you still add the boundary prose in Step 3).

- [ ] **Step 3: Edit SKILL.md — curation as orthogonal item + boundary**

Per spec 011 §"Change D": strengthen the orthogonal `promote` into a curation checklist item — surface this work's findings + existing `knowledge/` entries, ask which to organise into the agent md (`CLAUDE.md`/`AGENTS.md`), agent drafts, human approves. State the **knowledge/ ↔ agent-md boundary**: `knowledge/` = WIP/evolving/cross-cutting; agent md = durable human-endorsed conventions; promote is one-way (knowledge → agent md), write-gate on entry, promote-as-move on graduation, so a finding lives in **exactly one place**. MUST contain `one place` (or `exactly one place`) and a move-not-copy phrase.

- [ ] **Step 4: Run — verify it passes**

Run: `tools/tsugu/test-skill-content.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "feat(tsugu): findings curation as orthogonal converge item + knowledge/agent-md boundary (spec 011 Change D)"
```

---

## Task 6: SKILL.md — add `prune` routine (Change E) + submodule converge handoff

**Files:**
- Modify: `tools/tsugu/test-skill-content.sh` (Task-6 anchors)
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (`## Routing`; new `### prune` routine; submodule converge prose)

- [ ] **Step 1: Add failing anchors**

```bash
# --- Task 6: prune routine (Change E) + submodule handoff ---
need '### .*prune|`prune`'                  "prune routine section"
need 'human-present'                        "prune is human-present"
need 'read-only until'                      "prune read-only until confirmation"
need 'possibly-landed'                      "prune possibly-landed bucket"
need 'never deletes .*in-progress|stale in-progress' "prune never deletes unfinished work"
need 'renamed to a human work branch'       "submodule converge = handoff rename"
need 'meta repo no longer manages'          "meta no longer manages submodule handoff"
```

- [ ] **Step 2: Run — verify it fails**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: SKILL.md missing: prune routine section`.

- [ ] **Step 3: Edit SKILL.md — routing + prune routine + submodule**

- In `## Routing`, list `prune` as the fourth routine.
- Add a `### prune` routine section per spec 011 §"Change E" (E1–E4): human-present, read-only until per-item confirm; deletes only **settled** + **leftover-worktree** on confirm; **possibly-landed / dropped / orphaned-accepted** surface-and-confirm; **stale in-progress** surfaced read-only → points to converge, never deleted; remote deletes run after per-item confirm (unify rule "no remote delete without explicit human approval"; B3 prints-only).
- Update the submodule converge prose (spec 011 §"Submodule consequence"): bare-submodule accept → handoff (rename to a human work branch in the submodule, **meta repo no longer manages it**); the paired meta branch is classified by the existing meta partition, no new marker.

- [ ] **Step 4: Run — verify it passes**

Run: `tools/tsugu/test-skill-content.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "feat(tsugu): add prune routine; submodule converge becomes handoff (spec 011 Change E + submodule)"
```

---

## Task 7: New `commands/prune.md` + update `commands/converge.md`

**Files:**
- Create: `plugins/tsugu/commands/prune.md`
- Modify: `plugins/tsugu/commands/converge.md`
- Modify: `tools/tsugu/test-skill-content.sh` (Task-7 cross-file anchors)

- [ ] **Step 1: Add failing anchors**

```bash
# --- Task 7: command files ---
need_file 'plugins/tsugu/commands/prune.md'                                  "prune command file"
need_in 'plugins/tsugu/commands/prune.md' 'prune'                            "prune command invokes prune routine"
need_in 'plugins/tsugu/commands/prune.md' 'read-only|human-present|approve'  "prune command states the invariants"
need_in 'plugins/tsugu/commands/converge.md' 'handoff'                       "converge command says handoff"
need_in 'plugins/tsugu/commands/converge.md' 'prune'                         "converge command points to prune"
```

- [ ] **Step 2: Run — verify it fails**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: missing file: plugins/tsugu/commands/prune.md`.

- [ ] **Step 3: Create `commands/prune.md`**

Model on `commands/converge.md` (frontmatter `description:` + `argument-hint`, body invokes the skill's prune routine). Content:

```markdown
---
description: Human-present, read-only-until-approved sweep of unused local + remote branches — deletes settled/leftover-worktree on confirm; surfaces dropped/possibly-landed/orphaned-accepted to confirm; never touches unfinished work. Never deletes without explicit per-item approval
argument-hint: ""
---

# /tsugu:prune

Invoke the `tsugu` skill and run the **prune** routine. A queue-wide cleanup pass
for unused branches (local + remote).

Load-bearing invariants the skill enforces: read-only until per-item human
confirmation (running it just to look is fine); deletes only **settled** (tip
contained in default) and **leftover worktrees** directly on confirm; surfaces
**dropped / possibly-landed (no containment) / orphaned-accepted** for explicit
confirmation; **stale in-progress** is surfaced read-only and pointed at
`converge`, never deleted here; **remote deletes run only after explicit per-item
approval** (no remote delete without human approval).
```

- [ ] **Step 4: Edit `commands/converge.md` description**

Update its `description:` and body to reflect handoff-only accept, the human-marked maintenance exception, and that cleanup is pointed at `prune`. MUST contain `handoff` and `prune`.

- [ ] **Step 5: Run — verify it passes**

Run: `tools/tsugu/test-skill-content.sh`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/commands/prune.md plugins/tsugu/commands/converge.md
git commit -m "feat(tsugu): add /tsugu:prune command; converge command -> handoff + prune pointer (spec 011)"
```

---

## Task 8: `references/git-recipes.md` — remove the old accept tail, add handoff + prune recipes

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/git-recipes.md`
- Modify: `tools/tsugu/test-skill-content.sh` (Task-8 cross-file anchors)

- [ ] **Step 1: Add failing anchors**

```bash
# --- Task 8: git-recipes ---
GR='plugins/tsugu/skills/tsugu/references/git-recipes.md'
need_in "$GR" 'git branch -m prepare/'           "handoff rename recipe"
need_in "$GR" 'prune'                             "prune sweep recipe"
need_in "$GR" 'local \+ remote|local and remote'  "accepted enumerated across local+remote"
# old completion-tail step gone as a standalone heading:
grep -Eq '^## Completion tail' "$ROOT/$GR" && fail "git-recipes still has '## Completion tail' heading" || pass "completion-tail heading removed"
```

(Add `GR=...` once; the `grep` line is inline because `refute` is SKILL-scoped.)

- [ ] **Step 2: Run — verify it fails**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: plugins/.../git-recipes.md missing: handoff rename recipe`.

- [ ] **Step 3: Edit `git-recipes.md`**

Per spec 011 §"Files touched" git-recipes row:
- **Remove** the default accept recipe ("Hand off for merge (include mode)"), the exclude-mode "Cut a clean public branch" by-path clean-cut, and the `## Completion tail` section.
- **Retain + re-scope** the freshness-rebase / verify / ready-to-merge recipe under a heading scoped to the **maintenance complete path**, with its unlock condition (human-marked) stated.
- **Add** a cold-start-safe **handoff rename** recipe (`git branch -m` and the remote-tracking create variant + collision check) and a **prune sweep** recipe (containment + slug-pairing reads; the delete-on-confirm vs surface-and-confirm categories; remote delete after per-item confirm).
- **State** that the partition enumerates accepted-prefix branches across **local + remote** refs (B1a fact 2).
- **Sweep** the dangling completion-tail cross-references (the `[Completion tail](#completion-tail)` link near the top and the partition-table "completion-tail / cleanup candidate" cell) to point at `prune` instead.
- **Keep** the `prepare`-side Freshness and Cleanup-order sections.

- [ ] **Step 4: Run — verify it passes**

Run: `tools/tsugu/test-skill-content.sh`
Expected: all PASS.

- [ ] **Step 5: Verify no other reference still links the removed anchor**

Run: `grep -rn 'completion-tail\|Completion tail' plugins/tsugu/`
Expected: only intentional mentions remain (e.g. "the old completion tail is now in prune"); no live cross-reference to a deleted heading. Fix any stragglers, then re-run the test.

- [ ] **Step 6: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/references/git-recipes.md
git commit -m "docs(tsugu): git-recipes — handoff rename + prune sweep; remove default accept tail (spec 011)"
```

---

## Task 9: `references/advanced.md` — bare-submodule landing → handoff

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/advanced.md`
- Modify: `tools/tsugu/test-skill-content.sh` (Task-9 anchor)

- [ ] **Step 1: Add failing anchor**

```bash
# --- Task 9: advanced.md submodule handoff ---
need_in 'plugins/tsugu/skills/tsugu/references/advanced.md' 'hand off|handoff' "bare-submodule landing reduced to handoff"
```

- [ ] **Step 2: Run — verify it fails (or passes if already present)**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL` if the word isn't there yet; otherwise proceed to make the substantive edit in Step 3 regardless.

- [ ] **Step 3: Edit `advanced.md`**

Reduce the "Bare-submodule two-repo landing" section to a handoff statement per spec 011 §"Submodule consequence": the agent does not run the ordered two-repo transaction; it renames the submodule's `prepare/<slug>` to a human work branch and stops; the cross-repo landing (gitlink bump, both PRs) is the human's. Keep the maintenance-exception note.

- [ ] **Step 4: Run — verify it passes**

Run: `tools/tsugu/test-skill-content.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/references/advanced.md
git commit -m "docs(tsugu): advanced — bare-submodule landing reduced to handoff (spec 011)"
```

---

## Task 10: `references/notes-and-packet.md` — curation discipline + boundary

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/notes-and-packet.md`
- Modify: `tools/tsugu/test-skill-content.sh` (Task-10 anchors)

- [ ] **Step 1: Add failing anchors**

```bash
# --- Task 10: notes-and-packet curation discipline ---
NP='plugins/tsugu/skills/tsugu/references/notes-and-packet.md'
need_in "$NP" 'write-gate|do not record what'      "knowledge/ write-gate"
need_in "$NP" 'one place|move, not copy|promote-as-move' "promote-as-move / one place"
```

- [ ] **Step 2: Run — verify it fails**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: plugins/.../notes-and-packet.md missing: knowledge/ write-gate`.

- [ ] **Step 3: Edit `notes-and-packet.md`**

Add the `knowledge/` lean discipline per spec 011 §"Change D": write-gate (don't record what the repo/commit/agent-md already records), promote-as-move (graduate to agent md → remove from `knowledge/`), the synthesis-vs-single-commit line, and the knowledge↔agent-md one-place boundary.

- [ ] **Step 4: Run — verify it passes**

Run: `tools/tsugu/test-skill-content.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh plugins/tsugu/skills/tsugu/references/notes-and-packet.md
git commit -m "docs(tsugu): notes-and-packet — knowledge/ lean discipline + agent-md boundary (spec 011)"
```

---

## Task 11: Version bump + plugin/marketplace descriptions

**Files:**
- Modify: `.claude-plugin/marketplace.json`
- Modify: `plugins/tsugu/.claude-plugin/plugin.json`
- Modify: `tools/tsugu/test-skill-content.sh` (Task-11 cross-file anchors)

- [ ] **Step 1: Add failing anchors**

```bash
# --- Task 11: version + descriptions ---
# tsugu's marketplace entry must be at 0.6.0 (match within the tsugu block):
grep -Pzoq '"name":\s*"tsugu"[\s\S]*?"version":\s*"0\.6\.0"' "$ROOT/.claude-plugin/marketplace.json" \
  && pass "tsugu version 0.6.0" || fail "marketplace.json: tsugu not at 0.6.0"
need_in 'plugins/tsugu/.claude-plugin/plugin.json' 'prune'  "plugin.json mentions prune"
```

(If `grep -P` / `-z` is unavailable, fall back to a `jq` check: `jq -e '.plugins[]|select(.name=="tsugu")|.version=="0.6.0"' .claude-plugin/marketplace.json`.)

- [ ] **Step 2: Run — verify it fails**

Run: `tools/tsugu/test-skill-content.sh`
Expected: `FAIL: marketplace.json: tsugu not at 0.6.0`.

- [ ] **Step 3: Edit the manifests**

- `.claude-plugin/marketplace.json`: in the `tsugu` entry, bump `"version": "0.5.0"` → `"0.6.0"`, and update its `description` to name four routines (init/prepare/converge/**prune**) and converge = handoff.
- `plugins/tsugu/.claude-plugin/plugin.json`: update `description` likewise (must contain `prune`).

- [ ] **Step 4: Run — verify it passes**

Run: `tools/tsugu/test-skill-content.sh`
Expected: all PASS. Also validate JSON: `jq . .claude-plugin/marketplace.json >/dev/null && jq . plugins/tsugu/.claude-plugin/plugin.json >/dev/null` (no output = valid).

- [ ] **Step 5: Commit**

```bash
git add tools/tsugu/test-skill-content.sh .claude-plugin/marketplace.json plugins/tsugu/.claude-plugin/plugin.json
git commit -m "chore(tsugu): bump 0.5.0 -> 0.6.0; descriptions name four routines (spec 011)"
```

---

## Task 12: Project `CLAUDE.md` — tsugu summary (three routines → four)

**Files:**
- Modify: `CLAUDE.md` (project root, the **tsugu:** bullet under "Plugin Details")

- [ ] **Step 1: Locate the tsugu summary**

Run: `grep -n 'Three routines\|init.*prepare.*converge\|tsugu:' CLAUDE.md | head`
Expected: the `**tsugu:**` paragraph that says "Three routines: `init` … `prepare` … `converge` …" and "Three slash commands: `/tsugu:init`, `/tsugu:prepare`, `/tsugu:converge`."

- [ ] **Step 2: Edit the tsugu summary**

Update to **four** routines / four slash commands — add `prune` (the human-approved sweep of unused local+remote branches); change the `converge` description to handoff-only accept (with the human-marked maintenance exception) instead of the full completion tail; add `/tsugu:prune` to the slash-command list and `docs/superpowers/specs/011-tsugu-handoff-converge-design.md` to the spec list.

- [ ] **Step 3: Verify**

Run: `grep -n 'prune\|/tsugu:prune\|011-tsugu' CLAUDE.md`
Expected: the new `prune` mentions and the 011 spec reference are present.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md — tsugu now four routines (add prune); converge = handoff (spec 011)"
```

---

## Task 13: Full verification + PR

**Files:** none (verification + integration)

- [ ] **Step 1: Run the tsugu content guard end-to-end**

Run: `tools/tsugu/test-skill-content.sh`
Expected: every line `PASS`, ending `All tsugu SKILL.md content checks passed.`

- [ ] **Step 2: Run the other plugins' guards to confirm no cross-plugin regression**

Run: `tools/review-loop/test-skill-content.sh && tools/old-react/test-validator.sh`
Expected: both pass (this change shouldn't touch them; a failure means an accidental edit).

- [ ] **Step 3: Sanity-grep for leftover superseded language across the tsugu plugin**

Run: `grep -rn 'completion tail\|freshness-rebase.*verify.*rewrite\|never renames a branch' plugins/tsugu/`
Expected: no live default-path completion-tail prose, and no un-narrowed "never renames a branch"; only intentional historical/explanatory mentions remain. Fix and re-run Step 1 if any slip through.

- [ ] **Step 4: Validate all touched JSON**

Run: `jq . .claude-plugin/marketplace.json >/dev/null && jq . plugins/tsugu/.claude-plugin/plugin.json >/dev/null && echo OK`
Expected: `OK`.

- [ ] **Step 5: Open the PR**

```bash
git push -u origin feat/tsugu-handoff-converge
gh pr create --title "tsugu: explore→handoff converge + findings curation + prune (spec 011)" \
  --body "Implements docs/superpowers/specs/011-tsugu-handoff-converge-design.md. Closes #48, #49.

- prepare: gather understanding, don't finalize (scope-only branches first-class)
- converge accept: handoff-only rename (default) + human-marked maintenance exception (never auto-merges)
- findings curation: orthogonal converge item + knowledge/<->agent-md boundary
- new /tsugu:prune: human-present, conservative branch sweep (local + remote)
- no schema bump (stays 4); public-branch-tsugu untouched
- content-regression guard: tools/tsugu/test-skill-content.sh

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 6: Run the review-loop on the PR**

After the PR is open, run `/review-loop <PR#>` (local Claude + Codex gate, then Copilot) per the project's review convention. Do not merge autonomously.

---

## Notes for the implementer

- **The spec is the prose source of truth.** Where a task says "edit to match spec 011 §X," open that section and lift the wording; the `need`/`refute` anchors only pin the load-bearing phrases, not the full prose.
- **Anchors are regexes** (`grep -E`). If you phrase a sentence differently than the anchor expects, either keep the anchor's literal phrase in the prose or update the anchor to match your wording — but never weaken an anchor just to make it pass; it must still assert the real requirement.
- **`refute` anchors are regression guards.** Tasks 3 and 8 assert the *old* default-accept tail and the `## Completion tail` heading are gone. If a later edit reintroduces them, the guard fails — that's intended.
- **Commit per task** (the repo convention: "Fix each review issue in a separate commit"). The harness grows monotonically, so each task's test run also re-checks all prior anchors — a built-in regression sweep.
