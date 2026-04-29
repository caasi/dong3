---
title: Effects at the page boundary
slug: compose-effects-at-page-boundary
category: compose
impact: HIGH
tags: [composition, effects, lifecycles]
---

## Effects at the page boundary

Push side-effects up the component tree until they live at or near a page-level component, then extract pure leaves below. This is the React projection of **Functional Core, Imperative Shell**: leaf components are the functional core (pure projections of props to JSX); the page-level component is the imperative shell that owns fetching, mutation, navigation, and any other contact with the outside world. Same shape known historically as the container/presenter pattern, modernised with hooks — a custom hook (`useTodos`, `useUser`) is the container, every component below is presentational.

**Incorrect** (each leaf wires its own fetch + state):
```tsx
function HeaderUserName() {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => { fetch('/api/me').then(r => r.json()).then(setUser); }, []);
  return <span>{user?.name}</span>;
}

function SidebarBadge() {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => { fetch('/api/me').then(r => r.json()).then(setUser); }, []);
  return <img src={user?.avatar} />;
}
```

**Correct** (the page owns the effect; leaves are pure):
```tsx
function ProfilePage() {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => { fetch('/api/me').then(r => r.json()).then(setUser); }, []);
  return (
    <>
      <Header><HeaderUserName user={user} /></Header>
      <Sidebar><SidebarBadge user={user} /></Sidebar>
    </>
  );
}

function HeaderUserName({ user }: { user: User | null }) { return <span>{user?.name}</span>; }
function SidebarBadge({ user }: { user: User | null }) { return <img src={user?.avatar} />; }
```

When refactoring legacy code this gives a reliable sequence: (1) type the side-effects (typed return values, typed dispatch); (2) lift them up to where the page-level shell can own them; (3) extract pure leaves below. Each step is independently mergeable, diffs stay small, and the codebase becomes easier to reason about — for humans and for coding agents that walk the tree.

The rule is permissive about *what* lives at the page boundary. A page can own effects through `useEffect`, a custom hook, a server-state library, or context-bound fetch logic. What matters is that leaves below the boundary are pure — see `compose-leaf-purity` for the leaf contract, and `model-single-source-of-truth` for the shared-state aspect when multiple consumers need the same fetched value.
