# policy-and-intake

`.tsugu/policy.md` records the per-repo rules a cold-start agent reads before any
unattended preparation. It lives on the **default branch always** (so the
coordination ref it points to stays discoverable — no circularity). This document
gives the one-line semantics of every field, then explains the intake
human-bridge.

## `policy.md` fields

### `tsugu-schema:`

The schema-version stamp (current: `2`). It is the first line of the file, and a
migration **writes it last** — only after every N→N+1 rename and semantic change
has been applied does `init` stamp the new number, so a half-applied migration is
never mistaken for a completed one. Readers use it to decide whether a re-run of
`init` must migrate (older stamp → apply `references/migrations.md` in order) or
is a plain idempotent repair (stamp already current).

### Private / Public boundary

The whole point of the file: where the agent may act freely vs where it must ask.

- **`## Private Git Space (agent may do freely)`** — actions the agent performs
  without approval: create/commit (push per `## Push`'s `push-prepare-branches:`)
  `prepare/*` / `investigate/*` / `review/*` branches, worktrees, write `.tsugu/*`,
  run tests, try reversible patches, dispatch its own built-in review subagents.
  All of this is git-local and reversible.
- **`## Public Coordination (ask first)`** — actions requiring human approval:
  open MR/PR, tracker comment / status change, assign reviewers, Slack, public
  commitments, moving findings into human-facing docs, irreversible cleanup.

The boundary in one line:

```text
Git branch / pushed branch / .tsugu notes  →  agent may do freely
MR / PR / tracker / Slack / reviewer assignment  →  human approval required
```

### `## Branch Prefixes`

The **work** namespaces the queue is built from. Default `prepare/*
investigate/* review/*` — these are queue items: branches the partition reads and
classifies. They must be **DISJOINT from `## Handoff Prefixes`** — `init` and
migration validate this — because the partition pairs a work branch against a
handoff branch by **shared slug**, and an overlapping prefix would make a branch
both a queue item and its own handoff. `public/*` is **no longer** a work prefix;
it retires into the handoff convention (see below).

### `## Handoff Prefixes`

The **human-workflow** namespaces a converge cut hands work into for a PR.
Default `feat/* fix/*` (a migration also folds legacy `public/*` here). A handoff
branch is **not** a queue item; it exists so the partition can read one
ref-level fact: a handoff branch whose **slug pairs** a work branch's slug means
**that work is decided, awaiting merge** — skip it as a candidate, surface it in
converge's awaiting-merge section. The pairing is by **name, not commits**, so it
survives whatever the forge does to commits (PR-branch rebases, squashes,
force-pushes). Must be disjoint from `## Branch Prefixes`.

### `## Push`

```md
## Push
push-prepare-branches: yes
```

`push-prepare-branches:` records the answer `init` captured to "may agents
create/commit/push preparation branches automatically?" Pushing is what makes a
branch a **message**: the human's `converge` and the next scheduled agent both
read remote-tracking refs, so a pushed branch is a cross-machine handoff. The
default is **`yes`**. Answer `no` to keep work local — `prepare` then commits
locally and stops for approval (single-machine by nature: the human and the next
run share one clone). When the `## Push` section is **absent** (a repo
initialized under schema 1, before this field existed), readers default to
`yes`, falling back to any curated Private-Git-Space wording that already grants
push there.

### `## Public branch`

```md
## Public branch
public-branch-tsugu: include
```

Controls whether the agent's `.tsugu/` coordination metadata reaches the default
branch. Two values, default **`include`**:

- **`include` (default):** the work branch **is** what merges — directly (solo
  flow) or via a slug-paired handoff branch. Merging lands the branch's `.tsugu/`
  evidence (`runs/`, `packets/`, the rewritten `context.md`) on the default
  branch as durable shared memory; there is no by-path filtering and no separate
  evidence-landing step. The trade-off, stated openly: mainline history carries
  the agent's preparation commits and `.tsugu/` files — and in the agent-first
  orientation that history *is* the memory.
- **`exclude` (opt-out):** cut a **fresh** public branch from the fetched default
  (handoff-named, same slug) and apply accepted changes **by path**, so the public
  diff introduces **no** `.tsugu/` changes (the guarantee is "never introduced",
  not "stripped afterward"). For collaborative repos where human reviewers should
  not see coordination metadata in the PR. Landing is then confirmed via the
  public branch's containment, not the work branch's (by-path application breaks
  the work branch's own containment).

### `## Merge method`

Tsugu **recommends merge commits — do not squash-merge tsugu-managed branches.**
Preserved history is what makes settlement, lineage, and evidence derivable from
the DAG; the recommendation is recorded here and in the README. The consequence
of a **forced squash:** the squash commit's parents contain none of the work
commits, so the landing is **not derivable** — lineage is severed, not obscured.
Exactly there, and only there, the fact is recorded out of band: the human
confirms the landing at `converge` and the intake note records `landed: <sha>`
(see the `landed:` semantics below).

### `## Housekeeping`

```md
## Housekeeping
<!-- stale-after: 30 days -->
```

`stale-after:` is the age threshold past which an in-progress branch or open
intake note is **surfaced for cleanup**. It ships **commented** — `converge`
records the threshold here progressively on first use (ask once), so it reflects
a real decision rather than a hardcoded guess. Staleness itself is **derived**,
never written: a branch is stale when its last commit (or, for a zero-commit
claimed branch, the coordination-ref commit that flipped its note to `claimed`)
is older than `stale-after`. Surfacing is for **human-decided cleanup** — the
list of over-threshold branches / notes is shown at `converge` for a person to
act on. **A scheduled `prepare` never cleans up** on its own.

### `remote:`

The authoritative remote for `git fetch` and branch enumeration. Default
`origin`. Stated explicitly for **multi-remote safety** — so `<remote>/…` refs are
unambiguous regardless of which remote the local checkout tracks.

### `default-branch:`

Optional override for `<default>`. If blank, `<default>` is resolved from
`<remote>/HEAD` (`git symbolic-ref refs/remotes/<remote>/HEAD`). Set it only when
`<remote>/HEAD` is unreliable or the repo's default is non-obvious.

### `coordination-ref:`

The ref where the mutable inbox (`intake/`) and promoted `knowledge/` are
written. **Default: `default`** (a sentinel meaning "the repo's default branch" —
it resolves to `<default>`, not a branch literally named `default`). Point it at
a dedicated branch (e.g. `tsugu/coord`, ideally an orphan) when the default
branch is **push-protected** — the agent needs a writable home for `.tsugu/`
coordination data, but in a human-collaborative repo the task **code** only ever
reaches default through a human-merged PR, not an agent push. That right varies
per environment, which is why it is a per-repo policy field.

### `## Intake Sources`

The human-bridge sources (if any) the repo observes. **Default: none** —
git-native only. List sources (e.g. an issue tracker, a notes file, an RSS feed,
a YARA/CVE watch, a CI query) here only if this repo needs to bridge a human-world
signal into git. See the human-bridge section below for the recorded form.

### `## Skill use`

States the shipped invariant: **Tsugu invokes no user-installed skill by
default** — it uses native git plus its own built-in capabilities (Task subagents,
Codex-as-a-tool, Claude's own reasoning). Humans trigger workflow skills
(planning, debugging, review-loop, …) by keyword. This text reflects the shipped
behavior and is the same in every repo.

### `## Skills Tsugu may use (this repo, opt-in)`

The **per-repo opt-in** — and the *only* place a skill name may appear. **Default:
none.** A repo owner MAY list specific user-installed skills (e.g.
`systematic-debugging`) that Tsugu may use during **human-absent `prepare`** in
**this repo**. This is repo-local config: the shipped `SKILL.md` never names a
skill, so the plugin stays universal while a repo extends it locally.

### `## Recursion`

Whether to recurse into submodules / child repos. Default: **only when relevant to
the current goal / intake / branch.** Keeps an omni-repo traversal scoped instead
of descending into every nested repo unconditionally.

## Intake: the optional human-bridge

**Git is the inbox.** A pure-Tsugu workflow communicates through git alone: an
agent fetches, sees new/changed branches and newly committed `.tsugu/intake/`
notes, and that *is* the work queue. No external tracker is required, and the
default loop runs with zero external integrations.

Tracker observation — an issue tracker, CI, a CVE feed, a notes file, Slack — is
**OPTIONAL** and is **not the spine.** It is a thin shim whose only job is to
convert a **human-world signal** into the git-native substrate: a committed
`.tsugu/intake/<slug>.md` note (and optionally a seed branch). The note records
where the signal came from in its `## Observed source` line (e.g.
`human-bridge: <name>`). Once that conversion happens, **every downstream step is
identical** — the queue read, the partition, the `prepare`/`converge` routines all
operate on the committed note and branches, never on the tracker. Tsugu ships
**no adapter** for any tracker; `## Intake Sources` is an interface stub, not built
integration.

### The configuration moment

Intake sources are configured **once**, and the configuration is recorded in
`policy.md` so the question is never re-asked.

- **`init` asks first.** `init` keeps its "Intake sources?" question (default:
  none — git-native only). A human who answers there is done.
- **First interactive `prepare` is the backstop.** For a repo initialized before
  this question existed, or where the human deferred the answer at `init`,
  `prepare` adds a one-time setup question. It is allowed despite `prepare`'s
  external-silence work posture because the first `prepare` run is typically
  interactive. On start, after reading `policy.md`, **if `## Intake Sources` is
  still the unconfigured default and a human can respond**, ask **once**:

  > Git-native intake is the default. Should I also read tasks/context from an
  > external source — a task manager, issue tracker, notes file, RSS feed, or a
  > watch/scan (YARA/CVE, CI)? If so, give me the read instruction — a shell
  > command, file path, or MCP tool name.

  Record the answer under `## Intake Sources` and continue.
- **A negative answer is also recorded** — as
  `default: git-native (confirmed — no external sources)` — so it is textually
  distinct from the unconfigured default and the question is never re-asked.
- **Push-protected persistence.** `policy.md` lives on the default branch, so when
  that branch is push-protected the recorded answer cannot be pushed directly.
  Follow the `init` rule: write the change on an `init/*` branch and open a
  **human-approved PR** (the human is present at the configuration moment, so the
  approval can happen right then). Until it merges, runs treat the field as
  unconfigured and fall back to git-native.
- **Never block headless.** If no human can respond (a scheduled/headless run),
  **never block** on the question: fall back to git-native intake, and note in the
  run note + packet that intake sources are unconfigured — `converge` surfaces
  this as an open question.
- Reconfiguration is not a special mode: the human edits `policy.md`, or runs
  `/tsugu:prepare` interactively and says to change the source.

### The recorded form

Each configured source is a natural-language entry plus **one read instruction** —
no per-system integration logic in the plugin:

```md
## Intake Sources
default: git-native. Each additional source below is read on every prepare run.

- name: my-todos
  read: ~/notes/todo.md                # a file path / MCP tool name / where to look
  notes: lines starting with "- [ ]" are open tasks; mention repo names to scope.
```

A source is three things: a **name**, **one `read:` pointer** (a file path, an MCP
tool name, or a description of where to look), and a **`notes:` interpretation
hint**. On each run the `prepare` **agent resolves** the pointer with its own
**permissioned tools** — Tsugu never directly executes a string committed in
`policy.md` — interprets the result with the hint, and converts anything new into
committed `.tsugu/intake/<slug>.md` notes (`status: open`,
`## Observed source: human-bridge: <name>`).

**Why a pointer, not a command.** `policy.md` lives in the repo, and `prepare` may
run headless/scheduled — so a `read:` that Tsugu auto-executed would be remote code
execution in any repo where others can write the default branch / coordination
ref. Instead the agent acts: it reads the file, calls the MCP tool, or — only where
a source genuinely needs a command — issues it as **its own gated tool call**, which
the harness's permission layer can prompt on, gate, or block. Prefer file paths and
MCP tools; reserve commands for trusted repos.

Sources are **not limited to task systems** — anything the agent can poll fits the
same shape: an RSS feed (the agent fetches `<url>`), a security watch (a YARA scan
whose new matches become intake notes), a CVE feed, a CI status query.
Downstream is identical regardless — the queue read, partition, and routines
operate only on git.

### Dedup, slugs never reused, re-opens out of scope

- **Dedup by slug.** Derive the slug from a **stable identifier** in the source
  (issue number, todo-line hash, title slug). If an intake note with that slug
  already exists at the coordination ref — in **any** status — **skip it**. A
  `done`/`dropped` note is the durable record that the item was already processed;
  re-importing would resurrect finished work.
- **Slugs are never reused for new work** (any intake form). A fresh ask whose
  slug collides with a `done`/`dropped` note or a lingering handoff branch is
  surfaced at `converge` as a naming conflict, not silently classified.
- **Re-opened source items are out of scope for v1.1.** A source item that comes
  back to life after its note is closed is **not** re-imported automatically — the
  human (or the human instructing the agent) authors a fresh intake note under a
  new slug.

### `landed:` semantics

`landed:` is a **write-once** field on the intake note, recorded **only** when a
**forced squash** severed containment — when landing is **not** derivable from the
DAG. Otherwise the work branch (or, in `exclude` mode, its slug-paired public
branch) is contained in the default ref and settlement is derivable; no SHA is
written. The SHA is **validated in both directions** — on write and on read it
must **resolve** and be **contained in the fetched default ref**; a `landed:` that
fails either check is a reconciliation case, never silent settlement.

`landed:` complements a claim that is itself **derived** — beginning active work
means rewriting `context.md`, and *that* commit's author and timestamp are the
claim (the 004 `claimed-by:`/`claimed-at:` fields are gone). `landed:` is the one
piece the DAG cannot supply once a squash has cut the thread, so it is written
down; everything else about the work's live state stays derived.

### The reconciliation rule

**Absence is never proof of success.** A `claimed` intake note whose linked branch
is **gone** — *without* a recorded `landed:` and *without* confirmable containment
in default — is a **reconciliation case**: surface it to the human at the next
`converge`. **Never** auto-flip it to `done` or `dropped`. The same applies to a
`landed:` SHA that fails validation on read. Closing an intake note (`claimed →
done`) requires a **confirmed landing** — containment, or the `converge`
confirmation that records a valid `landed: <sha>` — and happens **before branch
cleanup only**: the branch is the landing evidence, so it outlives the flip, never
the reverse.
