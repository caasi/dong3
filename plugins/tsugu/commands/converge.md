---
description: Human-present convergence — morning status view (read-only until you decide), then decide dispositions in-session. Accept is handoff-only (renames prepare/<slug> to an accepted prefix and stops); completes only on a human-marked maintenance task. Never auto-merges; cleanup is pointed at /tsugu:prune
argument-hint: "[branch]"
---

# /tsugu:converge

Invoke the `tsugu` skill and run the **converge** routine. `$ARGUMENTS` may name
a branch to converge directly, skipping the selection question.

Load-bearing invariants the skill enforces: reads branches live (the local +
remote work refs after fetch — local-first, the same union as `prepare`) — the
packet is a personal/derived view,
never committed; steps before the disposition are read-only — running this just
to look (how many branches are workable, what awaits merge, what is stale) is a
first-class use; **accept hands off** — it renames `prepare/<slug>` to
`<accepted-prefix>/<slug>` (a move, slug preserved) and stops, leaving the
freshness-rebase / verify / completion to the human; the **complete** path runs
only when the human has explicitly **marked the task as maintenance** (the agent
never self-classifies); merging/opening the PR is the human's act — Tsugu never
auto-merges; staleness is shown as a flag on the candidate list, and the
queue-wide cleanup of settled / leftover branches is pointed at `/tsugu:prune`.

Before the human triggers a workflow skill, `converge` reminds the agent to
**verify findings** with the human — a reminder, not a routine step (spec 017).
