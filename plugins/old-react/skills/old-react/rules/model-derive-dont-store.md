---
title: Derive, don't store
slug: model-derive-dont-store
category: model
impact: HIGH
tags: [state, derivation, ssot]
---

## Derive, don't store

If a value can be computed from the model, do not also keep it in the model. A stored derivation is a second source of truth waiting to drift. Derive at read time; cache only when measurement shows the derivation costs more than the cache management.

**Incorrect** (stores `total` alongside `items`):
```tsx
type Cart = { items: Item[]; total: number };

function add(cart: Cart, item: Item): Cart {
  return { items: [...cart.items, item], total: cart.total + item.price };
}
```

**Correct** (derives `total` from `items`):
```tsx
type Cart = { items: Item[] };

function add(cart: Cart, item: Item): Cart {
  return { items: [...cart.items, item] };
}

function total(cart: Cart): number {
  return cart.items.reduce((sum, item) => sum + item.price, 0);
}
```

If `total` is hot, wrap `total` in a memoized selector — that is a *cache*, not a state field, because it is recomputed automatically when its inputs change and never persisted across reloads.

**Caveat: complex derivations need memoization.** "Derive don't store" does not mean "recompute every render." For expensive transforms — sorting, grouping, large reductions, joins across slices — wrap the derivation in `useMemo` (component-local) or a memoized selector (cross-component; see `references/lib-suggestions.md` for selector libraries). The discipline is: state holds inputs, selectors hold cached outputs, and the cache is invalidated by reference change of its inputs. Skipping memoization on hot paths re-introduces the cost the original "stored derivation" was trying to avoid — without the bug.
