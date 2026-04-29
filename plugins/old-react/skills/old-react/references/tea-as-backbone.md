# TEA as the backbone

The Elm Architecture (TEA) is the structural shape behind every category in this skill: `purity-`, `immutable-`, `model-`, `message-`, `effect-`, `hooks-`, `compose-`. Map each category to a TEA element and the rules become legible as one consistent design.

## TEA, in one paragraph

```
type Model     = ...
type Msg       = ...
update         : Msg -> Model -> (Model, Cmd Msg)
view           : Model -> Html Msg
subscriptions  : Model -> Sub Msg
```

`Model` is immutable state. `Msg` is a tagged union of events. `update` is pure: takes a message and the current state, returns the next state and a list of commands to execute. `view` is pure: takes the state and returns a description of the UI. `Cmd` and `Sub` are effect descriptions interpreted by the runtime.

Every TEA element is data. Pure functions never perform effects directly; the runtime does, on values it can inspect and replay.

## Mapping to React idioms

| TEA | React analogue | Rules covering it |
|-----|---------------|-------------------|
| `Model` immutable | one source of state per slice | `model-`, `immutable-` |
| `Msg` tagged union | reducer action types | `message-` |
| `update` pure | reducer / functional setState | `purity-`, `message-` |
| `view = Model -> Html Msg` | function component | `purity-`, `compose-` |
| `Cmd Msg` | effect described as data and dispatched | `effect-` |
| `Sub Msg` | declarative subscription via effect | `effect-` |
| (substrate) | hooks are the slot-table that approximates this | `hooks-` |

The first six rows are language-level concepts in Elm; in React they are conventions. The last row — hooks — is a React-specific mechanism. That is why `hooks-` rules look different in shape (procedural discipline) from the rest (architectural discipline).

## Lineage: Bret Victor → Elm → Redux

The chain is causal, not coincidental.

1. **February 2012** — Bret Victor, *Inventing on Principle*. Live coding demos. Principle: *"creators need an immediate connection to what they're creating."* The time-scrubbing UI is the motivating image. ([Transcript](https://jamesclear.com/great-speeches/inventing-on-principle-by-bret-victor); [video](https://www.youtube.com/watch?v=EGqwXt90ZqA).)
2. **Late 2013 → April 2014** — Laszlo Pandy and Evan Czaplicki, Elm time-travelling debugger. First production-grade implementation; depends on **immutability + purity + TEA shape**. ([Elm news, April 2014](https://elm-lang.org/news/time-travel-made-easy); [Wadler's blog, May 2014](https://wadler.blogspot.com/2014/05/elms-time-travelling-debugger.html).)
3. **Mid-2015** — Dan Abramov and Andrew Clark, Redux. TEA ported to JavaScript with weaker types. `(state, action) → state` is Elm's `update : Msg → Model → Model` minus `Cmd`. Time-travel via Redux DevTools. ([Redux history](https://redux.js.org/understanding/history-and-design/history-of-redux); [interview](https://survivejs.com/blog/redux-interview/); [The Redux Journey, React Europe 2016](https://www.youtube.com/watch?v=uvAXVMwHJXU).)

Each step preserves the substrate that makes time-travel possible: pure functions, immutable state, discrete labeled events. Drop any one and time-travel breaks.

## What "drifts away from TEA" looks like

- State stored in a `useState` *and* mirrored in a parent — no longer a single `Model`.
- A thunk that mutates a global, then dispatches — no longer a `Cmd Msg`.
- A reducer that calls `Math.random()` — no longer a pure `update`.
- A component that reads `localStorage` during render — no longer a pure `view`.
- A subscription set up in `componentDidMount` and never torn down — no longer a `Sub Msg`.

Each is the failure mode of a category in this skill.
