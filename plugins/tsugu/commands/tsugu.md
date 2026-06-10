---
description: Run a Tsugu routine — git-native unattended work preparation & human–agent convergence (init / prepare / converge / settle)
argument-hint: "[init|prepare|converge|settle]"
---

# /tsugu

Carry engineering work forward across human-absence and the agent→human handoff, using git's DAG as the coordination substrate. One lifecycle, four routines:

- `/tsugu init` — set up the repo's `.tsugu/` workspace + `policy.md` (the agent's coordination metadata); ask the minimum, idempotent.
- `/tsugu prepare` — while the human is absent: fetch, find work (git branches / intake notes / agent-discovered issues), do private git work on `prepare/*` branches, run tests, record evidence + a convergence packet. External silence.
- `/tsugu converge` — while the human is present: present the packet + prepared branches and decide together what becomes public. Tsugu presents and yields; the human triggers any skill by keyword.
- `/tsugu settle` — accept / reject / pause. For accepted work: cut a clean public branch (no `.tsugu/` in the diff) and open a PR (human-gated), promote reusable knowledge, clean up branches/worktrees.

**Routing:**

The argument (`$ARGUMENTS`) is passed to the `tsugu` skill, which dispatches to the matching routine. If no argument is supplied, the skill lists the four routines above with one-line descriptions and asks which to run.

**Behavior:**

Invoke the `tsugu` skill. Load-bearing invariants the skill enforces:

- **Never auto-merges** — no public coordination (MR/PR, tracker, reviewer assignment) without human approval.
- **Light / script-free** — routines are documented guidance; no shell scripts are shipped with the plugin.
- **Invokes no user-installed skill by default** — Tsugu uses native git + its own built-in capabilities; a repo's `.tsugu/policy.md` may opt-in to named skills locally.
