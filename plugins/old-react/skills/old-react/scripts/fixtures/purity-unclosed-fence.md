---
title: Unclosed fence
slug: purity-unclosed-fence
category: purity
impact: HIGH
tags: [render]
---

## Unclosed fence

This file opens a fenced code block under **Incorrect** but never closes
it. The closing ``` for the section is missing entirely. A fence-pair
balance check should reject the file.

**Incorrect** (mutates state, fence never closed):
```tsx
state.x = 1;

**Correct** (returns new state):
```tsx
return { ...state, x: 1 };
```
