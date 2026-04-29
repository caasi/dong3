---
title: Controlled by default
slug: model-controlled-by-default
category: model
impact: HIGH
tags: [state, ssot, events]
---

## Controlled by default

A controlled component is `view : Model → Html Msg` made literal: the input's `value` reads from state, and `onChange` dispatches a labeled message that drives the next state. Uncontrolled inputs hide the value in the DOM — a mutable register the reducer never sees — so the model stops being the source of truth and replay breaks even when nothing is explicitly mirrored.

The continuation lens helps: `<input value={x} onChange={e => …}>` is a view that carries its own continuation handlers. The user's keystroke is the side-effect that re-enters the update loop with a fresh message; the component, in continuation-passing form, is `(value, k) => view-with-k-as-onChange`.

**Incorrect** (uncontrolled; the DOM holds the value):
```tsx
function NameField() {
  const ref = useRef<HTMLInputElement>(null);
  // the only way to read the value is at submit time, via the DOM
  return <input ref={ref} defaultValue="" />;
}
```

**Correct** (controlled; state holds the value, onChange threads the continuation):
```tsx
function NameField({ name, onChange }: { name: string; onChange: (v: string) => void }) {
  return <input value={name} onChange={e => onChange(e.target.value)} />;
}
```

Genuine exceptions exist — `<input type="file">` cannot be controlled, and very-large forms where the field is read only on submit can stay uncontrolled to avoid per-keystroke re-render. Treat those as deliberate trade-offs documented at the call site, not as the default.
