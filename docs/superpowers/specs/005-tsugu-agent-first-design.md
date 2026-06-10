# 005 — Tsugu v1.1: agent-first revisions

## Relationship to 004

This spec **extends** `004-tsugu-skill-design.md`. The lifecycle, the `.tsugu/`
namespace idea, git-native intake, the convergence packet, the
no-skill-orchestration rule, and the multi-agent reservations all stand
unchanged. 005 revises four surfaces, found by dogfooding:

| Line | Change | What it supersedes in 004 |
| --- | --- | --- |
| A | One command per routine: `/tsugu:init` `/tsugu:prepare` `/tsugu:converge` `/tsugu:settle` | "Packaging & file layout" — the single `commands/tsugu.md` router |
| B | `prepare` asks once where to get tasks/context (recorded, no adapter) | Extends `init`'s "Intake sources?" question and the human-bridge interface |
| C | Agent-first publishing & derived settlement: push by default; `branch.md` → per-ref `context.md`; `settled` becomes a **derived** git fact, not a written status; `.tsugu/context/` → `.tsugu/knowledge/`; public/default branches MAY carry `.tsugu/` (`public-branch-tsugu: include\|exclude`, default `include`) | Design principle #5; success criterion #7; the settle "no `.tsugu/` in the diff" guarantee; `init`'s neutral auto-push question; the `branch.md` name and its `settled` status; the `.tsugu/` placement table's "ephemeral, work-branch-only" entries (those become the `exclude`-mode description); the `context/` directory name |
| D | `init` re-run migrates an older `.tsugu/` to the current schema (`tsugu-schema` version stamp + documented migration steps) | Extends the `init` idempotency rule |

Everything in 004 not named in this table is unchanged.

## Motivation

Three dogfooding observations and one orientation shift:

1. **Command ergonomics.** The single router command surfaces as
   `/tsugu:tsugu init` — the doubled name is noise for a command meant to be run
   daily and wired to schedulers.
2. **Scheduled `prepare` needs a configured source.** The intended usage is:
   run `prepare` once by hand, then wire it to `/schedule`/cron every few hours.
   A scheduled run cannot ask where tasks come from, so the *first interactive*
   run must ask and record the answer.
3. **Cross-machine handoff is the normal case, not the edge case.** The user
   runs `prepare` on a Linux machine and `converge` on a MacBook. That only
   works if `.tsugu/` state is pushed by default — and it reframes the design:
   **the primary goal is agents coordinating through git; humans assist.** 004
   centered the human reviewer (clean PR diffs, `.tsugu/` kept out of public
   branches); 005 flips the default and keeps the human-reviewer posture as an
   opt-out.
4. **Written terminal state duplicates what git already knows.** 004 tracked
   `settled` as a written `branch.md` status. But "this work landed on the
   mainline" is a fact git itself records (ancestry). Deriving settlement from
   the DAG removes a whole class of state-sync bugs (stale statuses, inherited
   terminal states polluting fresh branches) and shrinks the internal state
   machine.
5. **Shipped repos drift behind the plugin.** 005 itself changes the
   `policy.md` schema and renames paths, so already-initialized repos need an
   upgrade path that is not "hand-edit the files."

## A — One command per routine

Replace `commands/tsugu.md` with four thin routers:

```text
plugins/tsugu/commands/
  init.md        →  /tsugu:init
  prepare.md     →  /tsugu:prepare
  converge.md    →  /tsugu:converge
  settle.md      →  /tsugu:settle
```

- Each command file invokes the `tsugu` skill with its routine fixed, and
  passes any extra `$ARGUMENTS` through as free-form context for that routine.
- **No overview command.** The four commands are the whole surface; the skill's
  own trigger description still routes natural-language requests.
- The skill is unchanged structurally: one `SKILL.md`, four routines. Only the
  routing text changes (SKILL.md "Routing" section, README, root `CLAUDE.md`
  "One slash command" → four commands).
- The plugin version in `.claude-plugin/marketplace.json` gets a minor bump.

## B — `prepare` asks where tasks come from (record, no adapter)

004's intake design stands: git is the inbox; external trackers are an optional
human-bridge; Tsugu ships **no adapter**. 005 adds the *configuration moment*
and the *recorded form*.

### The configuration moment

`init` keeps its "Intake sources?" question (default: none — git-native only),
as in 004. `prepare` adds a **backstop** for repos initialized before this
question existed, or where the human deferred the answer at `init`.

`prepare` distinguishes its **work posture** (external silence — unchanged)
from a one-time **setup question**, which is allowed because the first
`prepare` run is typically interactive:

- On start, after reading `policy.md`: if `## Intake Sources` is still the
  unconfigured default **and** a human can respond (the run is interactive),
  ask once:

  > Git-native intake is the default. Should I also read tasks/context from an
  > external source (a task manager, issue tracker, notes file)? If so, give me
  > the read instruction — a shell command, file path, or MCP tool name.

  Record the answer in `policy.md` under `## Intake Sources` and continue. A
  **negative answer is also recorded** — as
  `default: git-native (confirmed — no external sources)` — so it is textually
  distinct from the unconfigured default and the question is never re-asked.
- If no human can respond (scheduled/headless run), **never block**: fall back
  to git-native intake, and note in the run note + packet that intake sources
  are unconfigured — `converge` surfaces this as an open question.
- **Push-protected default branch:** `policy.md` lives on the default branch,
  so when that branch is push-protected the answer cannot be pushed directly.
  Follow the 004 `init` rule: write the change on an `init/*` branch and open a
  human-approved PR (the human is present at the configuration moment, so the
  approval can happen right then). Until it merges, runs treat the field as
  unconfigured and fall back to git-native.
- Reconfiguration is not a special mode: the human edits `policy.md`, or runs
  `/tsugu:prepare` interactively and says to change the source.

### The recorded form

Each configured source is a natural-language entry plus **one read
instruction** — no per-system integration logic in the plugin:

```md
## Intake Sources
default: git-native. Each additional source below is read on every prepare run.

- name: my-todos
  read: `cat ~/notes/todo.md`          # shell command, file path, or MCP tool name
  notes: lines starting with "- [ ]" are open tasks; mention repo names to scope.
```

On each run, `prepare` executes the read instruction, interprets the result
with the `notes:` hint, and converts anything new into committed
`.tsugu/intake/<slug>.md` notes (`status: open`,
`## Observed source: human-bridge: <name>`). Downstream is identical to 004 —
the queue read, partition, and routines operate only on git.

**Dedup rule:** derive the slug from a stable identifier in the source (issue
number, todo line hash, title slug). If an intake note with that slug already
exists at the coordination ref — in **any** status — skip it. A `done`/`dropped`
note is the durable record that the item was already processed; re-import would
resurrect finished work. **Re-opened source items are out of scope for v1.1:**
a source item that comes back to life after its note is closed is not
re-imported automatically — the human (or the human instructing the agent)
authors a fresh intake note with a new slug.

## C — Agent-first publishing & derived settlement

### Orientation

The end state Tsugu serves is **agents coordinating through git, with humans
assisting** — not agents producing artifacts for human-centric review flows.
`.tsugu/` notes are the agents' shared memory; hiding them from public branches
optimizes for human reviewers at the cost of agent legibility. 005 makes agent
legibility the default and keeps the human-reviewer posture as per-repo opt-out.

Two state-model consequences follow, beyond the publishing defaults:
settlement is **derived from the DAG** instead of written (C3), and the
per-branch note becomes a **per-ref context file** that every branch — default
included — carries and rewrites (C1).

### C1 — `context.md`: every ref describes itself

`branch.md` is renamed **`context.md`**, and its scope widens: it describes
**the situation and origin of the ref it lives on** — any branch, the default
branch included.

- **On a work branch:** what 004's `branch.md` carried — `status:`
  (`open | paused | converged` — see C3 for why `settled` is gone),
  `claimed-by:` / `claimed-at:`, why this branch exists, current understanding,
  open questions, next actions, verification, promotion candidates.
- **On the default branch:** the mainline's current situation — what this repo
  is, where the mainline stands, what recently landed. No `status:` /
  `claimed-*` fields (those are work-branch concepts). `init` writes the first
  version.
- **Inherit → rewrite cycle:** a new work branch cut from default inherits the
  mainline `context.md`; the agent's first act of real work rewrites it into
  the branch's own narrative ("why this branch exists"). This replaces 004's
  "fresh branch has no `branch.md` yet" gap — there is always a `context.md`,
  and whether it has been rewritten distinguishes untouched from active
  branches (the queue additionally pre-filters untouched branches via the
  derived check, C3).
- **Rewrite on merge-back:** before a work branch merges into the mainline
  (`include` mode, C5), `settle`'s final commit on the branch **rewrites
  `context.md` into the post-merge mainline narrative**: read the default
  branch's current `context.md` from the fetched ref, integrate what this work
  changes, drop the work-only fields. After the merge, the default branch's
  `context.md` reflects current reality — it is maintained narrative, not
  residue. Work-specific history stays in the keyed `runs/` and `packets/`
  files, which accumulate without collisions. Concurrent merges may conflict on
  `context.md`; that conflict is meaningful (two narratives to integrate) and
  is resolved by rewriting against the then-current default version during the
  freshness rebase.
- **Backward compatibility:** readers accept a legacy `branch.md` when
  `context.md` is absent on a work branch; a legacy `status: settled` is
  treated as "skip" (see C3). Live work branches migrate on next touch; only
  templates and references change centrally (see D).

### C2 — `.tsugu/context/` → `.tsugu/knowledge/`

With `context.md` taken as "this ref's situation," the promoted-knowledge
directory `.tsugu/context/` (`shared/`, `dormant/`, `archived/`) is renamed
**`.tsugu/knowledge/`** to avoid two adjacent meanings of "context". Semantics
are unchanged: `knowledge/` holds deliberately promoted, durable knowledge on
the coordination ref; `context.md` describes the here-and-now of one ref.

### C3 — Settlement is derived, not written

The `status:` enum shrinks to **`open | paused | converged`**. There is no
written `settled` state. **A branch is settled when git says so: it contributes
no non-`.tsugu/` changes beyond the fetched default ref.**

- **Primary signal — ancestry:** after the branch itself merges (the `include`
  default, C5), `git merge-base --is-ancestor <branch> <remote>/<default>`
  holds. Cheap, exact, and meaningful: settled work *is* merged work.
- **Queue pre-filter:** `prepare`'s partition gains a git-level first check —
  a branch whose contribution is empty (just cut, or already landed) is
  skipped before its `context.md` is even consulted. This is what makes
  inherited mainline `context.md` files harmless: nothing reads them as work
  state on a branch that has no work.
- **By-path landings** (`exclude` mode) don't produce ancestry. There the 004
  freshness rebase does the job: rebasing the work branch onto the fetched
  default drops already-applied patches, after which the contribution is empty
  and ancestry holds. Exact mechanics → `references/git-recipes.md`.
- **Settled branches get cleaned up, and absence is the strongest signal:** a
  deleted work branch is not in the queue at all. `settle` (and the human) may
  delete merged work branches per policy; until cleanup, the derived check
  keeps them skipped.
- **Rejected work** writes no status either: record the reason where it may
  matter (run note; intake note → `dropped`), then remove worktrees and delete
  the branch when safe. To keep a rejected branch around, mark it `paused`
  with a note saying why.
- **Intake-note closing decouples from a status write:** flip `claimed → done`
  once the merge is confirmed. If the session ends before the human merges,
  the note stays `claimed`; a later `prepare` run may tidy it — flip to `done`
  when the linked branch is derived-settled or gone. Same for the legacy
  table: an intake note whose linked branch shows legacy `status: settled` is
  closeable.
- **converge still writes `converged`** (a human decision is a real event git
  does not record), and `paused` still marks parked work. Both are
  human-meaningful, non-derivable states — exactly the ones worth writing.

### C4 — Push by default

The `init` question "may agents create/commit/push preparation branches
automatically?" defaults to **yes** (004 asked it neutrally, with no default).
Pushing is what makes the branch a message: the MacBook `converge` and the next
scheduled agent both read remote-tracking refs. A repo can still answer no;
`prepare` then commits locally and stops for approval, as the shipped v1.0
SKILL.md prepare step already specifies.

To make success criterion #4 (cross-machine handoff) hold, **`converge` gains
the same fetch-first read path as `prepare`**: resolve `<remote>` + `<default>`,
`git fetch`, and read packet/branches/`context.md` from remote-tracking refs —
machine B reconstructs the full state from `git fetch` alone.

### C5 — `public-branch-tsugu: include | exclude`

New `policy.md` field, default **`include`**:

- **`include` (default):** the work branch **is** the public branch. `settle`
  Accepted = freshness-rebase onto the fetched default, verify (build/tests),
  rewrite `context.md` to the post-merge narrative (C1), push, then the
  human-gated PR **of the work branch itself**. Merging it makes settlement
  ancestry-true (C3) and lands the branch's `.tsugu/` evidence (`runs/`,
  `packets/`, the rewritten `context.md`) on the default branch as durable
  shared memory. No fresh `public/*` cut, no by-path filtering, no separate
  evidence-landing step. Trade-offs, stated openly: mainline history carries
  the agent's (possibly messy) preparation commits and `.tsugu/` files; in the
  agent-first orientation that history *is* the memory, and the repo's merge
  convention (merge commits, no squash) preserves it.
- **`exclude` (opt-out):** 004's behavior — cut a fresh `public/*` branch from
  the fetched `<remote>/<default>`, apply accepted code/test/doc/config **by
  path** so the public diff introduces no `.tsugu/` changes. For collaborative
  repos where human reviewers should not see coordination metadata in PRs.
  Settlement is still derived (C3, via rebase-collapse), and cleanup of the
  work branch after the public PR merges follows 004's settle.

Unchanged in both modes: verification before the human gate, PR opening stays
human-gated, promotion to `knowledge/shared/`, cleanup order
(`git worktree remove` before branch delete). The `public/*` prefix remains in
the default prefix set but is only used by `exclude` mode.

### Ripple

- `templates/`: `branch.md` → `context.md` (work-branch form; `init` writes
  the default-branch form), `policy.md` gains `public-branch-tsugu` + the new
  defaults wording.
- SKILL.md: prepare (queue pre-filter, push default, intake backstop),
  converge (fetch-first, status write), settle (both C5 arms, derived
  settlement, intake tidy), boundary section, multi-agent section (enum).
- `references/git-recipes.md`: derived-settlement checks, include-mode settle,
  freshness-rebase collapse, `knowledge/` paths; the by-path clean-cut recipe
  becomes the `exclude` arm.
- `references/notes-and-packet.md`: `context.md` semantics (per-ref, inherit →
  rewrite, merge-back rewrite), placement/durability wording for both modes,
  packet's "Suggested public branch" wording.
- `references/policy-and-intake.md`: new fields; intake recorded form, dedup +
  re-open scope, push-protected persistence.

## D — `init` re-run migrates (`tsugu-schema`)

004's idempotency rule ("repair missing skeleton paths, never overwrite a
curated `policy.md`") cannot express renames or semantic changes. 005 adds
deterministic, version-stamped migration.

### Version stamp

`policy.md` gains a `tsugu-schema: N` field (integer). Schema history:

- **Schema 1** — the 004 layout. Any `.tsugu/` without a `tsugu-schema` field
  is schema 1 by definition.
- **Schema 2** — this spec: `tsugu-schema` itself, `public-branch-tsugu`, the
  structured `## Intake Sources` format, `context.md` (file + default-branch
  form), and the `knowledge/` rename.

### `init` re-run decision

1. No `.tsugu/` → fresh init (004 flow), stamped with the current schema.
2. `.tsugu/` present, `tsugu-schema` == current → 004 idempotent repair only.
3. `.tsugu/` present, schema older → apply documented migration steps in order
   (N→N+1 until current), then update the stamp and commit. The commit message
   names the migration range (e.g. `chore(tsugu): migrate .tsugu/ schema 1→2`).

### Migration rules

- Steps live in a new `references/migrations.md`, one section per step:
  *condition → actions → what must not be touched*.
- Migrations **add or restructure schema parts only — never overwrite curated
  content**. Existing intake-source entries, boundary edits, opted-in skills,
  and prefix customizations are preserved verbatim or re-wrapped in the new
  format.
- **Each migration action is idempotent, and the stamp is written last.** A
  migration may stop midway (a non-mechanical conflict, an interruption); the
  stamp still says the old schema, so the re-run re-enters the same migration
  and the already-applied actions no-op. Only after every action of a step
  succeeds is `tsugu-schema` updated.
- `init` is human-triggered, so a migration step MAY ask once when a new field
  is behavior-changing (progressive-init rule from 004). Concretely, 1→2 asks
  about `public-branch-tsugu` with default `include`; if the human does not
  decide, write the default and say so in the commit message.
- A migration that cannot be applied mechanically (a curated section
  conflicting with the new structure) **stops and asks** — never force-resolve.
- Push-protected default branches follow the 004 `init` rule: write the
  migration on an `init/*` branch and open a human-approved PR.

### Migration 1→2 (shipped with this spec)

1. Add `public-branch-tsugu:` to `policy.md` (ask once, default `include`).
2. Re-wrap any existing `## Intake Sources` content into the structured entry
   format (B), preserving listed sources. This re-wrap is **not** fully
   mechanical: a legacy free-prose entry (e.g. "gh issues") has no derivable
   `read:` instruction — such entries take the ask-once path (or are carried
   over with an explicit `read: TODO (ask the human)` marker when no human is
   available).
3. Rename `.tsugu/context/` → `.tsugu/knowledge/` on the coordination ref
   (`git mv`, contents preserved).
4. Update `.tsugu/templates/` from the plugin (`branch.md` template replaced
   by `context.md`).
5. Write the default branch's `.tsugu/context.md` (mainline form) if absent.
6. Add `tsugu-schema: 2` — **last**, after steps 1–5 succeed.

Live work branches are **not** migrated centrally: agents read legacy
`branch.md` / `status: settled` per the C1/C3 compatibility rules, and each
branch converts on its next touch.

## Affected surface

| File | Change |
| --- | --- |
| `commands/tsugu.md` | **removed** |
| `commands/{init,prepare,converge,settle}.md` | **new** thin routers |
| `skills/tsugu/SKILL.md` | routing; init (schema stamp, migration decision, flipped push default, intake question); prepare (queue pre-filter, intake backstop, push default); converge (fetch-first, `converged` write); settle (C5 arms, derived settlement, intake tidy); boundary + multi-agent sections (enum, `context.md`) |
| `skills/tsugu/templates/policy.md` | `tsugu-schema`, `public-branch-tsugu`, new Intake Sources format, push default wording |
| `skills/tsugu/templates/branch.md` → `templates/context.md` | renamed + per-ref semantics (work-branch and mainline forms) |
| `skills/tsugu/references/policy-and-intake.md` | new fields; intake recorded form, dedup + re-open scope, push-protected persistence |
| `skills/tsugu/references/git-recipes.md` | derived-settlement checks; include-mode settle; freshness collapse; `knowledge/` paths; clean-cut as `exclude` arm |
| `skills/tsugu/references/notes-and-packet.md` | `context.md` per-ref semantics + both-mode placement/durability; packet wording |
| `skills/tsugu/references/migrations.md` | **new** — migration rules + steps, starting with 1→2 |
| `skills/tsugu/README.md` | command surface + new defaults |
| `.claude-plugin/marketplace.json` | tsugu plugin minor version bump |
| root `CLAUDE.md` | tsugu section: four commands, agent-first defaults |

## Success criteria

1. `/tsugu:init`, `/tsugu:prepare`, `/tsugu:converge`, `/tsugu:settle` each
   run their routine directly; no `/tsugu:tsugu` form remains.
2. A first interactive `prepare` on a repo with unconfigured intake sources
   asks once, records the answer (including a confirmed-negative form) in
   `policy.md`, and subsequent scheduled runs read it without asking.
3. A scheduled `prepare` with unconfigured sources falls back to git-native,
   never blocks, and surfaces the open question at `converge`.
4. With defaults, `prepare` on machine A pushes branches + `.tsugu/` such that
   a fetch-first `converge` on machine B reconstructs the full state from
   `git fetch` alone.
5. With `public-branch-tsugu: include`, merging the work branch lands its
   `.tsugu/` evidence on the default branch and leaves the default branch's
   `context.md` rewritten to the post-merge reality; with `exclude`, the
   public diff introduces no `.tsugu/` changes (004 behavior).
6. No written `settled` state exists: a merged work branch is skipped by the
   queue via the derived check alone, and a branch freshly cut from default
   (inherited mainline `context.md`, no commits) is likewise skipped. Legacy
   `status: settled` notes are still read as "skip".
7. Re-running `/tsugu:init` on a schema-1 repo migrates it to schema 2 without
   losing any curated `policy.md` content; an interrupted migration re-enters
   safely (stamp written last); re-running after completion is a no-op.

## Deferred (unchanged from 004)

Multi-agent arbitration, tracker adapters, external notification, automatic
periodic sync of long-lived branches. Re-opened intake items (B) are also
deferred.
