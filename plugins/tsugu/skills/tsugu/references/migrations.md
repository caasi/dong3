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
  branch + human-approved PR (the 004 `init` rule). Any **coordination-ref**
  change — e.g. the `knowledge/` rename — is deferred and performed only **after**
  that PR merges; otherwise schema-1 readers and the renamed coordination ref
  would disagree during the window. Until the migration completes, readers accept
  **both** `context/` and `knowledge/` names. **The `tsugu-schema` stamp lives in
  `policy.md` on the default branch, so it always rides the policy `init/*` PR —
  but that PR is merged only *after* the coordination-ref rename is confirmed on
  its own ref** (they are not one commit when the coordination ref is a separate
  branch). Two cases: when `coordination-ref` is `default`, the rename and the
  stamp travel in the same PR (stamp written last within it); when it is a
  separate pushable branch (the usual push-protected setup), the rename is pushed
  to that branch first and confirmed, then the policy PR carrying the stamp is
  merged. Either way the stamp is genuinely last — while it is absent a re-run
  re-enters, so the schema never reads complete over a half-applied rename.

## Migration 1→2

Schema 1 is the 004 layout: any `.tsugu/` without a `tsugu-schema` field is
schema 1 by definition. Schema 2 is this spec's layout — the `tsugu-schema`
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
instruction, an interpretation hint). This re-wrap is **not** fully mechanical: a
legacy free-prose entry (e.g. "gh issues") has no derivable `read:` instruction.
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
**coordination-ref** change, so on a push-protected default branch it is
**deferred until the policy PR merges** (see the contract above); readers accept
both `context/` and `knowledge/` until then. The step 8 schema stamp is **gated
on this rename**: the policy PR carrying the stamp merges only after the rename is
confirmed on its ref (same PR when `coordination-ref=default`; the separate coord
branch is renamed first otherwise).

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
