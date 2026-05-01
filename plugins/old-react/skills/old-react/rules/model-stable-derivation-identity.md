---
title: Stable derivation identity
slug: model-stable-derivation-identity
category: model
impact: MEDIUM
tags: [derivation, memoization, render, state]
---

## Stable derivation identity

Derivations only memoize when their **output identity** is stable across calls with equal inputs. This is the dual of the immutability rule: just as an update must produce a *new* reference when state changes, a derivation must produce the *same* reference when state does *not* change. A derivation that mints a fresh value — object literal, function closure, array, or component type — on every call silently defeats every consumer downstream: memoized subtrees re-render, dependency arrays fire spuriously, and reference-equality store comparisons always fail.

The anti-pattern bites at three surfaces.

### Surface 1 — derived value (selector or computed field)

A derivation that returns a fresh object on a fallback path breaks memoization every time that path is taken.

**Incorrect** (fresh literal returned on every empty-list call):
```ts
const selectFirst = (s: State) =>
  s.list.length === 0 ? {} : s.list[0];
```

**Correct** (let the return type carry the absence; `undefined` is itself a stable singleton):
```ts
const selectFirst = (s: State): Item | undefined =>
  s.list.length === 0 ? undefined : s.list[0];
```

`undefined` has stable identity by definition — no allocation, no type lie, no frozen sentinel. The return type widens to `Item | undefined`, which forces consumers to handle the empty case explicitly. When the consumer needs a typed Item-shaped fallback (e.g. for default rendering without conditional checks), define a real `EMPTY_ITEM` that conforms to `Item` and freeze that — never cast `{}` through `as Item`.

A selector factory that mints a fresh selector on every call makes per-call memoization impossible.

**Incorrect** (factory returns a new function on every call):
```ts
const selectById = (id: Id) => (s: State) => s.byId[id];
```

**Correct** (one stable selector; pass `id` at the call site as a second argument). Identity is stable because the function is defined once at module scope; parameterization rides on the argument list, not on closure capture. Reselect's `createSelector` accepts the same shape — `(state, id)` — and this is its recommended pattern in preference to per-id factories (see `references/lib-suggestions.md`).
```ts
const selectById = (s: State, id: Id) => s.byId[id];
// Consumer: const item = selectById(state, id);
```

When the curried *shape* must be preserved (e.g. integrating with a library API that expects `(s) => v`), keep the factory but cache by key so each id maps to one stable output — see Pattern B below. The plain `Map` example in Pattern B assumes a bounded keyspace; for unbounded keys, use a bounded LRU. `WeakMap` is only an option when the key is itself an object (entity reference, DOM node, etc.) — primitive ids (`string` / `number`) cannot key a `WeakMap`, so an LRU or similar evicting cache is the correct choice for that case.

### Surface 2 — derived callback (curried event handler in a list)

A curried handler that creates a fresh closure per item per render defeats memoization on list rows.

**Incorrect** (fresh closure per item per render; memoized row always re-renders):
```tsx
const onRemove = (id: Id) => () => dispatch(remove(id));
return items.map(item =>
  <Row key={item.id} item={item} onRemove={onRemove(item.id)} />,
);
```

**Correct** (single stable handler; identity carried by argument, not closure):
```tsx
const onRemove = useCallback((id: Id) => dispatch(remove(id)), [dispatch]);
return items.map(item =>
  <Row key={item.id} item={item} onRemove={onRemove} />,
);
// Row calls props.onRemove(props.item.id) internally
```

See also `compose-leaf-purity`, which describes the related property that leaf components should receive stable prop identities.

### Surface 3 — derived component (HOC factory called inside render)

Calling a component factory inside a render function produces a fresh component type on every render. React treats a fresh type as a brand-new component and unmounts the previous subtree — lost state, lost refs, broken animations. This is the sharpest class: not "wasted re-render" but "subtree remount with state loss".

**Incorrect** (factory called inside render; fresh component type every render):
```tsx
function Page() {
  const Wrapped = withProps({ theme: 'dark' })(InnerComponent);
  return <Wrapped />;
}
```

**Correct** (factory applied once at module scope, or stabilised with `useMemo`):
```tsx
const Wrapped = withProps({ theme: 'dark' })(InnerComponent);
function Page() { return <Wrapped />; }

// When factory inputs depend on render-time data:
function Page({ theme }: Props) {
  const Wrapped = useMemo(
    () => withProps({ theme })(InnerComponent),
    [theme],
  );
  return <Wrapped />;
}
```

## Curried functions — how to keep them

This rule does **not** ban currying. It bans **unstable identity per (input → output)** at any of the three surfaces above. Several patterns let curried selectors, callbacks, and component factories coexist with reference-equality consumers without removing the currying.

**Pattern A — Drop currying at the consumer seam.** Flatten to two arguments at the React boundary; keep currying inside. For selectors: `(s, id) => s.byId[id]`. For callbacks: accept `(id: Id)` as the prop and call it from inside the child component.

**Pattern B — Per-key memoized factory.** Cache by argument so each input maps to one stable output — `Map`, `WeakMap`, or a bounded LRU (see `references/lib-suggestions.md`). This keeps the curried shape and adds identity stability. Avoid unbounded caches.

**Pattern C — `useMemo` / `useCallback` at the call site.** `const sel = useMemo(() => selectById(id), [id])` for selectors; `useCallback` for callbacks; `useMemo` for component factories. Component-local; requires no changes to the curried function itself.

**Pattern D — Defunctionalization.** Replace `f(arg)` with a tagged carrier `{ tag: '...', arg }` interpreted by one stable function. Identity is carried by data, not by closure — the same principle that motivates `effect-emit-named-actions`.

**Pattern E — Modern memoization libraries.** Cache-size > 1 and weak-map-style memoization handle parameterized calls natively. See `references/lib-suggestions.md` for library-specific guidance.

**Pattern F — Auto-memoizing compilers.** When the runtime auto-stabilizes identity, the tension dissolves. Frame as a future direction, not a migration blocker for existing code.

Prior art and library-specific implementations are in `references/lib-suggestions.md`.
