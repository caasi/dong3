# 002 — Migrate `review-loop` to a dong3 Plugin

## Goal

Package the existing local `review-loop` skill (currently hand-placed at
`~/.claude/skills/review-loop/`) as a standalone plugin in the `caasi/dong3`
marketplace, so it installs and updates through the normal marketplace channel
instead of living as an untracked copy on one machine. The marketplace plugin
becomes the **single source of truth**.

As part of the migration, the skill is **dogfooded on its own PR**: the change
ships on a feature branch, and `review-loop` itself drives the review of that
branch (local Claude + Codex gate, then Copilot once the PR is open). The review
covers **every artifact the agent generated on the branch — this spec, the
implementation plan, and the code** — not just the code diff.

## Background

`review-loop` is an assisted (not autonomous) multi-reviewer convergence loop.
It runs local reviewers first — a Claude subagent always, plus Codex in a tmux
pane when available — and only then requests GitHub Copilot for PR targets. It
classifies every reviewer's comments into tiers (T1 mechanical / T2 local
refactor / T3 architectural), auto-fixes mechanical ones, and pauses for the
author's judgment on architectural ones. It never merges autonomously.

The local skill is one `SKILL.md` plus three helper scripts:

- `scripts/codex-pane.sh` — find/create/drive the Codex tmux pane.
- `scripts/copilot.sh` — request / re-request the Copilot reviewer (REST + GraphQL).
- `scripts/pr-comments.sh` — paginated fetch of reviews + inline comments; clean-pass detection.

The skill degrades gracefully: Codex is skipped silently without `$TMUX`/`codex`,
and the Copilot phase applies only to GitHub PR targets. The name is kept as
`review-loop` — the iterative loop is its identity, and graceful degradation means
the name does not over-promise.

## Scope

### In scope (this PR)

A new top-level plugin `plugins/review-loop/`, structured like `old-react`:

```
plugins/review-loop/
  .claude-plugin/plugin.json
  commands/review-loop.md
  skills/review-loop/
    SKILL.md
    README.md            # new — every dong3 skill ships one
    scripts/
      codex-pane.sh
      copilot.sh
      pr-comments.sh
```

Plus repo-level manifest and doc updates:

- The ported SKILL.md `description` + "Inputs"/"Target" prose and the README are
  generalized from "code changes" to "changes (code or design artifacts: specs,
  plans, docs)" — see § "Target scope".
- `.claude-plugin/marketplace.json`: add the `review-loop` entry and bump
  `metadata.version` `1.2.0 → 1.3.0` (convention: bump on plugin add/remove).
- Project `CLAUDE.md`: add `review-loop` to the structure tree and the
  "Plugin Details" section; update the plugin count ("seven" → "eight").

### Out of scope (follow-up, different repo)

Retiring the local copy at `~/.claude/skills/review-loop/` and repointing the
global `~/.claude/CLAUDE.md` references happen **after** this plugin is merged,
installed, and verified — they touch a different repo (`~/.claude`), so they stay
out of this PR's diff per scope discipline.

## Design

### 1. Packaging — standalone plugin

`review-loop` is a distinct capability with its own scripts and lifecycle, so it
ships as its own plugin rather than folding into an existing one. The layout
mirrors `old-react` (a `commands/` + `skills/` plugin).

`plugin.json`:

```json
{
  "name": "review-loop",
  "description": "Assisted multi-reviewer convergence loop — local Claude + Codex gate first, then GitHub Copilot for PRs; tiers comments, auto-fixes mechanical ones, never merges autonomously",
  "author": { "name": "caasi" },
  "homepage": "https://github.com/caasi/dong3",
  "repository": "https://github.com/caasi/dong3",
  "license": "MIT",
  "keywords": ["code-review", "pull-request", "copilot", "codex", "review-loop", "tmux"],
  "skills": "./skills/",
  "commands": "./commands/"
}
```

### 2. SKILL.md port — harden script paths to `${CLAUDE_PLUGIN_ROOT}`

The skill body ports over essentially verbatim, with two additions: the
script-path hardening below, and the doc-oriented review guidance from
§ "Target scope". The one substantive path change: every relative `scripts/<name>.sh`
reference becomes `${CLAUDE_PLUGIN_ROOT}/skills/review-loop/scripts/<name>.sh`.

Rationale: at runtime the working directory is the *user's repo*, not the skill
directory, so a bare `scripts/codex-pane.sh` would not resolve. `${CLAUDE_PLUGIN_ROOT}`
is unambiguous from any cwd. The three scripts themselves need **no change** — they
already use POSIX-friendly options and resolve their CLI dependencies (`codex`,
`tmux`, `gh`, `jq`) from `PATH`. The "Helper scripts" section and the inline
examples in Phase A/B are updated to use the rooted paths.

### 3. Slash command — `/review-loop`

`commands/review-loop.md`, mirroring `/old-react`. Frontmatter carries both a
`description` and an `argument-hint`, like old-react's command:

- `description:` one line summarizing the loop.
- `argument-hint: "[PR-number | branch | (blank = current branch vs base)]"`
- Body routes to the `review-loop` skill, restating the load-bearing invariants:
  local gate first, Codex/Copilot are optional and degrade silently, and the loop
  never merges autonomously.

Defaults: no argument → review the current branch vs its base (local diff target).

### 4. README.md — new user-facing doc

Every dong3 skill ships a `README.md` (user docs) distinct from `SKILL.md` (system
prompt). The new README covers: what the loop does, the reviewer roster and
priority, requirements (always-on Claude; optional tmux+codex; optional gh+jq for
Copilot), the tier model, and the never-auto-merge stance.

### 5. Target scope — review covers all generated artifacts, not only code

The local skill's prose frames the target as "code changes." This migration
generalizes it: the loop applies to **any artifact the agent produces** — design
specs, implementation plans, docs, *and* code. The principle is that nothing the
agent generates ships unreviewed.

The loop's *mechanics* (phases, tiers, scripts) need no change — a `git` diff of
`specs/*.md` or `plans/*.md` is a valid local-diff target it already handles — but
the ported SKILL.md needs two prose additions so the reviewer behaves sensibly on
documents:

- **Framing:** the `description` and the "Inputs"/"Target" language (and the
  README) say "changes (code or design artifacts: specs, plans, docs)" instead of
  "code changes," pointing the reviewer at prose-quality concerns for document
  targets (clarity, consistency, structure, factual accuracy, gaps), not only code.
- **Discipline caveat:** the existing tier model and the "one commit per item, TDD"
  instruction are written for code. The port adds a caveat that for document
  targets the reviewer flags doc-specific findings, and the **TDD / one-commit-per-item
  discipline applies only where there is executable behavior or tests** — for prose,
  prefer one logical edit per finding.

This interacts with the repo's git rule that docs may land directly on `main`:
when a doc is reviewed via this loop as part of a mixed code+docs branch, it rides
that feature branch (mixed commits → feature branch, per CLAUDE.md). Standalone
doc-only changes may still go direct to `main`; running the local Claude+Codex gate
on them first is encouraged, and the Copilot/PR phase does not apply **unless a PR
is opened** (a doc-only PR is still a valid GitHub PR target).

### 6. Manifest + project CLAUDE.md

- marketplace.json gains the `review-loop` entry (name, source, description,
  version `0.1.0`) and bumps `metadata.version` to `1.3.0`.
- CLAUDE.md: add `review-loop/` to the structure tree with a one-line gloss, add a
  "Plugin Details" paragraph, and correct the plugin count.

## Dogfooding workflow

Every artifact the agent generates is reviewed through `review-loop`, regardless
of which branch it lives on (per § "Target scope"). Because design docs may land
directly on `main` (repo git rule), the docs and the code take different routes —
but both pass the **local Claude + Codex gate** first:

1. **Docs (this spec, the plan)** — reviewed by the Claude subagent and Codex
   (tmux pane) until both are clean, then committed to `main` with a `docs:`
   message. The Copilot/PR phase does not apply (no PR for direct-to-`main` docs).
   *(This already happened for the spec: Claude APPROVED, Codex found four issues,
   fixes applied, Codex re-reviewed → APPROVED.)*
2. **Code** — built on `feat/review-loop-plugin` (RAM-disk worktree), then run
   through the **full** loop: local Claude + Codex gate, open the PR, then the
   Copilot phase, looping until a clean pass. Merge only on the author's explicit
   instruction (merge commit, history preserved).

The still-present *local copy* drives every review. The shipped SKILL.md is
**mechanically identical** to it (phases, tiers, and scripts unchanged); its prompt
wording differs only in the plugin script paths and the target-scope framing, and a
README is added. The three scripts are byte-identical. So the loop reviewing this
work is a genuine self-review — exercising every phase against its own migration,
and against every kind of artifact it now claims to cover.

## Success criteria

- `plugins/review-loop/` exists with `plugin.json`, `commands/review-loop.md`,
  `skills/review-loop/SKILL.md`, `skills/review-loop/README.md`, and the three
  scripts (executable bits preserved).
- `skills/review-loop/SKILL.md` retains its `name: review-loop` + `description`
  frontmatter (load-bearing for skill discovery); the description is updated only to
  reflect the broadened target scope (§ "Target scope").
- SKILL.md references all three scripts via `${CLAUDE_PLUGIN_ROOT}/...`; no bare
  relative `scripts/` paths remain.
- The three scripts are unchanged from the local originals (diff-clean except for
  location).
- marketplace.json lists `review-loop` and `metadata.version` is `1.3.0`; the file
  is valid JSON.
- Project CLAUDE.md reflects eight plugins including `review-loop`.
- The migration PR has been driven through `review-loop`'s own local gate (and
  Copilot, since it is a GitHub PR) to a clean pass before merge.

## Non-goals

- No change to the loop's mechanics — phases, tiers, and the three scripts are
  unchanged; a doc diff was always a valid target. The SKILL.md/README additions are
  additive guidance only: broadened target framing, doc-specific findings, and the
  caveat that the TDD / one-commit-per-item discipline applies only to executable
  changes (§ "Target scope").
- No rename (`review-loop` is kept).
- No editing of the global `~/.claude/CLAUDE.md` or deletion of the local skill in
  this PR (tracked as a post-merge follow-up).
