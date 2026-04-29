---
title: Unclosed frontmatter
slug: purity-unclosed-frontmatter
category: purity
impact: HIGH
tags: [render]

## Unclosed frontmatter

This file opens frontmatter with `---` and never closes it. Every other
field is well-formed and would individually validate, so the only check
that should reject this file is the closing-`---` check.

**Incorrect** (mutates state):
```tsx
state.x = 1;
```

**Correct** (returns new state):
```tsx
return { ...state, x: 1 };
```
