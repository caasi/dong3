---
title: Model status as a tagged union
slug: model-status-as-tagged-union
category: model
impact: HIGH
tags: [state, reducer, ssot]
---

## Model status as a tagged union

A process occupies exactly one status at any moment — idle, loading, succeeded, or failed — yet modelling it as several independent booleans lets the type system accept nonsensical combinations: simultaneously loading *and* errored, uploading *and* submitted. Encoding status as a tagged union collapses the state space to exactly the valid states; reducers and views become exhaustive matches, and the type checker catches missing cases for free.

**Incorrect** (boolean cluster; impossible states reachable):
```tsx
const [loading, setLoading] = useState(false);
const [error, setError] = useState<Error | null>(null);
const [data, setData] = useState<User | null>(null);
```

**Correct** (one tagged union; impossible states unrepresentable):
```tsx
type Remote<T> =
  | { tag: 'idle' }
  | { tag: 'loading' }
  | { tag: 'ok'; value: T }
  | { tag: 'err'; error: Error };

const [status, setStatus] = useState<Remote<User>>({ tag: 'idle' });
```

The same shape applies to reducer state: a `loading: boolean` field beside an `error` field admits `loading: true, error: someError` — a combination that is reachable but never meaningfully renderable. Replace the pair with a single discriminant field and let the type system enforce the constraint. For status graphs complex enough that a tagged union no longer captures all legal transitions, see `references/lib-suggestions.md` for state-machine library options.
