---
title: Consistent context access
slug: compose-consistent-context-access
category: compose
impact: LOW
tags: [composition, deps, subscriptions]
---

## Consistent context access

A HOC chain (`A(B(C(Component)))`) is left-to-right function composition written out-of-line: each step injects props the inner component depends on, and the dataflow is invisible at the call site. Hooks invert this — the component reads the same context-bound values from inside, where the dataflow is local and typed. The real failure this rule targets is **mixed convention**: when one part of the codebase reads a context via HOC and another reads the same context via hook, every reader pays the cognitive cost of reconstructing which path applies. Consistency is the signal, not orthodoxy.

**Incorrect** (HOC chain; hook equivalents already used elsewhere in the same project):

```tsx
export default withStore(
  (state: AppState) => ({ slice: state.slice }),
  {},
)(withRoute(memo(PageBase)));
```

**Correct** (hooks inside the component; dataflow visible at the call site):

```tsx
function PageBase(props: Props) {
  const slice = useStore((s: AppState) => s.slice);
  const route = useRoute();
  // ...
}
export default memo(PageBase);
```

This rule fires only when all three gating conditions hold:

1. **React ≥ 16.8** — hooks exist in the runtime.
2. **The HOC's library exposes a hook counterpart on the version pinned by this project.** If the project pins a pre-hook version of a library, the HOC chain is not a violation — document it as an upgrade-readiness note at most.
3. **The same context is already accessed via hooks elsewhere in this codebase.** Inconsistency is the actual signal. If the project uses HOCs consistently throughout, emit at most an info-level note, not a violation.

If condition 1 or 2 fails: emit no finding. If only condition 3 fails: emit an info-level note, not a violation.

Detection heuristic: for each HOC chain, identify the context keys each HOC injects (store, route, theme, i18n, …). For each key, check whether a hook-form access to that key exists anywhere in `src/**`. If it does and the gating conditions pass, report a violation citing the example file where the hook form is already used.

## Not a violation when

- The library version pinned by the project does not ship a hook counterpart. Document as an upgrade-readiness note; do not fail the file.
- Class components in the same file consume the HOC-injected props — hooks are unavailable inside class components.
- The HOC is a non-context concern (error boundary, code-splitting boundary, animation wrapper) — these have no hook-form replacement and are out of scope.
- The codebase consistently uses HOCs across the board with no hook-form access to the same context anywhere in the project.

See `compose-leaf-purity` for the related leaf purity concern: a leaf that reads from a store directly (whether via hook or HOC) violates leaf purity. Consistent context access and leaf purity are complementary — fix the access style first, then lift the access to the right level in the tree. For library-specific hook counterparts and version ranges, see `references/lib-suggestions.md`.

<!--
Author notes:
  - Rule body uses pattern vocabulary only (reducer, action, dispatch, store, message,
    command, subscription, selector, state machine, observable as a concept,
    tagged union, effect handler).
  - Library brand names (Redux, MobX, RxJS, TanStack, SWR, Reselect, Immer, XState, ...)
    are NOT allowed in the rule body. Reference `references/lib-suggestions.md` instead.
  - RxJS operator names (switchMap, mergeMap, debounceTime, ...) count as brand-adjacent.
-->
