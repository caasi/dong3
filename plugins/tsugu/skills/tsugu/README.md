# tsugu

A git-native skill for **unattended work preparation and human–agent convergence**.
継ぐ (*tsugu*) means "to inherit / continue / carry forward" — Tsugu carries
engineering work forward across the gap when no human is watching, the handoff from
agent to human, and the resume by whoever comes next. It never auto-merges.

## What this is

Using git's DAG as the coordination substrate, an agent prepares engineering work
**privately on git branches** (often while you are away), records evidence in
committed `.tsugu/` notes, and packages a **convergence packet**. When you return,
you **converge** — review the prepared evidence, decide together what becomes
public, and complete that decision into clean public form, all in one
human-present session. A branch is a unit of work one agent hands to the next;
committed `.tsugu/` notes are the memory that outlives the session that produced
them.

Tsugu prepares the board; workflow skills (planning, debugging, TDD, review-loop)
play the game with you; Tsugu converges the result. It is **not** an implementation
methodology — it prepares the input and carries the output forward, and triggers
none of those skills itself.

## The three routines

One lifecycle, three routines:

1. **init** — set up the repo's `.tsugu/` workspace + `policy.md` (the agent's
   coordination metadata). Asks the minimum; idempotent (re-running repairs the
   skeleton and never overwrites a curated `policy.md`).
2. **prepare** (human absent) — fetch, find work (from git branches / `.tsugu/`
   intake notes / agent-discovered issues), do private git work on the configured
   work-prefix branches (`prepare/*`, `investigate/*`, `review/*`), run tests,
   record evidence + a convergence packet. **External
   silence** — interrupt only if the task is unsafe, destructive, or blocked.
3. **converge** (human present) — present the packet + prepared branches, decide
   **with you** what becomes public, and complete that disposition in the same
   session: accept (cut a handoff branch, promote knowledge, open a PR — all
   **human-gated**), reject, or park. Tsugu presents and yields; it invokes no
   skill (you trigger any workflow skill by keyword). Running it just to look is a
   first-class use — the read-only pass is your **morning status view**: how many
   prepared branches are workable today, what awaits merge, what needs
   reconciliation. Looking and leaving is a valid outcome.

   Set `public-branch-tsugu: exclude` in `policy.md` to keep `.tsugu/` evidence out
   of PR diffs (a clean public branch applied by path, for collaborative repos);
   the default `include` lands the evidence on the mainline as durable shared
   memory.

## How to invoke

```text
/tsugu:init         # set up .tsugu/ + policy.md
/tsugu:prepare      # private preparation while you are away
/tsugu:converge [branch]   # review the packet together, decide + complete in-session
```

`prepare` is meant to run on a cadence — wire it to `/schedule` / cron so a cloud
agent runs it. A SKILL.md cannot self-wake; the cadence always comes from an
external driver.

## The `.tsugu/` namespace at a glance

All Tsugu metadata is **committed** under `.tsugu/` (it is shared memory, not local
scratch):

```text
.tsugu/
  policy.md      coordination rules (private vs public boundary, branch prefixes, …)
  templates/     skeletons written by init
  intake/        durable shared inbox (git-native work queue)
  context.md     this ref's situation, pure narrative — every branch and the mainline
  knowledge/     promoted knowledge; structure is the agents' own
  runs/          per-session work notes (runs/<slug>-<date-time>.md)
  packets/       convergence evidence for the human to review
```

After `git fetch`, the queue is read from remote-tracking refs — branch names plus
`.tsugu/` notes must be legible enough that a cold-start agent can reconstruct what
branches exist, why, and what's next, with **zero conversation transcript**.

## State is derived

Tsugu writes **no status fields**. Live coordination state is read from git's own
facts — ref names, ancestry, containment, commit recency — never from a tracked
status line:

- **settled** = the work landed, derived from **containment** (the branch's tip is
  contained in the default branch).
- **pending** (decided, awaiting merge) = a **slug-paired handoff branch** exists —
  a branch under a configured handoff prefix sharing the work branch's slug. The
  pairing is by name, so it survives anything the forge does to commits.

Because settlement is derived from history, **prefer merge commits — do not
squash-merge tsugu-managed branches**. A squash severs the ability to derive the
landing; if a human system forces one, `converge` confirms it and records
`landed: <sha>` in the intake note so the fact is still recoverable.

## Private vs public boundary

The load-bearing invariant, recorded per-repo in `policy.md`:

```text
Git branch / pushed branch / .tsugu notes        →  agent may do freely
MR / PR / tracker / Slack / reviewer assignment   →  human approval required
```

Tsugu works freely in private git space and **never performs public coordination
without approval**.

## Non-goals

- **Never auto-merges** and never opens an MR/PR or touches a tracker on its own.
- **Light / script-free** — recipes are documented git guidance; no scripts ship.
- **Invokes no user-installed skill by default** — native git + its own built-in
  subagents only. A repo's `.tsugu/policy.md` may opt-in to named skills locally;
  the shipped skill stays skill-agnostic.

See the design specs for the full model:
[004 — the original skill design](../../../../docs/superpowers/specs/004-tsugu-skill-design.md)
and [005 — the agent-first revision](../../../../docs/superpowers/specs/005-tsugu-agent-first-design.md)
(three routines, derived state).
