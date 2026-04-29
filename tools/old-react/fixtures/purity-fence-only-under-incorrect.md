---
title: Both blocks under Incorrect
slug: purity-fence-only-under-incorrect
category: purity
impact: HIGH
tags: [render, state]
---

## Both blocks under Incorrect

This rule has both `**Incorrect**` and `**Correct**` markers and four fence
lines (two code blocks), but both blocks live under `**Incorrect**`. The
`**Correct**` section has no fenced block. A purely-numerical fence-count
check would accept it; a per-section check should reject.

**Incorrect** (first example):
```tsx
const a = 1;
```

**Incorrect** (second example, still wrong):
```tsx
const b = 2;
```

**Correct** (no block):
The fix is left as an exercise for the reader.
