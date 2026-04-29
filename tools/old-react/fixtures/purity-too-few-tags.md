---
title: Too few tags
slug: purity-too-few-tags
category: purity
impact: HIGH
tags: [render]
---

## Too few tags

This file declares only one tag. The spec requires two-to-four tags
from the closed set, so the validator should reject this.

**Incorrect** (mutates state):
```tsx
state.x = 1;
```

**Correct** (returns new state):
```tsx
return { ...state, x: 1 };
```
