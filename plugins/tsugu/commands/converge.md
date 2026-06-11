---
description: Human-present convergence — morning status view (read-only until you decide), then decide and complete dispositions in-session. Never auto-merges
argument-hint: "[branch]"
---

# /tsugu:converge

Invoke the `tsugu` skill and run the **converge** routine. `$ARGUMENTS` may name
a branch to converge directly, skipping the selection question.

Load-bearing invariants the skill enforces: steps before the disposition are
read-only — running this just to look (how many branches are workable, what
awaits merge, what is stale) is a first-class use; merging/opening the PR is
the human's act — Tsugu never auto-merges; housekeeping (stale branches) is
human-decided per item.
