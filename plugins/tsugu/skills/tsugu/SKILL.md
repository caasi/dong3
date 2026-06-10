---
name: tsugu
description: Git-native preparation & convergence — carry work forward across the gap when no human is watching, the handoff to a human, and the resume by whoever comes next. Use to prepare work before review, then converge it with the human, or run the lifecycle via `/tsugu:init`, `/tsugu:prepare`, `/tsugu:converge`. Triggers on "prepare work before review", "carry work forward", "git-native preparation", "init/prepare/converge", or "/tsugu". Human-triggered and schedule-wireable (wire `prepare` to `/schedule`/cron). Invokes no user-installed skill by default — native git + its own built-in subagents only. Never auto-merges and never performs public coordination without approval.
---

# Tsugu — 継ぐ (prepare & converge over git)

## 継ぐ (tsugu)

**継ぐ** · つぐ / *tsugu* · to **inherit**, **continue**, **carry forward** (succeed to a role). The name is the intent: work is carried forward rather than restarted —

- **inherit** — a cold-start or *different* agent inherits the work from git + `.tsugu/` alone, with no conversation transcript;
- **continue** — `prepare` continues the work while human attention is absent, leaving reversible evidence instead of an empty task description;
- **carry forward** — `converge` carries the prepared work into clean public form *with the human present* and promotes what is worth keeping.

**Git's DAG is the medium of inheritance.** A branch is a unit of work one agent hands to the next; committed `.tsugu/` notes are the memory that outlives the session that produced them.

**In one line:** Tsugu **guides agents to cooperate with each other through git**, and **helps the human come back to prepared work**. It *guides* — it never forces: the agent decides and acts through its own tools; Tsugu only prepares the ground (see the no-force principle in the spine).

Tsugu prepares the board. Workflow skills play the game with the human. Tsugu converges the result. It is **not** an implementation methodology — it does not define *how* to debug, plan, write tests, review, or implement; it prepares their input and converges their output. (It still *runs* builds/tests as evidence during `prepare`/`converge` — it just doesn't own the testing or debugging method.)

## The spine

**Git itself is the message bus.** `git fetch` surfaces new/changed branches and newly committed `.tsugu/` notes — that *is* the inbox. A pure-Tsugu workflow coordinates through git alone, with zero external integrations.

- **`.tsugu/` is committed shared memory**, not local scratch. A branch or worktree is "a message with executable evidence."
- **Tsugu never executes `.tsugu/` content — it offers data and trusts the agent.** Everything in `.tsugu/` (policy, notes, intake `read:` pointers, recipes, committed repro scripts) is data and guidance for an agent, never a string the system `eval`s. Tsugu forces nothing: it prepares the ground; the agent decides and acts through its own **permissioned, interceptable tools** — read a file, call an MCP tool, or issue a command as its own gated tool call. The agent's judgment governs, and the harness's security layer intercepts anything script-like, so content committed to `.tsugu/` is never a remote-execution vector.
- **External tracker observation is an OPTIONAL human-bridge, never the spine.** Jira / GitLab / GitHub issues / CI / CVE feeds are a shim whose only job is to convert a human-world signal into the git-native substrate (a committed `.tsugu/intake/` note, optionally a seed branch). Once converted, every downstream step is identical. Pure-Tsugu users skip this layer entirely.
- **Legibility is a hard constraint:** branch names + `.tsugu/intake/` + per-ref `context.md` must let an agent that has only run `git fetch` reconstruct "what branches exist, why, and what's next" with no transcript. git-native intake depends on it.

### The orientation principle

The end state Tsugu serves is **agents coordinating through git, with humans assisting** — not agents producing artifacts for human-centric review flows. `.tsugu/` notes are the agents' shared memory; hiding them from public branches optimizes for human reviewers at the cost of agent legibility. Agent legibility is the default; the human-reviewer posture is a per-repo opt-out (`public-branch-tsugu: exclude`).

One principle governs all the state-model rules below:

> **Refs and the DAG carry every fact the partition reads; text carries narrative for minds and write-once records.** Live coordination state — in progress / decided / landed / who's on it / what grew out of what — is derived from ref names, ancestry, containment, and commit authorship and recency, never written into files. Files hold two things only: **narrative** (maintained freely; it informs judgment, never classification) and **write-once records** (run notes, packets, intake terminal fields). A fact is recorded **only when an operation severs the DAG's ability to answer it, at the moment it stops being derivable** — never before, never mutated after.

### The slug is the join key

Every piece of one work item shares one slug: the work branch (`prepare/<slug>`), the intake note (`intake/<slug>.md`), the packet, the run notes, and — when one exists — the handoff branch (`<handoff-prefix>/<slug>`). Names are write-once identity (Tsugu never renames a branch), so name-level joins survive everything that rewrites commits. **One slug = one work item:** same-slug branches under *different work prefixes* (e.g. a `review/<slug>` artifact from a built-in review subagent) are that item's artifacts — they share its lifecycle and are swept by its completion tail. Work prefixes and handoff prefixes must be **disjoint** sets; `init` and migration validate this.

## Routing

`/tsugu:init` · `/tsugu:prepare` · `/tsugu:converge` — one lifecycle, three routines:

- **init** — first-run setup (or schema migration on re-run); ask the minimum, write the `.tsugu/` skeleton + policy.
- **prepare** — human-absent: read the queue from git, work it privately, leave evidence.
- **converge** — human-present: present the packet, decide together, and complete the disposition in-session.

Mechanics are deferred — do not re-derive git commands here:

- Exact git (fetch → read-queue-from-remote-refs, containment + slug-pairing partition, coordination-ref writes, handoff-branch cut, include-mode merge-back, exclude-mode clean-cut, freshness rebase, completion tail, cleanup order, init skeleton) → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/git-recipes.md`.
- `policy.md` fields + intake interface (incl. the human-bridge, `landed:`, reconciliation) → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/policy-and-intake.md`.
- `context.md` / `intake` / `runs` / `packet` / `knowledge` structure → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/notes-and-packet.md`.
- `init` re-run migration steps (schema N→N+1) → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/migrations.md`.
- `init` writes the repo's `.tsugu/` files from `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/templates/`.

## The three routines

### `init`

Runs when a repo has no `.tsugu/`, or re-runs to repair or migrate an existing one. Capture the **minimum** preferences for safe unattended prep — ask only a few: may agents create/commit/push prep branches automatically (**default: yes** — pushing makes the branch a message the next machine reads)? which public actions need approval (default: MR/PR, tracker comment/status, reviewer assignment, Slack, public commitments)? branch prefixes (default work-only `prepare/* investigate/* review/*`)? handoff prefixes for PRs (default `feat/* fix/*`)? should the default branch carry `.tsugu/` (`public-branch-tsugu: include|exclude`, **default `include`**)? recurse into submodules (default: only when relevant)? intake sources (**default: none** — git-native only)?

Then write the `.tsugu/` skeleton + `policy.md` from the plugin templates (seed each empty dir with a real file — git can't track empty directories). **Stamp `tsugu-schema: 2`** as the first line of a fresh `policy.md`.

**Validate prefix-disjointness.** The work prefixes (`## Branch Prefixes`) and the handoff prefixes (`## Handoff Prefixes`) must be **disjoint sets** — the partition pairs a work branch against a handoff branch by shared slug, so an overlapping prefix would make a branch both a queue item and its own handoff. `init` (and migration) refuse to write overlapping sets and ask the human to resolve.

**Re-run decision** — read `policy.md`'s `tsugu-schema:` stamp and pick one of three:

1. **No `.tsugu/`** → fresh init (write skeleton + policy + templates), stamped with the current schema.
2. **`.tsugu/` present, stamp == current** → **idempotent repair** only: fill any missing skeleton path, otherwise a no-op. It **never overwrites** a curated `policy.md`.
3. **`.tsugu/` present, stamp older** → **migrate**: apply `references/migrations.md` steps in order (N→N+1 until current), then update the stamp **last** and commit (message names the range, e.g. `chore(tsugu): migrate .tsugu/ schema 1→2`). Migrations add/restructure schema parts only, never overwrite curated content; an interrupted migration re-enters safely (stamp written last).

- **Progressive:** when a new situation appears, ask once, record the rule in `policy.md`, let future agents inherit it.
- **Push-protected default:** the fixed metadata (`policy.md`, `templates/`) must reach the default branch; if it is push-protected, write on an `init/*` branch and open a **human-approved PR**. `prepare` does not run in that repo until the metadata is merged. The same applies to a migration: it rides an `init/*` branch + PR; the `tsugu-schema` stamp rides the policy PR as the **last** write, and that PR merges only **after** the `knowledge/` rename is confirmed on the coordination ref (same PR when `coordination-ref=default`; the separate coord branch is renamed first otherwise) — never a "complete" stamp over a half-applied rename.

### `prepare` (human absent)

The core routine. No human is present, so Tsugu does its own git work directly and may dispatch its **own built-in Task subagents** — but it invokes **no user-installed skill**. Posture: **external silence, internal preparation.** Interrupt the human only if the task is unsafe, destructive, or blocked; when unsure, continue with reversible private git work.

`prepare` **does NOT self-wake** — a SKILL.md is a prompt loaded into a running agent and cannot schedule itself. Cadence always comes from an external `/schedule`/cron driver.

1. **Fetch first** (`git fetch --prune <remote>`), resolving `<remote>` + `<default>`, so every read below uses fresh remote-tracking refs, not a stale checkout.
2. Read `policy.md` + guidance from the **fetched default ref** (yields the work + `## Handoff Prefixes`, `## Push`, `public-branch-tsugu`, `coordination-ref`, `stale-after`, among others).
3. **Read the queue from remote-tracking refs**, plus `knowledge/` from the coordination ref, plus `intake/` notes (an **`open`** note with no linked branch = unbranched work to consider; a **`claimed`** note whose linked branch has vanished is a **reconciliation case** for `converge`, never auto-resumed by a scheduled `prepare`).

   **Partition each work branch `<work-prefix>/<slug>` by two ref-level facts, checked in order** — there is **no written branch state**:

   | Fact | State | Disposition |
   | --- | --- | --- |
   | tip contained in `<remote>/<default>` (in `exclude` mode: the slug-paired public branch's tip, since by-path application breaks the work branch's own containment) — or its intake note records a valid `landed:` | **settled** — the work landed | skip; completion-tail / cleanup candidate |
   | a branch with the **same slug** exists under a configured `## Handoff Prefixes` | **decided, awaiting merge** | skip as a candidate; shown in `converge`'s awaiting-merge section |
   | neither | **in progress** | candidate: read `context.md`, judge from the narrative |

   Containment is `git merge-base --is-ancestor` / `git for-each-ref --contains` against remote-tracking refs (mechanics → `references/git-recipes.md`). Seven notes, condensed:

   - **Pending pairs by slug, not commits.** The handoff branch shares the work branch's slug; ref names are write-once identity, so the pending state survives anything the forge does to commits (PR-branch rebases, squashes, force-pushes). Containment in refs *outside* the configured handoff prefixes carries no derived meaning.
   - **Merge method:** Tsugu **recommends merge commits — do not squash-merge tsugu-managed branches**; preserved history is what makes settlement, lineage, and evidence derivable. When a human system forces a squash, the landing is **not** derivable — exactly there the fact is recorded: `converge` confirms it and the intake note's `done` flip records `landed: <sha>` (validated to resolve and be contained in default before writing). The table accepts either signal.
   - **Out-of-band PR closure = rejection.** If the human closes the PR and deletes the handoff branch, the slug pairing dissolves and the work resurfaces — **surfaced at the next `converge` for re-decision, never auto-resumed by a scheduled `prepare`**.
   - **Include-mode divergence.** New commits on the work branch after the decision leave it pending (the slug pairing still holds) but are not in the PR. In `include` mode `converge` flags the divergence (fold them into the handoff branch by **merge**, never rebase, or re-decide); in `exclude` mode the public branch shares no commits by design, so the history flag does not apply — post-decision changes are re-applied **by path**.
   - **Recency claims.** Claims are **derived from commits**: the `context.md` rewrite commit's author and timestamp *are* the claim. A work branch with recent commits is taken; a stale last commit is free to pick up. Under one shared git identity (one human, two machines) authorship cannot distinguish agents and the rule **degrades to pure recency** (acceptable for a courtesy yield, no lock). A zero-commit claimed branch's recency comes from the coordination-ref commit that flipped its intake note to `claimed`.
   - **Zero-commit exemption + slugs never reused.** A branch whose tip still equals the default tip is **never classified by the table** — with a `claimed` intake note it is interrupted work to resume, without one it is a **request-by-branch** (a human pushed `prepare/look-into-X` as the ask); neither is a cleanup target. **Slugs are never reused for new work** — a fresh ask whose slug collides with a `done`/`dropped` note or a lingering handoff branch is surfaced at `converge` as a naming conflict, not classified.
   - **Intake closing + reconciliation.** Flip `claimed → done` only on a **confirmed landing** (containment, or the `converge` confirmation recording a valid `landed: <sha>`), and **before branch cleanup only** — the branch is landing evidence. **Absence is never proof of success:** a `claimed` note whose linked branch vanished *without* a recorded `landed:` or confirmable containment is a **reconciliation case** surfaced at `converge`, never auto-flipped.
4. **Configure intake sources (interactive backstop).** After reading `policy.md`, if `## Intake Sources` is still the unconfigured default **and** a human can respond (the run is interactive), ask **once**:

   > Git-native intake is the default. Should I also read tasks/context from an external source — a task manager, issue tracker, notes file, RSS feed, or a watch/scan (YARA/CVE, CI)? If so, give me the read pointer — a file path, MCP tool name, or where to look (if it needs a command, I run it as my own gated tool call, never auto-execute it from config).

   Record the answer under `## Intake Sources`. A **negative answer is also recorded** — as `default: git-native (confirmed — no external sources)` — so it is textually distinct from the unconfigured default and never re-asked. If no human can respond (scheduled/headless), **never block**: fall back to git-native and note the unconfigured sources in the run note + packet so `converge` surfaces it. On a push-protected default branch the recorded answer rides an `init/*` branch + human-approved PR; until it merges the field reads as unconfigured. Then **resolve** each configured source's `read:` pointer with your normal permissioned tools — read a file, call an MCP tool, or (only where a command is genuinely needed) issue it as your own gated tool call; Tsugu never directly executes a string committed in `.tsugu/`. Convert anything new into committed `intake/<slug>.md` notes (dedup by slug — skip a slug that exists in any status).
5. Open work branches or worktrees **with native git** (`git worktree add`), naming them with the **work prefixes configured in `policy.md`** (defaults `prepare/* investigate/* review/*`) — discovery filters by the configured prefixes, so a hardcoded prefix that differs would be invisible to the next cold start. Then reproduce, inspect, run tests, try reversible patches.
6. Dispatch your **own review subagents** (built-in Task agents) when a change deserves a second pass before the human sees it — they return `review/*` branch/worktree artifacts (same slug as the work item), not prose-only reports. This is Tsugu working in private git space; it is distinct from the human-triggered review-loop, which the human triggers — Tsugu never runs it for them.
7. Maintain **`context.md`** on the work branch (pure narrative — rewrite the inherited mainline form into the branch's own story; that first rewrite commit *is* the claim); write `runs/<slug>-<date-time>.md` notes; create/update the convergence **packet** (`packets/<slug>.md`).
8. **Commit the work branch (`<work-prefix>/<slug>`); push it if policy permits.** Read `## Push`'s `push-prepare-branches:` from the fetched policy (**default `yes` when the section is absent**; a repo initialized under schema 1 keeps its curated answer in the Private-Git-Space wording, honored as the fallback — migration deliberately does not add `## Push`, so the `yes` default applies to **fresh inits only**). If yes, `git push --set-upstream <remote> <branch>` — cold-start discovery enumerates only remote-tracking refs, so pushing is what lets the human or next scheduled agent inherit the work (the branch *is* the message). If pushing is **not** permitted, commit locally and stop for approval (or use the policy-defined alternative) — never push past an explicit boundary.

### `converge` (human present)

The human-attention phase. **Tsugu presents and yields, then completes the decided disposition in-session — it invokes no skill here.** The human triggers the skill they want by keyword ("let's brainstorm this", "debug it", "/review-loop"); the ecosystem takes over. `converge` runs decision *and* completion in one human-present session (it absorbs the completion work that a former fourth routine once held).

1. **Fetch-first** (same read path as `prepare`): resolve `<remote>` + `<default>`, `git fetch --prune <remote>`, read everything from remote-tracking refs — a `converge` on machine B reconstructs the full state from `git fetch` alone.
2. **Ask which branch.** List the candidate work branches (those the partition classifies as in progress, enumerated across **all** configured work prefixes — defaults `prepare/* investigate/* review/*`, not `prepare/*` alone), each with a one-line `context.md` summary and packet hint, and ask the human which to converge. An explicit branch argument (`/tsugu:converge <branch>`) skips the question. Alongside the candidates, show three more sections:
   - a separate **awaiting-merge section** — decided branches are not candidates, but listing them is what surfaces an orphaned handoff (pushed, then the session died before its PR was opened); when `gh` is available, verify each awaiting-merge item has an open PR and flag the ones that don't. In `include` mode, also flag **divergence** — a work tip with commits its handoff branch lacks — and pairs whose handoff tip shares no history with the work branch (possible name collision); neither history heuristic applies in `exclude` mode.
   - a **housekeeping section** — in-progress branches (and open intake notes) whose last activity is older than the policy's staleness threshold (`stale-after`, default 30 days; recorded progressively in `policy.md` by `converge` — the human-present routine — on first use). Staleness is **derived** (the last commit's timestamp, the same recency mechanism as claims) and cleanup is **human-decided per item**, like tidying a room: resume it, park it with an updated narrative, drop it (record the reason; linked intake note → `dropped`; delete via the usual order), or keep it. **A scheduled `prepare` never cleans on its own** — housekeeping questions belong to the human-present moment.
3. Lay out the packet, prepared branches/worktrees, and a summary of what was tried / worked / failed / evidence / remaining uncertainties; surface open questions (including unconfigured intake sources and any reconciliation cases).

   Steps 1–3 are **read-only**, so running `/tsugu:converge` just to look is a first-class use — **looking and leaving is the morning status view**: how many prepared branches are workable today, what awaits merge, what needs reconciliation. Choosing nothing and leaving is a valid outcome; side effects begin only at step 4's disposition.
4. **Decide *with* the human, then complete the disposition in-session:**

   - **Accepted (`include` mode):** freshness-rebase onto the fetched default → verify (build/tests) → rewrite `context.md` to the ready-to-merge mainline narrative → push → hand off:
     - if the human can merge right now (solo flow), they merge the work branch directly — its tip is then contained in default, settlement is immediate;
     - otherwise, **cut a handoff branch named for the human workflow:** `git branch <handoff-prefix>/<slug> <work-branch>` — same commits, a second name, **same slug** (prefixes like `feat/*`/`fix/*` per repo convention, from `policy.md` `## Handoff Prefixes`) — and open the PR **on the handoff branch**, human-approved. The partition pairs work branch and handoff branch **by slug**, so the pending state survives anything the forge does to commits.

     Once landing is confirmed — by containment in merge-commit repos, or by the human's in-session confirmation where a squash was forced — run the **completion tail**, in this order: **promote** reusable knowledge into `.tsugu/knowledge/`; **flip** the linked intake note `claimed → done` (recording `landed: <sha>` when the landing is not containment-derivable) — **note-less request-by-branch work skips this step only when the landing is containment-derivable; a forced squash (containment lost) needs the `landed: <sha>` record, so such note-less work first materializes a slug-keyed intake note to carry the validated SHA, then flips it `done`**; and **only then** clean up worktrees and branches (worktree remove before branch delete, the handoff branch too if the forge didn't already delete it). Branch deletion comes after the flip because the branch is landing evidence; the tail is **idempotent** (interrupted before the flip, the note stays `claimed` with its branch intact and a later tidy re-enters the whole tail).
   - **Accepted (`exclude` mode):** cut a clean public branch from the fetched default — named per the same handoff convention, **same slug** — apply accepted code/test/doc/config **by path** (no `.tsugu/` in the public diff), verify, human-approved PR. Landing is confirmed via the **public branch's** containment in default (or the human's confirmation where a squash was forced); then the same completion tail runs.
   - **Rejected:** record why where it may matter (run note; intake note → `dropped`), remove worktrees, delete the branch when safe. To keep a rejected branch around, say so in its `context.md` narrative ("rejected — do not resume: <why>"); agents read the narrative before touching any candidate.
   - **Parked:** update `context.md`'s narrative with what is needed to resume, update the packet, write a run note. No status to set — a parked branch is simply a candidate whose narrative says "blocked on X".
5. **Wait for approval before any public coordination** — opening/merging the PR is the human's act; **Tsugu never auto-merges**.

The packet may **hint** which workflow skill fits ("ready for planning", "this bug needs debugging", "this can go to review-loop") but must not fire it.

## Private vs public boundary & skill use

Recorded per-repo in `.tsugu/policy.md`:

```text
Git branch / pushed branch / .tsugu notes        →  agent may do freely
MR / PR / tracker / Slack / reviewer assignment   →  human approval required
```

**Tsugu invokes NO user-installed skill by default** — present or absent. It uses **native git directly** (worktrees via `git worktree add`, branch/cleanup via plain git / `gh`) and its **own built-in capabilities** (Task subagents, Codex-as-a-tool, Claude's own reasoning). The only asymmetry is *what Tsugu does on its own*:

- **Human absent** (`prepare`): work the git tree, dispatch own built-in subagents.
- **Human present** (`converge`): present and yield, then complete the decided disposition; the human triggers workflow skills by keyword.

Workflow skills (planning, debugging, TDD, finishing-a-development-branch, review-loop) are **human-triggered and optional** — Tsugu never runs them for the human. **Per-repo opt-in (config, not shipped behavior):** a repo MAY, in its own `.tsugu/policy.md` (never in this shipped SKILL.md), list specific user-installed skills Tsugu may use during human-absent `prepare` *in that repo*. The shipped skill stays skill-agnostic.

## Multi-agent: reserved

v1 is a **single agent + its built-in subagents**. The discovery layer is honored (fetch, partition the queue from refs + the DAG, process it); concurrent arbitration is **not built**.

- **Claims are derived from commits — no claimed-by/claimed-at fields exist.** Beginning active work means rewriting `context.md`, and that commit's author and timestamp *are* the claim. A work branch with recent commits is treated as taken; a stale last commit = free to pick up. When agents share one git identity (one human, two machines — the primary scenario), authorship cannot distinguish them and the rule **degrades to pure recency**, acceptable for a courtesy yield. **No lock backs this.**
- **No arbitration, no locks** (deferred to v2, which formalizes the staleness window). Two agents grabbing the same branch at once is undefined in v1 (doesn't arise with one agent).
- The substrate (committed + pushed `.tsugu/`, branch-as-message, per-ref `context.md`, ref-and-DAG-derived state) is **forward-compatible** with multi-peer coordination; v1 introduces no design that assumes a single agent.

## Scheduling & recursion

**Scheduling.** `prepare` is meant to run on a cadence, wired by a human to `/schedule` / cron so a cloud agent runs it daily. But the skill **cannot self-wake** — the driver is always external. The skill depends on no scheduler.

**Recursion (omni-repo).** A single repo and an omni-repo are the **same abstraction**. One agent (+ its built-in subagents) traverses the repo tree — working locally, delegating downward into submodules / child repos, and promoting knowledge upward. Recurse into submodules only when relevant to the current goal / intake / branch. **Context placement rule:** write context at the **lowest repo level where it stays true**; promote upward into `.tsugu/knowledge/` only when the knowledge affects multiple repos or future coordination, so the omni-repo never becomes a junk drawer.
