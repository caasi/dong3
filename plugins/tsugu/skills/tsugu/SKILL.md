---
name: tsugu
description: Git-native preparation & convergence — carry work forward across the gap when no human is watching, the handoff to a human, and the resume by whoever comes next. Use to prepare work before review, settle converged work into clean public form, or run the lifecycle via `/tsugu [init|prepare|converge|settle]`. Triggers on "prepare work before review", "carry work forward", "git-native preparation", "init/prepare/converge/settle", or "/tsugu". Human-triggered and schedule-wireable (wire `prepare` to `/schedule`/cron). Invokes no user-installed skill by default — native git + its own built-in subagents only. Never auto-merges and never performs public coordination without approval.
---

# Tsugu — 継ぐ (prepare & converge over git)

## 継ぐ (tsugu)

**継ぐ** · つぐ / *tsugu* · to **inherit**, **continue**, **carry forward** (succeed to a role). The name is the intent: work is carried forward rather than restarted —

- **inherit** — a cold-start or *different* agent inherits the work from git + `.tsugu/` alone, with no conversation transcript;
- **continue** — `prepare` continues the work while human attention is absent, leaving reversible evidence instead of an empty task description;
- **carry forward** — `settle` carries the prepared, converged work into clean public form and promotes what is worth keeping.

**Git's DAG is the medium of inheritance.** A branch is a unit of work one agent hands to the next; committed `.tsugu/` notes are the memory that outlives the session that produced them.

Tsugu prepares the board. Workflow skills play the game with the human. Tsugu settles the result. It is **not** an implementation methodology — it does not debug, plan, test, review, or implement; it prepares their input and settles their output.

## The spine

**Git itself is the message bus.** `git fetch` surfaces new/changed branches and newly committed `.tsugu/` notes — that *is* the inbox. A pure-Tsugu workflow coordinates through git alone, with zero external integrations.

- **`.tsugu/` is committed shared memory**, not local scratch. A branch or worktree is "a message with executable evidence."
- **External tracker observation is an OPTIONAL human-bridge, never the spine.** Jira / GitLab / GitHub issues / CI / CVE feeds are a shim whose only job is to convert a human-world signal into the git-native substrate (a committed `.tsugu/intake/` note, optionally a seed branch). Once converted, every downstream step is identical. Pure-Tsugu users skip this layer entirely.
- **Legibility is a hard constraint:** branch names + `.tsugu/intake/` + `.tsugu/branch.md` must let an agent that has only run `git fetch` reconstruct "what branches exist, why, and what's next" with no transcript. git-native intake depends on it.

## Routing

`/tsugu [init|prepare|converge|settle]` — one lifecycle, four routines:

- **init** — first-run setup; ask the minimum, write the `.tsugu/` skeleton + policy.
- **prepare** — human-absent: read the queue from git, work it privately, leave evidence.
- **converge** — human-present: present the packet and yield; the human drives.
- **settle** — carry the decided outcome forward (Accepted / Rejected / Paused).

Mechanics are deferred — do not re-derive git commands here:

- Exact git (fetch → read-queue-from-remote-refs, coordination-ref writes, cut-clean-public-branch, freshness rebase, cleanup order, init skeleton) → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/git-recipes.md`.
- `policy.md` fields + intake interface (incl. the human-bridge) → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/policy-and-intake.md`.
- `branch.md` / `intake` / `runs` / `packet` / `context` structure → `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/references/notes-and-packet.md`.
- `init` writes the repo's `.tsugu/` files from `${CLAUDE_PLUGIN_ROOT}/skills/tsugu/templates/`.

## The four routines

### `init`

Runs when a repo has no `.tsugu/`. Capture the **minimum** preferences for safe unattended prep — ask only a few: may agents create/commit/push prep branches automatically? which public actions need approval (default: MR/PR, tracker comment/status, reviewer assignment, Slack, public commitments)? branch prefixes (default `prepare/* investigate/* review/* public/*`)? recurse into submodules (default: only when relevant)? intake sources (**default: none** — git-native only)?

Then write the `.tsugu/` skeleton + `policy.md` from the plugin templates (seed each empty dir with a real file — git can't track empty directories).

- **Idempotent:** re-running on an initialized repo *repairs* missing skeleton paths and is otherwise a no-op; it **never overwrites** a curated `policy.md`.
- **Progressive:** when a new situation appears, ask once, record the rule in `policy.md`, let future agents inherit it.
- **Push-protected default:** the fixed metadata (`policy.md`, `templates/`) must reach the default branch; if it is push-protected, write on an `init/*` branch and open a **human-approved PR**. `prepare` does not run in that repo until the metadata is merged.

### `prepare` (human absent)

The core routine. No human is present, so Tsugu does its own git work directly and may dispatch its **own built-in Task subagents** — but it invokes **no user-installed skill**. Posture: **external silence, internal preparation.** Interrupt the human only if the task is unsafe, destructive, or blocked; when unsure, continue with reversible private git work.

`prepare` **does NOT self-wake** — a SKILL.md is a prompt loaded into a running agent and cannot schedule itself. Cadence always comes from an external `/schedule`/cron driver.

1. **Fetch first**, resolving `<remote>` + `<default>`, so every read below uses fresh remote-tracking refs, not a stale checkout.
2. Read `policy.md` + guidance from the **fetched default ref** (yields prefixes + `coordination-ref`).
3. **Read the queue from remote-tracking refs**, plus `context/shared/` from the coordination ref. Partition by `branch.md status` × `claimed-by`:

   | status | claimed-by | disposition |
   | --- | --- | --- |
   | `open` | empty | **pick up** |
   | `open` | non-empty, **recent** `claimed-at` | **yield** (taken) |
   | `open` | non-empty, **stale** `claimed-at` | **pick up** — reclaim (re-set `claimed-by`/`claimed-at`) |
   | `paused` | — | **resume** (rebase onto default first) |
   | `converged` | — | skip (awaiting human) |
   | `settled` | — | skip (done) |

   Plus `intake/` notes with `status: open` and no linked branch = unbranched work to consider.
4. Open work branches or worktrees **with native git** (`git worktree add`), naming them with the **prefixes configured in `policy.md`** (defaults `prepare/*` / `investigate/*`) — discovery filters by the configured prefixes, so a hardcoded prefix that differs would be invisible to the next cold start. (Same applies to the `public/*` / `review/*` prefixes in `settle` and review-subagent dispatch.) Then reproduce, inspect, run tests, try reversible patches.
5. Dispatch your **own review subagents** (built-in Task agents) when a change deserves a second pass before the human sees it — they return `review/*` branch/worktree artifacts, not prose-only reports. This is Tsugu working in private git space; it is distinct from the human-triggered review-loop, which the human triggers — Tsugu never runs it for them.
6. Write `runs/` notes; maintain `branch.md` (set `status`, and `claimed-by` + `claimed-at` when active work begins — courtesy, see Multi-agent); create/update the convergence **packet**.
7. **Commit the `prepare/*` branch; push it if policy permits.** Check the fetched `policy.md` Private-Git-Space boundary (the `init` answer to "may agents push preparation branches automatically?"). If yes, `git push --set-upstream <remote> <branch>` — cold-start discovery enumerates only remote-tracking refs, so pushing is what lets the human or next scheduled agent inherit the work (the branch *is* the message). If pushing is **not** permitted, commit locally and stop for approval (or use the policy-defined alternative) — never push past an explicit boundary.

### `converge` (human present)

The human-attention phase. **Tsugu presents and yields — it invokes no skill here.** The human triggers the skill they want by keyword ("let's brainstorm this", "debug it", "/review-loop"); the ecosystem takes over.

1. Lay out the relevant packet, prepared branches/worktrees, and a summary of what was tried / worked / failed / evidence / remaining uncertainties.
2. Surface open questions and decisions.
3. Decide *with* the human which prepared changes become public.
4. **Wait for approval before any public coordination.**
5. Once the human has decided a disposition, set the branch's `branch.md status: converged` — the transition that writes the `converged` state the prepare table skips — then **commit and push that transition** (policy permitting). For a pushed branch, a local-only status change leaves the remote `branch.md` at `open`, so a scheduled `prepare` reading remote refs would pick the already-decided work up again.

The packet may **hint** which workflow skill fits ("ready for planning", "this bug needs debugging", "this can go to review-loop") but must not fire it.

### `settle`

Three outcomes write a terminal status — Accepted/Rejected → `settled`, Paused → `paused` — and, **if the work has a linked intake note, also close it on the coordination ref** (`claimed → done` on Accepted, `→ dropped` on Rejected) so finished items don't linger as active in the durable inbox. **Timing matters: write the terminal `settled` (and close the intake note) only AFTER the public branch is cut and verified** — if patch-apply/build/tests fail, leave the branch `open`/`converged` and the intake `claimed` so the work stays in the queue rather than vanishing. (Paused/Rejected write their terminal status up front.) ⚙ = agent-mechanical (private git); 🔒 = human-triggered/approved.

**Accepted:**
1. ⚙ Cut a clean `public/*` branch fresh from the **fetched** `<remote>/<default>` (not a stale local default).
2. ⚙ Apply only accepted code/test/doc/config **by path** — the public branch's diff vs default introduces **no `.tsugu/` changes**.
3. ⚙ Verify (build / tests). **Only once this passes**, write `branch.md status: settled` and close the linked intake note (`claimed → done`) — a failed settlement keeps the work in the queue.
4. 🔒 Opening the PR is human-gated — the human may use `finishing-a-development-branch` or trigger review-loop; **Tsugu does not run them for the human**.
5. ⚙ Promote reusable knowledge to `.tsugu/context/shared/` (commit to the coordination ref).
6. ⚙ Clean up: `git worktree remove` **before** `git branch -D` (never delete a branch a worktree still has checked out).

**Rejected:** record why if it may matter later; archive/delete the packet per policy; remove temp worktrees; delete rejected `review/*` branches when safe; promote only important failure reasons.

**Paused:** set `status: paused`; update the packet; write a run note; list what is needed to resume; leave the branch resumable (it **rebases onto default on resume** — see git-recipes freshness).

## Private vs public boundary & skill use

Recorded per-repo in `.tsugu/policy.md`:

```text
Git branch / pushed branch / .tsugu notes        →  agent may do freely
MR / PR / tracker / Slack / reviewer assignment   →  human approval required
```

**Tsugu invokes NO user-installed skill by default** — present or absent. It uses **native git directly** (worktrees via `git worktree add`, branch/cleanup via plain git / `gh`) and its **own built-in capabilities** (Task subagents, Codex-as-a-tool, Claude's own reasoning). The only asymmetry is *what Tsugu does on its own*:

- **Human absent** (`prepare`, the ⚙ parts of `settle`): work the git tree, dispatch own built-in subagents.
- **Human present** (`converge`, the 🔒 parts of `settle`): present and yield; the human triggers workflow skills by keyword.

Workflow skills (planning, debugging, TDD, finishing-a-development-branch, review-loop) are **human-triggered and optional** — Tsugu never runs them for the human. **Per-repo opt-in (config, not shipped behavior):** a repo MAY, in its own `.tsugu/policy.md` (never in this shipped SKILL.md), list specific user-installed skills Tsugu may use during human-absent `prepare` *in that repo*. The shipped skill stays skill-agnostic.

## Multi-agent: reserved

v1 is a **single agent + its built-in subagents**. The discovery layer is honored (fetch, read branch status, process the queue); concurrent arbitration is **not built**.

- `claimed-by:` + `claimed-at:` in `branch.md` are a **courtesy yield** — set when active work begins, retained as history on settle/pause. A branch with `status: open` and a non-empty, *recent* claim is treated as taken; empty or stale claim = free to pick up. **No lock backs this.**
- **No arbitration, no locks** (deferred to v2). Two agents grabbing the same branch at once is undefined in v1 (doesn't arise with one agent).
- The substrate (committed + pushed `.tsugu/`, branch-as-message, per-branch status) is **forward-compatible** with multi-peer coordination; v1 introduces no design that assumes a single agent.

## Scheduling & recursion

**Scheduling.** `prepare` is meant to run on a cadence, wired by a human to `/schedule` / cron so a cloud agent runs it daily. But the skill **cannot self-wake** — the driver is always external. The skill depends on no scheduler.

**Recursion (omni-repo).** A single repo and an omni-repo are the **same abstraction**. One agent (+ its built-in subagents) traverses the repo tree — working locally, delegating downward into submodules / child repos, and promoting knowledge upward. Recurse into submodules only when relevant to the current goal / intake / branch. **Context placement rule:** write context at the **lowest repo level where it stays true**; promote upward only when the knowledge affects multiple repos or future coordination, so the omni-repo never becomes a junk drawer.
