# old-react

Review and refactor pre-RSC React code with FP-thinking rules. Library-agnostic in the rule body; library suggestions live in `references/lib-suggestions.md`.

## What this is

A Claude Code skill that distills a lineage-aware view of React (2014–2023) into actionable architectural rules across five active categories: state architecture (`model-`), effects (`effect-`), composition (`compose-`), render purity (`purity-`), and hook applicability (`hooks-`). The full set is listed in `SKILL.md`.

Two categories remain deferred because existing tooling already enforces the highest-impact rules in them:

- `immutable-` — the `immutability` diagnostic (`eslint-plugin-react-hooks` v5+, `recommended-latest` preset).
- `message-` — TypeScript discriminated-union return types encode the type-level discipline.

The skill focuses on architectural rules where neither the type system nor existing linters provide equivalent coverage. Hook-correctness checks (`react-hooks/rules-of-hooks`, `react-hooks/exhaustive-deps`) and the React-Compiler-derived `purity` / `set-state-in-render` / `static-components` diagnostics remain deferred to those tools; the `hooks-` and `purity-` rules listed in `SKILL.md` cover orthogonal architectural concerns.

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

Five active categories (see `SKILL.md` for the canonical rule list):

| Prefix | Concern |
|--------|---------|
| `model-` | State architecture (SSOT, derive-don't-store, controlled-by-default, tagged-union status, narrow selectors) |
| `effect-` | Cmd/Sub-shaped effects |
| `compose-` | Composition (leaf purity, effects at page boundary, optional callbacks, consistent context access) |
| `purity-` | Render-phase purity (no effect in derivation) |
| `hooks-` | Hook applicability (class-fallback when hooks cannot express the lifecycle) |

Two categories remain deferred: `immutable-` and `message-` (each covered by existing lint or type-level checks; see above).

## Versioning

- v0.1.0 — initial release: 7 architectural rules (model 3, effect 2, compose 2), 5 reference docs + an advanced-patterns reference, slash command, validator. Four categories (`purity-`, `immutable-`, `message-`, `hooks-`) deferred at ship.
- v0.2.0 — current release: 14 rules across 5 active categories (model 6, compose 4, effect 2, purity 1, hooks 1). Two categories (`immutable-`, `message-`) remain deferred to existing tooling. References gained an advanced-patterns doc and a prior-art table in `lib-suggestions.md`; `fp-thinking.md` anchors immutability to Okasaki's persistent-data-structures result. The canonical rule set lives in `SKILL.md`.
- **No fixed roadmap.** A rule ships only when a real review surfaces a concrete failure not already caught by lint or types, with at least one Incorrect / Correct example pair. See spec §9 "Adding rules — real-example-driven" for the criteria.

## See also

- `references/fp-thinking.md`
- `references/tea-as-backbone.md`
- `references/hooks-as-slot-table.md`
- `references/lib-suggestions.md`
- `references/scoreboard.md`
- `references/advanced-patterns.md` — patterns and mental models worth knowing but not enforced as rules
- Spec: `docs/superpowers/specs/001-old-react-skill-design.md`
- Source reference: `docs/old-react.md`
