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
- append `watch` (e.g. `/review-loop watch`, `/review-loop 46 watch`) — open a live spectator pane for the Codex review; **requires a tmux session**. A lone `watch` token is the watch request against the default target, not a branch named `watch`.

**Target:**

The change under review may be code or design artifacts (specs, plans, docs). For
document targets the loop reviews clarity, consistency, structure, and factual
accuracy; TDD / one-commit-per-item discipline applies only to executable changes.

**Behavior:**

Invoke the `review-loop` skill. Load-bearing invariants the skill enforces:

- **Local gate first** — a Claude subagent always reviews; Codex (headless
  `codex exec review`) joins when `codex` is on `PATH`; tmux is optional and
  opens a live-watch pane **only when you ask** (the `watch` arg or an
  in-conversation request), never by default. The local gate must be clean
  before any GitHub PR is opened.
- **Copilot is GitHub-only** — requested only for PR targets, after the local gate.
- **Never merges autonomously** — the author decides T2/T3 fixes and the final
  merge. Default to a merge commit to preserve history.
