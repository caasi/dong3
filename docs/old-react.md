# React.js (pre–Server Components) — A Reference, with a Postscript on Why React Is Not Haskell

> *An opinionated, lineage-first reference for engineers who want to understand React the way the people who designed it actually thought about it: as the latest in a long line of FRP/FP-derived UI ideas, mostly preserved poorly.*
>
> **Scope.** This document is about the React you actually write between roughly 2014 and 2023: classes, then hooks, with Redux, MobX, observables, RxJS, and Cycle.js orbiting around it. It deliberately excludes React Server Components and the `use` hook from the *practice* sections — these are different enough that the patterns below stop being load-bearing. They reappear, however, as a *critical lens* in the new postscript: **"React is not Haskell"**, where the FP analogy that always animated React finally collapses under its own weight.
>
> **Editorial stance.** Most of the React/JS-ecosystem libraries discussed below are degraded copies of FP/FRP concepts that already had cleaner formulations in ML, Haskell, Elm, OCaml, and ClojureScript. They are still worth understanding — they are what you will actually maintain — but the reader should not mistake them for the originals. Where the original is materially better (it usually is), that is said plainly.

---

## 1. Lineage: where React's ideas actually came from

React did not appear from nowhere. Almost every interesting idea in React was either lifted from, or a watered-down version of, work that predated it by years or decades.

### 1.1 ML and the StandardML/OCaml family

React's internal language, before TypeScript got good, was Hack at Facebook and ML in spirit. Jordan Walke's original prototype was written in StandardML and compiled to JS. The component-as-function-of-props mental model — `view = f(state)` — is the natural shape of an ML pattern-match returning a tagged union. Sebastian Markbåge's "React Basic" (`reactjs/react-basic`) explicitly says "the core premise for React is that UIs are simply a projection of data into a different form of data. The same input gives the same output. A simple pure function." This is ML thinking dressed in JS clothes.

OCaml's later addition of one-shot effect handlers in OCaml 5 (2022) is part of the same intellectual line; we will return to it because it is the language feature React's authors wanted in JavaScript and never got. The relevant primary sources are KC Sivaramakrishnan et al.'s "Retrofitting Effect Handlers onto OCaml" (arXiv:2104.00250) and Ningning Xie & Daan Leijen's "Generalized Evidence Passing for Effect Handlers" (ICFP 2021).

### 1.2 Conal Elliott, FRP, and Functional Reactive Animation (1997)

Modern reactive UI starts with Conal Elliott and Paul Hudak, "Functional Reactive Animation" (ICFP '97). The two key abstractions are:

- **`Behavior a`** — a value of type `a` that varies continuously over time. `Behavior Picture` is an animation; `Behavior Float` is a moving number.
- **`Event a`** — a discrete-time stream of values of type `a`.

Programs are *compositional*: behaviors and events are first-class values combined by ordinary functions (`map`, `filter`, `time`, `integral`, `untilB`). Time is *continuous and denotational*, not a tick rate, not a frame number. This is what FRP originally meant.

Almost everything else called "FRP" — RxJS, Bacon.js, MobX, the typical "Observable" library — is what Conal himself dryly calls "FRP-ish": discrete-only, glitchy, with leaky operational semantics. André Staltz, the author of Cycle.js, eventually wrote "Why I cannot say FRP but I just did" (2015) acknowledging exactly this distinction.

### 1.3 Elm: FRP made shippable, then walked back

Evan Czaplicki's senior thesis "Elm: Concurrent FRP for Functional GUIs" (2012) and the follow-up PLDI'13 paper "Asynchronous Functional Reactive Programming for GUIs" took Conal/Hudak FRP and made two pragmatic compromises: time becomes discrete, and signal graphs are statically constructed. Elm originally exposed `Signal a`. By Elm 0.17 (May 2016) Czaplicki had removed signals from the public API entirely, replacing them with **The Elm Architecture (TEA)**:

```
model    : Model
update   : Msg -> Model -> (Model, Cmd Msg)
view     : Model -> Html Msg
subscriptions : Model -> Sub Msg
```

This is the direct ancestor of Redux. Dan Abramov has been explicit about this. Redux is, at heart, TEA with weaker types and dynamic dispatch. Elm's `Cmd`/`Sub` model — effects as data values returned from `update`, *interpreted* by the runtime — is also the intellectual ancestor of redux-saga effects, redux-observable epics, and what algebraic-effect handlers do natively.

### 1.4 Om and ClojureScript: the immutable-data insight

David Nolen's Om (December 2013) was the demonstration that *React + persistent immutable data structures + reference equality in `shouldComponentUpdate`* dominates React-with-mutable-state in both performance and predictability. Om's key trick: application state lives in a single Clojure atom; components receive a **cursor** into it; reference equality on persistent data is `O(1)` and tells you exactly whether to re-render.

Almost every "good" pattern in the JS-React ecosystem since — Redux's single store, Reselect's structural-sharing memoization, Immer's structural-sharing patches, the entire React-Redux v7+ `useSelector` story — is Om-shaped. None of them are as clean as Om. ClojureScript got this right in 2013; the JS ecosystem is still catching up.

### 1.5 The summary that matters

> **React is, charitably, an FP/FRP-flavored UI library implemented in a language that does not have the substrate for FP/FRP.** Every "innovation" in the React ecosystem after 2013 is in some sense a workaround for that substrate problem. Hooks, Suspense, the React Compiler, and `use` are increasingly desperate workarounds. The lineage is honest; the implementation is not.

---

## 2. Pre-hooks idioms (what you will still find in real codebases)

If you are reading this you almost certainly maintain code written between 2015 and 2019 that uses these patterns. They are not "wrong" — they were the right way at the time. They are now legacy.

### 2.1 Class components

```js
class TodoList extends React.Component {
  constructor(props) {
    super(props);
    this.state = { todos: [], filter: "all" };
    this.handleAdd = this.handleAdd.bind(this);
  }
  componentDidMount()   { this.subscribe(); }
  componentDidUpdate(prev) { if (prev.userId !== this.props.userId) this.refetch(); }
  componentWillUnmount(){ this.unsubscribe(); }
  shouldComponentUpdate(nextProps, nextState) { /* manual diffing */ }
  render() { /* ... */ }
}
```

Lifecycle methods are *temporally* organized — "what to do at mount, update, unmount" — but real concerns are *cross-temporal*: a subscription has a setup *and* a teardown *and* a re-setup-when-deps-change. Class components forced you to scatter one logical concern across three lifecycle methods. Hooks, whatever else can be said about them, fix this specific cross-cutting problem with `useEffect`'s setup/cleanup pair.

### 2.2 Higher-Order Components (HOCs)

A HOC is a function `Component → Component`. The canonical examples are `connect` (react-redux pre-hooks), `withRouter`, `withTheme`. They are point-free composition of components, the way ML libraries compose functions:

```js
const enhance = compose(
  connect(mapStateToProps),
  withRouter,
  withTheme
);
export default enhance(MyComponent);
```

HOCs collapsed into "wrapper hell" in DevTools, broke ref forwarding, and required ceremony to preserve `displayName` and static methods. Andrew Clark's `recompose` library (2016) was the most honest attempt to make HOCs into a real combinator library — `withState`, `withHandlers`, `lifecycle`, `mapPropsStream` (the last is a *first-class stream-of-props* combinator, basically a Cycle.js component-of-one). Clark himself archived recompose in October 2018 with the note: *"Hooks solves all the problems I attempted to address with Recompose three years ago, and more on top of that. I will be discontinuing active maintenance of this package … and recommending that people use Hooks instead."* That sentence is the obituary for the HOC era.

### 2.3 Render props

When HOC composition got too painful, the community swung to render props:

```jsx
<Mouse>
  {({ x, y }) => <Cursor x={x} y={y} />}
</Mouse>
```

Render props are higher-order *components-as-functions*, which is just CPS-style component composition. They compose worse than HOCs in nesting (the "pyramid of doom") but better in TypeScript inference. Both HOCs and render props were attempts to express what monads/applicatives express in Haskell or what `withState`/`mapPropsStream` express in recompose: stateful, effectful logic decoupled from the component that uses it.

### 2.4 Container/Presenter (presentational vs container components)

Dan Abramov's 2015 article (he later partially recanted): split components into "presentational" (pure render of props, no state, no data fetching, easy to test/storybook) and "container" (knows about Redux, fetching, routing). This works well as a discipline, but Hooks made the split less mechanical and more situational. The good half of this idea — *purity of leaf components* — survives in the Rules of React's "Components must be idempotent" requirement. The bad half — *every form must be wrapped in two components* — is dead and good riddance.

---

## 3. Flux / Redux as a small embedded DSL

Flux (Facebook, 2014) said: state changes flow in one direction; views dispatch *actions*; *stores* react to actions. Redux (Dan Abramov, Andrew Clark, 2015) compressed Flux to a single function:

```
(state, action) -> state
```

That's it. This is — and this matters — a transcription of Elm's `update : Msg -> Model -> (Model, Cmd Msg)` minus the `Cmd`. The `Cmd` is what came back, painfully, as middleware.

### 3.1 The eDSL framing

Treating Redux as a small embedded DSL clarifies almost everything:

- **Actions** are abstract syntax tree nodes (`{ type, payload }` is a tagged union value).
- **Reducers** are interpreters: `Action × State → State`.
- **The store** is the AST evaluator + state heap.
- **Middleware** is a *reinterpretation* layer: it transforms the meaning of an action *before* the reducer sees it. This is exactly the role of an effect handler in algebraic-effects parlance, and exactly the role of `Cmd` interpreters in Elm.

Once you see this, everything from `redux-thunk` to `redux-saga` to `redux-observable` is the same idea differently encoded.

### 3.2 redux-thunk: the cheapest possible cheat

```js
const fetchUser = (id) => (dispatch, getState) => {
  dispatch({ type: 'USER_FETCH_START', id });
  api.fetchUser(id).then(
    (u) => dispatch({ type: 'USER_FETCH_OK', user: u }),
    (e) => dispatch({ type: 'USER_FETCH_FAIL', error: e })
  );
};
```

A thunk is "an action that is actually a function, and the middleware runs the function for you". This is not an eDSL — it's an escape hatch *out* of the DSL into raw imperative JS. It is fine for small apps and a disaster for large ones because the action log no longer describes the program: half the program is in opaque function bodies that the time-travel debugger and replay tools cannot inspect.

### 3.3 redux-saga: generators as algebraic effects, badly

`redux-saga` (Yassine Elouafi, late 2015 — see issue `reduxjs/redux#1139`) is the most theoretically interesting middleware in the ecosystem. Sagas are generator functions that `yield` *effect descriptions* — plain JS objects — which the saga middleware interprets:

```js
function* fetchUser(action) {
  try {
    const user = yield call(api.fetchUser, action.id);    // effect: call
    yield put({ type: 'USER_FETCH_OK', user });           // effect: dispatch
  } catch (e) {
    yield put({ type: 'USER_FETCH_FAIL', error: e });
  }
}

function* root() {
  yield takeEvery('USER_FETCH', fetchUser);               // effect: subscribe
}
```

The crucial trick: `call(api.fetchUser, id)` does **not** call the API. It returns a *description* `{ type: 'CALL', fn, args }`. The middleware decides what to do with the description. This makes sagas synchronously testable — you can `iterator.next()` and assert on the yielded effect object — and lets you trivially mock side effects for tests.

This is *exactly* the algebraic-effects pattern: a computation `perform`s an effect (via `yield`); a handler (the saga middleware) interprets it; the continuation is the generator's next step. Elouafi later wrote an excellent four-part series, "Algebraic Effects in JavaScript", showing how generators implement one-shot delimited continuations and noting that "if you ever worked with libraries like redux-saga it's the same idea".

The honest assessment: redux-saga is a userland effect-handler system shoved through ES6 generators. It works because generators give you one-shot delimited continuations within one stack frame. It is awkward at scale because the ergonomics of yielding effect objects are bad relative to a real handler-based language (Eff, Koka, OCaml 5), and because there is no type-system reflection of what effects a saga performs. You are doing algebraic effects with no effect rows.

### 3.4 redux-observable: the same idea in RxJS

Netflix's `redux-observable` (2016) is sagas without generators: an *epic* is a function `Observable<Action> → Observable<Action>` running over the action stream:

```js
const fetchUserEpic = (action$) =>
  action$.pipe(
    ofType('USER_FETCH'),
    mergeMap((a) => from(api.fetchUser(a.id)).pipe(
      map((u) => ({ type: 'USER_FETCH_OK', user: u })),
      catchError((e) => of({ type: 'USER_FETCH_FAIL', error: e }))
    ))
  );
```

This is the most directly Cycle.js-shaped thing in the Redux ecosystem. The price is that you must internalize RxJS's enormous operator vocabulary. The reward is genuine compositionality of asynchronous flows: cancellation, debouncing, racing, throttling, switching are one operator each.

### 3.5 Comparing the three middlewares

| Property                     | redux-thunk          | redux-saga                    | redux-observable             |
|------------------------------|----------------------|-------------------------------|-----------------------------|
| Effects are data?            | No (opaque function) | **Yes** (yielded objects)     | Sort of (Observable values) |
| Testable without mocks?      | No                   | **Yes**                       | Yes (marble tests)          |
| Cancellation                 | DIY                  | Built-in (`cancel`/`race`)    | Built-in (operator)         |
| Conceptual ancestor          | None — escape hatch  | Algebraic effects / coroutines | FRP / Rx / Cycle.js        |
| Type-system effect tracking  | None                 | None                          | None                        |

If you are starting a *new* Redux codebase in 2026, you should not be. Use Redux Toolkit (which bundles RTK Query) or TanStack Query plus Zustand or Jotai. But if you maintain a 2017-era codebase, prefer saga/observable to thunk: the effect-as-data discipline is what you want, even imperfectly encoded.

---

## 4. MobX: TFRP, signals, and what spreadsheets always knew

Michel Weststrate's MobX (originally `mobservable`, 2015) explicitly markets itself as **Transparent Functional Reactive Programming**. The TFRP idea is older than MobX — it traces back to Knockout, Meteor's Tracker, Vue's reactivity system, and ultimately to spreadsheets. The "T" matters: graph edges between observables and observers are inferred *automatically* by recording reads inside `autorun`/observer scopes.

```js
import { makeAutoObservable, autorun } from "mobx";

class Cart {
  items = [];
  get total() { return this.items.reduce((s, i) => s + i.price, 0); }
  add(i) { this.items.push(i); }
  constructor() { makeAutoObservable(this); }
}

const c = new Cart();
autorun(() => console.log("total:", c.total));   // re-runs whenever items change
c.add({ price: 10 });                              // logs: total: 10
```

Important properties:
- **Signal-graph reactivity, not virtual-DOM diffing.** When `c.items` changes, MobX precisely re-runs only the observers that read `total`. No tree diffing.
- **Glitch-free synchronous propagation.** Topological ordering of reactions; no inconsistent intermediate states.
- **Mutable state is fine.** This is the opposite philosophy to Redux/Om. MobX assumes you mutate in place; reactivity tracks reads/writes for you.

The 2026 vocabulary for "signal-based reactivity" — Solid, Vue 3 Composition API, Svelte 5 runes, Angular signals, Preact signals, the TC39 Signals proposal — is essentially the rediscovery of TFRP. MobX got there in 2015 and has shipped TFRP for a decade. It is, by some distance, the most intellectually coherent piece of state management in the React ecosystem, and it is consistently underrated because it does not fit the "everything is a pure function" mythology that React markets.

The honest comparison with Redux:

| Concern                | MobX (TFRP)                        | Redux (Om-shaped)                |
|------------------------|------------------------------------|----------------------------------|
| State                  | Mutable, observable                | Immutable, replaced wholesale    |
| Update mechanism       | Direct mutation in actions         | Reducer returns new state        |
| Subscription           | Auto-tracked from reads            | Explicit selectors               |
| Time-travel debugging  | Hard (mutation)                    | Trivial (action log)             |
| Performance default    | Optimal (precise propagation)     | Requires `useSelector`/Reselect   |
| Mental model           | Spreadsheets                       | `(state, action) → state`         |

Both are correct designs in their respective universes. People who insist one is "right" and the other is "wrong" are missing that they answer different questions.

---

## 5. Cycle.js: the road not taken

André Staltz's Cycle.js (2014) takes the reactive idea seriously to its conclusion. A Cycle.js application *is* a function

```
main : Sources → Sinks
```

where sources and sinks are streams (xstream or RxJS Observables). DOM events come in as a source; virtual DOM goes out as a sink; HTTP requests go out, responses come in; WebSocket frames flow in both directions. Side effects live in **drivers**: pluggable interpreters for sinks. This is, structurally, exactly Elm's `Cmd`/`Sub` discipline, and exactly what algebraic-effect handlers do, expressed in Rx.

```js
function main(sources) {
  const click$ = sources.DOM.select('.btn').events('click');
  const count$ = click$.fold((acc, _) => acc + 1, 0);
  const vdom$ = count$.map(n => div([button('.btn', `Clicked ${n} times`)]));
  return { DOM: vdom$ };
}
run(main, { DOM: makeDOMDriver('#app') });
```

Cycle.js has the cleanest *theory* of any UI library on this list. It also has the smallest user base, because writing every part of an application in xstream operators is genuinely hard, and because the network effects of React eat everything. Read Staltz's "Unidirectional User Interface Architectures" and "Why we built xstream" for the design philosophy. Cycle.js is what React might have looked like if Markbåge had won the 2016 TC39 fight (see §11 below).

---

## 6. Reselect, Immutable.js, Immer

### 6.1 Reselect — memoized selectors

Reselect (`reduxjs/reselect`, packaged into Redux Toolkit by default) is a single idea: a memoized selector recomputes only when its inputs (compared by reference equality) change.

```js
import { createSelector } from 'reselect';
const selectTodos      = (s) => s.todos;
const selectFilter     = (s) => s.filter;
const selectVisibleTodos = createSelector(
  [selectTodos, selectFilter],
  (todos, filter) => todos.filter(t => match(t, filter))
);
```

It works because Redux state is treated as immutable: `selectTodos(state) === selectTodos(state)` is true unless the todos slice was actually replaced. This is *Om's reference-equality optimization* re-implemented at the selector level. The pitfall is that any selector that returns a fresh object/array on every call (`(s) => s.users.map(transform)`) defeats the cache the moment you wrap it. The pre-Hooks cure was per-component selector instances; the modern cure is `weakMapMemoize` (Reselect 5).

### 6.2 Immutable.js — persistent data structures

Facebook's Immutable.js gave JS persistent `Map`, `List`, `Set`, `Record`, `OrderedMap` with structural sharing — the actual Clojure data structures, ported. The cost: a parallel API (`get`/`set`/`merge`) that does not interoperate with idiomatic JS. Many teams, including Facebook itself, walked back from Immutable.js in favor of:

### 6.3 Immer — copy-on-write with mutable syntax

Michel Weststrate's Immer (same author as MobX) lets you write mutable code and gives you immutable results via Proxies and structural sharing:

```js
import { produce } from 'immer';
const next = produce(state, draft => {
  draft.users[id].active = true;     // looks mutable; isn't
});
```

This is the design Redux Toolkit standardized (`createSlice` uses Immer internally). It is the right answer for 95% of "I want immutability without ceremony" cases. It is *not* a replacement for the algorithmic benefits of persistent data structures (Immer's structural sharing is ad-hoc per `produce` call, not amortized across the application), but it is a vastly better ergonomic answer than spread-juggling.

---

## 7. Recompose — the lost utility belt

Acdlite's `recompose` (2016) was the closest thing the React ecosystem ever had to a real combinator library. The most interesting combinators:

- `withState(name, setter, initial)` — adds state without a class.
- `withHandlers({ onClick: ({ count, setCount }) => () => setCount(count+1) })` — stable handler functions.
- `lifecycle({ componentDidMount() {} })` — lifecycle as a HOC.
- `branch(pred, leftHOC, rightHOC)` — conditional component wrapping.
- `mapPropsStream(props$ => observable$)` — a component is a function from a stream of props to a stream of props. This was *Cycle.js inside React*.

Recompose was archived in 2018 because, as Clark put it himself, Hooks subsume its goals. That is *almost* true: `useState`/`useReducer` cover `withState`; `useCallback` covers `withHandlers`; `useEffect` covers `lifecycle`. What Hooks do *not* cover cleanly is `mapPropsStream` — there is no first-class observable-based component definition in modern React, and you have to roll one with `useSyncExternalStore` and a lot of glue. This is one of the genuine regressions.

---

## 8. Hooks as an algebraic-effects approximation (sharpened)

Hooks (React 16.8, February 2019) introduced `useState`, `useEffect`, `useContext`, `useReducer`, `useMemo`, `useCallback`, `useRef`, `useLayoutEffect`, etc. The marketing framing is "function components can now have state". The interesting framing — Sebastian Markbåge's framing, internal to the React team — is that hooks are a userland approximation of **algebraic effects**.

### 8.1 The party-line analogy

In algebraic-effects-flavored languages (Eff, Koka, OCaml 5, the Markbåge proposal of §11), a computation can `perform` a named effect (`State`, `Read`, `Random`) and the *handler* up the call stack interprets it. In Dan Abramov's "Algebraic Effects for the Rest of Us" (overreacted.io, July 2019):

> *"You can think of `useState()` as of being a `perform State()` effect which is handled by React when executing your component. That would 'explain' why React (the thing calling your component) can provide state to it (it's above in the call stack, so it can provide the effect handler) … of course, that's not how React actually works because we don't have algebraic effects in JavaScript."*

And in his earlier "Making Sense of React Hooks" (October 2018), Abramov writes the sentence the React team has been quietly walking back ever since:

> *"If you're a functional programming purist and feel uneasy about React relying on mutable state as an implementation detail, you might find it satisfactory that handling Hooks could be implemented in a pure way using algebraic effects (if JavaScript supported them)."*

A React-team member (Sebastian Markbåge) had spent 2016 trying to get exactly that into JavaScript. He failed (see §11). Hooks are what was built instead.

### 8.2 What hooks actually are

Strip the marketing and read the source (`react-reconciler`'s `ReactFiberHooks.js`). Hooks are:

1. A **module-level mutable dispatcher pointer** (`ReactCurrentDispatcher.current`) that React swaps on entry and exit of a component render.
2. A **per-fiber linked list of hook records** (`memoizedState.next.next.next…`).
3. An **integer cursor** that advances by one for every hook call within a single render.
4. A discipline (the **Rules of Hooks**) that ensures the integer cursor stays in lockstep across renders — so the *N*th hook call refers to the same hook record each time.

This is not algebraic effects. It is a position-indexed slot table backed by render-time mutable globals. The reason hooks must be called unconditionally and in the same order is that the slot index is implicit in source position; if you put a hook inside an `if`, the index drifts and the `useState` that was at slot 2 last render is now at slot 1 and reads someone else's state.

### 8.3 The CPS-vs-data distinction (this is the core technical claim)

This is where the framing matters, and where Isaac Huang's "React is not Haskell" (caasih.net, April 2026) sharpens what was ambient before. Two questions:

**(a) When you write `useState(0)`, what gets produced?** In Haskell, `getLine :: IO String` evaluates to a *value* of type `IO String` — a description of an action, not the action itself. The `IO a` value is a node in a (conceptual) action tree that `main`'s runtime later interprets. Crucially, *the program is data*. The compiler can inspect, reorder, fuse, and eliminate parts of it.

In React, `useState(0)` is a function call that, *during render*, **directly mutates** the fiber's hook list (or reads from it on update). It produces a `[value, setter]` tuple. There is no intermediate description. There is no action list to inspect. The "effect" *is* the call.

**(b) How does the surrounding system reason about it?** Suspense's "throw a promise" mechanism is, structurally, a **CPS transformation done at render time**: the component throws, the framework catches at the nearest `<Suspense>` boundary, then *replays the render from scratch* when the promise resolves. The component is *not* paused at a continuation; React has no continuation to resume. It only has the input props, state, and context, and it re-runs the function. (Kent C. Dodds's "How React Suspense Works Under the Hood" lays this out clearly: "After a component throws, React doesn't have any magic way to jump back to where the render left off. Instead, it simply re-renders the entire component from scratch.")

This is qualitatively different from a real effect handler (or even Haskell's `do` desugaring). A real handler captures the rest of the computation; React fakes it via *idempotence* — the assumption that re-rendering with the same inputs is equivalent to resuming, because rendering is supposed to be pure. When that assumption holds, the trick works. When it doesn't, you get the entire surface area of bugs that the "Rules of React" exist to lint away (more on this in §10).

### 8.4 Why the Haskell compiler can do things React cannot

Take `foldr/build` short-cut deforestation (Andrew Gill, John Launchbury, Simon Peyton Jones, "A Short Cut to Deforestation", FPCA '93). The rule is one line:

```haskell
{-# RULES "foldr/build"  forall k z g. foldr k z (build g) = g k z #-}
```

Together with the formulation `map f xs = build (\c n -> foldr (\x ys -> c (f x) ys) n xs)`, this rule causes `sum [1..10]`, `map f . map g . filter p`, and tree pipelines to fuse into single tight loops with **zero intermediate list allocation**. This is the famous result where `foldr (+) 0 [1..10]` compiles to roughly `sum_loop 1 10 0` — an imperative-shaped accumulator with no list ever materialized.

This works because:

1. Haskell lists are *data*; `build` and `foldr` have type-system-guaranteed semantics; the compiler treats them as inspectable structure.
2. The language is referentially transparent, so the `foldr/build` rewrite is *unconditionally sound*. No side-effect analysis is required.
3. GHC's `RULES` pragma, plus phased inlining and `INLINE`/`NOINLINE`/`CONLIKE` controls, lets library authors register equational program transformations that the optimizer applies during simplification.

(See: GHC User's Guide §6.19.1 "Rewrite rules"; the original Gill/Launchbury/Peyton Jones FPCA '93 paper; treeMap fusion as documented in `randomhacks.net/2007/02/10/map-fusion-and-haskell-performance/`.)

The React equivalent does not exist because:

1. JS components are not data. They are functions called for their side effects on the fiber tree.
2. JS has no purity guarantees the compiler can rely on. Any function call could mutate the world.
3. Therefore the React Compiler (v1.0, October 2025) must do **purity inference by metaprogramming on the JS AST**: it walks Babel's AST, applies heuristics to identify components and hooks, conservatively types values it can recognize (primitives, hooks, refs), and *gives up* on code it cannot prove safe. Per the React Compiler design goals (`facebook/react/compiler/docs/DESIGN_GOALS.md`):

   > *"Support code that violates React's rules. React's rules exist to help developers build robust, scalable applications and form a contract that allows us to continue improving React without breaking applications. **React Compiler depends on these rules to safely transform code, and violations of rules will therefore break React Compiler's optimizations.**"*

The compiler's response when it sees a Rules-of-React violation is not to fail the build — it is to **silently skip optimizing the affected component**. This is honest engineering, but it is also exactly the contract a real type-system-enforced effect system would *not* require, because the compiler could prove the transformation safe.

### 8.5 The Rules of Hooks as a workaround for not having an effect system

The Rules of Hooks are:

1. Only call hooks at the top level (no `if`/`for`/early-return).
2. Only call hooks from React function components or other custom hooks.

These are linter rules (`eslint-plugin-react-hooks/rules-of-hooks` and `react-hooks/exhaustive-deps`). They are enforced *outside* the type system, by string-matching identifier names beginning with `use` and walking the JS AST. The newer `eslint-plugin-react-hooks` v5+ adds Rules-of-React-derived diagnostics from the React Compiler (`purity`, `set-state-in-render`, `set-state-in-effect`, `static-components`, `immutability`, `refs`).

In a real algebraic-effect language, none of these rules would exist. A handler-based effect system would:

- make the capture boundary the effect boundary by construction (no need for "only call at top level"),
- carry effect rows in the type signature (no need for naming-convention enforcement),
- prevent unhandled effects at the type-checker level (no "Invalid hook call" runtime error),
- allow conditional effect performance because the operational semantics is a real `perform`/`resume`, not a positional array index.

The Rules of Hooks exist because hooks are not effects — they are array slots — and the discipline of "always touch all the slots in order" must be enforced *socially* via lint, because the language cannot enforce it.

### 8.6 What hooks did get right

To be fair: `useEffect`'s setup/cleanup pairing genuinely *is* better than class-component lifecycle methods for cross-cutting concerns. Custom hooks do compose. The Hook ecosystem has produced genuinely useful abstractions (`useSyncExternalStore`, `useDeferredValue`, `useTransition`). The story is not "hooks are bad" — it is "hooks are an approximation of an idea, and the gap shows up in exactly the places the React team has been patching with linters, compilers, and runtime warnings ever since."

---

## 9. Best practices for the React you actually maintain (pre–RSC, pre-`use`)

These are the lessons that survive the lineage analysis. They are stated as imperatives because they should be.

1. **Keep components pure.** This is now the React docs' first rule ("Components must be idempotent"). Treat it as a typeclass law, not a suggestion. If your component reads `Date.now()` or `localStorage` during render, it is broken. Move all such reads into event handlers or `useEffect`.

2. **Treat state as immutable, even in MobX.** Even when you use MobX, model state transitions as *replacements* of subtrees, not as long-lived in-place mutations spanning multiple ticks. The mental model is what matters; the implementation can mutate.

3. **Push state down; lift it up only when shared.** This is the same advice from 2014 and it remains correct.

4. **Co-locate effects with the state they synchronize.** A subscription's setup, teardown, and dependency list belong in one `useEffect`. If you find yourself splitting them across multiple effects to "share" a ref, you are reinventing class lifecycles.

5. **Prefer `useReducer` over `useState` once you have more than two correlated state variables.** Reducers are testable in isolation. `useState` chains lead to interleaved-update bugs that `unstable_batchedUpdates` and React 18's automatic batching only partially fix.

6. **Memoize expensive derivations with Reselect (or equivalent), not with `useMemo` everywhere.** `useMemo` is render-scoped; selectors are application-scoped. If you reach for `useMemo` to skip a 100ms computation, you have a state-shape problem, not a memoization problem.

7. **For server state, do not use Redux. Use TanStack Query / SWR / RTK Query.** Server state is fundamentally different from client state: it has cache invalidation, request deduplication, retry/backoff, focus revalidation. Reducer-based libraries handle none of this natively.

8. **Effects-as-data > effects-as-thunks.** Within the Redux family this means saga or observable, not thunk. Within the React family it means treating async state machines (TanStack Query, XState) as first-class.

9. **Run `eslint-plugin-react-hooks` with `recommended-latest` and treat `exhaustive-deps` warnings as errors.** Yes, the rule is sometimes wrong. It is right far more often than your intuition.

10. **If you adopt the React Compiler, do it after you have audited your codebase for Rules-of-React purity violations.** The compiler silently skips components that break the rules. Use the React DevTools compiler badge to verify which components are actually being optimized.

11. **Stop reaching for `useMemo`/`useCallback`/`React.memo` defensively** once the React Compiler is on. The whole point of compiler-driven memoization is that those wrappers become escape hatches for the few cases where referential stability matters for *correctness* (effect deps, subscription identity), not for performance.

12. **TypeScript hard, but understand its limits.** TS does not encode purity, does not encode hook-call ordering, does not encode effect rows. It will not save you from an out-of-order hook call. The linter will.

---

## 10. Scoreboard: how the patterns compare to the originals

This table should be read as: *what original FP/FRP idea is each ecosystem item a degraded copy of, and how degraded?* "Degradation" is judged on type-system reflection, compositionality, and operational rigor.

| Ecosystem item            | Original FP/FRP idea                       | Degradation                                                                                                                  |
|---------------------------|--------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| React component (`view = f(props, state)`) | Pure ML/Haskell function returning ADT    | Mild. Purity is documented and lint-checked, not type-checked. JSX is a thin sugar over `React.createElement` calls.        |
| Redux (`reducer + store`) | Elm Architecture (TEA)                     | Moderate. No `Cmd`/`Sub` discipline; effects are bolted on as middleware. No exhaustive `Msg` matching.                      |
| redux-thunk               | (none — escape hatch)                      | Severe. Effects are opaque function bodies, not data. No replay, no introspection, no testability without mocks.            |
| redux-saga                | Algebraic effect handlers via coroutines  | Moderate. Effects ARE data, handlers compose, but no effect rows in the type system; ergonomics are bad at scale.           |
| redux-observable          | FRP / Cycle.js with Rx                     | Mild. Genuine compositionality of streams; learning curve of RxJS is the cost.                                              |
| MobX                      | Transparent FRP (Knockout / spreadsheets / Reflex) | Mild. Best-in-class signal-graph reactivity in JS. Real grievance: not first-class in React's mental model.        |
| Cycle.js                  | FRP with effect handlers via drivers       | None. The architecture is correct. The cost is small ecosystem and steep ramp.                                              |
| Reselect                  | Memoization / Om's `=` on persistent data  | Mild. Works but easy to defeat by returning fresh objects.                                                                  |
| Immutable.js              | ClojureScript persistent data structures   | Mild on theory, severe on ergonomics — parallel API breaks JS interop.                                                       |
| Immer                     | Copy-on-write with structural sharing      | Mild. Pragmatic; not algorithmically optimal but ergonomically excellent.                                                    |
| Recompose                 | Combinator library / `mapPropsStream` ≈ Cycle.js | Discontinued. Hooks subsume most of it; `mapPropsStream` has no clean Hooks equivalent.                                |
| Hooks (`useState`, `useEffect`, …) | Algebraic effects (Eff / Koka / OCaml 5)         | **Severe.** Slot-table approximation. No effect rows; rules enforced by linter; "throw a Promise" is CPS, not a real handler. |
| `use(promise)` / `use(context)` (out of practice scope here) | Haskell's `do` notation desugaring `>>=`      | **Severe and miscategorized.** Specialized to two effect types; **not** parametric over a `Monad` class. See §11.5.            |
| React Compiler            | GHC's `RULES` + `INLINE` + purity         | Moderate. Cannot rely on language-level purity; must infer by AST metaprogramming; silently skips Rules-of-React violators.  |
| Suspense ("throw a promise") | One-shot delimited continuation            | **Severe.** No real continuation; replay-from-scratch on idempotence assumption.                                              |
| Server Components / `use` (out of practice scope) | Effect handlers + serialization boundary    | (See §11.) Borrows Haskell's reputation; ships none of its mechanism.                                                          |

---

## 11. Postscript: React is not Haskell

This section is a deeper analytical lens on the algebraic-effects framing of §8. It is prompted by Dan Abramov's recent "React is basically Haskell" claim (Bluesky / Reddit, 2026) and Isaac Huang's response, "React is not Haskell" (caasih.net, 2026-04-14), with an extension of the cultural-cost argument from Roriri's "What a React" (roriri.one, 2026-04-12).

The thesis is short: the React team always wanted algebraic effects in the language. They did not get them. What shipped instead — `use`, Suspense, Server Components, the React Compiler — is a stack of userland approximations whose abstractions leak in patterned, predictable ways. Calling this stack "Haskell" obscures the actual engineering and externalizes the cost of the leaks onto the people least equipped to absorb them.

### 11.1 The claim, and why it matters

In April 2026, Dan Abramov stated on Bluesky and reiterated on Reddit that *"React is basically Haskell"*. He was, characteristically, half-joking and half-serious — Abramov has been making this rhyme since "Algebraic Effects for the Rest of Us" (2019) and "Making Sense of React Hooks" (2018), where he wrote that hooks "could be implemented in a pure way using algebraic effects (if JavaScript supported them)". The vision is right. The claim, as stated, is wrong, in ways that matter for how people learn React.

### 11.2 `use` is not `do` notation

The most concrete error in the analogy is the suggestion that React's `use` hook is the Haskell `do`-notation analogue. It is not.

Haskell's `do`-notation desugars, by a compile-time syntactic rule defined in the Haskell 2010 report, into chains of `>>=` (bind) and `>>`:

```haskell
do x <- m1
   y <- m2
   return (f x y)
```

becomes

```haskell
m1 >>= \x ->
m2 >>= \y ->
return (f x y)
```

This works for **any** type `m` that implements the `Monad` typeclass — `IO`, `Maybe`, `Either e`, `[]`, `State s`, `Reader r`, `STM`, `Cont r`, `Free f`, your custom `Parser`, anything. The desugaring is parametric in the monad. `do`-notation is not aware of `IO`; it is aware of `>>=`. (Sources: GHC User's Guide §6.2 "Applicative do-notation" and §6.2.5 "Qualified do-notation"; *Real World Haskell* ch. 14 "Monads"; Marlow & Peyton Jones, "Desugaring Haskell's do-notation into Applicative Operations", Haskell Symposium 2016.)

React's `use` is the opposite. Reading the React 19 `use` source in `react/packages/react-reconciler/src/ReactFiberHooks.js`:

```ts
function use<T>(usable: Usable<T>): T {
  if (usable !== null && typeof usable === 'object') {
    if (typeof (usable as Thenable<T>).then === 'function') {
      return useThenable(usable);
    } else if (
      (usable as ReactContext<T>).$$typeof === REACT_CONTEXT_TYPE
    ) {
      return readContext(usable);
    }
  }
  throw new Error('An unsupported type was passed to use(): ' + String(usable));
}
```

`use` accepts exactly two cases — a thenable (Promise) or a `ReactContext`. There is no parametric polymorphism over an interface. There is no `Usable` typeclass that user code can implement: the React docs note *"In future React will likely add more `Usable` types"*, but the dispatch is hardcoded at the framework level by `$$typeof` brand checks. You cannot define your own `Random`, your own `State s`, your own `Parser` and pass it to `use`. This is specialized syntactic sugar over two specific framework primitives, not a general monadic abstraction.

**`use` is closer to `await` for two specific effect carriers than to `do` for any monad.** The React docs make this explicit: "`use(promise)` … roughly equates to `await promise` in an async function" and "When a context is passed to `use`, it works similarly to `useContext`."

### 11.3 What React's runtime actually does is a CPS transformation

The mechanism behind `use` and Suspense is a **continuation-passing-style transformation done at the framework level**: the component throws (a Promise), React catches at the nearest `<Suspense>` boundary, registers a `.then` to know when to retry, and **re-renders the entire component subtree from scratch** when the promise resolves. There is no captured continuation. There is no resume point. There is only "throw, catch, replay" plus the *idempotence assumption* that re-running the function with the same inputs produces the same outputs (the thenable cache makes this work for Promises).

This is fundamentally different from a Haskell `do` block, which:

- desugars at compile time into a syntactic tree of `>>=` calls,
- preserves all intermediate computation as a value of type `IO a` (or whatever monad),
- can be inspected, partially evaluated, fused, and rewritten by the compiler before any of it is *executed*.

The React analogue would be: hooks produce a description of the effects to perform; React inspects the description, optimizes it, and only then runs it. This is what redux-saga's effect objects are — and exactly why redux-saga is testable without mocks. React itself does not do this. **Hooks execute directly during render.** `useState`'s dispatch function performs the state-update enqueue immediately; `useEffect` schedules a side effect immediately; `use` immediately throws a promise or reads a context. The effects are not collected into a manipulable data structure that React can analyze.

### 11.4 Haskell optimizations work because monadic code is data

This is the part of the analogy that, when you press on it, reveals exactly what is missing.

In Haskell, `IO a` is "a description of an action that, when performed, yields an `a`". The `IO` monad in the GHC implementation is operationally `\s -> (a, s)` over a state-of-the-world token — an opaque value. But the *crucial* property is that monadic code is a value: `getLine >>= \s -> putStrLn s` is an expression that **evaluates to a value of type `IO ()`** without ever doing any I/O. Only when `main` (whose type is `IO ()`) is *executed* by the runtime does the action sequence happen.

Because `IO a` is data:

- **The compiler can inspect it.** GHC's `RULES` pragma rewrites left-hand-sides of equations into right-hand-sides during simplification. (GHC User's Guide §6.19.1.)
- **The compiler can fuse it.** `treeMap f (treeMap g t) = treeMap (f . g) t`, when registered as a RULE, eliminates one full tree traversal and replaces it with composition. The author of the original `randomhacks.net` "Map fusion" post saw a 225% throughput improvement from two such rules.
- **The compiler can deforest it.** `foldr/build` short-cut deforestation (Gill, Launchbury, Peyton Jones, "A Short Cut to Deforestation", FPCA '93) eliminates intermediate lists entirely. `foldr (+) 0 [1..10]` fuses into a tight imperative loop with **zero list cells allocated**, because lists are not magical primitives — they are inductively-defined data and `foldr`/`build` are the universal consumer/producer pair.

This works because three things hold simultaneously:

1. The program is data the compiler can rewrite.
2. The language is referentially transparent, so the rewrites are sound.
3. The type system tracks what is and is not pure (`IO a` is bracketed off; `a -> b` cannot do I/O).

React hooks are not data. `useState` is a *call*, not a *value*. There is no `Hook a` ADT that represents "a state hook with initial value 0" before execution. React cannot inspect a component's hook usage without running the component. There is no `RULES`-pragma equivalent that could rewrite `useMemo(() => f(useMemo(() => g(x), [x])), [x])` into a single fused memoization call, because `useMemo`'s second argument is a JS array whose contents are only known at runtime.

### 11.5 The React Compiler is therefore fragile by construction

The React Compiler (v1.0, October 2025; `react.dev/blog/2025/10/07/react-compiler-1`) does what it can. It uses Babel to lift JS into a custom HIR (High-level Intermediate Representation), runs validation and type-inference passes, identifies "reactive scopes" (groups of values created/mutated together), and inserts memoization. Its first design constraint, per `compiler/docs/DESIGN_GOALS.md`, is:

> *"'Just work' on idiomatic React code that follows React's rules (pure render functions, the rules of hooks, etc.)."*

And, dispositively:

> *"Support code that violates React's rules. … React Compiler depends on these rules to safely transform code, and violations of rules will therefore break React Compiler's optimizations."*

When the compiler encounters code that breaks a rule, **it does not fail the build**. It silently skips that component (visible only via a missing badge in React DevTools' compiler view) and emits no JS-level error. This is honest engineering — the compiler cannot prove safety, so it abstains — but it is also a contract that says: the optimization is conditional on a discipline that the language itself does not enforce.

In Haskell, by contrast, GHC's RULES are **unconditionally sound** within their stated scope, because the type system has already proven the relevant purity. You do not need to lint your code to keep `foldr/build` working; you need only let the compiler see through the type. This is the structural difference that the "React is basically Haskell" framing hides.

### 11.6 The honest implementation: Markbåge's 2016 TC39 proposal

This is the history that should be told more often, and that Huang's "React is not Haskell" reads as the critical pivot point. On **15 March 2016**, Sebastian Markbåge — already on the React core team, soon to be the principal designer of Hooks and Suspense — posted to `es-discuss`, the EcmaScript discussion list, a proposal titled **"One-shot Delimited Continuations with Effect Handlers"** (`esdiscuss.org/topic/one-shot-delimited-continuations-with-effect-handlers`; the original is at `mail.mozilla.org/pipermail/es-discuss/2016-March/045720.html`).

The proposal is short and clear. Its content:

- Cite OCaml's multicore effect-handler implementation (KC Sivaramakrishnan, 2015) as inspiration.
- Add two new language features: a `perform` expression (contextual keyword, "throws" an effect *and* captures a reified continuation) and a `catch effect` clause (binds `[effect, continuation]` from the `perform`).
- Skeleton syntax:

```js
function otherFunction() {
  console.log(1);
  let a = perform { x: 1, y: 2 };
  console.log(a);
  return a;
}

do try {
  let b = otherFunction();
  b + 1;
} catch effect -> [{ x, y }, continuation] {
  console.log(2);
  let c = continuation(x + y);
  console.log(c);
  c + 1;
}
// Prints: 1, 2, 3, 4. Evaluates to 5.
```

Markbåge's motivation, stated directly in the post:

> *"We've experimented with changing React's implementation to use these internally to handle concurrency and being able to solve complex algorithms that require a lot of back and forth such as layout calculation. It seems to make these implementations much easier while remaining efficient."*

He then anticipated the explicit-async objection:

> *"With generators and async functions, anytime you want to change any deep effects you have to unwind all potential callers. Any intermediate library has to be turned into async functions. The refactoring is painful and leaves you with a lot of syntax overhead. If you want to nest different effects such as layout, iterations and async functions that complexity explodes …"*

This is the same cross-cutting effect problem that monad transformers and free monads attack in Haskell, and it is exactly the problem that Hooks would later partially solve in userland.

The TC39 / es-discuss community pushed back on grounds that, with hindsight, look like a textbook case of cultural mismatch. The full thread is short and worth reading. The substantive objections:

1. **Explicit-over-implicit cultural preference.** Joe Pea: *"The beauty of JavaScript from the very beginning … is that dealing with asynchronous behavior is something a JavaScript developer is forced to do from the get go. Introducing invisible asynchronous behavior would deviate from that (and be more like Java). … Requiring `await` will force everyone to learn how to deal with async behavior from the get go."* This is the standard "function colors" defense — cf. Bob Nystrom's "What Color is Your Function" — which the JS community treats as a virtue.
2. **Compose with existing primitives.** Ben Newman: *"What if we simply allowed `await` expressions anywhere in the call stack of an async function … [it] would give us all the power of 'yielding deep in a fiber' with a much more familiar syntax."* TC39 needed a lot of convincing that coroutines were a good idea.
3. **No consensus that the use-case is real.** kai zhu (December 2019, after the thread had reopened in light of Hooks): *"the usage-scenario is not compelling. the same effect can be achieved in 12-lines of throwaway-code."* He attached an `async/await` snippet handling one timeout case. This is the typical problem of evaluating an effect-system proposal by a single-effect example.
4. **Try/catch should mean errors only.** Joe Pea again: *"The effect addition to try-catch seems like some sort of hacky workaround … which defeats its original purpose."*

Markbåge's reply to (1) is, with hindsight, the technically correct one:

> *"I start from the premise that this explicitness is already a huge and unmanageable problem through observation. … If it wasn't, the status quo would be fine, but it isn't. The beauty of algebraic effects is that these side-effects can't just randomly leak. If you're concerned about any particular code path having these side-effects you can catch all the effects in that code-path. … you opt-in to that guarantee when you need it, instead of forcing every little thing along the way make that decision."*

The proposal did not advance.

In November 2018 — after Hooks had been announced at React Conf — a developer named 森建 (mori) returned to the same thread:

> *"React Hooks, a new feature of React v16.7.0-alpha, is a hacky implementation, so there are restrictions that must be called in order. … One of React members says below: 'Finally, if you're a functional programming purist and feel uneasy about React relying on mutable state as an implementation detail, you might find it satisfactory that handling Hooks could be implemented in a pure way using algebraic effects (if JavaScript supported them).' IMHO, it's worth considering that we'll include Algebraic Effects specifications in ECMAScript."*

This is a specific historical fact: a community member, after seeing React ship its slot-table workaround, returned to the exact thread that had been declined two years earlier and pointed out that Hooks were the workaround for the language feature that had been refused. The thread did not reopen.

### 11.7 What this means for the "React is Haskell" claim

Recasting the lineage in light of §11.5–11.6:

1. The React team, through Sebastian Markbåge, identified the language-level abstraction they wanted — one-shot delimited continuations with effect handlers — and proposed it to TC39 in 2016.
2. TC39 declined, on a mix of cultural (explicit-over-implicit) and technical (use-case-not-compelling) grounds. None of the technical objections engaged with the Haskell-lineage type-system argument, because TC39 is not a typed-language committee.
3. The React team built userland approximations: hooks (slot tables), Suspense (throw-a-promise CPS), Server Components and `use` (specialized to two effect carriers). These work in the cases the team optimized for.
4. Each approximation comes with a non-syntactic invariant: hooks must be ordered, components must be pure, refs must not be read during render, state must not be set in render. These invariants are linted, not typed.
5. As the API surface grew, the React Compiler was needed to recover performance lost to the hooks-as-slot-table model. The compiler depends on those lint-enforced invariants, so violations produce silently un-optimized components.
6. The "React is basically Haskell" claim then takes the *vision* — pure components, monad-shaped composition, effects as data — and projects it onto the *implementation*, which is none of those things. The vision belongs to Haskell and OCaml. The implementation is a JS framework.

The honest summary, in Huang's framing: **the React team always wanted algebraic effects. After TC39 rejected the language-level proposal, they built ad-hoc approximations in userland. Saying "React is basically Haskell" is the right vision but the wrong claim — not even a basic effect handler made it into the language. They borrowed Haskell's reputation to legitimize their design without taking responsibility for getting the abstraction right.**

### 11.8 The asymmetric pedagogical cost

A note that should be stated honestly and not preachily, because it is the lived experience of most engineers using React, and it is the strongest argument for caring about all of this.

At the tier-1 companies whose internal practice produces React's documentation — Meta, Vercel, the Bluesky core team — broken abstractions are *rough edges*. There is internal education, code review density, senior engineer concentration, and direct Slack access to the people who designed the abstraction. When `useEffect` fires twice in StrictMode and that breaks an analytics integration, somebody in the room knows why, can explain it, and the team writes an internal wiki page. The abstraction leaks; the leak is repaired by social capital.

In the engineering cultures where junior-frontend training is "learn the framework, ship features" — this is the case in much of Asia, including the author of "What a React" (Roriri), based in Taiwan, and Huang, the author of "React is not Haskell" — the same leaks land differently. Side effects, purity, and monadic interfaces are not on the curriculum. The "Rules of Hooks" are taught as cargo: "do not put `useState` inside an `if` block" is *not* taught as "the slot index would drift; effects must be sequenced; this is a type-system gap"; it is taught as "the docs say so, the linter says so, do not." Memorized rules without the underlying model produce memorized rules. Memorized rules cannot be debugged from principles. Engineers cannot grow into seniors who reason from first principles, because the first principles were occluded by the framework.

The deeper cost is that the FP knowledge that *would* unlock real growth — algebraic effects, monadic interfaces, type-system effect tracking, denotational reasoning — becomes harder to teach because it is entangled with a broken implementation. The student looks at hooks and sees rules. The teacher tries to point at Haskell and the student does not see the connection, because the implementation is not Haskell. React was, briefly around 2014–2016, a gateway drug to FP. Today, with `use`, Suspense, and Server Components, it assumes you already understand the FP concepts behind it but refuses to teach them and gives you no correct abstraction to learn from. The juniors are left with rules.

This is not a moral failing of the React team. It is a structural consequence of choosing a userland implementation of an idea that the language refused, then marketing it with the rhetoric of the language that did get the idea right. The structural fix would be to either (a) be honest about what the implementation actually is — a CPS transformation specialized to Promises and Context — and stop claiming the Haskell mantle, or (b) get one-shot delimited continuations into TC39, which is currently dormant.

### 11.9 What follows for the document's editorial stance

The argument so far does not say "do not use React". It says: when you read a React API and the docs claim a Haskell-derived intuition, *check the implementation*. The intuition will be Haskell-shaped; the implementation will be a special case, an idempotence assumption, a slot table, a thrown promise, or a linter. Knowing the gap is the difference between a senior engineer and a person who has memorized rules.

The previous sections of this document — lineage, idioms, libraries, scoreboard — were written so that the gap can be named precisely each time. The postscript is the moral of the story.

---

## 12. Bridging to current practice

This document deliberately stops short of recommending patterns for React Server Components and the `use` hook. The reasons follow from §11: those features are the place where the FP analogy breaks most visibly, and where the engineering gap is widest. There is no clean way to teach `use` as "do-notation" and have the student debug a stale-promise bug from principles. There is no clean way to teach RSC's serialization boundary as "an effect handler" and have the student understand why a function passed across the boundary causes an error. The honest pedagogy is: these features are useful, they are not what they are advertised to be, and they belong in their own document with their own caveats.

For the React you actually maintain today — class components, hooks, Redux, MobX, observables, Reselect, Immer — the lineage holds and the rules in §9 are sufficient. Treat the editorial framing of the postscript as background context for why those rules look the way they do.

---

*Inline source materials: Conal Elliott & Paul Hudak, "Functional Reactive Animation" (ICFP 1997); Evan Czaplicki, "Elm: Concurrent FRP for Functional GUIs" (2012) and "Asynchronous FRP for GUIs" (PLDI 2013); David Nolen, "Om" (2013–2014); André Staltz, "Unidirectional User Interface Architectures" (2015) and the Cycle.js docs; Andrej Bauer & Matija Pretnar, "Programming with Algebraic Effects and Handlers" (arXiv:1203.1539); Sebastian Markbåge, "One-shot Delimited Continuations with Effect Handlers", es-discuss, 15 March 2016 (esdiscuss.org/topic/one-shot-delimited-continuations-with-effect-handlers); Andrew Gill, John Launchbury, Simon Peyton Jones, "A Short Cut to Deforestation" (FPCA 1993); GHC User's Guide §6.19.1 "Rewrite rules"; Dan Abramov, "Making Sense of React Hooks" (Medium, October 2018) and "Algebraic Effects for the Rest of Us" (overreacted.io, July 2019); React docs at react.dev — `reference/react/use`, `reference/rules`, `reference/eslint-plugin-react-hooks`, `blog/2025/10/07/react-compiler-1`; `facebook/react/compiler/docs/DESIGN_GOALS.md`; KC Sivaramakrishnan et al., "Retrofitting Effect Handlers onto OCaml" (arXiv:2104.00250); Ningning Xie & Daan Leijen, "Generalized Evidence Passing for Effect Handlers" (ICFP 2021); Yassine Elouafi, redux-saga (`reduxjs/redux#1139`) and "Algebraic Effects in JavaScript" series (dev.to/yelouafi); Michel Weststrate, "Pure rendering in the light of time and state" (Medium, 2015) on MobX TFRP; Andrew Clark, recompose archival note (October 2018); Isaac Huang ("caasih"), "React is not Haskell" (caasih.net/posts/2026-04-14-react-is-not-haskell); Roriri, "What a React" (roriri.one/2026/04/12/what-a-react).*