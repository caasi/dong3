# Spec: `old-react` skill — FP-thinking review and refactor for pre-RSC React

> Status: Design draft (brainstorming output)
> Author: caasi
> Date: 2026-04-29

## 1. Purpose

A Claude Code skill that reviews and refactors React code in pre-RSC projects (classes, hooks, Redux/MobX/observable, Reselect, Immer) using **FP-thinking rules** grounded in:

1. **Render purity** — `view = f(model)`, no side effects in render.
2. **Immutable updates** — never mutate state; structural sharing.
3. **The Elm Architecture (TEA) as backbone** — Single Source of Truth (SSOT), discrete labeled messages, effects as descriptions. This is the substrate that makes time-travel debugging possible.

The skill is **library-agnostic** in the rule body — examples use raw React/JS only. A separate `references/lib-suggestions.md` maps user-chosen libraries (Redux Toolkit, MobX, TanStack Query, Reselect, Immer, XState, RxJS) to the FP principles they embody.

The skill explicitly excludes React Server Components, the `use(promise)` hook, and `'use client'` / `'use server'` boundaries. Those features represent a different practice and belong in a separate skill.

## 2. Background

Source material: `docs/old-react.md` — a 660-line lineage-first reference for React 2014–2023, ending in §9 (12 best-practice imperatives) and §10 (a "scoreboard" of how each ecosystem item degrades from its FP/FRP original) and a postscript "React is not Haskell" (§11).

The skill distills §9 + §10 into operational rules that an agent can apply during code review and refactor.

The historical chain that motivates the SSOT + time-travel framing:

1. **Feb 2012** — Bret Victor, *"Inventing on Principle"*. Live coding demos. Principle: *"creators need an immediate connection to what they're creating."* Time-scrubbing UI = the motivating image.
2. **2013** — Laszlo Pandy, Elm time-travelling debugger (Elm Workshop 2013). First production-grade implementation. Depends on **immutability + purity + TEA shape**.
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
        purity-no-nondeterminism-in-render.md
        purity-no-setstate-in-render.md
        ...
        immutable-spread-not-mutate.md
        ...
        model-single-source-of-truth.md
        ...
        message-transitions-as-events.md
        ...
        effect-as-description-not-thunk.md
        ...
        hooks-top-level-only.md
        ...
        compose-no-inline-components.md
        ...
      references/
        fp-thinking.md
        tea-as-backbone.md
        hooks-as-slot-table.md
        lib-suggestions.md
        scoreboard.md
      scripts/
        validate-rules.sh         # shell-only frontmatter + section linter
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
7. **Scope check** — if file contains `use(promise)`, `'use client'`, `'use server'`, or `async` server components, the skill states the limit and reviews only the parts in scope.

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

**No library names in the rule body.** Examples are raw React/JS only. Library hooks (e.g. "if you use Redux Toolkit, see `references/lib-suggestions.md#redux`") go at the end.

## 9. Rule budget

40 rules total, distributed:

| Category | Count | Examples |
|----------|-------|----------|
| `purity-` | 6 | `no-nondeterminism-in-render`, `no-setstate-in-render`, `no-ref-read-in-render`, `idempotent-derivations`, `pure-update-functions`, `deterministic-keys` |
| `immutable-` | 5 | `spread-not-mutate`, `no-array-index-mutation`, `immer-shape-for-deep`, `stable-refs-via-memo`, `copy-on-write` |
| `model-` | 7 | `single-source-of-truth`, `push-down-default`, `lift-to-lca`, `derive-dont-store`, `normalize-collections`, `no-parallel-state`, `server-vs-client-state` |
| `message-` | 5 | `transitions-as-events`, `reducer-for-correlated`, `action-shape-tagged-union`, `exhaustive-handling`, `replayable-from-log` |
| `effect-` | 7 | `as-description-not-thunk`, `setup-cleanup-pair`, `deps-honest`, `separate-render-from-effect`, `event-vs-effect`, `async-state-machine`, `no-imperative-subscription` |
| `hooks-` | 5 | `top-level-only`, `exhaustive-deps`, `custom-hook-extract`, `no-defensive-memo`, `prefer-reducer` |
| `compose-` | 5 | `function-over-hoc-pyramid`, `no-inline-components`, `leaf-purity`, `custom-hooks-not-render-props`, `slot-pattern-for-layout` |

**v0.1.0 release:** ships ~14 rules (2 per category, highest-impact pick).
**v0.2.0:** fills remaining ~26.

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

`scripts/validate-rules.sh` (POSIX shell, `set -euo pipefail`):

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

- v0.1.0: skeleton plugin + 14 rules (2 per category) + 5 reference docs + slash command + validator.
- v0.2.0: fill remaining 26 rules.
- v0.3.0+: react to user feedback (which rules fire, false positives, missing patterns).

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
