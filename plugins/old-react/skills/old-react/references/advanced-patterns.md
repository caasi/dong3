## Advanced patterns and hints

Patterns and mental models worth knowing but **not** enforced as rules. Use them as inspiration when the v0.1.0 rules feel constraining, when designing v0.2.0 candidates, or when explaining the FP-thinking lens to a teammate. None of these belong in `rules/` until they earn their slot through real review experience.

> Where existing tooling already encodes a pattern, the skill prefers to point at the tooling rather than restate it. The notes below call out which Redux ecosystem features cover the same ground.

### Curried updates: object-as-last-parameter

A small ergonomic trick from FP languages. Define update functions as `update(value)(target) -> target'`, with the target as the last parameter. The same function then composes across contexts:

```ts
const append = (item: string) => (xs: string[]): string[] => [...xs, item];

// In a plain pipeline
const next = append('foobar')(prev);

// In a Promise chain
Promise.resolve(prev).then(append('foobar'));

// In a React state setter
setItems(append('foobar'));
```

Already covered by Redux: **Redux Toolkit's `createAction`** generates static action creators with typed payloads, a `match` type guard, and stable `type` properties. The `createSlice` reducers consume those actions and update with Immer's mutation-shaped syntax — together they cover the same ergonomic ground for state updates without the manual currying.

Source: [COSCUP 2022 — FP frontend (caasih)](https://hackmd.io/@caasih/coscup-2022-fp-frontend-full).

### Nested and composable actions

A root reducer handles the outer state envelope (loading / ok / error) and delegates inner actions to a domain-specific reducer:

```ts
type AsyncState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'ok'; inner: T }
  | { status: 'error'; error: Error };

type AsyncAction<A> =
  | { type: 'fetch' }
  | { type: 'ok'; payload: T }
  | { type: 'fail'; error: Error }
  | { type: 'inner'; action: A };

function asyncReducer<T, A>(
  innerReducer: (s: T, a: A) => T,
): (s: AsyncState<T>, a: AsyncAction<A>) => AsyncState<T> {
  return (state, action) => {
    if (action.type === 'inner' && state.status === 'ok') {
      return { ...state, inner: innerReducer(state.inner, action.action) };
    }
    // outer reducer handles fetch / ok / fail
    // ...
  };
}
```

Compose business logic out of small features into large features without flattening every action into one giant union.

Already covered by Redux: **`combineReducers`** is the canonical reducer-composition mechanism, used "by far the most" widely-used approach to structuring reducer logic. For richer composition (delegation by tag, cross-slice handlers), the *Beyond combineReducers* docs cover the patterns.

Source: same article.

### CPS as the unifying React abstraction

`Promise<T>`, `Observable<T>`, hooks (`useState`, `useEffect`), and `async/await` are all CPS transformations bridging "callback shape" and "linear-syntax shape". Modern front-ends "rush to implement what programming languages should do" — async/await is JS's CPS-to-direct-style transform; React Hooks are the UI-library version of the same:

```ts
// Callback shape (CPS)
fetchUser(id, (err, user) => { ... });

// Promise (delimited CPS)
fetchUser(id).then(user => { ... });

// async/await (language-level CPS)
const user = await fetchUser(id);

// Hooks (UI-library CPS)
const [user] = usePromise(fetchUser(id));
```

This framing makes the entire async story (Hooks, Suspense, `use(promise)`) legible as one design pressure: bridging the gap between callbacks and linear code. See `references/hooks-as-slot-table.md` for the React-specific slot mechanism, and `references/fp-thinking.md` for the broader lens.

Source: same article.

### Time and space duality

`useState` projects values across *time* — each render reads the latest. A complementary `useSpace` collects past renders into a *spatial* array, exposing the entire change history within a single render:

```ts
function useSpace<T>(value: T): T[] {
  const ref = useRef<T[]>([]);
  ref.current = [...ref.current, value];
  return ref.current;
}
```

The author labels this 無用 (useless) because standard React APIs already solve the production cases. The value is the **mental model**: state as a projection of an event stream, not a "current value". This reinforces the action-log framing in `effect-emit-named-actions` — every meaningful state transition is named, the timeline is legible, "what is the current value" is a derivation.

Source: [無測無用 (caasih)](https://caasih.net/playground/useless).

### When to reach for these

| Situation | Pattern |
|-----------|---------|
| You find yourself writing the same update three times for different containers | Curried updates |
| Your reducer is becoming a giant tag-union and slices want their own | Nested / composable actions |
| You're explaining why hooks have these strange rules | CPS framing |
| You want to think about state as derivation, not storage | Time-space duality / event sourcing |

If the same pattern shows up across enough reviews to justify enforcement, promote it from this file to a `rules/<slug>.md`. Until then it is a hint.
