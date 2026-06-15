# review-loop Explicit-over-Automatic UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `review-loop` from auto-spawning the tmux watch pane (gate it behind an explicit watch request), and add a post-convergence offer to group the review fixup commits — per [spec 010](../specs/010-review-loop-explicit-ux-design.md).

**Architecture:** Edits to the `review-loop` skill's prose/guidance (`SKILL.md`, `commands/review-loop.md`, `README.md`) — it's an LLM-read system prompt, so behavior changes are wording changes — plus a content-regression test guarding the new anchors, and a manifest version bump. No runtime code besides the bash snippets embedded in the skill.

**Tech Stack:** Markdown (system prompt), Bash, `git`, `tmux`, `jq`. No build system — plugin/skill repo.

---

## Scope & Conventions

- **Implementation** (runtime plugin behavior): **work on a feature branch in a worktree, never `main`.** Branch: `feat/review-loop-explicit-ux`. The execution skill creates the worktree (RAM disk, per `superpowers:using-git-worktrees`); run every git command from inside it.
- Conventional commits, scoped: `feat(review-loop):`, `docs(review-loop):`, `test(review-loop):`, `chore(review-loop):`.
- Dev tooling (the test) stays under `tools/review-loop/`, never inside `plugins/`.
- The spec (`docs/superpowers/specs/010-review-loop-explicit-ux-design.md`) is the source of truth.
- All SKILL.md edits use the **Edit tool** with the verbatim "Find" anchors below as `old_string`. Anchors were captured from the current files; a clean match is expected. If an Edit fails to match, re-read the live file and report rather than guessing.

## File Structure

**Modify:**
- `plugins/review-loop/skills/review-loop/SKILL.md` — Part A (pane gate + prose) and Part B (after-convergence offer + §B4 reachability).
- `plugins/review-loop/commands/review-loop.md` — `watch` arg + two invariant lines.
- `plugins/review-loop/skills/review-loop/README.md` — two pane mentions.
- `.claude-plugin/marketplace.json` — review-loop `0.3.0` → `0.4.0`.

**Create:** nothing (the test already exists; we extend it).

**Modify (dev tooling):**
- `tools/review-loop/test-skill-content.sh` — add a `refute()` helper + Part A/B anchors.

---

## Task 1: Part A — gate the watch pane (SKILL.md §A2)

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md` (§A2 spawn block, ~lines 81–86)

- [ ] **Step 1: Replace the spawn-block bullet (prose + gate code)**

Find (verbatim):

```
- **Optional tmux live-watch (spectating only, not the channel) — spawn it now, before the first `codex` call, so it covers round 1.** The channel is *always* `codex exec`. If `$TMUX` is set, spawn one read-only spectator pane that follows the per-run `$log` (for round 1 that `$log` is a JSON event stream — the human's authoritative summary is still Claude's relayed tier list; the pane is a raw-feed spectator aid):
  ```bash
  [ -n "${TMUX:-}" ] && watch_pane=$(tmux split-window -h -P \
    -F '#{session_name}:#{window_index}.#{pane_index}' "tail -f '$log'" 2>/dev/null) || true
  ```
```

Replace with:

```
- **Optional tmux live-watch (spectating only, not the channel) — spawn it only when the user explicitly asked to watch.** The channel is *always* `codex exec`. **Default — even inside tmux — is headless: no pane.** Spawn a read-only spectator pane *only when the user asked to watch* — a `watch` argument to the command, or an in-conversation request like "let me watch" / "show me the codex pane". Being inside tmux is **required but not a request on its own**. The agent sets `watch=1` when it recognized such a request (equivalently, it just runs the spawn only then); the pane follows the per-run `$log` (a raw-feed spectator aid — the authoritative human summary is still Claude's relayed tier list):
  ```bash
  # spawn ONLY when the user asked to watch (watch=1, set from intent) AND inside tmux.
  # $TMUX is necessary, not sufficient.
  [ -n "${watch:-}" ] && [ -n "${TMUX:-}" ] && watch_pane=$(tmux split-window -h -P \
    -F '#{session_name}:#{window_index}.#{pane_index}' "tail -f '$log'" 2>/dev/null) || true
  ```
  If the user asked to watch but `$TMUX` is unset (can't split a pane), note it once — "not in a tmux session, so I can't open a watch pane; Codex findings are still relayed in the tier list" — and continue headless. Never fail on this.
```

- [ ] **Step 2: Verify the edit**

Run: `sed -n '79,92p' plugins/review-loop/skills/review-loop/SKILL.md`
Expected: the bullet now says "spawn it only when the user explicitly asked to watch", the gate code begins `[ -n "${watch:-}" ] && [ -n "${TMUX:-}" ]`, the no-tmux note is present, fences balanced.

- [ ] **Step 3: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): gate the tmux watch pane behind an explicit request

Default is headless even inside tmux; spawn only when the user asked to watch
(watch arg or in-conversation), with \$TMUX necessary but not sufficient. Note
the no-tmux case. Implements spec 010 Part A.

Closes #43."
```

---

## Task 2: Part A — consistency prose (SKILL.md mentions)

Four prose mentions still imply `$TMUX`-alone adds the pane. Reword each.

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md` (lines ~10, 19, 22, 35)

- [ ] **Step 1: Line 10 — reword**

Find: `Codex runs wherever the `codex` CLI is on `PATH` — no tmux needed; tmux is only an optional live-watch layer for a human to spectate the review.`
Replace: `Codex runs wherever the `codex` CLI is on `PATH` — no tmux needed; tmux only adds a live-watch pane **when the user asks to watch** (never by default).`

- [ ] **Step 2: Line 19 — reword**

Find: `(tmux is **not** required — it only adds an optional live-watch pane; see A2.)`
Replace: `(tmux is **not** required — it only adds a live-watch pane **when you ask to watch**; see A2.)`

- [ ] **Step 3: Line 22 — reword**

Find: `plus `tmux` only for the optional live-watch pane`
Replace: `plus `tmux` only for the live-watch pane (used only when you ask to watch)`

- [ ] **Step 4: Line 35 — reword**

Find: `tmux is not required; if `$TMUX` is set it only adds an optional live-watch pane. See A2.`
Replace: `tmux is not required; it adds a live-watch pane **only when you ask to watch** (and you're in tmux). See A2.`

- [ ] **Step 5: Verify**

Run: `grep -n 'only when you ask\|when the user asks to watch\|when you ask to watch' plugins/review-loop/skills/review-loop/SKILL.md`
Expected: matches at the four reworded lines. Also `grep -n 'optional live-watch pane' plugins/review-loop/skills/review-loop/SKILL.md` should now return nothing (all reworded).

- [ ] **Step 6: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "docs(review-loop): reword tmux prose to 'only when you ask' (spec 010 Part A)

Refs #43."
```

---

## Task 3: Part A — command doc (`watch` arg + invariant)

**Files:**
- Modify: `plugins/review-loop/commands/review-loop.md`

- [ ] **Step 1: Add the `watch` arg to Usage**

Find:
```
- `/review-loop <PR-number>` — review an open GitHub PR (adds the Copilot phase).
```
Replace:
```
- `/review-loop <PR-number>` — review an open GitHub PR (adds the Copilot phase).
- append `watch` (e.g. `/review-loop watch`, `/review-loop 46 watch`) — open a live spectator pane for the Codex review; **requires a tmux session**. A lone `watch` token is the watch request against the default target, not a branch named `watch`.
```

- [ ] **Step 2: Update the invariant line**

Find:
```
  `codex exec review`) joins when `codex` is on `PATH`; tmux is optional (a
  live-watch pane only), not a gate. The local gate must be clean before any
  GitHub PR is opened.
```
Replace:
```
  `codex exec review`) joins when `codex` is on `PATH`; tmux is optional and
  opens a live-watch pane **only when you ask** (the `watch` arg or an
  in-conversation request), never by default. The local gate must be clean
  before any GitHub PR is opened.
```

- [ ] **Step 3: Verify**

Run: `grep -n 'append .watch.\|only when you ask' plugins/review-loop/commands/review-loop.md`
Expected: both the Usage line and the invariant line match.

- [ ] **Step 4: Commit**

```bash
git add plugins/review-loop/commands/review-loop.md
git commit -m "docs(review-loop): document the watch arg in the command doc (spec 010 Part A)

Refs #43."
```

---

## Task 4: Part A — README pane mentions

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/README.md`

- [ ] **Step 1: Reword the roster mention**

Find:
```
2. **Codex** (headless `codex exec review`) — when `codex` is on `PATH`; tmux only
   adds an optional live-watch pane.
```
Replace:
```
2. **Codex** (headless `codex exec review`) — when `codex` is on `PATH`; tmux
   opens a live-watch pane only when you ask (never by default).
```

- [ ] **Step 2: Reword the requirements mention**

Find:
```
- **Codex (optional):** the `codex` CLI on `PATH` (tmux optional — only for a
  live-watch pane). `jq` is used to read the resume `thread_id` from `codex`'s
```
Replace:
```
- **Codex (optional):** the `codex` CLI on `PATH` (tmux optional — opens a
  live-watch pane only when you ask). `jq` is used to read the resume `thread_id` from `codex`'s
```

- [ ] **Step 3: Verify**

Run: `grep -n 'only when you ask' plugins/review-loop/skills/review-loop/README.md`
Expected: two matches. And `grep -n 'optional live-watch pane\|only for a' plugins/review-loop/skills/review-loop/README.md` returns nothing.

- [ ] **Step 4: Commit**

```bash
git add plugins/review-loop/skills/review-loop/README.md
git commit -m "docs(review-loop): README pane mentions gated on explicit request (spec 010 Part A)

Refs #43."
```

---

## Task 5: Part B — after-convergence offer + §B4 reachability (SKILL.md)

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md` (§B4 line ~190; Exit conditions ~194–198)

- [ ] **Step 1: Route the §B4 clean-pass stop through the offer**

Find:
```
- **Copilot clean-pass stop signal:** when `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh clean-pass <num>` exits 0 (newest Copilot review matches `generated no (new )?comments.` — "generated no comments." on a first review, "generated no new comments." on a re-review), **STOP immediately** — cancel the cron/`/loop` job, do not schedule another poll. Post: "Copilot review is clean — no new comments. Stopping the loop; your call on what's next (review / merge / more work)." Then wait.
```

Replace:
```
- **Copilot clean-pass stop signal:** when `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/pr-comments.sh clean-pass <num>` exits 0 (newest Copilot review matches `generated no (new )?comments.` — "generated no comments." on a first review, "generated no new comments." on a re-review), **STOP immediately** — cancel the cron/`/loop` job, do not schedule another poll. Post: "Copilot review is clean — no new comments." Then run the **After convergence — offer to group commits** step (Exit conditions) *before waiting* — without it the offer is unreachable on the GitHub path — and wait for the author's call (group commits / review / merge / more work).
```

- [ ] **Step 2: Add the After-convergence subsection at the end of Exit conditions**

Find:
```
- **Merge** — never merge autonomously. Only on an explicit `merge` instruction. Default to a merge commit (`gh pr merge --merge`, not `--squash`) to preserve history; ask before deleting the branch, and prefer leaving the local branch in place for the author to prune. Honor the project's own merge conventions if they differ.
```

Replace (the Merge bullet, unchanged, followed by the new subsection):
```
- **Merge** — never merge autonomously. Only on an explicit `merge` instruction. Default to a merge commit (`gh pr merge --merge`, not `--squash`) to preserve history; ask before deleting the branch, and prefer leaving the local branch in place for the author to prune. Honor the project's own merge conventions if they differ.

### After convergence — offer to group commits (assisted, never automatic)

When the loop reaches its clean/stop state and the current branch is a **non-default feature branch** carrying **≥ 2 commits** ahead of its target base, **offer** (ask — never do it automatically) to group the review fixups before merge.

- **Never on a primary/default branch.** Detect the default branch across the branch's configured remote `<r>` — `git symbolic-ref --short refs/remotes/<r>/HEAD` with the `<r>/` prefix stripped — falling back to the local `main`/`master`/`develop` set and the project's stated default. If detection is inconclusive and the branch isn't clearly a feature branch, **don't offer**. On the default/primary branch, skip silently.
- **Count** against the integration **target** base — the loop's inferred `$base` (`$base..HEAD`), **not** `@{upstream}..HEAD` (which is ~empty on a pushed PR branch). Capture the branch tip at loop start so the offer reports what the loop added; otherwise phrase it as "N commits ahead of base".
- **Offer:** "The loop added N commits to `<branch>` (incl. M fixups). Group them before you merge? Feature branch only — I'll keep a backup; if the branch has an upstream I'll force-push to it, else group locally (no push)." Decline → do nothing.
- **On accept — non-interactive grouping (`git rebase -i` is unavailable):**
  1. require a clean tree — if dirty (tracked or untracked), `git stash --include-untracked`; restore later with `git stash pop --index` (refuse if the index can't be restored);
  2. backup: `git branch <backup> HEAD`; and if the branch has an upstream, **capture the upstream SHA now, before any rewrite** — `lease=$(git rev-parse @{upstream})` — for the pinned lease in step 8 (capturing it later risks a fetch refreshing the tracking ref mid-rewrite and the lease then accepting a concurrent remote commit);
  3. capture the branch point as a fixed SHA — `bp=$(git merge-base "$base" HEAD)` — and `git reset --soft "$bp"` then `git reset` (reset to the captured SHA, **not** a moving ref);
  4. re-commit in the chosen groups (ask the shape: by area / coarse / squash) by staging paths per commit — grouping is **by file/area**, so per-commit splits within one file can't be reconstructed;
  5. verify tree-hash: `git rev-parse <backup>^{tree}` equals `git rev-parse HEAD^{tree}`;
  6. run the project's tests if present;
  7. restore the stash (if taken) — **before** any push;
  8. **push last, only if the branch has an upstream** (`@{upstream}` resolves): derive remote+ref from `%(upstream:remotename)`/`%(upstream:remoteref)`, and push with the lease pinned to the SHA captured **in step 2 (before the rewrite)**: `git push --force-with-lease=<remoteref>:$lease <remotename> HEAD:<remoteref>`. No upstream → group locally, **do not push or publish**;
  9. **abort/rollback on any failure before the push** — `git reset --hard <backup>`, restore the stash (remove operation-created untracked artifacts blocking it; never the user's content; if it still won't restore, STOP and surface `<backup>` + the stash entry), and do not push. Keep `<backup>` until verified success.
- **Invariants:** never overwrite remote commits the regrouped branch lacks; on any lease mismatch, abort and surface — never auto-retry. **Grouping preserves the base relationship; it does not advance onto a moved base** (the merge commit reconciles that; advancing is a separate, explicit, user-driven rebase). Never offer on a primary branch.
```

- [ ] **Step 3: Verify**

Run: `sed -n '188,235p' plugins/review-loop/skills/review-loop/SKILL.md`
Expected: §B4 now routes through the offer before waiting; the "### After convergence — offer to group commits (assisted, never automatic)" subsection follows the Merge bullet with all 9 numbered steps and the Invariants; fences/backticks balanced.

- [ ] **Step 4: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): offer to group commits after convergence (spec 010 Part B)

Assisted, never automatic; feature-branch only (robust default-branch
detection); non-interactive soft-reset grouping with backup, tree-hash check,
tests, push only to an existing upstream via pinned lease, and rollback. Route
§B4's clean-pass stop through the offer so it's reachable on the GitHub path.

Refs #43."
```

---

## Task 6: Part B — command doc invariant

**Files:**
- Modify: `plugins/review-loop/commands/review-loop.md`

- [ ] **Step 1: Add the after-convergence invariant**

Find:
```
- **Never merges autonomously** — the author decides T2/T3 fixes and the final
  merge. Default to a merge commit to preserve history.
```
Replace:
```
- **Never merges autonomously** — the author decides T2/T3 fixes and the final
  merge. Default to a merge commit to preserve history.
- **After convergence** — offers to group the review fixup commits; never
  auto-rebases, feature-branch only, never touches a primary branch.
```

- [ ] **Step 2: Verify**

Run: `grep -n 'After convergence' plugins/review-loop/commands/review-loop.md`
Expected: one match.

- [ ] **Step 3: Commit**

```bash
git add plugins/review-loop/commands/review-loop.md
git commit -m "docs(review-loop): note the after-convergence group-commits offer (spec 010 Part B)

Refs #43."
```

---

## Task 7: Content-regression test — `refute()` + anchors

**Files:**
- Modify: `tools/review-loop/test-skill-content.sh`

- [ ] **Step 1: Add a `refute()` helper after `need()`**

Find:
```
need() { # $1=regex, $2=description
  grep -Eq "$1" "$SKILL" || fail "SKILL.md missing: $2"
  pass "$2"
}
```
Replace:
```
need() { # $1=regex, $2=description
  grep -Eq "$1" "$SKILL" || fail "SKILL.md missing: $2"
  pass "$2"
}

refute() { # $1=regex, $2=description — fails if the regex IS present
  ! grep -Eq "$1" "$SKILL" || fail "SKILL.md still contains (should be gone): $2"
  pass "no longer present: $2"
}
```

- [ ] **Step 2: Add the Part A / Part B anchors before the final echo**

Find:
```
need 'references/codex-sandbox-host-fixes\.md'           "host-fix reference link"

echo "All SKILL.md content checks passed."
```
Replace:
```
need 'references/codex-sandbox-host-fixes\.md'           "host-fix reference link"

# spec 010 Part A — watch pane gated behind explicit request
need 'asked to watch'                                    "watch pane gated on explicit request"
refute 'is set, spawn'                                   "old tmux-alone spawn prose"

# spec 010 Part B — after-convergence group-commits offer
need 'After convergence'                                 "after-convergence offer section"
need 'force-with-lease'                                  "pinned-lease push guidance"
need 'never automatic'                                   "offer is assisted, never automatic"

echo "All SKILL.md content checks passed."
```

- [ ] **Step 3: Run the test**

Run: `bash tools/review-loop/test-skill-content.sh`
Expected: PASS — all checks (including `no longer present: old tmux-alone spawn prose`), ending `All SKILL.md content checks passed.`
If `refute 'is set, spawn'` FAILS, the Task 1 prose still contains "is set, spawn" — fix the Task 1 wording, not the test.

- [ ] **Step 4: Commit**

```bash
git add tools/review-loop/test-skill-content.sh
git commit -m "test(review-loop): assert spec 010 Part A/B anchors (+ refute helper)

Refs #43."
```

---

## Task 8: Version bump

**Files:**
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Bump review-loop to 0.4.0**

Find:
```
      "description": "Assisted multi-reviewer review loop — local Claude + Codex gate first, then GitHub Copilot for PRs; never merges autonomously",
      "version": "0.3.0"
```
Replace:
```
      "description": "Assisted multi-reviewer review loop — local Claude + Codex gate first, then GitHub Copilot for PRs; never merges autonomously",
      "version": "0.4.0"
```

- [ ] **Step 2: Verify**

Run: `jq -r '.plugins[] | select(.name=="review-loop") | .version' .claude-plugin/marketplace.json`
Expected: `0.4.0`. Also `jq . .claude-plugin/marketplace.json >/dev/null && echo "valid json"`.

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "chore(review-loop): bump to 0.4.0 (explicit-over-automatic UX)

Refs #43."
```

---

## Task 9: Full gate + manual verification

- [ ] **Step 1: Run the content test**

Run: `bash tools/review-loop/test-skill-content.sh`
Expected: all checks pass, exit 0.

- [ ] **Step 2: Clean-tree + no-markers check**

Run: `git status --short && git diff --cached --check`
Expected: clean tree (all committed), no conflict markers/whitespace errors.

- [ ] **Step 3: Manual read-through verification**

Confirm by reading the rendered SKILL.md §A2 and Exit conditions:
- the pane gate requires `${watch:-}` AND `${TMUX:-}`; default headless prose present; no-tmux note present;
- no remaining "If `$TMUX` is set, spawn" / "optional live-watch pane" phrasings anywhere (`grep -rn 'is set, spawn\|optional live-watch pane' plugins/review-loop/` → nothing);
- the "After convergence — offer to group commits" subsection is present with the 9 steps + invariants; §B4 routes through it.

- [ ] **Step 4: Record results** for the PR description (no commit).

---

## Task 10: Open the PR

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feat/review-loop-explicit-ux
```

- [ ] **Step 2: Open the PR linking #43**

```bash
gh pr create --base main --head feat/review-loop-explicit-ux \
  --title "review-loop: explicit-over-automatic UX (watch-pane gate + post-loop group-commits offer)" \
  --body "$(cat <<'EOF'
Implements spec 010 (docs/superpowers/specs/010-review-loop-explicit-ux-design.md).

Closes #43.

## Part A — gate the tmux watch pane (issue #43)
- Pane spawns only on an explicit watch request (the `watch` arg or an in-conversation ask) AND inside tmux; default headless even inside tmux.
- Watch-requested-but-no-tmux → brief note, headless.
- SKILL.md §A2 + prose, command doc (`watch` arg), README — all reworded so nothing implies `$TMUX`-alone triggers the pane.

## Part B — after-convergence group-commits offer (author request)
- After the loop converges on a non-default feature branch with ≥2 commits, the skill OFFERS (never auto) to group the review fixups: robust default-branch detection, non-interactive soft-reset grouping, backup branch, tree-hash check, tests, push only to an existing upstream via a pinned `--force-with-lease`, full rollback. Grouping preserves the base relationship (no auto-advance onto a moved base).
- §B4 routed through the offer so it's reachable on the GitHub clean-pass path.

## Tests
- `tools/review-loop/test-skill-content.sh` extended with a `refute()` helper + Part A/B anchors.
- review-loop 0.3.0 → 0.4.0.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: (optional) `/review-loop <PR#>`** to add the Copilot gate before merge. Never merge autonomously — the author decides.

---

## Self-Review (completed by plan author)

- **Spec coverage:** Part A gate → Task 1; Part A consistency prose → Task 2; Part A command doc → Task 3; Part A README → Task 4; Part B offer + §B4 → Task 5; Part B command doc → Task 6; Testing (refute + anchors) → Task 7; version bump → Task 8; manual/E2E verification → Task 9. All spec sections mapped.
- **Placeholder scan:** none — every Edit step has verbatim Find/Replace text; no TBD/TODO.
- **Name consistency:** the `watch` flag, `${watch:-}`/`${TMUX:-}` gate, `<backup>`/`bp`/`$base`, `@{upstream}`, `%(upstream:remotename)`/`%(upstream:remoteref)`, and the section title "After convergence — offer to group commits" are used identically across SKILL.md edits, the command doc, and the content-test anchors (`asked to watch`, `is set, spawn`, `After convergence`, `force-with-lease`, `never automatic`).
- **Branch discipline:** all work on `feat/review-loop-explicit-ux` (implementation, not main).
