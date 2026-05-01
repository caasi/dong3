---
title: Narrow selector shape
slug: model-narrow-selector-shape
category: model
impact: HIGH
tags: [state, reducer, render, memoization]
---

## Narrow selector shape

A selector is a function `state → view-input`. Every field it reads becomes a re-render trigger: if any of those fields changes, the consumer re-renders. Selecting a whole slice to reach one nested value is the same anti-pattern as importing a whole module to use one symbol — except the cost is paid on every dispatch, not once at startup.

Select the **smallest shape that lets the view do its job**. Push lookups (`map[id]`, `list.find`) into the selector so the result can be compared by reference equality; a pinpoint selector almost always returns the same reference when its slice has not changed, making the equality check free.

This rule is about *selector grain*, not about what belongs in the model at all — the question of whether to store or derive a value is `model-derive-dont-store`.

**Incorrect** (selects a whole map to read one entry; any mutation to any entry re-renders the consumer):
```tsx
const map = useSelector(s => s.users.byId);
const user = map[userId];
```

**Incorrect** (bundles unrelated fields into one object; any dispatch that touches any field invalidates the result):
```tsx
const { depot, navbarActiveItem, draftLength } = useSelector(s => ({
  depot: s.depot,
  navbarActiveItem: s.web.navbarActiveItem,
  draftLength: s.draft.totalCount,
}));
```

**Correct** (selector keyed on exactly what the view needs; reference equality holds when the entry is unchanged):
```tsx
const user = useSelector(s => s.users.byId[userId]);
```

**Correct** (one selector per independent concern; each consumer re-renders only when its own slice changes):
```tsx
const depot = useSelector(s => s.depot);
const navbarActiveItem = useSelector(s => s.web.navbarActiveItem);
const draftLength = useSelector(s => s.draft.totalCount);
```

When the same keyed selector is used in many places, lift it into a selector factory to avoid duplicating the path:

```tsx
const selectUser = (id: Id) => (s: State) => s.users.byId[id];
const user = useSelector(selectUser(userId));
```

The principle is store-agnostic: whether the store is a reducer-store, an atom, or a signal graph, narrow inputs produce narrow re-renders. Memoization libraries for costly derivations are listed in `references/lib-suggestions.md`.
