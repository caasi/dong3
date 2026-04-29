# old-react

Review and refactor pre-RSC React code with FP-thinking rules. Library-agnostic in the rule body; library suggestions live in `references/lib-suggestions.md`.

## What this is

A Claude Code skill that distills a lineage-aware view of React (2014–2023) into 6 actionable rules across three v0.1.0 categories: model architecture (Single Source of Truth, derive-don't-store, controlled-by-default), effects-as-data (effect-as-description, setup-cleanup-pair), and composition (leaf-purity).

Four categories are deferred to v0.2.0 because existing tooling already enforces the highest-impact rules in those categories:

- `purity-` — `react-hooks/purity` and `react-hooks/set-state-in-render` (eslint-plugin-react-hooks v6+, `recommended` preset).
- `immutable-` — `react-hooks/immutability` (same preset).
- `message-` — TypeScript discriminated-union return types encode the type-level discipline.
- `hooks-` — `react-hooks/rules-of-hooks`, `react-hooks/exhaustive-deps`.

v0.1.0 focuses on architectural rules where neither the type system nor existing linters provide equivalent coverage.

The shape is grounded in the Elm Architecture (TEA): `Model`, `Msg`, `update`, `view`, `Cmd`, `Sub`. The closer your React code sits to TEA shape, the more you get for free — Single Source of Truth, time-travel debugging, hot-reloadable logic. The lineage Bret Victor → Elm → Redux is documented in `references/tea-as-backbone.md`.

## Scope

**In scope:** Class components, hooks, Redux / MobX / observables, Reselect, Immer, redux-saga, redux-observable, RxJS, XState, TanStack Query, SWR.

**Out of scope:** React Server Components, the `use(promise)` hook, `'use client'` and `'use server'` boundaries. Files containing these are skipped per the skill's **Scope check**.

## How to use

In any conversation:

```text
review this React file with old-react
```

Or use the slash command:

```text
/old-react review src/Foo.tsx
/old-react refactor src/Foo.tsx
```

The skill emits grouped findings (review) or unified diffs (refactor), each citing a rule slug like `model-single-source-of-truth` so you can look up the principle.

## Categories

v0.1.0 ships these three:

| Prefix | Concern |
|--------|---------|
| `model-` | State architecture (SSOT, controlled-by-default) |
| `effect-` | Cmd/Sub-shaped effects |
| `compose-` | Composition (leaf purity) |

Four categories deferred to v0.2.0: `purity-`, `immutable-`, `message-`, `hooks-` (each covered by existing lint or type-level checks; see above).

## Versioning

- v0.1.0 — 6 architectural rules (model 3, effect 2, compose 1), 5 reference docs, slash command, validator. Four categories (`purity-`, `immutable-`, `message-`, `hooks-`) deferred; their highest-impact rules are already enforced by `eslint-plugin-react-hooks` v6+ (`react-hooks/recommended`).
- **v0.2.0 and beyond — open backlog, not a fixed roadmap.** The point of the skill is FP thinking in React UI development, not rule count. A rule ships only when (a) a recurring architectural failure surfaces in real review and (b) the failure is *not* already caught by an existing linter or by TypeScript. The total may stay under 10 rules forever. See spec §9 for the candidate backlog.

## See also

- `references/fp-thinking.md`
- `references/tea-as-backbone.md`
- `references/hooks-as-slot-table.md`
- `references/lib-suggestions.md`
- `references/scoreboard.md`
- Spec: `docs/superpowers/specs/001-old-react-skill-design.md`
- Source reference: `docs/old-react.md`
