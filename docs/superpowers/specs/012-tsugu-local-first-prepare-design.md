# 012 — Tsugu local-first prepare: `prepare/*` stays local by default; recognize a human takeover by containment (schema 4 → 5)

## Relationship to 004 / 005 / 006 / 007 / 008 / 011

This spec **extends** the lineage `004 → 005 → 006 → 007 → 008 → 011`. Everything those
specs establish stands: git-native intake, derived state (refs + DAG + containment +
recency; no status fields), the no-skill-orchestration rule, the no-force principle,
the storage split (committed `.tsugu/` vs personal global folder), the work-prefix /
accepted-prefix partition, 011's **handoff-oriented converge** (accept = mode-agnostic
rename; maintenance exception; curation; `prune`), and the never-auto-merge /
public-coordination-needs-approval boundary.

012 **narrows one assumption 008 baked in — that `prepare/*` is pushed by default so
"the branch is the message."** In the **single-machine** reality (011's recommended
provisioned-machine locus), pushing every `prepare/*` to the remote is unnecessary
(the same machine already has the local branch) and is the **source** of the lingering
remote `prepare/<slug>` that confuses cold-start sessions (issue #52). 012 makes
`prepare` **local-first**: work stays on local `prepare/*` by default; the remote push
becomes an opt-in for genuine **cross-machine agent collaboration** (the already-deferred
*Multi-agent: reserved* case). It also teaches discovery to recognize when **a human has
taken the work onto their own branch** — by **containment**, not just by the accepted-prefix
slug name — so a scheduled session never re-works or re-pushes already-converged work.

Captured from live omni `prepare`/`converge` use, recorded in **issue #52**. It is the
single-machine / human-named-branch half of the discovery gap 011 named as the deferred
multi-agent concurrency case.

**This is a schema change.** The `push-prepare-branches` *default* flips (`yes` → `no`),
so 012 bumps **`tsugu-schema: 4 → 5`** and ships a 4→5 migration that pins the **old**
default into existing repos (preserves their behavior). New `init` stamps 5 → default
`no`.

| Line | Change | What it supersedes | Issue |
| --- | --- | --- | --- |
| A | **Local-first `prepare`.** `push-prepare-branches` defaults **`no`**; `prepare` keeps work on **local** `prepare/*`; discovery enumerates work-prefix branches **local + remote**; remote push of `prepare/*` is an **opt-in** for cross-machine agent collaboration | 008's `push-prepare-branches: yes` default + SKILL.md step 8 "cold-start discovery enumerates *only* remote-tracking refs, so pushing is what lets the next agent inherit" | #52 |
| B | **Human-takeover detection (containment-primary).** A `prepare/<slug>` whose tip is **contained** by any **non-default, non-work-prefix** ref (local or remote) is **taken over** — a human carried the work onto their own branch. `git for-each-ref --contains <prepare-tip>` minus default + work prefixes | 011's partition recognized a takeover **only** by accepted-prefix slug name (B1a fact 2) — missing a human's own-named branch (`isaac/fix-thing`) | #52 |
| C | **Takeover disposition (cleanup).** A taken-over `prepare/<slug>` **leaves the queue** (never worked/pushed); the **local** ref is **auto-deleted** (fully contained → nothing lost); a **remote** ref (from a prior opt-in push) is **prompted** for deletion via `prune`, human-confirmed | n/a (new) | #52 |
| D | **Auto-push invariant.** `prepare` **never auto-pushes a non-work-prefix branch** (accepted / human). The sole exception — cross-machine **agent-to-agent** push with no human present — is deferred (*Multi-agent: reserved*) | implicit before; #52 asks it be explicit so "the agent pushes an already-converged local branch" cannot happen | #52 |

Everything in 004–011 not named here is unchanged. In particular: 011's accept = handoff
rename, the maintenance exception, curation, the `prune` categories, the submodule
handoff, and `public-branch-tsugu` are all unchanged except where a line above touches
them.

## The principle (the spine)

> **The provisioned machine is the locus; local refs are the queue. The remote is for
> *crossing machines*, not for *being the message* on one.** 008's "push so the branch
> is the message" assumed multiple machines inheriting via `git fetch`. On the single
> provisioned machine 011 recommends, the local refs already carry the queue — so
> `prepare/*` stays **local by default**, and a push is an explicit act reserved for
> cross-machine agent collaboration.

Two consequences follow directly:

- **The lingering-remote problem dissolves at the source.** #52's failure — a cold-start
  session seeing a stale remote `prepare/<slug>` after the human took the work — only
  existed *because* `prepare/*` was pushed. Local-first repos never push it, so there is
  nothing to linger. 011's B1a "surviving remote `prepare/<slug>`" residual **vanishes**
  for local-first repos (it was a consequence of the push).
- **B3 simplifies.** 011's converge handoff (B3) prompted the human to *push the accepted
  branch* **and** *delete the stale remote `prepare/<slug>`*. Under local-first there is
  no remote `prepare/<slug>` — so B3 shrinks to just "push the accepted branch."

### The tradeoff, stated openly

Pushing `prepare/*` also gave a **remote backup** of in-flight work (it survives machine
loss). Local-first means in-flight `prepare` work is **local-only until handoff**. For the
single provisioned-machine locus this is an accepted trade; the **cross-machine opt-in**
(Change A) restores the backup for anyone who wants it. `init` surfaces this when it sets
the default.

---

## Change A — Local-first `prepare` (issue #52)

### A1. The default flips

`## Push`'s `push-prepare-branches` **defaults to `no`** (was `yes`). `prepare` commits
work to **local** `prepare/*` branches and **does not push them**. The push is an
**opt-in**: a repo that wants cross-machine agent collaboration (machine A prepares,
machine B inherits) sets `push-prepare-branches: yes`.

SKILL.md step 8 changes from "push it if policy permits (default `yes`)… pushing is what
lets the next agent inherit (the branch *is* the message)" to: **commit the local work
branch; push it only when `push-prepare-branches: yes` (cross-machine opt-in, default
`no`).** The "branch is the message" framing is **scoped to the cross-machine case** —
on one machine the local branch *is already* the queue.

### A2. Discovery enumerates work prefixes local + remote

The queue read changes from "**Read the queue from remote-tracking refs**" to **read
work-prefix branches across local *and* remote refs**. On a single machine the queue is
the **local** `prepare/*`; with the cross-machine opt-in it is local **+** remote (a
slug present in either is one work item, unioned by slug — the same union shape 011's
B1a established for accepted prefixes). `knowledge/` + policy still come from the fetched
default / coordination ref as before.

git-recipes' "Read the queue" work-branch enumeration (currently `git branch --remotes …
# pushed mode`) gains the **local** form (`git branch --format=… | grep work-prefixes`)
and unions the two by slug — mirroring 011's local+remote accepted enumeration. The
existing "pushed mode" note becomes "cross-machine opt-in mode."

### A3. Cross-machine push is the opt-in (deferred *Multi-agent*)

Pushing `prepare/*` is the mechanism by which a **second machine's** agent inherits work
— the cross-machine agent-to-agent collaboration tsugu already files under *Multi-agent:
reserved*. 012 names it as the **reason** `push-prepare-branches: yes` exists, and folds
the "agent may push for another agent" exception there. Not built further here; the knob
is the opt-in.

---

## Change B — Human-takeover detection by containment (issue #52)

011's partition recognized that work was handed off **only** by an accepted-prefix branch
sharing the slug (B1a fact 2). But a human frequently takes the work onto a branch that is
**not** under a configured accepted prefix — `isaac/fix-thing`, a personal or feature name
of their own. 011's slug-pairing can't see it, so the `prepare/<slug>` reads in-progress
and a scheduled `prepare` may re-work it.

**012 adds a containment signal.** A `prepare/<slug>` is **taken over** when its tip is
**contained** by **any non-default, non-work-prefix ref** (local or remote):

```bash
git for-each-ref --contains "<prepare/slug-tip>" --format='%(refname:short)'
# remove: <default>           (containment there is the existing SETTLED row)
#         <work-prefix>/*      (queue siblings built on the same base)
# anything left ⇒ a human/accepted branch carries this work ⇒ taken over
```

- **Containment is primary, mode/name-agnostic.** Any ref carrying the prepared commits
  means the work is **already taken** — whether the human named it `feature/<slug>`,
  `isaac/fix-thing`, or anything else.
- **It generalizes slug-pairing.** A tsugu accepted branch (`feature/<slug>`, renamed
  from `prepare/<slug>` per 011) **contains** the tip, so containment catches it too.
  **Slug-name pairing stays** as the **complementary** catch for the **squashed / rewritten**
  take — where the human's branch no longer contains the tip verbatim but the name still
  pairs.
- **The squash/rebase residual is unchanged.** If the human **squashed or rebased** their
  take onto a **differently-named** branch, *neither* containment *nor* slug-name fires.
  That is 011's existing non-derivable residual: `prepare`'s judgment leans conservative
  (leave the unfamiliar stale branch for `converge`; reversible; never auto-merges). 012
  does not re-solve it.

The partition's "decided / not-in-progress" derivation becomes: **a slug-paired accepted
branch (by name) OR any non-default/non-work ref contains the tip.**

---

## Change C — Takeover disposition: queue-leave + cleanup (issue #52)

A taken-over `prepare/<slug>` is **redundant** — a human branch already carries its
commits. Disposition:

1. **Leaves the queue.** Discovery classifies it *taken over*, not *in-progress* — the
   agent **never works or pushes it**. (Automatic; it is simply no longer a candidate.)
2. **Local ref auto-deleted.** Because the human branch **fully contains** the tip
   (nothing is lost), `prepare` / `converge` **deletes the local `prepare/<slug>`**
   directly — it is the agent's own scratch ref and its content lives on the human's
   branch. (This is the one place 012 lets the agent delete a local ref without a prompt;
   it is safe precisely because of containment.)
3. **Remote ref prompted, human-confirmed.** If a prior **opt-in push** left a remote
   `prepare/<slug>`, its deletion is **surfaced by `prune`** (and may be surfaced at
   `converge`) — *"`prepare/<slug>` is fully carried by `<branch>` — remove the redundant
   remote ref?"* — **human-confirmed, remote always explicit** (the never-auto-remote
   rule). Local-first repos never pushed it, so this case only arises for cross-machine
   opt-in repos.

`prune` gains a **`taken-over` (redundant prepare)** category alongside settled /
possibly-landed / dropped / orphaned-accepted: a `prepare/<slug>` whose commits a
non-work, non-default ref contains. Local side is already cleaned (step 2); the remote
side is its surface-and-confirm job.

---

## Change D — Auto-push invariant (issue #52)

State it explicitly, so "the agent pushes an already-converged local branch to remote"
cannot happen:

> **`prepare` auto-pushes only the `<work-prefix>/*` branch it is working, and only when
> `push-prepare-branches: yes`. It never auto-pushes an accepted-prefix or human-named
> branch** — publishing those is the human's act (011's B3, print-only).

The **sole exception** — a cross-machine **agent-to-agent** push with **no human present**
(machine A pushes a coordination ref for machine B) — is **deferred** to the existing
*Multi-agent: reserved* section; it is **not** built here. Absent that opt-in, the invariant
holds unconditionally.

---

## Schema 4 → 5 and the compat migration

The `push-prepare-branches` **default** changes behavior, so the default is **schema-gated**
and 012 bumps the stamp:

- **Fresh `init`** stamps **`tsugu-schema: 5`** and writes the new default
  `push-prepare-branches: no` (with the cross-machine opt-in noted in the policy comment).
- **Existing repos** (`tsugu-schema: 4`, no explicit `push-prepare-branches`): the **4→5
  migration writes the explicit `push-prepare-branches: yes`** — pinning the **old**
  default so the upgrade **does not silently change their behavior**. A repo that already
  set the field explicitly keeps its value untouched (migrations never overwrite curated
  content).
- **The default is read schema-aware in the interim:** a still-schema-4 repo with no
  explicit value is treated as the **old `yes`** default until the migration runs; a
  schema-5 repo with no explicit value is the **new `no`**. This prevents a behavior flip
  before the migration pins the value. (After migration, old repos always carry an explicit
  value, so the schema-aware default only matters during the upgrade window.)

The migration rides `references/migrations.md` (a `4→5` step) and the `init` re-run path
(stamp written **last**, per the established migration discipline; on a push-protected
default branch it rides an `init/*` branch + human-approved PR, exactly as 004–011
specify). No committed `.tsugu/` files or directories are added or removed — the only
structural change is the stamp + the explicit policy field.

---

## State model (unchanged invariant, restated)

No disposition sets a **status field**. *Taken over* is **derived** (containment by a
non-default/non-work ref); the local auto-delete is a branch action; the remote prompt is
human-confirmed. State stays derived from refs / DAG / containment / recency.
*Narrative informs judgment, never classification.* The discovery model is now:

```
prepare: read work prefixes LOCAL (+ remote when push opted in) → partition:
  • tip contained in default                         → settled
  • slug-paired accepted branch, OR tip contained by
    any non-default/non-work ref                     → decided / TAKEN OVER (cleanup)
  • neither                                          → in-progress (work it)
work stays LOCAL by default; push only on the cross-machine opt-in;
never auto-push accepted/human branches.
```

---

## Files touched

| File | Change |
| --- | --- |
| `plugins/tsugu/skills/tsugu/SKILL.md` | step 8 → local-first (push default `no`, opt-in framing); "Read the queue from remote-tracking refs" → **local + remote** work prefixes; partition gains the **containment takeover** derivation; new **taken-over** disposition (queue-leave + local auto-delete + remote prompt); the **auto-push invariant** (D); schema `4 → 5`; *Multi-agent* gains the cross-machine push opt-in/exception; B3 note that there is no remote `prepare/<slug>` under local-first |
| `plugins/tsugu/skills/tsugu/references/git-recipes.md` | "Read the queue" work enumeration gains the **local** form + union-by-slug (mirroring 011's accepted local+remote); the `git for-each-ref --contains` **takeover** check; the push recipe → opt-in; the settlement/landed_ref note unaffected |
| `plugins/tsugu/skills/tsugu/references/migrations.md` | **new `4 → 5` step** — write explicit `push-prepare-branches: yes` when absent (preserve old behavior); stamp written last; `init/*`-branch + PR path on push-protected default |
| `plugins/tsugu/skills/tsugu/templates/policy.md` | `tsugu-schema: 5`; `## Push` default `push-prepare-branches: no`; comment notes local-first + the cross-machine opt-in (`yes`) + the in-flight-backup tradeoff |
| `plugins/tsugu/skills/tsugu/SKILL.md` (`init`) + `references/notes-and-packet.md` | `init` asks/sets the push default (surfacing the tradeoff); `prune` doc gains the **taken-over (redundant prepare)** category |
| `plugins/tsugu/commands/prune.md` + `commands/prepare.md` | prune description notes the taken-over category; prepare description notes local-first if it implies pushing |
| `plugins/tsugu/skills/tsugu/README.md` | local-first prepare + the cross-machine opt-in, in user-facing terms |
| `.claude-plugin/marketplace.json` + `plugins/tsugu/.claude-plugin/plugin.json` | bump tsugu `0.6.0 → 0.7.0`; descriptions note local-first + schema 5 |
| `tools/tsugu/test-skill-content.sh` | content anchors: local-first default, `--contains` takeover, taken-over disposition, auto-push invariant, schema 5; refute the old "push it if policy permits (default `yes`)" / "remote-tracking refs" queue framing |

**Schema migration:** `tsugu-schema: 4 → 5` with the compat step above. `public-branch-tsugu`
and the 011 handoff model are unchanged.

## Closes

`#52` (cold-start discovery must search for human branches; never re-work or auto-push
already-converged work).
