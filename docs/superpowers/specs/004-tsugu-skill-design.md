# 004 — Tsugu: a Git-native preparation & convergence skill

## Name — 継ぐ (tsugu)

**Japanese:** 継ぐ · **reading:** つぐ / *tsugu* · **meaning:** to inherit, to
continue, to succeed (to a role), to carry forward.

The name is the intention. Tsugu exists so work is **carried forward** rather than
restarted — across the gap when no human is watching, across the handoff from
agent to human, and across time to whoever (or whatever) resumes it later. The
three senses of 継ぐ map onto the lifecycle:

- **inherit** — a cold-start or *different* agent inherits the work from git +
  `.tsugu/` alone, with no conversation transcript (success criterion #9);
- **continue** — `prepare` continues the work while human attention is absent,
  leaving reversible evidence instead of an empty task description;
- **carry forward** — `settle` carries the prepared, converged work forward into
  clean public form and promotes what is worth keeping.

Git's DAG is the medium of inheritance: a branch is a unit of work one agent hands
to the next, and committed `.tsugu/` notes are the memory that outlives the
session that produced them.

## Goal

Ship a new `tsugu` plugin in the `caasi/dong3` marketplace: a single skill,
driven by a `/tsugu [init|prepare|converge|settle]` slash command, that lets an
agent **prepare work freely and privately using git's DAG as the coordination
substrate**, package the result as evidence a human (or another agent) can pick
up later, and settle the work cleanly.

Tsugu is not an implementation methodology and does not replace workflow skills
(brainstorming, planning, debugging, TDD, code review, branch finishing). It
**prepares their input and settles their output**.

```text
Tsugu prepares the board.
Workflow skills play the game with the human.
Tsugu settles the result.
```

## Core intent (the spine)

**Git itself is the message bus.** An agent runs `git fetch`, sees new/changed
branches and newly committed `.tsugu/` notes, and that *is* the inbox/intake. No
external issue tracker is required — by design, a pure-Tsugu workflow
communicates through git alone.

`.tsugu/` is **committed shared memory** for that coordination, not local
scratch. A branch or worktree is "a message with executable evidence."

External source observation (Jira / GitLab / GitHub issues / CI / CVE) is **not
the spine** — it is an *optional human-bridge*: a shim whose only job is to
convert a human-world signal into the git-native substrate (a committed
`.tsugu/intake/` note, optionally a seed branch). Once converted, every
downstream step is identical. Pure-Tsugu users skip this layer entirely.

A hard constraint follows from "git is the message bus": branch names plus
`.tsugu/intake/` and `.tsugu/branch.md` must be **legible enough that a
cold-start agent which has only run `git fetch` can reconstruct "what branches
exist, why, and what's the next action" with zero conversation transcript.**
git-native intake *depends* on this legibility; it is a design constraint, not a
nice-to-have.

## Non-goals

- Tsugu does **not** define how to debug, plan, test, review, or implement.
- Tsugu does **not** auto-merge or autonomously perform public coordination.
- Tsugu does **not** invoke user-installed workflow skills (see Scope IN #7).
- Tsugu does **not** require or ship adapters for any external tracker.

## Trigger model

Tsugu is **human-triggered and schedule-wireable** (intended as part of a daily
workflow):

- **Human-triggered:** the user runs `/tsugu prepare` (or another routine).
  "Unattended" means the user does not babysit the run — not that the skill
  wakes itself.
- **Schedule-wireable:** the skill ships guidance for wiring `prepare` to
  `/schedule` / cron so a cloud agent can run it on a cadence. The skill does
  not depend on any scheduler.

A SKILL.md is a prompt loaded when an agent is already running; it **cannot
self-wake**. The cadence always comes from an external driver (`/schedule` /
cron), never from Tsugu itself. The skill text must not imply otherwise.

## Scope

### v1 — IN

1. Four-routine lifecycle `init → prepare → converge → settle`, packaged as a
   **single skill** `tsugu` + `/tsugu [init|prepare|converge|settle]`.
2. `.tsugu/` **committed** namespace with a **durability gradient** (ephemeral
   branch-local notes vs durable `intake/` + promoted `context/shared/` on the
   coordination ref, default = default branch).
3. **Private Git space (free) vs public coordination space (approval-gated)**
   boundary, recorded per-repo in `.tsugu/policy.md`.
4. **git-native intake**: `git fetch` → read the queue from remote-tracking refs
   (branch status + `intake/` notes) = work queue. Branch-as-message; the agent's
   own built-in review subagents return branch/worktree artifacts, not prose.
5. **Convergence packet** as the bridge to (human-triggered) workflow skills.
6. **Recursive workspace model**: a single repo and an omni-repo are the same
   abstraction; one agent (+ its built-in subagents) traverses the repo tree,
   working locally or delegating downward and promoting knowledge upward.
7. **No skill orchestration.** Tsugu uses **native git directly** (worktrees via
   `git worktree add`, branch/cleanup via plain git / `gh`) and its **own
   built-in agent capabilities** (Task subagents, the Codex CLI used as a tool,
   Claude's own reasoning). It does **not** invoke **user-installed** workflow
   skills (worktrees, finishing-a-development-branch, review-loop, brainstorming,
   planning, debugging, TDD) — those are **human-triggered and optional**. Rule:
   an agent may freely use built-in/system capabilities; a user-installed skill
   runs only when the human triggers it (or when that skill is itself designed to
   auto-run — which is the skill's prerogative, not Tsugu's to invoke). **Per-repo
   opt-in:** a repo MAY, in its own `.tsugu/policy.md` (never in the shipped
   SKILL.md), list specific user-installed skills Tsugu may use during human-absent
   `prepare` in that repo. The shipped skill stays skill-agnostic; the opt-in is
   repo-local.
8. **Script-light**: no `scripts/` directory in v1. Tsugu = SKILL.md (intent +
   conventions + plain-git recipes) + `templates/` + `references/`; the agent
   runs native git directly.
9. **Multi-agent space reserved** (see "Multi-agent: reserved, not built").
10. Intake **core = self-authored / agent-discovered** notes and pushed
    branches; works with zero external integrations.
11. **Freshness rule** for persistent branches (see "Branch freshness").

### v1 — OUT (deferred / interface-only)

| Item | Disposition |
| --- | --- |
| Peer-agent discovery, atomic claim/locks, concurrent arbitration | v2 (see below) |
| External tracker adapters (Jira / GitLab / GitHub issues / Slack) | Interface stub only in `policy.md`; no adapter built |
| External notification (Slack, etc.) | Deferred |
| Long-lived `research/*` / `experiment/*` **automatic periodic** sync | Deferred — but on-resume rebase freshness IS in v1 (see "Branch freshness") |

### Multi-agent: reserved, not built

The deepest intent — "agents collaborate through git alone; a `fetch` surfaces
many new branches to process" — is honored in v1 at the **discovery** level: a
single agent (+ built-in subagents) can fetch, read branch status, and process
the queue. What v1 deliberately does **not** build is **concurrent arbitration**
(two agents racing for the same branch).

To keep the door open without building arbitration, v1 adds:

1. A **courtesy** `claimed-by:` + `claimed-at:` pair in `branch.md` (convention
   only — no lock, no script). They are **set when an agent begins active work**
   on a branch and **retained as historical state** on settle/pause (never
   auto-cleared). The polite-yield rule: a branch whose `branch.md` has
   `status: open` **and** a non-empty `claimed-by` with a **recent** `claimed-at`
   is treated as taken — another agent skips it; `status: open` with empty
   `claimed-by` (or a stale `claimed-at`) = free to pick up (re-set both on
   pickup). No lock backs this. Recency is the agent's judgment in v1; v2
   formalizes a staleness window.
2. A design rule: **v1 introduces no design that assumes a single agent.** All
   substrate (committed + pushed `.tsugu/`, branch-as-message, distributed
   per-branch status) is forward-compatible with multi-peer coordination.
3. An honest limitation: atomic locking and contention resolution are **not**
   present in v1. Two agents grabbing the same branch simultaneously is
   undefined in v1 (does not arise with a single agent in practice); v2 adds it.

> The heart (git-native discovery + polite yielding + forward-compat) is in v1;
> only the crash barrier (hard concurrency guarantees) is deferred.

### Branch freshness

Persistent branches stay fresh by **rebasing onto the fetched default ref
(`<remote>/<default>`, never a stale local default) on resume** (and optionally
periodically), so a branch paused and resumed weeks later does not drift
(supports success criterion #9):

- Scratch `prepare/*` / `investigate/*` branches: **rebase** onto
  `<remote>/<default>` freely (they are working scratch space). If the branch was
  already pushed, update it with `git push --force-with-lease` (never a plain
  `--force`).
- History-bearing or long-lived branches: **prefer merge** to preserve history.
- **Non-trivial conflicts → stop and ask the human.**

This honors the repo's history-protection conventions (never rewrite shared/
primary history; feature-scratch rebase is fine). Full *automatic periodic* sync
of long-lived `research/*` / `experiment/*` branches remains v2.

## Packaging & file layout

Single skill, script-light, one slash command (closest analogue: `review-loop`).

```text
plugins/tsugu/
  .claude-plugin/plugin.json
  commands/tsugu.md                  # /tsugu [init|prepare|converge|settle]
  skills/tsugu/
    SKILL.md                         # intent + conventions + git recipes + routing
    references/
      git-recipes.md                 # public-branch build, cleanup order,
                                     # fetch→read-queue-from-remote-refs, freshness rebase
      policy-and-intake.md           # policy.md fields + intake interface
                                     # (incl. human-bridge explanation)
      notes-and-packet.md            # branch.md / intake / runs / packets / context structure
    templates/                       # init writes these into the user's repo .tsugu/
      policy.md  branch.md  intake.md  run.md  packet.md
```

No `scripts/` directory. (`review-loop` ships scripts only because Copilot's
GraphQL/REST + jq is genuinely too fiddly to inline; Tsugu's operations — read
the queue, build a public branch, order cleanup, freshness rebase — are plain
git and stay inline as documented recipes. The exception bar: a recipe is
scripted only if proven too error-prone to run inline.)

## The `.tsugu/` namespace & durability gradient

All Tsugu metadata lives under `.tsugu/`. Tsugu writes normal project files only
when performing the actual task; all coordination notes stay under `.tsugu/`.

Placement is the concrete form of the durability gradient — **which branch each
path lives on**:

```text
.tsugu/
  policy.md          ← default branch ALWAYS (curated rules; keeps coordination-ref discoverable)
  templates/         ← default branch ALWAYS (written by init, durable)
  intake/            ← coordination ref, default = default branch (durable shared inbox)
  context/
    shared/          ← coordination ref (only after deliberate promotion; future branches/agents inherit)
    dormant/         ← coordination ref (not loaded by default)
    archived/        ← coordination ref (not searched by default)
  branch.md          ← each work branch (ephemeral, carries status + claimed-by)
  runs/              ← work branch (ephemeral session notes)
  packets/           ← work branch (ephemeral convergence evidence)
```

### Reading the queue (git-native intake)

After `git fetch`, the fresh state lives in **remote-tracking refs**
(`refs/remotes/<remote>/*`) — **not** the local working tree or local branches.
So the queue is read from those refs, never from the checkout:

- Enumerate remote work branches by the configured **work** prefixes from
  `policy.md` — `prepare/*` `investigate/*` `review/*` (`public/*` is a settle
  output, not a queue item): `git branch -r --format='%(refname:short)'`, then
  filter to the configured `<remote>/` and those prefixes. Each kept result is **already a full remote-qualified ref**
  (e.g. `origin/prepare/foo`) — use it **verbatim**; do **not** re-prefix
  `<remote>/` (that double-prefixes).
- Read each branch's context without checkout / dirty tree, using that verbatim
  ref: `git show <branch-ref>:.tsugu/branch.md`.
- **Discover** pending intake note filenames, then read each (resolved against
  the configured `coordination-ref`, default = `<default>`):
  `git ls-tree -r --name-only <remote>/<coordination-ref> -- .tsugu/intake/`,
  **keep only `*.md` paths**, then `git show <remote>/<coordination-ref>:<path>`
  for each — and treat it as a queue item only if it has a `status:` field, so
  seed files (`.gitkeep` / `README`) are ignored.

Claiming an item means opening a `prepare/*` branch whose existence + `branch.md`
becomes the live state. **The branch itself is the message.**

### Writing the inbox & shared context (coordination ref)

Mutable coordination data — `intake/` notes (create + `open → claimed → done`)
and `context/shared/` promotions — lives on a **coordination ref**, set in
`policy.md` as `coordination-ref` (**default: the repo's default branch**).
`policy.md` and `templates/` always live on the default branch itself, so the
coordination ref is always discoverable (no circularity).

A `.tsugu/`-only commit to the coordination ref is **private-space**, not public
coordination — it needs no approval. Write protocol: commit the `.tsugu/` change,
then `git pull --rebase` (or fetch + rebase) and push. **On conflict, re-read the
affected note's current lifecycle state and reconsider before re-applying** —
never blindly overwrite a `claimed` / `done` another agent just wrote (the ref is
append-mostly so conflicts are rare, but a *contended intake note* must be
re-evaluated, not force-resolved).

If the default branch is **push-protected**, point `coordination-ref` at a
dedicated long-lived branch (e.g. `tsugu/coord`); the agent reads and writes
`intake/` + `context/shared/` there and never pushes the protected default. All
queue reads above then resolve against `<remote>/<coordination-ref>` instead of
`<remote>/<default>`. **Bootstrap** such a branch once, **preferring an orphan
branch** that holds only `.tsugu/intake/` + `context/shared/`. (A plain
`git branch <coord> <remote>/<default>` would inherit a full copy of default —
code, `policy.md`, `templates/` — which then goes stale; if used anyway, treat
only the coord branch's `intake/` + `context/shared/` as authoritative and always
read `policy.md` / `templates/` from `<remote>/<default>`, never from coord.)
Since git does not track empty directories, seed those dirs with real files (a
`.gitkeep`, or an initial `README` / intake note) before the first commit, then
push it and set upstream; thereafter the normal commit → `pull --rebase` → push
protocol applies.

**Why this lives in `policy.md`:** in a human-collaborative repo the task **code**
never reaches the default branch by an agent push — it advances only through the
**human-merged PR** (settle step 4, human-gated), where a human reviewer holds the
merge right. The agent only needs a writable home for `.tsugu/` *coordination*
data *without* default-push rights — exactly what `coordination-ref` provides — and
because that right varies per environment, it is a per-repo policy setting.

### Intake-note vs branch.md lifecycle (two layers, no conflict)

Intake notes are **durable** and live on the coordination ref (default: the
default branch) as the inbox. They
carry an **inbox-level** lifecycle distinct from a branch's **work-level** state,
so the two never contradict — they describe different layers:

| Layer | Where | Status field | Records |
| --- | --- | --- | --- |
| Inbox | `intake/<slug>.md` (coordination ref; default = default branch) | `open → claimed → done \| dropped` | *that* work entered the inbox and where it went |
| Work | `branch.md` (work branch) | `open \| paused \| converged \| settled` | the *live* work context |

A "new" intake item for the queue = a note with `status: open` and no linked
branch. When an agent opens a branch for it, the note flips to `claimed` (with a
breadcrumb to the `prepare/*` branch); `settle` flips it to `done` / `dropped`.

The clean **public** branch for an actual MR/PR is **cut fresh from the default
branch**, and only the accepted code/test/doc/config is applied to it **by path**.
The default branch already carries the fixed `.tsugu/` metadata (`policy.md`,
`templates/`; plus `intake/` + `context/shared/` when `coordination-ref` = default),
and that stays as-is — the precise guarantee is that **the public branch's diff vs
the default branch introduces no `.tsugu/` changes** (no work-branch-only `branch.md` /
`runs/` / `packets/` ever land in the reviewed diff). (Detailed git commands live
in `references/git-recipes.md`.) Committing `.tsugu/` is the norm on work branches;
transparency is a feature, not a leak.

### Context placement rule

Write context at the **lowest repo level where it remains true**. Promote upward
(toward the omni-repo) only when the knowledge affects multiple repos or future
coordination. This keeps an omni-repo from becoming a junk drawer.

## The four routines

### `init`

Runs when a repo has no `.tsugu/`. Captures the **minimum** human preferences
needed for safe unattended preparation — ask only a few questions:

- May agents create / commit / push preparation branches automatically?
- Which public actions require approval? (default: MR/PR, tracker comment, tracker
  status change, reviewer assignment, Slack, public commitments)
- Branch prefixes? (default: `prepare/*` `investigate/*` `review/*` `public/*`)
- Recurse into submodules? (default: only when relevant to the current goal /
  intake / branch)
- Intake sources? (**default: none** — git-native only)

Then write the `.tsugu/` skeleton + `policy.md` from the plugin templates. Because
git does not track empty directories, seed each created directory with a real
file (`.gitkeep` or an initial note). The fixed metadata (`policy.md`,
`templates/`) must reach the **default branch**: if it is push-protected, `init`
writes them on an `init/*` branch and opens a **human-approved PR** to land them,
and `prepare` does not run in that repo until the metadata is merged (so
`policy.md` / `coordination-ref` are resolvable).

**Idempotency:** re-running `init` on an already-initialized repo **repairs** any
missing skeleton paths and is otherwise a no-op; it **never overwrites** a
curated `policy.md`.

**Progressive:** when a new situation appears later, ask once, record the rule in
`policy.md`, and let future agents inherit it.

If appropriate, add a short pointer to `CLAUDE.md` / `AGENTS.md`:
`This repo uses Tsugu. Read .tsugu/policy.md before unattended preparation.`

### `prepare` (human absent)

The core routine. `prepare` **does not schedule itself** — a SKILL.md cannot
self-wake (see Trigger model); a human wires its cadence via `/schedule`. When it
runs, no human is present, so Tsugu does its own git work directly and may
dispatch its **own built-in subagents** — but it invokes **no user-installed
skill**.

1. **Resolve `<remote>` + `<default>`, then `git fetch <remote>` first.** Bootstrap
   the circular dependency: begin with `origin` (or the local checkout's
   `policy.md`) for the first fetch; if the fetched `policy.md` names a different
   `remote`, re-fetch from it. Resolve `<default>` from `<remote>/HEAD`
   (`git symbolic-ref refs/remotes/<remote>/HEAD`; `git remote set-head <remote>
   --auto` if unset) or an explicit `default-branch` policy field. Fetching first
   means every `<remote>/…` ref below uses fresh remote-tracking refs, not a
   stale checkout; multi-remote repos stay unambiguous.
2. Read policy + guidance from the **fetched default ref** (not the checkout):
   `git show <remote>/<default>:.tsugu/policy.md` (plus `CLAUDE.md` / `AGENTS.md`
   if present). This yields the configured prefixes and `coordination-ref`.
3. **Read the queue from remote-tracking refs** (see §Reading the queue), and
   read `context/shared/` from `<remote>/<coordination-ref>` (when
   `coordination-ref` ≠ the default branch, branches cut from default won't
   contain it, so it must be read explicitly). Partition the work by
   `branch.md status` + `claimed-by`:

   | status | claimed-by | disposition |
   | --- | --- | --- |
   | `open` | empty | **pick up** |
   | `open` | non-empty, recent | **yield** (taken) |
   | `paused` | — | **resume candidate** (rebase onto default first — see Branch freshness) |
   | `converged` | — | skip (awaiting human) |
   | `settled` | — | skip (done) |

   Plus `intake/` notes with `status: open` and no linked branch = unbranched
   work to consider.
4. For chosen work: open `prepare/*` / `investigate/*` branches or worktrees
   **with native git** (`git worktree add`); reproduce, inspect, run tests, try
   reversible patches.
5. Dispatch your **own review subagents** (built-in Task agents — **not** the
   user-installed `review-loop` skill) when a change benefits from a second pass
   before the human sees it; they return `review/*` branch/worktree artifacts,
   not prose-only reports. This is Tsugu working in private git space, and is
   distinct from the human-triggered `review-loop`.
6. Write `runs/` notes; maintain `branch.md` (incl. `status`, and set
   `claimed-by` + `claimed-at` when you begin active work — see Multi-agent);
   create/update the convergence **packet**.

Posture: **external silence, internal preparation.** Only interrupt the human if
the task is unsafe, destructive, or blocked. When unsure, continue with
reversible private git work.

### `converge` (human present)

The human-attention phase. **Tsugu presents and yields — it invokes no skill
here.** The human triggers the skill they want by keyword ("let's brainstorm
this", "debug it", "/review-loop"); the skill ecosystem takes over.

1. Lay out the relevant packet, prepared branches/worktrees, and a summary of
   what was tried / worked / failed / evidence / remaining uncertainties.
2. Surface open questions and decisions for the human.
3. Decide *with* the human which prepared changes become public.
4. Wait for approval before any public coordination action.
5. Once the human has reviewed and decided a disposition (before `settle` runs),
   set the branch's `branch.md status: converged` — this is the transition that
   writes the `converged` state the prepare partition table skips.

The packet may **hint** which workflow skill fits ("this is ready for planning /
this bug needs debugging / this can go to review-loop") but must not fire it.

### `settle`

Three outcomes. Each first writes the terminal `branch.md status` — **Accepted**
and **Rejected** → `settled`, **Paused** → `paused` — before retaining or deleting
the work branch. In **Accepted**, ⚙ = agent-mechanical (private git), 🔒 =
human-triggered/approved:

**Accepted:**
1. ⚙ Cut a clean `public/*` branch fresh from the **fetched `<remote>/<default>`
   ref** (not a stale local default).
2. ⚙ Apply only accepted code/test/doc/config **by path** (so the public branch's
   diff vs default introduces no `.tsugu/` changes).
3. ⚙ Verify (build / tests).
4. 🔒 Opening the PR is human-triggered/approved — the human may use
   `finishing-a-development-branch` / `review-loop`; **Tsugu does not invoke
   them**.
5. ⚙ Promote reusable knowledge to `.tsugu/context/shared/` (commit to the
   coordination ref).
6. ⚙ Clean up worktrees, then review branches.

**Rejected:** record why if it may matter later; archive or delete the packet per
policy; remove temporary worktrees; delete rejected review branches when safe;
promote only important failure reasons.

**Paused:** set `branch.md` `status: paused`; update the packet; write a run note;
list what is needed to resume; leave the branch resumable (it will **rebase onto
default on resume** — see Branch freshness).

Cleanup order (always): `git worktree remove <path>` **before** `git branch -D
<branch>`. Never delete a branch still checked out by a worktree.

## Private vs public boundary & skill use

The boundary, recorded in `policy.md`:

```text
Git branch / pushed branch / .tsugu notes  →  agent may do freely
MR / PR / tracker / Slack / reviewer assignment  →  human approval required
```

**Skill use** (a first-class principle): Tsugu uses native git and its own
built-in capabilities directly and invokes **no user-installed skill** — whether
the human is present or not. The only asymmetry is *what Tsugu does on its own*:

- **Human absent (`prepare`, mechanical parts of `settle`):** Tsugu works the git
  tree and dispatches its own built-in subagents.
- **Human present (`converge`, coordination parts of `settle`):** Tsugu presents
  and yields; the human triggers workflow skills by keyword.

(Built-in/system capabilities — Task subagents, Codex-as-a-tool, Claude's own
reasoning — the agent may use freely. A user-installed skill that is itself
designed to auto-run is that skill's prerogative, not Tsugu's to trigger.)

**Per-repo opt-in (config, not shipped behavior):** the shipped `SKILL.md` names
no user-installed skill. A repo owner MAY, in that repo's `.tsugu/policy.md`, opt
Tsugu into specific user-installed skills for that repo; Tsugu may then use the
opted-in skills during human-absent `prepare`. This keeps the shipped skill
universal while letting a repo extend it locally — the skill list lives in
repo-local config, never in `SKILL.md`.

## Templates (shipped in the plugin, written into the repo by `init`)

```md
# policy.md
## Private Git Space (agent may do freely)
create/commit/push prepare·investigate·review branches; worktrees; write .tsugu/*;
run tests; try reversible patches; dispatch own (built-in) review subagents
## Public Coordination (ask first)
open MR/PR; tracker comment / status change; assign reviewers; Slack; public
commitments; move findings into human-facing docs; irreversible cleanup
## Branch Prefixes
prepare/*  investigate/*  review/*  public/*
## Remote
remote: origin                   # authoritative remote for fetch + branch enumeration (multi-remote safety)
default-branch:                  # optional; if blank, resolved from <remote>/HEAD
## Coordination ref
coordination-ref: default        # where intake/ + context/shared/ are written;
# set to a branch (e.g. tsugu/coord) if the default branch is push-protected
## Intake Sources
default: none (git-native only). Add human-bridge sources here only if needed
(e.g. gh issues, CI).
## Skill use
Tsugu invokes no user-installed skill by default; it uses native git + its own
built-in capabilities. Humans trigger workflow skills (planning, review-loop, …)
by keyword.
## Skills Tsugu may use (this repo, opt-in)
default: none. List user-installed skills Tsugu may use during human-absent
prepare in THIS repo (e.g. systematic-debugging). Repo-local only — the shipped
SKILL.md never names skills.
## Recursion
Recurse into submodules / child repos only when relevant to the current goal /
intake / branch.
```

```md
# branch.md          (work-level live state; ephemeral, on the work branch)
status: open          # open | paused | converged | settled
claimed-by:           # courtesy only (no lock); set when active work begins, kept as history
claimed-at:           # ISO timestamp paired with claimed-by; lets a stale claim be reclaimed
## Why this branch exists
## Current understanding
## Open questions
## Next actions
## Verification
## Promotion candidates
```

```md
# intake.md          (inbox-level record; durable, on the coordination ref — default = default branch — intake/<slug>.md)
status: open          # open | claimed | done | dropped
linked-branch:        # breadcrumb set when status → claimed
## Observed source    (git-native self-note / agent-discovered / human-bridge: <ref>)
## Summary
## Related repos
## Initial guess
## Need human context
```

```md
# run.md             (runs/<date-time>.md)
## Goal
## Context read
## Actions taken
## Branches touched
## Verification
## Follow-up
## Need human context
## Promotion candidates
```

```md
# packet.md          (packets/<work-slug>.md)
## Intake source
## Branches prepared
## What was tried
## What worked
## What failed
## Evidence
## Relevant files
## Test results
## Remaining uncertainties
## Need human decisions
## Candidate next plans          # hints which workflow skill fits — does not fire it
## Public actions requiring approval
## Suggested public branch        # name/target for the to-be-cut-fresh branch (see settle), not "push this branch as-is"
```

## Design principles

1. Git is the source of truth; git is the message bus.
2. Every git repo can be a Tsugu workspace; the model is recursive across
   submodules and child repos.
3. Tsugu metadata lives under `.tsugu/` and is committed.
4. Branches are work contexts; a branch/worktree is a message with executable
   evidence.
5. Preparation branches may be messy; public branches are cut clean from the
   default branch (so the public diff vs default introduces no `.tsugu/` changes
   — never introduced, not stripped after).
6. The coordination ref holds shared knowledge only when intentionally promoted
   (coordination ref = default branch by default).
7. Context starts at the lowest level where it is true; promote only reusable
   knowledge upward.
8. Agents work freely in private git space; public coordination requires approval.
9. **Tsugu invokes no user-installed skill by default** — it uses native git +
   its own built-in capabilities. Human present → present and yield; human absent
   → work the tree directly. Other workflow skills are human-triggered and
   optional. A repo's `.tsugu/policy.md` (never the shipped SKILL.md) may opt-in
   to named skills locally.
10. Tsugu prepares evidence for workflow skills; it does not replace engineering
    methodology.
11. Human attention is spent on convergence, not cold-start investigation.
12. Prefer branch/worktree artifacts over prose-only claims.
13. Keep schemas light; Markdown for human-readable context; structured formats
    only when machine-maintained and easy to validate.
14. Initialize progressively: ask once, record the rule, let future agents
    inherit it.
15. Keep the lifecycle small: init, prepare, converge, settle.
16. **v1 introduces no design that assumes a single agent**; the substrate is
    forward-compatible with multi-peer coordination (which v1 does not build).
17. External tracker observation is an optional human-bridge, never the spine.
18. A cold-start agent must reconstruct branch intent and next action from git +
    `.tsugu/` alone (read from remote-tracking refs), with zero transcript.
19. Persistent branches stay fresh by rebasing onto the default branch on resume;
    scratch branches rebase freely, history-bearing branches prefer merge,
    non-trivial conflicts stop for the human.

## Success criteria (v1)

1. An agent can `init` a repo with minimal human input (idempotent re-init).
2. The default loop runs with **zero external integrations** (git-native intake).
3. The agent can prepare private git branches, commits, and evidence, and push
   them without creating public-coordination noise.
4. Tsugu metadata stays contained under `.tsugu/`.
5. A human returning later can review a concise convergence packet instead of
   cold-starting.
6. Existing workflow skills can use the packet as input, **triggered by the
   human** — Tsugu invokes none of them.
7. A clean public branch is cut fresh from the default branch so its diff vs
   default introduces no `.tsugu/` changes.
8. Reusable knowledge can be promoted into shared context.
9. A **different agent** (sequential handoff, not concurrent) can resume the work
   days/weeks later from git +
   `.tsugu/` alone (read via remote-tracking refs), without the original
   conversation transcript; the resumed branch rebases onto default to stay fresh.
10. The same v1 works unchanged in both a single repo and an omni-repo.
11. Multiple agents running together can see each other's `claimed-by` and yield
    politely (no hard guarantee; arbitration is v2).

## Deferred to v2

- Peer-agent discovery and atomic claim/lock with concurrent arbitration.
- External tracker / Slack adapters.
- Long-lived `research/*` / `experiment/*` **automatic periodic** sync (on-resume
  rebase freshness is already in v1).
