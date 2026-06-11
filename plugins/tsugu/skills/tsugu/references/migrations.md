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
  migration steps below **in order** (N→N+1 until current), then update the stamp
  and commit. The commit message names the migration range (e.g.
  `chore(tsugu): migrate .tsugu/ schema 1→2`).

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
  the **last** write to land; how the `knowledge/` rename orders against it
  depends on where the coordination ref lives. When `coordination-ref` is
  `default` (the default branch itself), the rename is also a default-branch
  change and travels **in the same policy PR**, stamp written last within it — one
  atomic merge. When `coordination-ref` is a separate pushable branch (the usual
  push-protected setup), the rename is pushed to that branch **first** and
  confirmed, **then** the policy PR carrying the stamp is merged. Either way the
  stamp lands only after the rename is confirmed, and while it is absent a re-run
  re-enters — so the schema never reads complete over a half-applied rename.
  Throughout the window readers accept **both** `context/` and `knowledge/` names,
  so a schema-1 reader and the renamed coordination ref never disagree.

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
evidence lands on the default branch, or a clean public branch is cut by path),
so a step MAY ask the human. If the human does not decide, write `include` and
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
so existing `public/*` branches keep their meaning as decided/landed outputs
(pending/landed, never work candidates). The two lists must stay disjoint. Do not
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
order on the `init/*` branch. A schema-1 repo runs **1→2→3**: the 1→2 steps
(which create `intake/`, seed `templates/`, etc.) run first, then 2→3
removes/relocates them — wasteful but correct under the sequential contract; an
implementation MAY short-circuit but is not required to.

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
