# 007 — Tsugu thin core: `prepare/*` is the work prefix, non-containment landings are advanced (schema 4)

## Relationship to 004 / 005 / 006

This spec **extends** `006-tsugu-workspace-transfer-design.md` (which superseded
parts of `005`, which extended `004`). 004/005/006 remain the lineage: the
git-native intake idea, derived state, the no-skill-orchestration rule, the
no-force principle, the storage split (committed `.tsugu/` vs personal global
folder), and the multi-agent reservations all stand.

007 is a **mental-model simplification**, not a storage change. It narrows what
is *foreground* in the core skill and relocates the heaviest path (settlement
when a landing rewrites history) to an advanced reference — **relocate, not
remove**. No capability is dropped; the default surface shrinks. Captured from
the homelab→MacBook workflow recorded in issue #38.

The new schema is **`tsugu-schema: 4`**, with a documented 3→4 migration. A
schema-1/2 repo migrates 1→2→3→4 under the existing N→N+1 contract.

| Line | Change | What it supersedes |
| --- | --- | --- |
| A | **Single `prepare/*` work prefix.** The default work-prefix set drops to `prepare/*` alone; `investigate/* review/*` leave the default. Built-in review/investigate subagents work *inside* the `prepare/*` branch/worktree; their status lives in `context.md` narrative, not the branch namespace | 006/SKILL.md's default work prefixes `prepare/* investigate/* review/*` and the `review/<slug>` same-slug-artifact example |
| B | **Non-containment landings → advanced.** Core assumes merge commits (settlement = containment). Include-mode landings that **rewrite history** — squash, rebase-before-merge, force-push — leave the work tip uncontained; that path (narrative-backstop / re-surface-until-confirmed) moves to a new `references/advanced.md` | SKILL.md's in-core squash handling across the partition notes, `converge` step 4, the completion tail, and the `## Merge method` template |
| C | **`accepted-prefixes`.** policy section `## Handoff Prefixes` → `## Accepted Prefixes`; shape is a list, default `feature/* bugfix/* chore/*`; handoff is framed as an *event* (translate `prepare/<slug>` → repo-native human branch), not a Tsugu-owned namespace | 006/policy's `## Handoff Prefixes` defaults `feat/* fix/*` |
| D | **converge dispositions stated as accept / park / drop**, with `continue` implicit and `promote` orthogonal | SKILL.md's accept/reject/park naming (rename `reject`→`drop`) |
| E | **Migration 3→4** (interactive prefix-collapse proposal + per-branch legacy handling) | n/a (new) |

Everything in 004/005/006 not named here is unchanged. In particular, **exclude
mode (`public-branch-tsugu`), multi-agent forward-compat, and omni-repo
recursion stay in the core** — they are part of the intended setup, not advanced.

## The principle (the spine)

> **Tsugu prepares `prepare/*` branches. Humans decide what converges.**

One test governs whether a concept belongs in the *core* (as opposed to derived,
advanced, or workflow-specific), carried verbatim from issue #38:

> Does this help a cold-start agent or human understand and continue prepared
> work **from Git alone**? If yes, keep it near the core. If not, make it
> derived, advanced, or workflow-specific.

This spec applies that test to four core surfaces and moves what fails it.

## A — Single `prepare/*` work prefix

### A1 — The default work-prefix set is `prepare/` alone

`init` writes a single work prefix by default:

```text
## Branch Prefixes
prepare/*
```

(was `prepare/* investigate/* review/*`). The branch name is **stable work
identity**, not a workflow state machine. "Investigation", "review status",
"implementation notes", "risk", and "next action" all live in
`.tsugu/context.md` on the branch — narrative for minds — never in the branch
namespace.

### A2 — Built-in subagents work *inside* the `prepare/` branch

`prepare`'s built-in review/investigate Task subagents no longer emit a separate
`review/<slug>` (or `investigate/<slug>`) branch as a same-slug artifact. They
operate within the work branch / its worktree and record findings in the work
branch's `context.md` (and promote durable findings to `knowledge/` as before).

Consequence for the slug-as-join-key text: the concept **stays**. One slug still
ties **four legs** — the work branch, its `context.md`, the personal packet
(`packets/<slug>.md`), and the accepted branch when one exists; the SKILL.md edit
must preserve all four. Only the **extra-work-prefix artifact leg** (the
"same-slug branch under a *different work prefix* is that item's artifact"
example) leaves the core, because the default no longer produces such branches. A
repo MAY still configure additional work prefixes (the mechanism is intact); when
it does, the slug-artifact rule still holds and is documented in
`references/advanced.md`.

### A3 — Discovery filters by the configured prefixes (unchanged mechanism)

Cold-start discovery still enumerates remote-tracking refs and filters by the
prefixes recorded in `policy.md`. With the new default this is just `prepare/*`.
A repo that has curated extra prefixes keeps discovering them — nothing about the
filter changes; only the shipped default shrinks.

## B — Non-containment landings move to `references/advanced.md`

### B1 — Core assumes merge commits

The core mental model is containment-derived settlement only:

```text
prepare/<slug> tip contained in <remote>/<default>  =>  settled
```

The SKILL.md partition keeps exactly two ref-level facts in the core table:

| Fact | State | Disposition |
| --- | --- | --- |
| tip contained in `<remote>/<default>` (in `exclude` mode: the slug-paired public branch's tip) | **settled** | skip; completion-tail / cleanup candidate |
| a same-slug branch exists under a configured `## Accepted Prefixes` | **decided, awaiting merge** | skip as candidate; shown in converge's awaiting-merge section |
| neither | **in progress** | candidate: read `context.md`, judge from narrative |

`prepare` still **recommends merge commits** and warns against squash-merging
tsugu-managed branches. `exclude` mode stays in core (its by-path landing is
already containment-derivable via the public branch's tip).

### B2 — What moves to advanced

The new `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/advanced.md` holds the
**non-containment-landing** path, lifted out of the core. This is the general
class — **any include-mode landing that rewrites history so the work branch's
own tip is not contained in default**: a forced squash (the squash commit's
parents contain none of the work commits), but equally a rebase-before-merge or
a force-push of the accepted branch (default then contains neither the original
`prepare/*` tip nor its history). Squash is the canonical example; the path is
the same for all three. It is lifted out of:

- the partition notes (the elaboration beyond the two core facts);
- `converge` step 4's accept-include clause (the "handed off — may have landed"
  narrative written at the decision when a rewrite is anticipated);
- the completion-tail trigger (human's in-session confirmation instead of
  containment, when the rewrite means containment can never settle the item).

The advanced path documents:

- the narrative-backstop ("handed off — may have landed via squash/rebase"
  written into `context.md` at the converge decision);
- the re-surface-until-confirmed behavior (the work tip is never contained, so
  the item stays "decided, awaiting merge" and re-surfaces at each `converge`
  until the human confirms the landing and runs the completion tail);
- the "disable the forge's auto-delete-head-branch" recommendation **for the
  rewrite case** (so the slug-paired ref survives long enough to confirm);
- the rewrite-specific completion-tail trigger (human confirmation, not
  containment).

The core SKILL.md keeps a one-line pointer: *"A landing that rewrites history
(squash, rebase-before-merge, force-push) breaks containment-derived settlement;
see `references/advanced.md`."*

Two things stay in core because `exclude` mode (which stays in core) needs them
independently of any rewrite: (a) the general **narrative backstop** for a
*deleted* handoff/public ref (the forge auto-deletes on merge); and (b) the
**retain-handoff / disable-auto-delete** recommendation — `exclude` mode settles
via the public branch's containment, so that ref must survive too. Only the
*rewrite-specific* elaboration moves to advanced.

## C — `accepted-prefixes` (handoff as an event)

### C1 — policy section rename + shape

```text
## Accepted Prefixes
feature/*  bugfix/*  chore/*
```

(was `## Handoff Prefixes` with defaults `feat/* fix/*`.) The field is a **list**
(`accepted-prefixes`), default `feature/* bugfix/* chore/*`. Existing
prefix-disjointness validation still applies: the work prefixes
(`## Branch Prefixes`) and the accepted prefixes (`## Accepted Prefixes`) must be
**disjoint sets**; `init` and migration refuse overlapping sets.

### C2 — Handoff is an event, not a namespace

Tsugu owns the **agent-side preparation queue** (`prepare/*`). The repo's
existing human git flow owns public branches, PRs, and merges. At converge
`accept`, Tsugu *translates* from the preparation queue into the human flow:

```text
prepare/<slug>   --accept-->   <accepted-prefix>/<slug>   (e.g. feature/<slug>)
```

Same commits, a second name, **same slug** — the partition pairs the two by
shared slug, so the "decided, awaiting merge" state survives anything the forge
does to commits. This is the same mechanism as today's handoff branch, reframed:
"handoff" is the *act of translating at accept time*, not a prefix Tsugu owns.

When multiple accepted prefixes are configured, the human picks which one at
`accept` time (or the slug/context implies it).

## D — converge dispositions

### D1 — Three named terminal dispositions

`converge` step 4 presents, per branch:

- **accept** — translate `prepare/<slug>` into a repo-native human branch
  (`<accepted-prefix>/<slug>`), verify, push, hand off. Two arms, both unchanged
  from 006 and both kept in core:
  - *include mode* — merge directly in the solo flow (work tip then contained →
    settled), or cut the accepted branch + human-approved PR;
  - *exclude mode* — cut a clean public branch from the fetched default, same
    slug, and apply the accepted code/test/doc/config **by path** (no `.tsugu/`
    in the public diff); settlement reads off the **public branch's** containment,
    not the work branch's.
- **park** — write into `context.md` what is needed to resume ("blocked on X").
  No status field is set; a parked branch is simply a candidate whose narrative
  says it's blocked, de-prioritized by the staleness/housekeeping derivation.
- **drop** — record *why* in `context.md` ("dropped — do not resume: <why>";
  agents read the narrative before touching any candidate), remove worktrees,
  delete the branch when safe. (Renamed from `reject`; the "record why"
  narrative is retained.)

### D2 — `continue` is implicit

In a human-present `converge`, **every branch the human does not act on is
already "continue"** — it stays an in-progress candidate. This is the
looking-and-leaving morning status view (steps 1–3 touch no git or shared
state). `continue` is therefore **not** a named verb; it is the default. Its only
active form is the human triggering a workflow skill on the branch *now*
("let's brainstorm this", "/review-loop") — which Tsugu does not fire itself.

### D3 — `promote` is orthogonal

`promote` (extract durable findings into `.tsugu/knowledge/` or `AGENTS.md`) is
**not** a sibling disposition in a pick-one list. It can ride *any* disposition:

- most often it is `accept`'s completion-tail step (as today);
- but "**drop** the branch yet **promote** the lesson" is valid and useful;
- it can also be done standalone during the morning view.

It remains a converge checklist item, per issue #38's own note ("promote does not
necessarily need to be a separate command").

### D4 — Invariant preserved

None of accept / park / drop / continue / promote sets a *status field*. Each
produces either a branch action (accept/drop), a narrative write (park/drop's
reason), or a knowledge write (promote). State stays **derived** from refs, the
DAG, containment, and recency — exactly as in 006. *Narrative informs judgment,
never classification.*

## E — Migration 3→4

Added to `references/migrations.md` as the `3→4` step.

### E1 — Always-applied, mechanical

1. Rename the policy section `## Handoff Prefixes` → `## Accepted Prefixes`
   (content preserved verbatim — a schema-3 repo's curated `feat/* fix/*` stay as
   they are; only the heading changes).
2. Update the `tsugu-schema:` stamp to `4` — **written last**, after all other
   steps, so an interrupted migration re-enters safely.
3. If the default branch is push-protected, the migration rides an `init/*`
   branch + human-approved PR; the stamp rides as the **last** write (never a
   "complete" stamp over a half-applied migration).

Renames/restructures schema parts only; **never overwrites curated content**.

### E2 — Interactive prefix-collapse proposal

If `## Branch Prefixes` contains more than `prepare/*`, migration **proposes**
collapsing to single `prepare/*` and **asks the human to confirm**. It never
auto-changes a curated prefix set. If the human declines, the multi-prefix set is
kept as-is (fully supported) and the migration completes with only E1 applied.

**Post-collapse disjointness re-check (T3-c).** The collapse can *introduce* an
overlap the schema-3 repo did not have: a repo could legally have curated work
prefixes `investigate/* review/*` and accepted prefixes `prepare/* feat/*`
(disjoint under schema 3). After the collapse, the work set is `prepare/*` and
the renamed accepted set still contains `prepare/*` → **overlap**, violating the
invariant C1 enforces. So after E1's rename **and** E2's collapse, migration
**re-runs the work ∩ accepted = ∅ check**; on overlap it stops and asks the human
to pick a different accepted prefix or decline the collapse. The collapse is not
committed until the sets are disjoint.

### E3 — Per-branch legacy handling

If the human accepts the collapse, migration handles existing branches under the
*removed* prefixes (`investigate/<slug>`, `review/<slug>`) **without renaming any
branch** (write-once identity is inviolate). For each such branch, it first
checks whether `prepare/<slug>` already exists, because in schema 3 a
`review/<slug>` is typically the **artifact** of an existing `prepare/<slug>`
(T3-b):

1. **`prepare/<slug>` already exists** → the legacy branch is that work item's
   artifact. Leave it to the work item's lifecycle (the completion tail already
   sweeps same-slug artifacts). **No recreate** — `git branch prepare/<slug>`
   would fail, and there is nothing to preserve.
2. **No `prepare/<slug>`** (a standalone legacy branch) → list the branch name and
   its **tip commit hash**, and ask the human whether to **recreate** it as
   `prepare/<slug>` pointing at that commit (`git branch prepare/<slug> <tip-sha>`,
   push, then optionally delete the old ref) — a *copy*, not a rename, so
   write-once identity holds.
3. **Ambiguous** — multiple divergent legacy branches share one slug, or the
   human wants to keep both the legacy branch and an existing `prepare/<slug>` →
   **stop and ask**; the human resolves by hand (rename/drop as they choose).
   Migration never picks for them and never force-overwrites a ref.

No legacy branch is touched without explicit per-branch confirmation. A branch
the human leaves alone simply stops being discovered under the new single-prefix
default — surfaced as a one-line note so it is never silently orphaned.

## Affected surface

- **`plugins/tsugu/skills/tsugu/SKILL.md`** — A (single prefix default, drop
  review-artifact example), B (move **every** rewrite-landing touchpoint to a
  pointer: the partition-note elaboration, the `converge` step-4 accept-include
  "may have landed" clause, and the completion-tail rewrite trigger; keep the
  three-row core table and the shared deleted-ref / retain-handoff lines for
  `exclude`), C (accepted-prefixes / handoff-as-event wording), D
  (accept/park/drop verbs, continue implicit, promote orthogonal). Net: shorter.
- **`plugins/tsugu/skills/tsugu/references/advanced.md`** — **new**: the
  non-containment-landing path (squash / rebase-before-merge / force-push); the
  slug-artifact rule for repos that configure extra work prefixes.
- **`plugins/tsugu/skills/tsugu/references/migrations.md`** — add `3→4` step (E).
- **`plugins/tsugu/skills/tsugu/references/policy-and-intake.md`** — rename the
  handoff-prefixes section to accepted-prefixes; new defaults.
- **`plugins/tsugu/skills/tsugu/templates/policy.md`** — `## Accepted Prefixes`
  with `feature/* bugfix/* chore/*`; `## Branch Prefixes` with `prepare/*` only;
  `tsugu-schema: 4`. **`## Merge method`** shrinks to "prefer merge commits;
  non-containment landings (squash / rebase / force-push) → `advanced.md`" while
  **keeping** the retain-handoff / disable-auto-delete line that `exclude` mode
  relies on.
- **`plugins/tsugu/commands/*.md`** — converge verb naming if referenced.
- **`plugins/tsugu/skills/tsugu/README.md`** — user-facing wording.
- **`CLAUDE.md`** (repo root, tsugu paragraph) — `Schema 4 (lineage: 004 → 005 →
  006 → 007)`, default work-prefix `prepare/*`, accepted-prefixes.
- **`.claude-plugin/marketplace.json`** — bump tsugu plugin version.

## Success criteria

1. A fresh `init` writes `## Branch Prefixes: prepare/*`, `## Accepted Prefixes:
   feature/* bugfix/* chore/*`, and `tsugu-schema: 4`.
2. The core SKILL.md partition table has **three rows** (settled / awaiting-merge
   / in-progress) derived from **two checked ref-level facts** (containment, then
   slug-pairing), with **no rewrite-landing elaboration** in core; the
   non-containment-landing path lives only in `references/advanced.md`, reachable
   by a one-line pointer.
3. exclude mode, multi-agent forward-compat, and omni-repo recursion remain
   documented **in core** (unchanged from 006).
4. converge documents accept / park / drop as the named dispositions, states
   `continue` as the implicit default, and `promote` as an orthogonal checklist
   item that can ride any disposition.
5. Running `init` on a schema-3 repo with `## Handoff Prefixes` renames it to
   `## Accepted Prefixes`, stamps `tsugu-schema: 4` last, and — only on human
   confirmation — proposes the prefix collapse; legacy `investigate/`/`review/`
   branches are handled per-branch with their tip hash shown, never auto-touched.
6. A schema-1/2 repo migrates 1→2→3→4 under the existing N→N+1 contract.
7. The slug-as-join-key concept survives with all four legs intact (work branch,
   `context.md`, packet, accepted branch); only the `review/<slug>`
   extra-work-prefix artifact example leaves the core (it moves to advanced for
   configured-extra-prefix repos).

## Open questions (resolved in this spec)

- *Collapse to `prepare/` only, or keep multi-prefix?* → Single `prepare/`
  default; multi-prefix stays configurable and documented in advanced (A).
- *Which heavy mechanics leave the core?* → Only the non-containment-landing
  path — any include-mode landing that rewrites history (squash / rebase /
  force-push) (B). exclude, multi-agent, recursion stay in core.
- *`accepted-prefix` single value or list?* → List, default
  `feature/* bugfix/* chore/*` (C).
- *Are converge's five verbs peers?* → No: accept/park/drop are terminal
  dispositions; continue is the implicit default; promote is orthogonal (D).
- *Does migration touch curated prefixes?* → Never auto; proposes collapse with
  confirmation, re-checks work ∩ accepted = ∅ after collapse, and handles legacy
  branches per-branch (artifact → leave; standalone → recreate-at-hash;
  ambiguous → stop and ask), never renaming (E).

## Deferred (unchanged from 004/005/006)

- Concurrent multi-agent arbitration and locks (the substrate stays forward-
  compatible; recency-derived claims remain the only mechanism).
- Any scheduler inside the skill (`prepare` is driven externally by
  `/schedule`/cron).
- Tooling/scripts beyond documented git recipes (the skill stays light /
  script-free).
