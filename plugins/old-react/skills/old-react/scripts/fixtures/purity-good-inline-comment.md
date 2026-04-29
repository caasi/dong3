---
title: Good with inline comment # smoke test for comment stripping
slug: purity-good-inline-comment
category: purity
impact: HIGH
tags: [render]
---

## Good with inline comment

A minimal valid rule whose frontmatter carries a YAML inline comment on
the title line. The validator must strip the trailing `# ...` so the
extracted title matches the body heading.

**Incorrect** (mutates state):
```tsx
state.x = 1;
```

**Correct** (returns new state):
```tsx
return { ...state, x: 1 };
```
