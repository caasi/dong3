# tsugu

A git-native skill for **unattended work preparation and human–agent convergence**.
継ぐ (*tsugu*) means "to inherit / continue / carry forward" — Tsugu carries
engineering work forward across the gap when no human is watching, the handoff from
agent to human, and the resume by whoever comes next. It never auto-merges.

## What this is

Using git's DAG as the coordination substrate, an agent prepares engineering work
**privately on git branches** (often while you are away), records the evolving
narrative in a committed `context.md`, and promotes durable findings into a shared
`knowledge/` wiki. When you return, you **converge** — read the prepared branches
live, decide together what becomes public, and **hand off** the explored branch to
you (the human owns the design and the landing), all in one human-present session. A branch is a unit of work one agent
hands to the next; the committed `.tsugu/` knowledge is the memory that outlives the
session that produced it.

Tsugu prepares the board; workflow skills (planning, debugging, TDD, review-loop)
play the game with you; Tsugu converges the result. It is **not** an implementation
methodology — it prepares the input and carries the output forward, and triggers
none of those skills itself.

## The four routines

One lifecycle, four routines:

1. **init** — set up the repo's committed `.tsugu/` workspace + `policy.md` (the
   shared coordination policy). Asks the minimum; idempotent (re-running repairs the
   skeleton and never overwrites a curated `policy.md`; re-running on an older repo
   migrates the schema).
2. **prepare** (human absent) — fetch, derive the queue from git branches, do
   private git work on the configured work-prefix branches (default `prepare/*`),
   run tests, record evidence in `context.md`, and promote shareable findings into
   `knowledge/`. **External silence** — interrupt only if the task is unsafe,
   destructive, or blocked. Work stays on **local** `prepare/*` by default
   (**local-first**); pushing to the remote is a **cross-machine opt-in**
   (`push-prepare-branches: yes` in `policy.md`), which also restores the remote
   backup of in-flight work. When you take over a prepared branch onto your own
   branch, Tsugu recognizes the takeover by containment and surfaces the now-redundant
   `prepare/<slug>` for cleanup at `prune`/`converge` — it is **never auto-deleted**.
3. **converge** (human present) — read the prepared branches live, present the
   status view, decide **with you** what becomes public, and **hand off** that
   disposition in the same session. The default **accept** is a **handoff**: it
   **renames** the prepared `prepare/<slug>` branch to a repo-native
   `<accepted-prefix>/<slug>` and **stops** — the agent does not finish the work,
   rewrite history, push, or open a PR; **you** re-decide the design and own the
   landing. (The one exception: a task **you** explicitly marked maintenance-type — a
   security upgrade, a dependency bump — may be carried to ready-to-merge; the agent
   **never self-classifies** work as mechanical, and **never auto-merges**.) The
   other dispositions are **park** (note in `context.md` what's needed to resume) and
   **drop** (record *why*, then clean up). A branch you don't act on just
   **continues** — the implicit default. **Findings curation** rides alongside any of
   these: the agent surfaces durable findings + existing `knowledge/` entries and
   asks which to organise into the agent md (`CLAUDE.md` / `AGENTS.md`) — agent
   drafts, you approve. Tsugu presents and yields; it invokes no skill (you trigger
   any workflow skill by keyword). Running it just to look is a first-class use — the
   read-only pass is your **morning status view**: how many prepared branches are
   workable today, what awaits merge, what's stale. Looking and leaving is a valid
   outcome.
4. **prune** (human present) — a recurring, queue-wide cleanup sweep of unused
   branches (**local + remote**), the home for the destructive cleanup that
   handoff-only `converge` and a never-cleaning scheduled `prepare` leave to pile up.
   **Read-only until you confirm each item:** it deletes **settled** branches (tip
   landed in default) and **leftover worktrees** on confirmation, **surfaces +
   confirms** dropped / possibly-landed / orphaned-accepted before any delete, and
   **never** touches stale in-progress work (it points you to `converge` instead).
   No remote delete without your explicit per-item approval.

## How to invoke

```text
/tsugu:init         # set up .tsugu/ + policy.md
/tsugu:prepare      # private preparation while you are away
/tsugu:converge [branch]   # read the branches together, decide + hand off in-session
/tsugu:prune        # human-approved sweep of unused local + remote branches
```

`prepare` is meant to run on a cadence — wire it to an external driver (a local
cron, `/loop`) **on the provisioned machine**: the one that holds *both* the
personal-folder source config *and* the live MCP/connector credentials (typically
your local homelab). An unprovisioned cloud/headless run is allowed but degrades to
**git-native only** — it works the queue derivable from refs, with no tracker/source
intake. A SKILL.md cannot self-wake; the cadence always comes from an external
driver you start.

## The `.tsugu/` namespace at a glance

The committed `.tsugu/` is a **work-in-progress knowledge layer** — a richer,
agent-maintained sibling of `AGENTS.md` / `CLAUDE.md`, pushed so any inheritor reads
it from `git fetch` alone. It holds exactly three things:

```text
.tsugu/
  policy.md      shared coordination policy (boundary, work + accepted prefixes,
                 merge method, … — `tsugu-schema: 5`)
  context.md     this ref's narrative — every branch tells its own story; the
                 default branch tells the mainline's
  knowledge/     free-form shared wiki (promoted, durable findings)
```

Everything *about how Tsugu operates for one human* lives in a **personal folder**,
per machine and **never committed**:

```text
~/.claude/tsugu/<project-key>/   (per machine, never committed; not in the repo)
  config.md      observation sources + opt-in skills
  packets/       converge decision-views (derived, regenerated live)
```

The repo holds knowledge; the skill holds behavior; the personal folder holds one
human's setup. `<project-key>` derives from the repo's git common dir, so every
worktree of one repo shares one personal folder per machine. The personal folder
does not transfer across machines — the only cross-machine contract is the pushed
git branches, so each machine seeds its own config (Tsugu asks once, on the first
interactive `prepare`/`converge`).

After `git fetch`, the queue is read from **local + remote** work-prefix refs
(local-first by default; remote work refs are read too, for opt-in pushes and
leftovers) — branch names plus each branch's `context.md` must be legible enough
that a cold-start agent can
reconstruct what branches exist, why, and what's next, with **zero conversation
transcript**.

## State is derived

Tsugu writes **no status fields**. Live coordination state is read from git's own
facts — ref names, ancestry, containment, commit recency — never from a tracked
status line. There is **no inbox layer and no recorded landed-SHA**; the partition
is single-layer, classifying each work branch by two ref-level facts:

- **settled** = the work landed, derived from **containment** (the branch's tip is
  contained in the default branch).
- **taken over** = a human now owns the work — either any **non-default, non-work
  branch contains** the tip (a human carried it onto their own branch) **or** a
  **slug-paired accepted branch** exists (a `converge` handoff). tsugu stops
  managing it; converge surfaces accepted handoffs in its awaiting-merge section.
  Slug-pairing is by name, so it survives anything the forge does to commits — the
  complementary catch when a history rewrite severs containment.

Because settlement is derived from history, **prefer merge commits**. A landing that
rewrites history (squash, rebase-before-merge, force-push) leaves the work tip
uncontained and breaks containment-derived settlement — that path is handled in
[`references/advanced.md`](references/advanced.md).

## Private vs public boundary

The load-bearing invariant, recorded per-repo in `policy.md`:

```text
Git branch / pushed branch / committed .tsugu/    →  agent may do freely
MR / PR / tracker / Slack / reviewer assignment   →  human approval required
```

Tsugu works freely in private git space and **never performs public coordination
without approval**.

## Public-branch mode

`public-branch-tsugu: include | exclude` (recorded in `policy.md`, **default
`include`**) governs whether the committed WIP-knowledge layer lands on the
public/default branch:

- **`include`** (default) — the work branch merges as-is, so its **prep commit DAG
  plus its `context.md` narrative** land on the mainline as durable shared memory.
- **`exclude`** — keeps `.tsugu/` **off the default branch**, for collaborative repos
  that want coordination metadata out of public history. Accept is the same handoff
  rename in both modes (the renamed branch carries `.tsugu/`); in `exclude` the
  **human strips `.tsugu/` when they open the public PR** — converge no longer cuts a
  separate by-path public branch.

Either way, **`knowledge/` lands on the coordination ref** — it is the team's shared
brain in both modes.

## Non-goals

- **Never auto-merges** and never opens an MR/PR or touches a tracker on its own.
- **Light / script-free** — recipes are documented git guidance; no scripts ship.
- **Invokes no user-installed skill by default** — native git + its own built-in
  subagents only. A repo's personal folder may opt-in to named skills per machine;
  the shipped skill stays skill-agnostic.

See the design specs for the full model:
[004 — the original skill design](../../../../docs/superpowers/specs/004-tsugu-skill-design.md)
and [005 — the agent-first revision](../../../../docs/superpowers/specs/005-tsugu-agent-first-design.md)
(lineage: the init/prepare/converge routines, derived state), refined by
[006 — the workspace holds only what transfers (schema 3)](../../../../docs/superpowers/specs/006-tsugu-workspace-transfer-design.md)
(committed WIP-knowledge layer + personal folder) and
[007 — the thin core (schema 4)](../../../../docs/superpowers/specs/007-tsugu-thin-core-design.md)
(single `prepare/*` work prefix, accepted-prefixes, non-containment landings → advanced).
