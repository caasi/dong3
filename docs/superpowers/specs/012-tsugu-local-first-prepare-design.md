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
| B | **Human-takeover detection (containment-primary).** A `prepare/<slug>` whose tip is **contained** by a **branch** that is neither the default (nor its aliases) nor a work-prefix ref (local or remote) is **taken over** — a human carried the work onto their own branch. Fresh `git for-each-ref --contains` scoped to `refs/heads`/`refs/remotes` | 011 saw a takeover **only** by the accepted-prefix slug name (B1a fact 2), missing a human's own-named branch (`isaac/fix-thing`). 012 **generalizes** to containment by any branch and **keeps** slug-pairing as the complementary squash-catch — not a replacement | #52 |
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
- **B3 simplifies — for local-first repos.** 011's converge handoff (B3) prompted the
  human to *push the accepted branch* **and** *delete the stale remote `prepare/<slug>`*.
  Under local-first there is no remote `prepare/<slug>` — so B3 shrinks to just "push the
  accepted branch." A **cross-machine opt-in** repo (`push-prepare-branches: yes`) **still
  pushes `prepare/*`**, so 011's full B3 (push accepted **+** delete remote prepare)
  **applies there unchanged** — the remote-prepare-delete line survives only in opt-in
  repos.

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

### A2. Discovery reads work prefixes local + remote (a default flip, not a new mechanism)

`git-recipes.md`'s `## Read the queue` **already ships both reads**: a remote-tracking
"pushed mode" **and** a "No-push mode is local" path (`git branch --format=… | grep
work-prefixes`) gated on `push-prepare-branches: no`. 012 does **not** invent local
discovery — it **flips which is the default**, and makes the queue the **union of local
and remote** work-prefix refs (a slug in either is one item, unioned by slug — the same
union shape 011's B1a established for accepted prefixes).

**Discovery reads remote work refs regardless of the push default.** Only *pushing* is
gated by the opt-in; *reading* always includes remote work refs, because a leftover or
opt-in-pushed remote `prepare/*` must still be seen — it is exactly what the
takeover/`prune` cleanup targets (#52). The one statement that needs softening is
**SKILL.md's flat "Read the queue from remote-tracking refs"** (the only *unconditional*
remote-only line); the recipes' enumeration logic mostly stands — just **rename both mode
labels** ("pushed mode" → "cross-machine opt-in mode"; "no-push mode is local" →
"local-first (default)"). `knowledge/` + policy still come from the fetched default /
coordination ref as before.

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
**contained** by a **branch** that is neither the default nor a work-prefix branch. The
check must be precise — a loose filter false-positives, and Change C's cleanup is
destructive on a wrong hit:

```bash
git fetch --prune <remote>          # FIRST — so remote-tracking refs are fresh (no stale hits)
git for-each-ref --contains "<prepare/slug-tip>" refs/heads refs/remotes/<remote> \
     --format='%(refname:short)'    # scope to BRANCHES only — never tags / other namespaces
# then, after normalizing the <remote>/ prefix off remote-tracking names, EXCLUDE:
#   • the default and its aliases:  <default>, <remote>/<default>, <remote>/HEAD
#       (containment there is the existing SETTLED row, not a takeover)
#   • work-prefix refs, LOCAL *and* remote:  <work-prefix>/*  and  <remote>/<work-prefix>/*
#       (a pushed work branch's OWN remote ref must NOT count as a foreign takeover ref)
# anything left ⇒ a NON-WORK, NON-DEFAULT branch carries this work ⇒ taken over (→ Change C)
```

- **Containment is primary, name-agnostic.** A branch carrying the prepared commits means
  the work is **already taken** — whether the human named it `feature/<slug>`,
  `isaac/fix-thing`, or anything else. That is the gap over 011, which saw a takeover only
  by the accepted-prefix slug name.
- **It generalizes — and does not replace — slug-pairing.** A tsugu accepted branch
  (`feature/<slug>`, renamed from `prepare/<slug>` per 011) **contains** the tip, so
  containment catches it too. **Slug-name pairing stays** as the **complementary** catch
  for the **squashed / rewritten** take, where the human's branch no longer contains the
  tip verbatim but the name still pairs.
- **Fresh + correctly-scoped, or it's dangerous.** The two filters above (fetch-first; and
  excluding the default aliases + both local and remote work refs) are **load-bearing**: a
  stale remote-tracking ref, an unnormalized `<remote>/prepare/<slug>`, a tag, or
  `<remote>/main` slipping through would each falsely mark ordinary work as taken over. The
  signal is also **not proof of intent** — a branch built *on top of* the prepare tip that
  is **not** a takeover (a sibling item, a scratch experiment) also satisfies containment.
  That residual false-positive is exactly why Change C **surfaces for human confirmation
  and never auto-deletes**.
- **The squash/rebase residual is unchanged.** If the human **squashed or rebased** their
  take onto a **differently-named** branch, *neither* containment *nor* slug-name fires.
  That is 011's existing non-derivable residual: `prepare`'s judgment leans conservative
  (leave the unfamiliar stale branch for `converge`; reversible; never auto-merges). 012
  does not re-solve it.

The partition's "decided / not-in-progress" derivation becomes: **a slug-paired accepted
branch (by name) OR any non-default/non-work ref contains the tip.**

---

## Change C — Takeover disposition: queue-leave + human-confirmed cleanup (issue #52)

A taken-over `prepare/<slug>` is **probably redundant** — a non-work, non-default branch
already carries its commits. But "a branch contains the tip" is **not proof of a takeover**:
a scratch/experiment branch, or a second item a human based **on top of** the prepare tip,
also contains it (Change B). Because the containment signal can false-positive, the
disposition **never auto-deletes** — it surfaces for the human to confirm:

1. **Leaves the queue (automatic, safe).** Discovery classifies it *taken over*, not
   *in-progress* — the agent **never works or pushes it**. This is safe **regardless** of
   whether the containing branch is a real takeover: not working a branch loses nothing.
2. **Cleanup is surfaced, human-confirmed — never auto, never silent.** `prune` (and
   optionally `converge`) surfaces it: *"`prepare/<slug>` is fully carried by `<branch>` —
   remove the redundant `prepare/<slug>`?"* The human confirms it is a real takeover; only
   then is the ref deleted — **local and remote, both human-confirmed** (remote always
   explicit; **local too**, because the signal alone can't distinguish a takeover from a
   build-on-top branch, and a wrong guess would destroy the queue identity — slug +
   `context.md`-as-claim — of still-in-progress work).

`prune` gains a **`taken-over` (redundant prepare)** category — a `prepare/<slug>` (local
or remote) whose tip a **non-work, non-default branch** contains. It is
**surface-and-confirm** (like *possibly-landed*), never auto-delete. **Precedence with the
existing rows:** a remote `prepare/<slug>` whose tip is contained in `<remote>/<default>`
is already **settled** (the existing row) — list it there; *taken-over* covers only the
case where the containing ref is a **non-default** branch. The two predicates can coincide
on one ref, but the disposition (delete on confirm) is identical, so the overlap is
harmless — classify as *settled* when default contains it, else *taken-over*.

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
  value, so the schema-aware default only matters during the upgrade window.) **This
  schema-aware read lives at SKILL.md step 8** (the `push-prepare-branches` read): *absent
  → `yes` if `tsugu-schema: 4`, else `no`* — replacing the current flat "default `yes` when
  the section is absent."

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
prepare: read work prefixes LOCAL + remote (remote may hold leftovers / opt-in pushes)
  → partition, in order:
  • tip contained in <default> (or its remote aliases)      → settled
  • a slug-paired ACCEPTED-prefix branch exists             → decided, awaiting merge
        (011: skip, NO delete; the prepare ref is usually already gone via the rename)
  • tip contained by any OTHER non-default/non-work branch  → TAKEN OVER
        (leaves the queue; surface at prune/converge; delete ONLY on human confirm)
  • none of the above                                       → in-progress (work it)
work stays LOCAL by default; push only on the cross-machine opt-in;
never auto-push accepted/human branches; never auto-delete on a containment guess.
```

---

## Files touched

| File | Change |
| --- | --- |
| `plugins/tsugu/skills/tsugu/SKILL.md` | step 8 → local-first (push default `no`, opt-in framing) **+ the schema-aware read** (absent → `yes` if schema 4 else `no`); soften the flat "Read the queue from remote-tracking refs" → **local + remote** work prefixes; partition gains the **containment takeover** derivation (a distinct row from 011's *decided*); new **taken-over** disposition (queue-leave + **surface-and-confirm cleanup, never auto-delete**); the **auto-push invariant** (D); schema `4 → 5`; *Multi-agent* gains the cross-machine push opt-in/exception; B3 note (no remote `prepare/<slug>` under local-first; full B3 survives for opt-in repos) |
| `plugins/tsugu/skills/tsugu/references/git-recipes.md` | "Read the queue" **already has** both a remote ("pushed mode") and a local ("No-push mode is local") enumeration — 012 **makes local the default + unions local & remote by slug** (do **not** add a duplicate recipe); **rename both mode labels**; add the **fresh, ref-scoped, alias/work-excluding** `git for-each-ref --contains` takeover check; the push recipe → opt-in; the settlement/landed_ref note unaffected |
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
