---
title: Effects emit named actions
slug: effect-emit-named-actions
category: effect
impact: HIGH
tags: [effects, replay, events]
---

## Effects emit named actions

An effect — fetch, subscribe, persist, navigate — should emit named actions describing what happened, not be an opaque function that mutates the store directly. Each effect's outcomes are tagged values flowing through the same dispatch interface as user events; the action log is the legible timeline of the session.

This is **not** a recipe for pure Elm-style `Cmd Msg` values. In JavaScript the practical shape is a thunk that (a) returns a `Promise<T>` so call sites can compose with `await` and (b) dispatches one or more tagged actions (`'user/loading'`, `'user/ok'`, `'user/fail'`) along the way. You trade some replay-from-log purity for composability — the middle ground JS rewards.

**Incorrect** (effect is opaque; nothing in the action log says what happened):
```tsx
function loadUser(id: string) {
  return async (dispatch: Dispatch, getState: GetState) => {
    const user = await fetch(`/api/users/${id}`).then(r => r.json());
    getState().userMap[id] = user; // mutates store directly
  };
}
```

**Correct** (effect emits named actions and returns a composable Promise):
```tsx
function loadUser(id: string) {
  return async (dispatch: Dispatch): Promise<User> => {
    dispatch({ type: 'user/loading', id });
    try {
      const user = (await fetch(`/api/users/${id}`).then(r => r.json())) as User;
      dispatch({ type: 'user/ok', payload: user });
      return user;
    } catch (error) {
      dispatch({ type: 'user/fail', id, error });
      throw error;
    }
  };
}

// Compose at the call site — small features into large ones:
async function bootstrap(dispatch: Dispatch) {
  const me = await dispatch(loadUser('me'));
  await dispatch(loadFriends(me.id));
}
```

Two properties to preserve:

- **Every meaningful state transition has a tag.** Tools, tests, and replay drivers can read the action log to reconstruct the session; direct store mutation breaks that.
- **The thunk's return value is a real value, not a side channel.** `Promise<T>` lets you build large features out of small ones — `await dispatch(a)` then `await dispatch(b)` — without re-implementing composition inside the reducer.

Two honest limitations to keep in mind:

- **Race conditions are not eliminated.** The action stream is eager, not lazy; concurrent effects can interleave their action emissions in any order. If timing-sensitive bugs matter, reach for an effect-handler library that provides cancellation, racing, and switching (see `references/lib-suggestions.md`); this rule is about *visibility*, not concurrency control.
- **Replay is partial.** Re-issuing the action log does not reissue the I/O — you get the *trace* of what happened, not a re-runnable proof.

The rule's principle is the same whichever effect mechanism you reach for: outcomes are named, the timeline is legible, business logic composes through return values.
