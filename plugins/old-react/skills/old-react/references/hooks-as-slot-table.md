# Hooks as a slot table

Hooks are not algebraic effects. They are an *approximation* of algebraic effects, implemented as a position-indexed slot table backed by a render-time mutable global. Knowing this is the difference between memorizing the Rules of Hooks and being able to debug a violation from principles.

## What hooks actually are

1. A module-level mutable dispatcher pointer (`ReactCurrentDispatcher.current`) that React swaps on entry and exit of a component render.
2. A per-fiber linked list of hook records (`memoizedState.next.next.next…`).
3. An integer cursor that advances by one for every hook call within a single render.
4. A discipline (the Rules of Hooks) that ensures the cursor stays in lockstep across renders, so the *N*th hook call refers to the same hook record each time.

Drop the discipline and the cursor drifts: a `useState` at slot 2 last render is now at slot 1 and reads someone else's state.

## Why the rules look weird

- "Only call hooks at the top level" — because slot indices are implicit in source position.
- "Only call hooks from React function components or other custom hooks" — because the dispatcher pointer is only set during the render of such functions.
- "Honest dependency arrays" — because the framework cannot inspect the body of an effect to see what it reads; it can only compare the dep array you wrote.

These are *not* arbitrary stylistic preferences. They are the user-visible surface of a slot-table mechanism that has no language-level enforcement.

## What this means for rule design

`hooks-` rules in this skill are procedural: *do this, not that*. Other categories (`purity-`, `model-`, `message-`, `effect-`) are architectural: *shape your code this way and the procedural rules largely take care of themselves*. The two complement each other.

If you find yourself fighting `react-hooks/exhaustive-deps` (the official ESLint rule that backs the `hooks-` discipline; v0.1.0 of this skill defers to it rather than re-stating it), the fix is almost always at a different level — extract a stable identity, lift state, move logic into an event handler — not silence the linter.

## Further reading inside this skill

- `tea-as-backbone.md` — why architecture beats discipline.
- `fp-thinking.md` — the lens behind the architecture.
- `scoreboard.md` — how hooks compare to the original (algebraic effects).
