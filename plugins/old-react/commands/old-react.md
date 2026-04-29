---
description: Review or refactor pre-RSC React code with FP-thinking rules
argument-hint: "[review|refactor] [path]"
---

# /old-react

Review or refactor pre-RSC React code using the `old-react` skill.

**Usage:**

- `/old-react` — review the current selection or open file (default mode is `review`).
- `/old-react review [path]` — review the file or directory at `[path]`.
- `/old-react refactor [path]` — apply minimal-diff refactors at `[path]`.

**Scope:**

This command applies only to pre-RSC React: classes, hooks, Redux/MobX/observable patterns, Reselect, Immer. It does not apply to React Server Components, `use(promise)`, `'use client'`, or `'use server'` boundaries; the skill skips those spans and reports them.

**Behavior:**

Invoke the `old-react` skill in the requested mode against the resolved path (default: current context). Follow the skill's output protocol — grouped findings for review, unified diffs for refactor, scope-skipped spans listed at the end.

If the user provides no mode, default to `review`. If no path is provided, use the current open file or selection.
