# 005 — Tsugu v1.1: agent-first revisions

## Relationship to 004

This spec **extends** `004-tsugu-skill-design.md`. The `.tsugu/` namespace idea,
git-native intake, the convergence packet, the no-skill-orchestration rule, and
the multi-agent reservations all stand unchanged. 005 revises four surfaces,
found by dogfooding:

| Line | Change | What it supersedes in 004 |
| --- | --- | --- |
| A | One command per routine: `/tsugu:init` `/tsugu:prepare` `/tsugu:converge` | "Packaging & file layout" — the single `commands/tsugu.md` router |
| B | `prepare` asks once where to get tasks/context (recorded, no adapter) | Extends `init`'s "Intake sources?" question and the human-bridge interface |
| C | Agent-first lifecycle: **`converge` absorbs `settle`** (three routines); settlement becomes a **derived** git fact, not a written status; `branch.md` → per-ref `context.md`; `.tsugu/context/` → `.tsugu/knowledge/`; push by default; public/default branches MAY carry `.tsugu/` (`public-branch-tsugu: include\|exclude`, default `include`) | The four-routine lifecycle (the `settle` routine and its ⚙/🔒 step list fold into `converge`); design principle #5; success criterion #7; the settle "no `.tsugu/` in the diff" guarantee; `init`'s neutral auto-push question; the `branch.md` name and its `settled` status; the `.tsugu/` placement table's "ephemeral, work-branch-only" entries (those become the `exclude`-mode description); the `context/` directory name; the rule that `claimed-by`/`claimed-at` are "retained as historical state on settle/pause" (in `include` mode the merge-back rewrite drops them — git history and `runs/` are the durable record); the packet's "Suggested public branch … not 'push this branch as-is'" semantics (in `include` mode it is exactly "merge this branch"); the two-layer-lifecycle rule that *settle* flips intake notes (the flip moves to merge confirmation, with `prepare`/`converge` tidy as a backstop) |
| D | `init` re-run migrates an older `.tsugu/` to the current schema (`tsugu-schema` version stamp + documented migration steps) | Extends the `init` idempotency rule |

Everything in 004 not named in this table is unchanged.

## Motivation

Four dogfooding observations and one orientation shift:

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
   machine. And once settlement is derived, `settle`'s remaining work — update
   the context note, merge back — happens **while the human is already
   present**, so a separate routine duplicates `converge`.
5. **Shipped repos drift behind the plugin.** 005 itself changes the
   `policy.md` schema and renames paths, so already-initialized repos need an
   upgrade path that is not "hand-edit the files."

## A — One command per routine

Replace `commands/tsugu.md` with three thin routers (the lifecycle is three
routines now — see C1):

```text
plugins/tsugu/commands/
  init.md        →  /tsugu:init
  prepare.md     →  /tsugu:prepare
  converge.md    →  /tsugu:converge
```

- Each command file invokes the `tsugu` skill with its routine fixed, and
  passes any extra `$ARGUMENTS` through as free-form context for that routine
  (for `converge`, a branch name — see C1).
- **No overview command and no `settle` command.** The three commands are the
  whole surface; the skill's own trigger description still routes
  natural-language requests.
- The skill is unchanged structurally: one `SKILL.md`. Routing text, the
  frontmatter description (the trigger surface currently advertising
  `/tsugu [init|prepare|converge|settle]`), README, and the root `CLAUDE.md`
  all update to the three-routine surface.
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

## C — Agent-first lifecycle

### Orientation

The end state Tsugu serves is **agents coordinating through git, with humans
assisting** — not agents producing artifacts for human-centric review flows.
`.tsugu/` notes are the agents' shared memory; hiding them from public branches
optimizes for human reviewers at the cost of agent legibility. 005 makes agent
legibility the default and keeps the human-reviewer posture as per-repo opt-out.

Three state-model consequences follow, beyond the publishing defaults: the
lifecycle loses its fourth routine (C1), settlement is **derived from the DAG**
instead of written (C4), and the per-branch note becomes a **per-ref context
file** that every branch — default included — carries and rewrites (C2).

### C1 — `converge` absorbs `settle`: three routines

With settlement derived (C4), `settle`'s remaining substance is "update
`context.md` and merge back to the default branch" — work that happens while
the human is already present. A separate routine only re-created the
decided-but-not-settled gap. The lifecycle becomes **`init → prepare →
converge`**, where `converge` runs decision *and* completion in one
human-present session:

1. **Fetch-first** (same read path as `prepare`): resolve `<remote>` +
   `<default>`, `git fetch`, read everything from remote-tracking refs — a
   `converge` on machine B reconstructs the full state from `git fetch` alone.
2. **Ask which branch.** List the candidate work branches (those not skipped by
   the C4 partition), each with a one-line `context.md` summary and packet
   hint, and ask the human which to converge. An explicit branch argument
   (`/tsugu:converge <branch>`) skips the question.
3. Lay out the packet, prepared branches/worktrees, what was tried / worked /
   failed / evidence / remaining uncertainties; surface open questions
   (including unconfigured intake sources and any reconciliation cases — C4).
4. Decide *with* the human, then **complete the disposition in-session**:
   - **Accepted (`include` mode):** freshness-rebase onto the fetched default →
     verify (build/tests) → rewrite `context.md` to the post-merge mainline
     narrative (C2) → push → the human merges (or approves the PR). Once the
     merge is confirmed, run the **completion tail**, in this order: promote
     reusable knowledge to `knowledge/shared/`; remove the pending-merge line
     from the mainline `context.md` (a `.tsugu/`-only commit — private space
     per 004; **skip when the default branch is push-protected**: the named
     marker is already treated as residue by the partition (C4) and
     disappears with the next mainline rewrite); flip the intake note
     `claimed → done`, recording the landed tip SHA in the note as a durable
     breadcrumb; and **only then** clean up worktrees and branches (worktree
     remove before branch delete, as always). Branch deletion comes after the
     flip because the branch *is* the ancestry evidence — a lingering merged
     branch is harmless (ancestry-filtered; prune any time), while deleting
     it before the flip would turn an interruption into a false
     reconciliation case. The tail is idempotent: if interrupted before the
     flip, the note stays `claimed` and a later tidy pass re-enters the
     **whole** tail, not just the flip (C4); interrupted after the flip, only
     harmless cleanup remains.
   - **Accepted (`exclude` mode):** cut a clean `public/*` branch from the
     fetched default, apply accepted code/test/doc/config **by path** (no
     `.tsugu/` in the public diff), verify, human-approved PR. The work branch
     keeps its work-form `context.md` with `status: converged` until the
     public PR's landing is confirmed (C4), then the same completion tail runs.
   - **Rejected:** record why where it may matter (run note; intake note →
     `dropped`), remove worktrees, delete the branch when safe. To keep a
     rejected branch, mark it `paused` with a do-not-resume note (C4).
   - **Paused:** set `status: paused`, update the packet, write a run note
     listing what is needed to resume.
5. **Wait for approval before any public coordination** — opening/merging the
   PR is the human's act; Tsugu never auto-merges. When the merge cannot happen
   in-session (a collaborative PR awaiting other reviewers), the branch carries
   `status: converged (pending merge)` (C2) and a later session or tidy pass
   finishes the completion tail.

Tsugu still invokes no user-installed skill here: it presents and yields; the
human triggers workflow skills by keyword. The packet may hint which skill
fits, but must not fire it.

### C2 — `context.md`: every ref describes itself

`branch.md` is renamed **`context.md`**, and its scope widens: it describes
**the situation and origin of the ref it lives on** — any branch, the default
branch included.

- **On a work branch:** what 004's `branch.md` carried — `status:`
  (`open | paused | converged` — see C4 for why `settled` is gone),
  `claimed-by:` / `claimed-at:`, why this branch exists, current understanding,
  open questions, next actions, verification, promotion candidates — plus
  links to **its own** packet and run notes (slug defaults to the branch
  name), so a reader navigates to the relevant evidence instead of scanning
  directories.
- **On the default branch:** the mainline's current situation — what this repo
  is, where the mainline stands, what recently landed. No `status:` /
  `claimed-*` fields (those are work-branch concepts). `init` writes the first
  version.
- **Inherit → rewrite cycle:** a new work branch cut from default inherits the
  mainline `context.md`; the agent's first act of real work rewrites it into
  the branch's own narrative ("why this branch exists"). There is always a
  `context.md`; whether it has been rewritten distinguishes untouched from
  active branches. **Fallback partition rule:** a branch with real commits but
  a still-mainline-form `context.md` (agent crashed before the rewrite) is
  treated as `open`, unclaimed.
- **Rewrite on merge-back (`include` mode):** before the work branch merges,
  `converge` rewrites `context.md` into the post-merge mainline narrative:
  read the default branch's current `context.md` from the fetched ref,
  integrate what this work changes, drop the work-only fields — **except one
  line**: until the merge is confirmed, the file keeps
  `status: converged (pending merge of <branch>)` — **naming the branch** — so
  the partition can still classify the branch during the PR-waiting window.
  After merge the line is mainline residue: the completion tail removes it
  (C1), and until then a branch inheriting a marker that names a *different*
  branch treats it as residue, not its own status (C4).
  Work-specific history stays in the keyed `runs/` and `packets/` files.
  Concurrent merges may conflict on `context.md`; that conflict is meaningful
  (two narratives to integrate) and is resolved by rewriting against the
  then-current default version during the freshness rebase.
- **Load semantics after `include` merges:** `runs/` and `packets/` accumulate
  on the default branch as inherited archive. **Never read them wholesale** —
  navigate via the active branch's `context.md` (which names its own files) or
  via an intake note's breadcrumb. `knowledge/` remains the only deliberately
  curated tier.
- **Backward compatibility:** readers accept a legacy `branch.md` when
  `context.md` is absent on a work branch; a legacy `status: settled` is
  treated as "skip" (see C4). Live work branches migrate on next touch; only
  templates and references change centrally (see D).

### C3 — `.tsugu/context/` → `.tsugu/knowledge/`

With `context.md` taken as "this ref's situation," the promoted-knowledge
directory `.tsugu/context/` (`shared/`, `dormant/`, `archived/`) is renamed
**`.tsugu/knowledge/`** to avoid two adjacent meanings of "context". Semantics
are unchanged: `knowledge/` holds deliberately promoted, durable knowledge on
the coordination ref; `context.md` describes the here-and-now of one ref.

### C4 — Settlement is derived, not written

The `status:` enum shrinks to **`open | paused | converged`**. There is no
written `settled` state. **A branch is settled when its tip is an ancestor of
the fetched default ref** (`git merge-base --is-ancestor <branch-ref>
<remote>/<default>`) — settled work *is* merged work — **or when it has been
cleaned up**: a deleted branch is not in the queue at all.

- **Queue pre-filter:** `prepare`'s partition (and `converge`'s candidate
  list) first drops ancestor branches — merged work *and* freshly-cut branches
  with no commits — before reading `context.md`. This is what makes inherited
  mainline `context.md` files harmless. **Exemption:** a branch that is the
  `linked-branch:` of a `claimed` intake note is never pre-filtered — a
  zero-commit branch with a claim is interrupted work to resume (or a
  reconciliation case, below), not a fresh cut to ignore. Evidence-only
  branches (`investigate/*` whose whole deliverable is `.tsugu/` notes) have
  commits, so they stay visible like any other work; in `include` mode,
  merging that evidence *is* their accepted outcome.
- **`exclude` mode reaches settlement through explicit completion, not
  ancestry.** The by-path `public/*` cut never carries the work branch's
  `.tsugu/` commits, so the work branch never becomes an ancestor of default.
  The landing check is run against the **public branch** (recorded in the work
  branch's `context.md` / packet): once `public/<slug>` is an ancestor of the
  fetched default, the work is confirmed landed — run the completion tail
  (intake → `done`, promotion, cleanup of both branches). Until then the work
  branch's `status: converged` keeps it skipped.
- **Intake-note closing requires confirmed landing — and precedes only
  cleanup.** Flip `claimed → done` only when ancestry confirms the landing
  (the work branch itself in `include` mode; the linked public branch in
  `exclude` mode) **and promotion + residue removal have run; branch/worktree
  cleanup alone comes after the flip** (C1), so the ancestry evidence — the
  branch — survives every interruption window. The flip records the landed
  tip SHA in the note as a durable breadcrumb. An interrupted tail thus stays
  discoverable: the note remains `claimed` with its branch intact, and a
  `prepare`/`converge` tidy pass re-enters the whole idempotent tail for
  sessions that ended before or during completion.
  **Absence is never proof of success:** a `claimed` note whose linked branch
  is gone *without* ancestry evidence (accidental deletion, rejection that
  didn't update the note, force-push) is a **reconciliation case** — surface
  it to the human at the next `converge`; never auto-flip it to `done` or
  `dropped`.
- **Rejected work** writes no status either: record the reason where it may
  matter (run note; intake note → `dropped`), then remove worktrees and delete
  the branch when safe. To keep a rejected branch around, mark it `paused`
  with a do-not-resume note — `paused` is a resume *candidate*, not an
  auto-resume: the partition offers it, and the agent reads the `context.md`
  note before touching it, so a "rejected — do not resume" note is honored.
- **`converge` still writes `converged`** (a human decision is a real event
  git does not record) — but only when completion cannot finish in-session
  (the pending-merge window, C1/C2). `paused` still marks parked work. Both
  are human-meaningful, non-derivable states — exactly the ones worth writing.
  The partition matches `converged` **by prefix**: the
  `(pending merge of <branch>)` parenthetical (C2) is annotation, not a
  fourth state — but a marker that names a **different** branch than the one
  being read is inherited mainline residue, not that branch's status; the C2
  fallback rule (`open`, unclaimed) applies instead.

### C5 — Push by default

The `init` question "may agents create/commit/push preparation branches
automatically?" gains a **yes** default (004 asked it neutrally, with no
default). Pushing is what makes the branch a message: the MacBook `converge`
and the next scheduled agent both read remote-tracking refs. A repo can still
answer no; `prepare` then commits locally and stops for approval, as the
shipped v1.0 SKILL.md prepare step already specifies.

### C6 — `public-branch-tsugu: include | exclude`

New `policy.md` field, default **`include`**:

- **`include` (default):** the work branch **is** the public branch — converge
  Accepted merges it directly (C1). Merging makes settlement ancestry-true
  (C4) and lands the branch's `.tsugu/` evidence (`runs/`, `packets/`, the
  rewritten `context.md`) on the default branch as durable shared memory. No
  fresh `public/*` cut, no by-path filtering, no separate evidence-landing
  step. Trade-offs, stated openly: mainline history carries the agent's
  (possibly messy) preparation commits and `.tsugu/` files; in the agent-first
  orientation that history *is* the memory, and the repo's merge convention
  (merge commits, no squash) preserves it.
- **`exclude` (opt-out):** 004's behavior — cut a fresh `public/*` branch from
  the fetched `<remote>/<default>`, apply accepted changes **by path** so the
  public diff introduces no `.tsugu/` changes. For collaborative repos where
  human reviewers should not see coordination metadata in PRs. Completion and
  cleanup per C4's exclude-mode landing check.

Unchanged in both modes: verification before the human gate, PR
opening/merging stays human-gated, promotion to `knowledge/shared/`, cleanup
order (`git worktree remove` before branch delete). The `public/*` prefix
remains in the default prefix set but is only used by `exclude` mode.

### Ripple

- `templates/`: `branch.md` → `context.md` (work-branch form; `init` writes
  the default-branch form); `policy.md` gains `public-branch-tsugu` + the new
  defaults wording; `packet.md`'s "Suggested public branch" comment (written
  for the always-cut-fresh model) reworded for both modes.
- SKILL.md: frontmatter description (trigger surface: three routines, no
  "clean public form" framing) and the spine's legibility bullet
  (`branch.md` → `context.md`); init (schema stamp, migration decision, push
  default, intake question); prepare (queue pre-filter + exemption, intake
  backstop, push default); converge (absorbs settle: fetch-first, branch
  selection, dispositions, completion tail, pending-merge state); boundary +
  multi-agent sections (enum, `context.md`, claimed-field lifecycle).
- `references/git-recipes.md`: ancestry checks (work branch / public branch),
  queue pre-filter + exemption, include-mode merge-back, freshness rebase,
  `knowledge/` paths; the by-path clean-cut recipe becomes the `exclude` arm
  of converge.
- `references/notes-and-packet.md`: `context.md` per-ref semantics (inherit →
  rewrite, merge-back rewrite, pending-merge line, own-files links), load
  semantics for accumulated `runs/`/`packets/`, both-mode placement/durability,
  packet wording.
- `references/policy-and-intake.md`: new fields; intake recorded form, dedup +
  re-open scope, push-protected persistence, reconciliation rule.

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
- **Push-protected default branches:** the whole migration rides an `init/*`
  branch + human-approved PR (the 004 `init` rule), and any coordination-ref
  change (e.g. the `knowledge/` rename) is performed only **after** that PR
  merges — otherwise schema-1 readers and the renamed coord ref would disagree
  during the window. Until the migration completes, readers accept both
  `context/` and `knowledge/` names.

### Migration 1→2 (shipped with this spec)

1. Add `public-branch-tsugu:` to `policy.md` (ask once, default `include`).
2. Re-wrap any existing `## Intake Sources` content into the structured entry
   format (B), preserving listed sources. This re-wrap is **not** fully
   mechanical: a legacy free-prose entry (e.g. "gh issues") has no derivable
   `read:` instruction — such entries take the ask-once path (or are carried
   over with an explicit `read: TODO (ask the human)` marker when no human is
   available).
3. Rename `.tsugu/context/` → `.tsugu/knowledge/` on the coordination ref
   (`git mv`, contents preserved; deferred until the policy PR merges when the
   default branch is push-protected).
4. Update `.tsugu/templates/` from the plugin (`branch.md` template replaced
   by `context.md`).
5. Write the default branch's `.tsugu/context.md` (mainline form) if absent.
6. Add `tsugu-schema: 2` — **last**, after steps 1–5 succeed.

Live work branches are **not** migrated centrally: agents read legacy
`branch.md` / `status: settled` per the C2/C4 compatibility rules, and each
branch converts on its next touch.

## Affected surface

| File | Change |
| --- | --- |
| `commands/tsugu.md` | **removed** |
| `commands/{init,prepare,converge}.md` | **new** thin routers |
| `skills/tsugu/SKILL.md` | frontmatter description; spine legibility bullet; routing; init (schema stamp, migration decision, push question default, intake question); prepare (queue pre-filter + exemption, intake backstop, push default); converge (absorbs settle — see C1); settle section removed; boundary + multi-agent sections (enum, `context.md`, claimed-field lifecycle) |
| `skills/tsugu/templates/policy.md` | `tsugu-schema`, `public-branch-tsugu`, new Intake Sources format, push default wording |
| `skills/tsugu/templates/branch.md` → `templates/context.md` | renamed + per-ref semantics (work-branch and mainline forms) |
| `skills/tsugu/templates/packet.md` | "Suggested public branch" comment reworded for both modes |
| `skills/tsugu/references/policy-and-intake.md` | new fields; intake recorded form, dedup + re-open scope, push-protected persistence, reconciliation rule |
| `skills/tsugu/references/git-recipes.md` | ancestry checks; pre-filter + exemption; include-mode merge-back; freshness collapse; `knowledge/` paths; clean-cut as `exclude` arm |
| `skills/tsugu/references/notes-and-packet.md` | `context.md` per-ref semantics + pending-merge line + own-files links; accumulated `runs/`/`packets/` load semantics; both-mode placement/durability; packet wording |
| `skills/tsugu/references/migrations.md` | **new** — migration rules + steps, starting with 1→2 |
| `skills/tsugu/README.md` | command surface; lifecycle (three routines); `.tsugu/` diagram (`knowledge/`, `context.md`); former settle content folded into converge, clean-cut described as the `exclude` arm; add 005 spec link |
| `plugins/tsugu/.claude-plugin/plugin.json` | description updated to the three-routine surface (currently advertises `settle` twice) |
| `.claude-plugin/marketplace.json` | tsugu entry: description updated to three routines + minor version bump |
| root `CLAUDE.md` | tsugu section: three commands, three-routine lifecycle, agent-first defaults |

## Success criteria

1. `/tsugu:init`, `/tsugu:prepare`, `/tsugu:converge` each run their routine
   directly; no `/tsugu:tsugu` form and no `settle` command remain.
2. A first interactive `prepare` on a repo with unconfigured intake sources
   asks once, records the answer (including a confirmed-negative form) in
   `policy.md`, and subsequent scheduled runs read it without asking.
3. A scheduled `prepare` with unconfigured sources falls back to git-native,
   never blocks, and surfaces the open question at `converge`.
4. With defaults, `prepare` on machine A pushes branches + `.tsugu/` such that
   a fetch-first `converge` on machine B reconstructs the full state from
   `git fetch` alone.
5. `converge` lists candidate branches and asks which to work on; an explicit
   branch argument skips the question; Accepted work completes in-session
   (rebase, verify, `context.md` rewrite, human merge, intake close,
   promotion, cleanup) with no separate settle step.
6. With `public-branch-tsugu: include`, merging the work branch lands its
   `.tsugu/` evidence on the default branch and leaves the default branch's
   `context.md` rewritten to the post-merge reality; with `exclude`, the
   public diff introduces no `.tsugu/` changes (004 behavior) and landing is
   confirmed via the public branch's ancestry.
7. No written `settled` state exists: a merged work branch is skipped by the
   queue via ancestry alone; a branch freshly cut from default is skipped
   unless a `claimed` intake note links it; legacy `status: settled` notes are
   still read as "skip".
8. An intake note flips to `done` only on ancestry-confirmed landing, after
   promotion + residue removal and before branch cleanup, recording the
   landed tip SHA (an interrupted tail re-enters via tidy); a `claimed` note
   whose branch vanished without evidence is surfaced for human
   reconciliation, never auto-closed.
9. Re-running `/tsugu:init` on a schema-1 repo migrates it to schema 2 without
   losing any curated `policy.md` content; an interrupted migration re-enters
   safely (stamp written last); re-running after completion is a no-op.

## Deferred (unchanged from 004)

Multi-agent arbitration, tracker adapters, external notification, automatic
periodic sync of long-lived branches. Re-opened intake items (B) are also
deferred.
