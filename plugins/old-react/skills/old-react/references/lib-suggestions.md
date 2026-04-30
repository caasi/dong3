# Library suggestions

The rules in this skill are library-agnostic by design. This reference maps common pre-RSC libraries to the FP principles they embody, so an agent or reader can translate a rule to a concrete tool.

The columns are: TEA fidelity (how closely the library expresses `Model`, `Msg`, `update`, `Cmd`/`Sub`), and immutability discipline (how it handles updates).

## Stores and reducers

| Library | TEA fidelity | Immutability | Notes |
|---------|--------------|--------------|-------|
| **Redux Toolkit** | High (Model + Msg + update; `Cmd` is bolted on as middleware) | High (Immer underneath `createSlice`) | Closest mainstream port of TEA to JS. Time-travel via Redux DevTools. |
| **MobX** | Low (Model + setters + computed; no `Msg`) | Low (mutable observables) | Coherent alternative — TFRP. Trades replay for ergonomics. |
| **Zustand / Jotai** | Medium (small store + setters; reducer optional) | Depends on the user. | Lower ceremony than Redux; FP discipline is on you. |
| **Recoil** | Medium (atoms + selectors) | Medium. | Atom-based, derived selectors are pure. |

## Effect handling

| Library | Effect-as-data | Notes |
|---------|----------------|-------|
| **redux-saga** | Yes (yielded effect descriptions) | Closest mainstream userland approximation of algebraic effect handlers. |
| **redux-observable** | Sort of (Observables) | Genuine compositionality of streams. Steep RxJS learning curve. |
| **redux-thunk** | No (opaque function) | Escape hatch *out* of the eDSL. Avoid for non-trivial flows. |
| **XState** | Yes (state machine = data) | Excellent for correlated state where a discriminated union return type is no longer enough to encode legal transitions. |

## Server state

| Library | Notes |
|---------|-------|
| **TanStack Query** | Server cache, request dedup, focus revalidation, retries. The right answer for server state in 2026. |
| **SWR** | Lighter alternative to TanStack Query; same shape. |
| **Apollo / urql** | GraphQL-specific; same family. |

If you keep server state in Redux, you will rebuild a worse version of TanStack Query.

## Selectors and immutability helpers

| Library | Role |
|---------|------|
| **Reselect** | Memoized selectors. Reference-equality cache; defeated by selectors that return fresh objects every call. |
| **Immer** | Copy-on-write with mutation-shaped syntax. The right answer for 95% of "I want immutability without ceremony" cases. |
| **Immutable.js** | Persistent data structures (Map/List/Set/OrderedMap/Record). Strong theory, parallel API breaks JS interop. |

## Stable derivation identity — prior art

Prior art for the `model-stable-derivation-identity` rule. All are library-specific treatments of the same principle: a derivation must return a stable reference when its inputs have not changed.

| Source | What it covers |
|--------|---------------|
| [Reselect FAQ — factory functions for per-instance memoization](https://reselect.js.org/faq/) | Explains why a parametrised selector factory must be memoized per instance, not recreated per call. |
| [Redux — Deriving Data with Selectors](https://redux.js.org/usage/deriving-data-selectors) | Canonical Redux guidance on selector composition, memoization, and the failure mode of fresh-object selectors. |
| [Redux Toolkit — createSelector](https://redux-toolkit.js.org/api/createSelector) | API docs for the built-in memoized selector factory; covers the `inputSelectors` / `resultFunc` split that stabilises identity. |
| [LogRocket — re-reselect: Better Memoization and Cache Management](https://blog.logrocket.com/react-re-reselect-better-memoization-cache-management/) | Describes a per-key selector cache that maps each argument to one stable selector — Pattern B in the rule. |
| [Mat Brown — useCallback to preserve identity of partially-applied callbacks in collections](https://medium.com/@0utoftime/using-reacts-usecallback-hook-to-preserve-identity-of-partially-applied-callbacks-in-collections-3dbac35371ea) | Demonstrates Pattern A and Pattern C for curried callbacks in list renders. |
| [Dev.to — You should not use lodash for memoization](https://dev.to/nioufe/you-should-not-use-lodash-for-memoization-3441) | Explains why a single-arg-keyed unbounded cache is the wrong shape for parameterized selectors; use `Map` or a bounded LRU instead. |

## RxJS

A genuine FRP-shaped library, used both standalone and via `redux-observable`. When you need cancellation, debouncing, racing, or switching, RxJS expresses each as one operator.

Operator names (`switchMap`, `mergeMap`, `debounceTime`, `combineLatest`, …) are RxJS-specific brand vocabulary; rule bodies in this skill do not name them. They belong here.

## Status modelling and state machines

When a plain tagged union is enough — three to five states, no legal-transition enforcement needed — no library is required; a plain TypeScript discriminated union with `useState` or a reducer covers the pattern from `model-status-as-tagged-union`. When the status graph grows (branching flows, parallel regions, history, delays), a dedicated state-machine library encodes guards and transitions as data instead of ad-hoc conditionals. Options include XState (rich FSM/statechart model, effect integration via actors), `robot` (small FSM with a functional API), and `zag` (UI-component-oriented machines). None is recommended over another; choose based on graph complexity and team familiarity.

## Notes for rule authors

- The rule body talks about *patterns*: reducer, action, dispatch, store, message, command, subscription, selector, state machine, observable as a concept.
- This file is where library brand names live. When a rule benefits from "if you use X, see this section", link here.
- Keep the rule body intelligible to a reader who has never used any of these libraries. The pattern names from `references/tea-as-backbone.md` are the canonical vocabulary.
