# notes-and-packet

The shape and lifecycle of every `.tsugu/` note Tsugu maintains: `context.md`,
`intake/`, `runs/`, `packets/`, and `knowledge/`. Placement on the durability
gradient (which branch each lives on) is summarized in `SKILL.md`; this document
covers structure and load/lifecycle semantics. There is **no written branch
state** — live coordination facts (in progress / decided / landed / who's on it /
what grew out of what) are derived from ref names, ancestry, containment, and
commit recency, never written into a note (see `SKILL.md`'s partition and
`references/git-recipes.md`). Notes hold two things only: **narrative**
(maintained freely; it informs judgment, never classification) and **write-once
records** (run notes, packets, and intake's write-once breadcrumbs
`linked-branch:` / `landed:` — the note's `status:` itself still advances
`open → claimed → done | dropped`).

## `context.md` — every ref describes itself, in pure narrative

Lives **on each ref** — every work branch and the default branch. Read without a
checkout via `git show <branch-ref>:.tsugu/context.md`. It is the ref's situation
and origin told as narrative: **no `status:`, no `claimed-*`, no recorded
lineage** — those facts are derived from refs and the DAG.

- **On a work branch:** why this branch exists, current understanding, open
  questions, next actions, verification, promotion candidates — plus links to
  **this slug's own** packet and run notes (`packets/<slug>.md`,
  `runs/<slug>-<date-time>.md`). Sections: `## Why this ref exists`,
  `## Current understanding`, `## Open questions`, `## Next actions`,
  `## Verification`, `## Promotion candidates`, `## This work's files`.
- **On the default branch:** the mainline's current situation — what this repo
  is, where the mainline stands, what recently landed. `init` writes the first
  version.

**Prefer runnable evidence.** Verification should point at runnable artifacts — a
committed repro script, a failing test, a probe — over prose claims (extending
004's principle #12): the next inheritor re-runs instead of re-trusting. Narrative
explains; running code demonstrates.

**Inherit → rewrite cycle.** A new work branch cut from default inherits the
mainline `context.md`. The agent's **first act of real work rewrites it** into the
branch's own narrative — and that rewrite commit *is* the claim (its author and
timestamp are what the courtesy-yield rule reads; see `SKILL.md` C4). There is
always a `context.md`. A branch with real commits whose `context.md` is still the
inherited mainline form is simply a candidate whose narrative hasn't been written
yet; the partition needs no special rule for the file's form.

**Rewrite on merge-back (`include` mode).** Before the work branch merges,
`converge` rewrites `context.md` into the **ready-to-merge mainline narrative**:
read the default branch's current `context.md` from the fetched ref and integrate
what this work changes. The file that lands on default is **pure desired
content** — there is no state line to clean up afterwards, because "awaiting
merge" lives in the ref namespace (slug pairing), not in the file. If the PR is
instead rejected, the narrative is rewritten again at the next decision —
narrative is maintained freely; only *records* are write-once. Work-specific
history stays in this slug's keyed `runs/` and `packets/` files. Concurrent merges
may conflict on `context.md`; that conflict is meaningful (two narratives to
integrate) and is resolved by rewriting against the then-current default during
the freshness rebase.

**No lineage.** Lineage *to the mainline* is an ancestry question the DAG answers
while history is preserved; the only operation that severs it (a forced squash
merge) gets the landed-SHA record instead (`landed:` on the intake note, not a
field here). Cross-work-branch lineage is **scratch-grade** — a freshness rebase
may sever it, and that is acceptable; lineage never drives classification. A
recorded copy in any of these cases only goes stale.

**Backward compatibility.** Readers accept a legacy `branch.md` when `context.md`
is absent on a work branch. A legacy `status:` field is read once and folded into
the narrative on next touch: a legacy `status: settled` branch is a **cleanup
candidate**; a legacy `status: converged` branch is **surfaced at the next
`converge`** for its pending decision to be re-anchored (handoff branch or direct
merge).

## `intake/` — inbox-level record (two-layer model)

Durable, lives on the **coordination ref** (default = default branch) as
`intake/<slug>.md`. Intake and a branch's `context.md` describe **different
layers**, so they never contradict:

| Layer | Where | Status | Records |
| --- | --- | --- | --- |
| **Inbox** | `intake/<slug>.md` (coordination ref) | `open → claimed → done \| dropped` | *that* work entered the inbox and where it went |
| **Work** | the branch (refs + DAG) | derived from refs and the DAG (see SKILL.md partition) | the *live* work context, classified — never written |

The inbox status tracks *where the item went*; the work itself is classified from
refs and the DAG, never written — which is why two agents reading the same inbox
never see a contradictory state.

**Lifecycle.** A queue-worthy intake item = a note with `status: open` and **no
linked branch**. When an agent opens a work branch for it, the note flips to
`claimed` and records a breadcrumb in `linked-branch:` (write-once). The flip to
`done` happens **at confirmed landing**, as the **completion tail's last step
before cleanup**: promote knowledge → flip the note → only then delete the branch
(the branch is landing evidence; it outlives the flip, never the reverse). The
flip records `landed: <sha>` **only when a forced squash severed containment** —
otherwise landing is containment-derivable and no SHA is written. The `landed:`
SHA is **validated on write and on read**: it must resolve and be contained in the
fetched default ref; a `landed:` that fails either check is a reconciliation case,
never silent settlement. `dropped` records an abandoned item (record the reason
where it may matter).

The tail is **idempotent**: interrupted before the flip, the note stays `claimed`
with its branch intact and a later tidy pass re-enters the whole tail. **Absence
is never proof of success** — a `claimed` note whose linked branch vanished
*without* a recorded `landed:` or confirmable containment is a **reconciliation
case** for the human at the next `converge`, never auto-flipped to `done` or
`dropped`.

Fields: `status:`, `linked-branch:` (write-once, set when → `claimed`),
`landed:` (write-once, squash-forced landings only); sections `## Observed source`
(git-native self-note / agent-discovered / `human-bridge: <ref>`), `## Summary`,
`## Related repos`, `## Initial guess`, `## Need human context`.

**Dedup + slugs never reused.** Derive the slug from a stable identifier in the
source. If an intake note with that slug already exists at the coordination ref —
in **any** status — skip it; a `done`/`dropped` note is the durable record that
the item was already processed. Slugs are **never reused for new work** (any
intake form): a fresh ask whose slug collides with a `done`/`dropped` note or a
lingering handoff branch is surfaced at `converge` as a naming conflict, not
classified.

## `runs/` — session notes

Ephemeral, on the work branch as `runs/<slug>-<date-time>.md` (slug-keyed, so
accumulated runs on the default branch stay attributable to their work item). One
note per `prepare` session: an append-only, write-once trail of what an agent
actually did, so a later agent (or human) can reconstruct the session without the
transcript. Sections: `## Goal`, `## Context read`, `## Actions taken`,
`## Branches touched`, `## Verification`, `## Follow-up`, `## Need human context`,
`## Promotion candidates`.

## `packets/` — convergence evidence

Ephemeral, on the work branch as `packets/<slug>.md`. The **bridge to the human**
at `converge`: a concise, reviewable summary so the human reviews convergence
instead of cold-starting. Sections:

- `## Intake source`
- `## Branches prepared`
- `## What was tried`
- `## What worked`
- `## What failed`
- `## Evidence`
- `## Relevant files`
- `## Test results`
- `## Remaining uncertainties`
- `## Need human decisions`
- `## Candidate next plans` — **hints** which workflow skill fits ("ready for
  planning", "this bug needs debugging", "this can go to review-loop"). It is a
  hint for the human to act on; it **does NOT fire a skill** — Tsugu invokes none.
- `## Public actions requiring approval`
- `## Suggested handoff branch` — a name/target for the slug-paired branch
  `converge` will cut under a Handoff Prefix. The meaning depends on the mode:
  **include mode:** same commits as the work branch (merge it as-is); **exclude
  mode:** cut fresh from default, accepted changes applied by path.

## `knowledge/` — promoted knowledge

Three clauses, nothing more:

1. **Location:** `.tsugu/knowledge/` on the **coordination ref**.
2. **The promotion gate:** only deliberately promoted, durable knowledge
   enters — promotion stays an explicit act (during the completion tail), never a
   default, never a dumping ground.
3. **Internal organization belongs to the agents.** They organize, reorganize,
   and prune as they judge (each a `.tsugu/`-only commit); there is **no
   prescribed layout** — smarter future models inherit the freedom, not a frozen
   taxonomy.

**Load semantics.** After `include` merges, `runs/` and `packets/` accumulate on
the default branch as **inherited archive** — **never read them wholesale.**
Navigate via the active branch's `context.md` (which names its own files) or via
an intake note's breadcrumb. `knowledge/` is the **only deliberately curated
tier**.

## Context placement rule (omni-repo framing)

A single repo and an omni-repo are the **same abstraction** — Tsugu traverses a
tree of repos, and "where does this context belong" has one answer at any scale:

> Write context at the **lowest repo level where it remains true.** Promote upward
> (toward the omni-repo) **only** when the knowledge affects multiple repos or
> future coordination.

A fact true of one repo stays in that repo's `knowledge/`; a fact true across
several repos is promoted to the enclosing omni-repo level. This keeps an
omni-repo from becoming a junk drawer — promotion is a deliberate "this is true
more broadly now" decision, not the default.
