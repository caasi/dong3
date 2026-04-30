---
name: old-react
description: |
  Use when reviewing or refactoring React code in pre-RSC projects (classes, hooks,
  Redux/MobX/observable, Reselect, Immer). Applies FP-thinking rules grounded in
  render purity, immutable updates, and the Elm Architecture (Model, Msg, update,
  view, Cmd, Sub).
  Triggers on phrases like "review my React code", "refactor this class component",
  "audit hooks usage", "review this reducer", or the slash command `/old-react`.
  Out of scope: React Server Components, the `use(promise)` hook, `'use client'`
  and `'use server'` boundaries.
license: MIT
---

# old-react

Review and refactor pre-RSC React code using FP-thinking rules.

## When to apply

This skill activates only when the user explicitly asks for review or refactor of pre-RSC React code, or invokes `/old-react`. Do not auto-apply during unrelated work.

The skill assumes the user is maintaining code written between roughly 2014 and 2023: classes, then hooks, with Redux, MobX, observables, RxJS, and Cycle.js orbiting around it. See the **Scope check** section for how it handles files that mix the two eras.

## Core lens (FP thinking)

Three pillars. Read `references/fp-thinking.md` for the full treatment.

1. **Pure render.** `view = f(model)`. No `Date.now`, `Math.random`, storage, `setState`, or ref reads during render.
2. **Immutable updates.** A new state is a new value. Reference equality is what selectors and reconcilers use to detect change.
3. **Effects at the edges.** Effects are descriptions interpreted by a runtime, not callbacks invoked from inside business logic.

The Elm Architecture (TEA) is the shape behind all three. See `references/tea-as-backbone.md`.

## Mode: review

Read the code. Surface violations grouped by category (`purity-`, `immutable-`, `model-`, `message-`, `effect-`, `hooks-`, `compose-`), prioritized within each group by impact (CRITICAL → HIGH → MEDIUM → LOW). For each finding emit:

```text
[<rule-slug>] (<impact>) <file>:<line>
  <one-sentence why>
  Before: <minimal snippet>
  After:  <minimal snippet>
```

Group ordering: report `purity-` and `immutable-` violations first; they undermine reasoning about everything else.

## Mode: refactor

Apply rules one at a time. Each refactor produces a minimal diff. If multiple rules apply to one site, fix the highest-impact one first and ask before continuing. Output unified diffs with rationale citing the rule slug.

Never modify code in a span flagged by **Scope check** as out of scope.

## Rule index

**The skill exists to teach FP thinking in React UI development, not to maximise rule count.** A rule ships only when a recurring architectural failure surfaces in real review and is not already caught by lint or types. The total may stay under 10 rules. Categories without v0.1.0 rules are not abandoned — they defer to existing tooling and add a rule only when a specific gap surfaces.

| Prefix | Concern | v0.1.0 rules |
|--------|---------|--------------|
| `purity-` | Pure render and update | *(deferred to v0.2.0; covered by the `purity` and `set-state-in-render` diagnostics)* |
| `immutable-` | Update mechanics | *(deferred to v0.2.0; covered by the `immutability` diagnostic)* |
| `model-` | State architecture (SSOT) | `model-single-source-of-truth`, `model-derive-dont-store`, `model-controlled-by-default` |
| `message-` | Discrete labeled events | *(deferred to v0.2.0; TypeScript discriminated unions cover the type-level discipline)* |
| `effect-` | Cmd/Sub-shaped effects | `effect-emit-named-actions`, `effect-setup-cleanup-pair` |
| `hooks-` | React mechanism | `hooks-class-fallback-when-needed` *(hook correctness — `react-hooks/rules-of-hooks`, `react-hooks/exhaustive-deps` — remains deferred; this rule governs hook **applicability**, not correctness)* |
| `compose-` | Composition | `compose-leaf-purity`, `compose-effects-at-page-boundary`, `compose-optional-callbacks` *(`no-inline-components` covered by the `static-components` diagnostic and stable `react/no-unstable-nested-components`)* |

Read individual rule files in `rules/<slug>.md` for the full why + Incorrect/Correct + deeper notes.

## Scope check

Apply the following heuristic to every file before review or refactor:

- **File-level directives.** If line 1 (after optional comments) is `'use client'` or `'use server'`, **skip the whole file** and report `out of scope: directive '<…>' at line 1`.
- **Async function components.** If a top-level component is `async function` or `export default async function`, **skip its body** but review same-file pure helpers and pure components that don't depend on its output.
- **`use(promise)` / `use(context)` calls.** Skip the enclosing component body. Annotate the skipped span with `<file>:<start-line>-<end-line>`.
- **Server actions.** Functions whose body begins with `'use server'` directive: skip the function. Surrounding pure utilities remain in scope.
- **Mixed file.** Review only in-scope functions. Emit a `Skipped` section listing each out-of-scope span.
- **Refactor mode** never modifies code inside a skipped span, even when other rules might tangentially apply.

## Vocabulary discipline

The rule bodies use FP/TEA pattern terms only: reducer, action, dispatch, store, message, command, subscription, selector, state machine, observable (as a concept), tagged union, effect handler. Library brand names — Redux, MobX, RxJS, TanStack, SWR, Reselect, Immer, XState — and RxJS operator names live in `references/lib-suggestions.md`.

When recommending a library to the user, link to that reference rather than inlining the suggestion in the finding.

## Output protocol

- **Review** = grouped findings, each citing `<rule-slug>` + impact + before/after.
- **Refactor** = unified diff per rule applied, with rationale citing the rule slug.
- For both modes, end with a one-paragraph summary: how many findings per category, top three most impactful, scope-skipped spans (if any).

## References

- `references/fp-thinking.md` — the lens.
- `references/tea-as-backbone.md` — Elm Architecture, lineage Bret Victor → Elm → Redux.
- `references/hooks-as-slot-table.md` — why Rules of Hooks exist.
- `references/lib-suggestions.md` — library brand names and trade-offs.
- `references/scoreboard.md` — how each ecosystem item degrades from its FP/FRP original.
- `references/advanced-patterns.md` — patterns / mental models worth knowing but not enforced (curried updates, nested actions, CPS as the unifying abstraction, time-space duality).
