---
title: Single source of truth for remote state
slug: model-single-source-of-truth
category: model
impact: HIGH
tags: [state, ssot, replay]
---

## Single source of truth for remote state

When the same remote value is read by more than one component, fetch it once, cache it once, read it through one canonical interface. Each consumer running its own fetch is how the same data ends up loaded twice, refreshed at different times, and rendered with conflicting values. A single client-side cache — shared via context, a store, or a request-cache library — is the FP analogue of the Elm `Model`: the one place every consumer agrees to look.

This rule is about *shared* and *remote* state. The component-level question of "where does this controlled `<input>`'s value live?" is `model-controlled-by-default`; the cross-component question of "where does the current user / todo list / cart live?" is here.

**Incorrect** (each consumer fetches independently; values drift):
```tsx
function HeaderUserName() {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => { fetch('/api/me').then(r => r.json()).then(setUser); }, []);
  return <span>{user?.name}</span>;
}

function SidebarUserAvatar() {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => { fetch('/api/me').then(r => r.json()).then(setUser); }, []);
  return <img src={user?.avatar} />;
}
```

**Correct** (one cache; consumers read through it):
```tsx
const UserContext = createContext<User | null>(null);

function UserProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => { fetch('/api/me').then(r => r.json()).then(setUser); }, []);
  return <UserContext.Provider value={user}>{children}</UserContext.Provider>;
}

function HeaderUserName() {
  const user = useContext(UserContext);
  return <span>{user?.name}</span>;
}

function SidebarUserAvatar() {
  const user = useContext(UserContext);
  return <img src={user?.avatar} />;
}
```

The rule does not prescribe a specific cache mechanism — context, a global store, or a request-cache library all qualify; see `references/lib-suggestions.md` for the trade-offs. What matters is that exactly one canonical answer exists for "what is the current value?" and that fetch / invalidation logic is not duplicated across consumers. With a request-cache library this is automatic; with raw context it requires discipline at the provider boundary (one fetch site, one source).
