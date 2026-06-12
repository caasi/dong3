# policy-and-intake

`.tsugu/policy.md` records the per-repo **shared** rules a cold-start agent reads
before any unattended preparation. It lives on the **default branch always** (so
the coordination ref it points to stays discoverable — no circularity), and it
carries **only sections that transfer to any inheritor** — a coworker's agent, a
different machine. Anything tied to *one* human's sources, tools, or moment is
**personal config**, kept in a global folder, never committed (see the last
section). This document gives the one-line semantics of every shared field, then
the personal-config pointer.

## `policy.md` fields (shared — committed)

### `tsugu-schema:`

The schema-version stamp (current: `3`). It is the first line of the file, and a
migration **writes it last** — only after every N→N+1 rename and semantic change
has been applied does `init` stamp the new number, so a half-applied migration is
never mistaken for a completed one. Readers use it to decide whether a re-run of
`init` must migrate (older stamp → apply `references/migrations.md` in order,
1→2→3 for a schema-1 repo) or is a plain idempotent repair (stamp already
current).

### Private / Public boundary

The whole point of the file: where the agent may act freely vs where it must ask.

- **`## Private Git Space (agent may do freely)`** — actions the agent performs
  without approval: create/commit (push per `## Push`'s `push-prepare-branches:`)
  `prepare/*` / `investigate/*` / `review/*` branches, worktrees, write `.tsugu/*`,
  run tests, try reversible patches, dispatch its own built-in review subagents.
  All of this is git-local and reversible.
- **`## Public Coordination (ask first)`** — actions requiring human approval:
  open MR/PR, tracker comment / status change, assign reviewers, Slack, public
  commitments, moving findings into human-facing docs, irreversible cleanup.

The boundary in one line:

```text
Git branch / pushed branch / committed .tsugu/    →  agent may do freely
MR / PR / tracker / Slack / reviewer assignment   →  human approval required
```

### `## Branch Prefixes`

The **work** namespaces the queue is built from. Default `prepare/*` — these are
queue items: branches the partition reads and classifies. They must be **DISJOINT
from `## Accepted Prefixes`** — `init` and migration validate this — because the
partition pairs a work branch against an accepted branch by **shared slug**, and
an overlapping prefix would make a branch both a queue item and its own accepted
branch.

### `## Accepted Prefixes`

The **human-workflow** namespaces a converge cut hands work into for a PR.
Default `feature/* bugfix/* chore/*`. An accepted branch is **not** a queue item;
it exists so the partition can read one ref-level fact: an accepted branch whose
**slug pairs** a work branch's slug means **that work is decided, awaiting
merge** — skip it as a candidate, surface it in converge's awaiting-merge section.
The pairing is by **name, not commits**, so it survives whatever the forge does to
commits (PR-branch rebases, squashes, force-pushes). Must be disjoint from
`## Branch Prefixes`.

### `## Push`

```md
## Push
push-prepare-branches: yes
```

`push-prepare-branches:` records the answer `init` captured to "may agents
create/commit/push preparation branches automatically?" Pushing is what makes a
branch a **message**: the human's `converge` and the next scheduled agent both
read remote-tracking refs, so a pushed branch is a cross-machine handoff. The
default is **`yes`**. Answer `no` to keep work local — `prepare` then commits
locally and stops for approval (single-machine by nature: the human and the next
run share one clone). When the `## Push` section is **absent** (a repo
initialized before this field existed), readers default to `yes`.

### `## Public branch`

```md
## Public branch
public-branch-tsugu: include
```

Controls whether the committed **WIP-knowledge layer** reaches the default branch.
Two values, default **`include`**:

- **`include` (default):** the work branch **is** what merges — directly (solo
  flow) or via a slug-paired accepted branch. Merging lands the work branch's
  **prep commit DAG plus its `context.md` narrative** on the default branch as
  committed WIP knowledge; there is no by-path filtering and no separate
  evidence-landing step. The trade-off, stated openly: mainline history carries
  the agent's preparation commits and `context.md` — and in the agent-first
  orientation that history *is* the memory.
- **`exclude` (opt-out):** cut a **fresh** public branch from the fetched default
  (accepted-named, same slug) and apply accepted changes **by path**, so the public
  diff introduces **no** `.tsugu/` changes (the guarantee is "never introduced",
  not "stripped afterward"). For collaborative repos where human reviewers should
  not see coordination metadata in the PR. Landing is then confirmed via the
  **public branch's** containment, not the work branch's (by-path application breaks
  the work branch's own containment).

**`knowledge/` lands on the coordination ref regardless of mode** — it is the
team's shared brain in both `include` and `exclude`; the field governs only the
WIP layer (`context.md` + prep DAG), not `knowledge/`.

### `## Merge method`

Tsugu **prefers merge commits — do not squash-merge tsugu-managed branches.**
Preserved history is what makes settlement, lineage, and evidence derivable from
the DAG by containment. **Non-containment landings** (a forced squash,
rebase-before-merge, or force-push of the accepted branch) rewrite history so the
work tip is never contained in default — that heavier path lives in
`references/advanced.md`.

For the **`exclude`-mode** retain case: the repo **should disable the forge's
auto-delete-head-branch for tsugu accepted branches**, so the slug pairing
survives the merge and carries the "awaiting merge" state until the human's
completion tail deletes both branches. This is a recommendation, not a hard gate.

### `## Housekeeping`

```md
## Housekeeping
<!-- stale-after: 30 days -->
```

`stale-after:` is the age threshold past which an **in-progress** branch is
**surfaced for cleanup**. It ships **commented** — `converge` records the
threshold here progressively on first use (ask once), so it reflects a real
decision rather than a hardcoded guess. Staleness itself is **derived**, never
written: a branch is stale when its last commit is older than `stale-after`.
Surfacing is for **human-decided cleanup** — the list of over-threshold branches
is shown at `converge` for a person to act on. **A scheduled `prepare` never
cleans up** on its own.

### `remote:`

The authoritative remote for `git fetch` and branch enumeration. Default
`origin`. Stated explicitly for **multi-remote safety** — so `<remote>/…` refs are
unambiguous regardless of which remote the local checkout tracks.

### `default-branch:`

Optional override for `<default>`. If blank, `<default>` is resolved from
`<remote>/HEAD` (`git symbolic-ref refs/remotes/<remote>/HEAD`). Set it only when
`<remote>/HEAD` is unreliable or the repo's default is non-obvious.

### `coordination-ref:`

The ref where the promoted `knowledge/` wiki is written. **Default: `default`** (a
sentinel meaning "the repo's default branch" — it resolves to `<default>`, not a
branch literally named `default`). Point it at a dedicated branch (e.g.
`tsugu/coord`, ideally an orphan) when the default branch is **push-protected** —
the agent needs a writable home for `.tsugu/knowledge/`, but in a human-
collaborative repo the task **code** only ever reaches default through a human-
merged PR, not an agent push. That right varies per environment, which is why it
is a per-repo policy field. (There is no longer an `intake/` inbox at this ref —
schema 3 has no committed note layer.)

### `## Skill use`

States the shipped invariant: **Tsugu invokes no user-installed skill by
default** — it uses native git plus its own built-in capabilities (Task subagents,
Codex-as-a-tool, Claude's own reasoning). Humans trigger workflow skills
(planning, debugging, review-loop, …) by keyword. This text reflects the shipped
behavior and is the same in every repo — it is the *shipped invariant*, so it
stays shared. Only the per-machine **opt-in list** of skills a human trusts here
is personal (see below); the shipped skill never names a skill.

### `## Recursion`

Whether to recurse into submodules / child repos. Default: **only when relevant to
the current goal / branch.** Keeps an omni-repo traversal scoped instead of
descending into every nested repo unconditionally.

## Personal config (not in the repo)

Two things tsugu needs to operate are tied to *one* human's setup, not the team's
coordination, so they are **never committed**: observation **sources** (private
paths/filters/feeds — *how & what I observe*) and **opt-in skills** (depends on
*my* installed set and *my* trust). They live in a global, project-keyed file:

```text
~/.claude/tsugu/<project-key>/config.md
```

- **`<project-key>`** is the repo's **absolute common git dir with a trailing
  `/.git` removed**, dashified — derive it from `git rev-parse
  --path-format=absolute --git-common-dir`, strip a trailing `/.git`, then dashify
  (normalize to an absolute path first; `--git-common-dir` alone returns a bare
  `.git` in the main checkout but an absolute path in a linked worktree, so
  normalize *before*
  dashifying, else the store splits). Keying on the common git dir — not the
  checkout path — means **every worktree of one repo shares one folder per
  machine**. The key is per-machine-per-human; it need not be portable, only one
  key per repo per machine.
- **Two sections:** `## Intake Sources` (observation config) and `## Skills
  (opt-in)`. Neither has any repo footprint — nothing under the working tree, so
  nothing to `.gitignore` and nothing to commit by accident.

### Bootstrap (per-machine, ask once)

The personal folder does not transfer across machines, so each machine seeds its
own. When a section is absent **and** the run is **interactive** (a `prepare` or
`converge`), the routine asks **once**, separately for the two sections:

- **sources** — *"Any observation sources to read besides git? A file path, MCP
  tool name, or where to look — I resolve the `read:` pointer with my own
  permissioned tools, never auto-executing it from config."*
- **skills** — *"Any user-installed skills you trust me to use here during
  human-absent `prepare`? (default: none.)"*

A **negative answer is recorded as a confirmed-negative marker** — `sources:
git-native (confirmed)` / `skills: none (confirmed)` — so it is **never re-asked**;
an unset section is distinct from a confirmed-empty one. When **headless/
non-interactive**, never block on the question: fall back to git-native (no
sources, no opt-in skills) and surface "personal config unconfigured on this
machine" at the next `converge`.

### Resolving a source `read:` pointer (the no-force principle)

Each configured source is a **name**, **one `read:` pointer** (a file path, an MCP
tool name, or a description of where to look), and a **`notes:` interpretation
hint**. On each run the agent **resolves** the pointer with its own **permissioned,
interceptable tools** — it reads the file, calls the MCP tool, or — only where a
source genuinely needs a command — issues it as **its own gated tool call**, which
the harness's permission layer can prompt on, gate, or block. **Tsugu never
directly executes the pointer string** committed-or-not; this is the no-force
principle (a `read:` that the system auto-executed would be remote code execution
in any repo others can write — exactly why this config is personal, not committed).
Prefer file paths and MCP tools; reserve commands for trusted setups. Sources are
not limited to task systems — an RSS feed, a YARA/CVE watch, a CI status query all
fit the same shape.

A source signal becomes a **`prepare/<slug>` branch directly** — there is no
committed intake note first. Downstream every step is identical regardless of
where the signal came from; the queue read, the partition, and the routines
operate only on git.

### Source dedup (weakened, accepted)

With no committed note layer, **dedup is by live ref existence only**: an in-flight
item is deduped because a live `prepare/<slug>` branch with that slug is found. But
a source item whose work already **landed and whose branches were deleted** leaves
no ref — so if the external source still lists it, the next `prepare` may re-import
it as a fresh `prepare/<slug>`. This is **accepted**: the re-imported item surfaces
at `converge` as an ordinary candidate and the human drops it. **No committed
ledger is reintroduced** — that would be exactly the derived state schema 3
removes; `converge` is the human's interception point. Re-opened source items
remain out of scope.
