# notes-and-packet

The shape and lifecycle of the committed `.tsugu/` notes Tsugu maintains —
`context.md` and `knowledge/` — plus a short note on the **personal/derived**
packet. Placement on the durability gradient (which branch each lives on) is
summarized in `SKILL.md`; this document covers structure and load/lifecycle
semantics. There is **no written branch state** — live coordination facts (in
progress / decided / settled / who's on it / what grew out of what) are derived
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
  questions, next actions, verification, promotion candidates. The branch's story
  is **self-contained** — `## Promotion candidates` points at `knowledge/`, but
  there are no links to per-session files (there are none on the branch).
  Sections: `## Why this ref exists`, `## Current understanding`,
  `## Open questions`, `## Next actions`, `## Verification`,
  `## Promotion candidates`.
- **On the default branch:** the mainline's current situation — what this repo
  is, where the mainline stands, what recently landed. `init` writes the first
  version.

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

**Rewrite on merge-back (`include` mode).** Before the work branch merges,
`converge` rewrites `context.md` into the **ready-to-merge mainline narrative**:
read the default branch's current `context.md` from the fetched ref and integrate
what this work changes. The file that lands on default is **pure desired
content** — there is no state line to clean up afterwards, because "awaiting
merge" lives in the ref namespace (slug pairing), not in the file. If the PR is
instead rejected, the narrative is rewritten again at the next decision —
narrative is maintained freely. Concurrent merges may conflict on `context.md`;
that conflict is meaningful (two narratives to integrate) and is resolved by
rewriting against the then-current default during the freshness rebase.

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

**No prescribed structure.** Agents organize, reorganize, and prune as they judge
(each a `.tsugu/`-only commit). There is no fixed layout and no promotion gate —
smarter future models inherit the freedom, not a frozen taxonomy. It absorbs the
shareable findings a session produces (the underlying transcript is ephemeral and
is not kept).

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
approval`, and `## Suggested accepted branch` (a name/target for the slug-paired
branch `converge` will cut under an Accepted Prefix — **include mode:** same commits
as the work branch, merge it as-is; **exclude mode:** cut fresh from default,
accepted changes applied by path).

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
