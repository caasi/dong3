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
| C | Agent-first lifecycle: **`converge` absorbs `settle`** (three routines); **all live branch state is derived from the DAG** (containment) — the `branch.md` status enum and the `claimed-by`/`claimed-at` fields are removed entirely; `branch.md` → per-ref `context.md` (pure narrative); `.tsugu/context/` → `.tsugu/knowledge/`; push by default; public/default branches MAY carry `.tsugu/` (`public-branch-tsugu: include\|exclude`, default `include`) | The four-routine lifecycle (the `settle` routine and its ⚙/🔒 step list fold into `converge`); design principle #5; success criterion #7; the settle "no `.tsugu/` in the diff" guarantee; `init`'s neutral auto-push question; the `branch.md` name, its entire `status:` lifecycle (`open\|paused\|converged\|settled`), and the `claimed-by`/`claimed-at` courtesy fields (claims are now derived from commits); the `.tsugu/` placement table's "ephemeral, work-branch-only" entries (those become the `exclude`-mode description); the `context/` directory name **and its prescribed `shared/dormant/archived` tier taxonomy** (the knowledge dir's internal structure is now the agents' own); the packet's "Suggested public branch … not 'push this branch as-is'" semantics (in `include` mode it is exactly "merge this branch"); the two-layer-lifecycle rule that *settle* flips intake notes (the flip moves to landing confirmation, with `prepare`/`converge` tidy as a backstop) |
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
4. **Written state duplicates what git already knows.** 004 tracked a
   four-value `status:` plus claim fields in `branch.md`. But "this work
   landed", "this work was handed off and awaits merge", "someone is actively
   on this", and "this branch grew out of that one" are all facts the DAG and
   its refs already record (ancestry, containment, commit authorship and
   recency, merge-base). Every written copy of a derivable fact is a second
   source of truth that can go stale, needs cleanup, and can disagree across
   machines. Deriving them removes the whole class — and once nothing terminal
   is written, `settle`'s remaining substance ("update the context note, merge
   back") happens while the human is already present, so a separate routine
   duplicates `converge`.
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

One principle governs all the state-model changes below:

> **Refs and the DAG carry everything that changes; text carries only
> write-once records.** Live coordination state — in progress / decided /
> landed / who's on it / what grew out of what — is derived from ancestry,
> containment, commit authorship, and recency, never written into files.
> Files hold what never changes after writing: narrative, run notes, packets,
> intake terminal records. Mutable state needs synchronization and cleanup;
> write-once records need neither.

Concretely: the lifecycle loses its fourth routine (C1), the per-branch note
becomes a pure-narrative per-ref context file (C2), and the entire written
state machine — `status:`, `claimed-by:`, `claimed-at:` — is replaced by DAG
facts (C4).

### C1 — `converge` absorbs `settle`: three routines

With state derived (C4), `settle`'s remaining substance is "update
`context.md` and merge back to the default branch" — work that happens while
the human is already present. A separate routine only re-created the
decided-but-not-settled gap. The lifecycle becomes **`init → prepare →
converge`**, where `converge` runs decision *and* completion in one
human-present session:

1. **Fetch-first** (same read path as `prepare`): resolve `<remote>` +
   `<default>`, `git fetch --prune`, read everything from remote-tracking
   refs — a `converge` on machine B reconstructs the full state from
   `git fetch` alone.
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
     narrative (C2) → push → hand off:
     - if the human can merge right now (solo flow), they merge the work
       branch directly — its tip is contained in default, settlement is
       immediate (C4);
     - otherwise, **cut a handoff branch named for the human workflow**
       (`git branch <handoff>/<slug> <work-branch>` — same commits, a second
       name; prefixes like `feat/*`/`fix/*` per repo convention, configured in
       `policy.md`) and open the PR **on the handoff branch**, human-approved.
       From that moment the work branch's tip is contained in a non-work ref —
       every machine's partition sees "decided, awaiting merge" from the DAG
       alone (C4).

     Once landing is confirmed (the tip reaches default), run the
     **completion tail**, in this order: promote reusable knowledge into
     `.tsugu/knowledge/`; flip the intake note `claimed → done`, recording the
     landed tip SHA in the note as a durable breadcrumb; and **only then**
     clean up worktrees and branches (worktree remove before branch delete, as
     always — the handoff branch too, if the forge didn't already delete it).
     Branch deletion comes after the flip because the branch *is* the
     ancestry evidence — a lingering merged branch is harmless
     (containment-filtered; prune any time), while deleting it before the
     flip would turn an interruption into a false reconciliation case. The
     tail is idempotent: interrupted before the flip, the note stays `claimed`
     with its branch intact and a later tidy pass re-enters the whole tail;
     interrupted after, only harmless cleanup remains.
   - **Accepted (`exclude` mode):** cut a clean public branch from the fetched
     default (named per the same human-workflow convention), apply accepted
     code/test/doc/config **by path** (no `.tsugu/` in the public diff),
     verify, human-approved PR. Landing is confirmed via the **public
     branch's** containment in default (the work branch records the public
     branch's name in `context.md` — a write-once breadcrumb, kept because
     by-path application breaks the containment link the DAG would otherwise
     provide); then the same completion tail runs.
   - **Rejected:** record why where it may matter (run note; intake note →
     `dropped`), remove worktrees, delete the branch when safe. To keep a
     rejected branch around, say so in its `context.md` narrative ("rejected —
     do not resume: <why>"); agents read the narrative before touching any
     candidate (C4).
   - **Parked:** update `context.md`'s narrative with what is needed to
     resume, update the packet, write a run note. No status to set — a parked
     branch is simply a candidate whose narrative says "blocked on X".
5. **Wait for approval before any public coordination** — opening/merging the
   PR is the human's act; Tsugu never auto-merges.

Tsugu still invokes no user-installed skill here: it presents and yields; the
human triggers workflow skills by keyword. The packet may hint which skill
fits, but must not fire it.

### C2 — `context.md`: every ref describes itself, in pure narrative

`branch.md` is renamed **`context.md`**, its scope widens, and **all state
fields are removed** — it is narrative plus write-once links, nothing else.

- **On a work branch:** why this branch exists, current understanding, open
  questions, next actions, verification, promotion candidates — plus links to
  **its own** packet and run notes (slug defaults to the branch name), and, in
  `exclude` mode, the public-branch breadcrumb (C1). No `status:`, no
  `claimed-*`: those facts are derived (C4). **Lineage is never recorded
  either** — which branch this one grew out of, and what its base is, are
  `merge-base`/ancestry questions the DAG answers exactly; a recorded copy
  only goes stale.
- **On the default branch:** the mainline's current situation — what this repo
  is, where the mainline stands, what recently landed. `init` writes the first
  version.
- **Inherit → rewrite cycle:** a new work branch cut from default inherits the
  mainline `context.md`; the agent's first act of real work rewrites it into
  the branch's own narrative. There is always a `context.md`. A branch with
  real commits whose `context.md` is still the inherited mainline form (a
  session that died before the rewrite) is simply an unclaimed candidate whose
  narrative hasn't been written yet — the partition needs no special rule for
  it (C4 derives "unclaimed" from commit authorship, not from the file).
- **Rewrite on merge-back (`include` mode):** before the work branch merges,
  `converge` rewrites `context.md` into the post-merge mainline narrative:
  read the default branch's current `context.md` from the fetched ref,
  integrate what this work changes. The file that lands on default is **pure
  desired content** — there is no state line to clean up afterwards, because
  "awaiting merge" lives in the DAG (handoff-branch containment, C1/C4), not
  in the file. Work-specific history stays in the keyed `runs/` and
  `packets/` files. Concurrent merges may conflict on `context.md`; that
  conflict is meaningful (two narratives to integrate) and is resolved by
  rewriting against the then-current default version during the freshness
  rebase.
- **Load semantics after `include` merges:** `runs/` and `packets/` accumulate
  on the default branch as inherited archive. **Never read them wholesale** —
  navigate via the active branch's `context.md` (which names its own files) or
  via an intake note's breadcrumb. `knowledge/` remains the only deliberately
  curated tier.
- **Backward compatibility:** readers accept a legacy `branch.md` when
  `context.md` is absent on a work branch. Legacy `status:` fields are read
  once and folded into the narrative on next touch; a legacy
  `status: settled` branch is a cleanup candidate; a legacy
  `status: converged` branch is surfaced at the next `converge` for its
  pending decision to be re-anchored (handoff branch or direct merge). Only
  templates and references change centrally (see D).

### C3 — `.tsugu/context/` → `.tsugu/knowledge/`, structure unprescribed

With `context.md` taken as "this ref's situation," the promoted-knowledge
directory `.tsugu/context/` is renamed **`.tsugu/knowledge/`** to avoid two
adjacent meanings of "context".

The same reduction as C4 applies to its insides. 004 prescribed a tier
taxonomy (`shared/` / `dormant/` / `archived/`) — load-attention metadata
encoded in paths. Knowledge moves between tiers, so that is mutable state
needing maintenance, and nothing mechanical ever enforced it (no machinery
"doesn't load" `dormant/`; it was instruction text). 005 stops prescribing.
The contract shrinks to three clauses:

1. **Location:** `.tsugu/knowledge/` on the coordination ref.
2. **The promotion gate:** only deliberately promoted, durable knowledge
   enters — promotion stays an explicit act, never a default.
3. **Internal organization belongs to the agents.** They organize, reorganize,
   and prune as they judge (each a `.tsugu/`-only commit); smarter future
   models inherit the freedom, not a frozen taxonomy. References describe the
   gate and the location, never a layout.

### C4 — All live state is derived from the DAG

There is no written branch state. The partition classifies every work branch
(those under the configured work prefixes) by **containment** — one git
mechanism, three states:

| DAG fact (about the work branch's tip) | State | Disposition |
| --- | --- | --- |
| contained in `<remote>/<default>` | **settled** — the work landed | skip; completion-tail / cleanup candidate |
| contained in any **non-work** ref (a handoff branch — `feat/*`, `fix/*`, …) | **decided, awaiting merge** | skip (a human decision is pending at the forge) |
| contained nowhere else | **in progress** | candidate: read `context.md`, judge from the narrative |

Checks are `git merge-base --is-ancestor` / `git for-each-ref --contains`
against remote-tracking refs (exact mechanics → `references/git-recipes.md`).
Notes:

- **The pending state exists if and only if its artifact exists.** "Decided,
  awaiting merge" is not a recorded claim about the world — it *is* the
  handoff branch, which had to exist anyway to open the PR. No
  state-vs-artifact desync is possible. If the human rejects the PR and
  deletes the handoff branch, the work branch's tip is no longer contained
  anywhere and the work **resurfaces as in-progress** — correct, since the
  decision was reversed.
- **New commits after the decision** make the tip uncontained again, so the
  branch resurfaces as in-progress. Also correct: work added after a decision
  is new, undecided work. The decided content itself stays frozen on the
  handoff branch; the open PR is unaffected.
- **Branches only ever created to serve the human workflow.** The handoff
  branch (`feat/*` / `fix/*` per repo convention, a `## Handoff Prefixes`
  policy field) and `exclude` mode's public branch are the only non-work
  branches Tsugu cuts — they exist for the human's PR conventions, not for
  Tsugu bookkeeping. Work branches are never renamed.
- **Claims are derived from commits.** The 004 `claimed-by:`/`claimed-at:`
  fields are gone. Beginning active work means rewriting `context.md` (C2) —
  that commit's author and timestamp *are* the claim. The courtesy-yield rule
  reads the DAG: a work branch with recent commits by another agent is taken;
  one whose last commit is stale is free to pick up. (Same courtesy-only
  semantics as 004 — no lock, v2 formalizes the staleness window.)
- **Zero-commit claimed-linked exemption.** A branch freshly cut from default
  has a tip contained in default and would read "settled". The existing
  exemption covers it: a branch joined to a `claimed` intake note (slug ↔
  branch name) is never classified by containment alone — it is interrupted
  work to resume, or a reconciliation case.
- **Intake-note closing requires confirmed landing.** Flip `claimed → done`
  only when containment confirms the landing (the work branch's tip in
  `include` mode; the public branch's tip in `exclude` mode), recording the
  landed tip SHA in the note, and **before branch cleanup only** (C1) — the
  branch is the evidence; it outlives the flip, never the reverse. A
  `prepare`/`converge` tidy pass re-enters the whole idempotent tail for
  sessions that ended mid-completion. **Absence is never proof of success:** a
  `claimed` note whose linked branch is gone *without* a recorded landed SHA
  or confirmable containment is a **reconciliation case** — surface it to the
  human at the next `converge`; never auto-flip it to `done` or `dropped`.

### C5 — Push by default

The `init` question "may agents create/commit/push preparation branches
automatically?" gains a **yes** default (004 asked it neutrally, with no
default). Pushing is what makes the branch a message: the MacBook `converge`
and the next scheduled agent both read remote-tracking refs. A repo can still
answer no; `prepare` then commits locally and stops for approval, as the
shipped v1.0 SKILL.md prepare step already specifies.

### C6 — `public-branch-tsugu: include | exclude`

New `policy.md` field, default **`include`**:

- **`include` (default):** the work branch **is** what merges — directly (solo
  flow) or via a handoff branch that shares its tip (C1). Merging lands the
  branch's `.tsugu/` evidence (`runs/`, `packets/`, the rewritten
  `context.md`) on the default branch as durable shared memory. No by-path
  filtering, no separate evidence-landing step. Trade-offs, stated openly:
  mainline history carries the agent's (possibly messy) preparation commits
  and `.tsugu/` files; in the agent-first orientation that history *is* the
  memory, and the repo's merge convention (merge commits, no squash)
  preserves it.
- **`exclude` (opt-out):** 004's behavior — cut a fresh public branch from
  the fetched `<remote>/<default>`, apply accepted changes **by path** so the
  public diff introduces no `.tsugu/` changes. For collaborative repos where
  human reviewers should not see coordination metadata in PRs. Landing
  confirmation via the public branch's containment (C1/C4).

Unchanged in both modes: verification before the human gate, PR
opening/merging stays human-gated, promotion into `.tsugu/knowledge/`, cleanup
order (`git worktree remove` before branch delete).

### Ripple

- `templates/`: `branch.md` → `context.md` (pure narrative — no status/claim
  fields; work-branch form, `init` writes the default-branch form);
  `policy.md` gains `public-branch-tsugu`, `## Handoff Prefixes`, + the new
  defaults wording; `packet.md`'s "Suggested public branch" comment (written
  for the always-cut-fresh model) reworded for both modes.
- SKILL.md: frontmatter description (trigger surface: three routines, no
  "clean public form" framing) and the spine's legibility bullet
  (`branch.md` → `context.md`); init (schema stamp, migration decision, push
  question default, intake question); prepare (containment partition, derived
  claims, intake backstop, push default); converge (absorbs settle — see C1);
  settle section removed; boundary + multi-agent sections (derived claims,
  `context.md`).
- `references/git-recipes.md`: containment checks (`--is-ancestor`,
  `for-each-ref --contains`, `fetch --prune`), handoff-branch cut, include-mode
  merge-back, freshness rebase, `knowledge/` paths; the by-path clean-cut
  recipe becomes the `exclude` arm of converge.
- `references/notes-and-packet.md`: `context.md` per-ref pure-narrative
  semantics (inherit → rewrite, merge-back rewrite, own-files links,
  no-lineage rule); accumulated `runs/`/`packets/` load semantics; both-mode
  placement/durability; `knowledge/` described as gate + location, no layout;
  packet wording.
- `references/policy-and-intake.md`: new fields (incl. Handoff Prefixes);
  intake recorded form, dedup + re-open scope, push-protected persistence,
  reconciliation rule.

## D — `init` re-run migrates (`tsugu-schema`)

004's idempotency rule ("repair missing skeleton paths, never overwrite a
curated `policy.md`") cannot express renames or semantic changes. 005 adds
deterministic, version-stamped migration.

### Version stamp

`policy.md` gains a `tsugu-schema: N` field (integer). Schema history:

- **Schema 1** — the 004 layout. Any `.tsugu/` without a `tsugu-schema` field
  is schema 1 by definition.
- **Schema 2** — this spec: `tsugu-schema` itself, `public-branch-tsugu`,
  `## Handoff Prefixes`, the structured `## Intake Sources` format,
  `context.md` (pure-narrative file + default-branch form), and the
  `knowledge/` rename (internal structure unprescribed).

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
2. Add `## Handoff Prefixes` to `policy.md` (default `feat/* fix/*`; ask once
   if the repo's convention is visible to confirm).
3. Re-wrap any existing `## Intake Sources` content into the structured entry
   format (B), preserving listed sources. This re-wrap is **not** fully
   mechanical: a legacy free-prose entry (e.g. "gh issues") has no derivable
   `read:` instruction — such entries take the ask-once path (or are carried
   over with an explicit `read: TODO (ask the human)` marker when no human is
   available).
4. Rename `.tsugu/context/` → `.tsugu/knowledge/` on the coordination ref
   (`git mv`, contents preserved — existing tier subdirectories ride along as
   plain folders, since no internal layout is prescribed anymore; deferred
   until the policy PR merges when the default branch is push-protected).
5. Update `.tsugu/templates/` from the plugin (`branch.md` template replaced
   by the pure-narrative `context.md`).
6. Write the default branch's `.tsugu/context.md` (mainline form) if absent.
7. Add `tsugu-schema: 2` — **last**, after steps 1–6 succeed.

Live work branches are **not** migrated centrally: agents read legacy
`branch.md` per the C2 compatibility rules (legacy `status:` folded into
narrative on next touch; legacy `settled` → cleanup candidate; legacy
`converged` → surfaced at the next `converge`), and each branch converts on
its next touch.

## Affected surface

| File | Change |
| --- | --- |
| `commands/tsugu.md` | **removed** |
| `commands/{init,prepare,converge}.md` | **new** thin routers |
| `skills/tsugu/SKILL.md` | frontmatter description; spine legibility bullet; routing; init (schema stamp, migration decision, push question default, intake question); prepare (containment partition, derived claims, intake backstop, push default); converge (absorbs settle — see C1); settle section removed; boundary + multi-agent sections (derived claims, `context.md`) |
| `skills/tsugu/templates/policy.md` | `tsugu-schema`, `public-branch-tsugu`, `## Handoff Prefixes`, new Intake Sources format, push default wording |
| `skills/tsugu/templates/branch.md` → `templates/context.md` | renamed; pure narrative (no status/claim fields); work-branch and mainline forms |
| `skills/tsugu/templates/packet.md` | "Suggested public branch" comment reworded for both modes |
| `skills/tsugu/references/policy-and-intake.md` | new fields (incl. Handoff Prefixes); intake recorded form, dedup + re-open scope, push-protected persistence, reconciliation rule |
| `skills/tsugu/references/git-recipes.md` | containment checks; handoff-branch cut; include-mode merge-back; freshness rebase; `knowledge/` paths; clean-cut as `exclude` arm |
| `skills/tsugu/references/notes-and-packet.md` | `context.md` pure-narrative per-ref semantics + own-files links + no-lineage rule; accumulated `runs/`/`packets/` load semantics; both-mode placement/durability; `knowledge/` as gate + location, no prescribed layout; packet wording |
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
   (rebase, verify, `context.md` rewrite, direct merge or handoff branch + PR,
   promotion, intake close, cleanup) with no separate settle step.
6. With `public-branch-tsugu: include`, merging lands the work's `.tsugu/`
   evidence on the default branch and leaves the default branch's `context.md`
   rewritten to the post-merge reality, with **no state line to clean up
   anywhere**; with `exclude`, the public diff introduces no `.tsugu/` changes
   (004 behavior) and landing is confirmed via the public branch's
   containment.
7. **No written branch state exists** — no `status:`, no `claimed-*`, no
   recorded lineage. The partition derives settled / awaiting-merge /
   in-progress from containment alone; claims derive from commit authorship
   and recency; a branch freshly cut from default is classified via the
   claimed-intake exemption, not a file. Work branches are never renamed; the
   only branches Tsugu creates beyond work branches are human-workflow
   handoff/public branches. Legacy `status:` files are still read (folded
   into narrative on next touch).
8. An intake note flips to `done` only on containment-confirmed landing,
   after promotion and before branch cleanup, recording the landed tip SHA
   (an interrupted tail re-enters via tidy); a `claimed` note whose branch
   vanished without evidence is surfaced for human reconciliation, never
   auto-closed.
9. Re-running `/tsugu:init` on a schema-1 repo migrates it to schema 2 without
   losing any curated `policy.md` content; an interrupted migration re-enters
   safely (stamp written last); re-running after completion is a no-op.

## Deferred (unchanged from 004)

Multi-agent arbitration, tracker adapters, external notification, automatic
periodic sync of long-lived branches. Re-opened intake items (B) are also
deferred. A formalized claim-staleness window (the derived-claim recency
judgment) remains v2, as in 004.
