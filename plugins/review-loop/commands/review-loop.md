---
description: Run the assisted adversarial review panel — local reviewers answer blind on the same unfixed diff, then attack each other's findings; a forge reviewer follows for PR/MR targets; never merges autonomously
argument-hint: "[PR-number | branch | (blank = current branch vs base)]"
---

# /review-loop

Run the `review-loop` skill against a target.

**Usage:**

- `/review-loop` — review the current branch versus its base (local diff target).
- `/review-loop <branch>` — review the given branch versus its base.
- `/review-loop <PR-number>` — review an open GitHub PR (adds the forge reviewer; GitHub Copilot is the built-in adapter and needs no enrollment).
- append `watch` (e.g. `/review-loop watch`, `/review-loop 46 watch`) — open a live spectator pane for the Codex review; **requires a tmux session**. A lone `watch` token is the watch request against the default target, not a branch named `watch`.

**Target:**

The change under review may be code or design artifacts (specs, plans, docs). For
document targets the loop reviews clarity, consistency, structure, and factual
accuracy; TDD / one-commit-per-item discipline applies only to executable changes.

**Behavior:**

Invoke the `review-loop` skill. Load-bearing invariants the skill enforces:

- **Local gate first** — a Claude subagent always reviews; Codex (headless
  `codex exec --json --sandbox read-only review -`) joins when `codex` is live; tmux is optional and
  opens a live-watch pane **only when you ask** (the `watch` arg or an
  in-conversation request), never by default. The local gate must be clean
  before any GitHub PR is opened.
- **Blind round 1, then one cross-critique round** — every live panelist reviews the
  same unfixed diff without seeing the others, then attacks their findings. Never
  auto-fixes a panelist's finding unless it was **reproduced**, or **survived** an adversary
  with high confidence and a concrete falsification condition. A finding that was attacked and
  not defended (`refuted-undefended`) faced an adversary and is still never auto-fixed.
- **The built-in forge reviewer needs no enrollment** — GitHub Copilot is requested for
  PR targets after the local gate, whenever `gh` is authenticated **and `jq` is present**,
  unless you opt out.
  Enrollment adds a *declared* reviewer for another forge. With none available, Phase B
  is skipped.
- **`/review-loop:init`** — optional; discovers which coding CLIs this host has and
  verifies how to call each one by actually calling it.
- **Never merges autonomously** — the author decides T2/T3 fixes and the final
  merge. Default to a merge commit to preserve history.
- **After convergence** — offers to group the review fixup commits; never
  auto-rebases, feature-branch only, never touches a primary branch.
