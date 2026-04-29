---
title: Frontmatter never closed; body has horizontal rule
slug: purity-frontmatter-body-hr
category: purity
impact: HIGH
tags: [render, state]

## Frontmatter never closed; body has horizontal rule

This file omits the closing `---` for its YAML frontmatter. The body
*does* contain a `---` line below as a Markdown horizontal rule, but
that is not a frontmatter terminator — body content (this very H2)
appears before it.

---

**Incorrect** (mutates state):
```tsx
state.x = 1;
```

**Correct** (returns new state):
```tsx
return { ...state, x: 1 };
```
