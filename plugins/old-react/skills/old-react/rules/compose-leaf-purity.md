---
title: Keep leaf components pure
slug: compose-leaf-purity
category: compose
impact: MEDIUM
tags: [composition, purity, render]
---

## Keep leaf components pure

Leaf components — the buttons, rows, badges, fields — should accept everything they need as props and return JSX. They should not fetch data, talk to a store directly, or read globals. This is the "presentational" half of the old container/presenter split, and it survives because pure leaves are trivially testable, trivially memoizable, and trivially reusable.

**Incorrect** (leaf reaches into a store):
```tsx
function UserBadge() {
  const user = useUserStore(s => s.current); // direct store access
  return <span>{user.name}</span>;
}
```

**Correct** (leaf takes its data as a prop):
```tsx
function UserBadge({ user }: { user: User }) {
  return <span>{user.name}</span>;
}

function CurrentUserBadge() {
  const user = useUserStore(s => s.current);
  return <UserBadge user={user} />;
}
```

The container component (`CurrentUserBadge`) is the only one that knows about the store. Replacing the store, or rendering `UserBadge` from a fixture in a test or component-demo page, costs nothing.

Demoability is the concrete payoff: a pure leaf can be mounted with literal prop fixtures (`<UserBadge user={{ name: 'Ada' }} />`) and renders identically every time, with no provider tree, no mock store, no network shim. The leaf can be demoed alone — in a unit test, an isolated dev page, or a component-explorer tool. The packaging is a detail; the property that makes any of them work is leaf purity. The moment a leaf reads from a store or context directly, every demo now needs the surrounding world reconstructed, and the leaf has stopped being a leaf.

See `compose-consistent-context-access` for the related concern of mixed HOC/hook access styles: when context is read inconsistently across the codebase, the dataflow becomes harder to follow regardless of where in the tree the read occurs.
