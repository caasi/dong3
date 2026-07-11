---
description: Run the assisted review loop — local reviewers answer blind and in parallel (enrolled roster; heterogeneity is a bonus, not a gate), then a forge reviewer (Copilot) for PRs; never merges autonomously
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

- **Local gate first** — a Claude subagent always reviews; Codex (headless,
  via `codex exec`) joins when it is enrolled, or, with no config, whenever
  `codex` is on `PATH` (the native `review` subcommand on a working sandbox,
  the embedded-diff `codex exec … -` form when the sandbox is `broken`). tmux
  is optional and opens a live-watch pane **only when you ask** (the `watch`
  arg or an in-conversation request), never by default. The local gate must be
  clean before any GitHub PR is opened.
- **Blind and parallel** — every live reviewer reviews the same unfixed diff, none sees another's
  findings, and fixes land after all have reported. Cross-critique is recommended and gates nothing.
- **Heterogeneity is a bonus, not a gate** — the loop never requires a cross-family reviewer; the
  verdict names which ones actually ran.
- **The built-in forge reviewer needs no enrollment** — GitHub Copilot is requested for PR targets
  after the local gate, whenever `gh` is authenticated and `jq` is present, unless you opt out.
- **`/review-loop:init`** — optional; discovers which coding CLIs this host has and verifies how to
  call each one by actually calling it.
- **Never merges autonomously** — the author decides T2/T3 fixes and the final
  merge. Default to a merge commit to preserve history.
- **After convergence** — offers to group the review fixup commits; never
  auto-rebases, feature-branch only, never touches a primary branch.
