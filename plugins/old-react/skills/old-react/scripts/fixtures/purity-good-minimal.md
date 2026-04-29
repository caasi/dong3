---
title: Good Minimal
slug: purity-good-minimal
category: purity
impact: HIGH
tags: [render]
---

## Good Minimal

A minimal valid rule used to smoke-test the validator.

**Incorrect** (mutates state):
```tsx
state.x = 1;
```

**Correct** (returns new state):
```tsx
return { ...state, x: 1 };
```
