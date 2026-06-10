# notes-and-packet

The shape and lifecycle of every `.tsugu/` note Tsugu maintains: `branch.md`,
`intake/`, `runs/`, `packets/`, and `context/`. Placement on the durability
gradient (which branch each lives on) is summarized in `SKILL.md`; this document
covers structure and load/lifecycle semantics.

## `branch.md` — work-level live state

Ephemeral, lives **on each work branch**. Read without a checkout via
`git show <branch-ref>:.tsugu/branch.md`. It is the live context for one unit of
work.

- **`status:`** — `open | paused | converged | settled`. The work-level lifecycle:
  `open` while active or available, `paused` when set aside (resumable), `converged`
  after the human has reviewed and decided a disposition, `settled` at a terminal
  outcome (accepted or rejected).
- **`claimed-by:`** + **`claimed-at:`** — a **courtesy** pair, no lock. **Set when
  an agent begins active work**; **retained as historical state** on settle/pause
  (never auto-cleared). Polite-yield rule: `status: open` with a non-empty
  `claimed-by` and a **recent** `claimed-at` = treated as taken (another agent
  skips it); `status: open` with empty `claimed-by` or a **stale** `claimed-at` =
  free to pick up (re-set both on pickup). Recency is the agent's judgment in v1.
- Body sections: `## Why this branch exists`, `## Current understanding`,
  `## Open questions`, `## Next actions`, `## Verification`,
  `## Promotion candidates`.

## `intake/` — inbox-level record (two-layer model)

Durable, lives on the **coordination ref** (default = default branch) as
`intake/<slug>.md`. Intake and `branch.md` describe **different layers**, so they
never contradict:

| Layer | Where | Status field | Records |
| --- | --- | --- | --- |
| **Inbox** | `intake/<slug>.md` (coordination ref) | `open → claimed → done \| dropped` | *that* work entered the inbox and where it went |
| **Work** | `branch.md` (work branch) | `open \| paused \| converged \| settled` | the *live* work context |

Lifecycle: a queue-worthy intake item = a note with `status: open` and **no linked
branch**. When an agent opens a `prepare/*` branch for it, the note flips to
`claimed` and records a breadcrumb in `linked-branch:`. `settle` flips it to
`done` (accepted/handled) or `dropped` (abandoned). The inbox status tracks *where
the item went*; the branch status tracks *the work itself* — keeping them separate
is why two agents reading the same inbox never see a contradictory state.

Fields: `status:`, `linked-branch:` (set when → `claimed`); sections
`## Observed source` (git-native self-note / agent-discovered / `human-bridge:
<ref>`), `## Summary`, `## Related repos`, `## Initial guess`,
`## Need human context`.

## `runs/` — session notes

Ephemeral, on the work branch as `runs/<date-time>.md`. One note per `prepare`
session: an append-only trail of what an agent actually did, so a later agent (or
human) can reconstruct the session without the transcript. Sections: `## Goal`,
`## Context read`, `## Actions taken`, `## Branches touched`, `## Verification`,
`## Follow-up`, `## Need human context`, `## Promotion candidates`.

## `packets/` — convergence evidence

Ephemeral, on the work branch as `packets/<work-slug>.md`. The **bridge to the
human** at `converge`: a concise, reviewable summary so the human reviews
convergence instead of cold-starting. Sections:

- `## Intake source`
- `## Branches prepared`
- `## What was tried`
- `## What worked`
- `## What failed`
- `## Evidence`
- `## Relevant files`
- `## Test results`
- `## Remaining uncertainties`
- `## Need human decisions`
- `## Candidate next plans` — **hints** which workflow skill fits ("ready for
  planning", "this bug needs debugging", "this can go to review-loop"). It is a
  hint for the human to act on; it **does NOT fire a skill** — Tsugu invokes none.
- `## Public actions requiring approval`
- `## Suggested public branch` — a **name/target** for the branch `settle` will cut
  **fresh** from default. It is a proposal, **not "push this branch as-is"**: the
  prepare branch is messy private space; the public branch is cut clean.

## `context/` — promoted knowledge

Lives on the coordination ref. Three tiers with distinct **load semantics**:

- **`shared/`** — loaded by default. Reusable knowledge inherited by future
  branches/agents. Written **only after deliberate promotion** (during `settle`),
  never as a dumping ground. When `coordination-ref` ≠ the default branch, a branch
  cut from default won't contain `shared/`, so it must be read explicitly from
  `<remote>/<coordination-ref>`.
- **`dormant/`** — **not loaded by default.** Knowledge kept but not currently
  relevant; pulled in deliberately when needed.
- **`archived/`** — **not searched by default.** Retired knowledge kept for the
  record only.

## Context placement rule (omni-repo framing)

A single repo and an omni-repo are the **same abstraction** — Tsugu traverses a
tree of repos, and "where does this context belong" has one answer at any scale:

> Write context at the **lowest repo level where it remains true.** Promote upward
> (toward the omni-repo) **only** when the knowledge affects multiple repos or
> future coordination.

A fact true of one repo stays in that repo's `context/`; a fact true across
several repos is promoted to the enclosing omni-repo level. This keeps an
omni-repo from becoming a junk drawer — promotion is a deliberate "this is true
more broadly now" decision, not the default.
