# Scoreboard

How each ecosystem item compares to the FP/FRP idea it descends from. Adapted and condensed from `docs/old-react.md` §10. "Degradation" is judged on type-system reflection, compositionality, and operational rigor.

| Ecosystem item | Original idea | Degradation |
|---------------|----------------|-------------|
| React component (`view = f(props, state)`) | Pure ML/Haskell function returning ADT | Mild. Purity is documented and lint-checked, not type-checked. |
| Redux (`reducer + store`) | Elm Architecture (TEA) | Moderate. No `Cmd`/`Sub` discipline; effects are bolted on as middleware. |
| redux-thunk | (none — escape hatch) | Severe. Effects are opaque function bodies. No replay, no introspection. |
| redux-saga | Algebraic effect handlers via coroutines | Moderate. Effects ARE data, handlers compose, but no effect rows in the type system. |
| redux-observable | FRP / Cycle.js with Rx | Mild. Genuine compositionality of streams. RxJS learning curve is the cost. |
| MobX | Transparent FRP | Mild on theory; not first-class in React's mental model. Trades replay for ergonomics. |
| Reselect | Memoization / Om's `=` on persistent data | Mild. Easy to defeat by returning fresh objects. |
| Immer | Copy-on-write with structural sharing | Mild. Pragmatic; not algorithmically optimal but ergonomically excellent. |
| Hooks | Algebraic effects | Severe. Slot-table approximation. Rules enforced by linter, not types. |
| Suspense ("throw a promise") | One-shot delimited continuation | Severe. No real continuation; replay-from-scratch on idempotence assumption. |

## How to use this table

It is not a ranking; it is a translation guide. When the rule body says "model state transitions as discrete labeled events", this table tells you which library expresses that idea cleanly (Redux, redux-saga, XState) and which does not (redux-thunk).

For a longer treatment of any row, see `docs/old-react.md` §3–§10.
