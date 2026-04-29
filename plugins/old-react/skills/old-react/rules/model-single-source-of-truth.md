---
title: Single source of truth
slug: model-single-source-of-truth
category: model
impact: HIGH
tags: [state, ssot, replay]
---

## Single source of truth

A piece of state should live in one place. If two components hold the "same" value in two pieces of local state, they will drift, and there is no longer a meaningful answer to *"what is the current state?"*. Replay, time-travel, and reasoning about the application as a whole all depend on a single canonical source.

**Incorrect** (the value is mirrored into local state):
```tsx
function Form({ user }: { user: User }) {
  const [name, setName] = useState(user.name); // shadow copy
  return <input value={name} onChange={e => setName(e.target.value)} />;
}
```

**Correct** (the parent owns the value; the child is a controlled view):
```tsx
function Form({ user, onChange }: { user: User; onChange: (u: User) => void }) {
  return (
    <input
      value={user.name}
      onChange={e => onChange({ ...user, name: e.target.value })}
    />
  );
}
```

When two siblings need the same value, lift it to their lowest common ancestor or to a store. Mirroring is fine *only* if the mirror is genuinely transient (e.g. a draft that explicitly forks from the source on edit and rejoins on submit), and that fork must be modeled, not implicit.
