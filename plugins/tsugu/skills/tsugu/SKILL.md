---
name: tsugu
description: Git-native preparation & convergence — carry work forward across the gap when no human is watching, the handoff to a human, and the resume by whoever comes next. Use to prepare work before review, then converge it with the human, or run the lifecycle via `/tsugu:init`, `/tsugu:prepare`, `/tsugu:converge`, `/tsugu:prune`. Triggers on "prepare work before review", "carry work forward", "git-native preparation", "init/prepare/converge/prune", or "/tsugu". Human-triggered and schedule-wireable (wire `prepare` to a driver on the provisioned machine — local cron / `/loop` / `/schedule`). Invokes no user-installed skill by default — native git + its own built-in subagents only. Never auto-merges and never performs public coordination without approval.
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

Every piece of one work item shares one slug: the work branch (`prepare/<slug>`), its `context.md`, its personal packet (`packets/<slug>.md`), and — when one exists — the accepted branch (`<accepted-prefix>/<slug>`). Identity is the **slug**, and Tsugu **never renames the slug**: handoff renames only the **prefix** (`prepare/<slug>` → `<accepted-prefix>/<slug>`), preserving the slug, so the name-level joins it carries survive everything that rewrites commits. (This narrows the inherited 004–008 invariant "Tsugu never renames a branch" — read it as "never renames the slug" post-011.) **One slug = one work item.** Work prefixes and accepted prefixes must be **disjoint** sets; `init` and migration validate this. (A repo that configures *extra* work prefixes can produce same-slug artifacts under a different work prefix — that case is documented in `references/advanced.md`.)

## Routing

`/tsugu:init` · `/tsugu:prepare` · `/tsugu:converge` · `/tsugu:prune` — one lifecycle, four routines:

- **init** — first-run setup (or schema migration on re-run); ask the minimum, write the committed `.tsugu/` (`policy.md` + mainline `context.md` + seeded `knowledge/`).
- **prepare** — human-absent: read the queue from git, work it privately, leave evidence.
- **converge** — human-present: read the branches live, present the status view, decide together, hand off (and curate) in-session.
- **prune** — human-present: a recurring, read-only-until-confirmed sweep of unused local + remote branches once refs have piled up.

Mechanics are deferred — do not re-derive git commands here:

- Exact git (fetch → read-queue-from-remote-refs, containment + slug-pairing partition, the handoff rename, the maintenance freshness-rebase recipe, the `prune` sweep, cleanup order, init skeleton) → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/git-recipes.md`.
- Shared `policy.md` fields + the personal-config pointer (sources + opt-in skills in the global folder) → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/policy-and-intake.md`.
- `context.md` / `knowledge/` structure + the personal/derived packet → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/notes-and-packet.md`.
- `init` re-run migration steps (schema N→N+1, including 2→3) → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/migrations.md`.
- `init` writes the repo's committed `.tsugu/` files from `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/templates/` — templates are read **by reference**, never copied into a repo `templates/` directory.
- Submodule recursion (enumerate + `.tsugu/policy.md` gate + recurse-and-run + bare paired branch), its handoff, and graduation → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/git-recipes.md` (§ Submodule recursion), `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/advanced.md` (§ Bare-submodule handoff), `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/notes-and-packet.md` (§ Graduation).

## The four routines

### `init`

Runs when a repo has no `.tsugu/`, or re-runs to repair or migrate an existing one. Capture the **minimum** preferences for safe unattended prep — ask only a few: may agents create/commit/push prep branches automatically (**default: yes** — pushing makes the branch a message the next machine reads)? which public actions need approval (default: MR/PR, tracker comment/status, reviewer assignment, Slack, public commitments)? branch prefixes (default work-only `prepare/*`)? accepted prefixes for handoff PRs (default `feature/* bugfix/* chore/*`)? should the default branch carry the WIP-knowledge layer (`public-branch-tsugu: include|exclude`, **default `include`**)? recurse into submodules (default: only when relevant)?

**`/tsugu:init [<submodule-path>]` + graduation.** With a `<submodule-path>` argument
`init` targets that submodule directly (skips the "which repo / confirm target"
question). When run on a submodule under a tsugu-managed omni-repo (detected via
`git rev-parse --show-superproject-working-tree`), it **graduates** the submodule:
it scans the omni `knowledge/` for entries naming this submodule, presents them, and
on per-entry human confirmation **cuts** them down into the new submodule
`knowledge/` (knowledge only). The omni gitlink **must** be bumped to the new
`.tsugu/` commit (else a fresh checkout re-classifies the submodule as bare).
In-flight paired meta branches are left to finish at meta `converge`. Mechanics →
`references/notes-and-packet.md` (§ Graduation).

Observation sources and opt-in skills are **personal config** — `init` does not ask for them and does not write them to `policy.md`; they are bootstrapped per-machine on the first interactive `prepare`/`converge` (see `prepare`).

Then write committed `.tsugu/` from the plugin templates: `policy.md` (shared sections) + a mainline `context.md` + a seeded `knowledge/` (one real file — git can't track empty directories). **No `intake/`, `runs/`, `packets/`, or `templates/` directory is created in the repo.** **Stamp `tsugu-schema: 5`** as the first line of a fresh `policy.md`.

**Validate prefix-disjointness.** The work prefixes (`## Branch Prefixes`) and the accepted prefixes (`## Accepted Prefixes`) must be **disjoint sets** — the partition pairs a work branch against an accepted branch by shared slug, so an overlapping prefix would make a branch both a queue item and its own accepted branch. `init` (and migration) refuse to write overlapping sets and ask the human to resolve.

**Re-run decision** — read `policy.md`'s `tsugu-schema:` stamp and pick one of three:

1. **No `.tsugu/`** → fresh init (write `policy.md` + mainline `context.md` + seeded `knowledge/`), stamped with the current schema.
2. **`.tsugu/` present, stamp == current** → **idempotent repair** only: fill any missing skeleton path, otherwise a no-op. It **never overwrites** a curated `policy.md`.
3. **`.tsugu/` present, stamp older** → **migrate**: apply `references/migrations.md` steps in order (N→N+1 until current; a schema-1 repo runs 1→2→3→4), then update the stamp **last** and commit (message names the range, e.g. `chore(tsugu): migrate .tsugu/ schema 3→4`). Migrations add/restructure schema parts only, never overwrite curated content; an interrupted migration re-enters safely (stamp written last).

- **Progressive:** when a new situation appears, ask once, record the rule in `policy.md`, let future agents inherit it.
- **Push-protected default:** the shared metadata `init` writes to the default branch (`policy.md` **and** the mainline `context.md`) must reach it; if it is push-protected, write both on an `init/*` branch and open a **human-approved PR**. `prepare` does not run in that repo until the metadata is merged. The same applies to a migration: it rides an `init/*` branch + PR; the `tsugu-schema` stamp rides the policy PR as the **last** write — never a "complete" stamp over a half-applied migration.

### `prepare` (human absent)

The core routine. No human is present, so Tsugu does its own git work directly and may dispatch its **own built-in Task subagents**; it invokes a user-installed skill **only when a human has explicitly opted one in** via the personal-folder `skills` section (see *Private vs public boundary & skill use*) — otherwise none. Posture: **external silence, internal preparation.** Interrupt the human only if the task is unsafe, destructive, or blocked; when unsure, continue with reversible private git work.

**`prepare` exists to gather understanding, not to finalize.** Its job is to **carry understanding forward**, not to rush a complete implementation — so a cold-start agent must not read `prepare` as a mandate to implement everything. Foreground, **above producing finished code**: investigation and **root cause**; the **option space** and its **trade-offs**; **open questions**; and the **decision-free vs needs-the-human** split — which parts have a determinate answer and which require human design context.

- **Reference code is optional and partial by design.** Working code in a prepare branch is welcome as **proof-of-feasibility and a starting point** — it does *not* need to be a complete implementation. Stopping short of a finished implementation is explicitly fine; "only enough to prove feasibility and surface the decisions" is the target, not a shortfall.
- **A scope-only branch is a first-class outcome.** Splitting a multi-part item into scope branches and deferring product / UX / backend decisions to converge is encouraged. A **scope-only branch** — `context.md` with the investigation, option space, and open questions, and **no product / codebase changes** — is a first-class `prepare` outcome, not an incomplete one. (Its `context.md` commit puts the branch ahead of default and reads as in-progress; a tip-equals-default branch is never a cleanup target.)
- **Decision-free code is still reference/proof, still handed off.** Implementing a decision-free item during `prepare` does **not** make it "completed work" — it stays reference / proof-of-feasibility and is handed off at converge like any other branch; the human still re-decides and owns the landing. The *only* path that carries work to completion is the human-marked maintenance exception. So "implement the decision-free items" means "prove them with working code," not "finish and ship them."

`prepare` **does NOT self-wake** — a SKILL.md is a prompt loaded into a running agent and cannot schedule itself. Cadence always comes from an external driver on the provisioned machine — local cron / `/loop` / `/schedule`.

1. **Fetch first** (`git fetch --prune <remote>`), resolving `<remote>` + `<default>`, so every read below uses fresh remote-tracking refs, not a stale checkout.
2. Read `policy.md` + guidance from the **fetched default ref** (yields the work + `## Accepted Prefixes`, `## Push`, `public-branch-tsugu`, `coordination-ref`, `stale-after`, among others).
3. **Read the queue from work-prefix refs, local + remote** (plus `knowledge/` from the coordination ref). There is no committed note layer — the queue *is* the set of work branches. Under local-first, work **stays on local** `prepare/*` by default, so discovery must read local work refs too; remote work refs are still read **regardless** of the push default (a leftover or opt-in-pushed remote `prepare/*` must still be seen). Mechanics (the local + remote union by slug) → `references/git-recipes.md`.

   **Partition each work branch `<work-prefix>/<slug>` by two ref-level facts, checked in order** — there is **no written branch state**:

   | Fact | State | Disposition |
   | --- | --- | --- |
   | tip contained in `<remote>/<default>` (or its remote aliases) | **settled** — the work landed | skip; `prune` cleanup candidate |
   | a slug-paired branch (by name) exists under a configured `## Accepted Prefixes` **OR** any **non-default, non-work** branch contains the tip | **decided / taken over** — a human carried the work onto their own branch | skip as a candidate; surfaced at `prune`/`converge` (see *taken-over*, Change C) |
   | none of the above | **in progress** | candidate: read `context.md`, judge from the narrative |

   **Takeover by containment (Change B).** A `prepare/<slug>` is **taken over** when its tip is **contained** by a **branch** that is neither the default (nor its aliases `<remote>/<default>` / `<remote>/HEAD`) nor a work-prefix ref (local *and* remote `<work-prefix>/*`). This **generalizes** 011's accepted-prefix slug-pairing to a **human's own-named branch** (`isaac/fix-thing`) — the #52 gap where slug-pairing alone could not see the take. **Slug-name pairing stays** as the complementary catch for the squashed / rewritten take (where the human's branch no longer contains the tip but the name still pairs). The precise check — fresh `git fetch --prune` first, `git for-each-ref --contains` scoped to `refs/heads`/`refs/remotes`, the `<remote>/` prefix normalized before matching, default aliases + local-and-remote work refs excluded — lives in `references/git-recipes.md` (do not re-derive here). **Git-native, script-free:** this is one native `git for-each-ref --contains` plus inline filtering, documented as a recipe, **not a shipped script** (tsugu ships no scripts).

   **Classification is per-ref (per-tip), not per-slug.** The local + remote union-by-slug is a **display** merge only; the settled / taken-over / in-progress predicates each run on a **specific tip**. When the local `prepare/<slug>` and a stale `<remote>/prepare/<slug>` **diverge**, classify **each ref by its own tip**: a stale remote tip contained by a human branch is *taken over*, but a **newer local** in-progress tip that nothing contains stays workable — never mark the local in-progress ref taken-over from the remote tip's containment. The slug-level view shows both, flagged.

   Containment is `git merge-base --is-ancestor` / `git for-each-ref --contains` against remote-tracking refs (mechanics → `references/git-recipes.md`). Five notes, condensed:

   - **Pending pairs by slug, not commits.** The accepted branch shares the work branch's slug; ref names are write-once identity, so the pending state survives anything the forge does to commits (PR-branch rebases, squashes, force-pushes). Containment in refs *outside* the configured accepted prefixes is the **takeover** signal (Change B), not a *pending* signal — pending is derived from the slug pairing, not from foreign containment.
   - **Core assumes merge commits.** Tsugu **recommends merge commits — do not squash-merge tsugu-managed branches**; preserved history is what makes settlement containment-derivable. Accept is **mode-agnostic** (the work branch is renamed to the accepted branch in **both** `include` and `exclude` mode — see converge / Change B), so settlement reads off the **accepted branch's** containment in default in both modes. Because that disposition can only be read *while the slug-paired accepted ref survives*, **recommend disabling the forge's auto-delete-head-branch for tsugu accepted branches**. *A landing that rewrites history (squash, rebase-before-merge, force-push) — or, in `exclude` mode, the human stripping `.tsugu/` into a fresh published branch before merging — breaks containment-derived settlement; the item then settles via `prune`'s possibly-landed (no containment) — confirm bucket; see `references/advanced.md`.*
   - **No marker — the partition + conservative judgment guard (see B1a).** Default handoff writes **no** marker (it renames and stops). A scheduled `prepare` is kept off handed-off work by the two-fact partition: **containment** (a merge-commit landing → settled) or **slug-pairing** (the retained accepted branch, **enumerated local + remote** → decided). For a **non-containment landing** (a rewrite, or an `exclude`-strip) the retained accepted branch still pairs by slug; the advanced narrative backstop is only a **legibility** note on the accepted branch, **not** a resume-guard (a note there can't reach a surviving remote `prepare/<slug>`). The one signal-less residual is the accepted ref **deleted** *and* B3 not yet run, so a stale remote `prepare/<slug>` survives: held to the **same 004–008 guarantee level** — `prepare`'s judgment leans conservative (leave the stale branch for `converge`; reversible; never auto-merges), and running **B3 promptly** removes the ref (once no ref survives, the item just leaves the partition — the work is already in `<default>`). *Judgment, not a written status, governs.*
   - **Out-of-band PR closure (a forge-side decline, outside `converge`).** Distinct from the `drop` disposition (§ converge step 4): the human closes the PR and deletes the accepted branch *on the forge*, dissolving the slug pairing. **If a work ref still survives** (e.g. the stale remote `prepare/<slug>`, B3 not yet run), the item **resurfaces at the next `converge`** for re-decision — never auto-resumed by a scheduled `prepare`. **If no ref survives**, it simply leaves the partition (nothing to resurface).
   - **Recency claims + zero-commit exemption.** Claims are **derived from commit recency** (see Multi-agent): the `context.md` rewrite commit's author and timestamp *are* the claim. A branch whose tip still equals the default tip is **never classified by the table** — it is interrupted work or a **request-by-branch** (a human pushed `prepare/look-into-X` as the ask), never a cleanup target; it carries no recency until someone commits to it.

4. **Bootstrap personal config (interactive only).** Personal config lives in a global, project-keyed folder (`~/.claude/tsugu/<project-key>/`; `<project-key>` derives from the repo's absolute common git dir, so every worktree of one repo shares one folder per machine — see `references/policy-and-intake.md`). It does not transfer across machines, so each machine seeds its own. When a section is absent **and** the run is interactive, ask **once**, separately for the two sections:

   - **sources** — *"Any observation sources to read besides git? A file path, MCP tool name, or where to look. I resolve the `read:` pointer with my own permissioned tools, never auto-executing it from config."*
   - **skills** — *"Any user-installed skills you trust me to use here during human-absent `prepare`? (default: none.)"*

   Record each answer in the personal folder; **a negative answer is recorded as a confirmed-negative marker** (`sources: git-native (confirmed)` / `skills: none (confirmed)`) so it is never re-asked — an unset section is distinct from a confirmed-empty one. When **headless/non-interactive**, never block: fall back to git-native (no sources, no opt-in skills) and surface "personal config unconfigured on this machine" at the next `converge`. Then **resolve** each configured source's `read:` pointer with your normal permissioned tools — read a file, call an MCP tool, or (only where a command is genuinely needed) issue it as your own gated tool call; Tsugu never directly executes the pointer string. **A source signal becomes a `prepare/<slug>` branch directly** — there is no committed note first.

5. Open work branches or worktrees **with native git** (`git worktree add`), naming them with the **work prefixes configured in `policy.md`** (default `prepare/*`) — discovery filters by the configured prefixes, so a hardcoded prefix that differs would be invisible to the next cold start. Then reproduce, inspect, run tests, try reversible patches.
6. Dispatch your **own review/investigate subagents** (built-in Task agents) when a change deserves a second pass before the human sees it — they work **inside the `prepare/<slug>` branch / its worktree**, recording findings in the work branch's `context.md` (and promoting durable findings to `knowledge/`), not as a separate same-slug branch. This is Tsugu working in private git space; it is distinct from the human-triggered review-loop, which the human triggers — Tsugu never runs it for them.
7. Maintain **`context.md`** on the work branch (pure narrative — rewrite the inherited mainline form into the branch's own story; that first rewrite commit *is* the claim). Promote durable, shareable findings into `.tsugu/knowledge/`. Refresh the convergence **packet** (`packets/<slug>.md`) in the **personal folder** — it is a personal/derived view, never committed.
8. **Commit the work branch (`<work-prefix>/<slug>`) — local-first.** `prepare` is **local-first by default**: commit the local work branch and **keep work local** — **push only when `push-prepare-branches: yes`**, a **cross-machine opt-in**. Read `## Push`'s `push-prepare-branches:` from the fetched policy **schema-aware**: when the field is **absent**, the default is `yes` if the repo is still `tsugu-schema: 4`, else `no` (a schema-5 repo defaults `no`; the 4→5 migration pins the explicit `yes` into existing repos so behavior never flips silently). If `yes`, `git push --set-upstream <remote> <branch>` — in the **cross-machine** case pushing is what lets a *second machine's* agent inherit the work (there, the branch *is* the message); on one machine the local branch already *is* the queue. If pushing is set but otherwise **not** permitted by the boundary, commit locally and stop for approval (or use the policy-defined alternative) — never push past an explicit boundary.

   **Auto-push invariant (Change D).** `prepare` **auto-pushes only the `<work-prefix>/*` branch it is working**, and only when `push-prepare-branches: yes`. It **never auto-pushes** an accepted-prefix or human-named branch — publishing those is the human's act (011's B3, print-only). The sole exception — a cross-machine **agent-to-agent** push with no human present — is **deferred** to *Multi-agent: reserved*; absent that opt-in the invariant holds unconditionally, so "the agent pushes an already-converged local branch" cannot happen.
9. **Recurse into submodules (omni-repo).** After working this repo's own queue,
   **if this repo's own `## Recursion` permits descent** (default: only when
   relevant), enumerate submodules and gate each on a **readable `.tsugu/policy.md`**
   (three outcomes: HAS / BARE / **INVALID** — a `.tsugu/` without a readable
   `policy.md` is surfaced, never treated as bare) — that gate, not the submodule's
   own policy, decides recurse-vs-meta-drive. A **HAS-`.tsugu/`** submodule takes the
   **recurse-and-run** path — run this whole `prepare` routine inside it
   (`git -C <submodule>`) using the submodule's own policy + personal-config intake;
   it runs at its own schema (never force-migrated). For a **bare** submodule, the
   branch still lands **in the submodule** but **meta** policy governs it and the
   findings ride a **paired meta `prepare/<slug>`** (gitlink bump + `context.md`).
   The branch always lands at the lowest repo owning the **code**; `.tsugu/`
   knowledge lands at the lowest repo that **has** a `.tsugu/`. **Ask, don't guess:**
   when a bare submodule's default branch is ambiguous or a rule isn't covered by
   meta policy, ask the human if interactive, else leave the item unbranched for the
   next `converge`. Mechanics → `references/git-recipes.md` (§ Submodule recursion).

### `converge` (human present)

The human-attention phase. **Tsugu presents and yields, then completes the decided disposition in-session — it invokes no skill here.** The human triggers the skill they want by keyword ("let's brainstorm this", "debug it", "/review-loop"); the ecosystem takes over. `converge` runs decision *and* completion in one human-present session.

1. **Fetch-first** (same read path as `prepare`): resolve `<remote>` + `<default>`, `git fetch --prune <remote>`, read everything from remote-tracking refs. **Read each tsugu branch live** (its `context.md` + DAG state) to assemble the picture — a `converge` on machine B reconstructs the full state from `git fetch` alone, never from machine A's packet. Any cache stays personal/ephemeral (the chat session or the global folder), never a committed `.tsugu/` artifact.
2. **Ask which branch.** List the candidate work branches (those the partition classifies as in progress, enumerated across **all** configured work prefixes (default `prepare/*`)), each with a one-line `context.md` summary and packet hint, and ask the human which to converge. An explicit branch argument (`/tsugu:converge <branch>`) skips the question. Alongside the candidates, show two more sections:
   - a separate **awaiting-merge section** — decided branches are not candidates, but listing them surfaces an orphaned accepted branch (pushed, then the session died before its PR opened); when `gh` is available, flag awaiting-merge items lacking an open PR. Also flag a possible **name collision** — an accepted tip sharing no history with the same-slug work it claims to carry — **in both modes** (accept renames the work branch to the accepted branch in include *and* exclude, so this check is no longer `include`-only). Work-vs-accepted *divergence* no longer arises: the rename means there is no separate work branch to diverge from the accepted one.
   - **a stale flag on the candidate list, not a separate block** — a candidate whose last activity predates `stale-after` (default 30 days; recorded progressively in `policy.md` by `converge` on first use) is shown with a **"stale" marker** and handled by the normal accept / park / drop / continue dispositions. Staleness is **derived** (last-commit timestamp, the same recency mechanism as claims); there is no dedicated converge cleanup block. The queue-wide read-only sweep of unused branches now lives in `/tsugu:prune`. **A scheduled `prepare` never cleans on its own.**
3. Regenerate the **personal packet** live from the branches and lay it out alongside the prepared branches/worktrees and a summary of what was tried / worked / failed / evidence / remaining uncertainties; surface open questions (including any personal config unconfigured on this machine).

   Steps 1–3 touch **no git or shared state** — they make no commits, no pushes, no public coordination; regenerating the personal packet writes only a derived, ephemeral view in the personal folder (not a shared artifact, so it is not a meaningful side effect). In that sense running `/tsugu:converge` just to look is a first-class use — **looking and leaving is the morning status view**: how many prepared branches are workable today, what awaits merge, what's stale. Choosing nothing and leaving is a valid outcome; **all shared/git side effects begin only at step 4's disposition**.
4. **Decide *with* the human, then complete the disposition in-session:**

   - **Accepted — default handoff (mode-agnostic):** accept is a **minimal handoff** — **rename** `prepare/<slug>` → `<accepted-prefix>/<slug>` and **stop**. The agent does **NOT** freshness-rebase, build/test, rewrite `context.md` to a mainline narrative, push, or open a PR — completion is the human's. (One *optional* exception to "no write": when a **history-rewriting landing is anticipated**, the advanced narrative backstop MAY add a one-line *"handed off — may have landed via squash/rebase"* **legibility** note to `context.md` — it is not a resume-guard; see the backstop note below and `references/advanced.md`.)
     - **B1 — rename (move, not a copy), cold-start safe.** The move renames only the **prefix**, preserving the slug. On the machine that prepared it: `git branch -m prepare/<slug> <accepted-prefix>/<slug>`. On a cold-start machine where only `<remote>/prepare/<slug>` exists: `git branch <accepted-prefix>/<slug> <remote>/prepare/<slug>` (the *move* completes when the human deletes the remote `prepare/<slug>` — B3). `prepare/<slug>` does **not** survive beside the accepted branch — it is a **move, not a copy**. `<accepted-prefix>` comes from `policy.md`'s `## Accepted Prefixes` (default `feature/* bugfix/* chore/*`). **Before renaming/creating, check no `<accepted-prefix>/<slug>` already exists** (local or remote) — a collision means the slug is already in flight; surface it rather than clobber.
     - **B1a — the handoff-pending window needs no new marker.** Between the local rename and the human's remote reconcile (B3), `<remote>/prepare/<slug>` still exists, so a scheduled `prepare` could rediscover it. The **existing two-fact partition** already guards this, checked in order: (1) **containment** — after a merge-commit landing the work tip is contained in default → settled → skipped; (2) **slug-pairing** — the local `<accepted-prefix>/<slug>` from B1 pairs immediately (the partition enumerates accepted-prefix branches across **local + remote** refs), remotely once the human pushes (B3). No new marker is added. (A *second machine* running `prepare` in the pre-push window — when the accepted branch is local-only on the converge machine — is the **deferred multi-agent concurrency case**, see *Multi-agent*; single-agent / single-machine is fully guarded.) The residual (a history-rewriting landing **and** the accepted branch deleted) is held to the **same 004–008 guarantee level**: with the accepted ref gone, `prune`'s *possibly-landed* bucket **can't** derive it (that bucket needs a *surviving* accepted ref) — so the recourse is `prepare`'s **conservative judgment** (leave it for `converge`, never auto-resume) plus **B3** removing the stale ref. (Where the accepted ref is instead **retained**, `prune`'s possibly-landed-confirm bucket is the clean recourse.)
     - **B2 — mode-agnostic.** The rename is identical under `public-branch-tsugu: include` and `exclude`; the exclude-mode by-path **clean-cut** accept path is **removed**. The `.tsugu/` exploration commits **ride along** on `<accepted-prefix>/<slug>`; since the human owns everything after handoff, the human decides whether to strip `.tsugu/` when *they* open their public PR. (This narrows `exclude`: it still governs whether `.tsugu/` rides the default branch, but converge no longer cuts a `.tsugu/`-free handoff branch.)
     - **B3 — remote reconcile is a prompt, never a silent op.** After the local rename the remote still has the stale `prepare/<slug>` and lacks the accepted branch. The agent **surfaces the commands for the human** (resolving `<remote>`) and **prints these** — it does **not** run them:
       ```bash
       git push --set-upstream <remote> <accepted-prefix>/<slug>
       git push <remote> --delete prepare/<slug>
       ```
       **Local-first note (Change A):** under the default local-first policy there is **no remote `prepare/<slug>`** to delete (it was never pushed), so B3 shrinks to just the accepted-branch push. The remote-prepare-delete line above survives only in a **cross-machine opt-in** repo (`push-prepare-branches: yes`), where 011's full B3 applies unchanged.
     - **B4 — prune reminder.** Close the handoff with: *"handed off; once you've pushed `<accepted-prefix>/<slug>` and the work lands, run `/tsugu:prune` to sweep the stale `prepare/<slug>` and the settled branch."* No branch is prunable **at handoff time** (the human hasn't pushed yet and nothing has landed), so this points at `prune` for *later*; it asserts no current count.
     - **B5 — no settlement tracking; the old completion tail is dissolved.** After the rename the local `prepare/<slug>` no longer exists; the item leaves the queue once the remote work ref is gone (B3). `converge` keeps **no** named completion tail — promotion moves to curation (the orthogonal `promote`, below) and cleanup moves to `/tsugu:prune`. Whether `<accepted-prefix>/<slug>` later lands is **the human's** concern; its settled-ness is read **later, by `prune`** (via containment, or its possibly-landed bucket where history was rewritten), never actively tracked here. State stays derived, never a status field.
   - **Maintenance exception — human-marked tasks may complete (default stays handoff).** The **complete** path (rename first → then bring the accepted branch current and verified to ready-to-merge per the maintenance recipe in `references/git-recipes.md`) is unlocked **only when the human has explicitly marked the task as maintenance-type** — never the agent's call. Two designation channels: (1) **human-authored task-source designation**, captured at intake and recorded **verbatim** in the branch's `context.md` narrative (e.g. *"human-marked maintenance (security upgrade) — completion authorized; source: <where the human marked it>"*) — the agent **must not synthesize** the designation from the work's content (a diff that *looks* like a dependency bump is not self-authorization); (2) **live at converge**, the present human says "this one's maintenance — take it to completion." **Provenance fallback:** if the agent cannot tell whether a label was applied by a human or by automation, it does **not** treat it as authorization — it falls back to channel 2 (ask live); **ambiguous provenance defaults to handoff, never completion.** The complete path still **renames first** (B1, so `prepare/<slug>` is gone either way), still surfaces the B3 prompt and the B4 prune pointer, and **Tsugu still never auto-merges** — "ready-to-merge" means accepted-branch readiness (rebased + verified), not a clean public diff; an `exclude`-mode repo's human still strips `.tsugu/` when they open the public PR. The agent **never self-classifies** a task as mechanical; absent an explicit human marking → default handoff (B). Cleanup of the resulting branches is deferred to `/tsugu:prune`.
   - **Accepted (bare-submodule paired branch) — also a handoff.** Under handoff-only
     there is no agent-driven two-repo landing transaction. At submodule converge the
     submodule's `prepare/<slug>` is simply **renamed to a human work branch**
     (`<accepted-prefix>/<slug>`) **in the submodule**, and stops —
     the **meta repo no longer manages it** (to the meta repo it is just "a human work
     branch now exists in the submodule"; no agent-driven gitlink re-point). The cross-repo landing (gitlink
     bump, both PRs) is **the human's** when they finish the work. The existing **paired
     meta `prepare/<slug>`** is **not auto-managed** here — it remains a normal candidate
     classified by the **same existing meta partition** (containment, then slug-pairing;
     no new marker) that surfaces at the **meta** repo's own `converge` (and at `prune`).
     The maintenance exception still applies per-repo if the human marked that work
     maintenance-type. Full procedure → `references/advanced.md` (§ Bare-submodule
     handoff). Drop / park / continue each act on **both** branches of the pair. Note:
     meta `converge` does **not** aggregate HAS-`.tsugu/` submodules' own queues —
     converge those by running `/tsugu:converge` inside each submodule.
   - **taken-over — suppress-and-surface, human-confirmed cleanup (Change C).** A `prepare/<slug>` whose tip a **non-work, non-default branch** contains is **probably redundant** (a human carried the work onto their own branch), but containment is **not proof** — a scratch/experiment branch or a sibling item based *on top of* the tip also contains it. So the disposition **never silently drops and never auto-deletes**: the agent **does not auto-resume** it, but it is **surfaced** at `prune`/`converge` for the human to **confirm or reject** — a real takeover → cleanup; a false-positive (build-on-top, sibling item) → the human says "keep working" and it returns to *in-progress*. A scheduled (human-absent) `prepare` simply **leaves it for `converge`**. On confirmation the redundant ref is removed **local *and* remote, both human-confirmed** — local too, because a wrong guess would destroy the queue identity (slug + `context.md`-as-claim) of still-in-progress work.
   - **drop:** record *why* in the branch's `context.md` narrative ("dropped — do not resume: <why>"; agents read the narrative before touching any candidate), remove worktrees, delete the branch when safe. (Renamed from `reject`; the "record why" narrative is retained.)
   - **park:** update `context.md`'s narrative with what is needed to resume, and the personal packet. No status to set — a parked branch is simply a candidate whose narrative says "blocked on X".

   **`continue` is implicit.** Every branch the human does **not** act on is already "continue" — it stays an in-progress candidate. Steps 1–3 above (the looking-and-leaving morning status view) touch no git or shared state, so a `converge` that decides nothing leaves every branch continuing by default. `continue` is therefore **not** a named verb; its only active form is the human triggering a workflow skill on the branch *now* ("let's brainstorm this", "/review-loop") — which Tsugu does not fire itself.

   **Findings curation is an orthogonal converge checklist item.** Promoting durable findings is **not** a sibling disposition in a pick-one list — **curation is orthogonal**, a converge checklist item (not a fifth verb): it rides *any* disposition ("**drop** the branch yet **promote** the lesson" is valid) and may also run standalone during the morning view. When there is nothing worth promoting it is a no-op. **Flow:** surface (a) this work's durable findings (from the branch's `context.md` / knowledge additions) **and** (b) existing `.tsugu/knowledge/` entries → ask the human **which should be organised into the agent md** (`CLAUDE.md` / `AGENTS.md`) → the **agent drafts** the edit → the **human approves** (moving findings into human-facing docs is public coordination → ask first).

   **The `knowledge/` ↔ agent-md boundary (a finding lives in exactly one place).** The two stores are not interchangeable and promote runs **one direction only**: `knowledge/` holds **WIP / still-evolving / cross-cutting** findings (the working wiki); the agent md (`CLAUDE.md` / `AGENTS.md`) holds **durable, human-endorsed conventions**. **Promote = move, not copy** — graduate `knowledge/` → agent md once a finding has stabilised into a durable convention the human endorses, then **remove it from `knowledge/`** (at most leave a pointer); there is no reverse direction. A **write-gate** keeps not-yet-durable or already-recorded facts out, and promote-as-move keeps a finding in **exactly one place**, never both. (Details → `references/notes-and-packet.md`.)

   **Invariant.** None of accept / park / drop / continue / promote sets a *status field*. Each produces a branch action (accept/drop), a narrative write (park, drop's reason), or a knowledge write (promote); state stays **derived** from refs, the DAG, containment, and recency. *Narrative informs judgment, never classification.*
5. **Wait for approval before any public coordination** — opening/merging the PR is the human's act; **Tsugu never auto-merges**.

The packet may **hint** which workflow skill fits ("ready for planning", "this bug needs debugging", "this can go to review-loop") but must not fire it.

### `prune` (human present)

A **fourth** routine — **not** part of the per-item lifecycle the way `prepare` / `converge` are; it is a **recurring cleanup pass** the human runs when refs have piled up. A queue-wide, **human-present** sweep of unused branches (**local + remote**) — the home for the destructive cleanup that per-branch `converge` (now handoff-only, no tail) and a never-cleaning scheduled `prepare` leave to accumulate. **Small: a view + approve-delete, not a new workflow.**

1. **Listing is read-only until the human confirms.** Like the morning view, steps before deletion touch no state — `prune` lists what is removable and **why**, derived from refs / DAG / containment / recency. **`prune` is human-present and deletes nothing without per-item human confirmation** (running it just to look is fine). A narrative hint like "do not resume" is **surfaced for the present human to confirm**, never an auto-classifier that deletes on its own. *Judgment by a present human, not classification by a status field.*
2. **What `prune` lists, and how each is handled** — **conservative by default**; under the handoff model the human owns the branch after the rename, so most categories are **surface-and-confirm**:

   | Category | Derivation | Handling |
   | --- | --- | --- |
   | **settled** | tip contained in `<remote>/<default>` — the human merged with history intact | **delete on confirm** (low risk — provably landed). Local + remote. The main post-handoff target |
   | **taken-over (redundant prepare)** | a `prepare/<slug>` (local or remote) whose tip a **non-work, non-default** branch contains — a human carried the work onto their own branch | **surface + confirm each** (like *possibly-landed*) — never auto-delete; the containment signal can false-positive on a build-on-top branch. On confirm, delete local + remote. **Precedence:** if `<remote>/<default>` contains the tip it is **settled** (above); *taken-over* covers only the case where the containing ref is a **non-default** branch |
   | **leftover worktree** | a worktree dir whose branch is already deleted | **delete on confirm** (just a stale checkout dir) |
   | **possibly-landed (no containment)** | a surviving `<accepted-prefix>/<slug>` whose tip is **not contained** in default and whose landing **can't be confirmed by containment** (squash / rebase / `.tsugu/`-strip) — whether its remote counterpart was deleted **or** the ref was *retained* per the rewrite/strip recommendation | **surface + confirm each** — `prune` cannot prove it landed, so it asks; never auto-deletes on a guess |
   | **dropped** | the branch's `context.md` says "do not resume" | **surface + confirm** — the backstop for branches converge's `drop` recorded but could not delete (a remote ref, a deferred cleanup) |
   | **orphaned accepted** | a pushed accepted branch with no open PR and no recent activity | **surface read-only + confirm** — often the human's **live** work branch, so never auto-eligible |

   Deletion is **per-item or batch**, on explicit confirmation. **Remote deletes: `prune` runs `git push <remote> --delete <branch>` after explicit per-item human confirmation** — the confirmation *is* the approval. This differs from converge **B3**, which only *prints* the remote-delete command (mid-handoff, precondition not yet met). The unifying rule: **no remote delete without explicit human approval**. Cleanup order is the established one: `git worktree remove` **before** `git branch --delete`.
3. **Conservative — never deletes unfinished work.** `prune` **never deletes** in-progress, recent, or unsettled work. **Stale in-progress** branches (older than `stale-after`, but not landed) — including **scope-only** branches (Change A), handled identically — are **surfaced read-only** and marked *"not deletable here — decide at `converge`."* `prune` only *points*; the resume / park / drop decision happens in `converge`'s normal candidate flow.

Mechanics (containment + slug-pairing reads; the delete-on-confirm vs surface-and-confirm categories; remote delete after per-item confirm) → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/git-recipes.md` (§ Prune sweep).

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
- **Cross-machine `prepare/*` push is the opt-in reserved here.** Under local-first (Change A) `prepare` keeps work local by default; `push-prepare-branches: yes` exists for genuine **cross-machine agent collaboration** (machine A prepares, machine B inherits via `git fetch`). The auto-push invariant's **sole exception** — an agent pushing a coordination ref *for another agent* with no human present — is this deferred case; it is not built further here, the knob is the opt-in.
- The substrate (committed + pushed `.tsugu/`, branch-as-message, per-ref `context.md`, ref-and-DAG-derived state) is **forward-compatible** with multi-peer coordination; this design introduces nothing that assumes a single agent.

## Scheduling & recursion

**Scheduling.** `prepare` is meant to run on a cadence, wired by an external driver **the human starts** — a local cron, or `/loop` (cloud `/schedule` works too). But the skill **cannot self-wake** — the driver is always external. The skill depends on no scheduler. **Recommended default locus:** the **provisioned machine** — the one holding **both** the personal-folder source config (the `read:` pointers, never committed) **AND** the MCP/connector credentials, typically the local homelab — since `prepare`'s useful signals come from interactively-authenticated sources and neither dependency transfers across machines. An **unprovisioned** cloud/headless run is still allowed but not the default: it **degrades to git-native** (it works the queue derivable from refs; no tracker/source intake), and the two gaps surface differently — **source config missing** → detectable at any *same-machine* `converge` (the existing "personal config unconfigured on this machine" notice); **credentials missing / MCP auth fails** → reported in the run's **own output only** (the driver's log on that machine), **not** auto-surfaced at a later `converge` — no committed or cross-run diagnostic is persisted (state stays single-layer), and `converge` gains no source-probing scope. The distinction is **provisioning, not cloud-vs-local**: a cloud machine independently provisioned with both does **not** degrade.

**Recursion (omni-repo).** A single repo and an omni-repo are the **same
abstraction**. After working its own queue, `prepare` enumerates submodules and gates
each on a **readable `.tsugu/policy.md`** (HAS / BARE / **INVALID** — a `.tsugu/`
without a readable `policy.md` is surfaced, not treated as bare): a HAS-`.tsugu/`
submodule takes the **recurse-and-run** path (its own policy + intake, its own
schema); a bare submodule is **meta-driven** with
the branch in the submodule and findings on a **paired meta branch** (gitlink bump +
`context.md`). The branch always lands at the lowest repo owning the **code**;
`.tsugu/` knowledge at the lowest repo that **has** a `.tsugu/` (else it bubbles up).
The **parent's own `## Recursion`** toggle governs whether it descends at all ("only
when relevant"); descent into a bare level goes **one level deep** (direct child
only). **Context placement rule:** write context at the **lowest repo level where it
stays true**; promote upward into `.tsugu/knowledge/` only when it spans repos.
Mechanics → `references/git-recipes.md` (§ Submodule recursion); handoff →
`references/advanced.md` (§ Bare-submodule handoff); graduation →
`references/notes-and-packet.md` (§ Graduation).
