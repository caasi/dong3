# tsugu

A git-native skill for **unattended work preparation and human–agent convergence**.
継ぐ (*tsugu*) means "to inherit / continue / carry forward" — Tsugu carries
engineering work forward across the gap when no human is watching, the handoff from
agent to human, and the resume by whoever comes next. It never auto-merges.

## What this is

Using git's DAG as the coordination substrate, an agent prepares engineering work
**privately on git branches** (often while you are away), records evidence in
committed `.tsugu/` notes, and packages a **convergence packet**. When you return,
you **converge** — review the prepared evidence and decide together what becomes
public — and the work is **settled** into clean public form. A branch is a unit of
work one agent hands to the next; committed `.tsugu/` notes are the memory that
outlives the session that produced them.

Tsugu prepares the board; workflow skills (planning, debugging, TDD, review-loop)
play the game with you; Tsugu settles the result. It is **not** an implementation
methodology — it prepares the input and settles the output, and triggers none of
those skills itself.

## The four routines

One lifecycle, four routines:

1. **init** — set up the repo's `.tsugu/` workspace + `policy.md` (the agent's
   coordination metadata). Asks the minimum; idempotent (re-running repairs the
   skeleton and never overwrites a curated `policy.md`).
2. **prepare** (human absent) — fetch, find work (from git branches / `.tsugu/`
   intake notes / agent-discovered issues), do private git work on `prepare/*`
   branches, run tests, record evidence + a convergence packet. **External
   silence** — interrupt only if the task is unsafe, destructive, or blocked.
3. **converge** (human present) — present the packet + prepared branches and decide
   **with you** what becomes public. Tsugu presents and yields; it invokes no skill
   (you trigger any workflow skill by keyword).
4. **settle** — accept / reject / pause. For accepted work: cut a clean public
   branch (no `.tsugu/` in the diff), open a PR (**human-gated**), promote reusable
   knowledge to shared context, and clean up branches/worktrees.

## How to invoke

```text
/tsugu              # lists the four routines and asks which to run
/tsugu init         # set up .tsugu/ + policy.md
/tsugu prepare      # private preparation while you are away
/tsugu converge     # review the packet together, decide what goes public
/tsugu settle       # accept / reject / pause the converged work
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
  context/       shared / dormant / archived knowledge, promoted on settle
  branch.md      per work branch: status + claim metadata
  runs/          per-session work notes
  packets/       convergence evidence for the human to review
```

After `git fetch`, the queue is read from remote-tracking refs — branch names plus
`.tsugu/` notes must be legible enough that a cold-start agent can reconstruct what
branches exist, why, and what's next, with **zero conversation transcript**.

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

See [the design spec](../../../../docs/superpowers/specs/004-tsugu-skill-design.md)
for the full model.
