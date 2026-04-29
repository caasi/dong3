---
title: Bad tag
slug: purity-bad-tag
category: purity
impact: HIGH
tags: [render, foobar]
---

## Bad tag

This file's frontmatter declares `tags: [render, foobar]`. `foobar` is
not in the closed tag set defined by the spec, so the validator should
reject it.

**Incorrect** (mutates state):
```tsx
state.x = 1;
```

**Correct** (returns new state):
```tsx
return { ...state, x: 1 };
```
