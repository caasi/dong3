---
title: Prefer optional event handler props
slug: compose-optional-callbacks
category: compose
impact: MEDIUM
tags: [composition, events]
---

## Prefer optional event handler props

A required `onXxx` prop couples the component to every call site: callers must supply a handler even when they have no meaningful response to the event. Making callbacks optional — defaulting to a no-op or `undefined` — lets the component be moved, reused, or composed in new contexts without forcing that coupling on callers that don't need it. This is the component's API applying the same "open for extension, closed for modification" property that pure functions achieve at the function level.

**Incorrect** (caller is forced to supply a handler it may not need):
```tsx
type SaveButtonProps = {
  onSave: () => void; // required — every caller must wire this up
};

function SaveButton({ onSave }: SaveButtonProps) {
  return <button onClick={onSave}>Save</button>;
}

// Caller in a read-only context must pass a no-op just to satisfy the type:
<SaveButton onSave={() => {}} />
```

**Correct** (callback is optional; component supplies a safe default):
```tsx
type SaveButtonProps = {
  onSave?: () => void; // optional — callers wire it up only when they care
};

function SaveButton({ onSave }: SaveButtonProps) {
  return <button onClick={onSave}>Save</button>;
}

// Caller in a read-only context omits it:
<SaveButton />

// Caller that needs the callback wires it up:
<SaveButton onSave={() => dispatch({ type: 'doc/saved' })} />
```

A callback should be required only when the component cannot function correctly without it — for example, a controlled input where `onChange` is the only channel back to the state owner (see `model-controlled-by-default`), or a form whose submission is meaningless without a handler. Treat required callbacks as a deliberate constraint documented at the type level, not as the default.

When a callback is genuinely optional, prefer leaving the type as `(() => void) | undefined` and letting the browser handle the absent prop naturally (e.g. passing `undefined` to an `onClick` attribute is a valid no-op). Avoid redundant explicit `() => {}` defaults in the destructuring: they hide the "nothing will happen" case at the call site and make the absence of intent harder to grep for.

<!--
Author notes:
  - Rule body uses pattern vocabulary only (reducer, action, dispatch, store, message,
    command, subscription, selector, state machine, observable as a concept,
    tagged union, effect handler).
  - Library brand names (Redux, MobX, RxJS, TanStack, SWR, Reselect, Immer, XState, ...)
    are NOT allowed in the rule body. Reference `references/lib-suggestions.md` instead.
  - RxJS operator names (switchMap, mergeMap, debounceTime, ...) count as brand-adjacent.
-->
