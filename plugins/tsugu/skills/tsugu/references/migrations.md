# migrations

These are **documented migration steps** — guidance an `init` re-run follows with
its own judgment, not scripts to run blindly. Tsugu ships no scripts; every
action below is plain git (or a file edit) the agent performs inline, reading the
situation and adapting. Where a step says "ask once" or "stops and asks", that is
a deliberate decision point for the agent's judgment, not a branch to automate
away.

## The migration contract

`init` is human-triggered and idempotent. On every re-run it makes one of three
decisions by reading `policy.md`'s `tsugu-schema:` stamp:

- **fresh** — no `.tsugu/` present → fresh init (the 004 flow), stamped with the
  current schema.
- **repair** — `.tsugu/` present and `tsugu-schema` already current → plain
  idempotent repair only: fill any missing skeleton path, never overwrite a
  curated `policy.md`.
- **migrate** — `.tsugu/` present and the stamp is older → apply the documented
  migration steps below **in order** (N→N+1 until current — the full chain is
  `1→2→3→4→5→6→7→8`), then update the stamp and commit. The commit message names the
  migration range (e.g. `chore(tsugu): migrate .tsugu/ schema 1→2`).

The steps obey these rules, which hold for every migration (not just 1→2):

- **Each step is *condition → actions → what must not be touched*.** A step runs
  only when its condition holds; it performs its listed actions; it leaves
  everything else — curated content a human tuned — untouched.
- **Migrations add or restructure schema parts only — never overwrite curated
  content.** Existing intake-source entries, boundary edits, opted-in skills, and
  prefix customizations are preserved verbatim or re-wrapped in the new format.
- **Every step is idempotent by virtue of its condition.** A migration may stop
  midway — a non-mechanical conflict, an interruption. Re-running `init` re-enters
  the same migration; each step whose condition no longer holds no-ops. The
  idempotency lives in the condition guards, not in the raw actions (a bare
  `git mv` run twice fails — see step 5).
- **The stamp is written last.** Only after every action of a step succeeds is
  `tsugu-schema` updated. Because the stamp still reads the *old* schema while a
  migration is in flight, an interrupted re-run re-enters the same migration
  rather than skipping past a half-applied one.
- **A behavior-changing field MAY ask once.** `init` is human-triggered, so a
  step that introduces a new field whose value changes behavior may ask the
  human a single question (the progressive-init rule from 004). If the human does
  not decide, write the documented default and say so in the commit message.
- **A non-mechanical conflict stops and asks.** When a curated section conflicts
  with the new structure and cannot be re-wrapped mechanically, the migration
  **stops and asks** — never force-resolve.
- **Push-protected default branches:** the whole migration rides an `init/*`
  branch + human-approved PR (the 004 `init` rule). The `tsugu-schema` stamp lives
  in `policy.md` on the default branch, so it always rides this policy PR and is
  the **last** write to land. Where a migration also renames a store, how that
  rename orders against the stamp depends on which ref holds the store. When it is
  the default branch itself, the rename travels **in the same policy PR**, stamp
  written last within it — one atomic merge. When it is a separate pushable branch
  (before schema 8, a `coordination-ref` such as `tsugu/coord`; the usual
  push-protected setup), the rename is pushed to that branch **first** and
  confirmed, **then** the policy PR carrying the stamp is merged. Either way the
  stamp lands only after the rename is confirmed, and while it is absent a re-run
  re-enters — so the schema never reads complete over a half-applied rename.
  Throughout such a window readers accept **both** the old and the new directory
  names, so a stale reader and the renamed ref never disagree.

## Migration 1→2

Schema 1 is the 004 layout: any `.tsugu/` without a `tsugu-schema` field is
schema 1 by definition. Schema 2 is the spec 005 layout — the `tsugu-schema`
stamp itself, `public-branch-tsugu`, `## Handoff Prefixes` (with legacy `public/*`
folded in), the structured `## Intake Sources` format, the pure-narrative
`context.md` (work-branch + default-branch forms), the `landed:` intake field, and
the `.tsugu/context/` → `.tsugu/knowledge/` rename. Apply these eight steps in
order on the `init/*` branch.

**1. Add `public-branch-tsugu:` to `policy.md`** — ask once, default `include`.
This field is behavior-changing (it decides whether the work branch's `.tsugu/`
evidence rides the default branch, or is kept off it — the human strips it when
publishing), so a step MAY ask the human. If the human does not decide, write `include` and
note the default in the commit message. Condition: the field is absent. Do not
touch any existing `policy.md` content.

**2. Add `## Handoff Prefixes` and narrow `## Branch Prefixes`.** Write
`## Handoff Prefixes` with the default `feat/* fix/*` (ask once to confirm if the
repo's branch-naming convention is visible). Narrow `## Branch Prefixes` to
**work-only** by **preserving the repo's configured work prefixes** and removing
only `public/*` from them — `prepare/* investigate/* review/*` is the default
*only when the section was never customized*; a repo that added e.g. `explore/*`
keeps it (the contract forbids overwriting curated prefixes). Crucially, **append
legacy `public/*` to the Handoff Prefixes list** — never to the work prefixes —
so existing `public/*` branches keep their meaning as taken-over/landed outputs
(never work candidates). The two lists must stay disjoint. Do not
rename or delete any existing branch.

**3. Add the merge-commit recommendation line to `policy.md`.** Record the
`## Merge method` guidance: prefer merge commits, do not squash-merge
tsugu-managed branches (derived settlement depends on preserved history); if a
human system forces a squash, converge confirms the landing and records
`landed: <sha>`. Condition: the recommendation is absent.

**4. Re-wrap `## Intake Sources` into the structured entry format.** Preserve
every listed source; rewrite each into the structured form (a name, one `read:`
pointer, an interpretation hint). This re-wrap is **not** fully mechanical: a
legacy free-prose entry (e.g. "gh issues") has no derivable `read:` pointer.
Such entries take the **ask-once** path — or, when no human is available, are
carried over verbatim with an explicit `read: TODO (ask the human)` marker rather
than guessed at. Never drop a listed source.

**5. Rename `.tsugu/context/` → `.tsugu/knowledge/` on the coordination ref.**
Condition: `.tsugu/context/` still exists and `.tsugu/knowledge/` does not.

```bash
git mv .tsugu/context .tsugu/knowledge
```

If `.tsugu/knowledge/` already exists (a prior partial migration moved it) this
step is **already done — skip it; do not re-run the move.** `git mv` is not
idempotent: with the source gone it fails, and with the target directory already
present it nests `context/` *inside* `knowledge/` instead of erroring — so verify
`.tsugu/knowledge/` is absent before the move.

Contents are preserved: existing tier subdirectories (e.g. `context/shared`,
`context/dormant`, `context/archived` from the 004 layout) **ride along as plain
folders**, since no internal layout is prescribed anymore. This is a
**coordination-ref** change. On a push-protected default branch the rename
completes on its own ref **before** the schema stamp lands — in the same `init/*`
PR when `coordination-ref=default`, or pushed to the separate coord branch first
otherwise (see the contract above). Readers accept both `context/` and
`knowledge/` names meanwhile, and step 8's stamp is **gated on this rename**: the
policy PR carrying it merges only once the rename is confirmed.

**6. Refresh `.tsugu/templates/` from the plugin.** Replace the schema-1
`branch.md` template with the pure-narrative `context.md`; update `intake.md` so
it gains the `landed:` field. Templates are plugin-owned scaffolding, not curated
content, so refreshing them is safe. Condition: `branch.md` still exists, or
`intake.md` lacks a `landed:` field.

> **Under the shipped (schema-3) plugin, the schema-2-only templates
> `branch.md`, `intake.md`, and `run.md` are no longer shipped.** Refresh only
> the templates the current plugin actually provides, and **skip the rest** — do
> not try to copy a template the plugin stopped shipping. This step exists for a
> repo migrating *only* 1→2 under a schema-2 plugin; on the **1→2→3** path the
> very next migration removes `templates/` (and `intake/`/`runs/`) wholesale, so
> there is nothing to gain by materializing them (see the 1→2→3 note under
> *Migration 2→3*).

**7. Write the default branch's mainline `context.md` if absent.** Write the
default-branch (mainline) form of `context.md` — the mainline note **file**
`.tsugu/context.md`, distinct from the `context/` **directory** renamed in step 5.
Condition: it does not already exist — never overwrite a curated mainline note.

**8. Add `tsugu-schema: 2` — last.** Only after steps 1–7 have all succeeded,
stamp `tsugu-schema: 2` as the first line of `policy.md`. This is what marks the
migration complete; until it is written, a re-run re-enters migration 1→2 and the
already-applied steps no-op. **Push-protected exception:** the stamp still rides
the `policy.md` PR, but that PR merges only **after** step 5's coordination-ref
rename is confirmed on its ref — they share the PR when `coordination-ref=default`,
otherwise the separate coord branch is renamed first. The stamp is gated on the
rename, so the schema never reads complete while a step is still pending.

## Live work branches convert on next touch

Live work branches are **not** migrated centrally — this migration touches the
default branch and the coordination ref, not every in-flight `prepare/*`. Agents
read legacy work branches per the schema-1 compatibility rules: when `context.md`
is absent, fall back to `branch.md`; read a legacy `status:` once and fold it into
the narrative on the branch's next touch (a legacy `settled` becomes a cleanup
candidate; a legacy `converged` is surfaced at the next `converge`). Each branch
converts to schema 2 on its own next touch — no central rewrite.

## Migration 2→3

Schema 3 is this spec's layout: the committed `.tsugu/` shrinks to
`policy.md` + `context.md` + `knowledge/`; the personal observation config
(intake sources + opted-in skills) moves to the migrating machine's global
folder; and `intake/`, `runs/`, `packets/`, and repo `templates/` are gone
(stopped going forward; existing history left intact). Apply these five steps in
order on the `init/*` branch. A schema-1 repo runs **1→2→3**. Because 2→3 removes
`intake/`, `runs/`, `packets/`, and `templates/` wholesale — and the shipped
schema-3 plugin **no longer carries** the schema-2-only templates (`branch.md`,
`intake.md`, `run.md`) that 1→2 step 6 would otherwise refresh — apply the
**durable** 1→2 changes and skip **only the *filesystem* scaffolding** that 2→3
deletes. Concretely:

- **Apply** (these survive into schema 3, or are required by 2→3): the
  `context/`→`knowledge/` rename (1→2 step 5); the surviving policy fields
  (`public-branch-tsugu`, `## Handoff Prefixes`, the merge-method line — steps 1–3);
  the mainline `context.md` (step 7); **and 1→2 step 4 — re-wrapping
  `## Intake Sources` into the structured `name`/`read:`/`notes` form.** Step 4 is
  **not** optional on this path: 2→3 step 1 relocates those `## Intake Sources`
  entries *verbatim* into the personal `config.md`, which requires that structure —
  skipping it would copy unstructured legacy entries and leave the migrated sources
  unusable. Finally **1→2 step 8 stamps `tsugu-schema: 2`**, completing 1→2 per the
  N→N+1 contract; **only then** does 2→3 run and stamp `tsugu-schema: 3` last.
- **Skip** (transient; 2→3 deletes it, and the schema-3 plugin no longer ships it):
  materializing the `intake/`/`runs/` directories, seeding `templates/`, and
  refreshing the `branch.md`/`intake.md`/`run.md` templates (1→2 step 6's
  unshipped parts).

The net effect is the schema-3 layout, the migrated intake sources are
well-formed, and the path never depends on a template the plugin stopped shipping.
(Carrying the filesystem scaffolding through and letting 2→3 delete it is also
correct — just wasteful — but **only** where those schema-2 templates are still
available; under the shipped plugin they are not, so skip.)

**1. Move personal sections out of `policy.md`.** Condition: either
`## Intake Sources` or `## Skills Tsugu may use (this repo, opt-in)` is still
present in committed `policy.md`. Read both sections, write them into **the
migrating machine's** personal folder `~/.claude/tsugu/<project-key>/config.md`
(intake sources + opt-in skills); **then remove** both sections from `policy.md`.
The shipped-invariant `## Skill use` section stays. `<project-key>` is the
common-git-dir-derived key (stable across worktrees), not the raw checkout path.
This step is **re-entrant, so an abandoned policy PR is safe.** The personal write
is the durable copy and is **re-derivable from the old `policy.md` until the
removal lands**: the write happens locally and outside git, while the section
removal rides the `init/*` policy PR on a push-protected default. If that PR is
rejected/abandoned, committed `policy.md` still carries the sections, so a re-run
simply re-reads them and re-writes the (unchanged) personal copy — no
double-source-of-truth survives a re-run, and the personal write happening first
is harmless. **Other machines self-seed by re-asking:** once the migration merges,
`policy.md` no longer carries these sections, so each other machine's next
interactive `prepare`/`converge` re-asks (separately for sources and skills) via
the bootstrap behavior and seeds *that machine's* personal folder. Observation
config is per-machine and is not meant to transfer — there is **no git-history
recovery and no in-repo breadcrumb**.

**2. Remove the relocated/removed committed paths — per-path, idempotent, and
history-preserving.** Condition: any of `.tsugu/intake`, `.tsugu/runs`,
`.tsugu/packets`, `.tsugu/templates` still exists. This **stops writing them
going forward; leave history intact — never rewrite history** (rewriting would
violate the protect-primary-history invariant, and the old artifacts are
harmless). Remove each path **only if present**, because a bare `git rm -r` fails
if any pathspec matches nothing and a partial tree need not have all of them (the
schema-2 skeleton seeds only `intake/`/`knowledge/`/`templates/`; `runs/` and
`packets/` appear on first `prepare`, so a repo that never ran `prepare` has
neither). Use a per-path guard or the `--ignore-unmatch` flag:

```bash
git rm -r --ignore-unmatch .tsugu/intake
git rm -r --ignore-unmatch .tsugu/runs
git rm -r --ignore-unmatch .tsugu/packets
git rm -r --ignore-unmatch .tsugu/templates
```

It is `--ignore-unmatch` (no trailing `d`); `--ignore-unmatched` is not a valid
git flag and aborts the command. With it, the step no-ops cleanly on a partial
tree and an interrupted re-run re-enters. **Cross-ref placement:** only `intake/`
lives on the **coordination ref**; `runs/`/`packets/` (accumulated on the default
branch when work branches merge in `include` mode) and repo-seeded `templates/`
live on the **default branch**. So the removal spans two refs whenever
`coordination-ref != default` (the push-protected setup that 1→2 already handles
for the `context/→knowledge/` rename): remove `intake/` on the coordination ref
and `runs/`/`packets/`/`templates/` on the default branch, with the **coord-ref
deletion confirmed before the step-5 schema stamp**, exactly as 1→2 orders its
coord-ref rename ahead of the stamp. When `coordination-ref = default`, all of it
rides the one `init/*` policy PR, stamp last. In-flight work branches simply
**stop** writing `runs/`/`packets/` and convert on next touch; the `git rm`
targets the copies already accumulated on default. Throughout the window a reader
tolerates the old dirs still being present — they are inert once `prepare`/
`converge` stop writing them.

**3. Redefine `public-branch-tsugu` wording** in `policy.md` per E2 — **same
value, only the description changes** to the WIP-knowledge framing (whether the
work branch's committed WIP-knowledge layer — its prep commit DAG plus its
`context.md` narrative — lands on the public/default branch; `knowledge/` lands on
the coordination ref regardless of mode). Also remove any `landed:` / intake-flip
wording from `## Merge method`, replacing it with the retain-handoff guidance: a
forced-squash landing **retains the handoff branch** so the pairing carries the
awaiting-merge state, with the `context.md` narrative as the backstop when the
forge deletes the branch anyway. Condition: the old wording is present. **Never
change the chosen value** — only its description.

**4. Switch template reads to `${CLAUDE_PLUGIN_ROOT}`.** `init`/`prepare`/
`converge` now read templates from
`${CLAUDE_PLUGIN_ROOT}/skills/tsugu/templates/` instead of the repo's
`.tsugu/templates/` (removed in step 2). The `context.md` template loses its
`runs/`/`packets/` links. **No repo template files are written.**

**5. Stamp `tsugu-schema: 3` — last.** Only after steps 1–4 have all succeeded,
stamp `tsugu-schema: 3` as the first line of `policy.md`. This is what marks the
migration complete; until it is written, a re-run re-enters migration 2→3 and the
already-applied steps no-op. **Push-protected exception:** the stamp rides the
`policy.md` PR, but that PR merges only **after** step 2's coordination-ref
deletion (`intake/`) is confirmed on its ref — they share the PR when
`coordination-ref = default`, otherwise the separate coord branch's deletion lands
first. The stamp is gated on that confirmation, so the schema never reads complete
while a step is still pending.

Live work branches are not migrated centrally — they convert on next touch (the
schema-compat `branch.md`/`context.md` reads still apply).

## Migration 3→4

Schema 4 is the spec 007 layout: a **mental-model simplification**, not a storage
change. Three things move: the policy section `## Handoff Prefixes` is renamed
`## Accepted Prefixes` (E1); the default work prefix collapses from
`prepare/* investigate/* review/*` to **`prepare/*` alone** — but only on human
confirmation, never auto (E2); and existing branches under the removed prefixes
are handled per-branch, never renamed (E3). Apply these steps in order on the
`init/*` branch. A schema-1 repo runs **1→2→3→4→5→6→7** under the N→N+1 contract — 1→2,
then 2→3, then 3→4, then 4→5, then 5→6, then 6→7, each stamping its own schema last
before the next runs.

### E1 — Rename (always-applied, mechanical)

**1. Rename `## Handoff Prefixes` → `## Accepted Prefixes`.** The heading changes;
the **content is preserved verbatim** — a schema-3 repo's curated `feat/* fix/*`
stay exactly as they are. This renames a schema part only; it never overwrites
curated content. Condition: a `## Handoff Prefixes` section is still present.

*(The schema stamp is **not** written here — it is the final step E4, after E2
and E3, so an interrupted collapse/legacy pass is never stamped complete.)*

### E2 — Interactive prefix-collapse proposal

**2. Propose collapsing `## Branch Prefixes` to `prepare/*` — ask the human.**
Condition: `## Branch Prefixes` contains **more than** `prepare/*`. Migration
**proposes** collapsing to the single `prepare/*` default and **asks the human to
confirm**; it **never auto-changes a curated prefix set**. If the human **declines**,
the multi-prefix set is kept as-is (fully supported going forward) and the
migration completes with **only E1 applied** — skip E3.

**Order matters for restart-safety — do NOT rewrite `## Branch Prefixes` yet.**
On confirmation, *first* **record the removed work prefixes** (every work prefix
except `prepare/*`, read from the still-intact `## Branch Prefixes`) into the
`## Legacy Work Prefixes` policy note, *then* run E3 against that recorded set.
The actual collapse of `## Branch Prefixes` → `prepare/*` is **deferred to after
E3** (step 3d). This ordering is what makes the migration re-entrant: if it is
interrupted before the stamp, the next run either still sees the multi-prefix
`## Branch Prefixes` (E2 re-proposes and re-derives) **or** finds the removed set
preserved in `## Legacy Work Prefixes` — so the custom prefixes E3 needs are never
lost. (Were the list collapsed first, an interruption would leave `prepare/*`
alone in `## Branch Prefixes` with no way to recover what was removed.)

**Post-collapse disjointness re-check.** The collapse can *introduce* an overlap a
schema-3 repo did not have: a repo could legally have curated work prefixes
`investigate/* review/*` and accepted prefixes `prepare/* feat/*` (disjoint under
schema 3). After E1's rename **and** this collapse, the work set becomes
`prepare/*` while the renamed accepted set still contains `prepare/*` → **overlap**,
violating the work ∩ accepted = ∅ invariant. So after the rename and collapse,
migration **re-runs the work ∩ accepted = ∅ disjointness check**. On overlap it
**stops and asks** the human to pick a different accepted prefix or to decline the
collapse; the collapse is **not committed until the two sets are disjoint**.

### E3 — Per-branch legacy handling (only if the collapse is accepted)

If the human accepts the collapse, migration handles existing branches under
**every work prefix the collapse removes** — not only the defaults
`investigate/* review/*`, but **any custom work prefix** the schema-3 repo had
configured (e.g. `research/*`). Use the **removed set recorded in step 2's
`## Legacy Work Prefixes` note** (equivalently the pre-collapse `## Branch
Prefixes`, still intact at this point — `## Branch Prefixes` is not collapsed
until step 3d). **Never hardcode the old defaults**, or branches under a custom
prefix silently escape discovery. Handle each such branch **without renaming any
branch** — write-once identity is inviolate. For each, first check whether `prepare/<slug>` already
exists, because in schema 3 a same-slug artifact (e.g. `review/<slug>`) is
typically the **artifact** of an existing `prepare/<slug>`.

**3a. `prepare/<slug>` already exists (the legacy branch is an artifact).** No
recreate — `git branch prepare/<slug>` would fail against the live work branch.
Whether deletion is safe depends on whether the legacy branch carries commits the
work branch lacks, so migration runs an **ancestry check** first:

```bash
git merge-base --is-ancestor <legacy-tip> <remote>/prepare/<slug>
```

- **fully contained** (exit 0; no unique commits) → truly redundant with the live
  work branch: migration **offers to delete it now** (confirmation; show the tip
  hash).
- **has commits `prepare/<slug>` lacks** (exit non-zero) → **not** redundant;
  **never auto-delete** — treat as **ambiguous (case 3c)**: stop and ask the human
  (who may merge the unique commits into `prepare/<slug>`, keep the branch, or drop
  it).

If the artifact is **not** deleted, migration records the dropped prefix in a
`## Legacy Work Prefixes` policy note, which the **completion-tail sweep also
consults** until no branches remain under it — otherwise, once the prefixes are
dropped, the sweep no longer *discovers* the removed prefixes and the branch
would strand. *Writes to `policy.md`:* pruning a prefix from the note (or removing
the now-empty note) is an **optional** tidy following the **same policy-write path
as any other `policy.md` edit** — direct on an unprotected default, or an `init/*`
branch + human-approved PR where the default is push-protected. A stale-but-empty
note is harmless (no branches under it → no sweep effect), so leaving it is always
acceptable; removal is never required.

**3b. No `prepare/<slug>` (a standalone legacy branch).** List the branch **name
and its tip commit hash**, and ask the human whether to **recreate** it as
`prepare/<slug>` pointing at that commit — a *copy*, not a rename, so write-once
identity holds:

```bash
git branch prepare/<slug> <tip-sha>   # then push
```

After the copy the old ref is redundant: **delete it** (recommended), **or**, if
the human keeps it, **record its dropped prefix in `## Legacy Work Prefixes`**
exactly as in case 3a — otherwise the retained old ref strands under the
collapsed-away prefix and is omitted from future completion-tail sweeps.

**3c. Ambiguous.** Multiple divergent legacy branches share one slug, or the human
wants to keep both the legacy branch and an existing `prepare/<slug>` → **stop and
ask**; the human resolves by hand (rename/drop as they choose). Migration never
picks for them and never force-overwrites a ref.

No legacy branch is touched without explicit per-branch confirmation. **Artifacts
(case 3a) are delete-or-record**, so they never strand. A **standalone branch
(case 3b) the human declines to recreate** stops being discovered under the new
single-prefix default — that is the human's explicit choice, surfaced as a
one-line note so it is never *silently* dropped.

**3d. Collapse `## Branch Prefixes` → `prepare/*` — now that every legacy branch
is handled.** This is the deferred write from step 2: only after 3a/3b/3c have
processed all branches under the removed prefixes is it safe to rewrite the work
prefix list to `prepare/*` alone. (Any prefix still needed for an un-handled or
human-retained branch remains recorded in `## Legacy Work Prefixes`, which the
completion-tail sweep consults until it empties.)

### E4 — Stamp last (the final action of the whole 3→4 migration)

**4. Stamp `tsugu-schema: 4` — last.** Only after E1, E2, and E3 (where they run)
have all succeeded, update the `tsugu-schema:` stamp to `4` as the first line of
`policy.md`. This is the **final action** of the migration and is what marks 3→4
complete; until it is written, the stamp still reads `3`, so an interrupted re-run
(e.g. the collapse was proposed but the legacy branches were not yet handled)
re-enters migration 3→4 and the already-applied steps (whose conditions no longer
hold) no-op. **Push-protected exception:** where the default branch is
push-protected, the whole migration rides an `init/*` branch + human-approved PR,
and the stamp rides as the **last** write to land — never a "complete" stamp over
a half-applied migration.

This migration changes policy fields and branch *refs* (E1–E3); it does **not**
rewrite the *content* committed on live work branches (their own `context.md`),
which is unchanged between schema 3 and 4.

## Migration 4→5

Schema 5 is the spec 012 layout: a **single behavior-changing default flips** —
`prepare` becomes **local-first**, so the `push-prepare-branches` default changes
from the old `yes` (push preparation branches) to the new `no` (keep work local;
push is a cross-machine opt-in). Nothing structural changes — **no committed
`.tsugu/` files or directories are added or removed**; the only changes are one
explicit policy field and the stamp. Apply these two steps in order on the `init/*`
branch. A schema-1 repo runs **1→2→3→4→5→6→7** under the N→N+1 contract — each prior
migration stamps its own schema last before the next runs.

**1. Pin the old default — write explicit `push-prepare-branches: yes` when the
field is absent.** Condition: `policy.md`'s `## Push` section has **no explicit
`push-prepare-branches` value**. Because schema 4 read an absent field as the old
`yes` default, simply bumping the stamp to 5 (whose absent default is the new `no`)
would **silently flip an existing repo's behavior**. So the migration **writes the
explicit `push-prepare-branches: yes`** into `## Push`, pinning the old behavior so
the upgrade changes nothing. **Never overwrite an explicit value** — a repo that
already set `push-prepare-branches` (to `yes` or `no`) keeps it verbatim (the
contract forbids overwriting curated content). This is the only action of the
migration; it is idempotent by its condition (a present value no-ops).

**2. Stamp `tsugu-schema: 5` — last.** Only after step 1 has succeeded (the
explicit value is present, written or already curated), update the `tsugu-schema:`
stamp to `5` as the first line of `policy.md`. This is the **final action** and is
what marks 4→5 complete; until it is written the stamp still reads `4`, so the
schema-aware default-read (absent → `yes` if schema 4, else `no`; SKILL.md step 9)
keeps the old behavior through the upgrade window, and an interrupted re-run
re-enters migration 4→5. **Push-protected exception:** where the default branch is
push-protected, the whole migration rides an `init/*` branch + human-approved PR,
and the stamp rides as the **last** write to land — never a "complete" stamp over a
half-applied migration (exactly as 004–011 specify).

This migration changes one policy field and the stamp; it touches no branch refs
and rewrites no `context.md`.

## Migration 5→6

Schema 6 is the spec 013 layout: `prepare` gains a **freshness-rebase** step that
keeps in-progress work branches current against the default branch. Like 4→5, this
is **one behavior-changing default plus one structural addition** — no branch refs
move and no existing `context.md` is rewritten. Apply these three steps in order on
the `init/*` branch. A schema-1 repo runs **1→2→3→4→5→6→7** under the N→N+1 contract —
each prior migration stamps its own schema last before the next runs.

**1. Pin the old default — write explicit `rebase-prepare-onto-default: no` when the
field is absent.** Condition: `policy.md` has **no `## Freshness` section**, or a
`## Freshness` section with **no explicit `rebase-prepare-onto-default` value**.
Because an absent field reads as `no` regardless of schema (the fail-safe default —
see SKILL.md's rebase step), a schema-5 repo already behaves as `no` today; but
schema 6 also ships a **fresh-init** default of `yes`, so leaving the field absent
after the stamp bumps would put the repo one accidental re-init away from silently
starting to rewrite and force-push its `prepare/*` branches. So the migration
**writes the explicit `rebase-prepare-onto-default: no`** into `## Freshness`
(creating the section if it doesn't exist), pinning the **pre-013** behavior so the
upgrade changes nothing unattended. **Never overwrite an explicit value** — a repo
that already set `rebase-prepare-onto-default` (to `yes` or `no`) keeps it verbatim
(the contract forbids overwriting curated content). To turn the routine refresh on,
the human flips the pinned `no` to `yes` — a deliberate, one-line opt-in. This step
is idempotent by its condition (an explicit value already present no-ops).

**2. Add `.tsugu/.gitattributes` — unconditionally.** Condition: `.tsugu/.gitattributes`
does not already exist. Write it with `context.md merge=union` (the
`templates/gitattributes` content). Unlike step 1, this action is **not
flag-gated and not conditioned on any policy value** — it is the one intentional,
flag-independent non-preservation in this migration: `context.md` is narrative, and
narrative should never block any merge, on any repo, regardless of whether
`rebase-prepare-onto-default` ends up `yes` or `no`. If the file already exists
(e.g. a human added it by hand), leave it untouched — the migration only creates it
when absent. This step is idempotent by its condition.

**3. Stamp `tsugu-schema: 6` — last.** Only after steps 1 and 2 have both succeeded
(the explicit `## Freshness` value is present, written or already curated, and
`.tsugu/.gitattributes` exists), update the `tsugu-schema:` stamp to `6` as the
first line of `policy.md`. This is the **final action** and is what marks 5→6
complete; until it is written the stamp still reads `5`, so an interrupted re-run
re-enters migration 5→6 and each step's condition guard makes the re-entry a no-op
for whatever already landed. **Push-protected exception:** where the default branch
is push-protected, the whole migration rides an `init/*` branch + human-approved
PR, and the stamp rides as the **last** write to land — never a "complete" stamp
over a half-applied migration (exactly as 004–012 specify).

This migration changes one policy field, adds one committed file
(`.tsugu/.gitattributes`), and the stamp; it touches no branch refs and rewrites no
existing `context.md`.

## Migration 6→7

Schema 7 is the spec 015 layout: the mainline `context.md` gains a standing
`POST-HANDOFF CLEANUP` block, and the repo's agent md gains a routing pointer. Like
5→6, this is **structural additions only** — no policy default changes, no branch
refs move, no existing `context.md` narrative is rewritten. A schema-1 repo runs
**1→2→3→4→5→6→7** under the N→N+1 contract. Apply these three steps in order on the
`init/*` branch.

**1. Normalize the mainline `context.md` block.** Condition: always (idempotent by
construction). **Strip every** `POST-HANDOFF CLEANUP` HTML-comment block from the
default branch's mainline `.tsugu/context.md`, then **re-append one canonical copy**
(the `templates/context.md` block). One rule heals all three states: absent → adds
it; present-and-canonical → identity; drifted or duplicated (a `prepare` rewrite that
retyped or duplicated it) → collapsed to one canonical copy. The strip matches
**only the HTML-comment shape carrying the reserved marker** — `POST-HANDOFF CLEANUP`
is a **reserved string inside `.tsugu/context.md` comments**, so normalization never
touches the surrounding curated `##` narrative. This is the **first** migration to
modify an existing curated `context.md` (5→6 only added a new file); appending/
normalizing a schema-owned region is "restructure the schema part," not "overwrite
curated content."

**2. Add the agent-md pointer.** Condition: the repo's agent md lacks the
`## tsugu — post-handoff cleanup` marker. Append the section from
`${CLAUDE_PLUGIN_ROOT}/skills/tsugu/templates/agent-md-pointer.md` to `CLAUDE.md`
(and `AGENTS.md` if the repo uses one) — **append-only, never rewriting existing
content**, human-approved (public coordination; `init` is human-present). Absent any
agent md, offer to create a minimal `CLAUDE.md`. Idempotent by the marker.

**3. Stamp `tsugu-schema: 7` — last.** Only after steps 1–2 succeed, update the
`tsugu-schema:` stamp to `7` as the first line of `policy.md`. Until it is written a
re-run re-enters migration 6→7 and each step's condition guard makes the re-entry a
no-op (or, for step 1, an idempotent identity). **Push-protected exception:** the
whole migration (context.md normalize + agent-md pointer + stamp) rides an `init/*`
branch + human-approved PR, stamp the **last** write to land — as 004–013 specify.

This migration changes no policy field, touches no branch refs, and rewrites no
surrounding `context.md` narrative.

## Migration 7→8

Schema 8 is the spec 022 layout: the committed store is renamed `knowledge/` →
`evidence/` and re-scoped from a repo-wide wiki on a coordination ref to a **per-ref
directory that is emptied at landing**; `merge=union` and `.tsugu/.gitattributes` are
removed; the `POST-HANDOFF CLEANUP` block stops being byte-immutable and gains the
four-way disposal; `## Promotion candidates` leaves `context.md`; and `## Coordination
ref` leaves `policy.md`.

**Condition:** `.tsugu/` present and `tsugu-schema` reads `7`.

**0. Read `coordination-ref` before anything else — the migration may span two refs.**
`knowledge/` is not necessarily on the default branch. `policy.md`'s
`coordination-ref: default` is a sentinel; the other setting is a separate branch,
preferably an **orphan** such as `tsugu/coord` that holds **only** `knowledge/`, with
`policy.md` always read from the default branch. Read the field **now**, because step 4
removes it, and split the steps by **where each file actually lives**:

| Steps | Ref |
|---|---|
| 1–2 (`knowledge/` rename and triage) | the ref `coordination-ref` names |
| 3–7 (`.gitattributes`, `policy.md`, `context.md`, agent md, stamp) | the **default branch**, always |

Running every step against the coordination ref is as wrong as ignoring the field.
On the orphan layout that branch has no `policy.md`, no `context.md` and no
`.gitattributes`, so steps 3–7 would no-op there while the default branch stayed at
schema 7. Ignoring the field instead makes step 1's guard find no `knowledge/`, step 2
triage nothing, and step 7 stamp schema 8 over content still sitting untriaged on a
branch nothing points at — a migration that reports success and did nothing. This is
the same two-ref split migration 2→3 states in its `Cross-ref placement:` paragraph,
with the same ordering rule: the coordination-ref work is pushed and **confirmed
first**, then the policy change carrying the stamp lands.

**1. Rename the store.** On the ref step 0 resolved, guarded on `knowledge/` still
existing (a bare `git mv` run twice fails, and onto an existing target directory it
**nests** instead of erroring — migration 1→2 step 5 states both):

```bash
[ -d .tsugu/knowledge ] && git mv .tsugu/knowledge .tsugu/evidence
```

Keep the `.gitkeep`. If `evidence/` already exists and `knowledge/` does not, this step
has run — no-op.

**2. Triage every entry — human-present, one by one, with no exemption.** Present each
entry with a proposed destination and **move it only on the human's approval**:

| The entry | Route | Approval |
|---|---|---|
| A convention this repo follows | `CLAUDE.md` / `AGENTS.md` | human approves — public coordination |
| An explanation a person reads | `docs/` | human approves — public coordination |
| A behaviour the code must keep | the test suite | none — an ordinary code change |
| Everything else | delete | none |

**A throwable spike gets no exemption.** 017's blessed transient is a *work-branch*
carve-out, and this store is not a work branch: a spike belonging to work that already
landed is done and is deleted, and a spike belonging to work still in flight sits on
that work's own branch, which this migration never touches. **Idempotency condition:**
an entry is presented only while it is still in `evidence/` on this ref. Dispose of
each entry as it is decided rather than collecting decisions and applying them at the
end, so the remaining contents *are* the record of what is left and an interrupted
re-run re-presents only the undecided ones.

**Then surface the old coordination branch**, if step 0 resolved a non-default ref:
say it now holds nothing tsugu reads and let the human decide. A remote delete is
public coordination and never happens without explicit per-item approval — the rule
`prune` states.

**3. Delete `.tsugu/.gitattributes`** (default branch). With no `merge=union`, nothing
auto-resolves `.tsugu/`; `prepare` resolves a narrative conflict itself and declines a
structural one. If the file is already absent, no-op.

**4. `policy.md`** (default branch): remove the `## Coordination ref` section and its
`coordination-ref:` field; drop the coordination-ref sentences from the
`## Public branch` comment; and edit `## Freshness`'s cost note, which names
union-interleave from a third section neither of the other two edits reaches.

**5. `context.md`** (default branch): remove `## Promotion candidates`; replace the
`POST-HANDOFF CLEANUP` block with the schema-8 text (no byte-immutability language;
the four-way `evidence/` disposal; a backstop cue that reads "the default branch's
`context.md` tells one branch's story instead of the mainline's" rather than
"duplicate `##` headers", which was union's signature and can no longer occur); and
update the `## Blindspots` comment's directory name.

**6. Agent-md pointer** (default branch): refresh the `## tsugu — post-handoff
cleanup` section to the new block text, including its own copy of the backstop cue.
Append-only, marker-idempotent, human-approved — the 015 rules are unchanged.

**7. Stamp `tsugu-schema: 8` — last.** Only after every step above succeeds, and
after the coordination-ref work of steps 1–2 is confirmed. Until the stamp is written
a re-run re-enters this migration and each condition guard makes the re-entry a no-op.

**Reader tolerance during the window.** A reader accepts `knowledge/` when `evidence/`
is absent, as the 1→2 window did for `context/`. A schema-7 repo is therefore readable
by a schema-8 agent before its `init` re-run.
