---
title: Heading lives only in a code fence
slug: purity-title-only-in-fence
category: purity
impact: HIGH
tags: [render]
---

This file's body never declares a real `## Heading lives only in a code
fence` H2 — the literal string only appears inside a code fence below.
The validator should not be fooled by substring matching that crosses
fence boundaries.

```text
## Heading lives only in a code fence
```

**Incorrect** (mutates state):
```tsx
state.x = 1;
```

**Correct** (returns new state):
```tsx
return { ...state, x: 1 };
```
