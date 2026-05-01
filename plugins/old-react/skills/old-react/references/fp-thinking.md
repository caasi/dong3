# FP thinking, applied to React

> React wants to be Elm. The closer you write code to TEA shape, the more you get for free: Single Source of Truth, time-travel debugging, hot-reloadable logic, replay-from-log. The further you drift, the more rules-of-hooks you need to memorize.

This reference defines the lens that the rules in this skill apply. It is short on history (see `tea-as-backbone.md`) and short on libraries (see `lib-suggestions.md`); the goal here is the lens.

## Three pillars

### 1. Pure leaves

`view = f(model)`. A component is a pure projection of its inputs to JSX. Reading wall-clock time, random sources, storage, or external mutable state during render breaks idempotence and replay.

### 2. Immutable updates

A new state is a new value. Reference equality on persistent data is what selectors, reconcilers, and time-travel use to know that something changed. In-place mutation makes "before" and "after" indistinguishable.

**Why immutability is affordable.** Persistent data structures share unchanged subtrees across versions: an "update" allocates O(log n) new nodes and reuses the rest by reference. Chris Okasaki's *Purely Functional Data Structures* (CMU PhD thesis, 1996; Cambridge book, 1998) showed this discipline preserves the asymptotic complexity of mutable equivalents — and that lazy evaluation is what keeps amortized bounds intact under arbitrary version reuse. React's reconciler, Redux's selectors, Immer's drafts, and Immutable.js / RRB-tree libraries are practitioner instantiations of this result. The structural-sharing contract is also what makes `model-stable-derivation-identity` more than a memoization hack: preserving identity on unchanged input *is* preserving the persistent-data-structures invariant at the derivation layer.

The lineage Okasaki → Elm → Redux is the *data-side* prefix to the Bret Victor → Elm → Redux *interaction-side* lineage in `tea-as-backbone.md`. Time-travel debugging needs both: structural sharing so old versions remain O(1) accessible, and TEA shape so transitions are replayable.

### 3. Effects at the edges

Effects are descriptions interpreted by a runtime, not callbacks invoked from inside business logic. The reducer is pure; the world is not; the boundary between them is explicit.

## Why these three reinforce each other

Drop any one and the others lose value. Mutable state defeats time-travel even with pure render. Pure render with effects-as-callbacks loses replay. Effects-as-data with mutable state cannot reach a known earlier state by replay because "earlier state" is not preserved.

The TEA shape — `Model`, `Msg`, `update`, `view`, `Cmd`, `Sub` — fixes all three at once. That is why every category in this skill traces back to it.

## What FP thinking *is not*

It is not a religion against MobX-style transparent FRP. Mutable observable state with auto-tracked subscriptions is a coherent alternative; the trade is ergonomics for replay. `references/scoreboard.md` makes the trade-off explicit.

It is not a religion against thunks or callbacks in tiny apps either. The cost of effects-as-data shows up at scale, in tests, and in tooling — not in a 50-line prototype.

## How to read a rule

Every rule names: a principle, a concrete failure mode, a concrete fix. The fix is not the only fix; it is the simplest fix that keeps the FP lens intact.
