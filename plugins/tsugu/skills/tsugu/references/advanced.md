# advanced

These are the **heavier, non-default paths** lifted out of the core skill so the
core mental model stays thin. Nothing here is dropped capability — it is
**relocated, not removed**. The core (`SKILL.md`) assumes **merge commits**, where
settlement is pure containment (the **accepted branch's** tip — the renamed work
branch — contained in `<remote>/<default>` ⇒ settled). The two sections below cover
what the core deliberately omits: landings that **rewrite history** so the accepted
tip is never contained, and the same-slug artifact rule for repos that configure
**extra work prefixes** beyond the default `prepare/*`.

The core SKILL.md keeps a one-line pointer into here: *"A landing that rewrites
history (squash, rebase-before-merge, force-push) breaks containment-derived
settlement; see `references/advanced.md`."*

---

## Non-containment landings

The core derives settlement from **containment** — the **accepted branch's** tip
(the renamed work branch) contained in default. That holds for a merge commit (the
merge's parents include that tip). It does **not** hold for a landing that
**rewrites history** so the accepted tip is no longer contained — and this is
**mode-agnostic**: it covers both an `include`-mode rewrite **and** an `exclude`-mode
landing where the human **strips `.tsugu/` into a fresh published branch** (default
then contains the stripped copies, not the accepted tip). The rewrite mechanism has
three forms:

- **forced squash** — the canonical example: the forge collapses the PR to one
  commit whose parents contain **none** of the work commits, so the work tip is
  not an ancestor of default;
- **rebase-before-merge** — the accepted branch is rebased onto the latest default
  before merging, so default contains the rebased copies, not the original
  `prepare/*` tip or its history;
- **force-push of the accepted branch** — the accepted ref is rewritten in place,
  so default ends up containing neither the original work tip nor the pre-rewrite
  history.

Squash is the canonical example; the path is the **same for all three** (and for
the `exclude`-strip case above). In every case `git merge-base --is-ancestor
<accepted-tip> <remote>/<default>` stays false even after the work genuinely landed,
so the containment-derived row can never settle the item.

### What the advanced path documents

For a non-containment landing, four things replace the containment signal the core
relies on:

1. **Narrative backstop — legibility, not a resume-guard.** When a rewrite is
   anticipated, you MAY record *"handed off — may have landed via squash/rebase"* in
   the **accepted branch's** `context.md` as a legibility note. Under 011 this is
   **not** the mechanism that keeps `prepare` off handed-off work: default handoff
   writes no marker, and a note on the *accepted* branch can't reach a surviving
   remote `prepare/<slug>` anyway (it was pushed earlier, without the note). What
   actually guards a surviving stale `prepare/<slug>` is the **partition** — it is
   slug-paired to the accepted branch → **taken-over** → skipped — or, in the
   signal-less residual (accepted ref deleted *and* B3 not yet run), `prepare`'s
   **conservative judgment** (leave the unfamiliar stale branch for `converge`;
   reversible, never auto-merges; B3 closes the window). *Judgment, not a written
   status, governs.*
2. **Re-surface until confirmed.** Because the work tip is **never** contained, the
   item cannot settle by containment; it stays **taken-over** (paired by its
   slug-paired accepted branch) and **re-surfaces at each `converge`** until
   the human confirms the landing — after which `prune` sweeps the branches (its
   *possibly-landed (no containment) — confirm* bucket) and curation promotes any
   findings. No settlement SHA is persisted — state stays single-layer; the slug
   pairing carries the "awaiting merge" disposition live.
3. **Disable the forge's auto-delete-head-branch — for the rewrite case.** A common
   merge setting deletes the head branch on merge. For a rewrite landing, that
   would delete the slug-paired accepted ref before the human confirms, severing
   the pairing that carries the disposition. So **disable auto-delete** so the
   accepted ref survives long enough to confirm. This is a recommendation, not a
   hard gate — where the forge deletes it anyway, the case degrades to the
   signal-less residual (`prepare`'s conservative judgment; B3 closes the window).
4. **Rewrite-specific cleanup trigger.** Cleanup fires on the human's **in-session
   confirmation**, not on containment (which never settles a rewrite landing). This
   is exactly `prune`'s *possibly-landed (no containment) — confirm* bucket: on
   confirmation, curation promotes reusable findings and `prune` deletes the
   **accepted branch** (post-handoff the work branch was renamed into it; only the
   stale remote `prepare/<slug>` also remains, if the human hasn't run B3 yet).

### What stays in core (shared)

Only one of these is truly **core and mode-agnostic**; the other is rewrite-specific:

- **(a) the retain-the-ref / disable-auto-delete recommendation** *(core, mode-agnostic)* —
  settlement reads off the **accepted branch's** containment in both modes, so that ref
  must survive the merge to carry the disposition (slug-pairing while awaiting,
  containment once landed). This belongs in core.
- **(b) the narrative backstop** *(NOT general; not a guard)* — 011's default handoff
  writes **no** marker (containment + slug-pairing guard the common cases). The backstop
  write applies **only** to the **anticipated-rewrite** case documented below, and even
  there it is a **legibility note** on the accepted branch — **not** a resume-guard or a
  classification signal (it can't reach a surviving remote `prepare/<slug>`).

So the **retain-the-ref recommendation** is core (shared by both modes); the
**narrative backstop** is the rewrite-specific elaboration advanced documents — it
is not a general handoff mechanism.

### The concrete forced-squash procedure

This is the procedure that previously lived in `policy-and-intake.md`'s
`## Merge method`, captured here so nothing is lost when that block shrinks to
"prefer merge commits; non-containment landings → advanced":

Tsugu **recommends merge commits — do not squash-merge tsugu-managed branches.**
Preserved history is what makes settlement, lineage, and evidence derivable from
the DAG by containment. The consequence of a **forced squash:** the squash commit's
parents contain none of the work commits, so the landing is **not** containment-
derivable — the work stays **taken-over** *because its slug-paired accepted branch
still pairs*. So when a forge nonetheless forces a squash, the repo
**should disable the forge's auto-delete-head-branch for tsugu accepted branches**,
so the slug pairing survives the merge and carries the "awaiting merge" state until
the human confirms and `prune` deletes the accepted branch (plus the stale remote
`prepare/<slug>` if not already reconciled via B3). This is a recommendation, not a
hard gate; where the forge deletes the accepted branch regardless, the outcome
matches SKILL.md's backstop note: **if no work ref survives** (the human ran B3, so
the stale remote `prepare/<slug>` is gone too), the item **leaves the partition** —
the squashed work is already in `<default>`, nothing to resume. **If the stale
remote `prepare/<slug>` still survives** (B3 not yet run), that ref reads in-progress
with no accepted pair and no containment, and the backstop note (on the now-deleted
accepted branch) can't reach it — so the **only** guard is `prepare`'s **conservative
judgment**: leave the unfamiliar stale branch for `converge` (reversible, never
auto-merges). Running **B3** removes the ref and closes the window.
**No settlement SHA is recorded out of band** — settlement is pure containment, and
the retained-ref case re-surfaces live at each `converge` until the human confirms
and drops the accepted branch.

---

## Slug artifact under extra work prefixes

The default work-prefix set is **`prepare/*` alone**, and `prepare`'s built-in
review/investigate subagents work **inside** the `prepare/*` branch / its
worktree, recording findings in that branch's `context.md` — they no longer emit a
separate `review/<slug>` (or `investigate/<slug>`) branch as a same-slug artifact.
So the core no longer produces extra-prefix branches, and the slug-artifact rule
left the core SKILL.md and lives here.

A repo **MAY** still configure additional work prefixes — the mechanism is intact;
discovery filters by whatever prefixes `policy.md`'s `## Branch Prefixes` records.
When a repo does configure extra work prefixes, the rule holds:

> A **same-slug branch under a *different work prefix*** is that work item's
> **artifact**. It shares the work item's lifecycle and is **swept with the work
> item at `prune`** — it is not an independent queue item.

This keeps the slug as the single join key. The default's **four legs** are always
intact (the work branch, its `context.md`, the personal packet
`packets/<slug>.md`, and the accepted branch when one exists); the extra-prefix
artifact leg is **only** present in a repo that has curated additional work
prefixes, and even then it follows the work item's slug rather than standing on its
own.

## Bare-submodule handoff

Under handoff-only converge (spec 011 Change B), a bare submodule's accept is **no
longer an agent-driven two-repo landing transaction**. It is a **handoff**, the same
as any other branch:

- **Hand off the submodule branch and stop.** At submodule converge, the submodule's
  `prepare/<slug>` is **renamed to a human work branch** (`<accepted-prefix>/<slug>`,
  named per **meta** policy's `## Accepted Prefixes`, same slug) **in the submodule** —
  a move, cold-start safe, exactly like the primary handoff in `git-recipes.md`. Then
  it stops. No agent-driven gitlink re-point, no ordered cross-repo transaction, no
  forge PR.
- **The meta repo no longer manages it.** To the meta repo it is just "a human work
  branch now exists in the submodule." The cross-repo landing — landing the submodule
  PR, bumping the meta gitlink, landing the meta PR — is **the human's** when they
  finish the work, not the agent's.
- **The existing paired meta `prepare/<slug>`** (a bare submodule's findings ride a
  meta branch carrying the gitlink bump + `context.md`, per 008) is **not auto-managed**
  when the submodule branch is handed off. The agent does not rename, land, or delete
  it as part of the handoff. It remains a **normal candidate** classified by the **same
  existing meta partition** (containment of its tip in the meta default, then
  slug-pairing — no new marker) that surfaces at the **meta** repo's own `converge`
  (and at `prune`). Handing off the submodule branch and handling the meta branch are
  **decoupled**.
- **The maintenance exception (Change C) can still apply per-repo** if the human
  marked that work maintenance-type — then the complete path (rename first → bring
  current + verified → ready-to-merge) applies in the submodule, still never
  auto-merging.

The remote reconcile (push the accepted branch, delete the stale remote
`prepare/<slug>`) is the human's, surfaced as a prompt; cleanup of the handed-off
refs is deferred to `prune`.

**Out of scope:** nested bare chains (a bare submodule inside a bare submodule) would
require a gitlink-bump chain through every intermediate — surface such a subtree for
the human to restructure, don't drive it.
