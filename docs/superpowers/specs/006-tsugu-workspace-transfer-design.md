# 006 — Tsugu v2: the workspace holds only what transfers (schema 3)

## Relationship to 004 / 005

This spec **supersedes parts of** `005-tsugu-agent-first-design.md` (which itself
extended `004-tsugu-skill-design.md`). 004 and 005 remain as **historical
lineage** — the git-native intake idea, the convergence packet, derived state,
the no-skill-orchestration rule, the no-force principle, and the multi-agent
reservations all stand. 006 is a **radical simplification** of the `.tsugu/`
workspace and the skill, captured by dogfooding after v1.1 (PR #35) and recorded
in issue #36.

The new schema is **`tsugu-schema: 3`**, with a documented 2→3 migration. A
schema-1 repo migrates 1→2→3 under the existing N→N+1 contract.

| Line | Change | What it supersedes in 005 |
| --- | --- | --- |
| A | The storage-location split: committed `.tsugu/` holds only what transfers to *any* inheritor; everything tied to one human's session/sources/rhythm moves to a **personal global folder** | §B's `## Intake Sources` policy block and the `intake/<slug>.md` note form; §C6's `packets/`/`runs/` durable-memory rationale |
| B | Committed `.tsugu/` collapses to **`policy.md` + `context.md` + `knowledge/`**; `intake/`, `runs/`, repo-seeded `templates/`, and `packets/` are removed or relocated | §C2's `runs/`/`packets/` links and load-via-active-branch archive semantics; §C3's `knowledge/` promotion gate; §D's repo template-seeding |
| C | **No intake notes.** Work-entry is a `prepare/<slug>` branch directly; the entire intake-note lifecycle (`open→claimed→done\|dropped`, `linked-branch:`, `landed:`, note-based reconciliation) is gone. State is single-layer (branches only) | §C4's `landed:`/reconciliation rules and the intake-note two-layer lifecycle; §B's dedup-by-note |
| D | `converge` reads tsugu branches **live**; the packet is a **personal/derived** decision-view regenerated per human/machine, never a pushed artifact | §C1's pushed-packet presentation and the completion tail's intake-flip step |
| E | `public-branch-tsugu` is **redefined** (not dropped): it governs whether the committed **WIP-knowledge layer** (`context.md` + prep DAG) lands on the public/default branch | §C6's durable-memory rationale resting on `packets/`/`runs/` |
| F | The skill **shrinks substantially** to match; templates live in the skill, referenced not copied | §D's repo template-seeding; the references built for the two-layer intake/landed/runs lifecycle |

Everything in 004/005 not named here is unchanged.

## The principle (the spine)

> **`.tsugu/` (committed, pushed) holds only what transfers to *any* inheritor —
> a different human, a different machine, a different set of sources, a different
> work cadence. Anything tied to *one* human's session, sources, or rhythm is
> personal or derived, never pushed.**

**Corollary — enforce the split at the storage location, not via prompt
instructions.** The boundary is *where the file lives* (committed vs a global
personal folder), not "the agent decides what's safe to share." This is the
deeper lesson behind the v1.1 Copilot security flag on committing a `read:` shell
command: a personal observation pointer should never have been in a committed
file in the first place. It mirrors Claude Code's own `settings.json` (shared via
git) vs `settings.local.json` (personal) — except tsugu puts personal data in a
**global** folder so it never touches the repo at all (no `.gitignore` to
maintain, nothing in the working tree to commit by accident).

The boundary test is **audience/privacy**, not completeness: *"does a coworker's
agent need this to coordinate?"* → shared; *"is this my method, my tools, my
private paths, my moment?"* → personal. A **half-formed** insight meant for the
team is still **shared** — the split is audience, not maturity.

## The final shape

**Shared `.tsugu/` — committed, pushed (transfers to any inheritor):**

| File | Role |
|---|---|
| `policy.md` | coordination policy — **shared sections only** (see A3) |
| `context.md` | per-ref branch narrative (the branch's own story) + a mainline form on the default branch |
| `knowledge/` | free-form shared wiki (durable findings) |

**Personal — global folder, project-keyed (e.g. `~/.claude/tsugu/<project-key>/`),
never in the repo:**

| Item | Why personal |
|---|---|
| observation config (intake **sources**) | private paths/filters/feeds — *how & what I observe* |
| opt-in **skills** | depends on *my* installed set + *my* trust |
| `packets/<slug>.md` | the converge decision-view — *my* human, *my* moment, *my* cadence; a **derived view**, not a pushed input (see D) |

**Removed from committed `.tsugu/`:**

| Item | Where it goes |
|---|---|
| `.tsugu/intake/` (notes/inbox) | **gone.** Work-entry = a `prepare/<slug>` branch directly; `converge` reads branches **live** |
| `.tsugu/runs/` (session logs) | **gone.** Shareable findings → `knowledge/`; the session transcript is ephemeral |
| `.tsugu/templates/` (seeded into repo) | **relocated into the skill** — referenced from `${CLAUDE_PLUGIN_ROOT}`, not copied into every repo |
| `.tsugu/packets/` | **relocated to the personal folder** — never pushed |
| `landed:` field | **gone** — settlement is pure containment + live re-surfacing (see C3) |

So pushed `.tsugu/` collapses to **`policy.md` + `context.md` + `knowledge/`**.

## A — The shared / personal split

### A1 — Shared `.tsugu/` is committed WIP knowledge

The reframe that anchors v2: the committed `.tsugu/` is no longer a *coordination
state store* — it is a **work-in-progress knowledge layer**, a richer,
agent-maintained sibling of `AGENTS.md` / `CLAUDE.md`. Two parts:

- **`context.md`** — the evolving narrative of one ref (each work branch tells its
  own story; the default branch tells the mainline's). This is the WIP half: the
  current understanding, open questions, next actions, verification, promotion
  candidates of live or recently-landed work.
- **`knowledge/`** — the durable, curated half: findings a coworker's agent would
  want, promoted deliberately.

Together they are "AGENTS.md / CLAUDE.md but richer and work-in-progress" — the
committed knowledge any inheritor reads from `git fetch` alone. Everything *about
how tsugu operates* moves out of the repo: into **personal config** (A2) and into
**the skill's own shipped norms** (the SKILL.md + references). The repo holds
knowledge; the skill holds behavior; the personal folder holds one human's setup.

### A2 — The personal global folder

Personal data lives in a global, project-keyed folder — proposed convention
`~/.claude/tsugu/<project-key>/` (exact path is an implementation detail). It is
**per-machine-per-human**: it never needs to match across machines, because the
only cross-machine contract is the pushed git branches. Precedent: Claude Code's
own auto-memory at `~/.claude/projects/<key>/`; tsugu's personal store sits
alongside it.

- **`<project-key>`** is derived from the **repo's common git dir**, not the
  current checkout path, so it is **stable across worktrees**. tsugu routinely
  creates worktrees (different paths, same repo and work item); keying on the cwd
  would split one repo's sources/skills/packets across several personal folders.
  Resolve the key from `git rev-parse --git-common-dir` (the shared `.git` of the
  main checkout — identical from every linked worktree), reduced to the repo's main
  path or a hash of it. The key need not be portable across machines (personal data
  is per-machine-per-human); it only needs to be **one key per repo per machine**.
- **Contents:** `sources` (observation config — the v1.1 `## Intake Sources`
  block), `skills` (opt-in skills — the v1.1 `## Skills Tsugu may use (this repo,
  opt-in)` block), and `packets/<slug>.md` (the converge decision-view — see D).
- **No repo footprint:** nothing under the working tree, so nothing to
  `.gitignore` and nothing to commit by accident.

**Bootstrap (a new behavior, replacing v1.1's intake-only `prepare` backstop).**
The personal folder does not transfer across machines, so each machine seeds its
own. When the folder (or a given section of it) is absent on a machine that can ask
(an **interactive `prepare` or `converge`**), the routine asks **once**, separately
for the two sections:

- **sources** — "Any observation sources to read besides git? (a file path, MCP
  tool name, or where to look — I resolve the `read:` pointer with my own
  permissioned tools, never auto-executed.)" A negative answer is recorded as a
  **confirmed-negative marker** (`sources: git-native (confirmed)`) so it is never
  re-asked; an unset folder is distinct from a confirmed-empty one.
- **skills** — "Any user-installed skills you trust me to use here during
  human-absent `prepare`? (default: none.)" Likewise recorded, negative included.

When **headless/non-interactive**, never block: fall back to git-native (no
sources, no opt-in skills) and surface "personal config unconfigured on this
machine" at the next `converge`. This is the explicit, defined trigger — the v1.1
skill only asked for sources during interactive `prepare` and never for skills, so
schema 3 specifies the broader behavior rather than relying on it.

### A3 — The `policy.md` split

`policy.md` keeps only the sections a coworker's agent needs to coordinate.
The boundary is audience/privacy (the spine).

| `policy.md` section | Verdict |
|---|---|
| `tsugu-schema`, Private-Git-Space / Public-Coordination boundary, `## Branch Prefixes`, `## Handoff Prefixes`, `## Public branch` (`public-branch-tsugu` — redefined, E), `## Merge method`, `## Housekeeping` (`stale-after`), `coordination-ref`, `remote:` / `default-branch:`, `## Recursion`, `## Skill use` (the shipped invariant), `## Push` (`push-prepare-branches` — pushed branches are messages to coworkers) | **shared** → stays in committed `.tsugu/policy.md` |
| `## Intake Sources` | **personal** → global folder (`sources`) |
| `## Skills Tsugu may use (opt-in)` | **personal** → global folder (`skills`) |

`## Skill use` (the *shipped invariant* that tsugu invokes no user-installed skill
by default) stays shared — it states behavior true in every repo. Only the
**opt-in list** (which named skills *this human* trusts here) is personal.

## B — `knowledge/` is a free-form, repo-wide agent wiki

Drop v1.1's "promotion gate / three clauses" framing. The instruction to agents
is simply: **put shareable repo knowledge here** — findings a coworker's agent
would want. Kept to the audience boundary (not private-source details, not
session-specific scratch — those are personal or ephemeral). No prescribed
structure; agents organize and prune as they judge (each a `.tsugu/`-only commit).
It absorbs the **shareable findings** previously recorded in `runs/` (the
underlying transcript was ephemeral and is not kept) and is the team's shared
brain.

The omni-repo placement rule from 004/005 still holds: write knowledge at the
**lowest repo level where it stays true**; promote upward only when it affects
multiple repos.

## C — State model without intake notes

### C1 — The partition is single-layer (branches only)

With `intake/` gone, there is no inbox layer. The partition classifies each work
branch `<work-prefix>/<slug>` by **two ref-level facts, checked in order** — no
written state of any kind:

| Fact | State | Disposition |
| --- | --- | --- |
| tip contained in `<remote>/<default>` (in `exclude` mode: the slug-paired public branch's tip) | **settled** — the work landed | skip; completion-tail / cleanup candidate |
| a branch with the **same slug** exists under a configured `## Handoff Prefixes` | **decided, awaiting merge** | skip as candidate; shown in converge's awaiting-merge section |
| neither | **in progress** | candidate: read `context.md`, judge from the narrative |

Containment is `git merge-base --is-ancestor` / `git for-each-ref --contains`
against remote-tracking refs. The slug remains the **join key** — work branch,
its `context.md`, its personal packet, and its handoff branch all share one slug;
names are write-once identity, so pairing survives anything the forge does to
commits. Claims remain **derived from commit recency** (the `context.md` rewrite
commit's author + timestamp). Zero-commit branches remain **exempt** from the
table — a `prepare/<slug>` whose tip equals the default tip is interrupted work or
a **request-by-branch** (a human pushed it as the ask), never a cleanup target.

What disappears versus v1.1: the entire intake-note lifecycle
(`open→claimed→done|dropped`), `linked-branch:`, the `landed:` field and its
validation, the "claimed note whose branch vanished" reconciliation case, and the
zero-commit-claim recency rule that read a coordination-ref note commit. **Claims
on zero-commit branches now have no recency source** — a zero-commit
`prepare/<slug>` is simply a request-by-branch candidate until someone commits to
it; the first commit establishes recency, as for any branch.

### C2 — Work-entry is a branch

There is **no note-without-branch**. A work item *is* the set of refs sharing one
slug; the unit of work is a `prepare/<slug>` (or `investigate/<slug>` /
`review/<slug>`) branch. An external source signal (A2/D) becomes a
`prepare/<slug>` branch directly — `prepare` opens the branch (zero-commit
request-by-branch, or begins working it) rather than writing a committed note
first.

### C3 — Settlement without `landed:` (re-surface live)

Settlement is **pure containment** (`merge-base --is-ancestor`). The
non-containment-preserving case (a forced squash, or a rebase workflow that leaves
the work branch pointing at pre-rewrite commits) is **not derivable from refs**,
and v2's answer — chosen over prohibiting such landings — is that it **does not
need to persist**:

- A repo using **merge commits** (tsugu's standing recommendation) is fully
  containment-derivable — no record ever needed.
- A **non-containment-preserving landing** stays in **"decided, awaiting merge"**
  *because its slug-paired handoff branch still pairs* — and that pairing is the
  only thing keeping the orphaned (squash-broken) work branch from looking
  in-progress. So the forced-squash path has a **hard dependency on the handoff
  branch surviving** the merge: see the retain-handoff requirement below. It
  **re-surfaces at each `converge`** while it pairs; there is no *derived*
  settled-state for it, by design. The human ends it by confirming the landing and
  running the **completion tail**: promote any reusable findings to `knowledge/`,
  then delete **both** the work branch and the handoff branch. Once both are gone
  the item **leaves the partition entirely** (no refs → not classified, exactly
  like any cleaned-up settled item). The **durable landed artifact is the squash
  commit itself** on the default branch — the work content is there, just not
  containment-linked or slug-keyed. No slug→SHA mapping is needed: the item is done
  and out of the partition, so there is nothing left to classify. Re-surfacing and
  dropping are **sequenced, not in conflict**.

- **If the forge auto-deletes the handoff branch anyway** (a common merge setting),
  a squash-broken work branch is neither contained nor slug-paired, so the
  partition (C1) would call it **in-progress** — and a scheduled `prepare` must not
  resume already-landed work. The **narrative backstop** closes this: the work
  branch's `context.md` reads "handed off — may have landed via squash" (written at
  the converge decision, before the PR is opened), and `prepare`'s **judgment**
  reads that narrative and **leaves the branch for `converge`** rather than
  resuming it. This stays within the orientation principle — *narrative informs
  judgment, never classification*: the partition still classifies it in-progress;
  the agent's judgment, not a written state field, declines to work it. The robust
  path is still the retain-handoff requirement below; the narrative backstop is the
  safety net for repos whose forge deletes the branch regardless.

**Retain-handoff requirement (forced-squash path).** This extends the standing
merge-method guidance recorded in `policy.md`'s `## Merge method` (prefer merge
commits — do not squash-merge tsugu-managed branches). When a forge nonetheless
forces a squash, the repo **should disable auto-delete-head-branch for tsugu
handoff branches** so the slug pairing survives the merge and carries the
"awaiting merge" state until the human's completion tail deletes both branches.
This is a recommendation, not a hard gate (the rejected stricter alternative was to
make merge-commit-or-retained-handoff a hard requirement that leaves squash-only
forges unsupported). Where the forge deletes the branch regardless, the narrative
backstop above is the fallback. `init` records this guidance alongside the
merge-method line; it changes no chosen value.

This **intentionally reverses 005 §C4's "the landed SHA has nowhere durable to
live."** v2's answer: it does not need to live anywhere — settlement is
containment, and the one lossy case re-surfaces live (held visible by the retained
handoff branch, with the narrative backstop behind it) until the human drops it.

The completion tail therefore loses its **intake-flip step**. It becomes: confirm
landing (containment, or human confirmation for a forced squash) → promote to
`knowledge/` → clean up worktrees then branches (worktree remove before branch
delete; the handoff branch too). It stays idempotent — interrupted before
cleanup, the branches remain and a later tidy re-enters.

The **out-of-band PR closure** case is unchanged in spirit: if the human closes
the PR and deletes the handoff branch, the slug pairing dissolves and the work
**re-surfaces at the next `converge`** for re-decision, never auto-resumed.

### C4 — Source dedup is weakened (accepted)

v1.1 used a `done`/`dropped` intake note as the durable record that a source item
was already processed, preventing re-import. With intake notes gone, **dedup is by
live ref existence only**: a source item whose work already landed *and whose
branches were deleted* leaves no ref, so if the external source still lists it,
the next `prepare` may re-import it as a fresh `prepare/<slug>`.

This is **accepted** (issue #36, confirmed): the re-imported item surfaces at
`converge` as an ordinary candidate, and the human drops it. No committed ledger
is reintroduced — that would be exactly the derived state v2 removes. In-flight
dedup still works (a live branch with the slug is found). Re-opened source items
remain **out of scope** (as in v1.1). The trade-off is logged here, not hidden:
solo dogfooding tolerates it because `converge` is the human's interception point.

## D — `converge` reads branches live; the packet is personal

When the human runs `/tsugu:converge` for the "what should I do next" status view,
the agent **checks out / reads each tsugu branch live** (its `context.md` + DAG
state) to assemble the picture, rather than reading a committed cache. This may be
slower than reading a pushed artifact; **any cache stays personal/ephemeral** —
the chat session context or the global personal folder — **never a committed
`.tsugu/` artifact**.

The **packet** (`packets/<slug>.md`) becomes a **personal, derived** decision-view
in the global folder. This is what reconciles personal packets with the
cross-machine contract (005's "a `converge` on machine B reconstructs the full
state from `git fetch` alone"): **machine B never needs machine A's packet** — it
**regenerates the decision-view live** from the pushed branches (`context.md` +
DAG + B's own sources). The packet is a *derived, personal lens* over the shared
truth, not a required input. The shared, inheritable truth is the branch
(`context.md` + commits) and `knowledge/`.

`converge`'s steps 1–3 (fetch, partition, present) remain **read-only** — the
morning status view. Side effects begin only at the disposition (step 4). The
packet may still **hint** which workflow skill fits, but fires none.

## E — `context.md` changes, and `public-branch-tsugu` redefined

### E1 — `context.md`

`context.md` stays (per-ref pure narrative + a mainline form on default), but:

- It **no longer links to `runs/` or `packets/`** — `runs/` is gone, `packets/` is
  personal (not on the branch). The "## This work's files" section is dropped; the
  branch's story is self-contained, with `## Promotion candidates` still pointing
  at `knowledge/`.
- The "accumulated archive loaded via active branch" semantics from 005 §C2 no
  longer apply — there is no `runs/`/`packets/` archive on the default branch to
  navigate. After an `include` merge, what lands is the rewritten mainline
  `context.md` and the prep DAG; `knowledge/` is the curated tier, read directly.

The inherit→rewrite cycle, the merge-back rewrite (include mode), the "no lineage"
rule, and the schema-compat reads (`branch.md` fallback) are unchanged.

### E2 — `public-branch-tsugu: include | exclude` redefined

The field is **kept and redefined** (not dropped). Values and mechanism are
unchanged (`include` default / `exclude` opt-out; include = the work branch merges
as-is, exclude = a clean public branch cut from default, accepted changes applied
by path). What it **governs** is redefined to match the smaller shared surface:

- **v1.1:** whether the work branch's `.tsugu/` evidence
  (**`runs/` + `packets/` + `context.md`**) lands on the mainline.
- **v2:** whether the committed **WIP-knowledge layer** — the work branch's prep
  commit DAG plus its `context.md` narrative — lands on the public/default branch.
  `runs/` and `packets/` no longer exist on the branch, so they are not part of
  the question. **`knowledge/` lands via coordination-ref writes regardless of
  mode** — it is the team's shared brain in both `include` and `exclude`.

The durable-shared-memory rationale for the `include` default thus shifts from
"`runs/`/`packets/` land" to "`context.md` + the prep DAG land as committed WIP
knowledge; `knowledge/` lands on the coord ref either way." `exclude` still serves
collaborative repos that keep coordination metadata out of PR diffs — the public
branch's diff introduces no `.tsugu/` changes, and landing is confirmed via the
public branch's containment.

## F — The skill shrinks to match

The skill is rewritten to fit the much smaller design. Removed: intake-note
lifecycle, `landed:`/reconciliation, `runs/`, repo template-seeding, the two-layer
partition's inbox layer, and the pushed-packet machinery. Templates move **into
the skill** (referenced from `${CLAUDE_PLUGIN_ROOT}`, not copied into repos).

Expected reference collapse:

- `policy-and-intake.md` → shared `policy.md` fields **only**, plus a short pointer
  to the **personal config** (sources + opt-in skills in the global folder). The
  whole intake human-bridge / recorded-form / dedup / `landed:` / reconciliation
  body shrinks to: "observation sources are personal config; resolve each `read:`
  pointer with your own permissioned tools (the no-force principle stands); a
  source signal becomes a `prepare/<slug>` branch."
- `notes-and-packet.md` → `context.md` (per-ref pure narrative, no `runs/`/
  `packets/` links) + `knowledge/` (free-form wiki, no promotion-gate framing) +
  a brief note that the packet is a **personal/derived** view. The two-layer
  intake table is removed.
- `git-recipes.md` → keep: read-queue (cold-start), the two-fact containment
  partition (simpler), handoff-branch cut, include/exclude arms, freshness,
  cleanup order, init skeleton (smaller — no `intake/`/`templates/` seeding).
  Remove: coordination-ref intake writes, `landed:` validation, the
  completion-tail intake flip.
- `migrations.md` → keep 1→2 (for schema-1 repos), **add 2→3**.

Templates kept in the skill: `policy.md` (shared sections only), `context.md`
(work-branch + mainline forms), `packet.md` (now written into the personal
folder). Removed: `intake.md`, `run.md`.

## G — Migration 2→3

The 2→3 migration follows the established contract (condition → actions →
what-must-not-be-touched; each step idempotent; stamp written last; a
non-mechanical conflict stops and asks; push-protected default rides an `init/*`
branch + human-approved PR). Steps:

1. **Move personal sections out of `policy.md`.** Read `## Intake Sources` and
   `## Skills Tsugu may use (this repo, opt-in)` from committed `policy.md`; write
   them into **the migrating machine's** personal folder
   (`~/.claude/tsugu/<project-key>/` `sources` + `skills`); then **remove** both
   sections from `policy.md`. The shipped-invariant `## Skill use` section stays.
   Condition: either section is still present in `policy.md`.
   - **Re-entrant, so an abandoned policy PR is safe.** The personal-folder write
     is the durable copy and is **idempotent and re-derivable from the old
     `policy.md`** until the removal lands: the write happens locally and outside
     git, while the section removal rides the `init/*` policy PR on a push-protected
     default. If that PR is rejected/abandoned, committed `policy.md` still carries
     the sections, so a re-run simply re-reads them and re-writes the (unchanged)
     personal copy — no double-source-of-truth survives a re-run, and the personal
     write being first is harmless.
   - **Other machines self-seed by re-asking.** After the migration merges,
     `policy.md` no longer carries these sections. On each other machine's next
     interactive `prepare`/`converge`, the **bootstrap behavior defined in A2**
     asks (separately for sources and skills, negative-markers recorded) and seeds
     *that machine's* personal folder. This is principle-aligned: observation
     config is "how & what *I* observe" — inherently per-machine, not meant to
     transfer. No git-history recovery and no in-repo breadcrumb.
2. **Remove the relocated/removed committed paths**, per-path and idempotently —
   this **stops writing them going forward; history is left intact** (no rewrite —
   it would violate the protect-primary-history invariant, and old artifacts are
   harmless). Two subtleties the bare `git rm -r .tsugu/intake .tsugu/runs
   .tsugu/packets .tsugu/templates` gets wrong:
   - **Idempotency / partial trees.** A bare `git rm -r` **fails if any pathspec
     matches nothing**, and the schema-2 `init` skeleton seeds only
     `intake/`/`knowledge/`/`templates/` — `runs/` and `packets/` are created on
     first use, so a repo that never ran `prepare` has neither. Remove each path
     **only if present** (a per-path guard, or `git rm -r --ignore-unmatched
     <path>`), so the step no-ops cleanly on a partial tree and an interrupted
     re-run re-enters. Condition: any of these paths still exists.
   - **Cross-ref placement.** `intake/`/`runs/`/`packets/` live on the
     **coordination ref**; repo-seeded `templates/` lives on the **default
     branch**. When `coordination-ref != default` (the push-protected setup that
     1→2 already handles for the `context/→knowledge/` rename), these are on
     *different refs* — one `git rm` cannot span both. Split the removal: the
     coord-ref paths are removed on the coordination ref, `templates/` on default,
     and the **coord-ref deletions are confirmed before the step-5 schema stamp**,
     exactly as 1→2 orders its coord-ref rename ahead of the stamp. When
     `coordination-ref = default`, all four ride the one `init/*` policy PR, stamp
     last. Throughout the window a reader tolerates the old dirs still being
     present (they are inert once `prepare`/`converge` stop writing them).
3. **Redefine `public-branch-tsugu` wording** in `policy.md` (E2) — same values,
   updated description (WIP-knowledge framing). Remove any `landed:` / intake-flip
   wording. Condition: the old wording is present. Never change the chosen value.
4. **Refresh templates by reference.** `init`/`prepare`/`converge` now read
   templates from `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/templates/` instead of the
   repo's `.tsugu/templates/` (removed in step 2). `context.md` template loses its
   `runs/`/`packets/` links. No repo template files are written.
5. **Stamp `tsugu-schema: 3` — last**, after steps 1–4 succeed.

`<project-key>` for step 1 may be the local repo path. A schema-1 repo runs
1→2→3: the 1→2 steps (which create `intake/`, seed `templates/`, etc.) run first,
then 2→3 removes/relocates them — wasteful but correct under the sequential
contract; an implementation MAY short-circuit but is not required to.

Live work branches are not migrated centrally — they convert on next touch (the
schema-compat `branch.md`/`context.md` reads still apply).

## Affected surface

| File | Change |
| --- | --- |
| `skills/tsugu/SKILL.md` | shrink: remove intake-note lifecycle, `landed:`/reconciliation, `runs/`, template-seeding, inbox layer; routing + spine reflect committed `.tsugu/` = `policy.md` + `context.md` + `knowledge/`; personal config + packet framing; `public-branch-tsugu` redefined; schema 3 |
| `skills/tsugu/references/policy-and-intake.md` | shared `policy.md` fields only + personal-config pointer; intake body collapses to "sources are personal; resolve `read:` via permissioned tools; signal → `prepare/<slug>` branch"; remove `landed:`/dedup-by-note/reconciliation |
| `skills/tsugu/references/notes-and-packet.md` | `context.md` no `runs/`/`packets/` links; `knowledge/` free-form (no gate); packet is personal/derived; remove two-layer intake table |
| `skills/tsugu/references/git-recipes.md` | drop coordination-ref intake writes, `landed:` validation, completion-tail intake flip; simpler partition; init skeleton without `intake/`/`templates/` |
| `skills/tsugu/references/migrations.md` | add migration 2→3 (keep 1→2) |
| `skills/tsugu/templates/` | keep `policy.md` (shared only), `context.md` (no `runs/`/`packets/` links), `packet.md` (personal-folder form); **remove** `intake.md`, `run.md`; templates referenced not copied into repos |
| `skills/tsugu/commands/{init,prepare,converge}.md` | reflect personal config + live-read converge where they mention intake/packets |
| `skills/tsugu/README.md` | `.tsugu/` diagram (`policy.md` + `context.md` + `knowledge/`); personal folder; state model; redefined `public-branch-tsugu`; add 006 link |
| `plugins/tsugu/.claude-plugin/plugin.json` | description updated to the v2 shape |
| `.claude-plugin/marketplace.json` | tsugu entry: description + **minor version bump** |
| root `CLAUDE.md` | tsugu section: committed `.tsugu/` = `policy.md`+`context.md`+`knowledge/`; personal folder; schema 3; no intake/runs/packets |

## Success criteria

1. A fresh `init` writes only `policy.md` (shared sections) + `context.md`
   (mainline) + `knowledge/` under committed `.tsugu/`; no `intake/`, `runs/`,
   `packets/`, or `templates/` directory is created in the repo.
2. Observation sources and opt-in skills are read from and written to the
   **personal global folder**, never committed `policy.md`. A `read:` pointer is
   resolved by the agent's own permissioned tools (no-force principle intact). The
   `<project-key>` derives from the repo's common git dir, so every worktree of one
   repo shares **one** personal folder on a given machine.
3. A work item is a `prepare/<slug>` branch (no note-without-branch). The
   partition derives settled / awaiting-merge / in-progress from containment +
   slug pairing alone — no `status:`, no `linked-branch:`, no `landed:`.
4. A merge-commit landing settles by **containment**. A forced-squash landing
   stays "decided, awaiting merge" via its **retained handoff branch** and
   **re-surfaces at each `converge`** until the human confirms it and runs the
   completion tail (promote → delete both branches); no SHA is persisted, and once
   both branches are gone the item leaves the partition. Where the forge deletes
   the handoff branch on merge, the work branch's `context.md` narrative keeps
   `prepare` from resuming it (narrative informs judgment, never classification).
5. `converge` reconstructs the status view **live** from `git fetch` + branch
   reads; the packet is regenerated as a **personal/derived** view (machine B
   needs no packet from machine A). No committed packet exists.
6. With `public-branch-tsugu: include`, merging lands the prep DAG + the rewritten
   mainline `context.md` (committed WIP knowledge), with **no state line to clean
   up**; with `exclude`, the public diff introduces no `.tsugu/` changes.
   `knowledge/` lands on the coordination ref in **both** modes.
7. Re-running `/tsugu:init` on a schema-2 repo migrates it to schema 3: personal
   sections move to the migrating machine's global folder and are removed from
   `policy.md`; `intake/`/`runs/`/`packets/`/`templates/` are `git rm`'d
   (history left intact); the stamp is written last; an interrupted migration
   re-enters safely; a schema-1 repo migrates 1→2→3.
8. Other machines bootstrap their own personal folder by **re-asking** on first
   interactive `prepare`/`converge` — separately for sources and opt-in skills,
   recording a confirmed-negative marker — and fall back without blocking when
   headless; no git-history recovery or in-repo breadcrumb is used.
9. The shipped skill is materially smaller: SKILL.md and references no longer
   describe intake-note lifecycle, `landed:`, reconciliation, `runs/`, or repo
   template-seeding; templates are referenced from `${CLAUDE_PLUGIN_ROOT}`.

## Open questions (resolved in this spec)

1. **`public-branch-tsugu` fate** → **redefined** (E2). Kept; re-scoped to govern
   whether the committed WIP-knowledge layer (`context.md` + prep DAG) lands on
   the public/default branch. `knowledge/` lands on the coord ref regardless.
2. **Existing committed `packets`/`intake`/`runs` in history** → **stop writing
   going forward** (`git rm`); **history left intact** (no rewrite — protects
   primary-branch history; old artifacts are harmless).
3. **Per-machine personal-folder bootstrap** → the **migrating machine self-seeds**
   from the old `policy.md` sections; **other machines re-ask** on first
   interactive run (no history recovery, no breadcrumb).
4. **Settlement of non-containment-preserving landings** → **re-surface live at
   each `converge`** until the human drops both branches (C3); the squash commit
   is the durable artifact. The forced-squash path **retains the handoff branch**
   (recommendation extending the merge-method guidance) so the pairing carries the
   awaiting-merge state, with the `context.md` **narrative backstop** when the
   forge deletes it anyway. (Prohibiting such landings, and a hard
   merge-commit-or-retained-handoff requirement, were the rejected stricter
   alternatives — they would constrain squash-only forges.)
5. **Source dedup after a landed item's branches are deleted** → **weakened,
   accepted** (C4): dedup is by live ref only; a re-imported done item surfaces at
   `converge` and the human drops it. No committed ledger.

## Deferred (unchanged from 004/005)

Multi-agent arbitration, tracker adapters, external notification, automatic
periodic sync of long-lived branches, re-opened intake items, and a formalized
claim-staleness window all remain deferred.
