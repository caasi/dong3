# advanced

These are the **heavier, non-default paths** lifted out of the core skill so the
core mental model stays thin. Nothing here is dropped capability — it is
**relocated, not removed**. The core (`SKILL.md`) assumes **merge commits**, where
settlement is pure containment (`prepare/<slug>` tip contained in
`<remote>/<default>` ⇒ settled). The two sections below cover what the core
deliberately omits: landings that **rewrite history** so the work tip is never
contained, and the same-slug artifact rule for repos that configure **extra work
prefixes** beyond the default `prepare/*`.

The core SKILL.md keeps a one-line pointer into here: *"A landing that rewrites
history (squash, rebase-before-merge, force-push) breaks containment-derived
settlement; see `references/advanced.md`."*

---

## Non-containment landings

The core derives settlement from **containment** — the work branch's own tip
contained in default. That holds for a merge commit (the merge's parents include
the work tip). It does **not** hold for any **include-mode landing that rewrites
history** so the work branch's own tip is no longer contained in default. This is
the general class; three landings fall into it:

- **forced squash** — the canonical example: the forge collapses the PR to one
  commit whose parents contain **none** of the work commits, so the work tip is
  not an ancestor of default;
- **rebase-before-merge** — the accepted branch is rebased onto the latest default
  before merging, so default contains the rebased copies, not the original
  `prepare/*` tip or its history;
- **force-push of the accepted branch** — the accepted ref is rewritten in place,
  so default ends up containing neither the original work tip nor the pre-rewrite
  history.

Squash is the canonical example; the path is the **same for all three**. In every
case `git merge-base --is-ancestor <work-tip> <remote>/<default>` stays false even
after the work genuinely landed, so the containment-derived row can never settle
the item.

### What the advanced path documents

For a non-containment landing, four things replace the containment signal the core
relies on:

1. **Narrative backstop.** At the converge decision (before the PR opens, when a
   rewrite is anticipated), write *"handed off — may have landed via
   squash/rebase"* into the work branch's `context.md`. The partition still
   classifies the orphaned work branch as a candidate, but `prepare`'s **judgment**
   reads that narrative and **leaves the branch for `converge`** rather than
   resuming already-landed work — *narrative informs judgment, never
   classification*.
2. **Re-surface until confirmed.** Because the work tip is **never** contained, the
   item cannot settle by containment; it stays **decided, awaiting merge** (paired
   by its slug-paired accepted branch) and **re-surfaces at each `converge`** until
   the human confirms the landing and runs the completion tail. No settlement SHA
   is persisted — state stays single-layer; the slug pairing carries the
   "awaiting merge" disposition live.
3. **Disable the forge's auto-delete-head-branch — for the rewrite case.** A common
   merge setting deletes the head branch on merge. For a rewrite landing, that
   would delete the slug-paired accepted ref before the human confirms, severing
   the pairing that carries the disposition. So **disable auto-delete** so the
   accepted ref survives long enough to confirm. This is a recommendation, not a
   hard gate — squash-only forges stay supported via the narrative backstop above.
4. **Rewrite-specific completion-tail trigger.** The completion tail fires on the
   human's **in-session confirmation**, not on containment (which never settles a
   rewrite landing). On confirmation: promote reusable findings, then clean up —
   delete **both** the work branch and the accepted branch.

### What stays in core (for `exclude` mode)

Two of these look like they could move wholesale, but they **stay in core**
because `exclude` mode (which stays in core) needs them **independently of any
rewrite**:

- **(a) the general deleted-ref narrative backstop** — for a *deleted* handoff /
  public ref (the forge auto-deletes on merge), so landed work doesn't read as
  in-progress; and
- **(b) the retain-handoff / disable-auto-delete recommendation** — `exclude` mode
  settles via the **public branch's** containment, so that ref must survive too.

Advanced only adds the **rewrite-specific** elaboration on top of these — the
deleted-ref backstop and the retain-handoff recommendation themselves are core,
shared with `exclude`.

### The concrete forced-squash procedure

This is the procedure that previously lived in `policy-and-intake.md`'s
`## Merge method`, captured here so nothing is lost when that block shrinks to
"prefer merge commits; non-containment landings → advanced":

Tsugu **recommends merge commits — do not squash-merge tsugu-managed branches.**
Preserved history is what makes settlement, lineage, and evidence derivable from
the DAG by containment. The consequence of a **forced squash:** the squash commit's
parents contain none of the work commits, so the landing is **not** containment-
derivable — the work stays "decided, awaiting merge" *because its slug-paired
accepted branch still pairs*. So when a forge nonetheless forces a squash, the repo
**should disable the forge's auto-delete-head-branch for tsugu accepted branches**,
so the slug pairing survives the merge and carries the "awaiting merge" state until
the human's completion tail deletes both branches. This is a recommendation, not a
hard gate; where the forge deletes the branch regardless, the work branch's
`context.md` **narrative backstop** ("handed off — may have landed via squash")
keeps `prepare` from resuming it. **No settlement SHA is recorded out of band** —
settlement is pure containment, and the one lossy case re-surfaces live at each
`converge` until the human drops both branches.

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
> **artifact**. It shares the work item's lifecycle and is **swept by its
> completion tail** — it is not an independent queue item.

This keeps the slug as the single join key. The default's **four legs** are always
intact (the work branch, its `context.md`, the personal packet
`packets/<slug>.md`, and the accepted branch when one exists); the extra-prefix
artifact leg is **only** present in a repo that has curated additional work
prefixes, and even then it follows the work item's slug rather than standing on its
own.
