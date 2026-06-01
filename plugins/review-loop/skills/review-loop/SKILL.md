---
name: review-loop
description: General assisted review loop for changes — code or design artifacts (specs, plans, docs). Prefers local reviewers (Claude subagent + headless Codex via `codex exec review`) as the first gate; for GitHub PR targets, also requests Copilot after the PR is open. Loops each reviewer until clean or its usage limit, classifies comments into tiers, auto-fixes mechanical ones, pauses on architectural ones for user judgment. Never merges autonomously.
---

# Review Loop (Assisted)

Assisted, not autonomous. Preserves the author's architectural voice and learning across review cycles. General-purpose: the target may be a **local branch / working diff** (no remote needed) or a **GitHub PR**, and the changes under review may be **code or design artifacts** (specs, plans, docs).

**Local reviewers are preferred and run first.** A Claude subagent and Codex (headless, via `codex exec review`) cost nothing extra and are fast, so they are the first gate. Codex runs wherever the `codex` CLI is on `PATH` — no tmux needed; tmux is only an optional live-watch layer for a human to spectate the review. GitHub Copilot is added only when the target is a GitHub PR, and only after the local gate is clean.

## Why this loop exists

Claude and Codex reviewing **together** produces noticeably better output than either model alone — they catch different classes of issues, and Codex's pass tightens the diff before it ever reaches GitHub. The downstream payoff: by the time Copilot sees the PR, there's much less for it to complain about, so review rounds converge faster. Front-loading combined local Claude+Codex review as the first gate is the entire reason this loop exists.

## Requirements

- **Always usable:** the Claude subagent reviewer needs nothing extra.
- **Codex reviewer (optional):** the `codex` CLI on `PATH`. Absent it, the Codex step is skipped silently. (tmux is **not** required — it only adds an optional live-watch pane; see A2.)
- **GitHub Copilot phase (optional):** the authenticated `gh` CLI and `jq`. Only used for GitHub PR targets.

The skill and helper scripts resolve their CLI dependencies (`codex`, `gh`, `jq`, plus `tmux` only for the optional live-watch pane) from `PATH`, so the skill is self-contained and portable across machines.

## Inputs

- **Target** — one of:
  - a **local diff/branch** (default: current branch vs its base), or
  - a **GitHub PR number** (or a branch that already has an open PR → treat as GitHub target).
  - The diff may contain code, design artifacts (specs, plans, docs), or both — the loop reviews whatever changed.
- Repo / base branch inferred from the current working directory.

## Reviewer roster & priority

1. **Local Claude subagent** — always. Dispatch a subagent (Task tool) to do the review.
2. **Local Codex** (headless `codex exec review`) — when `codex` is on `PATH`. tmux is not required; if `$TMUX` is set it only adds an optional live-watch pane. See A2.
3. **GitHub Copilot** — only for GitHub PR targets, after the PR is open.

## Helper scripts

Prebuilt so you don't re-derive the same commands each run. All in `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/`, executable:

- `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh {status <pr> | request <pr> | rerequest <pr>}` — manage the Copilot reviewer. `request` uses `gh pr edit --add-reviewer`; `rerequest` uses the GraphQL `requestReviews` mutation. Note: the first-ever Copilot review may need a one-time request through the GitHub UI (see B1).
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

**A2. Codex review** (only if `codex` is on `PATH`; otherwise skip silently — don't block, don't mention it). Codex runs **headless** via `codex exec review` — no tmux, no pane, runs wherever `codex` is on `PATH`. The `review` subcommand is read-only by construction; Codex *finds* issues, Claude applies fixes (Codex never edits the tree).

- **Set up logs (once, at loop start):** pick a `<runid>` (PR number, branch slug, or `mktemp` suffix). `$log` is the **cumulative** feed for the optional watch pane *only*; each round also writes its own `$round` file, which is what Claude actually reads (so old rounds' findings are never replayed):
  ```bash
  log="/tmp/review-loop-codex.<runid>.log"; err="/tmp/review-loop-codex.<runid>.err"
  : >"$log"   # cumulative across rounds — for the tail -f watch pane only
  ```
  Then **each round**: write Codex's stdout to a fresh `$round` file, capture `rc`, append that round to `$log` for the watch, and read **`$round`** (this round only):
  ```bash
  round="$(mktemp "${TMPDIR:-/tmp}/review-loop-codex.XXXXXX")"   # template form: portable on BSD/macOS too
  rc=0
  <codex exec …> >"$round" 2>"$err" || rc=$?   # rc=0; … || rc=$? so it survives `set -e`; NEVER `| tee` (masks Codex's rc)
  cat "$round" >>"$log"                       # feed the cumulative watch pane
  # Claude reads "$round" (only this round); parse thread_id from "$round" too
  ```

- **Optional tmux live-watch (spectating only, not the channel) — spawn it now, before the first `codex` call, so it covers round 1.** The channel is *always* `codex exec`. If `$TMUX` is set, spawn one read-only spectator pane that follows the per-run `$log` (for round 1 that `$log` is a JSON event stream — the human's authoritative summary is still Claude's relayed tier list; the pane is a raw-feed spectator aid):
  ```bash
  [ -n "${TMUX:-}" ] && watch_pane=$(tmux split-window -h -P \
    -F '#{session_name}:#{window_index}.#{pane_index}' "tail -f '$log'")
  ```
  The agent **never reads from this pane** — it reads `codex exec`'s stdout. All rounds append to the same `$log`, so the single pane keeps showing them. **Tear it down** at loop end (clean, usage-limit fallback, or abort) so it doesn't orphan: `tmux kill-pane -t "$watch_pane"`. No tmux? Codex still runs — the human sees its findings relayed in Claude's own grouped tier list.

- **Resolve the target into the working tree first.** `codex exec review` reviews the *current checkout*, so before reviewing, make the checkout match the requested target: for a `<branch>` target, `git checkout` it (or run from its worktree); for a `<PR-number>` target, `gh pr checkout <num>` first. Only then does `review --base "$base"` (or `--uncommitted`) look at the right diff. (If checking out isn't possible, pipe `gh pr diff <num>` through the freeform `review -` form instead.)

- **First round — map the loop's target to a `review` invocation, with `--json`.** This is the round whose session id we need, so run it with `--json` and capture `thread_id` for resume (§ Convergence rounds). `--sandbox read-only` goes **before** the subcommand. Target flags take **no** prompt (they conflict with `[PROMPT]` — `review --uncommitted -` errors rc=2), so the targeted forms carry no instructions. Use `--base "$base"` as the canonical default-target form:
  ```bash
  round="$(mktemp "${TMPDIR:-/tmp}/review-loop-codex.XXXXXX")"
  rc=0
  codex exec --json --sandbox read-only review --base "$base"  >"$round" 2>"$err" || rc=$?   # branch vs base (default)
  # other targets: review --uncommitted (working tree) · review --commit "$sha" (one commit)
  cat "$round" >>"$log"   # feed the watch pane
  thread_id=$(sed -nE 's/.*"thread_id"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$round" | head -1)
  ```
  With `--json` the stdout is a JSON **event stream**: Claude reads the review content from the assistant/agent-message events in `$round` and classifies it into T1/T2/T3, **and** extracts `thread_id` for resume. The human-readable findings still reach the author via Claude's own relayed tier list (Claude relays regardless), so JSON-on-stdout is fine.
  For **custom focus** (e.g. steering a doc-artifact review), use the freeform form — no target flag, Codex infers the diff itself; name the target in prose. Keep `--json` here too, so a focused first round still captures `thread_id` for resume (otherwise convergence falls back to `--last`):
  ```bash
  round="$(mktemp "${TMPDIR:-/tmp}/review-loop-codex.XXXXXX")"
  rc=0
  printf '%s\n' "Review the changes against main as a design artifact: clarity, consistency, factual accuracy, gaps. No tests here." \
    | codex exec --json --sandbox read-only review - >"$round" 2>"$err" || rc=$?
  cat "$round" >>"$log"
  thread_id=$(sed -nE 's/.*"thread_id"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$round" | head -1)
  ```
  Use the targeted form by default; reach for freeform only when custom focus is worth giving up the explicit target flag.

- **Capture the exit status, don't pipe it away.** Never `codex … | tee` — that makes `$?` reflect `tee`, not Codex, and the three-outcome split below needs Codex's real exit code. Redirect stdout to the per-round `$round` file and stderr to `$err`, grab `rc=$?` immediately, then `cat "$round" >>"$log"` for the watch and read `$round` for classification.

- **Model / effort — defer to the user's Codex config.** Pass **no `-m` and no reasoning-effort override**: `codex exec review` honors `~/.codex/config.toml`'s `review_model` (falling back to the session default). Only if the author names a model for the session ("use gpt-5.4") pass `-m` for the rest of the loop.

- **Three outcomes** after each call — branch on `rc`:
  - **`rc == 0` → read the review (NL judgment).** Read **this round's `$round`** (not the cumulative `$log`, which replays earlier rounds) — a JSON event stream on the first round (read the review text from the assistant/agent-message events), plain text on `resume` rounds. Either way Claude classifies it into T1/T2/T3 or judges "no remaining problems," exactly as it handles its own subagent review. (Only `thread_id` is parsed out of the JSON; the review itself is read, not grepped.)
  - **Non-zero *with* a limit message in `$err`** (matching `usage limit|rate limit|quota|too many requests|try again later`) → **usage-limited.** **Stop the Codex sub-loop**, note "Codex hit its usage limit — falling back to Claude-only local review (+ Copilot if this is a GitHub target)," and continue without Codex.
  - **Non-zero *without* a limit match → "Codex failed"** (bad flag, invalid base, auth failure, etc.). Do **not** silently fold this into the usage-limit fallback — **surface it to the author** with a stderr summary (`tail "$err"`), then degrade to Claude-only. (A read-only review in an untrusted/first-run directory was verified to *proceed* — rc=0 — not hard-fail, so no dedicated trust branch is needed; any future trust-gate non-zero exit lands here.)

- **Convergence rounds — resume the same session (plain, no `--json`).** Use the `thread_id` captured from the first round (the `--json` stream's `thread_id` field — not `session_id`) and resume so Codex remembers its prior comments. No `--json` here — `resume` produces readable output and there's no new id to capture (`resume`'s trailing `-` for the follow-up prompt is valid — only `review` target flags conflict with a prompt):
  ```bash
  round="$(mktemp "${TMPDIR:-/tmp}/review-loop-codex.XXXXXX")"
  rc=0
  printf '%s\n' "I applied these fixes: <summary>. Are your earlier points resolved? Any new concerns?" \
    | codex exec --sandbox read-only resume "$thread_id" - >"$round" 2>"$err" || rc=$?
  cat "$round" >>"$log"   # feed the watch pane; Claude reads "$round" (this round only)
  ```
  **Fallbacks, in order:** no id captured → `resume --last` (caveat: `--last` is cwd-scoped, so an unrelated `codex` session started in this repo mid-loop becomes the new "last"); `resume` fails (session expired/missing) → a **fresh** `codex exec --sandbox read-only review -` (freeform, no target flag) with the prior findings restated, so a round never silently loses the review.

- **Loop Codex until clean or its usage limit:** each round classify its findings into tiers, resolve picks, fix, then `resume` for re-review. Repeat until **either** Codex reports no remaining problems (Codex gate clean) **or** it hits the usage-limit outcome above.

- **Freeform plain-exec fallback (rare).** Drop to `codex exec "<instructions + diff>"` only when (a) the installed `codex` is too old to have `exec review`, or (b) the target is **not** a git diff (e.g. a pasted artifact outside any repo) — in case (b) **only**, add `--skip-git-repo-check` (unnecessary on the normal `review`/`resume` paths).

**A3. Converge the local gate** — re-run A1/A2 after fixes until Claude is clean **and** Codex is clean *when available*. "Done" for Codex means any of: clean review, **or** Codex was unavailable this run — the `codex` CLI is absent, it stopped at its usage limit, or it **failed for a non-limit reason** (§4 "Codex failed": surfaced to the author, then degraded to Claude-only). In every unavailable case the gate proceeds on Claude alone; only an *available, not-yet-clean* Codex blocks. Only then proceed.

### Phase B — GitHub Copilot (only for GitHub PR targets)

**B0. Ensure a PR exists.** If the target is a branch with no PR yet, open it now with `gh pr create` — **only after Phase A is clean** (the local gate comes before opening a PR). If a PR number was given, skip creation.

**B1. Request Copilot review** — get `copilot-pull-request-reviewer` onto the reviewer list before any polling, or the loop waits forever for a bot that was never asked:
```bash
${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh status <num>     # who's requested vs who reviewed
${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh request <num>    # add Copilot via gh pr edit --add-reviewer
```
First-time caveat: on some repos `gh pr edit --add-reviewer` returns 422 for the bot, and the GraphQL re-request can't run yet because it needs a bot node id that only exists once Copilot has reviewed. If `request` fails 422 and Copilot has never reviewed this PR, ask the author to trigger the first Copilot review through the GitHub UI once; every later round can then use `rerequest`.

**B2. Pre-scan** — `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh fetch <num>` (paginated reviews + inline comments). Group unresolved comments into tiers, then handle them per *Tiers*.

**B3. Re-request Copilot** after fixes push — Copilot won't re-examine otherwise: `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/copilot.sh rerequest <num>`. If `codex` is on `PATH`, have Codex review the new commits headlessly (`codex exec --sandbox read-only review --base "$base"`, or `resume "$thread_id" -` to continue the session) **before** re-requesting Copilot (local gate first).

**B4. Poll** — `/loop 3m` re-run `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh fetch <num>`. New comments → re-classify → B2.
- **Copilot clean-pass stop signal:** when `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh clean-pass <num>` exits 0 (newest Copilot review matches `generated no (new )?comments.` — "generated no comments." on a first review, "generated no new comments." on a re-review), **STOP immediately** — cancel the cron/`/loop` job, do not schedule another poll. Post: "Copilot review is clean — no new comments. Stopping the loop; your call on what's next (review / merge / more work)." Then wait.

**B5. Repeat-comment guard (NL-based)** — for each new comment, compare semantically against prior comments on the same file/line. "Does this raise the same concern as a prior one that already had a fix commit?" If yes → **stop**, post "Copilot re-raised <X> after <commit>. Prior fix didn't satisfy it. Your call." and wait. Fingerprint (file:line + first 40 chars) is an acceptable fallback heuristic; NL comparison is the primary signal.

## Exit conditions

- **Local gate clean + (for GitHub) Copilot clean pass** (matches "generated no comments." / "generated no new comments.") → stop and surface to the author. This is the primary, explicit stop signal — prefer it over inferring doneness from "no new comments for N polls".
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
