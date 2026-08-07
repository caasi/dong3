# notes-and-packet

The shape and lifecycle of the committed `.tsugu/` notes Tsugu maintains —
`context.md` and `evidence/` — plus a short note on the **personal/derived**
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
  questions, blindspots, next actions, verification. The branch's story is
  **self-contained** — `## Verification` and `## Blindspots` point at the
  artifacts in `evidence/`, and there are no links to per-session files (there
  are none on the branch).
  Sections: `## Why this ref exists`, `## Current understanding`,
  `## Open questions`, `## Blindspots`, `## Next actions`, `## Verification`.
- **On the default branch:** the mainline's current situation — what this repo
  is, where the mainline stands, what recently landed. `init` writes the first
  version.

The mainline form ends with a **standing
`POST-HANDOFF CLEANUP` block** (an HTML comment, the
finishing-agent reminder). Its **narrative reset** is
**inert in `exclude` mode** — the human strips `.tsugu/` before the
public PR, so no branch narrative reaches default and there is
nothing to reset — and does real work only in `include` mode. Its
**`evidence/` disposal runs in both modes**: three of its four
routes write outside `.tsugu/` — the agent md, `docs/`, the test
suite — so they land whatever the mode, and only the deletion half
is inert where the human strips the directory anyway.

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

**Reset before landing.** Under 011, `converge`
**accept** renames `prepare/<slug>` → `<accepted-prefix>/<slug>`
and **stops** — it does **not** rewrite `context.md` to a mainline
narrative. The branch's own-story `context.md` rides the rename
unchanged; the human and a finishing agent complete the work
**outside tsugu's lifecycle**. Landing the branch would otherwise
put a dead branch's story on the mainline note. So the **finishing
agent resets `context.md` to the mainline form before landing** —
prompted by the standing `POST-HANDOFF CLEANUP` block and the
always-loaded agent-md pointer (spec 015) — and disposes of the
`evidence/` files that branch added, at the same moment. The
reset also **collapses Blindspots** together with the branch's own
story. This note carries the instruction for the tsugu-side reader; the
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

## `evidence/` — this branch's artifacts, emptied at landing

`.tsugu/evidence/` lives **on every ref**, exactly like `context.md`: each work
branch carries its own, and the default branch carries the mainline's, which in its
settled state holds `.gitkeep` and nothing else.

`context.md` explains the work; the files here let the next reader **run the check
instead of trusting the text**. Three kinds:

1. **Runnable evidence** — a repro script, a failing test not yet in the suite, a
   blindspot probe (017), a benchmark harness, a one-off check script. This is the
   primary content; 017's "one blessed transient" is now the ordinary case.
2. **Captured raw output too large for the narrative** — a profiler run, a long log,
   an API response, a `git log` dump. The claim in `context.md` rests on it.
3. **In-flight working documents** — the enumeration of every call site of a function
   being changed, an option-space comparison, a design sketch still under argument.

**No entry gate, and no prescribed layout.** Write freely; organise, rename and prune
as you judge. Whether a file is worth keeping is knowable only once the work is
finished, so the judgement belongs at landing and asking it at write time only
suppresses the writing.

**Prose belongs here, and it must cite.** A prose file quotes code or names an
external fact — a file and line, a command and its output, a specification, a ticket.
Evidence that cites nothing is an opinion, and `context.md` is where an opinion goes.

**One rule binds the write, and it is about disclosure.** `evidence/` is committed,
pushed under `push-prepare-branches: yes`, and reaches the default branch in
`include` mode, so a captured log or response can carry a token, a credential or
personal data onto a public branch. **Redact a capture before it is committed, or do
not capture it.** A secret found in something already committed is not fixed by
deleting the file in a later commit: **stop, tell the human, and treat it as exposed**
so it can be rotated. Rewriting history is a public destructive act the agent does not
perform unasked.

**Cross-branch reading needs no shared ref.** A per-ref directory is readable from any
other ref without a checkout, which is what replaced the coordination ref:

```bash
git ls-tree -r --name-only <branch> .tsugu/evidence/   # -r: agents may nest
git show <branch>:.tsugu/evidence/<file>
```

An un-converged branch keeps its `evidence/` for as long as it exists, so the material
is there for the whole time the sharing is wanted. Naming the branch to read is not a
new burden: `prepare` derives its queue from the local and remote work refs and
`converge` lists the candidates, so both already hold the branch list.

## Disposal at landing (the four routes)

The finishing agent resets `context.md` and disposes of `evidence/` at the same
moment, before the branch lands. Diff against the merge-base to find what **this
branch** added; never touch inherited entries. One question per file — **does anything
after this branch still need it?**

| The file | Route | Approval |
| --- | --- | --- |
| A convention this repo follows | `CLAUDE.md` / `AGENTS.md` | human approves — public coordination |
| An explanation a person reads | `docs/` | human approves — public coordination |
| A behaviour the code must keep | the test suite | none — an ordinary code change |
| Everything else | delete | none |

**Move, not copy** — a finding sits in one place, never in two drifting ones.
**Most files are deleted, and that is the normal outcome**, not a failure: the
directory exists to hold what is true while the work is in flight, and most of that
becomes false or redundant the day it lands. The terminal state is `.gitkeep` and
nothing else.

The question is *need*, not *truth*, and the difference is load-bearing. A failing
test written to reproduce a defect stops being true the moment the fix lands, and the
behaviour it pins is exactly what the suite must keep.

## The packet — personal and derived

The convergence **packet** (`packets/<slug>.md`) is **not** a committed `.tsugu/`
note. It lives in the **personal global folder**
(`~/.claude/tsugu/<project-key>/packets/<slug>.md`), is **regenerated live at
`converge`** from the prepared branches (`context.md` + the DAG + this machine's
own sources), and is **never pushed**. It is a *derived, personal lens* over the
shared truth — the shared, inheritable truth is the branch (`context.md` +
commits) and `evidence/`. **Machine B needs no packet from machine A:** it
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
> (toward the omni-repo) **only** when what it records affects multiple repos or
> future coordination.

A fact true of one repo stays in that repo's `evidence/`; a fact true across
several repos is promoted to the enclosing omni-repo level. This keeps an
omni-repo from becoming a junk drawer — promotion is a deliberate "this is true
more broadly now" decision, not the default.

## Graduation (relocating a submodule's evidence)

When a bare submodule the omni-repo was managing gets its own `.tsugu/`, the
submodule-specific evidence moves **down** out of the omni `.tsugu/` — the
deliberate inverse of "promote upward." `init` detects the enclosing omni-repo
(`git rev-parse --show-superproject-working-tree` → check that superproject for
`.tsugu/`), scans the omni `evidence/` for entries naming this submodule,
**presents them**, and on **per-entry human confirmation** cuts them down into the
new submodule `evidence/` (move content, remove from meta) — leaving the omni level
holding only genuinely cross-cutting entries.

**Graduation is a repo mutation, not a relabel.** Creating the submodule's
`.tsugu/policy.md` is a new submodule commit; removing the omni entries is a meta
commit; **the omni gitlink must be bumped** to the submodule commit carrying the new
`.tsugu/` — else a fresh checkout stays pinned to a pre-`.tsugu/` SHA, re-classifies
the submodule as bare, and operationally **reverses** graduation. `init` makes these
as ordinary commits per repo (submodule first, then the meta gitlink bump + evidence
removal) and is **re-entrant** (interrupted midway, re-running re-detects remaining
omni entries). No atomic cross-repo transaction is claimed; the human drives any PR.

**In-flight paired branches are left alone** — they finish at meta `converge`; only
new post-graduation work goes native-in-submodule. One guard: when such an in-flight
pair later accepts, its meta gitlink-bump must target the **current submodule default
tip** (which contains both the accepted work and the graduation commit), never a bare
ancestor — the same re-point rule as the two-repo accept, applied across the
graduation boundary.
