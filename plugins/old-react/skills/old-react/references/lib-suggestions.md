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

## RxJS

A genuine FRP-shaped library, used both standalone and via `redux-observable`. When you need cancellation, debouncing, racing, or switching, RxJS expresses each as one operator.

Operator names (`switchMap`, `mergeMap`, `debounceTime`, `combineLatest`, …) are RxJS-specific brand vocabulary; rule bodies in this skill do not name them. They belong here.

## Status modelling and state machines

When a plain tagged union is enough — three to five states, no legal-transition enforcement needed — no library is required; a plain TypeScript discriminated union with `useState` or a reducer covers the pattern from `model-status-as-tagged-union`. When the status graph grows (branching flows, parallel regions, history, delays), a dedicated state-machine library encodes guards and transitions as data instead of ad-hoc conditionals. Options include XState (rich FSM/statechart model, effect integration via actors), `robot` (small FSM with a functional API), and `zag` (UI-component-oriented machines). None is recommended over another; choose based on graph complexity and team familiarity.

## Notes for rule authors

- The rule body talks about *patterns*: reducer, action, dispatch, store, message, command, subscription, selector, state machine, observable as a concept.
- This file is where library brand names live. When a rule benefits from "if you use X, see this section", link here.
- Keep the rule body intelligible to a reader who has never used any of these libraries. The pattern names from `references/tea-as-backbone.md` are the canonical vocabulary.
