# review-loop Headless Codex (`codex exec review`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the review-loop skill's tmux-pane Codex channel with the headless `codex exec review` subcommand, demote tmux to an optional live-watch layer, and make Codex review run anywhere `codex` is on `PATH`.

**Architecture:** This is a skill (system-prompt) + docs + manifest change, not executable code — the artifacts are Markdown (`SKILL.md`, `README.md`), JSON (`marketplace.json`), and a script deletion. There are no unit tests; verification is done with `grep` assertions (no stale `tmux`/`codex-pane` references survive), JSON validity checks, and **empirical `codex` CLI smoke runs** (the spec requires confirming session-id capture, untrusted-dir behavior, and that a non-tmux run actually reviews). The empirical findings in Task 1 ground the wording written in Tasks 2 & 3.

**Tech Stack:** Markdown, JSON, Bash, the `codex` CLI (OpenAI Codex), `git`/`gh`.

**Spec:** `docs/superpowers/specs/003-review-loop-headless-codex-design.md`

**Scope note:** This is one cohesive subsystem (the Codex channel of one skill) — a single plan. No decomposition needed.

---

## File Structure

All paths under the plugin root `plugins/review-loop/`:

| File | Action | Responsibility after change |
|------|--------|------------------------------|
| `skills/review-loop/SKILL.md` | Modify | Phase A2 documents `codex exec review`/`resume` inline; intro, reviewer-roster, Requirements, PATH note, Helper-scripts, and `description` frontmatter drop the tmux gate |
| `skills/review-loop/scripts/codex-pane.sh` | **Delete** | (removed — channel no longer scrapes a pane) |
| `commands/review-loop.md` | Modify | Overlooked consumer: "Local gate first" invariant drops the `$TMUX`/tmux-pane gate (Codex gates on `codex` on `PATH`; tmux optional live-watch) |
| `skills/review-loop/README.md` | Modify | User-facing roster/requirements reflect headless Codex + optional live-watch |
| `.claude-plugin/marketplace.json` (repo root) | Modify | Bump `review-loop` plugin version `0.1.1 → 0.2.0` |
| `CLAUDE.md` (repo root) | Modify | One-line `review-loop` gloss drops "Codex in a `tmux` pane" |

`copilot.sh` and `pr-comments.sh` are **not touched**.

---

## Task 0: Feature branch on a RAM-disk worktree

Per project convention, code changes go on a feature branch in a RAM-disk worktree (never the main checkout).

- [ ] **Step 1: Check for a mounted RAM disk**

Run: `ls /Volumes/ramdisk 2>/dev/null && echo "RAM disk present" || echo "no RAM disk"`

If absent, **stop and ask the author** to create one (do not auto-create — it's their call on size/name); see the project's Worktrees convention. If present, continue.

- [ ] **Step 2: Create the worktree + branch from `main`**

Run:
```bash
git -C /Users/caasi/GitHub/caasi/dong3 worktree add \
  /Volumes/ramdisk/dong3/feat-headless-codex -b feat/review-loop-headless-codex main
cd /Volumes/ramdisk/dong3/feat-headless-codex
```
Expected: worktree created, HEAD on `feat/review-loop-headless-codex`.

- [ ] **Step 3: Verify branch**

Run: `git branch --show-current`
Expected: `feat/review-loop-headless-codex` (NOT `main`).

> All subsequent tasks run **inside the worktree** (`cd` there, or `git -C <worktree>`).

---

## Task 1: Empirical `codex` CLI verification (grounds Tasks 2–3)

The spec defers three facts to "the plan verifies." Resolve them now so the SKILL.md wording is grounded, not guessed. Record the answers in a scratch note — they decide exact wording in Task 2.

Throughout, **capture Codex's real exit status** with the redirect-then-`rc=$?` pattern — never `… | tee; echo $?` (that reads `tee`'s status, the very trap §1 of the spec warns about).

- [ ] **Step 0: Create a throwaway uncommitted change** (the fresh worktree is clean, but `review --uncommitted` needs a diff)

Run: `printf '\n<!-- codex smoke -->\n' >> README.md`
(Reverted in Step 5. Any tracked file works; this just gives `--uncommitted` something to review.)

- [ ] **Step 1: Session-id capture mechanism (§5 of spec)**

Run (target flag takes **no** prompt — see Step 1 note):
```bash
codex exec --json --sandbox read-only review --uncommitted >/tmp/cx.json 2>/tmp/cx.err; rc=$?
echo "rc=$rc"; grep -oiE '"thread_id"[[:space:]]*:[[:space:]]*"[^"]+"' /tmp/cx.json | head
```
**Verified (codex-cli 0.135.0):** `rc=0`; the `--json` stream carries `"thread_id":"<uuid>"` — parse `thread_id` (not `session_id`/`conversation_id`). **Also discovered:** `review --uncommitted -` (target flag + `[PROMPT]`/stdin) is **invalid** (rc=2, *"'--uncommitted' cannot be used with '[PROMPT]'"*) — target-flag forms take no prompt; custom focus uses freeform `review -`. Spec 003 §1/§4/§5 reconciled accordingly (this PR).

- [ ] **Step 2: Resume-by-id round-trips**

Run (using the id captured in Step 1):
```bash
printf 'Just confirming resume works; no action needed.\n' \
  | codex exec --sandbox read-only resume "<thread_id>" - \
      >/tmp/cx2.out 2>/tmp/cx2.err; rc=$?
echo "rc=$rc"; cat /tmp/cx2.out
```
**Verified:** `rc=0` — resume by `thread_id` works (resume's trailing `-` stdin prompt is valid; only `review` target flags conflict with a prompt). Id-based resume is the primary path, not just `--last`.

- [ ] **Step 3: Untrusted / first-run directory behavior (§4 of spec)**

Run:
```bash
tmp=$(mktemp -d "${TMPDIR:-/tmp}/rl.XXXXXX"); git -C "$tmp" init -q
echo base > "$tmp/f"; git -C "$tmp" add f; git -C "$tmp" commit -qm init   # give it a HEAD
echo changed >> "$tmp/f"                                                    # then a real diff
codex exec --sandbox read-only -C "$tmp" review --uncommitted \
  >/tmp/cx3.out 2>/tmp/cx3.err; rc=$?
echo "rc=$rc"; tail -3 /tmp/cx3.err; rm -rf "$tmp"
```
**Verified:** `rc=0` — a read-only review **proceeds** in a fresh repo; no trust hard-fail. So §4 needs no dedicated trust branch (any future trust-gate non-zero exit lands in the "Codex-failed" path). The initial commit + edit ensures `rc` reflects trust behavior, not "no HEAD / nothing to review."

- [ ] **Step 4: Non-tmux smoke run (the headline regression fix)**

Run with tmux disabled:
```bash
env -u TMUX codex exec --sandbox read-only review --uncommitted \
  >/tmp/cx4.out 2>/tmp/cx4.err; rc=$?
echo "rc=$rc"; head /tmp/cx4.out
```
**Verified:** `rc=0` + a review on stdout — Codex review works with no tmux (headline regression fixed). Re-run in Task 8 as the acceptance check.

- [ ] **Step 5: Record findings + revert the throwaway change**

Run: `git checkout README.md` (drop the Step 0 edit). Then write the four answers (session-id field/parse path, resume-by-id ✓/✗, untrusted-dir behavior, non-tmux ✓) to a scratch note at `/tmp/codex-verify-notes.md` (outside the worktree, not committed). These feed Task 2 wording. No commit this task.

---

## Task 2: Rewrite SKILL.md Phase A2 (the Codex channel)

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md` (Phase A2, currently lines ~64–82)

- [ ] **Step 0: Empirical findings already reconciled.** Task 1 confirmed: session id = `--json` `thread_id`; resume-by-id works; untrusted dir proceeds read-only (no hard-fail); **and** target flags conflict with `[PROMPT]` (so `review --uncommitted -` is invalid — targeted forms take no prompt, custom focus uses freeform `review -`). Spec 003 §1/§4/§5 + success criteria were reconciled on this branch. Write the A2 wording to match those corrected commands.

- [ ] **Step 1: Replace the A2 body** with the headless mechanism from spec §1, §4, §5. Cover, in this order:
  1. **First-round invocation** mapping the target to a `review` subcommand, `--sandbox read-only` **before** the subcommand, **`--json`** so the round's `thread_id` can be captured (target flags take **no** prompt — they conflict with `[PROMPT]`):
     ```bash
     codex exec --json --sandbox read-only review --uncommitted   # working tree
     codex exec --json --sandbox read-only review --base "$base"  # branch vs base
     codex exec --json --sandbox read-only review --commit "$sha" # one commit
     ```
     For custom focus (e.g. a doc artifact), use the freeform form — no target flag, Codex infers the diff (keep `--json`): `printf '<focus, name the target in prose>' | codex exec --json --sandbox read-only review -`.
  2. **Safe, per-round capture** (not `| tee`, which masks `$?`; and `set -e`-safe): write each round to its own `$round` file, append to the cumulative `$log` only for the watch pane, read `$round` for classification:
     ```bash
     round="$(mktemp "${TMPDIR:-/tmp}/review-loop-codex.XXXXXX")"; rc=0
     codex exec --json --sandbox read-only review --base "$base" >"$round" 2>"$err" || rc=$?
     cat "$round" >>"$log"
     thread_id=$(sed -nE 's/.*"thread_id"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$round" | head -1)
     ```
  3. **Model/effort:** pass no `-m`/effort; defer to `~/.codex/config.toml` `review_model`; session override only if the author names a model.
  4. **Convergence rounds:** resume by the captured **`thread_id`** (from the `--json` stream): `… resume "$thread_id" -`; ordered fallbacks `--last` (cwd-scoped caveat) → fresh freeform `review -` with prior findings restated.
  5. **Three outcomes** (from §4): `rc==0` → Claude reads stdout and classifies T1/T2/T3; non-zero **with** a limit-pattern stderr → usage-limited, stop Codex sub-loop, fall back to Claude-only (+ Copilot for GitHub); non-zero **without** a limit match → "Codex failed", **surface to author** with stderr summary (do not swallow). If Task 1 Step 3 showed a trust failure, name it as an example of the "Codex failed" branch.
  6. **Freeform fallback** (rare): only when `codex` lacks `exec review` or the target is non-git (then add `--skip-git-repo-check`).

- [ ] **Step 2: Verify the A2 body uses no pane-scraping mechanics**

Run: `grep -nE 'capture-pane|paste-buffer|send-keys|trust/onboarding' plugins/review-loop/skills/review-loop/SKILL.md`
Expected: **no matches** (these scraping verbs are gone repo-wide after the rewrite). Note: `codex-pane` and the roster/requirements `$TMUX` gate still appear until Task 3 cleans them — those are checked in Task 3 Step 6 and Task 8, not here.

- [ ] **Step 3: Add the optional tmux live-watch + per-run log/teardown** (spec §3) to A2:
  - Per-run `$log`/`$err`, truncated/created at loop start. Each round's stdout goes to its own `$round` file (read by Claude); `cat "$round" >>"$log"` feeds the cumulative watch log, `$err` overwritten per attempt.
  - If `$TMUX` set, spawn the read-only pane **before the first `codex` call** so it covers round 1: `tmux split-window -h -P -F '…' "tail -f '$log'"` (quote `$log`), capture its id, and `tmux kill-pane` it at loop end.
  - Tear the pane down at loop end (clean / fallback / abort): `tmux kill-pane -t "$watch_pane"`.

- [ ] **Step 4: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): headless codex exec review channel (Phase A2)"
```

---

## Task 3: Update SKILL.md surrounding sections (drop the tmux gate)

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/SKILL.md` — description frontmatter (line ~3), intro (line ~10), Requirements (lines ~18–22), Reviewer roster item 2 (line ~35), Helper scripts (lines ~40–46).

- [ ] **Step 1: `description` frontmatter** — replace "Codex in a tmux pane" with "Codex via `codex exec review` (headless; optional tmux live-watch)".

- [ ] **Step 2: Intro paragraph** — change "Codex (via the `codex` CLI in a tmux pane)" to headless wording; tmux is optional live-watch, not the channel.

- [ ] **Step 3: Reviewer roster item 2** — gate on `codex` being on `PATH`, **not** `$TMUX`. (`$TMUX` only enables the optional watch pane.)

- [ ] **Step 4: Requirements** — Codex reviewer needs only `codex` on `PATH`; list tmux under an optional "live-watch" note. Update the PATH-dependency sentence so it no longer lists `tmux` as required for the Codex step.

- [ ] **Step 5: Helper scripts** — remove the `codex-pane.sh` bullet entirely; keep `copilot.sh` and `pr-comments.sh`.

- [ ] **Step 6: Verify no tmux-as-channel / codex-pane references remain**

Run:
```bash
grep -nE 'codex-pane|tmux|\$TMUX' plugins/review-loop/skills/review-loop/SKILL.md
```
Expected: the ONLY surviving matches are the optional live-watch references (Task 2.3). No `codex-pane.sh`, no "skipped silently without `$TMUX`" gating of the Codex review itself.

- [ ] **Step 7: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): drop tmux gate from SKILL.md roster/requirements/description"
```

---

## Task 4: Delete codex-pane.sh

**Files:**
- Delete: `plugins/review-loop/skills/review-loop/scripts/codex-pane.sh`

- [ ] **Step 1: Remove the script**

Run: `git rm plugins/review-loop/skills/review-loop/scripts/codex-pane.sh`
Expected: file staged for deletion.

- [ ] **Step 2: Verify no live references in the shipped skill**

Run: `grep -rnE 'codex-pane' plugins/review-loop/skills/review-loop/SKILL.md plugins/review-loop/skills/review-loop/README.md`
Expected: **no matches** (SKILL.md cleaned in Task 3, README in Task 5). Note: `docs/superpowers/specs/00{2,3}-*` and `docs/superpowers/plans/003-*` mention `codex-pane.sh` descriptively (allowed), and `CLAUDE.md` still names it until Task 7 — do not expect those to be empty.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(review-loop): remove codex-pane.sh (channel is now codex exec)"
```

---

## Task 5: Update README.md

**Files:**
- Modify: `plugins/review-loop/skills/review-loop/README.md` (lines 11–13, 17–19, 24–25, 55–56)

- [ ] **Step 1: Reviewer roster (line 18)** — change "Codex (in a `tmux` pane) — when `$TMUX` is set and `codex` is on `PATH`" to "Codex (headless `codex exec review`) — when `codex` is on `PATH`; tmux only adds an optional live-watch pane".

- [ ] **Step 2: Requirements (line 25)** — "Codex (optional): the `codex` CLI on `PATH` (tmux optional, for a live-watch pane only)".

- [ ] **Step 3: Intro/What-this-is** — adjust any "Codex … tmux" phrasing to headless; keep the Claude+Codex-together rationale.

- [ ] **Step 4: Verify**

Run: `grep -nE 'tmux|\$TMUX' plugins/review-loop/skills/review-loop/README.md`
Expected: every hit is optional-live-watch language; no gating ("when `$TMUX` is set", "a tmux session") remains.

- [ ] **Step 5: Commit**

```bash
git add plugins/review-loop/skills/review-loop/README.md
git commit -m "docs(review-loop): README reflects headless Codex + optional live-watch"
```

---

## Task 6: Bump plugin version in marketplace.json

**Files:**
- Modify: `.claude-plugin/marketplace.json` (repo root)

- [ ] **Step 1: Bump the `review-loop` plugin version `0.1.1 → 0.2.0`** (behavior change to the mechanism → minor bump). Leave `metadata.version` (`1.3.0`) — no plugin added/removed.

- [ ] **Step 2: Verify valid JSON + the bump**

Run:
```bash
python3 -c "import json;d=json.load(open('.claude-plugin/marketplace.json'));print([p['version'] for p in d['plugins'] if p['name']=='review-loop'])"
```
Expected: `['0.2.0']` and no JSON error.

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "chore(review-loop): bump plugin to 0.2.0 (headless codex channel)"
```

---

## Task 7: Update project CLAUDE.md gloss

**Files:**
- Modify: `CLAUDE.md` (repo root) — the `review-loop` "Plugin Details" paragraph (line ~57) says both "Codex in a `tmux` pane when available" **and** lists `codex-pane.sh` in the helper-scripts enumeration. Both are now stale.

- [ ] **Step 1: Update the gloss** to "Codex via `codex exec review` (headless) when `codex` is on `PATH`; tmux optional for a live-watch pane", **and remove `codex-pane.sh`** from the helper-scripts parenthetical (leaving `copilot.sh`, `pr-comments.sh`) — Task 4 deleted that file, so the name must not dangle.

- [ ] **Step 2: Verify** (use `tmux`, not `tmux pane` — the source has a backtick between the words: `` `tmux` pane ``)

Run: `grep -nE 'codex-pane|tmux' CLAUDE.md`
Expected: **no `codex-pane` match anywhere**; the review-loop line mentions `tmux` only as the optional live-watch, not as the Codex channel.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(review-loop): CLAUDE.md gloss reflects headless codex channel"
```

---

## Task 8: Final acceptance verification + PR

- [ ] **Step 1: No stale `codex-pane` references in the shipped skill**

Run:
```bash
grep -rnE 'codex-pane' plugins/review-loop/skills/review-loop/SKILL.md \
  plugins/review-loop/skills/review-loop/README.md
```
Expected: empty.

- [ ] **Step 2: `tmux` / `$TMUX` appear only as optional live-watch**

Run: `grep -rnE 'tmux|\$TMUX' plugins/review-loop/skills/review-loop/`
Expected: every hit is live-watch language (spawn/`tail -f`/kill-pane the spectator pane); none gating the Codex review (no "when `$TMUX` is set", "a tmux session", or backticked `` `tmux` pane `` channel wording).

- [ ] **Step 3: Re-run the non-tmux smoke check (acceptance criterion)**

The branch now has commits vs `main`, so review the branch diff (no dirty file needed):
```bash
env -u TMUX codex exec --sandbox read-only review --base main \
  >/tmp/cx.out 2>/tmp/cx.err; rc=$?
echo "rc=$rc"; head /tmp/cx.out
```
Expected: `rc=0` + a review on stdout (proves the headline regression — Codex review with no tmux — is fixed).

- [ ] **Step 4: Marketplace JSON still valid**

Run: `python3 -m json.tool .claude-plugin/marketplace.json > /dev/null && echo OK`
Expected: `OK`.

- [ ] **Step 5: Local gate on the code FIRST (before any PR)**

Per the spec's dogfooding order (local Claude + Codex gate → PR → Copilot), run the **current** review-loop skill against this branch's diff *before* pushing. Resolve T1/T2/T3 to a clean local pass (Claude subagent + Codex). Only when the local gate is clean does the PR get opened.

- [ ] **Step 6: Open the PR and enter the Copilot phase**

Run:
```bash
git push -u origin feat/review-loop-headless-codex
gh pr create --fill --base main
```
Then hand back to the review-loop skill for the Copilot phase (request → poll → clean pass). Merge only on the author's explicit instruction (merge commit, preserve history).

---

## Notes for the implementer

- **Dogfooding:** the docs (spec 003, this plan) are reviewed by the *current* (tmux-pane) review-loop and land on `main`; the *code* rides this feature branch through the full loop. Do not merge autonomously.
- **One commit per task** keeps the PR review-loop's tier classification clean (these are doc/skill edits, so "one logical edit per finding" applies, not red-green TDD).
- **Don't touch** `copilot.sh` / `pr-comments.sh`, `metadata.version`, or the global `~/.claude/CLAUDE.md` (post-merge follow-up).
- If Task 1's empirical results contradict the spec's assumptions (e.g. `--json` carries no session id, or untrusted dirs hard-fail), **update spec 003 in the same PR** and note the correction — the spec explicitly delegated these to the plan.
