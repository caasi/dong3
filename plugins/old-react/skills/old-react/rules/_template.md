---
title: <human-readable rule title>
slug: <prefix>-<kebab-slug>     # must match filename basename
category: <one of: purity | immutable | model | message | effect | hooks | compose>
impact: <one of: CRITICAL | HIGH | MEDIUM | LOW>
tags: [<two-to-four tags from the closed set in spec §8>]
---

## <title>

<1–3 sentence why-it-matters, FP-grounded. State the principle, not the rule.>

**Incorrect** (<what's wrong, in <=8 words>):
```tsx
// minimal example showing the violation
```

**Correct** (<what's right, in <=8 words>):
```tsx
// minimal example showing the FP-shaped fix
```

<Optional 1–2 paragraph deeper context. May reference `references/*.md`.>

<!--
Author notes:
  - Rule body uses pattern vocabulary only (reducer, action, dispatch, store, message,
    command, subscription, selector, state machine, observable as a concept,
    tagged union, effect handler).
  - Library brand names (Redux, MobX, RxJS, TanStack, SWR, Reselect, Immer, XState, ...)
    are NOT allowed in the rule body. Reference `references/lib-suggestions.md` instead.
  - RxJS operator names (switchMap, mergeMap, debounceTime, ...) count as brand-adjacent.
-->
