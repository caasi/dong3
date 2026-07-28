# notes-and-packet

The shape and lifecycle of the committed `.tsugu/` notes Tsugu maintains —
`context.md` and `knowledge/` — plus a short note on the **personal/derived**
packet. Placement on the durability gradient (which branch each lives on) is
summarized in `SKILL.md`; this document covers structure and load/lifecycle
semantics. There is **no written branch state** — live coordination facts (in
progress / taken over / settled / who's on it / what grew out of what) are derived
from ref names, ancestry, containment, and commit recency, never written into a
note (see `SKILL.md`'s partition and `references/git-recipes.md`). The committed
notes hold **narrative only** (maintained freely; it informs judgment, never
classification).

## `context.md` — every ref describes itself, in pure narrative

Lives **on each ref** — every work branch and the default branch. Read without a
checkout via `git show <branch-ref>:.tsugu/context.md`. It is the ref's situation
and origin told as narrative: **no `status:`, no `claimed-*`, no recorded
lineage** — those facts are derived from refs and the DAG.

- **On a work branch:** why this branch exists, current understanding, open
  questions, blindspots, next actions, verification, promotion candidates. The
  branch's story is **self-contained** — `## Promotion candidates` points at
  `knowledge/`, but there are no links to per-session files (there are none on
  the branch).
  Sections: `## Why this ref exists`, `## Current understanding`,
  `## Open questions`, `## Blindspots`, `## Next actions`, `## Verification`,
  `## Promotion candidates`.
- **On the default branch:** the mainline's current situation — what this repo
  is, where the mainline stands, what recently landed. `init` writes the first
  version.

The mainline form ends with a **standing, byte-immutable
`POST-HANDOFF CLEANUP` block** (an HTML comment, the
finishing-agent reminder). Its **narrative reset** is
**inert in `exclude` mode** — the human strips `.tsugu/` before the
public PR, so no branch narrative reaches default and there is
nothing to reset — and does real work only in `include` mode. Its
`knowledge/` **reconciliation applies in both modes**, because
`knowledge/` lands on the coordination ref either way (spec 017:
that reconciliation is what disposes of a kept blindspot probe).

**Prefer runnable evidence.** Verification should point at runnable artifacts — a
committed repro script, a failing test, a probe — over prose claims (extending
004's principle #12): the next inheritor re-runs instead of re-trusting. Narrative
explains; running code demonstrates.

**Inherit → rewrite cycle.** A new work branch cut from default inherits the
mainline `context.md`. The agent's **first act of real work rewrites it** into the
branch's own narrative — and that rewrite commit *is* the claim (its author and
timestamp are what the courtesy-yield rule reads; see `SKILL.md`'s Multi-agent
section). There is always a `context.md`. A branch with real commits whose
`context.md` is still the inherited mainline form is simply a candidate whose
narrative hasn't been written yet; the partition needs no special rule for the
file's form.

**Reset before landing (`include` mode).** Under 011, `converge`
**accept** renames `prepare/<slug>` → `<accepted-prefix>/<slug>`
and **stops** — it does **not** rewrite `context.md` to a mainline
narrative. The branch's own-story `context.md` rides the rename
unchanged; the human and a finishing agent complete the work
**outside tsugu's lifecycle**. Because `context.md` carries
`merge=union`, landing the branch would otherwise concatenate its
whole story onto the mainline note (duplicate `##` headers). So
the **finishing agent resets `context.md` to the mainline form
before landing** — prompted by the standing `POST-HANDOFF CLEANUP`
block and the always-loaded agent-md pointer (spec 015). That
reset also **collapses Blindspots** together with the branch's own
story: the byte-immutable 015 block cannot name the new `##
Blindspots` section without a schema bump. This note carries the instruction for the tsugu-side reader; the
finishing agent's copy is the section's own skeleton comment in
`context.md`, which `prepare` keeps (spec 017).
The converge verify-findings reminder feeds the
packet's **remaining uncertainties**. `converge` itself never
rewrites the mainline. If the PR is instead rejected, the branch
narrative is rewritten again at the next decision — narrative is
maintained freely.

**No lineage.** Lineage *to the mainline* is an ancestry question the DAG answers
while history is preserved. Cross-work-branch lineage is **scratch-grade** — a
freshness rebase may sever it, and that is acceptable; lineage never drives
classification. A recorded copy only goes stale. (When a forced squash severs
containment, the slug-paired accepted branch — not a written field — carries the
"awaiting merge" state; see `SKILL.md`'s partition and `references/git-recipes.md`.)

**Backward compatibility.** Readers accept a legacy `branch.md` when `context.md`
is absent on a work branch. A legacy `status:` field is read once and folded into
the narrative on next touch: a legacy `status: settled` branch is a **cleanup
candidate**; a legacy `status: converged` branch is **surfaced at the next
`converge`** for its pending decision to be re-anchored (accepted branch or direct
merge).

## `knowledge/` — free-form, repo-wide agent wiki

`.tsugu/knowledge/` on the **coordination ref** (default = the default branch). It
is the team's shared brain — and it **lands on the coordination ref in both
`include` and `exclude` modes**.

The instruction is simply: **put shareable repo knowledge here** — findings a
coworker's agent would want. Kept to the audience boundary: **not**
private-source details, **not** session-specific scratch — those are personal or
ephemeral, never the committed wiki. A **half-formed** insight meant for the team
is still shareable; the split is audience, not maturity.

**One blessed transient: the blindspot probe.** `prepare` may
write decision-free disposable code to ground a blindspot and
keeps it here as rerunnable evidence (SKILL.md, `prepare` step 8).
It is disposed of by the POST-HANDOFF `knowledge/` reconciliation.
Until then leave it alone:
the optional cull below does not apply to it, and neither
does the write-gate. Promote-as-move still applies.

**No prescribed structure.** Agents organize, reorganize, and prune as they judge
(each a `.tsugu/`-only commit). There is no fixed **layout** — smarter future models
inherit the freedom, not a frozen taxonomy. It absorbs the shareable findings a
session produces (the underlying transcript is ephemeral and is not kept).

**Lean discipline (a finding lives in exactly one place).** Layout is free, but
`knowledge/` follows the same rule a good memory system does — *don't record what
the repo already records* — so it stays a lean synthesis layer, not a second copy of
git history or the agent md:

- **Write-gate (the entry gate).** Before **writing** a finding **into**
  `knowledge/`, check it isn't already in a commit message / derivable from the DAG,
  or already in the agent md (`CLAUDE.md` / `AGENTS.md`). If it is → **don't
  duplicate.** *Do not record what the repo, a commit, or the agent md already
  records.*
- **Promote-as-move (the one-way exit).** Promotion runs in **one direction only**:
  `knowledge/` → agent md, once a finding has **stabilised into a durable convention**
  and the human endorses it. **Promote = move, not copy** — once a finding graduates
  into the agent md, **remove it from `knowledge/`** (leave at most a pointer), so a
  finding sits in **one place**, never two drifting copies.
- **The line (so culling doesn't over-delete).** *Don't restate a single commit*
  (history has it). *Do keep cross-commit synthesis and the "why" no single commit
  holds* — e.g. "these 4 fixes share root cause X"; "this gotcha spans explore-ui and
  portal-api." git history is durable but not legible at a glance; that synthesis is
  exactly what `knowledge/` is for.

**The `knowledge/` ↔ agent-md boundary.** `knowledge/` holds **WIP / still-evolving /
cross-cutting** agent-shared findings; the **agent md** (`CLAUDE.md` / `AGENTS.md`)
holds **durable, stabilised, human-endorsed conventions**. The two stores are not
interchangeable, and the write-gate + promote-as-move together keep any one finding
in exactly one of them. Promotion into the agent md is **public coordination** — the
agent drafts, the human approves; it is never an autonomous write.

Converge **may** also surface `knowledge/` entries gone redundant (already promoted,
or merely restating a commit) and offer to remove them — an optional cull, not a
required step.

## The packet — personal and derived

The convergence **packet** (`packets/<slug>.md`) is **not** a committed `.tsugu/`
note. It lives in the **personal global folder**
(`~/.claude/tsugu/<project-key>/packets/<slug>.md`), is **regenerated live at
`converge`** from the prepared branches (`context.md` + the DAG + this machine's
own sources), and is **never pushed**. It is a *derived, personal lens* over the
shared truth — the shared, inheritable truth is the branch (`context.md` +
commits) and `knowledge/`. **Machine B needs no packet from machine A:** it
regenerates the decision-view live from the pushed branches.

Its purpose is unchanged — the **bridge to the human** at `converge`: a concise,
reviewable summary so the human reviews convergence instead of cold-starting.
Sections: `## Intake source`, `## Branches prepared`, `## What was tried`,
`## What worked`, `## What failed`, `## Evidence`, `## Relevant files`,
`## Test results`, `## Remaining uncertainties`, `## Need human decisions`,
`## Candidate next plans` (a **hint** which workflow skill fits — "ready for
planning", "this bug needs debugging", "this can go to review-loop" — for the
human to act on; it **does NOT fire a skill**), `## Public actions requiring
approval`, and `## Suggested accepted branch` (the Accepted-Prefix name the handoff
**renames** `prepare/<slug>` to — mode-agnostic: the same commits, with `.tsugu/`
riding along in both modes; in `exclude` the human strips `.tsugu/` when they open
the public PR. Converge no longer *cuts* a branch).

**Taken-over (redundant prepare) — surfaced, never auto-deleted.** A
`prepare/<slug>` whose tip a **non-work, non-default** branch contains (a human
carried the work onto their own branch — `isaac/fix-thing`) is **taken over**:
suppressed from auto-work and **surfaced** at `prune`/`converge` (the packet's
`## Need human decisions` / `## Public actions requiring approval`) for the human to
**confirm or reject**. `prune` carries it as a **`taken-over` (redundant prepare)**
category — **surface-and-confirm** (like *possibly-landed*), **never auto-delete**:
the containment signal can false-positive on a branch built *on top of* the prepare
tip (a sibling item, a scratch experiment). On confirmation the redundant ref is
deleted **local *and* remote, both human-confirmed**. This category is the
**git-containment-derivable** take only — the slug-paired **squash/rewrite** handoff
is **not** derivable from containment and surfaces as *possibly-landed*, not here. **Precedence with *settled*:**
if `<remote>/<default>` contains the tip it is **settled** (the existing category) —
list it there; *taken-over* covers only the case where the containing ref is a
**non-default** branch. (Mechanics → `git-recipes.md` § Prune sweep.)

## Context placement rule (omni-repo framing)

A single repo and an omni-repo are the **same abstraction** — Tsugu traverses a
tree of repos, and "where does this context belong" has one answer at any scale:

> Write context at the **lowest repo level where it remains true.** Promote upward
> (toward the omni-repo) **only** when the knowledge affects multiple repos or
> future coordination.

A fact true of one repo stays in that repo's `knowledge/`; a fact true across
several repos is promoted to the enclosing omni-repo level. This keeps an
omni-repo from becoming a junk drawer — promotion is a deliberate "this is true
more broadly now" decision, not the default.

## Graduation (knowledge relocation)

When a bare submodule the omni-repo was managing gets its own `.tsugu/`, the
submodule-specific knowledge moves **down** out of the omni `.tsugu/` — the
deliberate inverse of "promote upward." `init` detects the enclosing omni-repo
(`git rev-parse --show-superproject-working-tree` → check that superproject for
`.tsugu/`), scans the omni `knowledge/` for entries naming this submodule,
**presents them**, and on **per-entry human confirmation** cuts them down into the
new submodule `knowledge/` (move content, remove from meta) — leaving the omni level
holding only genuinely cross-cutting knowledge.

**Graduation is a repo mutation, not a relabel.** Creating the submodule's
`.tsugu/policy.md` is a new submodule commit; removing the omni entries is a meta
commit; **the omni gitlink must be bumped** to the submodule commit carrying the new
`.tsugu/` — else a fresh checkout stays pinned to a pre-`.tsugu/` SHA, re-classifies
the submodule as bare, and operationally **reverses** graduation. `init` makes these
as ordinary commits per repo (submodule first, then the meta gitlink bump + knowledge
removal) and is **re-entrant** (interrupted midway, re-running re-detects remaining
omni entries). No atomic cross-repo transaction is claimed; the human drives any PR.

**In-flight paired branches are left alone** — they finish at meta `converge`; only
new post-graduation work goes native-in-submodule. One guard: when such an in-flight
pair later accepts, its meta gitlink-bump must target the **current submodule default
tip** (which contains both the accepted work and the graduation commit), never a bare
ancestor — the same re-point rule as the two-repo accept, applied across the
graduation boundary.
