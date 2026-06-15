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
  - §A2 spawn block (lines ~81–86): the gate above + reframed prose ("spawn **only when the user explicitly asked to watch** … inside tmux is required but not a request on its own … **default — even inside tmux — is headless: no pane**").
  - Add the no-tmux-but-requested note.
  - Consistency edits to the prose mentions that currently imply `$TMUX`-alone triggers the pane (lines ~10, 19, 22, 35): reword to "only when you ask to watch (and you're in tmux)".
- `plugins/review-loop/commands/review-loop.md`:
  - **Usage:** add the `watch` arg — `/review-loop [target] [watch]` — "append `watch` to open a live spectator pane; requires a tmux session."
  - Invariant line (~27–28): "tmux is optional and opens a live-watch pane **only when you ask**, never by default."
- `README.md`: **no change** — it currently contains no mention of the pane, so there is nothing to mirror (this corrects the issue's assumption).

## Part B — After convergence, offer to rebase + group commits

### Trigger
When the loop reaches its clean/stop state (Exit conditions: local gate clean, plus — for GitHub targets — a Copilot clean pass) **and** the branch carries **≥ 2 commits** ahead of its base on a **non-primary feature branch**, the skill **offers** to rebase and group the commits before merge. It **asks**; it never rebases automatically.

### Guardrails (load-bearing)
- **Feature branches only.** Never offer (and never perform) a rebase on a primary branch (`main`/`develop`/`master`). Detect the current branch; if it's primary, skip the offer entirely.
- **Assisted, not autonomous.** Present the offer and wait. Declining leaves history exactly as-is.
- **Safety first on accept:** create a backup branch at the current tip before rewriting; group commits; verify the resulting tree is **identical** to the pre-rebase tree (`git diff <orig> HEAD` empty); run the project's tests if present; **force-push with `--force-with-lease`** only.
- **Respect project git conventions** (e.g. this repo: feature-branch rebase OK when asked; preserve primary-branch history; prefer merge commits for primary).

### The offer
> "The loop added N commits to `<branch>` (incl. M review fixups). Want me to rebase and group them before you merge? Feature branch only — I'll keep a backup branch and force-push with `--force-with-lease`."

On **accept**, ask the grouping shape (e.g. by area / a few coarse groups / single squash), then perform it with the guardrails above. On **decline**, do nothing.

### Insertion point
A new subsection at the end of **Exit conditions** in `SKILL.md` (after the clean-pass stop, before/near the existing **Merge** bullet — and explicitly *before* any merge, since grouping should happen on the branch prior to the merge commit). Mirror a one-line behavior note in `commands/review-loop.md` invariants ("after convergence, offers to rebase + group commits; never auto-rebases, feature-branch only").

### Files (Part B)
- `plugins/review-loop/skills/review-loop/SKILL.md` — Exit conditions section (~194–198): new "After convergence — offer to group commits" bullet/subsection.
- `plugins/review-loop/commands/review-loop.md` — one invariant line.

## Non-goals

- Not auto-spawning the pane; not auto-rebasing; not changing merge behavior (still never merges autonomously, still merge-commit by default).
- Not adding a real CLI argument parser — the LLM interprets `watch` and the rebase offer/accept from intent.
- Not rebasing or rewriting primary branches, ever.
- Not a squash-merge tool.

## Testing

`SKILL.md` and the command doc are prose (system prompt) — no unit test. Extend the existing content-regression guard `tools/review-loop/test-skill-content.sh` with anchors so a future edit can't silently revert:
- **Part A:** assert the §A2 pane gate text references an explicit watch request (e.g. matches `watch` in the gate) and that tmux-alone is not the trigger.
- **Part B:** assert an "after convergence" section mentions offering to rebase/group commits, feature-branch-only, and never-auto.

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
- [ ] `tools/review-loop/test-skill-content.sh` has anchors for both Part A and Part B.
- [ ] `review-loop` version bumped to 0.4.0 in `.claude-plugin/marketplace.json`.
