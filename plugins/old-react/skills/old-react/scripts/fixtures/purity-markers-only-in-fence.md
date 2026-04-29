---
title: Markers only in fence
slug: purity-markers-only-in-fence
category: purity
impact: HIGH
tags: [render]
---

## Markers only in fence

This file has the `**Incorrect**` and `**Correct**` strings only inside
a fenced code block — there are no real section markers in the body.
The validator should reject it because the body never declares the
sections outside fences.

```text
**Incorrect** (this looks like a marker but lives inside a fence):
const a = 1;

**Correct** (also fenced):
const b = 1;
```

This paragraph follows the fence and has no markers at all.
