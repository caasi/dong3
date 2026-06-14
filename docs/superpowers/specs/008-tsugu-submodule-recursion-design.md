# 008 — Tsugu submodule recursion: `prepare` recurses on `.tsugu/` presence; branch at the lowest code-owning repo (schema 4, no bump)

## Relationship to 004 / 005 / 006 / 007

This spec **extends** `007-tsugu-thin-core-design.md` (which extended 006 → 005 →
004). The whole lineage stands: git-native intake, derived state, the
no-skill-orchestration rule, the no-force principle, the storage split
(committed `.tsugu/` vs personal global folder), the single `prepare/*` work
prefix, accepted-prefixes, and the accept / park / drop dispositions.

008 **operationalizes omni-repo recursion**, which 007 named as in-core but never
turned into routine steps. It adds operational steps to `prepare` and `init` and
expands the existing `## Recursion` policy prose. It is **not a storage change**:
no new committed `.tsugu/` files or directories, **no schema bump** — the schema
stays `tsugu-schema: 4`. Existing schema-4 repos remain valid; recursion reads
`.tsugu/` presence at runtime. Captured from a live `/tsugu:prepare` incident on
the `omni` meta-repo recorded in issue #40.

| Line | Change | What it supersedes |
| --- | --- | --- |
| A | **`prepare` recurses on `.tsugu/` presence.** New routine step: enumerate submodules, gate on presence of `.tsugu/policy.md`, and for a `.tsugu/`-bearing submodule **recurse-and-run** (run the submodule's own prepare with its own policy + personal-config intake) | SKILL.md `## Scheduling & recursion`'s principle-only "recurse into submodules only when relevant" — now operationalized |
| B | **Branch always lands at the lowest code-owning repo.** A submodule-owned ticket branches **inside the submodule**, whether or not it has `.tsugu/`. The meta-repo never branches submodule-owned code at the meta level | The issue's original framing ("meta-repo MAY open `prepare/<slug>` at meta level" for bare submodules) — refined per maintainer guidance |
| C | **Bare-submodule paired meta branch.** When a submodule has **no** `.tsugu/`, its findings bubble up to the **meta** `.tsugu/` via a paired meta `prepare/<slug>` whose commit **bumps the gitlink** to the prepared submodule tip and carries `context.md`. No `.tsugu/` folder is created in the bare submodule | n/a (new) |
| D | **Source-scoping guidance.** Each repo's intake should be scoped to work it owns; overlapping the same tracker board at the meta level is named as the incident's anti-pattern. Guidance only — no central router, no defer/skip guard | n/a (new); the incident's root cause |
| E | **`init` graduation.** `/tsugu:init [<submodule-path>]` brings a bare submodule under control; when an enclosing tsugu-managed omni-repo is detected, it offers to **cut submodule-specific knowledge down** (human-confirmed, knowledge only). In-flight paired meta branches are left to finish at meta `converge` | n/a (new) |

Everything in 004–007 not named here is unchanged.

## The principle (the spine)

> **The branch lands at the lowest repo that owns the code; the `.tsugu/`
> knowledge lands at the lowest repo that *has* a `.tsugu/`.**

These two "lowest level" rules are distinct, and conflating them is what produced
the incident. Code belongs where it is edited and handed off (the submodule).
Knowledge belongs where there is a place to write it — the submodule's own
`.tsugu/` if it has one, otherwise the enclosing omni-repo's `.tsugu/`. A bare
submodule has no knowledge layer, so its findings bubble **up**; its code stays
**down**.

This is the same context-placement rule 007/notes-and-packet already states
("write context at the lowest repo level where it stays true"), made precise for
the submodule case: *true* is read against the repo that actually carries a
`.tsugu/`.

### The ownership signal

A submodule's `.tsugu/` — precisely, a **readable `.tsugu/policy.md`** (the exact
test, see below) — **is** the human's claim "this repo owns its own prepare
queue." Throughout this spec "`.tsugu/` presence" is shorthand for that test.
Detection is mechanical — enumerate submodules, test for `.tsugu/policy.md`; that
boolean decides recurse-vs-meta-drive per submodule.
Nothing else (component fields, a routing table, JQL inspection, the submodule's
own policy) is consulted to decide ownership — adding a **readable
`.tsugu/policy.md`** *is* the opt-in, not merely a `.tsugu/` directory; a
malformed or partial `.tsugu/` without a readable `policy.md` is **not** a valid
signal: surface it, never silently treat it as bare. A submodule never separately opts out of being recursed-into.
(Whether the parent *descends at all* is a **separate** question, governed by the
parent's own `## Recursion` toggle — see A2.)

## The case table

| Submodule state | Branch (code) | `.tsugu/` knowledge | Intake / policy used | Lifecycle owner |
| --- | --- | --- | --- | --- |
| **HAS `.tsugu/`** | `prepare/<slug>` in the submodule | the submodule's own `.tsugu/` | the submodule's own (recurse-and-run) | the submodule (its own `converge`) |
| **No `.tsugu/`** | `prepare/<slug>` in the submodule (no `.tsugu/` created there) | the **meta** `.tsugu/`, via a **paired meta `prepare/<slug>`** (gitlink bump + `context.md`) | the meta-repo's intake / policy | the meta-repo (`converge` sees the paired branch) |
| **Meta-level code** (gitlink / pin bumps, omni docs) | `prepare/<slug>` in the meta-repo | the meta `.tsugu/` | the meta-repo's | the meta-repo |

The slug joins everything as always: in the bare case, one slug joins the
meta-side `context.md` to the submodule-side code branch.

## A — `prepare` recurses on `.tsugu/` presence

### A1 — The recurse-and-run model (HAS `.tsugu/`)

"Recurse" means **run the full `prepare` routine inside the submodule, treating
it as its own repo.** This works because tsugu already keys personal config on
the **common git dir** (007/006): a submodule has its own git dir, so it already
gets its own project-key → its own `~/.claude/tsugu/<submodule-key>/` with its
own intake sources. Consequences fall out for free:

- The submodule's prepare reads **its own** `policy.md` — work/accepted prefixes,
  `## Push`, `default-branch` (e.g. explore-ui's `develop`, not `main`), CI-skip
  conventions (e.g. explore-ui requires `[ci skip]` for `.tsugu`-only commits).
- **Ownership is emergent** — "the submodule's own intake claimed it." No central
  component→repo router exists or is needed.
- The submodule's own queue read **continues an existing `prepare/<slug>`**
  instead of duplicating it (fixes the EXP-5978 duplicate from the incident).
- **Scope boundaries are respected emergently.** The submodule's prepare reads
  *its own* `context.md` scope boundaries: explore-ui's prepare never sees
  EXP-5967 (excluded in its own `context.md` / out of its board scope), while
  exp-graph-parser-ui's own intake pulls EXP-5967 and branches it there. The
  issue's "read all candidate submodules' `context.md` from a central router"
  open question **dissolves** — no central router needs to.
- **Intake is per-machine bootstrapped.** Recurse-and-run reads the submodule's
  sources only if that submodule's personal config was already bootstrapped on
  *this* machine — the bootstrap is **interactive-only** (007 §F), while
  recursion is the human-absent path. On a fresh provisioned machine an
  un-bootstrapped submodule degrades to git-native (no tracker intake) and
  surfaces "personal config unconfigured" at that submodule's next same-machine
  `converge`. Recursion does not block on it.

### A2 — Traversal mechanics (the new `prepare` step)

After the meta-repo works its own queue (existing `prepare` steps), a new step:

1. **Enumerate submodules** — `git submodule status` / `.gitmodules`. Recursion
   operates on **initialized** working trees (the presence test needs a
   checked-out tree); an uninitialized submodule (`git submodule status` shows a
   `-` prefix) is either initialized (`git submodule update --init <path>`) before
   gating or **skipped with a surfaced note** — never silently treated as bare (it
   may actually carry `.tsugu/` once checked out, and mis-driving it at the meta
   level is exactly the incident).
2. **Gate** — for each, test presence of `.tsugu/policy.md` (the ownership
   signal).
3. **Recurse** — for each `.tsugu/`-bearing submodule, run the `prepare` routine
   inside it via `git -C <submodule-path>` (optionally dispatched as a built-in
   Task subagent per submodule for isolation / parallelism). Whether the parent
   **descends at all** is governed by the **parent's own** `## Recursion` toggle
   ("only when relevant"); once descending, `.tsugu/` presence **alone** decides
   recurse-vs-meta-drive — the submodule's own policy is never consulted to gate
   being recursed-into.
4. **Schema-agnostic.** The submodule runs at its **own** schema; recursion does
   **not** force-migrate a schema-3 submodule. Its own prepare semantics apply.
5. **Depth-first to arbitrary depth** — a single repo and an omni-repo are the
   same abstraction at any scale. At each level the **enclosing** repo's
   `## Recursion` toggle decides whether to descend ("only when relevant" keeps
   the traversal scoped rather than descending into every nested repo
   unconditionally); a descended submodule's `.tsugu/` presence then decides
   recurse-vs-meta-drive for it. **Arbitrary depth holds for *managed* chains** —
   every level that carries its own `.tsugu/` recurse-and-runs and descends per its
   own `## Recursion`. **A bare level, however, is driven only one level deep:** the
   meta run may meta-drive a *direct* bare child (the one-level case the incident
   exercised), but anything **nested beneath a bare child** — bare or managed — is
   **surfaced, not driven**; driving it would turn the two-repo accept into an
   N-repo gitlink-chain transaction (out of scope — see Limitations). `prepare`
   notes such a nested subtree and leaves it for the human to restructure (e.g.
   `init` an intervening level to bring it under management).

## B / C — Bare-submodule paired meta branch (no `.tsugu/`)

When a ticket's code lives in a submodule that has **no** `.tsugu/`, the
meta-repo drives the work but the **branch still lands in the submodule** (easy
handoff: the human `cd`s into the submodule and the `prepare/<slug>` branch is
right there). No `.tsugu/` folder is created in the bare submodule. The findings
bubble up to the meta `.tsugu/` through a **paired meta branch**:

1. **Discover** the ticket via the **meta-repo's** intake (the bare submodule has
   no intake of its own).
2. **Do the git work inside the submodule checkout** — create `prepare/<slug>` in
   the submodule, reproduce, test, patch, commit. The submodule has no
   `.tsugu/policy.md`, so the **meta** `policy.md` governs every tsugu rule for
   this branch — work prefix, accepted prefix, push permission, freshness. The
   only fact taken from the submodule is its **actual** default branch, detected
   at runtime (`git -C <sub> symbolic-ref refs/remotes/<remote>/HEAD`).
   **Ask, don't guess:** when detection is ambiguous (no `…/HEAD`, multiple
   remotes) or a needed rule isn't covered by meta policy, **ask the human** if
   interactive; if headless, **leave the item unbranched** and surface it at the
   next `converge` rather than guessing. (A submodule with genuinely special
   conventions — a `[ci skip]` requirement, a non-`main` default — is a signal it
   should *graduate* to its own `.tsugu/` (E) so its policy has an authoritative
   home, instead of the meta run guessing.)
3. **Carry the findings on a paired meta branch** — create `prepare/<slug>` in the
   meta-repo (same slug) whose commit **bumps the submodule gitlink** to the
   prepared submodule tip **and** writes `.tsugu/context.md` narrating the work +
   pointing at the submodule branch (name + SHA). Durable findings promote to the
   meta `knowledge/`.
4. **Push** each branch where its repo's policy permits.

**Handoff bonus:** checking out the meta `prepare/<slug>` and running
`git submodule update` lands the submodule at the **prepared commit** — a
**detached HEAD** at the recorded gitlink SHA, *not* checked out on
`prepare/<slug>` (which may not even exist locally until fetched). To resume on
the named branch the human runs `git -C <sub> checkout prepare/<slug>` (the meta
`context.md` records its name + SHA). Even so, one meta checkout reflects the
whole prepared omni state.

**Surfacing.** The meta queue read (`git for-each-ref` over *meta* refs) sees the
paired meta `prepare/<slug>` naturally — so meta `converge` lists it as an
ordinary in-progress candidate. (A submodule-only ref would be invisible to the
meta repo, which is why the paired meta branch is required, not optional.)

### Converge of a bare-submodule item (two-repo landing)

This is the only `converge` change in 008. The paired meta branch's `context.md`
narrates the work and points at the submodule branch (name + SHA). The **accept**
is an **ordered, two-repo transaction** — *not* two independent accepts — because
the meta commit pins a submodule SHA, and the submodule's **landed** SHA differs
from the prepare-time tip (a merge commit, or a fresh SHA under squash/rebase).
Human-driven throughout (Tsugu never auto-merges):

1. **Land the submodule first** — open/merge the submodule forge's PR from an
   accepted-prefix branch named per **meta** policy's `## Accepted Prefixes` (same
   slug). Resolve the **landed** submodule SHA.
2. **Re-point, then land meta** — on the meta accepted branch (same slug), bump
   the gitlink to the submodule's **default-branch tip that now contains the
   landed work** — *not* the prepare-time tip, and *not* a bare ancestor SHA. The
   default tip also carries anything else landed meanwhile (e.g. a graduation
   `.tsugu/` commit); re-pointing to a pre-graduation ancestor would pass
   reachability yet silently **un-graduate** the submodule. (Pinning the default
   tip is ordinary submodule-bump coupling — the meta pin advances to whatever the
   submodule default holds at accept time; if isolating the exact work matters,
   pin a specific commit that contains the landed work + graduation instead.)
   Carry the final `context.md`; **open** the meta PR. **Then, immediately before
   merging it, re-validate against current meta default** — graduation or another
   bump may have landed since this step — and confirm the target still contains all
   required submodule commits; if not, update the gitlink onto the now-current
   default tip first, so the meta merge never overwrites a newer legitimate bump.
3. **Settlement is conjunctive and mechanically verified** — settled only when
   **all** hold: (a) the resolved **landed-work SHA** (and, where graduation
   applies, the graduation SHA) is an **ancestor of the gitlink target** — mere
   reachability of the target from default is not enough, since any ancestor would
   pass; (b) that gitlink target is reachable from the submodule's **fetched**
   default branch; and (c) the **landed meta commit** (resolve its SHA if the meta
   PR was squash/rebase-merged) is reachable from meta default **and its own tree
   records that gitlink target** — read it from the landed commit's tree, not the
   live default tree, so a later legitimate bump can't make settled work look
   unsettled. Prefer this mechanical check even when a side rewrote history (fetch
   + ancestry still work). Where a history rewrite makes mechanical proof
   genuinely impossible, confirmation **is** the human's in-session word — the
   existing `references/advanced.md` exception, not a stopgap; the item stays
   **pending/deferred** only when **neither** mechanical proof nor human
   confirmation is available.
4. **Completion tail reaches across (robustly)** — it deletes the meta work +
   accepted branches *and*, using the name + SHA in the meta `context.md`, reaches
   into the submodule to delete its `prepare/<slug>` + accepted branch (otherwise
   those branches **orphan** — a bare submodule has no queue or tail of its own).
   Because the converge machine may not have the submodule initialized, the tail
   first **initializes + fetches** it (`git submodule update --init`,
   `git -C <sub> fetch`); deletes **local and remote** refs per the meta `## Push`
   policy (remote deletion only where push is permitted); never deletes a
   checked-out branch; and is **idempotent** — an already-absent ref is a no-op,
   not an error.

The full ordered procedure lives in `references/advanced.md` next to the other
non-trivial landings.

**The other dispositions are *not* unchanged for a bare pair** — each spans two
branches across two repos:

- **continue** — advancing the submodule tip means the meta paired branch's
  gitlink + `context.md` must be refreshed to match, or the meta side goes stale;
  it stays an in-progress candidate.
- **park** — narrate "blocked on X" in the meta `context.md`; both branches
  remain as-is (no re-sync needed while parked).
- **drop** — record *why* in the meta `context.md`, then delete **both** refs (the
  meta paired branch and the submodule `prepare/<slug>` via `git -C <sub>`).
- **promote** — orthogonal as always; durable findings rise into the meta
  `knowledge/`.

**Out of scope (natural follow-up).** A fully *recursive `converge` status view*
that aggregates HAS-`.tsugu/` submodules' own queues into one omni-level morning
view is **not** built here — issue #40 is about `prepare`. 008's `converge`
change is limited to understanding the bare-submodule paired branch. A
HAS-`.tsugu/` submodule is converged by `cd`-ing into it and running its own
`/tsugu:converge`. **Consequence to name plainly:** until that recursive view
exists, reviewing an omni-repo's prepared work means running `/tsugu:converge`
once per HAS-`.tsugu/` submodule — the meta `converge` shows only meta-level +
bare-submodule paired branches, not the HAS-`.tsugu/` submodules' own queues.

## D — Source-scoping guidance (the overlap anti-pattern)

Under recurse-and-run, each `.tsugu/`-bearing submodule's own intake pulls its
own tickets. But if the meta-repo *also* holds a source that **overlaps** a
submodule's source (the same tracker board feeding tickets owned by a
`.tsugu/`-bearing submodule), the meta source would double-pull those tickets and
mis-attribute them — exactly the incident (the omni-level EXP source duplicated
EXP-5978 and mis-attributed EXP-5967 to explore-ui).

The skill **recommends** scoping each repo's intake to work it owns:

- a HAS-`.tsugu/` submodule runs **its own** board / JQL;
- the meta source covers **meta-level work** (pin bumps, omni docs) **+ bare
  submodule work** only.

Overlapping the same board at the meta level is named as the anti-pattern. **No
central router, no defer/skip guard** — guidance only, consistent with tsugu's
light / script-free philosophy. The incident's fix is partly "remove the
omni-level EXP source; let explore-ui and exp-graph-parser-ui run their own."

## E — `init` graduation (`/tsugu:init [<submodule-path>]`)

A bare submodule can be brought under its own control at any time. `init` gains:

### E1 — Optional path argument

`/tsugu:init [<submodule-path>]`. When the path is **present**, `init` targets
that submodule directly (operates in that path's working tree) and **skips the
"which repo / confirm target" question** — it proceeds straight to creating the
submodule's `.tsugu/` and the graduation flow. When **absent**, `init` operates
on the current repo (existing behavior).

### E2 — Knowledge-only graduation

When `init` runs on a submodule, it detects an enclosing tsugu-managed omni-repo
(`git rev-parse --show-superproject-working-tree` → check that superproject for
`.tsugu/`). If found, it scans the omni `knowledge/` for entries naming this
submodule, **presents them**, and on per-entry human confirmation **cuts** them
down into the new submodule `knowledge/` (move the content, remove from meta) —
leaving the omni level holding only genuinely cross-cutting knowledge. This is
the deliberate inverse of "promote upward": once the submodule has a level of its
own, facts true only of it belong there.

**Graduation is itself a repo mutation, not a free relabel.** Creating the
submodule's `.tsugu/policy.md` is a new submodule commit; removing the relocated
entries from the omni `knowledge/` is a meta commit. The omni gitlink **must** be
bumped to the submodule commit that carries the new `.tsugu/` — otherwise a fresh
checkout stays pinned to a pre-`.tsugu/` SHA, re-classifies the submodule as bare,
and operationally **reverses** the graduation. `init` makes these as ordinary
commits per repo — submodule first (its `.tsugu/` lands), then the meta gitlink
bump + knowledge removal — and is **re-entrant** (interrupted midway, re-running
`init` re-detects the remaining omni entries and resumes). No atomic cross-repo
transaction is claimed; the human drives any PR per the usual approval boundary.

### E3 — In-flight paired branches are left alone

Graduation does **not** touch in-flight paired meta `prepare/<slug>` branches —
they finish their current lifecycle at meta `converge`. Only **new**
post-graduation work goes native-in-submodule, because the next meta `prepare`
now sees the submodule's `.tsugu/` and recurse-and-runs instead of meta-driving.
A brief coexistence of a paired meta branch and native submodule branches is
expected and self-resolving (each lands through its own `converge`). **One guard:**
when such an in-flight pair later accepts, its meta gitlink-bump must target the
**current submodule default tip** (which contains both the accepted work *and* the
graduation `.tsugu/` commit), never the feature's bare landed SHA — this is just
the two-repo-accept re-point rule (step 2) applied across a graduation boundary,
and it prevents a late accept from un-graduating the submodule. No mid-flight
branch surgery, no schema migration — graduation is a knowledge-relocation
operation.

## Where it lands (files)

- **`skills/tsugu/SKILL.md`** — new `prepare` traversal step (A2); the
  bare-submodule paired-branch behavior (B/C); `init`'s path argument +
  graduation offer (E); tightened `## Scheduling & recursion` "Recursion"
  paragraph stating the `.tsugu/`-presence gate and the case table.
- **`skills/tsugu/references/policy-and-intake.md`** — expand `## Recursion`: the
  gate, the case table, the source-scoping anti-pattern (D).
- **`skills/tsugu/references/git-recipes.md`** — new `## Submodule recursion
  (omni-repo)` section: `git submodule` enumeration, the gate test, `git -C`
  recurse mechanics (schema-agnostic, depth-first), and the bare-submodule
  paired-branch + gitlink-bump recipe.
- **`skills/tsugu/references/advanced.md`** — the **ordered** two-repo accept
  landing for the bare case (submodule PR first → re-point gitlink to the *landed*
  SHA → meta PR; **conjunctive** settlement; completion tail reaches across into
  the submodule via `git -C <sub>` to clean its branches).
- **`skills/tsugu/references/notes-and-packet.md`** — the graduation /
  knowledge-relocation guidance, alongside the existing "Context placement rule
  (omni-repo framing)".
- **`.claude-plugin/marketplace.json`** — tsugu `0.4.0 → 0.5.0` (minor; new
  capability, no schema change).
- **`CLAUDE.md`** — add spec 008 to the tsugu lineage line.

## Acceptance criteria (from issue #40, mapped)

- `prepare` in an omni-repo creates **no** meta-level branch for a
  HAS-`.tsugu/`-submodule-owned ticket — recurse-and-run branches it in the
  submodule. ✓\* **(contingent — see Limitations L1:** the *absence of a meta
  double-pull* relies on the source-scoping recommendation (D), since `prepare`
  works the meta queue and overlap is guidance-only with no defer/skip guard. A
  mis-scoped meta source feeding the same board can still double-pull.)
- An existing submodule `prepare/<slug>` is **continued**, not duplicated — the
  submodule's own queue read. ✓
- A ticket a submodule's `.tsugu/context.md` excludes is **not** branched there
  and is routed to the correct submodule — emergent under recurse-and-run. ✓\*
  **(contingent — see Limitations L1:** routing is emergent only if the owning
  submodule's machine-local intake is bootstrapped and claims the ticket; there is
  no structural router.)
- Submodule commits in a **HAS-`.tsugu/`** submodule honor the submodule's **own**
  policy (prefixes, push, default branch, CI-skip) — recurse runs it. ✓ (A
  **bare** submodule's branch is governed by **meta** policy by construction (B/C),
  so this AC is scoped to HAS-`.tsugu/` submodules.)
- A ticket owned by a **bare** submodule branches **in that submodule** with a
  paired meta branch carrying findings + gitlink bump — the maintainer's
  refinement of the issue's AC #5. ✓
- A ticket with **no clear owner** is *not* force-branched into a submodule (there
  is no rule to pick one). **Deterministic flow:** genuinely meta-level work gets a
  meta-level `prepare/<slug>`; otherwise the item is **deferred to `converge`** (no
  branch created on a guess). At `converge` the human assigns an owner and the item
  **reclassifies** — native submodule preparation if the owner is a HAS-`.tsugu/`
  submodule, a bare pair if the owner is bare, or a meta branch if it was
  meta-level after all. ✓ (A *deferred* item creates no branch, so it carries no
  committed state; it resurfaces at the next `prepare`/`converge` by **re-reading
  external intake** — the same weakened-but-accepted dedup tradeoff schema 3
  already documents in `policy-and-intake.md` (§ Source dedup). No committed ledger
  is introduced.)

## Limitations (known, deliberate)

These are explicit scope boundaries, not oversights — flagged so the spec doesn't
read as guaranteeing more than it does:

- **L1 — AC#1 / AC#3 are contingent, not structural.** Both hold only under
  correct **source scoping** (D) and a **bootstrapped machine-local intake** for
  the owning submodule. There is **no structural router** and no defer/skip guard,
  by the guidance-only decision — a mis-scoped meta source feeding a submodule's
  board can still double-pull, and an un-bootstrapped submodule won't claim its
  ticket. The design makes the correct configuration *natural and recommended*; it
  does not *enforce* it. A structural router is explicitly out of scope.
- **L2 — Nested bare chains are out of scope.** Meta-driven bare work is limited
  to a **direct bare child** of a managed repo (the one-level case the incident
  exercised). A bare submodule nested inside another bare submodule would require a
  gitlink-bump chain through every intermediate — an N-repo transaction this spec
  does not define. Such a subtree is **surfaced for the human to restructure**
  (e.g. `init` an intervening level), never silently driven.
- **L3 — No recursive `converge` status view.** Reviewing an omni-repo's prepared
  work means running `/tsugu:converge` once per HAS-`.tsugu/` submodule; the meta
  `converge` aggregates only meta-level + bare-submodule paired branches. A unified
  omni-level morning view is a natural follow-up (this spec is about `prepare`).
