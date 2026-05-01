# Spec: `old-react` skill — FP-thinking review and refactor for pre-RSC React

> Status: Design draft (brainstorming output)
> Author: caasi
> Date: 2026-04-29

## 1. Purpose

A Claude Code skill that teaches **FP thinking in React UI development** — reviewing and refactoring pre-RSC React code (classes, hooks, Redux/MobX/observable, Reselect, Immer) through the lens of:

1. **Render purity** — `view = f(model)`, no side effects in render.
2. **Immutable updates** — never mutate state; structural sharing.
3. **The Elm Architecture (TEA) as backbone** — Single Source of Truth (SSOT), discrete labeled messages, effects as descriptions, controlled components as continuations. This is the substrate that makes time-travel debugging possible.

The skill ships *only* the rules that the type system and existing linters cannot already enforce. `eslint-plugin-react-hooks` v5+ already covers purity, immutability, set-state-in-render, static-components, rules-of-hooks, and exhaustive-deps via the `recommended-latest` preset (per `docs/old-react.md` §9); TypeScript discriminated unions cover the static shape of labeled transitions; `react/no-unstable-nested-components` covers nested-component instability. Where existing tooling speaks, the skill stays quiet. Where the gap is architectural — state ownership, effects-as-data, controlled-component shape, container/presenter splits — the skill names a principle and gives a concrete violation/fix pair.

The total rule count is open. The skill shipped 7 rules at v0.1.0; subsequent additions under the v0.1.x marketplace label have grown the set incrementally as new architectural failures surfaced in real review. The current canonical rule list lives in `SKILL.md`. The skill is judged by signal-to-noise, not by category coverage. See §9.

The skill is **library-agnostic** in the rule body — examples use raw React/JS only. A separate `references/lib-suggestions.md` maps user-chosen libraries (Redux Toolkit, MobX, TanStack Query, Reselect, Immer, XState, RxJS) to the FP principles they embody.

The skill explicitly excludes React Server Components, the `use(promise)` hook, and `'use client'` / `'use server'` boundaries. Those features represent a different practice and belong in a separate skill.

## 2. Background

Source material: `docs/old-react.md` — a 660-line lineage-first reference for React 2014–2023, ending in §9 (12 best-practice imperatives) and §10 (a "scoreboard" of how each ecosystem item degrades from its FP/FRP original) and a postscript "React is not Haskell" (§11).

The skill distills §9 + §10 into operational rules that an agent can apply during code review and refactor.

The historical chain that motivates the SSOT + time-travel framing:

1. **Feb 2012** — Bret Victor, *"Inventing on Principle"*. Live coding demos. Principle: *"creators need an immediate connection to what they're creating."* Time-scrubbing UI = the motivating image.
2. **Late 2013 → April 2014** — Laszlo Pandy and Evan Czaplicki, Elm time-travelling debugger. Public release and announcement April 2014 (`elm-lang.org/news/time-travel-made-easy`; Wadler's blog post May 2014). First production-grade implementation. Depends on **immutability + purity + TEA shape**.
3. **Mid-2015** — Dan Abramov, Redux. TEA ported to JS with weaker types. `(state, action) → state` is Elm's `update : Msg → Model → Model` minus `Cmd`. Time-travel via Redux DevTools.

The chain is causal, not coincidental. Each step preserves the substrate that makes time-travel possible: pure functions, immutable state, discrete labeled events. Drop any one and time-travel breaks.

The skill does not require users to adopt Redux or any specific store. It does require them to write code whose *shape* admits the same reasoning.

## 3. Non-goals

- **Not a Vercel-style perf skill.** No bundle, server, or rendering-perf rules. Vercel's `react-best-practices` covers that surface.
- **Not an RSC migration guide.** Scope is pre-RSC only.
- **Not a religious anti-mutation polemic.** MobX/TFRP is acknowledged as a coherent alternative trade-off (`references/scoreboard.md`); the skill flags the trade rather than condemning it.
- **Not a teaching tool for FP newcomers.** References give brief primers; deep teaching is out of scope. The skill assumes the agent (Claude) knows FP and applies it; the user picks libraries.

## 4. Plugin layout

```
plugins/old-react/
  .claude-plugin/
    plugin.json
  commands/
    old-react.md                  # /old-react slash command
  skills/
    old-react/
      SKILL.md
      README.md
      rules/
        _template.md              # rule file template (excluded from build)
        _sections.md              # category metadata (excluded)
        model-single-source-of-truth.md
        ...
        effect-emit-named-actions.md
        ...
        compose-leaf-purity.md
        compose-effects-at-page-boundary.md
        ...
      references/
        fp-thinking.md
        tea-as-backbone.md
        hooks-as-slot-table.md
        lib-suggestions.md
        scoreboard.md
        advanced-patterns.md
```

Dev-time tooling lives **outside** the plugin so it does not ship to skill users via the marketplace install:

```
tools/old-react/
  validate-rules.sh             # frontmatter + body structure linter (Bash)
  test-validator.sh             # fixture-based test runner
  fixtures/                     # bad-* and purity-* fixtures
```

## 5. Invocation surface

- **SKILL.md description-trigger.** User phrasing matches: e.g. "review my old React code", "audit hooks", "refactor this class component", "review this reducer".
- **One slash command: `/old-react [review|refactor] [path]`.** No mode arg defaults to `review`. No path arg means current selection / open file / repo-relevant context.

No auto-trigger. Skill activates only on explicit user intent.

## 6. SKILL.md shape

Frontmatter:

```yaml
---
name: old-react
description: |
  Review or refactor React code in pre-RSC projects using FP-thinking rules.
  Triggers on phrases like "review my React code", "refactor this class component",
  "audit hooks usage", or the slash command `/old-react`.
  Scope: classes, hooks, Redux/MobX/observable, Reselect, Immer.
  Out of scope: React Server Components, `use(promise)`, `'use client'`/`'use server'`.
license: MIT
---
```

Body sections, in order:

1. **When to apply** — pre-RSC scope. User-invoked.
2. **Core lens (FP thinking)** — three pillars: pure render, immutable state, effect separation. Half-page each. Cross-link to `references/fp-thinking.md` and `references/tea-as-backbone.md`.
3. **Mode: review** — read code, surface violations grouped by category, prioritized by impact tier, with rule-slug citations.
4. **Mode: refactor** — propose minimal-diff transformations; one rule per commit-sized change; show before/after.
5. **Rule index** — 7 categories table (prefix → category → impact range → rule count); list rule slugs grouped by category.
6. **Output protocol** — review = grouped findings, each citing `<rule-slug>` + impact + before/after; refactor = unified diff per rule applied, with rationale.
7. **Scope check (concrete heuristic)** — applied per file before review:
   - **File-level directives.** If line 1 of the file (after optional comments) is `'use client'` or `'use server'`, **skip the whole file** and report "out of scope: directive `'use <…>'` at line 1".
   - **Async function components.** If a top-level component declaration is `async function` or `export default async function`, **skip the function body** but still review same-file pure helper functions and pure components that don't reference its result.
   - **`use(promise)` / `use(context)` calls.** Skip the enclosing component body. Annotate the skipped span with line numbers in the review output.
   - **Server actions** (functions starting with `'use server'` directive on line 1 of the function body): skip the function. Surrounding pure utilities still in scope.
   - **Mixed file** (some functions in scope, some not): review only the in-scope functions; emit a "Skipped" section listing each out-of-scope span with file:line.
   - **Refactor mode** never modifies skipped spans, even when other rules might apply tangentially.

## 7. Rule taxonomy

7 categories. Prefixes are kebab-case, terminated by `-`.

| Prefix | TEA / mechanism element | Concern |
|--------|--------------------------|---------|
| `purity-` | `view : Model → Html Msg`, `update` pure | Render and update are pure functions. No `Date.now`, `Math.random`, `localStorage`, `setState`, ref reads in render. |
| `immutable-` | `Model` is immutable | Update mechanics: spread, structural sharing, Immer-shape. Never mutate in place. |
| `model-` | `Model` = single tree | State architecture: SSOT, push down, lift to LCA, derive don't store, normalize collections, no parallel state, server vs client state separation. |
| `message-` | `Msg` = labeled event | State transitions are discrete tagged values. Reducer-shape for correlated state. Replayable from log. Exhaustive handling. |
| `effect-` | `Cmd Msg` / `Sub Msg` | Effects are descriptions. Setup/cleanup pair. Honest dep arrays. Event vs effect distinction. Async state machines. No imperative subscriptions. |
| `hooks-` | React mechanism (slot table) | Top-level only. Exhaustive deps. Custom hook extraction. No defensive memo. Prefer reducer for correlated state. |
| `compose-` | structure | Function composition over HOC pyramids. Custom hooks, not render props. Leaf purity. No inline component definitions. Slot patterns. |

`immutable-` is distinct from `model-`: the former is *update mechanics*, the latter is *state architecture*. Both stand independent of TEA framing.

## 8. Rule file shape

Each rule file (one rule per file):

```markdown
---
title: <human-readable title>
slug: <prefix>-<kebab-slug>
category: purity | immutable | model | message | effect | hooks | compose
impact: CRITICAL | HIGH | MEDIUM | LOW
tags: [render, idempotence, ...]
---

## <title>

<1–3 sentence why-it-matters, FP-grounded>

**Incorrect** (<what's wrong>):
\`\`\`tsx
// bad
\`\`\`

**Correct** (<what's right>):
\`\`\`tsx
// good
\`\`\`

<optional 1–2 paragraph deeper context, may link to references/*.md>
```

**No library brand names in the rule body.** Library hooks (e.g. "if you use Redux Toolkit, see `references/lib-suggestions.md#redux`") go at the end of the rule file.

**Allowed vocabulary** (FP/TEA pattern terms, not library brand names):
`reducer`, `action`, `dispatch`, `store`, `message` / `Msg`, `command` / `Cmd`, `subscription` / `Sub`, `selector`, `state machine`, `observable` (as a concept), `tagged union`, `effect handler`.

**Disallowed in rule body** (move to `references/lib-suggestions.md`):
`Redux`, `Redux Toolkit`, `MobX`, `RxJS`, `TanStack Query`, `SWR`, `Reselect`, `Immer`, `XState`, `Cycle.js`, `Recoil`, `Jotai`, `Zustand`, `redux-saga`, `redux-observable`, `redux-thunk`.

**Tag vocabulary** (closed set; add new tags via spec amendment, not ad hoc):
`render`, `idempotence`, `update`, `state`, `mutation`, `derivation`, `events`, `effects`, `subscriptions`, `deps`, `composition`, `lifecycles`, `replay`, `ssot`, `purity`, `keys`, `refs`, `reducer`, `memoization`.

**Tag count:** each rule's `tags` list must contain **two to four** entries from the closed set above. Two enforces "name at least two cross-cutting concerns this rule touches"; four caps the visual noise. The validator (`tools/old-react/validate-rules.sh`) enforces both the closed set membership and the `2..4` count.

The constraint is brand-name only. Pattern terms from TEA / Elm / functional vocabulary are the *intended* language of rule bodies.

## 9. Rule scope

**The point of this skill is FP thinking in React UI development — TEA shape, pure render, immutable updates, effects-as-data, controlled components as continuations. Rules exist only where existing tooling does not already encode that lens. The total rule count is open: we add a rule when we find a recurring failure mode the type system and linters cannot catch, and we drop a rule the moment a linter ships an equivalent. Anything under ten rules is fine; under five is fine. The earlier "40 rules" target was a rough sketch of the design space, not a budget.**

What we will *not* do:
- Reach for a fixed rule count.
- Ship a rule because the category looks empty.
- Duplicate the `recommended-latest` preset (compiler-derived diagnostics: `purity`, `set-state-in-render`, `immutability`, `static-components`, etc.), `react/no-unstable-nested-components`, or anything TypeScript discriminated unions already enforce.

What we will do:
- Add a rule when a recurring architectural failure surfaces in real review and is not catchable by lint or types.
- Phrase rules as principles (with concrete violation/fix examples), not as procedural checks.
- Cite the linter or type-level mechanism that *does* cover any adjacent surface, so readers know the boundary.

### v0.1.0 — initial ship

7 architectural rules in three categories:

| Category | v0.1.0 slugs | Why it ships (linter/type-system gap) |
|----------|--------------|----------------------------------------|
| `model-` | `model-single-source-of-truth`, `model-derive-dont-store`, `model-controlled-by-default` | Architecture of state ownership. No linter reasons about whether two components mirror the same value, whether a derivation should be cached vs computed, or whether an input is controlled. |
| `effect-` | `effect-emit-named-actions`, `effect-setup-cleanup-pair` | Whether a thunk emits a named action vs. mutates the store directly is an architectural choice, not a lint check. Setup-cleanup pairing is enforceable conceptually but no linter catches "missing cleanup whose absence will leak". |
| `compose-` | `compose-leaf-purity`, `compose-effects-at-page-boundary` | Presentational/container split is an architectural call about *what* a component reads. The page-boundary rule captures the inverse — *where* effects live (Functional Core, Imperative Shell, modernised with hooks). Neither shape is a syntactic check. |

### v0.1.x — added since

Subsequent rule additions under the same marketplace label, each promoted from §v0.2.0+ backlog after surfacing in real review. The marketplace version bump is deferred until the in-flight set stabilises.

| Category | Slug | Origin |
|----------|------|--------|
| `compose-` | `compose-optional-callbacks` | optional-callback prop pattern (anti-no-op default). |
| `compose-` | `compose-consistent-context-access` | mixed HOC + hook access for the same context. |
| `purity-` | `purity-no-effect-in-derivation` | promoted from §v0.2.0 backlog (`pure-update-functions` family) once the gap surfaced concretely. |
| `model-` | `model-status-as-tagged-union` | promoted from §v0.2.0 backlog (`action-shape-tagged-union` applied to status states). |
| `model-` | `model-narrow-selector-shape` | new addition; selector-shape narrowing. |
| `hooks-` | `hooks-class-fallback-when-needed` | hook **applicability** (orthogonal to the deferred hook-correctness checks). |

The canonical, always-up-to-date list lives in `plugins/old-react/skills/old-react/SKILL.md`. Cross-check that file rather than this section if the two ever diverge.

### v0.2.0+ — open backlog

The list below is a working backlog of *candidate* rules. Each must justify itself against the FP-thinking lens and against existing tooling at the time of authoring. Many of these may turn out to be unnecessary in practice — if a rule does not fire in real reviews, it does not ship. The skill should stay small.

| Category | Candidate slugs (not commitments) |
|----------|------------------------------------|
| `purity-` | `no-ref-read-in-render`, `idempotent-derivations`, `pure-update-functions`, `deterministic-keys` |
| `immutable-` | `immer-shape-for-deep`, `stable-refs-via-memo`, `copy-on-write` |
| `model-` | `push-down-default`, `lift-to-lca`, `normalize-collections`, `no-parallel-state`, `server-vs-client-state` |
| `message-` | `transitions-as-events`, `reducer-for-correlated`, `action-shape-tagged-union`, `exhaustive-handling`, `replayable-from-log` |
| `effect-` | `deps-honest`, `separate-render-from-effect`, `event-vs-effect`, `async-state-machine`, `no-imperative-subscription` |
| `hooks-` | `custom-hook-extract`, `no-defensive-memo`, `prefer-reducer` |
| `compose-` | `function-over-hoc-pyramid`, `custom-hooks-not-render-props`, `slot-pattern-for-layout` |

### Already covered (will not ship as skill rules)

| Skill rule | Covered by |
|------------|------------|
| `purity-no-nondeterminism-in-render` | the `purity` diagnostic (eslint-plugin-react-hooks v5+, `recommended-latest` preset) |
| `purity-no-setstate-in-render` | the `set-state-in-render` diagnostic (same preset) |
| `immutable-spread-not-mutate` | the `immutability` diagnostic (same preset) |
| `immutable-no-array-index-mutation` | the `immutability` diagnostic (same preset) |
| `compose-no-inline-components` | the `static-components` diagnostic; `react/no-unstable-nested-components` (eslint-plugin-react, stable) |
| `hooks-top-level-only` | `react-hooks/rules-of-hooks` |
| `hooks-exhaustive-deps` | `react-hooks/exhaustive-deps` |
| Most of `message-` (static shape) | TypeScript discriminated unions on hook/function return types |

## 10. Reference docs

Five reference files. All hand-written.

| File | Content |
|------|---------|
| `fp-thinking.md` | Core lens: pure leaves, effects at edges, `view = f(state)`. Two pages. Opens with: *"React wants to be Elm. The closer you write code to TEA shape, the more you get for free."* |
| `tea-as-backbone.md` | Bret Victor → Elm → Redux chain (dated). Maps `Model`/`Msg`/`update`/`view`/`Cmd`/`Sub` to React idioms. Explains why all 7 categories trace back here. Includes external source links (see §13). |
| `hooks-as-slot-table.md` | Why Rules of Hooks exist. Slot-table mechanism. The React-specific layer that lives below FP-thinking. |
| `lib-suggestions.md` | Lib → FP principle map. Redux Toolkit, MobX, TanStack Query / SWR, Reselect, Immer, XState, RxJS. Each library scored on TEA fidelity + immutability discipline. |
| `scoreboard.md` | Condensed §10 from `docs/old-react.md`. Quick "what's this lib's degradation factor?" lookup. |

## 11. Slash command

`commands/old-react.md`:

```yaml
---
description: Review or refactor pre-RSC React code with FP-thinking rules
argument-hint: "[review|refactor] [path]"
---
```

Body delegates to the skill with the parsed mode (default `review`) and path (default current context).

## 12. Marketplace registration

Add to `.claude-plugin/marketplace.json`:

```json
{
  "name": "old-react",
  "source": "./plugins/old-react",
  "description": "FP-thinking review and refactor rules for pre-RSC React projects",
  "version": "0.1.0",
  "author": { "name": "caasi" }
}
```

Bump marketplace `metadata.version` (per the project memory rule on adding plugins).

## 13. Validation

Doc-only plugin, no TS build.

`tools/old-react/validate-rules.sh` (Bash, `set -euo pipefail`; lives at the repo root, **not** under `plugins/old-react/`, so the skill's marketplace install does not ship dev-time tooling to users):

- For each `rules/*.md` not starting with `_`:
  - Frontmatter present with required keys: `title`, `slug`, `category`, `impact`, `tags`.
  - `slug` matches `<category-prefix>-<kebab>` and matches the filename basename.
  - `category` ∈ allowed set; `impact` ∈ allowed set.
  - Body contains an `## <title>` section.
  - Body contains both `**Incorrect**` and `**Correct**` markers.
  - Body contains at least one fenced code block per Incorrect/Correct.
- Exit non-zero on first violation; print file + missing field.

Optional later: build a small `rules/_index.json` consumed by SKILL.md's rule-index section.

## 14. Versioning

- v0.1.0: skeleton plugin + 7 architectural rules (model 3, effect 2, compose 2) + 6 reference docs + slash command + validator (lives at repo-level `tools/old-react/`, not shipped to skill users). Four categories (`purity-`, `immutable-`, `message-`, `hooks-`) and one `compose-` rule defer to existing tooling — see §9.
- v0.1.x (post-ship): additional rules added as architectural failures surfaced in real review (see §9 "v0.1.x — added since"). Two categories (`immutable-`, `message-`) remain deferred. Marketplace version stays at `0.1.0` until the in-flight set stabilises; the canonical rule list lives in `SKILL.md`.
- next bump: ship together with whatever round of rule additions is currently in flight; pin a coherent rule set to a numbered release rather than bumping per-rule.
- v0.2.0+: open backlog. Add a rule only when a recurring architectural failure surfaces in real review and is not already enforced by lint or types. The total rule count is open. See §9 for the candidate list.
- v0.x.x: react to user feedback (which rules fire, false positives, missing patterns).

## 15. Out-of-scope follow-ups (not implemented in v0.1.0)

- A `new-react` companion skill for RSC, `use`, server actions, streaming.
- A test harness that runs each rule's "Incorrect" example through a small React fixture and asserts the rule fires (would require a build step).
- Auto-build of a flattened `AGENTS.md` like Vercel's compiled output.

## 16. Open questions

None blocking. Naming bikeshed: `model-` vs `state-shape-` could go either way; current pick (`model-`) makes the TEA backbone explicit at the prefix level.

## 17. References

- Bret Victor, *Inventing on Principle*, 2012. Transcript: <https://jamesclear.com/great-speeches/inventing-on-principle-by-bret-victor>. Video: <https://www.youtube.com/watch?v=EGqwXt90ZqA>.
- Laszlo Pandy and Evan Czaplicki, Elm time-travelling debugger. Wadler's Blog: <https://wadler.blogspot.com/2014/05/elms-time-travelling-debugger.html>. Elm news: <https://elm-lang.org/news/time-travel-made-easy>.
- Evan Czaplicki, "Elm: Concurrent FRP for Functional GUIs" (senior thesis, 2012); "Asynchronous Functional Reactive Programming for GUIs" (PLDI 2013).
- Dan Abramov, Andrew Clark, Redux. History: <https://redux.js.org/understanding/history-and-design/history-of-redux>. Reinventing Flux interview: <https://survivejs.com/blog/redux-interview/>. The Redux Journey (React Europe 2016): <https://www.youtube.com/watch?v=uvAXVMwHJXU>.
- `docs/old-react.md` (this repo), §1 lineage, §9 imperatives, §10 scoreboard, §11 postscript.
- Vercel, `react-best-practices` skill: <https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices> (rule-file shape and impact-tier conventions referenced for layout).
