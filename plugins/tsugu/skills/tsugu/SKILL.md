---
name: tsugu
description: Git-native preparation & convergence — carry work forward across the gap when no human is watching, the handoff to a human, and the resume by whoever comes next. Use to prepare work before review, then converge it with the human, or run the lifecycle via `/tsugu:init`, `/tsugu:prepare`, `/tsugu:converge`. Triggers on "prepare work before review", "carry work forward", "git-native preparation", "init/prepare/converge", or "/tsugu". Human-triggered and schedule-wireable (wire `prepare` to `/schedule`/cron). Invokes no user-installed skill by default — native git + its own built-in subagents only. Never auto-merges and never performs public coordination without approval.
---

# Tsugu — 継ぐ (prepare & converge over git)

## 継ぐ (tsugu)

**継ぐ** · つぐ / *tsugu* · to **inherit**, **continue**, **carry forward** (succeed to a role). The name is the intent: work is carried forward rather than restarted —

- **inherit** — a cold-start or *different* agent inherits the work from git + committed `.tsugu/` alone, with no conversation transcript;
- **continue** — `prepare` continues the work while human attention is absent, leaving reversible evidence instead of an empty task description;
- **carry forward** — `converge` carries the prepared work into clean public form *with the human present* and promotes what is worth keeping.

**Git's DAG is the medium of inheritance.** A branch is a unit of work one agent hands to the next; committed `.tsugu/` is the work-in-progress knowledge that outlives the session that produced it.

**In one line:** Tsugu **guides agents to cooperate with each other through git**, and **helps the human come back to prepared work**. It *guides* — it never forces: the agent decides and acts through its own tools; Tsugu only prepares the ground (see the no-force principle in the spine).

Tsugu prepares the board. Workflow skills play the game with the human. Tsugu converges the result. It is **not** an implementation methodology — it does not define *how* to debug, plan, write tests, review, or implement; it prepares their input and converges their output. (It still *runs* builds/tests as evidence during `prepare`/`converge` — it just doesn't own the testing or debugging method.)

## The spine

**Git itself is the message bus.** `git fetch` surfaces new/changed branches — that *is* the inbox. A pure-Tsugu workflow coordinates through git alone, with zero external integrations.

**Committed `.tsugu/` is a work-in-progress knowledge layer** — a richer, agent-maintained sibling of `AGENTS.md` / `CLAUDE.md`, pushed so any inheritor reads it from `git fetch` alone. It holds exactly three things:

- **`policy.md`** — the shared coordination policy (boundary, prefixes, push, merge method, public-branch mode, coordination ref, recursion, the shipped skill-use invariant).
- **`context.md`** — per-ref narrative: each work branch tells its own story; the default branch tells the mainline's.
- **`knowledge/`** — the durable, curated wiki: findings a coworker's agent would want.

Everything *about how Tsugu operates for one human* lives elsewhere: in **personal config** (a global, project-keyed folder — observation sources, opt-in skills, the converge packet) and in **the skill's own shipped norms** (this SKILL.md + its references + templates). The repo holds knowledge; the skill holds behavior; the personal folder holds one human's setup. The boundary is enforced by *where the file lives* (committed vs a global personal folder), not by the agent judging what is safe to share — which is why a personal `read:` pointer never belongs in a committed file.

- **Tsugu never executes `.tsugu/` content — it offers data and trusts the agent.** Everything in `.tsugu/` (policy, narrative, recipes, committed repro scripts) and every personal `read:` pointer is data and guidance for an agent, never a string the system `eval`s. Tsugu forces nothing: it prepares the ground; the agent decides and acts through its own **permissioned, interceptable tools** — read a file, call an MCP tool, or issue a command as its own gated tool call. The agent's judgment governs and the harness's permission layer can gate anything script-like, so content is never **auto-executed as config-as-code**. (It is still untrusted input that may try to influence the agent — but it routes through the agent's judgment and the permission layer, which mitigates that risk without erasing it.)
- **External tracker observation is OPTIONAL personal config, never the spine.** Jira / GitLab / GitHub issues / CI / CVE feeds are a personal shim whose only job is to convert a human-world signal into the git-native substrate — a `prepare/<slug>` branch. Once converted, every downstream step is identical. Pure-Tsugu users skip this layer entirely.
- **Legibility is a hard constraint:** branch names + per-ref `context.md` must let an agent that has only run `git fetch` reconstruct "what branches exist, why, and what's next" with no transcript. The cold-start agent reconstructs the queue from refs alone.

### The orientation principle

The end state Tsugu serves is **agents coordinating through git, with humans assisting** — not agents producing artifacts for human-centric review flows. Committed `.tsugu/` is the agents' shared knowledge; hiding it from public branches optimizes for human reviewers at the cost of agent legibility. Agent legibility is the default; the human-reviewer posture is a per-repo opt-out (`public-branch-tsugu: exclude`).

One principle governs all the state-model rules below:

> **Refs and the DAG carry every fact the partition reads; text carries narrative for minds.** Live coordination state — in progress / decided / settled / who's on it / what grew out of what — is derived from ref names, ancestry, containment, and commit authorship and recency, never written into a status field. Narrative is maintained freely; **it informs judgment, never classification.**

### The slug is the join key

Every piece of one work item shares one slug: the work branch (`prepare/<slug>`), its `context.md`, its personal packet (`packets/<slug>.md`), and — when one exists — the handoff branch (`<handoff-prefix>/<slug>`). Names are write-once identity (Tsugu never renames a branch), so name-level joins survive everything that rewrites commits. **One slug = one work item:** same-slug branches under *different work prefixes* (e.g. a `review/<slug>` artifact from a built-in review subagent) are that item's artifacts — they share its lifecycle and are swept by its completion tail. Work prefixes and handoff prefixes must be **disjoint** sets; `init` and migration validate this.

## Routing

`/tsugu:init` · `/tsugu:prepare` · `/tsugu:converge` — one lifecycle, three routines:

- **init** — first-run setup (or schema migration on re-run); ask the minimum, write the committed `.tsugu/` (`policy.md` + mainline `context.md` + seeded `knowledge/`).
- **prepare** — human-absent: read the queue from git, work it privately, leave evidence.
- **converge** — human-present: read the branches live, present the status view, decide together, and complete the disposition in-session.

Mechanics are deferred — do not re-derive git commands here:

- Exact git (fetch → read-queue-from-remote-refs, containment + slug-pairing partition, handoff-branch cut, include-mode merge-back, exclude-mode clean-cut, freshness rebase, completion tail, cleanup order, init skeleton) → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/git-recipes.md`.
- Shared `policy.md` fields + the personal-config pointer (sources + opt-in skills in the global folder) → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/policy-and-intake.md`.
- `context.md` / `knowledge/` structure + the personal/derived packet → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/notes-and-packet.md`.
- `init` re-run migration steps (schema N→N+1, including 2→3) → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/migrations.md`.
- `init` writes the repo's committed `.tsugu/` files from `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/templates/` — templates are read **by reference**, never copied into a repo `templates/` directory.

## The three routines

### `init`

Runs when a repo has no `.tsugu/`, or re-runs to repair or migrate an existing one. Capture the **minimum** preferences for safe unattended prep — ask only a few: may agents create/commit/push prep branches automatically (**default: yes** — pushing makes the branch a message the next machine reads)? which public actions need approval (default: MR/PR, tracker comment/status, reviewer assignment, Slack, public commitments)? branch prefixes (default work-only `prepare/* investigate/* review/*`)? handoff prefixes for PRs (default `feat/* fix/*`)? should the default branch carry the WIP-knowledge layer (`public-branch-tsugu: include|exclude`, **default `include`**)? recurse into submodules (default: only when relevant)?

Observation sources and opt-in skills are **personal config** — `init` does not ask for them and does not write them to `policy.md`; they are bootstrapped per-machine on the first interactive `prepare`/`converge` (see `prepare`).

Then write committed `.tsugu/` from the plugin templates: `policy.md` (shared sections) + a mainline `context.md` + a seeded `knowledge/` (one real file — git can't track empty directories). **No `intake/`, `runs/`, `packets/`, or `templates/` directory is created in the repo.** **Stamp `tsugu-schema: 3`** as the first line of a fresh `policy.md`.

**Validate prefix-disjointness.** The work prefixes (`## Branch Prefixes`) and the handoff prefixes (`## Handoff Prefixes`) must be **disjoint sets** — the partition pairs a work branch against a handoff branch by shared slug, so an overlapping prefix would make a branch both a queue item and its own handoff. `init` (and migration) refuse to write overlapping sets and ask the human to resolve.

**Re-run decision** — read `policy.md`'s `tsugu-schema:` stamp and pick one of three:

1. **No `.tsugu/`** → fresh init (write `policy.md` + mainline `context.md` + seeded `knowledge/`), stamped with the current schema.
2. **`.tsugu/` present, stamp == current** → **idempotent repair** only: fill any missing skeleton path, otherwise a no-op. It **never overwrites** a curated `policy.md`.
3. **`.tsugu/` present, stamp older** → **migrate**: apply `references/migrations.md` steps in order (N→N+1 until current; a schema-1 repo runs 1→2→3), then update the stamp **last** and commit (message names the range, e.g. `chore(tsugu): migrate .tsugu/ schema 2→3`). Migrations add/restructure schema parts only, never overwrite curated content; an interrupted migration re-enters safely (stamp written last).

- **Progressive:** when a new situation appears, ask once, record the rule in `policy.md`, let future agents inherit it.
- **Push-protected default:** the shared metadata `init` writes to the default branch (`policy.md` **and** the mainline `context.md`) must reach it; if it is push-protected, write both on an `init/*` branch and open a **human-approved PR**. `prepare` does not run in that repo until the metadata is merged. The same applies to a migration: it rides an `init/*` branch + PR; the `tsugu-schema` stamp rides the policy PR as the **last** write — never a "complete" stamp over a half-applied migration.

### `prepare` (human absent)

The core routine. No human is present, so Tsugu does its own git work directly and may dispatch its **own built-in Task subagents**; it invokes a user-installed skill **only when a human has explicitly opted one in** via the personal-folder `skills` section (see *Private vs public boundary & skill use*) — otherwise none. Posture: **external silence, internal preparation.** Interrupt the human only if the task is unsafe, destructive, or blocked; when unsure, continue with reversible private git work.

`prepare` **does NOT self-wake** — a SKILL.md is a prompt loaded into a running agent and cannot schedule itself. Cadence always comes from an external `/schedule`/cron driver.

1. **Fetch first** (`git fetch --prune <remote>`), resolving `<remote>` + `<default>`, so every read below uses fresh remote-tracking refs, not a stale checkout.
2. Read `policy.md` + guidance from the **fetched default ref** (yields the work + `## Handoff Prefixes`, `## Push`, `public-branch-tsugu`, `coordination-ref`, `stale-after`, among others).
3. **Read the queue from remote-tracking refs** (plus `knowledge/` from the coordination ref). There is no committed note layer — the queue *is* the set of work branches.

   **Partition each work branch `<work-prefix>/<slug>` by two ref-level facts, checked in order** — there is **no written branch state**:

   | Fact | State | Disposition |
   | --- | --- | --- |
   | tip contained in `<remote>/<default>` (in `exclude` mode: the slug-paired public branch's tip, since by-path application breaks the work branch's own containment) | **settled** — the work landed | skip; completion-tail / cleanup candidate |
   | a branch with the **same slug** exists under a configured `## Handoff Prefixes` | **decided, awaiting merge** | skip as a candidate; shown in `converge`'s awaiting-merge section |
   | neither | **in progress** | candidate: read `context.md`, judge from the narrative |

   Containment is `git merge-base --is-ancestor` / `git for-each-ref --contains` against remote-tracking refs (mechanics → `references/git-recipes.md`). Five notes, condensed:

   - **Pending pairs by slug, not commits.** The handoff branch shares the work branch's slug; ref names are write-once identity, so the pending state survives anything the forge does to commits (PR-branch rebases, squashes, force-pushes). Containment in refs *outside* the configured handoff prefixes carries no derived meaning.
   - **Work tip not contained → disposition reads off the slug-paired ref.** Tsugu **recommends merge commits — do not squash-merge tsugu-managed branches**; preserved history is what makes settlement containment-derivable. **Two cases leave the work branch's own tip *not* contained** in default, so its disposition can only be read off the slug-paired ref (never the work branch's own containment): (a) a **forced squash** (the squash commit's parents contain none of the work commits), and (b) **`exclude` mode** (accepted changes land **by path** on a fresh public branch — the work branch itself never merges). The two then **differ**: in `exclude` mode the item becomes **settled** the moment the public branch's tip is contained (a normal merge — partition row 1); a **forced squash** stays **"decided, awaiting merge"** and **re-surfaces at each `converge`** until the human confirms the landing and runs the completion tail (its own tip is never contained, so containment can never settle it). What they **share** is the failure mode below: either disposition can only be read *while that ref survives*, so **recommend disabling the forge's auto-delete-head-branch for tsugu handoff/public branches**.
   - **Narrative backstop (the handoff/public ref is deleted anyway).** If the forge deletes that ref on merge, the work branch is neither contained nor slug-paired, so the table calls it **in-progress** — and a scheduled `prepare` must not resume landed work. This covers both cases above (a forced squash, or any `exclude`-mode landing). The work branch's `context.md` reads "handed off — may have landed" (written at the converge decision); `prepare`'s **judgment** reads that and **leaves the branch for `converge`** rather than resuming it. The partition still classifies it in-progress; judgment, not a status field, declines to work it — *narrative informs judgment, never classification*.
   - **Out-of-band PR closure = rejection.** If the human closes the PR and deletes the handoff branch, the slug pairing dissolves and the work resurfaces — **surfaced at the next `converge` for re-decision, never auto-resumed by a scheduled `prepare`**.
   - **Recency claims + zero-commit exemption.** Claims are **derived from commit recency** (see Multi-agent): the `context.md` rewrite commit's author and timestamp *are* the claim. A branch whose tip still equals the default tip is **never classified by the table** — it is interrupted work or a **request-by-branch** (a human pushed `prepare/look-into-X` as the ask), never a cleanup target; it carries no recency until someone commits to it.

4. **Bootstrap personal config (interactive only).** Personal config lives in a global, project-keyed folder (`~/.claude/tsugu/<project-key>/`; `<project-key>` derives from the repo's absolute common git dir, so every worktree of one repo shares one folder per machine — see `references/policy-and-intake.md`). It does not transfer across machines, so each machine seeds its own. When a section is absent **and** the run is interactive, ask **once**, separately for the two sections:

   - **sources** — *"Any observation sources to read besides git? A file path, MCP tool name, or where to look. I resolve the `read:` pointer with my own permissioned tools, never auto-executing it from config."*
   - **skills** — *"Any user-installed skills you trust me to use here during human-absent `prepare`? (default: none.)"*

   Record each answer in the personal folder; **a negative answer is recorded as a confirmed-negative marker** (`sources: git-native (confirmed)` / `skills: none (confirmed)`) so it is never re-asked — an unset section is distinct from a confirmed-empty one. When **headless/non-interactive**, never block: fall back to git-native (no sources, no opt-in skills) and surface "personal config unconfigured on this machine" at the next `converge`. Then **resolve** each configured source's `read:` pointer with your normal permissioned tools — read a file, call an MCP tool, or (only where a command is genuinely needed) issue it as your own gated tool call; Tsugu never directly executes the pointer string. **A source signal becomes a `prepare/<slug>` branch directly** — there is no committed note first.

5. Open work branches or worktrees **with native git** (`git worktree add`), naming them with the **work prefixes configured in `policy.md`** (defaults `prepare/* investigate/* review/*`) — discovery filters by the configured prefixes, so a hardcoded prefix that differs would be invisible to the next cold start. Then reproduce, inspect, run tests, try reversible patches.
6. Dispatch your **own review subagents** (built-in Task agents) when a change deserves a second pass before the human sees it — they return `review/*` branch/worktree artifacts (same slug as the work item), not prose-only reports. This is Tsugu working in private git space; it is distinct from the human-triggered review-loop, which the human triggers — Tsugu never runs it for them.
7. Maintain **`context.md`** on the work branch (pure narrative — rewrite the inherited mainline form into the branch's own story; that first rewrite commit *is* the claim). Promote durable, shareable findings into `.tsugu/knowledge/`. Refresh the convergence **packet** (`packets/<slug>.md`) in the **personal folder** — it is a personal/derived view, never committed.
8. **Commit the work branch (`<work-prefix>/<slug>`); push it if policy permits.** Read `## Push`'s `push-prepare-branches:` from the fetched policy (**default `yes` when the section is absent**). If yes, `git push --set-upstream <remote> <branch>` — cold-start discovery enumerates only remote-tracking refs, so pushing is what lets the human or next scheduled agent inherit the work (the branch *is* the message). If pushing is **not** permitted, commit locally and stop for approval (or use the policy-defined alternative) — never push past an explicit boundary.

### `converge` (human present)

The human-attention phase. **Tsugu presents and yields, then completes the decided disposition in-session — it invokes no skill here.** The human triggers the skill they want by keyword ("let's brainstorm this", "debug it", "/review-loop"); the ecosystem takes over. `converge` runs decision *and* completion in one human-present session.

1. **Fetch-first** (same read path as `prepare`): resolve `<remote>` + `<default>`, `git fetch --prune <remote>`, read everything from remote-tracking refs. **Read each tsugu branch live** (its `context.md` + DAG state) to assemble the picture — a `converge` on machine B reconstructs the full state from `git fetch` alone, never from machine A's packet. Any cache stays personal/ephemeral (the chat session or the global folder), never a committed `.tsugu/` artifact.
2. **Ask which branch.** List the candidate work branches (those the partition classifies as in progress, enumerated across **all** configured work prefixes — defaults `prepare/* investigate/* review/*`, not `prepare/*` alone), each with a one-line `context.md` summary and packet hint, and ask the human which to converge. An explicit branch argument (`/tsugu:converge <branch>`) skips the question. Alongside the candidates, show two more sections:
   - a separate **awaiting-merge section** — decided branches are not candidates, but listing them surfaces an orphaned handoff (pushed, then the session died before its PR opened); when `gh` is available, flag awaiting-merge items lacking an open PR. In `include` mode, also flag **divergence** — a work tip with commits its handoff branch lacks, or a handoff tip sharing no history with the work branch (possible name collision); neither heuristic applies in `exclude` mode.
   - a **housekeeping section** — in-progress branches whose last activity is older than `stale-after` (default 30 days; recorded progressively in `policy.md` by `converge` on first use). Staleness is **derived** (last-commit timestamp, the same recency mechanism as claims); cleanup is **human-decided per item** — resume, park with an updated narrative, drop (record the reason in the narrative, delete via the usual order), or keep. **A scheduled `prepare` never cleans on its own.**
3. Regenerate the **personal packet** live from the branches and lay it out alongside the prepared branches/worktrees and a summary of what was tried / worked / failed / evidence / remaining uncertainties; surface open questions (including any personal config unconfigured on this machine).

   Steps 1–3 touch **no git or shared state** — they make no commits, no pushes, no public coordination; regenerating the personal packet writes only a derived, ephemeral view in the personal folder (not a shared artifact, so it is not a meaningful side effect). In that sense running `/tsugu:converge` just to look is a first-class use — **looking and leaving is the morning status view**: how many prepared branches are workable today, what awaits merge, what's stale. Choosing nothing and leaving is a valid outcome; **all shared/git side effects begin only at step 4's disposition**.
4. **Decide *with* the human, then complete the disposition in-session:**

   - **Accepted (`include` mode):** freshness-rebase onto the fetched default → verify (build/tests) → rewrite `context.md` to the ready-to-merge mainline narrative → push → hand off:
     - if the human can merge right now (solo flow), they merge the work branch directly — its tip is then contained in default, and the prep DAG + the rewritten mainline `context.md` land as committed WIP knowledge; settlement is immediate;
     - otherwise, **cut a handoff branch named for the human workflow:** `git branch <handoff-prefix>/<slug> <work-branch>` — same commits, a second name, **same slug** (prefixes like `feat/*`/`fix/*` per repo convention, from `policy.md` `## Handoff Prefixes`) — and open the PR **on the handoff branch**, human-approved. The partition pairs work branch and handoff branch **by slug**, so the pending state survives anything the forge does to commits. When a squash is anticipated, write the "handed off — may have landed via squash" narrative into the work branch's `context.md` now (the narrative backstop) and keep the handoff branch (disable forge auto-delete).
   - **Accepted (`exclude` mode):** cut a clean public branch from the fetched default — named per the same handoff convention, **same slug** — apply accepted code/test/doc/config **by path** (no `.tsugu/` in the public diff), verify, human-approved PR. Landing is confirmed via the **public branch's** containment in default (or the human's confirmation where a squash was forced). `knowledge/` still lands on the coordination ref. **The work branch never merges here, so its own tip is never contained** — settlement reads off the public branch's slug pairing; therefore, exactly as in the squash case, write the "handed off — may have landed" narrative into the work branch's `context.md` now (the narrative backstop) and keep the public branch alive (disable forge auto-delete) until the completion tail removes both.
   - **Completion tail** (once landing is confirmed — by containment in merge-commit repos, or by the human's in-session confirmation where a squash was forced): **promote** reusable findings into `.tsugu/knowledge/`, then **clean up** worktrees then branches (worktree remove before branch delete; delete **both** the work branch and the handoff branch). Once both refs are gone the item **leaves the partition entirely** (no refs → not classified). The durable landed artifact is **the landed commits on the default branch** — the merge in a normal include/exclude landing, or the squash commit where a squash was forced; no SHA is persisted, and there is no status to flip. The tail is **idempotent** — interrupted before cleanup, the branches remain and a later tidy re-enters.
   - **Rejected:** record why in the branch's `context.md` narrative ("rejected — do not resume: <why>"; agents read the narrative before touching any candidate), remove worktrees, delete the branch when safe.
   - **Parked:** update `context.md`'s narrative with what is needed to resume, and the personal packet. No status to set — a parked branch is simply a candidate whose narrative says "blocked on X".
5. **Wait for approval before any public coordination** — opening/merging the PR is the human's act; **Tsugu never auto-merges**.

The packet may **hint** which workflow skill fits ("ready for planning", "this bug needs debugging", "this can go to review-loop") but must not fire it.

## Private vs public boundary & skill use

Recorded per-repo in `.tsugu/policy.md`:

```text
Git branch / pushed branch / committed .tsugu/    →  agent may do freely
MR / PR / tracker / Slack / reviewer assignment   →  human approval required
```

**Tsugu invokes NO user-installed skill by default** — present or absent. It uses **native git directly** (worktrees via `git worktree add`, branch/cleanup via plain git / `gh`) and its **own built-in capabilities** (Task subagents, Codex-as-a-tool, Claude's own reasoning). The only asymmetry is *what Tsugu does on its own*:

- **Human absent** (`prepare`): work the git tree, dispatch own built-in subagents.
- **Human present** (`converge`): present and yield, then complete the decided disposition; the human triggers workflow skills by keyword.

Workflow skills (planning, debugging, TDD, finishing-a-development-branch, review-loop) are **human-triggered and optional** — Tsugu never runs them for the human. **Per-machine opt-in (personal config, not shipped behavior):** a human MAY, in their personal folder's `skills` section, list specific user-installed skills Tsugu may use during human-absent `prepare` *in that repo on that machine*. The shipped skill stays skill-agnostic.

## Multi-agent: reserved

Tsugu today is a **single agent + its built-in subagents**. The discovery layer is honored (fetch, partition the queue from refs + the DAG, process it); concurrent arbitration is **not built**.

- **Claims are derived from commit recency — no claimed-by/claimed-at fields exist.** Beginning active work means rewriting `context.md`, and that commit's author and timestamp *are* the claim. A work branch with recent commits is treated as taken; a stale last commit = free to pick up. When agents share one git identity (one human, two machines — the primary scenario), authorship cannot distinguish them and the rule **degrades to pure recency**, acceptable for a courtesy yield. **No lock backs this.**
- **No arbitration, no locks** (deferred to a future multi-agent iteration, which would formalize the staleness window). Two agents grabbing the same branch at once is undefined today (doesn't arise with one agent).
- The substrate (committed + pushed `.tsugu/`, branch-as-message, per-ref `context.md`, ref-and-DAG-derived state) is **forward-compatible** with multi-peer coordination; this design introduces nothing that assumes a single agent.

## Scheduling & recursion

**Scheduling.** `prepare` is meant to run on a cadence, wired by a human to `/schedule` / cron so a cloud agent runs it daily. But the skill **cannot self-wake** — the driver is always external. The skill depends on no scheduler.

**Recursion (omni-repo).** A single repo and an omni-repo are the **same abstraction**. One agent (+ its built-in subagents) traverses the repo tree — working locally, delegating downward into submodules / child repos, and promoting knowledge upward. Recurse into submodules only when relevant to the current goal / branch. **Context placement rule:** write context at the **lowest repo level where it stays true**; promote upward into `.tsugu/knowledge/` only when the knowledge affects multiple repos or future coordination, so the omni-repo never becomes a junk drawer.
