# Tsugu Submodule Recursion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Operationalize omni-repo submodule recursion in the tsugu skill — make `prepare` recurse into `.tsugu/`-bearing submodules, branch bare-submodule work in the submodule with a paired meta branch, and add `init` graduation — per spec `008-tsugu-submodule-recursion-design.md`.

**Architecture:** This is **skill/prose authoring**, not executable code. The deliverable is edits to one system prompt (`SKILL.md`), four reference documents, one manifest (`marketplace.json`), and the repo `CLAUDE.md`. There are **no unit tests** (tsugu is light / script-free — no scripts shipped). "Verification" per task is a structural grep/consistency check; the analog of a test suite is a final `review-loop` gate over the whole diff. No schema bump — the skill stays `tsugu-schema: 4`; recursion reads `.tsugu/policy.md` presence at runtime.

**Tech Stack:** Markdown (SKILL.md + references), JSON (marketplace.json). Git for branch/worktree/commit. `review-loop` skill for the final gate.

**Source of truth:** `docs/superpowers/specs/008-tsugu-submodule-recursion-design.md` (already on `main`). Each task below transcribes a specific spec section into operational SKILL/reference voice. When this plan and the spec disagree, the spec wins — re-read the relevant spec section before editing.

---

## Scope Check

Single subsystem (the tsugu skill). One plan. The change spans several files but they form one coherent feature; no decomposition into sub-plans needed.

## Branch / worktree policy

Per the repo conventions, **implementation goes on a feature branch in a worktree** (the spec already landed on `main` as docs; SKILL.md + marketplace.json affect shipped plugin behavior → feature branch + PR). Task 1 creates it. All later tasks run **inside the worktree** (`cd` into it for every git command).

## File Structure

| File | Responsibility | Change |
| --- | --- | --- |
| `plugins/tsugu/skills/tsugu/references/policy-and-intake.md` | Shared `policy.md` field docs | Expand `## Recursion`: the `.tsugu/policy.md` gate, the case table, source-scoping anti-pattern (spec D) |
| `plugins/tsugu/skills/tsugu/references/git-recipes.md` | Git mechanics | New `## Submodule recursion (omni-repo)` section: enumeration, gate test, recurse-and-run, bare paired-branch + gitlink-bump, depth/bare-intermediate limit (spec A/B/C) |
| `plugins/tsugu/skills/tsugu/references/advanced.md` | Non-trivial landings | New `## Bare-submodule two-repo landing` section: ordered accept, conjunctive ancestry settlement, completion-tail reach-across, dispositions over the pair (spec §converge) |
| `plugins/tsugu/skills/tsugu/references/notes-and-packet.md` | Context/knowledge placement | New `## Graduation (knowledge relocation)` subsection alongside the existing context-placement rule (spec E2/E3) |
| `plugins/tsugu/skills/tsugu/SKILL.md` | The skill's behavior (system prompt) | `prepare` traversal step; `converge` bare-item note; `init` path arg + graduation; tightened `## Scheduling & recursion`; new reference pointers |
| `.claude-plugin/marketplace.json` | Plugin versions | tsugu `0.4.0 → 0.5.0` |
| `CLAUDE.md` | Repo guidance | Add spec 008 to the tsugu lineage line |

Order rationale: write the deep **reference** mechanics first (Tasks 2–5), then update **SKILL.md** to summarize and point at them (Tasks 6–9), then version + repo docs (Task 10), then the gate + PR (Task 11). SKILL.md already references these files by name, so the reference sections must exist before SKILL.md points at them.

---

### Task 1: Create the feature branch worktree

**Files:** none edited; sets up the workspace.

- [ ] **Step 1: Confirm tmpfs is available**

Run: `df --human-readable /dev/shm 2>/dev/null && echo "tmpfs present" || echo "no tmpfs"`
Expected: prints a filesystem line + `tmpfs present`.

- [ ] **Step 2: Create the worktree on tmpfs from current `main`**

```bash
git -C /home/caasi/GitHub/dong3 fetch origin main
git -C /home/caasi/GitHub/dong3 worktree add /dev/shm/dong3/tsugu-submodule-recursion -b feat/tsugu-submodule-recursion origin/main
```

If Step 1 printed `no tmpfs`, fall back to a normal-filesystem worktree at
`/home/caasi/GitHub/dong3/.worktrees/tsugu-submodule-recursion` (deprecated but
acceptable) and use **that** path everywhere `/dev/shm/dong3/...` appears below.

- [ ] **Step 3: Verify the worktree is on the new branch at spec HEAD**

Run: `git -C /dev/shm/dong3/tsugu-submodule-recursion log --oneline -1 && git -C /dev/shm/dong3/tsugu-submodule-recursion branch --show-current`
Expected: HEAD is `7625420 docs(tsugu): spec 008 …` (or later); branch is `feat/tsugu-submodule-recursion`.

> For every later task, `cd /dev/shm/dong3/tsugu-submodule-recursion` (or use `git -C <that path>`) so commits land on the feature branch, not the main checkout.

---

### Task 2: Expand `## Recursion` in policy-and-intake.md (gate + case table + source scoping)

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/policy-and-intake.md` (the `## Recursion` section, currently ~lines 177–181)

- [ ] **Step 1: Read the current `## Recursion` section**

Run: `sed -n '/^### `## Recursion`/,/^## Personal config/p' plugins/tsugu/skills/tsugu/references/policy-and-intake.md`
Expected: the short "Whether to recurse into submodules / child repos. Default: only when relevant…" paragraph.

- [ ] **Step 2: Replace that section body with the operationalized version**

Replace the `### \`## Recursion\`` body (keep the heading) with:

```markdown
Whether to recurse into submodules / child repos. Default: **only when relevant to
the current goal / branch** — this field is the **parent's descent toggle**: it
governs whether *this* repo descends into its children at all, keeping an omni-repo
traversal scoped instead of descending into every nested repo unconditionally.

**The ownership signal is a readable `.tsugu/policy.md` in the submodule** — that
file is the human's claim "this repo owns its own prepare queue." Once the parent
descends, that boolean alone decides **recurse-vs-meta-drive** per submodule; a
submodule never separately opts out of being recursed-into, and its own policy is
not consulted to gate it. A malformed/partial `.tsugu/` without a readable
`policy.md` is **not** a valid signal — surface it, never silently treat it as
bare.

| Submodule state | Branch (code) | `.tsugu/` knowledge | Policy used | Lifecycle owner |
| --- | --- | --- | --- | --- |
| HAS `.tsugu/policy.md` | `prepare/<slug>` in the submodule | the submodule's own `.tsugu/` | the submodule's own (recurse-and-run) | the submodule (its own `converge`) |
| no `.tsugu/` | `prepare/<slug>` in the submodule (none created there) | the **meta** `.tsugu/`, via a paired meta `prepare/<slug>` | the meta `policy.md` | the meta-repo |
| meta-level code | `prepare/<slug>` in the meta-repo | the meta `.tsugu/` | the meta's | the meta-repo |

**Source scoping (the overlap anti-pattern).** Scope each repo's intake to work it
owns: a HAS-`.tsugu/` submodule runs **its own** board / JQL; the meta source
covers **meta-level work** (pin bumps, omni docs) **+ bare-submodule work** only.
Overlapping the same tracker board at the meta level double-pulls and mis-attributes
submodule tickets — the failure that motivated this design. This is **guidance
only — no central router, no defer/skip guard**.

Recursion mechanics (enumeration, the gate test, recurse-and-run, the bare paired
branch) live in `git-recipes.md` (§ Submodule recursion).
```

- [ ] **Step 3: Verify the section is well-formed and cross-references resolve**

Run: `grep -n "recurse-vs-meta-drive\|Submodule recursion\|overlap anti-pattern\|descent toggle" plugins/tsugu/skills/tsugu/references/policy-and-intake.md`
Expected: matches in the `## Recursion` area; the `git-recipes.md` pointer present.

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/policy-and-intake.md
git commit -m "docs(tsugu): policy-and-intake — operationalize ## Recursion (gate, case table, source scoping)"
```

---

### Task 3: Add `## Submodule recursion (omni-repo)` to git-recipes.md

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/git-recipes.md` (append a new top-level section at end of file)

- [ ] **Step 1: Confirm the append point**

Run: `tail -3 plugins/tsugu/skills/tsugu/references/git-recipes.md`
Expected: ends with the "Do **not** run `prepare` in that repo until the metadata PR is merged…" paragraph.

- [ ] **Step 2: Append the new section**

Append to the end of the file:

```markdown

## Submodule recursion (omni-repo)

`prepare` recurses after working the meta-repo's own queue. The branch always lands
at the lowest repo that owns the **code**; `.tsugu/` knowledge lands at the lowest
repo that **has** a `.tsugu/`.

**1 — Enumerate (initialized trees only).**

```bash
git submodule status   # a leading "-" = uninitialized: no working tree to test
```

An uninitialized submodule (leading `-`) is either initialized
(`git submodule update --init <path>`) before gating, or **skipped with a surfaced
note** — never silently treated as bare (it may carry `.tsugu/` once checked out).

**2 — Gate on a readable `.tsugu/policy.md` (three outcomes, not two).**

```bash
if   test -r "<sub>/.tsugu/policy.md"; then echo HAS      # managed: recurse-and-run (step 3)
elif test -e "<sub>/.tsugu";          then echo INVALID   # .tsugu/ exists but no readable policy.md
else                                       echo BARE      # genuinely bare: meta-drive (step 4)
fi
```

`INVALID` (a `.tsugu/` directory without a readable `policy.md`) is **surfaced, not
driven** — never silently collapsed into `BARE`.

**3 — HAS `.tsugu/` → recurse-and-run.** Run the full `prepare` routine inside the
submodule, treating it as its own repo. It already has its own project-key (keyed on
its own git dir) → its own personal-config intake.

```bash
git -C <submodule-path> fetch --prune <remote>
# then run prepare's steps with every git command prefixed `git -C <submodule-path>`
# (optionally dispatch a built-in Task subagent per submodule)
```

The submodule runs at its **own** schema (do **not** force-migrate a schema-3
submodule). Its own `policy.md`, `context.md` scope, default branch, and push rules
apply; its own queue read **continues an existing `prepare/<slug>` rather than
duplicating** it, and its `context.md` scope boundaries are respected emergently
(no central router). Reads its sources only if that submodule's personal config was bootstrapped
on **this** machine (interactive-only); else it degrades to git-native and surfaces
"personal config unconfigured" at the submodule's next same-machine `converge`.

**4 — no `.tsugu/` → meta-drives with a paired meta branch.** The branch still lands
in the submodule (easy handoff), but **meta** `policy.md` governs every tsugu rule
for it. **Resolve the base and rules BEFORE creating any branch** (ask-don't-guess —
never branch on a guess):

```bash
git -C <sub> fetch --prune <remote>
default=$(git -C <sub> symbolic-ref --quiet refs/remotes/<remote>/HEAD | sed 's#.*/##')
# Ambiguous (no .../HEAD, multiple remotes) OR a rule not covered by meta policy?
#   interactive -> ASK the human
#   headless    -> DO NOT branch: leave the item unbranched, surface it at next converge
# Only once base + rules are resolved:
git -C <sub> switch -c prepare/<slug> "<remote>/$default"
# … reproduce / test / patch / commit inside the submodule …
```

**No clear owner.** When a meta-source ticket maps to no obvious submodule, do **not**
guess one: if it's genuinely meta-level work open a meta `prepare/<slug>`; otherwise
**defer to `converge`** (create no branch). At `converge` the human assigns an owner
and it reclassifies — recurse-and-run target (HAS `.tsugu/`), a bare pair, or meta
work. A deferred item carries no committed state; it resurfaces by re-reading
external intake (the schema-3 weakened-dedup tradeoff), no ledger.

Then carry the findings on a **paired meta branch** (same slug):

```bash
# in the meta-repo working tree
git switch -c prepare/<slug>
git add <sub>                       # stage the gitlink bump to the prepared submodule tip
# write .tsugu/context.md narrating the work + the submodule branch name + SHA
git add .tsugu/context.md
git commit -m "prepare(<slug>): submodule work in <sub> @ <sha> (paired)"
```

Handoff: checking out the meta `prepare/<slug>` + `git submodule update` lands the
submodule at the prepared commit as **detached HEAD** at the recorded SHA (not on
`prepare/<slug>` — the human runs `git -C <sub> checkout prepare/<slug>` to resume).

**5 — Depth.** Traverse **depth-first**. Arbitrary depth holds for **managed** chains
(each level has its own `.tsugu/`). A **bare** level is driven **only one level deep** — a direct bare child
may be meta-driven, but anything nested beneath a bare child is **surfaced, not
driven** (it would become an N-repo gitlink-chain transaction). Note it and leave it
for the human to restructure (e.g. `init` an intervening level).

Push each branch where its repo's policy permits. The ordered two-repo **landing**
(at `converge`) lives in `advanced.md` (§ Bare-submodule two-repo landing).
```

- [ ] **Step 3: Verify**

Run: `grep -n "^## Submodule recursion\|recurse-and-run\|paired meta branch\|only one level deep" plugins/tsugu/skills/tsugu/references/git-recipes.md`
Expected: the new heading + the four anchors present.

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/git-recipes.md
git commit -m "docs(tsugu): git-recipes — add submodule recursion section (enumerate/gate/recurse/paired branch)"
```

---

### Task 4: Add the bare-submodule two-repo landing to advanced.md

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/advanced.md` (append a new top-level section at end of file)

- [ ] **Step 1: Confirm the append point**

Run: `tail -3 plugins/tsugu/skills/tsugu/references/advanced.md`
Expected: ends with the "…follows the work item's slug rather than standing on its own." paragraph.

- [ ] **Step 2: Append the new section**

Append to the end of the file:

```markdown

## Bare-submodule two-repo landing

When a bare submodule's work converges, accept is an **ordered, two-repo
transaction** (not two independent accepts): the meta commit pins a submodule SHA,
and the landed SHA differs from the prepare-time tip (merge commit, or a fresh SHA
under squash/rebase). Human-driven throughout — tsugu never auto-merges.

1. **Land the submodule first** — merge its forge PR from an accepted-prefix branch
   named per **meta** policy's `## Accepted Prefixes` (same slug). Resolve the
   **landed** submodule SHA.
2. **Re-point, then land meta** — on the meta accepted branch (same slug), bump the
   gitlink to the submodule's **default-branch tip that now contains the landed
   work** — never the prepare-time tip and never a pre-graduation ancestor (the
   default tip also carries anything landed meanwhile, e.g. a graduation `.tsugu/`
   commit; re-pointing to an ancestor would pass reachability yet silently
   *un-graduate* the submodule). Pinning the default tip is ordinary submodule-bump
   coupling — if isolating the exact work matters, pin a specific commit that
   contains the landed work + graduation instead. Open the meta PR; **immediately
   before merging it, re-validate against
   current meta default** (a bump may have landed since) and, if needed, re-point
   onto the now-current tip first.
3. **Settlement is conjunctive + ancestry-based** — settled only when **all** hold:
   (a) the landed-work SHA (and graduation SHA, if any) is an **ancestor** of the
   gitlink target (mere reachability is not enough); (b) that target is reachable
   from the submodule's fetched default; (c) the landed meta commit (resolve its SHA
   if squash/rebase-merged) is reachable from meta default **and its own tree records
   that gitlink target** (read from the landed commit's tree, not the live default
   tree, so a later legitimate bump can't unsettle old work). Where a history rewrite
   makes mechanical proof impossible, confirmation **is** the human's in-session word
   (as elsewhere in this file); pending/deferred only when neither mechanical proof
   nor human confirmation is available.
4. **Completion tail reaches across** — delete the meta work + accepted branches and,
   using the name + SHA in the meta `context.md`, reach into the submodule to delete
   its `prepare/<slug>` + accepted branch (else they orphan — a bare submodule has no
   queue or tail). The tail first **initializes + fetches** the submodule
   (`git submodule update --init`, `git -C <sub> fetch`), deletes **local and
   remote** refs per the meta `## Push` policy, never deletes a checked-out branch,
   and is **idempotent** (an already-absent ref is a no-op).

Concretely, the mechanical settlement checks (all must pass):

```bash
# (a) landed-work (and graduation, if any) SHA is an ANCESTOR of the gitlink target
git -C <sub> merge-base --is-ancestor <landed-work-sha> <gitlink-target-sha>
# (b) the gitlink target is reachable from the submodule's fetched default
git -C <sub> merge-base --is-ancestor <gitlink-target-sha> <remote>/<default>
# (c) the LANDED meta commit's own tree records that gitlink target …
git ls-tree <landed-meta-sha> <submodule-path>   # -> "160000 commit <gitlink-target-sha>\t<path>"
#     … and that landed meta commit is reachable from meta default
git merge-base --is-ancestor <landed-meta-sha> <remote>/<meta-default>
```

**The other dispositions change for a bare pair** — each spans two branches across
two repos:
- **continue** — advancing the submodule tip means refreshing the meta paired
  branch's gitlink + `context.md`, or the meta side goes stale.
- **park** — narrate "blocked on X" in the meta `context.md`; both branches remain.
- **drop** — record *why* in the meta `context.md`, then delete **both** refs (meta
  paired branch + submodule `prepare/<slug>` via `git -C <sub>`).
- **promote** — orthogonal; durable findings rise into the meta `knowledge/`.

**Out of scope:** nested bare chains (a bare submodule inside a bare submodule) would
require a gitlink-bump chain through every intermediate — surface such a subtree for
the human to restructure, don't drive it.
```

- [ ] **Step 3: Verify**

Run: `grep -n "^## Bare-submodule two-repo landing\|conjunctive\|reaches across\|un-graduate" plugins/tsugu/skills/tsugu/references/advanced.md`
Expected: the new heading + anchors present.

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/advanced.md
git commit -m "docs(tsugu): advanced — ordered bare-submodule two-repo landing (settlement + cleanup + dispositions)"
```

---

### Task 5: Add graduation (knowledge relocation) to notes-and-packet.md

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/references/notes-and-packet.md` (append after the existing "Context placement rule (omni-repo framing)" section, at end of file)

- [ ] **Step 1: Confirm the append point**

Run: `tail -3 plugins/tsugu/skills/tsugu/references/notes-and-packet.md`
Expected: ends with "…promotion is a deliberate "this is true more broadly now" decision, not the default."

- [ ] **Step 2: Append the new subsection**

Append to the end of the file:

```markdown

## Graduation (knowledge relocation)

When a bare submodule the omni-repo was managing gets its own `.tsugu/`, the
submodule-specific knowledge moves **down** out of the omni `.tsugu/` — the
deliberate inverse of "promote upward." `init` detects the enclosing omni-repo
(`git rev-parse --show-superproject-working-tree` → check that superproject for
`.tsugu/`), scans the omni `knowledge/` for entries naming this submodule,
**presents them**, and on **per-entry human confirmation** cuts them down into the
new submodule `knowledge/` (move content, remove from meta) — leaving the omni level
holding only genuinely cross-cutting knowledge.

**Graduation is a repo mutation, not a relabel.** Creating the submodule's
`.tsugu/policy.md` is a new submodule commit; removing the omni entries is a meta
commit; **the omni gitlink must be bumped** to the submodule commit carrying the new
`.tsugu/` — else a fresh checkout stays pinned to a pre-`.tsugu/` SHA, re-classifies
the submodule as bare, and operationally **reverses** graduation. `init` makes these
as ordinary commits per repo (submodule first, then the meta gitlink bump + knowledge
removal) and is **re-entrant** (interrupted midway, re-running re-detects remaining
omni entries). No atomic cross-repo transaction is claimed; the human drives any PR.

**In-flight paired branches are left alone** — they finish at meta `converge`; only
new post-graduation work goes native-in-submodule. One guard: when such an in-flight
pair later accepts, its meta gitlink-bump must target the **current submodule default
tip** (which contains both the accepted work and the graduation commit), never a bare
ancestor — the same re-point rule as the two-repo accept, applied across the
graduation boundary.
```

- [ ] **Step 3: Verify**

Run: `grep -n "^## Graduation\|gitlink must be bumped\|re-entrant\|left alone" plugins/tsugu/skills/tsugu/references/notes-and-packet.md`
Expected: the new heading + anchors present.

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/references/notes-and-packet.md
git commit -m "docs(tsugu): notes-and-packet — graduation (knowledge relocation, gitlink bump, re-entrant)"
```

---

### Task 6: SKILL.md — add the `prepare` recursion step

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (the `### \`prepare\` (human absent)` numbered list, currently ends at step 8 "Commit the work branch…")

- [ ] **Step 1: Read the end of the prepare routine**

Run: `grep -n "Commit the work branch" plugins/tsugu/skills/tsugu/SKILL.md`
Expected: locates step 8 of the prepare list.

- [ ] **Step 2: Add a new step 9 after step 8**

Immediately after the step 8 paragraph ("**Commit the work branch … never push past an explicit boundary.**"), insert:

```markdown
9. **Recurse into submodules (omni-repo).** After working this repo's own queue,
   enumerate submodules and gate each on a **readable `.tsugu/policy.md`**. For a
   **HAS-`.tsugu/`** submodule whose descent the **parent's own `## Recursion`**
   permits, **recurse-and-run** — run this whole `prepare` routine inside it
   (`git -C <submodule>`) using the submodule's own policy + personal-config intake;
   it runs at its own schema (never force-migrated). For a **bare** submodule, the
   branch still lands **in the submodule** but **meta** policy governs it and the
   findings ride a **paired meta `prepare/<slug>`** (gitlink bump + `context.md`).
   The branch always lands at the lowest repo owning the **code**; `.tsugu/`
   knowledge lands at the lowest repo that **has** a `.tsugu/`. **Ask, don't guess:**
   when a bare submodule's default branch is ambiguous or a rule isn't covered by
   meta policy, ask the human if interactive, else leave the item unbranched for the
   next `converge`. Mechanics → `references/git-recipes.md` (§ Submodule recursion).
```

- [ ] **Step 3: Verify the step is present and numbered**

Run: `grep -n "Recurse into submodules (omni-repo)\|Submodule recursion" plugins/tsugu/skills/tsugu/SKILL.md`
Expected: the new step 9 + the git-recipes pointer.

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "docs(tsugu): SKILL prepare — add submodule recursion step (recurse-and-run / bare paired branch)"
```

---

### Task 7: SKILL.md — add the `converge` bare-item note

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (the `### \`converge\` (human present)` section, step 4 "Decide *with* the human")

- [ ] **Step 1: Locate the converge accept dispositions**

Run: `grep -n "Accepted (\`exclude\` mode)\|Completion tail" plugins/tsugu/skills/tsugu/SKILL.md`
Expected: the accept-mode bullets in converge step 4.

- [ ] **Step 2: Add a bare-submodule accept bullet**

Immediately after the "**Accepted (`exclude` mode):** …" bullet (before the "**Completion tail**" bullet), insert:

```markdown
   - **Accepted (bare-submodule paired branch):** an **ordered two-repo
     transaction** — land the submodule PR first, re-point the meta gitlink to the
     submodule **default tip that now contains the landed work** (never a
     pre-graduation ancestor), then land the meta PR; settlement is **conjunctive +
     ancestry-based** and the completion tail **reaches across** (`git -C <sub>`) to
     clean the submodule branches. Full procedure → `references/advanced.md`
     (§ Bare-submodule two-repo landing). drop / park / continue each act on **both**
     branches of the pair. Note: meta `converge` does **not** aggregate
     HAS-`.tsugu/` submodules' own queues — converge those by running
     `/tsugu:converge` inside each submodule.
```

- [ ] **Step 3: Verify**

Run: `grep -n "Accepted (bare-submodule paired branch)\|Bare-submodule two-repo landing" plugins/tsugu/skills/tsugu/SKILL.md`
Expected: the new bullet + the advanced.md pointer.

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "docs(tsugu): SKILL converge — bare-submodule paired-branch two-repo landing note"
```

---

### Task 8: SKILL.md — `init` path argument + graduation

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (the `### \`init\`` section)

- [ ] **Step 1: Locate the init section opening**

Run: `grep -n "^### \`init\`" plugins/tsugu/skills/tsugu/SKILL.md`
Expected: the init routine heading (~line 68).

- [ ] **Step 2: Add a paragraph after the init opening paragraph**

Immediately after the first paragraph of `### \`init\`` ("Runs when a repo has no `.tsugu/`… recurse into submodules (default: only when relevant)?"), insert:

```markdown
**`/tsugu:init [<submodule-path>]` + graduation.** With a `<submodule-path>` argument
`init` targets that submodule directly (skips the "which repo / confirm target"
question). When run on a submodule under a tsugu-managed omni-repo (detected via
`git rev-parse --show-superproject-working-tree`), it **graduates** the submodule:
it scans the omni `knowledge/` for entries naming this submodule, presents them, and
on per-entry human confirmation **cuts** them down into the new submodule
`knowledge/` (knowledge only). The omni gitlink **must** be bumped to the new
`.tsugu/` commit (else a fresh checkout re-classifies the submodule as bare).
In-flight paired meta branches are left to finish at meta `converge`. Mechanics →
`references/notes-and-packet.md` (§ Graduation).
```

- [ ] **Step 3: Verify**

Run: `grep -n "tsugu:init \[<submodule-path>\]\|graduates the submodule\|§ Graduation" plugins/tsugu/skills/tsugu/SKILL.md`
Expected: the new paragraph + the notes-and-packet pointer.

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "docs(tsugu): SKILL init — path argument + knowledge-only graduation"
```

---

### Task 9: SKILL.md — tighten `## Scheduling & recursion` + update the mechanics pointer list

**Files:**
- Modify: `plugins/tsugu/skills/tsugu/SKILL.md` (the `## Scheduling & recursion` Recursion paragraph ~line 183, and the "Mechanics are deferred" pointer list ~lines 58–64)

- [ ] **Step 1: Replace the Recursion paragraph**

Replace the `**Recursion (omni-repo).** …` paragraph (the last paragraph of `## Scheduling & recursion`) with:

```markdown
**Recursion (omni-repo).** A single repo and an omni-repo are the **same
abstraction**. After working its own queue, `prepare` enumerates submodules and gates
each on a **readable `.tsugu/policy.md`**: a HAS-`.tsugu/` submodule **recurse-and-runs**
(its own policy + intake, its own schema); a bare submodule is **meta-driven** with
the branch in the submodule and findings on a **paired meta branch** (gitlink bump +
`context.md`). The branch always lands at the lowest repo owning the **code**;
`.tsugu/` knowledge at the lowest repo that **has** a `.tsugu/` (else it bubbles up).
The **parent's own `## Recursion`** toggle governs whether it descends at all ("only
when relevant"); descent into a bare level goes **one level deep** (direct child
only). **Context placement rule:** write context at the **lowest repo level where it
stays true**; promote upward into `.tsugu/knowledge/` only when it spans repos.
Mechanics → `references/git-recipes.md` (§ Submodule recursion); landing →
`references/advanced.md` (§ Bare-submodule two-repo landing); graduation →
`references/notes-and-packet.md` (§ Graduation).
```

- [ ] **Step 2: Add one pointer bullet to the mechanics list**

In the "Mechanics are deferred — do not re-derive git commands here:" bullet list (~lines 58–64), append a single new bullet at the end of the list (do not edit the existing bullets):

```markdown
- Submodule recursion (enumerate + `.tsugu/policy.md` gate + recurse-and-run + bare paired branch), its two-repo landing, and graduation → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/git-recipes.md` (§ Submodule recursion), `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/advanced.md` (§ Bare-submodule two-repo landing), `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/notes-and-packet.md` (§ Graduation).
```

- [ ] **Step 3: Verify**

Run: `grep -n "recurse-and-runs\|one level deep\|§ Submodule recursion" plugins/tsugu/skills/tsugu/SKILL.md`
Expected: the rewritten Recursion paragraph + the new pointer bullet.

- [ ] **Step 4: Commit**

```bash
git add plugins/tsugu/skills/tsugu/SKILL.md
git commit -m "docs(tsugu): SKILL — tighten ## Scheduling & recursion + add reference pointers"
```

---

### Task 10: Version bump + CLAUDE.md lineage

**Files:**
- Modify: `.claude-plugin/marketplace.json` (the `tsugu` plugin object's `version`)
- Modify: `CLAUDE.md` (the `**tsugu:**` paragraph lineage)

- [ ] **Step 1: Bump the tsugu version**

In `.claude-plugin/marketplace.json`, find the object with `"name": "tsugu"` (its description ends "…never auto-merges…") and change its `"version": "0.4.0"` to `"version": "0.5.0"`. Use an Edit anchored on the tsugu description text so the *other* 0.4.0 plugin is not touched.

Run to confirm exactly one tsugu line changed: `grep -n -B6 '"version": "0.5.0"' .claude-plugin/marketplace.json | grep -E '"name": "tsugu"|0.5.0'`
Expected: shows the tsugu name above the new `0.5.0`. (The authoritative "only tsugu bumped" gate is Step 3's `grep -c … == 1`.)

- [ ] **Step 2: Update the CLAUDE.md tsugu lineage**

In `CLAUDE.md`, the `**tsugu:**` line: change `Schema 4 (lineage: 004 → 005 → 006 → 007).` to `Schema 4 (lineage: 004 → 005 → 006 → 007 → 008).` and append ` + \`docs/superpowers/specs/008-tsugu-submodule-recursion-design.md\`` to the end of the `Spec:` list at the end of that paragraph. Add a short clause to the `prepare` description noting it "recurses into `.tsugu/`-bearing submodules (omni-repo)".

- [ ] **Step 3: Verify**

Run: `grep -n "004 → 005 → 006 → 007 → 008\|008-tsugu-submodule-recursion-design" CLAUDE.md && grep -c '"version": "0.5.0"' .claude-plugin/marketplace.json`
Expected: the lineage + spec path present; exactly `1` line at `0.5.0` (only tsugu bumped).

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/marketplace.json CLAUDE.md
git commit -m "chore(tsugu): bump 0.4.0 -> 0.5.0; CLAUDE.md lineage 004->008"
```

---

### Task 11: Final consistency pass, review-loop gate, and PR

**Files:** none edited unless the gate finds issues.

- [ ] **Step 1: Cross-reference integrity check**

Run:
```bash
grep -rn "Submodule recursion\|Bare-submodule two-repo landing\|§ Graduation" plugins/tsugu/skills/tsugu/SKILL.md plugins/tsugu/skills/tsugu/references/
```
Expected: every SKILL.md pointer has a matching `## ` heading in the named reference file (git-recipes `## Submodule recursion`, advanced `## Bare-submodule two-repo landing`, notes-and-packet `## Graduation`).

- [ ] **Step 2: Spec-coverage check**

Re-read `docs/superpowers/specs/008-tsugu-submodule-recursion-design.md` "Where it lands" + "Acceptance criteria". Confirm each named edit exists in the diff:
```bash
git diff --stat origin/main...HEAD
```
Expected: changes in SKILL.md, policy-and-intake.md, git-recipes.md, advanced.md, notes-and-packet.md, marketplace.json, CLAUDE.md — and nothing else.

- [ ] **Step 3: No schema bump leaked in**

Run: `grep -rn "tsugu-schema: 5\|schema 4→5\|schema 4 -> 5" plugins/tsugu/`
Expected: **no matches** (this change is schema-4, no migration).

- [ ] **Step 4: Run the review-loop gate over the implementation diff**

Invoke the `review-loop` skill on the feature branch (local Claude + Codex gate; for a branch with no PR yet it reviews `branch vs base`). Resolve T1 inline, pause on T2/T3 for the author. This is the analog of a test suite for prose changes.

- [ ] **Step 5: Push the branch, then open the PR (after the local gate is clean)**

```bash
git push -u origin feat/tsugu-submodule-recursion
gh pr create --base main --head feat/tsugu-submodule-recursion \
  --title "feat(tsugu): submodule recursion (prepare recurses on .tsugu/ presence)" \
  --body "Implements spec 008. Closes #40."
```

Then run review-loop's Copilot phase on the PR. **Never merge autonomously** — the author decides the merge (default: merge commit, preserve history).

---

## Notes for the executor

- **Worktree discipline:** every git command runs against `/dev/shm/dong3/tsugu-submodule-recursion` (cd in, or `git -C`). Commits on the wrong checkout land on `main` — don't.
- **No tests to write first:** this is prose. The "verification" steps are grep/structural checks; the real gate is Task 11's review-loop. Keep commits small and per-file as structured above.
- **The spec is the source of truth.** If a step's prose feels thin, open the matching spec section and prefer its wording.
- **Reference voice vs design voice:** the spec explains *why*; the SKILL/references state operational *what/how*. Transcribe into imperative, present-tense guidance — don't paste the spec's rationale verbatim.
