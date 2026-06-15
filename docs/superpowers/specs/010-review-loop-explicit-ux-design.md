# 010 — review-loop: explicit-over-automatic UX (watch-pane gate + post-loop rebase offer)

**Status:** Design
**Plugin:** `review-loop`
**Extends:** [002](002-review-loop-plugin-design.md), [003](003-review-loop-headless-codex-design.md), [009](009-review-loop-codex-sandbox-fix-design.md)
**Source:** [issue #43](https://github.com/caasi/dong3/issues/43) (Part A) + author request (Part B)
**Target version:** `review-loop` 0.3.0 → 0.4.0 (behavior change)

## Motivation

Two places where `review-loop` does the surprising thing automatically (or omits a useful explicit offer). The common principle: **explicit over automatic** — don't take a visible, stateful action the user didn't ask for; do offer optional conveniences out loud.

- **Part A (issue #43):** the tmux live-watch pane spawns whenever `$TMUX` is set — i.e. "am I inside tmux?", which is the user's normal working environment, not a request to spectate. An agent running the loop gets a surprise extra pane every time.
- **Part B (author request):** the loop typically produces many small per-finding fixup commits (e.g. 17 on a recent run). There is no step that offers to tidy them before merge, so the author has to remember to ask.

Both are assisted, never autonomous — consistent with the skill's existing ethos ("never merges autonomously").

## Part A — Gate the tmux watch pane behind an explicit request

### Current behavior
`SKILL.md` §A2 spawns the pane on `$TMUX` alone:
```bash
[ -n "${TMUX:-}" ] && watch_pane=$(tmux split-window -h -P \
  -F '#{session_name}:#{window_index}.#{pane_index}' "tail -f '$log'" 2>/dev/null) || true
```

### Desired behavior
Spawn the pane only when the user **explicitly asked to watch**, with `$TMUX` as a **necessary precondition** (you can't split a pane outside tmux) that is no longer **sufficient** on its own. Default — even inside tmux — is headless: no pane. Codex findings are relayed in Claude's grouped tier list regardless (the authoritative human-facing summary).

### What counts as a watch request
A `watch` intent the skill recognizes from **either**:
- an explicit `watch` (or `--watch`) argument to the command, e.g. `/review-loop 46 watch`; **or**
- an in-conversation request — "let me watch", "show me the codex pane", or similar.

(The skill is LLM-driven: it reads `SKILL.md` and interprets intent, so "argument" and "request" both reduce to the agent recognizing an explicit ask — there is no real CLI parser.)

A lone `watch` token (`/review-loop watch`) is the **watch request against the default target** (current branch vs base), **not** a branch named `watch`. To review a branch actually named `watch`, name it unambiguously (e.g. its full ref `refs/heads/watch`).

### The gate
```bash
# spawn ONLY when the user asked to watch (the `watch` arg or an in-conversation
# request) AND we're inside tmux. $TMUX is necessary, not sufficient.
[ -n "${watch:-}" ] && [ -n "${TMUX:-}" ] && watch_pane=$(tmux split-window -h -P \
  -F '#{session_name}:#{window_index}.#{pane_index}' "tail -f '$log'" 2>/dev/null) || true
```
Teardown (`kill-pane` guarded by `${watch_pane:-}`) is unchanged — if no pane was spawned, `$watch_pane` is unset and teardown is a no-op.

### Watch requested but not in tmux
If the user asked to watch but `$TMUX` is unset (can't split a pane), **note it once** and continue headless:
> "You're not in a tmux session, so I can't open a watch pane — Codex findings are still relayed in the tier list."

Never fail or block on this; the review proceeds exactly as the default headless path.

### Files (Part A)
- `plugins/review-loop/skills/review-loop/SKILL.md`:
  - §A2 spawn block: replace the gate code (lines ~83–84) with the gated form above, **and rewrite the bullet's prose at line 81** — the sentence "If `$TMUX` is set, spawn one read-only spectator pane …" is the most explicit tmux-alone trigger and must become "spawn **only when the user explicitly asked to watch** … inside tmux is required but not a request on its own … **default — even inside tmux — is headless: no pane**".
  - Add the no-tmux-but-requested note.
  - Consistency edits to the other prose mentions that currently imply `$TMUX`-alone triggers the pane (lines ~10, 19, 22, 35): reword to "only when you ask to watch (and you're in tmux)".
- `plugins/review-loop/commands/review-loop.md`:
  - **Usage:** add the `watch` arg — `/review-loop [target] [watch]` — "append `watch` to open a live spectator pane; requires a tmux session."
  - Invariant line (~27–28): "tmux is optional and opens a live-watch pane **only when you ask**, never by default."
- `plugins/review-loop/skills/review-loop/README.md`: **reword the two existing pane mentions** so neither implies tmux-alone opens the pane — lines ~18–19 ("tmux only adds an optional live-watch pane") and ~25–26 ("tmux optional — only for a live-watch pane") → "opens a live-watch pane **only when you ask**". (The issue was right that README needs mirroring; the path is `…/skills/review-loop/README.md`, not a top-level `README.md`.)

## Part B — After convergence, offer to rebase + group commits

### Trigger
When the loop reaches its clean/stop state (Exit conditions: local gate clean, plus — for GitHub targets — a Copilot clean pass) **and** the branch carries **≥ 2 commits** ahead of its base on a **non-primary feature branch**, the skill **offers** to rebase and group the commits before merge. It **asks**; it never rebases automatically.

**Counting commits / base.** Capture the branch tip **at loop start** as a baseline, so the offer can report what the loop *added* (and how many are review fixups) accurately. Count against the **integration base** — the loop's inferred `$base` (the actual review/PR **target** branch, SKILL §Inputs; the default branch only as a fallback), i.e. `$base..HEAD`. For a PR targeting a release branch, or a stacked PR, the target — not the default branch — is the base, so counting and the later soft-reset don't sweep in parent-branch commits. Do **not** count against `@{upstream}..HEAD`: on a pushed PR branch tracking `origin/<feature>`, upstream..HEAD is ~empty after each fix is pushed, so the ≥2-commit offer would wrongly skip even on a branch full of commits. Upstream/remote detection is reserved for the **push** decision (Guardrails), a separate concern from the count. If no loop-start baseline is available, phrase the count as "**N commits ahead of base**" rather than "N added by the loop" — never claim the loop added pre-existing commits.

### Guardrails (load-bearing)
- **Feature branches only.** Never offer (and never perform) a rebase on the **default/primary branch**. Detect it robustly — `git symbolic-ref --short refs/remotes/origin/HEAD` (the remote's default), falling back to the local `main`/`master`/`develop` set and the project's stated default — **not** a hardcoded triple (repos whose default is `trunk`/`production`/etc. must be protected too). If the current branch is the default/primary, skip the offer entirely.
- **Assisted, not autonomous.** Present the offer and wait. Declining leaves history exactly as-is.
- **Safety first on accept:** create a backup branch at the current tip before rewriting; group commits; verify the resulting tree is **identical** to the pre-rebase tip by **tree hash** (`git rev-parse <backup>^{tree}` == `git rev-parse HEAD^{tree}`, robust even with a dirty working tree); run the project's tests if present.
- **Push only an already-remote branch.** The loop also supports **local-only** targets. If the branch has an upstream/remote, **force-push with `--force-with-lease`**; if it is local-only (no remote), group the history **locally and do not push or publish it** — accepting "group commits" must never turn a private branch into a published one, and a force-push would otherwise fail for lack of an upstream.
- **Respect project git conventions** (e.g. this repo: feature-branch rebase OK when asked; preserve primary-branch history; prefer merge commits for primary).

### The offer
> "The loop added N commits to `<branch>` (incl. M review fixups). Want me to rebase and group them before you merge? Feature branch only — I'll keep a backup branch and force-push with `--force-with-lease`."

On **accept**, ask the grouping shape (e.g. by area / a few coarse groups / single squash), then perform it with the guardrails above. On **decline**, do nothing.

### Mechanism (non-interactive)
`git rebase -i` is **not available** in this environment (interactive flags unsupported), so grouping uses a **soft-reset + re-commit** flow, which also guarantees the final tree matches the pre-rebase tip:
0. **require a clean working tree** — if the tree is dirty (tracked **or untracked**), `git stash --include-untracked` first and restore afterward (or refuse and ask the user to commit/stash). Otherwise the soft-reset folds unrelated tracked edits into the regrouped commits, and staging whole paths would `git add` any unrelated **untracked** file lying under a staged path; the tree-hash check below only detects the corruption *after* history is rewritten, so it must be prevented up front;
1. backup: `git branch <backup> HEAD`;
2. `git reset --soft <base>` (then `git reset` to unstage), keeping all changes in the working tree;
3. re-commit in the chosen groups by staging the relevant paths per commit;
4. verify the tree-hash equality (Guardrails);
5. push per the local-only/remote rule (Guardrails).

Note this groups **by file/area** (the final tree is one combined state), so per-commit splits that crossed a single file in the original history can't be reconstructed — call that out when asking the grouping shape. (`git rebase --onto` with scripted sequencing is an alternative when commit-level reordering without squashing is wanted.)

### Insertion point
A new subsection at the end of **Exit conditions** in `SKILL.md` (after the clean-pass stop, before/near the existing **Merge** bullet — and explicitly *before* any merge, since grouping happens on the branch prior to the merge commit).

**Reachability — also amend §B4.** The existing §B4 "Copilot clean-pass stop signal" (line ~190) currently ends with "**STOP immediately** … Then wait." — so for a GitHub target, a clean Copilot pass jumps straight to waiting and the new offer under Exit conditions is **never reached**. §B4 must be edited so that on a clean pass it **makes the post-convergence offer first, then waits**. Without this edit the offer only fires for local (non-PR) targets.

### Files (Part B)
- `plugins/review-loop/skills/review-loop/SKILL.md` — Exit conditions section (~194–198): new "After convergence — offer to group commits" subsection; **and §B4 (line ~190): route the clean-pass stop through the offer before waiting.**
- `plugins/review-loop/commands/review-loop.md` — one invariant line ("after convergence, offers to rebase + group commits; never auto-rebases, feature-branch only").

## Non-goals

- Not auto-spawning the pane; not auto-rebasing; not changing merge behavior (still never merges autonomously, still merge-commit by default).
- Not adding a real CLI argument parser — the LLM interprets `watch` and the rebase offer/accept from intent.
- Not rebasing or rewriting primary branches, ever.
- Not a squash-merge tool.

## Testing

`SKILL.md` and the command doc are prose (system prompt) — no unit test. Extend the existing content-regression guard `tools/review-loop/test-skill-content.sh` with anchors so a future edit can't silently revert. The current harness only has `need <regex>` (assert **present**), which can't express "tmux-alone is no longer the trigger" — so **add a small `refute <regex>` helper** (fails if the regex IS present), or phrase every check positively. Suggested anchors:
- **Part A (positive):** `need 'asked to watch'` (or the watch-gated condition). **Part A (negative):** `refute` that the spawn line still gates on `${TMUX:-}` *without* a watch condition — e.g. refute a `watch`-free `[ -n "${TMUX:-}" ] && watch_pane=` line. (Pin the refute to the gate line so unrelated `$TMUX` mentions don't trip it.)
- **Part B:** `need 'After convergence'`, `need 'force-with-lease'`, `need 'feature.branch'`, and a never-auto anchor (`need 'never.*auto'` or similar).

Manual verification:
- In tmux, default `/review-loop` → **no pane** spawned.
- `/review-loop … watch` (or "show me the codex pane") in tmux → pane spawned, torn down at loop end.
- Watch requested, **not** in tmux → brief note, headless, review unaffected.
- Loop converges on a feature branch with ≥2 commits → offer appears; decline leaves history; accept groups + backup + `--force-with-lease`, primary untouched.

## Acceptance criteria

- [ ] Inside tmux, a default `/review-loop` spawns **no** watch pane.
- [ ] The pane spawns only on an explicit watch request (`watch` arg or in-conversation) **and** only when `$TMUX` is set.
- [ ] Watch requested but `$TMUX` unset → a brief surfaced note, review continues headless.
- [ ] `commands/review-loop.md` documents the `watch` arg; no prose anywhere still implies `$TMUX`-alone triggers the pane.
- [ ] After convergence on a **feature** branch with ≥2 commits, the skill **offers** (asks) to rebase + group; the offer never fires on a primary branch.
- [ ] Accepting groups the commits, keeps a backup branch, verifies an identical tree, and force-pushes with `--force-with-lease`; declining leaves history untouched.
- [ ] `tools/review-loop/test-skill-content.sh` has anchors for both Part A and Part B, including a `refute` helper (or positive rephrasing) for the "tmux-alone is no longer the trigger" negative.
- [ ] `review-loop` version bumped to 0.4.0 in `.claude-plugin/marketplace.json`.
