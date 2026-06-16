# 011 — Tsugu explore→handoff: `prepare` gathers (doesn't finalize), `converge` hands off (doesn't complete), + findings curation + a `prune` routine (schema 4, no bump)

## Relationship to 004 / 005 / 006 / 007 / 008

This spec **extends** the lineage `004 → 005 → 006 → 007 → 008`. Everything those
specs establish stands: git-native intake, derived state (refs + DAG +
containment + recency; no status fields), the no-skill-orchestration rule, the
no-force principle, the storage split (committed `.tsugu/` vs personal global
folder), the single `prepare/*` work prefix, accepted-prefixes, submodule
recursion, and the never-auto-merge / public-coordination-needs-approval
boundary.

**One inherited invariant is explicitly superseded.** 004–008 state "Tsugu never
renames a branch" (names are write-once identity, so name-level slug joins survive
forge rewrites). 011 **narrows** that: identity is the **slug**, and the slug is
never renamed. Handoff renames only the **prefix** (`prepare/<slug>` →
`<accepted-prefix>/<slug>`), preserving the slug — so the slug-join identity the
invariant protected is intact. Wherever 004–008 say "never renames a branch," read
"never renames the **slug**" post-011.

011 **re-aligns the two human-facing ends of the lifecycle to one intent — agents
explore; humans own design and completion.** It changes routine *behavior*; it is
**not a storage change**: no new committed `.tsugu/` files or directories, **no
schema bump** — the schema stays `tsugu-schema: 4`. Existing schema-4 repos remain
valid. The `public-branch-tsugu: include|exclude` **key, value, and storage are
untouched** (no schema change); what *does* change is that converge's accept no
longer branches on it — its behavioral effect narrows (see B2). The setting knob
itself is not being redesigned.

Captured from live `/tsugu:prepare` + `/tsugu:converge` use on the omni-repo,
recorded in **issues #48 (handoff-oriented converge) and #49 (prepare intent)** —
folded together here because they are the two ends of one intent.

| Line | Change | What it supersedes | Issue |
| --- | --- | --- | --- |
| A | **`prepare` intent is explicit: gather understanding, not finalize.** Investigation / root cause / option space / open questions / trade-offs / decision-free-vs-needs-human are foregrounded above producing finished code; reference code is optional and partial by design; a scope-only branch (`context.md`, no product/codebase changes) is a first-class outcome | SKILL.md `prepare`'s "tries reversible patches" framing — now states the **non-completion** intent so an agent doesn't read `prepare` as "implement the whole thing" | #49 |
| B | **`converge` accept defaults to handoff-only.** Accept **renames** `prepare/<slug>` → `<accepted-prefix>/<slug>` (move, not copy — slug preserved, prefix changed) and stops — no freshness-rebase, no verify, no `context.md` mainline rewrite, no PR. Mode-agnostic | The default accept *recipe* (rebase → verify → rewrite → push → offer PR), the separate *completion tail* (promote+cleanup) as one step, and the exclude-mode by-path clean-cut **as the default accept path**; the inherited "never renames a branch" invariant (narrowed to "never renames the slug") | #48 |
| C | **Maintenance exception: human-marked tasks may be carried to completion.** When — and only when — the human has **explicitly marked** a task maintenance-type (via the task source captured in the branch narrative, or live at converge), accept may take a **complete** path (freshness-rebase → verify → ready-to-merge). Still never auto-merges; the agent **never self-classifies** work as mechanical | n/a (new); the **default accept recipe** (freshness-rebase → verify → ready-to-merge) is **retained but re-scoped** to this path | #48 |
| D | **Findings curation is an orthogonal converge checklist item.** Surface this work's durable findings + existing `.tsugu/knowledge/` entries and ask which to organise into the agent md (`CLAUDE.md` / `AGENTS.md`); agent drafts, human approves. Enforce a `knowledge/` lean discipline (write-gate, promote-as-move, the synthesis-vs-single-commit line) | Strengthens the existing orthogonal `promote` step | #48 |
| E | **New `/tsugu:prune` routine.** A queue-wide, **human-present** sweep of unused **local + remote** branches — read-only until per-item confirmation; deletes only **settled** + **leftover-worktree** on confirmation; **surfaces-and-confirms** dropped / possibly-landed-no-containment / orphaned-accepted before any delete; surfaces stale in-progress read-only (points to converge, never deletes). Absorbs converge's dedicated stale-branch *surfacing* | converge's `housekeeping` section (dedicated stale block) — removed; stale becomes a flag on the normal candidate list + a prune read-only listing | #48 |

Everything in 004–008 not named here is unchanged. In particular: `init`'s
questions and skeleton, the partition's containment/slug-pairing reads at
`prepare` time, submodule **recursion at prepare**, and the personal-config model
are all unchanged except where a line above touches them.

## The principle (the spine)

> **The agent explores; the human owns the design and the completion.**
> `prepare` carries reasoning and evidence forward without trying to finish.
> `converge` hands the explored branch to the human and stops. The human
> re-decides the design (brainstorm → spec → plan) and chooses which workflow
> skill runs — both acts the agent must not pre-empt.

### Why the agent must not finish (the motivating failure)

A ticket is **structurally incomplete**: it omits the **undocumented human-to-human
discussion** — the architecture trade-offs and design choices that were settled in
conversation and never written down. An agent that runs such work to completion
produces something that *runs* but is **not the architecture the human wanted**,
because the deciding context was never in the agent's hands. That context **can
only be supplied by a human**. The correct cut is therefore: the agent explores up
to — but not through — the design decision, and hands the decision (and the
completion that depends on it) to the human.

This is the same philosophy SKILL.md already states ("Tsugu prepares the board.
Workflow skills play the game with the human." / "It is **not** an implementation
methodology."). The pre-011 implementation **drifted** from it on both ends:

- `prepare` could read as "implement the whole thing" (only "tries reversible
  patches" hinted otherwise) — over-investing in a "final" implementation that
  `converge` then re-brainstorms away;
- `converge`'s accept ran a **full completion tail** (freshness-rebase → verify →
  rewrite `context.md` → push → offer the PR), which made the agent (1) implicitly
  **choose** the "finish/implement" workflow and (2) **run it to completion** —
  both human-only acts.

011 pulls both ends back to the stated intent.

### The one exception the principle permits

The failure above is about **missing design context**. Work that has **no design
context to miss** — mechanical maintenance: a security upgrade, a dependency bump,
a lockfile refresh, a formatting pass — has a determinate correct outcome
(patched version, tests green), so finishing it does not risk the wrong-architecture
failure. Such work **may** be carried to completion — but the judgment "this is
mechanical" is **the human's, expressed explicitly**, never the agent's (see
Change C). The boundary that never moves regardless: **public coordination
(PR / merge / tracker) always needs human approval; Tsugu never auto-merges.**

---

## Change A — `prepare`: gather understanding, don't finalize (issue #49)

`prepare`'s purpose is **to carry understanding forward**, not to rush a complete
implementation. The skill must state this so a cold-start agent does not read
`prepare` as a mandate to implement everything.

**Foreground (above producing finished code):**

- investigation and **root cause**,
- the **option space** and its **trade-offs**,
- **open questions**,
- the **decision-free vs needs-the-human** split — which parts have a determinate
  answer and which require human design context.

**Reference code is optional and partial by design.** Working code in a prepare
branch is welcome as **proof-of-feasibility and a starting point** — it does *not*
need to be a complete implementation. It is explicitly fine to stop short of a
finished implementation; building "only enough to prove feasibility and surface
the decisions" is the target, not a shortfall.

**Scope branches are first-class.** Encourage splitting a multi-part item into
**scope branches** and **deferring product / UX / backend decisions to converge**.
A **scope-only branch** — `context.md` with the investigation, option space, and
open questions, and **no product / codebase changes** — is a **first-class prepare
outcome**, not an incomplete one. (The `context.md` commit still carries the claim,
so the branch is **not** a zero-commit / request-by-branch case — a branch whose
tip equals the default tip is never classified as a cleanup target; the scope-only
branch's `context.md` commit puts it ahead of default and reads as in-progress,
exactly as intended.)

**Reference-code review.** Heavyweight review (the human-triggered review-loop) is
for **non-trivial code the agent does write**; trivial, explicit changes just need
verification. This does not change Tsugu's no-skill-orchestration rule — the human
still triggers review-loop; `prepare` does not.

**Worked shape (the motivating case).** A 5-part requirement where the right move
was: **implement the 2 explicit decision-free items**, **scope the other 3**
(branches with `context.md`, deferred decisions), and **defer the product / backend
calls to converge**. That mixed outcome — some code, some scope-only — is a
healthy `prepare`, not a half-finished one.

**Decision-free code is still reference/proof, still handed off.** Implementing a
decision-free item during `prepare` does **not** make it "completed work." It stays
**reference / proof-of-feasibility** and is **handed off** at converge (Change B)
like any other branch — the human still re-decides and owns the landing. The *only*
path that carries work to completion is the human-marked **maintenance exception**
(Change C). So "implement the 2 decision-free items" means "prove them with working
code," not "finish and ship them" — that keeps A and C from blurring.

**Out of scope for 011:** the partition reads, the push/commit mechanics, and
submodule recursion at `prepare` are unchanged. A only edits the **framing** of
what `prepare` is *for*.

---

## Change B — `converge` accept defaults to handoff-only (issue #48)

Accept becomes a **minimal handoff**. The agent does **not** complete the work and
does **not** open an MR/PR.

### B1. Rename (move, not copy) — cold-start safe

The move renames only the **prefix**, preserving the slug. Two cases, because
`converge` may run on a machine that never had the local work branch:

```bash
# Local prepare/<slug> exists (the machine that prepared it):
git branch -m prepare/<slug> <accepted-prefix>/<slug>

# Cold start — only origin/prepare/<slug> exists (a second machine):
git branch <accepted-prefix>/<slug> <remote>/prepare/<slug>   # local create from remote-tracking
# the *move* completes when the human deletes the remote prepare/<slug> (B3)
```

"Rename" is **load-bearing**: it is a **move, not a copy** — `prepare/<slug>` does
**not** survive beside the accepted branch. Locally that means the literal
`git branch -m` (case 1); on a cold-start machine the local `prepare/<slug>` never
existed, so the move is "create the accepted branch from the remote-tracking ref +
the human deletes the remote `prepare/<slug>`" (B3) — the same logical move, just
completed across the local-create + remote-delete pair. `<accepted-prefix>` comes
from `policy.md`'s `## Accepted Prefixes` (default `feature/* bugfix/* chore/*` —
examples below use `feature/<slug>`). The **slug is preserved**; per the superseded
invariant (top), only the prefix changes. **Before renaming/creating, resolve the
accepted prefix and check no `<accepted-prefix>/<slug>` already exists** (local or
remote) — a collision means the slug is already in handoff/flight; surface it rather
than clobber.

The agent does **NOT**: freshness-rebase, build/test, rewrite `context.md` to a
mainline narrative, push, or open a PR.

### B1a. The handoff-pending window — guarded by the existing partition (no new marker)

Between the local rename (B1) and the human's remote reconcile (B3), the remote
`origin/prepare/<slug>` **still exists** (the agent doesn't delete it — B3 is the
human's). A scheduled `prepare` would otherwise **rediscover `origin/prepare/<slug>`
and resume already-handed-off work.** 011 adds **no new marker** for this — the
**existing two-fact partition already guards it**, checked in this order:

1. **Containment (settled).** `git merge-base --is-ancestor <prepare-tip>
   <remote>/<default>`. After a **merge-commit landing** (tsugu's recommended,
   never-squash policy), the work tip is contained in default, so the work branch is
   **settled** — even if the human **forgot to delete the remote `prepare/<slug>`**
   and the accepted branch is already gone. It is skipped as in-progress and becomes a
   `prune` target. **Cost is negligible:** this `--is-ancestor` is *already* computed
   per work branch by the partition (it is partition row 1) — no new comparison.
2. **Slug-pairing (decided / awaiting-merge).** A same-slug branch under a configured
   accepted prefix classifies `prepare/<slug>` as decided → skip. This covers the live
   handoff window: on the converge machine the **local** `<accepted-prefix>/<slug>`
   created by B1 pairs immediately; remotely it pairs once the human pushes (B3). For
   this to hold same-machine, the partition must **enumerate accepted-prefix branches
   across local + remote refs** (state this in `git-recipes.md`), so the local
   accepted branch counts before it is pushed.

**The two facts fully guard every landing that follows tsugu's two merge
recommendations** — *merge-commit (never squash) tsugu-managed branches* **and**
*retain the accepted branch (disable forge auto-delete) until cleanup*. Under those:
a merge-commit landing keeps the work tip contained (fact 1); a retained accepted
branch keeps the slug pair alive (fact 2). At least one always holds, so a scheduled
`prepare` never resumes handed-off work.

**The residual is not over-claimed as guarded.** When the human goes *against* both
recommendations — a **history-rewriting landing** (squash / rebase / force) **and**
the accepted branch deleted — neither fact holds: containment can't confirm and
there's no slug pair. (The **maintenance complete path** makes this reachable even
with a merge commit, because its freshness-rebase changes the accepted tip away from
the stale remote `prepare/<slug>` tip — so there the guard is specifically *retain
the accepted branch* / fact 2, not containment.) In the residual, 011 does **not**
claim a scheduled `prepare` is auto-guarded; instead:

- `prepare`'s **judgment leans conservative** — a `prepare/<slug>` it can neither
  confirm in-progress (no recent claim) nor classify settled/decided should be
  **left for `converge`**, not auto-resumed (the posture 004–008 already takes for
  out-of-band PR closure: work resurfaces, surfaced at the next `converge`, never
  auto-resumed to completion). Re-exploration is **reversible private git work and
  never auto-merges**, so the cost of a wrong guess is bounded.
- `prune`'s *possibly-landed (no containment) — confirm* bucket (E2) and the human
  are the authoritative recourse.

This is the **same guarantee level 004–008 already give for history-rewriting
landings** — 011 introduces nothing weaker, and adds no polluting marker. The
**cross-machine, accepted-still-unpushed** window (machine A holds the local accepted
branch, machine B runs `prepare` before B3) is the **deferred multi-agent concurrency
case** tsugu already scopes out ("no locks; two agents grabbing the same branch is
undefined today").

### B2. Mode-agnostic

The rename is identical under `public-branch-tsugu: include` and `exclude`. The
exclude-mode **by-path clean-cut** accept path is **removed** — it was part of the
default accept recipe. The `.tsugu/` exploration commits ride along on
`<accepted-prefix>/<slug>`; since the **human now owns everything after handoff**,
the human decides whether to strip `.tsugu/` when *they* open their public PR.

**This is an explicit narrowing of `exclude`, not "untouched."** The setting is not
removed (no schema change), but its **scope shrinks**: pre-011 it governed both (a)
whether `.tsugu/` rode the default branch **and** (b) whether converge's accepted /
handoff branch was cut `.tsugu/`-free. 011 drops (b) entirely — converge no longer
cuts a clean public branch — and keeps only (a). An `exclude`-mode repo that
depended on tsugu producing a `.tsugu/`-free handoff branch must now do that
stripping itself when the human opens the public PR. Stated plainly so no repo is
surprised by `.tsugu/` riding the renamed branch.

### B3. Remote reconcile is a prompt, never a silent op

After the local rename, the remote still has the stale `prepare/<slug>` and lacks
`<accepted-prefix>/<slug>`. The agent **surfaces the commands for the human** —
public/remote coordination stays human-approved:

```bash
git push --set-upstream <remote> <accepted-prefix>/<slug>
git push <remote> --delete prepare/<slug>
```

The agent prints these (resolving `<remote>`); it does **not** run them.

### B4. End-of-handoff prune reminder

Close the handoff with: *"handed off; once you've pushed `<accepted-prefix>/<slug>`
and the work lands, run `/tsugu:prune` to sweep the stale `prepare/<slug>` and the
settled branch."* No branch is prunable **at handoff time** — at that moment the
human hasn't yet pushed the accepted branch (B3 is a prompt they may defer) and
nothing has landed, so a "N branches now prunable" count would be 0 / indeterminate.
The reminder points at `prune` for *later*; it does not assert a current count.

### B5. Settlement / slug-pairing tracking is dropped

After the rename, the **local** `prepare/<slug>` no longer exists. The item leaves
`prepare`'s queue **once the remote work ref is gone** — i.e. after the human's B3
remote-delete (the queue reads remote-tracking work refs, so until then
`origin/prepare/<slug>` keeps the item nominally in the queue; the **existing
partition** is what keeps a scheduled `prepare` from resuming it — settled via
containment, or decided via slug-pairing against the local/remote accepted branch,
per B1a). Once the remote `prepare/<slug>` is deleted there is no longer a work ref
to track, and no work-branch ↔ accepted-branch slug pair.

**The old "Completion tail" step is dissolved, not merely "not run."** Pre-011 the
SKILL.md "Completion tail" bullet did two things after a landing: **promote**
findings into `knowledge/` and **clean up** worktrees/branches. 011 re-homes both:
**promotion → curation (Change D)** and **cleanup → `prune` (Change E)**. So
`converge` keeps **no** named completion tail of its own. ("Complete path" in 011
refers *only* to the human-marked maintenance recipe — Change C — never to this
dissolved promote+cleanup step.)

Whether `<accepted-prefix>/<slug>` later lands is **the human's** concern. Its
settled-ness is read **later, by `prune`** (Change E), not actively tracked by
`converge`. Where the human merged with history intact, settlement is **derivable**
(tip contained in default); where the human squashed / rebased / stripped `.tsugu/`,
containment will not hold even though the work landed — `prune` handles that via its
*possibly-landed (no containment) — confirm* bucket (E2), never an auto-delete on a
guess. Consistent with the invariant: state stays derived from refs/DAG/containment
(plus a present human's confirmation where derivation can't reach), never a status
field.

---

## Change C — Maintenance exception: human-marked completion (issue #48)

The default is handoff (B). The **complete** path — freshness-rebase → verify →
ready-to-merge — is unlocked **only when the human has explicitly marked the task
as maintenance-type**. Two designation channels:

1. **Human-authored task-source designation.** The marking must trace to an
   **explicit human act** — a human who *set* the task's maintenance designation (a
   label/field a person applied, or a task a person filed *as* maintenance). It is
   captured at intake and recorded **verbatim** in the branch's `context.md`
   narrative — e.g. *"human-marked maintenance (security upgrade) — completion
   authorized; source: <where the human marked it>."* This is **narrative that
   informs judgment**, not a status field (consistent with the spine).
   **The agent must not synthesize the designation from the work's content** — a
   diff that *looks* like a dependency bump is **not** self-authorization; only a
   human's explicit marking is. (This closes the loophole where the agent
   effectively self-classifies by reading a generic label as permission.) Channel 1
   requires a source present at `prepare` time; a **headless / git-native-degraded**
   `prepare` has no tracker source, so on those runs **only channel 2 is available**.
   **Provenance fallback:** if the agent cannot tell whether a label was applied by a
   human or by automation, it **does not treat it as authorization** — it falls back
   to channel 2 (ask the human live at converge). Ambiguous provenance defaults to
   handoff, never completion.
2. **Live at converge.** The human, present, says "this one's maintenance — take it
   to completion."

Absent an explicit human marking → **default handoff (B)**. The agent **never
self-classifies** a task as mechanical. (Protecting exactly the failure mode in the
spine: the agent must not decide on its own that something is "mechanical enough"
to finish.)

### The complete path (the re-scoped maintenance recipe)

When unlocked, accept proceeds in this exact order:

1. **Rename first, same as B1** — `prepare/<slug>` → `<accepted-prefix>/<slug>`
   (move, cold-start safe). The complete path is *handoff + extra prep on the
   renamed branch*, not a different branch model; `prepare/<slug>` is gone either way.
2. **Freshness-rebase** onto the fetched default, **verify** (build/tests), **bring
   to ready-to-merge.**
3. **`context.md` may be rewritten** to a ready-to-merge mainline narrative here
   (unlike the default handoff, this branch is heading to merge), at the agent's
   discretion.
4. **Surface the same B3 remote-reconcile prompt and the B4 prune pointer** — the
   maintenance path still hands the public coordination to the human.

The human then merges (or opens/approves the PR). **Tsugu still never auto-merges**;
PR/merge stays human-approved — the maintenance exception relaxes "don't finish the
*work*," **never** the public-coordination boundary. Mode-agnostic, same as B2.
Cleanup of the resulting branches is **deferred to `prune`** (or, if the human
merges on the spot, `prune` sweeps the settled ref later).

**"Ready-to-merge" means accepted-branch readiness, not a clean public diff.** It
means the branch is rebased onto the fetched default and builds/tests pass — i.e.
*the work is done and current*. It does **not** mean exclude-mode's old
`.tsugu/`-free public branch: under B2 the `.tsugu/` commits ride the accepted
branch in both modes, so an `exclude`-mode repo's human still strips `.tsugu/` when
they open the public PR (the maintenance path does not resurrect the by-path
clean-cut). Publishing remains the human's act either way.

The previously-default freshness-rebase + verify + ready-to-merge recipe in
`references/git-recipes.md` is therefore **retained but re-scoped** to this path,
with its unlock condition stated. The exclude-mode by-path clean-cut and the
agent-driven completion tail (as a default) are removed.

---

## Change D — Findings curation: orthogonal converge checklist item (issue #48)

Curation is **orthogonal** — like the existing `promote`, it rides any disposition
and may also run standalone in the morning view; it is **not** a fifth pick-one
verb. It fires at handoff and when the human runs `converge` just to curate. When
there is nothing worth promoting, it is a no-op.

**Curation does not contradict "hand off and stop."** "Stop" governs the *work*
(the agent doesn't complete the feature); it does **not** mean converge skips its
human-present checklist. Curation is one such checklist item — **human-confirmed,
human-approved**, run within the same converge session. The agent never edits the
agent md without the human picking the findings and approving the draft, so this
adds no autonomous completion.

**Flow:** surface (a) this work's durable findings (from the branch's `context.md`
/ knowledge additions) and (b) existing `.tsugu/knowledge/` entries → ask the human
**which should be organised into the agent md** (`CLAUDE.md` / `AGENTS.md`) → the
**agent drafts** the md edit → the **human approves** (moving findings into
human-facing docs is public coordination → ask first).

**The `knowledge/` ↔ agent-md boundary (a finding lives in exactly one place).**
The two stores are not interchangeable, and "promote" runs in one direction only:

- **`knowledge/`** holds **WIP, still-evolving, cross-cutting** agent-shared findings
  — the working wiki of an in-flight or recently-finished investigation.
- **The agent md (`CLAUDE.md` / `AGENTS.md`)** holds **durable, stabilised,
  human-endorsed conventions** — rules a person has signed off on as standing
  guidance.
- **Promote = graduate `knowledge/` → agent md**, once a finding has **stabilised
  into a durable convention** and the human endorses it. There is no reverse
  direction. The **write-gate** keeps not-yet-durable findings out of the agent md
  and keeps already-recorded facts out of `knowledge/`; **promote-as-move** removes
  the finding from `knowledge/` on graduation. Together they guarantee a finding
  sits in **one** place, never both — which is the drift this discipline prevents.

**`knowledge/` lean discipline** (the same rule a good memory system follows —
*don't record what the repo already records*):

- **Write-gate.** Before **writing** a finding **into** `knowledge/`, check it isn't
  already in a commit message / derivable from the DAG, or already in `CLAUDE.md` /
  `AGENTS.md`. If it is → **don't duplicate.** (This is the entry gate to
  `knowledge/`, distinct from "promote," which is the one-way exit `knowledge/` →
  agent md defined below.)
- **Promote = move, not copy.** Once a finding graduates **into** the agent md,
  **remove it from `knowledge/`** (leave at most a pointer) — no two drifting copies.
- **The line (so culling doesn't over-delete).** *Don't restate a single commit*
  (history has it). *Do keep cross-commit synthesis and the "why" no single commit
  holds* — e.g. "these 4 fixes share root cause X"; "this gotcha spans explore-ui
  and portal-api." git history is durable but not legible at a glance; that
  synthesis is exactly what `knowledge/` is for.
- **Optional cull.** Converge **may** surface `knowledge/` entries gone redundant
  (already promoted, or merely restating a commit) and offer to remove them.

---

## Change E — `/tsugu:prune` (new routine, issue #48)

A **fourth** routine. It is **not** part of the per-item lifecycle the way
`prepare` / `converge` are, and `init` is one-time setup — `prune` is a **recurring
cleanup pass** the human runs when refs have piled up. A queue-wide, **human-present**
sweep of unused branches (**local + remote**) — the home for the destructive
cleanup that per-branch `converge` (now handoff-only, no tail) and a never-cleaning
scheduled `prepare` leave to accumulate. **Small: a view + approve-delete, not a new
workflow.**

### E1. Read-only until the human confirms; human-present by construction

Like the morning view, steps before deletion touch no state. `prune` lists what is
removable and **why**, derived from refs / DAG / containment / recency. **`prune` is
a human-present routine and deletes nothing without per-item human confirmation** —
this is what keeps it consistent with the spine: a narrative hint like "do not
resume" is **surfaced for the present human to confirm**, never an auto-classifier
that deletes on its own. *Judgment by a present human, not classification by a
status field.*

### E2. What `prune` lists, and how each is handled

`prune` is **conservative by default** — under the handoff model the human owns the
branch after the rename, so most categories are **surface-and-confirm**, not
auto-eligible. Only two categories carry a low enough risk to delete directly on a
yes:

| Category | Derivation | Handling |
| --- | --- | --- |
| **settled** | tip contained in `<remote>/<default>` (`git merge-base --is-ancestor`) — the human merged with history intact | **delete on confirm** (low risk — provably landed). Local + remote. The main post-handoff target |
| **leftover worktree** | a worktree directory whose branch is already deleted | **delete on confirm** (low risk — just a stale checkout dir) |
| **possibly-landed (no containment)** | a surviving `<accepted-prefix>/<slug>` ref (local and/or remote, or just a leftover worktree) whose **tip is not contained** in default, **and** whose remote counterpart has been deleted (a merge that squashed / rebased / stripped, so containment can't confirm) — i.e. the ref exists but containment is silent | **surface + confirm each** — `prune` cannot prove it landed, so it asks; never auto-deletes on a guess |
| **dropped** | the branch's `context.md` narrative says "do not resume" | **surface + confirm** — the narrative is a *hint* the present human confirms (E1). Usually converge's `drop` already deleted the branch; this only catches the ones `drop` couldn't remove (a deferred or remote ref) |
| **orphaned accepted** | a pushed accepted branch with no open PR and no recent activity | **surface read-only + confirm** — under handoff this is often the human's **live** work branch, so it is *never* auto-eligible; delete only on explicit confirmation |

**Reconciliation with converge's `drop`.** `drop` (a converge disposition) still
records the reason and deletes the branch in-session when safe; `prune`'s *dropped*
row is the **backstop** for branches `drop` recorded but could not delete (e.g. a
remote ref, or a deferred cleanup) — not a second, divergent classifier.

Deletion is **per-item or batch**, on explicit confirmation. **Remote deletes:
`prune` runs `git push <remote> --delete <branch>` after explicit per-item human
confirmation** (the confirmation *is* the approval — `prune` is the human-present
approve-delete gate). This differs deliberately from converge **B3**, which only
*prints* the remote-delete command: at B3 the precondition isn't met yet (the human
hasn't pushed the accepted branch) and converge is mid-handoff, not a cleanup gate.
The unifying rule: **no remote delete without explicit human approval** — `prune`
obtains it per-item and acts; B3 surfaces and waits. **B3 vs `prune` are not
redundant:** B3 is the *immediate, optional* command the human may run right at
handoff (push the accepted branch, delete the stale remote `prepare/<slug>`);
`prune` is the *later, guided* cleanup pass that sweeps whatever B3 left behind (and
everything else that accumulated). A human who runs B3 promptly simply has less for
`prune` to find. Cleanup order is the established one: `git worktree remove`
**before** `git branch --delete`.

### E3. Conservative — never touches unfinished work

`prune` **never deletes** in-progress, recent, or unsettled work. **Stale
in-progress** branches (older than `stale-after`, but not landed) — including
**scope-only branches** (Change A), handled identically to code branches here — are
**surfaced read-only** and marked *"not deletable here — decide at `converge`."*
`prune` only *points*; the resume / park / drop decision happens in `converge`'s
normal candidate flow.

### E4. converge's dedicated housekeeping section is removed

The stale-branch *surfacing* that converge did in a dedicated `housekeeping` block
moves to `prune` (E3). In `converge`, staleness becomes a **flag on the normal
candidate list** (a candidate whose last activity predates `stale-after` is shown
with a "stale" marker), handled by the usual accept / park / drop / continue
dispositions. No new state; staleness stays derived from last-commit recency.

---

## Submodule consequence (within Change B's scope)

`converge`'s **bare-submodule accept** is today an agent-driven **ordered two-repo
landing transaction** (land the submodule PR → re-point the meta gitlink → land the
meta PR; `references/advanced.md`). Under handoff-only this also becomes a
**handoff**:

- At submodule converge, the submodule's `prepare/<slug>` is simply **renamed to a
  human work branch** (`<accepted-prefix>/<slug>`) **in the submodule**, and stops.
- **The meta repo no longer manages it** — to the meta repo it is just "a human
  work branch now exists in the submodule." No agent-driven gitlink re-point, no
  two-repo transaction.
- The cross-repo landing (gitlink bump, both PRs) is **the human's** when they
  finish the work — not the agent's.
- **The existing paired meta `prepare/<slug>`** (a bare submodule's findings ride a
  meta branch carrying the gitlink bump + `context.md`, per 008) is **not
  auto-managed at submodule converge** — the agent does not rename, land, or delete
  it as part of handing off the submodule branch. It remains a normal candidate that
  surfaces at the **meta** repo's own `converge` (and at `prune`), where the human
  decides its disposition. Handing off the submodule branch and handling the meta
  branch are **decoupled**, consistent with "meta no longer manages it." The meta
  paired branch is classified by the **same existing meta partition** (containment of
  its tip in the meta default, then slug-pairing) — no new marker; a scheduled meta
  `prepare` leaves a settled or decided paired branch exactly as B1a describes for the
  primary case.

The maintenance exception (Change C) can still apply per-repo if the human marked
that work maintenance-type. The `references/advanced.md` "Bare-submodule two-repo
landing" section is **removed / reduced to "hand off; the human owns the cross-repo
landing."**

---

## State model (unchanged invariant, restated for clarity)

None of the dispositions sets a **status field**. Each produces a branch action
(handoff rename / complete / drop's delete / prune delete-on-confirm), a narrative
write (park, drop's reason, the maintenance authorization), or a knowledge/agent-md
write (curation). The handoff-pending window adds **no marker** — it is guarded by
the existing partition (containment, then slug-pairing; B1a). Every narrative marker
that does exist (the maintenance authorization, drop's reason) **informs a scheduled
agent's or a present human's judgment** — none is read as a status that
auto-classifies the branch. State stays **derived** from refs, the DAG, containment,
and recency. *Narrative informs judgment, never classification.* The lifecycle is now:

```
init → prepare (gather, don't finalize) → converge (hand off + curate;
       complete only if human-marked maintenance) → [human re-brainstorms,
       finishes, opens MR] → prune (sweep what's done)
```

---

## Files touched

| File | Change |
| --- | --- |
| `plugins/tsugu/skills/tsugu/SKILL.md` | **frontmatter `name`/`description`** (hardcodes "init/prepare/converge" — must add `prune`); `prepare` framing (A); `converge` accept → handoff (B) + maintenance exception (C); curation as orthogonal item + the `knowledge/`↔agent-md boundary (D); add `prune` routine (E); remove converge's dedicated housekeeping block (E4); supersede "never renames a branch" → "never renames the slug"; submodule converge → handoff |
| `plugins/tsugu/commands/converge.md` | update description (handoff-only; complete only on human-marked maintenance; points to `prune`) |
| `plugins/tsugu/commands/prune.md` | **new** command file |
| `plugins/tsugu/skills/tsugu/references/git-recipes.md` | remove the default accept recipe + exclude-mode by-path clean-cut + the `## Completion tail` step; **retain + re-scope** the freshness-rebase/verify/ready-to-merge recipe to the maintenance path; add the cold-start-safe handoff rename recipe + the `prune` sweep recipe; **state that the partition enumerates accepted-prefix branches across local + remote refs** (so the converge machine's local accepted branch pairs before B3 push — B1a fact 2); **sweep all `## Completion tail` references** (the `[Completion tail](#completion-tail)` cross-ref at git-recipes.md:98 **and** the partition-table "completion-tail / cleanup candidate" cell at git-recipes.md:148 — the settled cleanup sweep now lives in `prune`); keep the `prepare`-side Freshness + Cleanup-order sections |
| `plugins/tsugu/skills/tsugu/references/advanced.md` | reduce the "Bare-submodule two-repo landing" section to handoff |
| `plugins/tsugu/skills/tsugu/references/notes-and-packet.md` | curation discipline (write-gate, promote-as-move, the line) + the `knowledge/`↔agent-md boundary for `knowledge/` |
| `.claude-plugin/marketplace.json` | bump tsugu version `0.5.0 → 0.6.0` (behavioral; **no schema bump**); **description update required** — both `plugin.json` and the marketplace entry enumerate "three slash commands" / init-prepare-converge |
| `plugins/tsugu/.claude-plugin/plugin.json` | **description update required** (four routines; converge = handoff) |
| `CLAUDE.md` (project) | tsugu summary: three routines → four; converge = handoff |

In the agent-md rows above, "agent md" means **the project's agent-md file —
`CLAUDE.md` and/or `AGENTS.md`, whichever the repo uses** (curation targets the one
present, or asks which when both exist).

**No schema migration.** `tsugu-schema` stays `4`; committed `.tsugu/` structure
(`policy.md` + `context.md` + `knowledge/`) is unchanged; `public-branch-tsugu`'s
key/value/storage is untouched (only its converge-accept effect narrows — see B2).

## Closes

`#48` (handoff-oriented converge + findings curation + `prune`) and `#49`
(`prepare` intent: gather, don't finalize).
