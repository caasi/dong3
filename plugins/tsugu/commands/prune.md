---
description: Human-present, read-only-until-approved sweep of unused local + remote branches — deletes settled/leftover-worktree on confirm; surfaces dropped/possibly-landed/orphaned-accepted to confirm; never touches unfinished work. Never deletes without explicit per-item approval
argument-hint: ""
---

# /tsugu:prune

Invoke the `tsugu` skill and run the **prune** routine. A queue-wide cleanup pass
for unused branches (local + remote).

Load-bearing invariants the skill enforces: read-only until per-item human
confirmation (running it just to look is fine); deletes only **settled** (tip
contained in default) and **leftover worktrees** directly on confirm; surfaces
**dropped / possibly-landed (no containment) / orphaned-accepted** for explicit
confirmation; **stale in-progress** is surfaced read-only and pointed at
`converge`, never deleted here; **remote deletes run only after explicit per-item
approval** (no remote delete without human approval).
