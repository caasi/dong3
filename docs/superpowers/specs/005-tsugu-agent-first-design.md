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
| C | Agent-first lifecycle: **`converge` absorbs `settle`** (three routines); **all live branch state is derived from refs and the DAG** — the `branch.md` status enum and the `claimed-by`/`claimed-at` fields are removed entirely; `branch.md` → per-ref `context.md` (pure narrative); `.tsugu/context/` → `.tsugu/knowledge/`; push by default; public/default branches MAY carry `.tsugu/` (`public-branch-tsugu: include\|exclude`, default `include`) | The four-routine lifecycle (the `settle` routine and its ⚙/🔒 step list fold into `converge`); design principle #5; success criteria #7 and #11; the settle "no `.tsugu/` in the diff" guarantee; `init`'s neutral auto-push question; the `branch.md` name, its entire `status:` lifecycle (`open\|paused\|converged\|settled`), and the `claimed-by`/`claimed-at` courtesy fields (claims are now derived from commits); the `public/*` prefix (the settle-output namespace — replaced by human-workflow handoff prefixes); the `.tsugu/` placement table's "ephemeral, work-branch-only" entries (those become the `exclude`-mode description); the `context/` directory name **and its prescribed `shared/dormant/archived` tier taxonomy** (the knowledge dir's internal structure is now the agents' own); the packet's "Suggested public branch … not 'push this branch as-is'" semantics (in `include` mode it is exactly "merge this branch"); the two-layer-lifecycle rule that *settle* flips intake notes (the flip moves to landing confirmation, with `prepare`/`converge` tidy as a backstop) |
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
   on this", and "this branch grew out of that one" are all facts refs and the
   DAG already record (names, ancestry, containment, commit authorship and
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
  > external source — a task manager, issue tracker, notes file, RSS feed, or
  > a watch/scan (YARA/CVE, CI)? If so, give me the read instruction — a shell
  > command, file path, or MCP tool name.

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
the queue read, partition, and routines operate only on git. Sources are not
limited to task systems: anything one read instruction can poll fits the same
shape — an RSS feed (`curl --silent <url>`), a security watch (a YARA scan whose new
matches become intake notes), a CVE feed, a CI status query.

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

> **Refs and the DAG carry every fact the partition reads; text carries
> narrative for minds and write-once records.** Live coordination state — in
> progress / decided / landed / who's on it / what grew out of what — is
> derived from ref names, ancestry, containment, and commit authorship and
> recency, never written into files. Files hold two things only: **narrative**
> (maintained freely; it informs judgment, never classification) and
> **write-once records** (run notes, packets, intake terminal fields). A fact
> is recorded **only when an operation severs the DAG's ability to answer it,
> at the moment it stops being derivable** — never before, never mutated
> after.

Concretely: the lifecycle loses its fourth routine (C1), the per-branch note
becomes a pure-narrative per-ref context file (C2), and the entire written
state machine — `status:`, `claimed-by:`, `claimed-at:` — is replaced by
ref-and-DAG facts (C4).

**The slug is the join key.** Every piece of one work item shares one slug:
the work branch (`prepare/<slug>`), the intake note (`intake/<slug>.md`), the
packet, the run notes, and — when one exists — the handoff branch
(`<handoff-prefix>/<slug>`). Names are write-once identity (Tsugu never
renames a branch), so name-level joins survive everything that rewrites
commits. One slug = one work item: same-slug branches under *different work
prefixes* (e.g. a `review/<slug>` artifact from a built-in review subagent)
are that item's artifacts — they share its lifecycle and are swept by its
completion tail. Work prefixes and handoff prefixes must be **disjoint**
sets; `init` and migration validate this.

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
2. **Ask which branch.** List the candidate work branches (those the C4
   partition classifies as in progress), each with a one-line `context.md`
   summary and packet hint, and ask the human which to converge. An explicit
   branch argument (`/tsugu:converge <branch>`) skips the question. Alongside
   the candidates, show a separate **awaiting-merge section** — decided
   branches are not candidates, but listing them is what surfaces an orphaned
   handoff (pushed, then the session died before its PR was opened); when
   `gh` is available, verify each awaiting-merge item has an open PR and flag
   the ones that don't. In `include` mode, also flag divergence — a work tip
   with commits its handoff branch lacks (C4) — and pairs whose handoff tip
   shares no history with the work branch (possible name collision, C4);
   neither history heuristic applies in `exclude` mode (C4). Third, a
   **housekeeping section**: in-progress branches (and open intake notes)
   whose last activity is older than the policy's staleness threshold
   (default 30 days; recorded progressively in `policy.md` on first use).
   Staleness is derived — the last commit's timestamp, the same recency
   mechanism as claims (C4) — and cleanup is **human-decided per item**, like
   tidying a room: resume it, park it with an updated narrative, drop it
   (record the reason; linked intake note → `dropped`; delete via the usual
   order), or keep it. A scheduled `prepare` never cleans on its own —
   housekeeping questions belong to the human-present moment.
3. Lay out the packet, prepared branches/worktrees, what was tried / worked /
   failed / evidence / remaining uncertainties; surface open questions
   (including unconfigured intake sources and any reconciliation cases — C4).
4. Decide *with* the human, then **complete the disposition in-session**:
   - **Accepted (`include` mode):** freshness-rebase onto the fetched default →
     verify (build/tests) → rewrite `context.md` to the ready-to-merge
     mainline narrative (C2) → push → hand off:
     - if the human can merge right now (solo flow), they merge the work
       branch directly — its tip is contained in default, settlement is
       immediate (C4);
     - otherwise, **cut a handoff branch named for the human workflow**:
       `git branch <handoff-prefix>/<slug> <work-branch>` — same commits, a
       second name, **same slug** (prefixes like `feat/*`/`fix/*` per repo
       convention, configured in `policy.md` `## Handoff Prefixes`) — and open
       the PR **on the handoff branch**, human-approved. The partition pairs
       work branch and handoff branch **by slug** (C4), so the pending state
       survives anything the forge does to commits.

     Once landing is confirmed — by containment in merge-commit repos, or by
     the human's in-session confirmation where a squash was forced (C4's
     landing rules) — run the **completion tail**, in this order: promote
     reusable knowledge into `.tsugu/knowledge/`; flip the intake note
     `claimed → done` (recording `landed: <sha>` when the landing is not
     containment-derivable); and **only then** clean up worktrees and branches
     (worktree remove before branch delete, as always — the handoff branch
     too, if the forge didn't already delete it). Branch deletion comes after
     the flip because the branch is landing evidence — a lingering merged
     branch is harmless (containment-filtered; prune any time), while
     deleting it before the flip would turn an interruption into a false
     reconciliation case. The tail is idempotent: interrupted before the
     flip, the note stays `claimed` with its branch intact and a later tidy
     pass re-enters the whole tail; interrupted after, only harmless cleanup
     remains.
   - **Accepted (`exclude` mode):** cut a clean public branch from the fetched
     default — named per the same handoff convention, **same slug**, so the
     pending state derives from the same name pairing — apply accepted
     code/test/doc/config **by path** (no `.tsugu/` in the public diff),
     verify, human-approved PR. Landing is confirmed via the **public
     branch's** containment in default (or the human's confirmation where a
     squash was forced); then the same completion tail runs.
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

Steps 1–3 are **read-only**, so running `/tsugu:converge` just to look is a
first-class use: it doubles as the morning status view — how many prepared
branches are workable today, what awaits merge, what needs reconciliation.
Choosing nothing and leaving is a valid outcome; side effects begin only at
step 4's disposition.

Tsugu still invokes no user-installed skill here: it presents and yields; the
human triggers workflow skills by keyword. The packet may hint which skill
fits, but must not fire it.

### C2 — `context.md`: every ref describes itself, in pure narrative

`branch.md` is renamed **`context.md`**, its scope widens, and **all state
fields are removed** — it is narrative plus write-once links, nothing else.

- **On a work branch:** why this branch exists, current understanding, open
  questions, next actions, verification, promotion candidates — plus links to
  **its own** packet and run notes (all keyed by the branch's slug). Evidence
  should prefer **runnable artifacts** — a committed repro script, a failing
  test, a probe — over prose claims (extending 004's principle #12): the next
  inheritor re-runs instead of re-trusting; narrative explains, running code
  demonstrates. No
  `status:`, no `claimed-*`: those facts are derived (C4). **Lineage is not
  recorded either** — lineage *to the mainline* is an ancestry question the
  DAG answers while history is preserved, and the operation that severs it (a
  squash merge) gets the landed-SHA record instead (C4). Cross-work-branch
  lineage is scratch-grade: a freshness rebase may sever it, and that is
  acceptable — lineage never drives classification. A recorded copy in any of
  these cases only goes stale.
- **On the default branch:** the mainline's current situation — what this repo
  is, where the mainline stands, what recently landed. `init` writes the first
  version.
- **Inherit → rewrite cycle:** a new work branch cut from default inherits the
  mainline `context.md`; the agent's first act of real work rewrites it into
  the branch's own narrative. There is always a `context.md`. A branch with
  real commits whose `context.md` is still the inherited mainline form (a
  session that died before the rewrite) is simply a candidate whose narrative
  hasn't been written yet — claim status comes from commit recency as usual
  (C4); the partition needs no special rule for the file's form.
- **Rewrite on merge-back (`include` mode):** before the work branch merges,
  `converge` rewrites `context.md` into the **ready-to-merge mainline
  narrative**: read the default branch's current `context.md` from the
  fetched ref, integrate what this work changes. The file that lands on
  default is **pure desired content** — there is no state line to clean up
  afterwards, because "awaiting merge" lives in the ref namespace (slug
  pairing, C4), not in the file. If the PR is instead rejected, the narrative
  is rewritten again at the next decision — narrative is maintained freely;
  only *records* are write-once (Orientation). Work-specific history stays in
  the keyed `runs/` and `packets/` files. Concurrent merges may conflict on
  `context.md`; that conflict is meaningful (two narratives to integrate) and
  is resolved by rewriting against the then-current default version during
  the freshness rebase.
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
  pending decision to be re-anchored (handoff branch or direct merge). These
  compatibility reads apply to **any pre-migration repo** a 005 agent
  touches, not only mid-migration: missing policy fields take their defaults
  (`## Handoff Prefixes` → `feat/* fix/*` plus legacy `public/*`), and both
  `context/` and `knowledge/` directory names are accepted. Only templates
  and references change centrally (see D).

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

### C4 — All live state is derived from refs and the DAG

There is no written branch state. The partition classifies every work branch
`<work-prefix>/<slug>` by **two ref-level facts**, checked in order:

| Fact | State | Disposition |
| --- | --- | --- |
| tip contained in `<remote>/<default>` (in `exclude` mode: the slug-paired public branch's tip, since by-path application breaks the work branch's own containment) — or its intake note records `landed:` | **settled** — the work landed | skip; completion-tail / cleanup candidate |
| a branch with the **same slug** exists under a configured `## Handoff Prefixes` | **decided, awaiting merge** | skip as a candidate; shown in `converge`'s awaiting-merge section |
| neither | **in progress** | candidate: read `context.md`, judge from the narrative |

Containment checks are `git merge-base --is-ancestor` /
`git for-each-ref --contains` against remote-tracking refs (exact mechanics →
`references/git-recipes.md`). Notes:

- **Pending pairs by name, not by commits.** The handoff branch shares the
  work branch's slug, and ref names are write-once identity — so the pending
  state survives everything a forge does to commits (rebase-updates of the PR
  branch, squashes, force-pushes). The handoff branch had to exist anyway to
  open the PR, so for genuine handoffs state and artifact cannot desync.
  Containment in refs **outside** the configured handoff prefixes (someone's
  integration branch that absorbed a work branch, a tag) carries **no**
  derived meaning. One acknowledged imprecision: a human coincidentally
  starting `<handoff-prefix>/<same-slug>` false-pairs — the failure direction
  is safe (the agent yields; the item stays visible in the awaiting-merge
  section), and in `include` mode `converge` marks pairs whose handoff tip
  shares no history with the work branch as possible name collisions to
  confirm (in `exclude` mode shared history is absent by design, so collisions
  there are caught only by the human seeing the awaiting-merge list — same
  safe failure direction).
- **Merge method: Tsugu recommends merge commits — do not squash-merge
  tsugu-managed branches.** Preserved history is what makes settlement,
  lineage, and evidence derivable; this recommendation is recorded in
  `policy.md` and the README. When a human system nonetheless forces a
  squash/rebase-merge, the landing is **not derivable** — the squash commit's
  parents contain none of the work commits; the lineage is severed, not
  obscured. Exactly there, and only there, the fact is recorded: the human
  confirms the landing at `converge` (they are usually the one who just
  merged) and the intake note's `done` flip records `landed: <sha>` — the
  thread back to the specific mainline commit. The SHA is **validated before
  writing**: it must resolve and be contained in the fetched default ref.
  Settled detection accepts either signal (table row 1); on read, a `landed:`
  whose SHA does not resolve or is not contained in default is treated as
  invalid — a reconciliation case, never silent settlement.
- **If the human closes the PR and deletes the handoff branch**, the slug
  pairing dissolves and the work resurfaces. Out-of-band PR closure usually
  means *rejection*, not reversal — so a resurfaced branch (one whose
  narrative reads ready-to-merge) is **surfaced at the next `converge` for
  re-decision, never auto-resumed by a scheduled `prepare`**.
- **New commits on the work branch after the decision** leave it pending (the
  slug pairing still holds) — but they are **not** in the PR, which tracks the
  handoff branch. In **`include` mode**, `converge`'s awaiting-merge section
  flags the divergence (a work tip with commits the handoff branch lacks):
  fold them into the handoff branch (update it by **merge**, never rebase) or
  re-decide. In **`exclude` mode** the public branch shares no commits with
  the work branch *by design*, so this history-based flag (and the
  shared-history collision heuristic below) does not apply — post-decision
  changes are re-applied **by path** at the next `converge`, preserving the
  no-`.tsugu/`-in-public-diff guarantee.
- **Claims are derived from commits.** The 004 `claimed-by:`/`claimed-at:`
  fields are gone. Beginning active work means rewriting `context.md` (C2) —
  that commit's author and timestamp *are* the claim. The courtesy-yield rule
  reads the DAG: a work branch with recent commits is taken; one whose last
  commit is stale is free to pick up. When agents share one git identity (one
  human, two machines — the primary scenario), authorship cannot distinguish
  them and the rule degrades to pure recency, which is acceptable for a
  courtesy yield (no lock — as in 004; v2 formalizes the staleness window).
  For a zero-commit claimed branch, recency comes from the coordination-ref
  commit that flipped its intake note to `claimed`.
- **Zero-commit branches are never classified by the table at all** — not by
  containment, not by a stale same-slug record. A branch whose tip still
  equals the default tip has no work to misread: with a `claimed` intake note
  (slug join) it is interrupted work to resume; without one it is a
  **request-by-branch** (a first-class 004 intake form — a human pushes
  `prepare/look-into-X` as the ask) — a new, unclaimed candidate. Neither is
  ever a cleanup target. **Slugs are never reused for new work** (any intake
  form, generalizing B's dedup rule); a fresh ask whose slug collides with a
  `done`/`dropped` note or a lingering handoff branch is surfaced at
  `converge` as a naming conflict, not classified.
- **Intake-note closing requires confirmed landing.** Flip `claimed → done`
  only on a confirmed landing — containment, or the `converge` confirmation
  that records `landed: <sha>` — and **before branch cleanup only** (C1): the
  branch is landing evidence; it outlives the flip, never the reverse. A
  `prepare`/`converge` tidy pass re-enters the whole idempotent tail for
  sessions that ended mid-completion. **Absence is never proof of success:** a
  `claimed` note whose linked branch is gone *without* a recorded `landed:`
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
  flow) or via a handoff branch that shares its tip and slug (C1). Merging
  lands the branch's `.tsugu/` evidence (`runs/`, `packets/`, the rewritten
  `context.md`) on the default branch as durable shared memory. No by-path
  filtering, no separate evidence-landing step. Trade-offs, stated openly:
  mainline history carries the agent's (possibly messy) preparation commits
  and `.tsugu/` files; in the agent-first orientation that history *is* the
  memory, and the recommended merge method (merge commits — C4) preserves it.
- **`exclude` (opt-out):** 004's behavior — cut a fresh public branch from
  the fetched `<remote>/<default>` (handoff-named, same slug), apply accepted
  changes **by path** so the public diff introduces no `.tsugu/` changes. For
  collaborative repos where human reviewers should not see coordination
  metadata in PRs. Pending derives from the same slug pairing; landing
  confirmation via the public branch's containment (C1/C4).

Unchanged in both modes: verification before the human gate, PR
opening/merging stays human-gated, promotion into `.tsugu/knowledge/`, cleanup
order (`git worktree remove` before branch delete).

### Ripple

- `templates/`: `branch.md` → `context.md` (pure narrative — no status/claim
  fields; work-branch form, `init` writes the default-branch form);
  `policy.md` gains `public-branch-tsugu`, `## Handoff Prefixes`, the
  merge-commit recommendation, + the new defaults wording (`## Branch
  Prefixes` default becomes `prepare/* investigate/* review/*` — `public/*`
  retires into the handoff convention); `intake.md` gains the `landed:` field
  (write-once, recorded only when landing is not containment-derivable) and
  keeps `linked-branch:` as a write-once breadcrumb; `run.md`'s filename
  convention becomes `runs/<slug>-<date-time>.md` (slug-keyed, so accumulated
  runs on default stay attributable); `packet.md`'s "Suggested public branch"
  comment (written for the always-cut-fresh model) reworded for both modes.
- SKILL.md: frontmatter description (trigger surface: three routines, no
  "clean public form" framing) and the spine's legibility bullet
  (`branch.md` → `context.md`); init (schema stamp, migration decision, push
  question default, intake question); prepare (slug/containment partition,
  derived claims, intake backstop, push default); converge (absorbs settle —
  see C1); settle section removed; boundary + multi-agent sections (derived
  claims, `context.md`).
- `references/git-recipes.md`: containment checks (`--is-ancestor`,
  `for-each-ref --contains`, `fetch --prune`), slug-pairing enumeration,
  handoff-branch cut, include-mode merge-back, freshness rebase, `knowledge/`
  paths; the by-path clean-cut recipe becomes the `exclude` arm of converge.
- `references/notes-and-packet.md`: `context.md` per-ref pure-narrative
  semantics (inherit → rewrite, merge-back rewrite, own-files links,
  no-lineage rule); accumulated `runs/`/`packets/` load semantics; both-mode
  placement/durability; `knowledge/` described as gate + location, no layout;
  packet wording.
- `references/policy-and-intake.md`: new fields (incl. Handoff Prefixes, the
  merge-method recommendation); intake recorded form, dedup + re-open scope,
  push-protected persistence, `landed:` semantics, reconciliation rule.

## D — `init` re-run migrates (`tsugu-schema`)

004's idempotency rule ("repair missing skeleton paths, never overwrite a
curated `policy.md`") cannot express renames or semantic changes. 005 adds
deterministic, version-stamped migration.

### Version stamp

`policy.md` gains a `tsugu-schema: N` field (integer). Schema history:

- **Schema 1** — the 004 layout. Any `.tsugu/` without a `tsugu-schema` field
  is schema 1 by definition.
- **Schema 2** — this spec: `tsugu-schema` itself, `public-branch-tsugu`,
  `## Handoff Prefixes` (+ the retired `public/*`), the structured
  `## Intake Sources` format, `context.md` (pure-narrative file +
  default-branch form), the `landed:` intake field, and the `knowledge/`
  rename (internal structure unprescribed).

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
   if the repo's convention is visible to confirm) and narrow `## Branch
   Prefixes` to work-only by **preserving the repo's configured work prefixes**
   (the `prepare/* investigate/* review/*` set is the default only when never
   customized) and removing only `public/*` from them — **legacy `public/*` is
   appended to the Handoff Prefixes list**, so existing `public/*` branches keep
   their meaning (pending/landed outputs, never work candidates).
3. Add the merge-commit recommendation line to `policy.md`.
4. Re-wrap any existing `## Intake Sources` content into the structured entry
   format (B), preserving listed sources. This re-wrap is **not** fully
   mechanical: a legacy free-prose entry (e.g. "gh issues") has no derivable
   `read:` instruction — such entries take the ask-once path (or are carried
   over with an explicit `read: TODO (ask the human)` marker when no human is
   available).
5. Rename `.tsugu/context/` → `.tsugu/knowledge/` on the coordination ref
   (`git mv`, contents preserved — existing tier subdirectories ride along as
   plain folders, since no internal layout is prescribed anymore; deferred
   until the policy PR merges when the default branch is push-protected).
6. Update `.tsugu/templates/` from the plugin (`branch.md` template replaced
   by the pure-narrative `context.md`; `intake.md` gains `landed:`).
7. Write the default branch's `.tsugu/context.md` (mainline form) if absent.
8. Add `tsugu-schema: 2` — **last**, after steps 1–7 succeed.

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
| `skills/tsugu/SKILL.md` | frontmatter description; spine legibility bullet; routing; init (schema stamp, migration decision, push question default, intake question); prepare (slug/containment partition, derived claims, intake backstop, push default); converge (absorbs settle — see C1); settle section removed; boundary + multi-agent sections (derived claims, `context.md`) |
| `skills/tsugu/templates/policy.md` | `tsugu-schema`, `public-branch-tsugu`, `## Handoff Prefixes`, merge-commit recommendation, work-only `## Branch Prefixes`, new Intake Sources format, push default wording, staleness threshold (commented default 30d) |
| `skills/tsugu/templates/branch.md` → `templates/context.md` | renamed; pure narrative (no status/claim fields); work-branch and mainline forms |
| `skills/tsugu/templates/intake.md` | `landed:` field (write-once, squash-forced landings only); `linked-branch:` kept as write-once breadcrumb |
| `skills/tsugu/templates/packet.md` | "Suggested public branch" comment reworded for both modes |
| `skills/tsugu/templates/run.md` | filename convention `runs/<slug>-<date-time>.md` (slug-keyed) |
| `skills/tsugu/references/policy-and-intake.md` | new fields (incl. Handoff Prefixes, merge-method recommendation); intake recorded form, dedup + re-open scope, push-protected persistence, `landed:` semantics, reconciliation rule |
| `skills/tsugu/references/git-recipes.md` | containment checks; slug-pairing enumeration; handoff-branch cut; include-mode merge-back; freshness rebase; `knowledge/` paths; clean-cut as `exclude` arm |
| `skills/tsugu/references/notes-and-packet.md` | `context.md` pure-narrative per-ref semantics + own-files links + no-lineage rule; accumulated `runs/`/`packets/` load semantics; both-mode placement/durability; `knowledge/` as gate + location, no prescribed layout; packet wording |
| `skills/tsugu/references/migrations.md` | **new** — migration rules + steps, starting with 1→2 |
| `skills/tsugu/README.md` | command surface; lifecycle (three routines); `.tsugu/` diagram (`knowledge/`, `context.md`); former settle content folded into converge, clean-cut described as the `exclude` arm; merge-commit recommendation; add 005 spec link |
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
5. `converge` lists in-progress candidates and asks which to work on (an
   explicit branch argument skips the question), shows decided branches in a
   separate awaiting-merge section (flagging PR-less orphans), surfaces stale
   branches/notes past the policy threshold as human-decided housekeeping
   (never cleaned by a scheduled `prepare`), and completes Accepted work
   in-session (rebase, verify, `context.md` rewrite, direct merge or
   slug-paired handoff branch + PR, promotion, intake close, cleanup) with no
   separate settle step.
6. With `public-branch-tsugu: include`, merging lands the work's `.tsugu/`
   evidence on the default branch and leaves the default branch's `context.md`
   rewritten to the post-merge reality, with **no state line to clean up
   anywhere**; with `exclude`, the public diff introduces no `.tsugu/` changes
   (004 behavior). In merge-commit repos (the recommended method) settlement
   derives from containment alone; where a squash was forced, the `converge`
   confirmation records `landed: <sha>` and settlement derives from that
   record.
7. **No written branch state exists** — no `status:`, no `claimed-*`, no
   recorded lineage. The partition derives settled / awaiting-merge /
   in-progress from containment + slug pairing + the `landed:` record; claims
   derive from commit recency; zero-commit branches are new candidates (or
   interrupted claimed work), never cleanup targets. Work branches are never
   renamed; the only branches Tsugu creates beyond work branches are
   slug-paired human-workflow handoff/public branches and `init/*` policy
   branches (B/D). Legacy `status:` files are still read (folded into
   narrative on next touch).
8. An intake note flips to `done` only on confirmed landing (containment, or
   converge-confirmed with `landed: <sha>`), after promotion and before
   branch cleanup (an interrupted tail re-enters via tidy); a `claimed` note
   whose branch vanished without evidence is surfaced for human
   reconciliation, never auto-closed; a branch whose handoff pairing
   dissolved (out-of-band PR closure) is re-decided at `converge`, never
   auto-resumed.
9. Re-running `/tsugu:init` on a schema-1 repo migrates it to schema 2 without
   losing any curated `policy.md` content; an interrupted migration re-enters
   safely (stamp written last); re-running after completion is a no-op.

## Deferred (unchanged from 004)

Multi-agent arbitration, tracker adapters, external notification, automatic
periodic sync of long-lived branches. Re-opened intake items (B) are also
deferred. A formalized claim-staleness window (the derived-claim recency
judgment) remains v2, as in 004.
