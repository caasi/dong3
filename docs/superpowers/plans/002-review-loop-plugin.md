# review-loop Plugin Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package the local `~/.claude/skills/review-loop` skill as a standalone `review-loop` plugin in the `caasi/dong3` marketplace, with a `/review-loop` command, scripts hardened to `${CLAUDE_PLUGIN_ROOT}`, and target scope broadened from code to any generated artifact.

**Architecture:** Mirror the `old-react` plugin layout (`.claude-plugin/plugin.json` + `commands/` + `skills/`). The three helper scripts are copied byte-identical; only `SKILL.md` is transformed (script-path hardening + target-scope framing). Repo-level `marketplace.json` and `CLAUDE.md` are updated. No build system — verification is deterministic shell checks (JSON validity, executable bits, path/frontmatter greps), not unit tests, since the artifact has no executable behavior (per spec §"Target scope").

**Tech Stack:** Bash scripts, JSON manifests, Markdown skill/command files. `jq` for JSON validation. `git worktree` on a RAM disk for isolation.

**Spec:** `docs/superpowers/specs/002-review-loop-plugin-design.md`

**Source of truth for the port:** `~/.claude/skills/review-loop/SKILL.md` and `~/.claude/skills/review-loop/scripts/{codex-pane,copilot,pr-comments}.sh`.

---

## File Structure

**Created (all under the new plugin):**
- `plugins/review-loop/.claude-plugin/plugin.json` — plugin manifest (no `version` field; version lives in marketplace.json).
- `plugins/review-loop/commands/review-loop.md` — `/review-loop` slash command.
- `plugins/review-loop/skills/review-loop/SKILL.md` — ported system prompt (transformed).
- `plugins/review-loop/skills/review-loop/README.md` — new user-facing doc.
- `plugins/review-loop/skills/review-loop/scripts/codex-pane.sh` — copied byte-identical (executable).
- `plugins/review-loop/skills/review-loop/scripts/copilot.sh` — copied byte-identical (executable).
- `plugins/review-loop/skills/review-loop/scripts/pr-comments.sh` — copied byte-identical (executable).

**Modified (repo root):**
- `.claude-plugin/marketplace.json` — add `review-loop` entry; bump `metadata.version` 1.2.0 → 1.3.0.
- `CLAUDE.md` — add `review-loop/` to the structure tree, add a Plugin Details paragraph, update count "seven" → "eight".

---

## Task 0: Feature branch on a RAM-disk worktree

**Files:** none (git setup).

**Precondition:** this plan and its spec must be committed to `main` (with `docs:` messages) **before** creating the worktree — otherwise the branch is cut from a `main` that lacks the plan. If either is still uncommitted, finish its local review (Claude + Codex), commit it to `main`, push, then proceed. The **code** goes on the feature branch created below.

- [ ] **Step 1: Check for a RAM disk**

Run: `ls /Volumes/ramdisk 2>/dev/null && echo "present" || echo "no RAM disk"`

If absent, STOP and ask the user to create one (per global CLAUDE.md "Worktrees" — do not auto-create). Suggested:
```bash
echo "$(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024)) GB total"
# then, user runs e.g.:  diskutil erasevolume HFS+ "ramdisk" $(hdiutil attach -nomount ram://8388608)
```

- [ ] **Step 2: Create the worktree + branch**

Run:
```bash
git worktree add /Volumes/ramdisk/dong3/review-loop -b feat/review-loop-plugin main
cd /Volumes/ramdisk/dong3/review-loop
```

- [ ] **Step 3: Verify the worktree is on the new branch**

Run: `git -C /Volumes/ramdisk/dong3/review-loop rev-parse --abbrev-ref HEAD`
Expected: `feat/review-loop-plugin`

**All subsequent tasks run with cwd = the worktree** (or use `git -C <worktree>`). Per global CLAUDE.md, committing from the wrong cwd lands commits on the wrong branch.

---

## Task 1: Scaffold the plugin tree and copy the scripts byte-identical

**Files:**
- Create: `plugins/review-loop/skills/review-loop/scripts/{codex-pane,copilot,pr-comments}.sh`

- [ ] **Step 1: Create directories**

Run:
```bash
mkdir -p plugins/review-loop/.claude-plugin
mkdir -p plugins/review-loop/commands
mkdir -p plugins/review-loop/skills/review-loop/scripts
```

- [ ] **Step 2: Copy the three scripts preserving mode**

Run:
```bash
cp -p ~/.claude/skills/review-loop/scripts/codex-pane.sh   plugins/review-loop/skills/review-loop/scripts/
cp -p ~/.claude/skills/review-loop/scripts/copilot.sh      plugins/review-loop/skills/review-loop/scripts/
cp -p ~/.claude/skills/review-loop/scripts/pr-comments.sh  plugins/review-loop/skills/review-loop/scripts/
```

- [ ] **Step 3: Verify byte-identical**

Run:
```bash
for f in codex-pane.sh copilot.sh pr-comments.sh; do
  diff -q ~/.claude/skills/review-loop/scripts/$f plugins/review-loop/skills/review-loop/scripts/$f
done
```
Expected: no output (all identical).

- [ ] **Step 4: Verify executable bits**

Run: `ls -l plugins/review-loop/skills/review-loop/scripts/*.sh`
Expected: each shows `-rwxr-xr-x` (executable). If not: `chmod +x plugins/review-loop/skills/review-loop/scripts/*.sh`.

- [ ] **Step 5: Commit**

```bash
git add plugins/review-loop/skills/review-loop/scripts/
git commit -m "feat(review-loop): vendor codex-pane/copilot/pr-comments scripts (byte-identical)"
```

---

## Task 2: Plugin manifest

**Files:**
- Create: `plugins/review-loop/.claude-plugin/plugin.json`

- [ ] **Step 1: Write plugin.json**

Content (mirrors `old-react` shape — no `version` field):
```json
{
  "name": "review-loop",
  "description": "Assisted multi-reviewer convergence loop — local Claude + Codex gate first, then GitHub Copilot for PRs; tiers comments, auto-fixes mechanical ones, never merges autonomously",
  "author": {
    "name": "caasi"
  },
  "homepage": "https://github.com/caasi/dong3",
  "repository": "https://github.com/caasi/dong3",
  "license": "MIT",
  "keywords": [
    "code-review",
    "pull-request",
    "copilot",
    "codex",
    "review-loop",
    "tmux"
  ],
  "skills": "./skills/",
  "commands": "./commands/"
}
```

- [ ] **Step 2: Verify valid JSON**

Run: `jq empty plugins/review-loop/.claude-plugin/plugin.json && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add plugins/review-loop/.claude-plugin/plugin.json
git commit -m "feat(review-loop): add plugin.json manifest"
```

---

## Task 3: Port SKILL.md — harden script paths + broaden target scope

**Files:**
- Create: `plugins/review-loop/skills/review-loop/SKILL.md` (from the local original, transformed)

The local SKILL.md has **14** `scripts/` references and is framed for "code changes." This task copies it, then applies (a) a global script-path hardening and (b) four framing edits.

- [ ] **Step 1: Copy the original**

Run:
```bash
cp ~/.claude/skills/review-loop/SKILL.md plugins/review-loop/skills/review-loop/SKILL.md
```

- [ ] **Step 2: Harden every script path to `${CLAUDE_PLUGIN_ROOT}`**

Run (note `#` sed delimiter so the `/` in the replacement is literal; `$ { }` are literal in sed replacement text):
```bash
sed -i '' 's#scripts/#${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/#g' \
  plugins/review-loop/skills/review-loop/SKILL.md
```
(On GNU sed, drop the `''` after `-i`.)

- [ ] **Step 3: Verify no bare `scripts/` paths remain and the count is right**

Run:
```bash
grep -c 'scripts/' plugins/review-loop/skills/review-loop/SKILL.md       # context occurrences
grep -c '\${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/' plugins/review-loop/skills/review-loop/SKILL.md
grep -nE '(^|[^/])\bscripts/' plugins/review-loop/skills/review-loop/SKILL.md | grep -v 'CLAUDE_PLUGIN_ROOT' || echo "no bare scripts/ paths"
```
Expected: the rooted count is **14**; the final grep prints `no bare scripts/ paths`.

- [ ] **Step 4: Framing edit F1 — frontmatter `description`**

Edit the `description:` line. Replace the leading sentence:
- OLD: `General assisted review loop for code changes.`
- NEW: `General assisted review loop for changes — code or design artifacts (specs, plans, docs).`

Leave the rest of the description sentence (Prefers local reviewers … Never merges autonomously.) unchanged. Verify the `name: review-loop` line is intact.

- [ ] **Step 5: Framing edit F2 — intro target line**

- OLD: `General-purpose: the target may be a **local branch / working diff** (no remote needed) or a **GitHub PR**.`
- NEW: `General-purpose: the target may be a **local branch / working diff** (no remote needed) or a **GitHub PR**, and the changes under review may be **code or design artifacts** (specs, plans, docs).`

- [ ] **Step 6: Framing edit F3 — Inputs/Target parenthetical**

In the `## Inputs` section, append to the `- **Target** — one of:` block a clarifying note that the diff may contain code, docs, or both. Add as a sub-bullet after the existing target options:
```markdown
  - The diff may contain code, design docs (specs/plans), or both — the loop reviews whatever changed.
```

- [ ] **Step 7: Framing edit F4 — Tiers TDD/doc caveat**

In the `## Tiers` section, replace the sentence:
- OLD: `One commit per item, TDD, and reply/note the commit hash.`
- NEW: `One commit per item, TDD, and reply/note the commit hash. (TDD and one-commit-per-item apply to executable changes; for prose/doc targets there are no tests to write first — prefer one logical edit per finding and review for clarity, consistency, structure, and factual accuracy.)`

- [ ] **Step 8: Verify frontmatter + framing**

Run:
```bash
head -4 plugins/review-loop/skills/review-loop/SKILL.md       # name + description frontmatter present
grep -c 'code or design artifacts' plugins/review-loop/skills/review-loop/SKILL.md   # expect 2 (F1, F2)
grep -c 'apply to executable changes' plugins/review-loop/skills/review-loop/SKILL.md # expect 1 (F4)
```
Expected: frontmatter block intact with `name:` and `description:`; counts as noted.

- [ ] **Step 9: Commit**

```bash
git add plugins/review-loop/skills/review-loop/SKILL.md
git commit -m "feat(review-loop): port SKILL.md — root script paths, broaden target to docs"
```

---

## Task 4: Slash command

**Files:**
- Create: `plugins/review-loop/commands/review-loop.md`

- [ ] **Step 1: Write the command file**

Content (mirrors `old-react`'s command — `description` + `argument-hint` frontmatter, body routes to the skill):
```markdown
---
description: Run the assisted multi-reviewer review loop (local Claude + Codex gate, then Copilot for PRs)
argument-hint: "[PR-number | branch | (blank = current branch vs base)]"
---

# /review-loop

Run the `review-loop` skill against a target.

**Usage:**

- `/review-loop` — review the current branch versus its base (local diff target).
- `/review-loop <branch>` — review the given branch versus its base.
- `/review-loop <PR-number>` — review an open GitHub PR (adds the Copilot phase).

**Target:**

The change under review may be code or design artifacts (specs, plans, docs). For
document targets the loop reviews clarity, consistency, structure, and factual
accuracy; TDD / one-commit-per-item discipline applies only to executable changes.

**Behavior:**

Invoke the `review-loop` skill. Load-bearing invariants the skill enforces:

- **Local gate first** — a Claude subagent always reviews; Codex (in a tmux pane)
  joins when `$TMUX` is set and `codex` is on `PATH`, otherwise it is skipped
  silently. The local gate must be clean before any GitHub PR is opened.
- **Copilot is GitHub-only** — requested only for PR targets, after the local gate.
- **Never merges autonomously** — the author decides T2/T3 fixes and the final
  merge. Default to a merge commit to preserve history.
```

- [ ] **Step 2: Verify frontmatter parses**

Run: `head -4 plugins/review-loop/commands/review-loop.md`
Expected: opening `---`, `description:`, `argument-hint:`, closing `---`.

- [ ] **Step 3: Commit**

```bash
git add plugins/review-loop/commands/review-loop.md
git commit -m "feat(review-loop): add /review-loop slash command"
```

---

## Task 5: README

**Files:**
- Create: `plugins/review-loop/skills/review-loop/README.md`

- [ ] **Step 1: Write the README**

Content (user-facing; models `old-react`'s README structure):
```markdown
# review-loop

An assisted (not autonomous) multi-reviewer convergence loop for changes — code or
design artifacts (specs, plans, docs). It runs local reviewers first and only then
reaches for GitHub Copilot, and it never merges on its own.

## What this is

A Claude Code skill that loops reviewers over a diff until they stop finding
problems, classifying every comment into tiers and pausing for your judgment on the
architectural ones. The point of the local-first ordering: Claude and Codex
reviewing **together** catch different classes of issues and tighten the diff before
it ever reaches GitHub, so Copilot has much less to flag and rounds converge faster.

## Reviewer roster (in priority order)

1. **Claude subagent** — always; needs nothing extra.
2. **Codex** (in a `tmux` pane) — when `$TMUX` is set and `codex` is on `PATH`;
   skipped silently otherwise.
3. **GitHub Copilot** — only for GitHub PR targets, after the local gate is clean.

## Requirements

- **Always usable:** the Claude subagent reviewer.
- **Codex (optional):** a `tmux` session and the `codex` CLI on `PATH`.
- **Copilot phase (optional):** an authenticated `gh` CLI and `jq`; GitHub PRs only.

## Tiers

- **T1 mechanical** — typos, lint, null checks, doc fixes — auto-fixed.
- **T2 local refactor** — extraction, naming, validation — resolved with you first.
- **T3 architectural** — module moves, API shape, "should this exist" — your call.

For document targets, findings are about clarity, consistency, structure, and
factual accuracy; the TDD / one-commit-per-item discipline applies only where there
is executable behavior.

## How to use

```text
review this branch with review-loop
```

Or the slash command:

```text
/review-loop              # current branch vs base
/review-loop 1234         # open PR #1234 (adds Copilot)
```

## Non-goals

- Not autonomous — you decide T2/T3 fixes and the final merge.
- Not a squash-merge tool — defaults to a merge commit to preserve history.
- The Copilot path is GitHub-only; on other forges the local Claude + Codex gate
  still applies.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/review-loop/skills/review-loop/README.md
git commit -m "docs(review-loop): add user-facing README"
```

---

## Task 6: Update the marketplace manifest

**Files:**
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Bump `metadata.version` 1.2.0 → 1.3.0**

Edit the `metadata.version` field from `"1.2.0"` to `"1.3.0"`.

- [ ] **Step 2: Append the `review-loop` plugin entry**

Add to the `plugins` array (after the `old-react` entry):
```json
    {
      "name": "review-loop",
      "source": "./plugins/review-loop",
      "description": "Assisted multi-reviewer review loop — local Claude + Codex gate first, then GitHub Copilot for PRs; never merges autonomously",
      "version": "0.1.0"
    }
```
(Remember the trailing comma on the preceding entry.)

- [ ] **Step 3: Verify valid JSON, version, and entry**

Run:
```bash
jq -e '.metadata.version == "1.3.0"' .claude-plugin/marketplace.json
jq -e '.plugins[] | select(.name=="review-loop") | .source == "./plugins/review-loop"' .claude-plugin/marketplace.json
jq '.plugins | length' .claude-plugin/marketplace.json   # expect 8
```
Expected: both `jq -e` print `true` (exit 0); length is `8`.

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat(review-loop): register plugin in marketplace, bump to v1.3.0"
```

---

## Task 7: Update project CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the intro count**

In "What This Is": change `seven independent plugins` → `eight independent plugins`.

- [ ] **Step 2: Add to the structure tree**

In the `plugins/` block, add a line (keep alphabetical-ish ordering consistent with the file; after `owasp/` is fine):
```
  review-loop/                    # Assisted multi-reviewer loop (Claude + Codex → Copilot), never auto-merges
```

- [ ] **Step 3: Add a Plugin Details paragraph**

Under "## Plugin Details", add:
```markdown
**review-loop:** Assisted, not autonomous, multi-reviewer convergence loop. Local reviewers run first — a Claude subagent always, plus Codex in a `tmux` pane when available — then GitHub Copilot for PR targets. Helper scripts in `skills/review-loop/scripts/` (`codex-pane.sh`, `copilot.sh`, `pr-comments.sh`) are referenced via `${CLAUDE_PLUGIN_ROOT}`. Target scope is any changed artifact: code or design artifacts (specs, plans, docs). One slash command: `/review-loop [PR# | branch | blank]`. Spec: `docs/superpowers/specs/002-review-loop-plugin-design.md`.
```

- [ ] **Step 4: Verify**

Run:
```bash
grep -c 'eight independent plugins' CLAUDE.md      # expect 1
grep -c 'review-loop' CLAUDE.md                    # expect >= 3 (tree + details + command)
```

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(review-loop): document plugin in project CLAUDE.md (eight plugins)"
```

---

## Task 8: Full structural validation

**Files:** none (verification only).

- [ ] **Step 1: Run the consolidated check**

Run from the worktree root:
```bash
set -e
# manifests valid
jq empty plugins/review-loop/.claude-plugin/plugin.json
jq empty .claude-plugin/marketplace.json
# tree complete
test -f plugins/review-loop/commands/review-loop.md
test -f plugins/review-loop/skills/review-loop/SKILL.md
test -f plugins/review-loop/skills/review-loop/README.md
# scripts executable + byte-identical to source
for f in codex-pane.sh copilot.sh pr-comments.sh; do
  test -x plugins/review-loop/skills/review-loop/scripts/$f
  diff -q ~/.claude/skills/review-loop/scripts/$f plugins/review-loop/skills/review-loop/scripts/$f
done
# SKILL.md: frontmatter + no bare scripts/ paths
grep -q '^name: review-loop' plugins/review-loop/skills/review-loop/SKILL.md
grep -q '^description:' plugins/review-loop/skills/review-loop/SKILL.md
! grep -nE '(^|[^/])scripts/' plugins/review-loop/skills/review-loop/SKILL.md | grep -qv 'CLAUDE_PLUGIN_ROOT'
echo "ALL STRUCTURAL CHECKS PASSED"
```
Expected: `ALL STRUCTURAL CHECKS PASSED`. Fix any failing check before proceeding.

---

## Task 9: Dogfood — review the branch through review-loop, then PR

**Files:** none (this runs the skill against the work just built).

This is the spec's dogfooding workflow for the **code** route. The spec and plan were already locally reviewed and committed to `main`; here the plugin code on `feat/review-loop-plugin` runs the **full** loop.

> **Note on the script paths below:** these invoke the still-installed **local** skill, which drives this review — not the freshly-vendored plugin copy. **Stay in the dong3 worktree** as cwd (so `gh`/`git` infer the correct repo and the diff is the branch under review) and call the local scripts by **absolute path**: `~/.claude/skills/review-loop/scripts/codex-pane.sh`, `~/.claude/skills/review-loop/scripts/copilot.sh`, `~/.claude/skills/review-loop/scripts/pr-comments.sh`. Do **not** `cd` into the local skill dir (that breaks repo inference), do not use the bare `scripts/...` form, and do not rewrite them to `${CLAUDE_PLUGIN_ROOT}` (that points at the vendored copy being reviewed).

- [ ] **Step 1: Local gate — Claude subagent**

Invoke `review-loop` against the working diff (the new plugin tree + manifest/CLAUDE.md changes). Dispatch a Claude subagent reviewer. Classify findings T1/T2/T3, resolve T2/T3 with the author, fix, commit per item.

- [ ] **Step 2: Local gate — Codex**

Use the open Codex pane (`~/.claude/skills/review-loop/scripts/codex-pane.sh ensure`; reuse the existing pane if still alive). Send the diff/summary, loop until Codex is clean or hits its usage limit. Apply fixes per tier.

- [ ] **Step 3: Converge the local gate**

Re-run Steps 1–2 after fixes until Claude is clean AND Codex is clean (or skipped/usage-limited). Only then open the PR.

- [ ] **Step 4: Open the PR**

Run:
```bash
git push -u origin feat/review-loop-plugin
gh pr create --base main --head feat/review-loop-plugin \
  --title "feat(review-loop): migrate review-loop skill to a dong3 plugin" \
  --body "Implements docs/superpowers/specs/002-review-loop-plugin-design.md. Self-reviewed via review-loop's own local Claude + Codex gate."
```

- [ ] **Step 5: Copilot phase**

`~/.claude/skills/review-loop/scripts/copilot.sh request <pr>` (or first-time via the GitHub UI), then `/loop 3m ~/.claude/skills/review-loop/scripts/pr-comments.sh fetch <pr>`. Tier and fix new comments; `~/.claude/skills/review-loop/scripts/copilot.sh rerequest <pr>` after pushes; stop on `~/.claude/skills/review-loop/scripts/pr-comments.sh clean-pass <pr>`.

- [ ] **Step 6: Surface to the author**

On a clean Copilot pass, stop and report. Do not merge — merge only on the author's explicit instruction (merge commit; ask before deleting the branch).

---

## Post-merge follow-up (OUT OF SCOPE for this plan — different repo)

Tracked but **not** done here (touches `~/.claude`, not the dong3 repo):
- After the plugin is merged, installed via the marketplace, and verified, retire the local copy at `~/.claude/skills/review-loop/`.
- Repoint references in the global `~/.claude/CLAUDE.md` from the local skill path to the installed plugin.
