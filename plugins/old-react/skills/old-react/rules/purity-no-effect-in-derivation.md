---
title: No observable side effects inside a derivation factory
slug: purity-no-effect-in-derivation
category: purity
impact: CRITICAL
tags: [render, derivation, effects, memoization]
---

## No observable side effects inside a derivation factory

A memoized derivation runs during the render phase, may be invoked multiple times per commit (concurrent rendering, strict-mode double-invoke), and may be discarded by the runtime before a commit occurs. Placing an observable side effect inside a derivation factory decouples the effect from the commit phase: the effect can fire 0, 1, or N times per logical state change, at an unpredictable moment. The correct boundary is the effect handler (commit phase), not the derivation factory (render phase).

**Incorrect** (setter inside memoized derivation):
```tsx
const data = useMemo(() => {
  const value = compute(input);
  setStatus('ready');   // render-phase effect — fires at unpredictable times
  return value;
}, [input]);
```

**Correct** (derivation pure; effect at commit):
```tsx
const data = useMemo(() => compute(input), [input]);

useEffect(() => {
  setStatus('ready');
}, [data]);
```

A concrete symptom of a render-phase effect is the "only works with `setTimeout`" workaround: the render phase rejects the state-update synchronously, so developers wrap it in a timeout to defer it past the commit. The fix is not a larger deferral — it is moving the call to an effect handler, where the runtime invokes it exactly once per commit.

### Local mutation is NOT a violation

The rule forbids **observable** side effects, not all mutation. A derivation factory may freely mutate values **created locally inside it**, as long as the factory as a whole remains externally pure (same input → same output, no observable interaction with state outside the factory).

This is the same carve-out the React docs grant explicitly for components and hooks: local mutation is fine; the constraint is about not mutating non-local values. It is also the FP tradition behind encapsulated mutable regions — in-place mutation is referentially transparent when the mutable scope cannot escape (see `references/fp-thinking.md`).

**Allowed** (mutation confined to a fresh value owned by the factory):
```tsx
const sorted = useMemo(() => {
  const buf = [...input];   // fresh array owned by this factory
  buf.sort(cmp);            // mutate the local copy
  return buf;               // caller treats as immutable
}, [input]);
```

```tsx
const index = useMemo(() => {
  const map: Record<string, T> = {};   // fresh object
  for (const item of items) map[item.id] = item;
  return map;
}, [items]);
```

**Still forbidden** (mutation observable outside the factory):
```tsx
useMemo(() => {
  input.sort(cmp);   // mutates the prop / upstream value
  return input;
}, [input]);
```

```tsx
useMemo(() => {
  ref.current.value = computed;   // ref is observable outside this factory
  return computed;
}, [computed]);
```

#### Test for "is this local?"

A mutation inside a derivation is local if **all three** hold:

1. The mutated value was created (not just dereferenced) inside the factory's lexical scope.
2. After the factory returns, the only handle to the value is the return value.
3. The factory does not retain a captured reference to the value across calls.

If any of (1)–(3) fails, the mutation is observable outside the factory; the effect must move to an effect handler.

Without this carve-out, reviewers would mass-rewrite efficient factories into shapes that allocate O(n) intermediate objects for no semantic gain. Externally-immutable internal mutation is a performance idiom that costs nothing in correctness.

### Relationship to `effect-setup-cleanup-pair`

A derivation that opens a subscription or acquires a resource typically violates both rules at once: the subscription is an observable side effect (this rule), and it has no paired teardown inside the same effect (see `rules/effect-setup-cleanup-pair.md`). Fix the placement first (move to an effect handler), then add the cleanup return.
