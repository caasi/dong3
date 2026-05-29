---
name: review-loop
description: General assisted review loop for changes — code or design artifacts (specs, plans, docs). Prefers local reviewers (Claude subagent + Codex in a tmux pane) as the first gate; for GitHub PR targets, also requests Copilot after the PR is open. Loops each reviewer until clean or its usage limit, classifies comments into tiers, auto-fixes mechanical ones, pauses on architectural ones for user judgment. Never merges autonomously.
---

# Review Loop (Assisted)

Assisted, not autonomous. Preserves the author's architectural voice and learning across review cycles. General-purpose: the target may be a **local branch / working diff** (no remote needed) or a **GitHub PR**, and the changes under review may be **code or design artifacts** (specs, plans, docs).

**Local reviewers are preferred and run first.** A Claude subagent and Codex (via the `codex` CLI in a tmux pane) cost nothing extra and are fast, so they are the first gate. GitHub Copilot is added only when the target is a GitHub PR, and only after the local gate is clean.

## Why this loop exists

Claude and Codex reviewing **together** produces noticeably better output than either model alone — they catch different classes of issues, and Codex's pass tightens the diff before it ever reaches GitHub. The downstream payoff: by the time Copilot sees the PR, there's much less for it to complain about, so review rounds converge faster. Front-loading combined local Claude+Codex review as the first gate is the entire reason this loop exists.

## Requirements

- **Always usable:** the Claude subagent reviewer needs nothing extra.
- **Codex reviewer (optional):** a `tmux` session (`$TMUX` set) and the `codex` CLI on `PATH`. Absent either, the Codex step is skipped silently.
- **GitHub Copilot phase (optional):** the authenticated `gh` CLI and `jq`. Only used for GitHub PR targets.

The helper scripts use POSIX-friendly options and resolve `codex`/`gh` from `PATH`, so the skill is self-contained and portable across machines.

## Inputs

- **Target** — one of:
  - a **local diff/branch** (default: current branch vs its base), or
  - a **GitHub PR number** (or a branch that already has an open PR → treat as GitHub target).
  - The diff may contain code, design docs (specs/plans), or both — the loop reviews whatever changed.
- Repo / base branch inferred from the current working directory.

## Reviewer roster & priority

1. **Local Claude subagent** — always. Dispatch a subagent (Task tool) to do the review.
2. **Local Codex** (tmux pane) — when `$TMUX` is set and `codex` is on `PATH`. See A2.
3. **GitHub Copilot** — only for GitHub PR targets, after the PR is open.

## Helper scripts

Prebuilt so you don't re-derive the same commands each run. All in `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/`, executable:

- `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/codex-pane.sh {find | ensure | send <pane> <message> | capture <pane> | usage-limited <pane>}` — manage the Codex tmux pane. `ensure` finds-or-creates (splits the current window) and prints the pane id; its **exit code** matters: `0` ready, `10` a trust/onboarding prompt is showing (you must approve it), `1` Codex failed to start. `send` pastes a possibly multi-line message faithfully and submits it. `usage-limited` exits 0 when the pane shows a rate/usage-limit message.
- `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh {status <pr> | request <pr> | rerequest <pr>}` — manage the Copilot reviewer. `request` uses REST; `rerequest` uses the GraphQL `requestReviews` mutation. Note: the first-ever Copilot review may need a one-time request through the GitHub UI (see B1).
- `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh {fetch <pr> | clean-pass <pr>}` — paginated fetch of reviews + inline comments; `clean-pass` exits 0 when Copilot's newest review is a clean pass.

Reach for these first. Only hand-write a command when a script genuinely doesn't cover the case.

## Tiers (used for every reviewer's comments)

- **T1 mechanical**: typos, lint, null checks, test-only changes, doc fixes, rename within one file.
- **T2 local refactor**: method extraction, variable naming across a module, added validation.
- **T3 architectural**: file/module moves, API shape, "should this exist", simplification, scope cuts.

Per round: post the grouped findings, **resolve T2/T3 with the author first** (quote the comment, draft 2–3 approaches with trade-offs, recommend one, wait for their pick), **then** apply the fixes — T1 auto-fixed, T2/T3 done as chosen. One commit per item, TDD, and reply/note the commit hash. (TDD and one-commit-per-item apply to executable changes; for prose/doc targets there are no tests to write first — prefer one logical edit per finding and review for clarity, consistency, structure, and factual accuracy.) Architectural decisions always land before mechanical edits are committed.

## Flow

### Phase A — Local review (always first)

**A0. Author pass first** — before touching anything, ask: "Any simplifications you'd collapse across these changes before I start?" Capture as a commit-plan override.

**A1. Claude subagent review** — dispatch a subagent to review the diff. Classify findings into T1/T2/T3, post the grouped list, resolve T2/T3 picks, then apply fixes (per *Tiers*). Commit fixes; push only if a remote/PR branch exists, otherwise commit locally.

**A2. Codex review** (only if `$TMUX` is set and `codex` is on `PATH`; otherwise skip silently — don't block, don't mention it):
- **Find or open the Codex pane** (capture the exit code safely — a bare `rc=$?` after a `set -e` command substitution can abort before you read it):
  ```bash
  if pane=$(${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/codex-pane.sh ensure); then rc=0; else rc=$?; fi
  ```
  Splitting the current window is intentional: the Codex pane sits beside the working pane so the interaction is visible. Accept the narrower pane as the trade-off.
  - `rc == 10` → Codex is showing a **trust/onboarding prompt**. Do **not** auto-approve it. Pause and tell the author: "Codex needs you to approve the folder-trust prompt in pane `$pane`, then say continue." Resume the Codex step once they confirm.
  - `rc == 1` → Codex couldn't start; skip the Codex step (fall back to Claude-only) and note it.
  - `rc == 0` → ready.
- **Send the work and read the reply:**
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/codex-pane.sh send "$pane" 'Please review this change: <paste diff or summary>'
  ${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/codex-pane.sh capture "$pane"      # read Codex's reply
  ```
- **Loop Codex until clean or its usage limit:** classify its findings into tiers, resolve picks, fix, then re-send for re-review. Check `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/codex-pane.sh usage-limited "$pane"` (exit 0 = limited) each round. Repeat until **either**:
  - Codex reports no remaining problems → Codex gate clean, **or**
  - it hits a **usage / rate-limit** message. On detection: **stop the Codex sub-loop**, note "Codex hit its usage limit — falling back to Claude-only local review (+ Copilot if this is a GitHub target)," and continue without Codex.

**A3. Converge the local gate** — re-run A1/A2 after fixes until Claude is clean **and** Codex is clean *when available* (Codex skipped for no-tmux/no-CLI, or stopped at its usage limit, counts as done). Only then proceed.

### Phase B — GitHub Copilot (only for GitHub PR targets)

**B0. Ensure a PR exists.** If the target is a branch with no PR yet, open it now with `gh pr create` — **only after Phase A is clean** (the local gate comes before opening a PR). If a PR number was given, skip creation.

**B1. Request Copilot review** — get `copilot-pull-request-reviewer` onto the reviewer list before any polling, or the loop waits forever for a bot that was never asked:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh status <num>     # who's requested vs who reviewed
${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh request <num>    # add Copilot via REST
```
First-time caveat: on some repos REST returns 422 for the bot, and the GraphQL re-request can't run yet because it needs a bot node id that only exists once Copilot has reviewed. If `request` fails 422 and Copilot has never reviewed this PR, ask the author to trigger the first Copilot review through the GitHub UI once; every later round can then use `rerequest`.

**B2. Pre-scan** — `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh fetch <num>` (paginated reviews + inline comments). Group unresolved comments into tiers, then handle them per *Tiers*.

**B3. Re-request Copilot** after fixes push — Copilot won't re-examine otherwise: `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh rerequest <num>`. If a Codex pane is reachable, have Codex review the new commits **before** re-requesting Copilot (local gate first).

**B4. Poll** — `/loop 3m` re-run `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh fetch <num>`. New comments → re-classify → B2.
- **Copilot clean-pass stop signal:** when `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh clean-pass <num>` exits 0 (newest Copilot review contains **"and generated no new comments."**), **STOP immediately** — cancel the cron/`/loop` job, do not schedule another poll. Post: "Copilot review is clean — no new comments. Stopping the loop; your call on what's next (review / merge / more work)." Then wait.

**B5. Repeat-comment guard (NL-based)** — for each new comment, compare semantically against prior comments on the same file/line. "Does this raise the same concern as a prior one that already had a fix commit?" If yes → **stop**, post "Copilot re-raised <X> after <commit>. Prior fix didn't satisfy it. Your call." and wait. Fingerprint (file:line + first 40 chars) is an acceptable fallback heuristic; NL comparison is the primary signal.

## Exit conditions

- **Local gate clean + (for GitHub) Copilot clean pass** ("and generated no new comments.") → stop and surface to the author. This is the primary, explicit stop signal — prefer it over inferring doneness from "no new comments for N polls".
- **Codex usage limit** → stop only the Codex sub-loop; the rest of the loop continues.
- **Merge** — never merge autonomously. Only on an explicit `merge` instruction. Default to a merge commit (`gh pr merge --merge`, not `--squash`) to preserve history; ask before deleting the branch, and prefer leaving the local branch in place for the author to prune. Honor the project's own merge conventions if they differ.

## Learning capture

After each round, append to a review journal in the repo (e.g. `.claude/pr-review-journal.md`, create if absent):
- Target (PR # or branch), round N, which reviewer raised it (Claude / Codex / Copilot)
- Comment → fix pattern
- T3 decisions + chosen approach + why
- Repeat-issue escalations (these = gaps in the project's conventions; candidates for the project's guidelines doc)

Periodically distill recurring patterns into the project's conventions/guidelines doc.

## Non-goals

- Not fully autonomous. The author decides T2/T3 fixes and the final merge.
- Not a squash-merge tool. Default to a merge commit to preserve history.
- The Copilot path is GitHub-only (uses `gh` + GitHub GraphQL). For other forges, the local Claude + Codex gate still applies; the remote-reviewer phase does not.
